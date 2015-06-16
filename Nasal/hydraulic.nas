## Hydraulic system for CRJ700 family ##
## Author:		Henning Stahlke
## Created:		May 2015

# CRJ700 has three (3) independent hydraulic system, each with a nominal 
# pressure of 3000psi (206.85 bar). 
# System 1 and 2 are identical, each consisting of engine driven pump (EDP) 
# (1A, 2A), AC motor pump (ACMP) (1B, 2B), shut of valve (SOV) and other parts.
# Pumps 1B,2B each are powered by the AC bus of the other side engine 
# (1B - AC bus 2, 2B - AC bus 1) and are controlled via switches in OHP, where 
# AUTO will run the pump if flaps > 0 (and AC power avail).
# SOV can be closed manually via the corresponding OHP switchlights or by 
# pushing ENG FIRE PUSH switchlight. For simplification, the SOV switches will
# be used as switches for pumps 1A,2A which are EDP and thus have no AC switch.  
# System 3 consists of two ACMP (3A,3B) controlled by OHP switches. 3A shall
# run always so the switch has no auto position. 3B will run in auto pos, if 
# flaps > 0 and either IDG provides AC power. 3B will run irrespectively of 
# switch position if ADG (ram air turbine) is deployed.

# Rudder and elevators are driven by all three system.
# Sys 1 (left engine): left aileron, left reverser, 
#		outboard (spoilerons, flight spoilers, ground spoilers)
# Sys 2 (right engine): right aileron, right reverser, outboard brakes,
#		inboard (spoilerons, flight spoilers), assist landing gear actu.
# Sys 3 (AC): l+r aileron, landing gear, inboard brakes, inboard gnd.spoil.
#		nose wheel steering

## FG properties used
# controls/hydraulic/system[n]
#		hyd-sov-open	OHP switches for SOV
#		pump-a, pump-b 	OHP switches for pumps (0, 1, 2 = auto)
# systems/hydraulic/system[0..2]/* 
#		system state
# systems/hydraulic/outputs/*	
#		computed effective hyd. states, this props enable hyd. functions
#


var HydraulicPump = {
	new: func (sys, pid, params) {
		var switch = params[0];
		var pwr_input = params[1];
		var input_min = params[2];
		var input_max = params[3];
		var obj = {parents: [HydraulicPump], 
			sys: sys, 
			pid: pid, 
			output_nominal: 3000,
			output_min: 1800,
			output: 0,
		};
		obj.serviceable_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pump-"~pid~"-serviceable", 1);
		obj.switch_node = props.globals.getNode("/controls/hydraulic/system["~sys~"]/"~switch, 1);
		obj.running_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pump-"~pid~"-running", 1); 
		obj.output_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pump-"~pid~"-psi", 1); 
		obj.pwr_input_node = props.globals.getNode(pwr_input, 1);
		obj.input_min = (input_min > 0) ? input_min : 1;
		obj.input_max = (input_max > 0) ? input_max : 1;
		obj.sw2 = 0; 
		#print("Init pump "~obj.pid);
		setlistener(obj.switch_node, func(v) {obj._switch_listener(v);},1,0);
		setlistener(obj.pwr_input_node, func(v) {obj._update_output();},1,0);
		setlistener(obj.serviceable_node, func(v) {obj._update_output();},1,0);
		return obj;
	},
	
	#0,1,2 : off, on, automatic mode (use 2nd switch input)
	_switch_listener: func(v){
		me.switch = v.getValue();
		#print("hyd.p "~me.sys~"."~me.pid~": "~me.switch~", "~me.sw2);
		me._update_output();
	},
	
	get_switch: func { return me.switch; },

	#store signal for pump automatic mode, called by hydraulic system class
	set_switch2:  func (on) {
		me.sw2 = (on > 0) ? 1 : 0;
		#print("hyd.p a "~me.sys~"."~me.pid~": "~me.switch~", "~me.sw2);
		if (me.switch == 2) me._update_output();
		return me.sw2;
	},	
	
	get_output: func () {
		return me.output;
	},

	_update_output: func {
		me.input = me.pwr_input_node.getValue();
		me.serviceable = me.serviceable_node.getValue();
		if (me.input == nil) me.input = 0;
		if (me.serviceable and (me.switch == 1 or me.switch == 2 and me.sw2)) {
			me.output = me.output_nominal;
			if (me.input < me.input_min) {
				me.output = int(me.output_nominal * me.input / me.input_min / 100);
				me.output = me.output * 100;
			}
			if (me.input > me.input_max) {
				me.output = int(me.output_nominal * me.input / me.input_max / 100);
				me.output = me.output * 100;
			}
		}
		else me.output = 0;
		me.output_node.setValue(me.output);

		#update running 0=off, 2=low output output, 1=good output output
		me.running = 0;
		if (me.output > 0) me.running = 2;
		if (me.output > me.output_min) me.running = 1;
		me.running_node.setValue(me.running);

		#print("hyd.upd "~me.sys~"."~me.pid~": "~me.output);
		return me.output;
	},
};

var HydraulicSystem = {
	new : func (sys, out_min, pa, pb, outputs_multi, outputs ) {
		obj = { parents : [HydraulicSystem],
			sys: sys, 
			pump_a: HydraulicPump.new(sys, "a", pa), 
			pump_b: HydraulicPump.new(sys, "b", pb),
			output_min: out_min,
			outputs_multi: [],
			outputs: [],
		};
		
		obj.output_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pressure-psi", 1); 
		obj.update_enabled_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/update-enabled", 1); 
		foreach (elem; outputs_multi) {
			append(obj.outputs_multi, props.globals.getNode("/systems/hydraulic/outputs/"~elem, 1));
		}
		foreach (elem; outputs) {
			append(obj.outputs, props.globals.getNode("/systems/hydraulic/outputs/"~elem, 1));
		}
		#print("HydraulicSystem.new "~sys);
		
		setlistener("controls/flight/flaps", func(v) {obj._auto_pump(v);},1,1);
		#setlistener("systems/hydraulic/system["~sys~"]", func {obj.update();}, 1, 2);
		return obj;
	},
	
	#set on-off-signal for pump B automatic mode
	_auto_pump: func (v) {
		me.pump_b.set_switch2(v.getBoolValue());
	},
	
	read_props: func {		
		me.output = me.output_node.getValue();
		me.update_enabled = me.update_enabled_node.getValue();
	},
	
	get_output: func {
		me.read_props();
		return me.output;
	},
	
	update: func() {
		me.read_props();
		if (me.update_enabled) {
			print("update "~me.sys~" "~me.update_enabled);
			var p1 = me.pump_a.get_output();
			var p2 = me.pump_b.get_output();
			me.output = (p1 < p2) ? p2 : p1;
			foreach (out; me.outputs_multi) {
				var hsys = props.globals.getNode("systems/hydraulic").getChildren("system");
				var pmax = 0;
				foreach (s; hsys) {
					p = s.getNode("pressure-psi").getValue();
					pmax = (p > pmax) ? p : pmax;
				}
				if (pmax >= me.output_min)
					out.setValue(1);
				else out.setValue(0);
			}		
			foreach (out; me.outputs) {
				out.setValue((me.output >= me.output_min));
			}
			me.output_node.setValue(me.output);
		}
	},
};

print("Creating hydraulic system ...");
#ACMPs have to be fixed after rework of electrical system
var hydraulics = [ 
	HydraulicSystem.new(0, 1800,
		["hyd-sov-open", "/engines/engine[0]/rpm", 21, 93],
		["pump-b", "/systems/electrical/right-bus", 24, 28],
		["rudder", "elevator", "aileron"], ["ob-spoileron", "ob-flight-spoiler", "ob-ground-spoiler", "left-reverser"],
	),
	HydraulicSystem.new(1, 1800,
		["hyd-sov-open", "/engines/engine[1]/rpm", 21, 93],
		["pump-b", "/systems/electrical/left-bus", 24 ,28],
		["rudder", "elevator", "aileron"], ["ib-spoileron", "ib-flight-spoiler", "landing-gear-alt", "right-reverser", "ob-brakes"],
	),
	HydraulicSystem.new(2, 1800,
		["pump-a", "/systems/electrical/right-bus", 24, 28],
		["pump-b", "/systems/electrical/left-bus", 24, 28],
		["rudder", "elevator", "aileron"], ["ib-ground-spoiler", "landing-gear", "nwsteering", "ib-brakes"],
	),
];

print("Hydraulic done.");
