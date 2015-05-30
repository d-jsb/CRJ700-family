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
	new: func (sys, pid, switch, pwr_input, input_min, input_max) {
		var obj = {parents: [HydraulicPump], 
			sys: sys, 
			pid: pid, 
			pressure_nominal: 3000,
			pressure: 0,
		};
		obj.serviceable_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pump-"~pid~"-serviceable", 1);
		obj.switch_node = props.globals.getNode("/controls/hydraulic/system["~sys~"]/"~switch, 1);
		obj.on_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pump-"~pid~"-on", 1); 
		obj.pressure_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pump-"~pid~"-psi", 1); 
		obj.running = obj.on_node.getBoolValue();
		obj.pwr_input_node = props.globals.getNode(pwr_input, 1);
		obj.input_min = (input_min > 0) ? input_min : 1;
		obj.input_max = (input_max > 0) ? input_max : 1;
		#print("Init pump "~obj.pid);
		setlistener(obj.switch_node, func(v) {obj._switch_listener(v);},1,0);
		return obj;
	},
	
	_switch_listener: func(v){
		#print("HydraulicPump["~me.sys~"]"~me.pid~": "~v.getValue());
		if (v.getValue() == 0) me.set_on_off(0);
		if (v.getValue() == 1) me.set_on_off(1);
	},
	
	get_switch: func { return me.switch_node.getValue(); },

	set_on_off:  func (on) {
		me.running = (on > 0) ? 1 : 0;
		me.on_node.setValue(me.running); 
		return me.running;
	},	
	
	get_pressure: func {
		me.input = me.pwr_input_node.getValue();
		#me.running = me.on_node.getValue();
		if (me.input == nil) me.input = 0;
		if (!me.running) me.pressure = 0;
		else {
			me.pressure = me.pressure_nominal;
			if (me.input < me.input_min) me.pressure = me.pressure_nominal * me.input / me.input_min;
			if (me.input > me.input_max) me.pressure = me.pressure_nominal * me.input / me.input_max;			
		}
		me.pressure_node.setValue(me.pressure);
		return me.pressure;
	},
};

var HydraulicSystem = {
	new : func (sys, pa, pb, outputs_multi, outputs ) {
		obj = { parents : [HydraulicSystem], sys: sys, pump_a: pa, pump_b: pb };		
		obj.pressure_psi_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pressure-psi", 1); 
		obj.pressure_nominal = pa.pressure_nominal;
		obj.outputs_multi = [];
		obj.outputs = [];
		foreach (elem; outputs_multi) {
			append(obj.outputs_multi, props.globals.getNode("/systems/hydraulic/outputs/"~elem, 1));
		}
		foreach (elem; outputs) {
			append(obj.outputs, props.globals.getNode("/systems/hydraulic/outputs/"~elem, 1));
		}
		#print("HydraulicSystem.new "~sys);
		setlistener("controls/flight/flaps", func(v) {obj._auto_pump(v);},1,0);
		#setlistener("systems/hydraulic/system["~sys~"]", func {obj.update();}, 1, 2);
		return obj;
	},
	
	_auto_pump: func (v) {
		if (me.pump_b.get_switch() == 2) {
			me.pump_b.set_on_off(v.getBoolValue());
		}
	},
	
	read_props: func {		
		me.pressure_psi = me.pressure_psi_node.getValue();
	},
	
	write_props: func {
		me.pressure_psi_node.setValue(me.pressure_psi);
	},
	
	get_pressure: func {
		me.read_props();
		return me.pressure_psi;
	},
	
	update: func() {
		me.read_props();
		var p1 = me.pump_a.get_pressure();
		var p2 = me.pump_b.get_pressure();
		me.pressure_psi = (p1 < p2) ? p2 : p1;
		
		foreach (out; me.outputs_multi) {
			var p1 = getprop("/systems/hydraulic/system[0]/pressure-psi");
			var p2 = getprop("/systems/hydraulic/system[1]/pressure-psi");
			var p3 = getprop("/systems/hydraulic/system[2]/pressure-psi");
			if (p1 >= me.pressure_nominal or p2 >= me.pressure_nominal or p3 >= me.pressure_nominal)
				out.setValue(1);
			else out.setValue(0);
		}		
		foreach (out; me.outputs) {
			out.setValue((me.pressure_psi >= me.pressure_nominal));
		}
		me.write_props();
	},
};

print("Creating hydraulic system ...");
#ACMPs have to be fixed after rework of electrical system
var hydraulics = [ 
	HydraulicSystem.new(0, 
		HydraulicPump.new(0, "a", "hyd-sov-open", "/engines/engine[0]/rpm", 21, 93),
		HydraulicPump.new(0, "b", "pump-b", "/systems/electrical/right-bus", 24, 28),
		["rudder", "elevator", "aileron"], ["ob-spoileron", "ob-flight-spoiler", "ob-ground-spoiler", "left-reverser"],
	),
	HydraulicSystem.new(1,
		HydraulicPump.new(1, "a", "hyd-sov-open", "/engines/engine[1]/rpm", 21, 93),
		HydraulicPump.new(1, "b", "pump-b", "/systems/electrical/left-bus", 24 ,28),
		["rudder", "elevator", "aileron"], ["ib-spoileron", "ib-flight-spoiler", "landing-gear-alt", "right-reverser", "ob-brakes"],
	),
	HydraulicSystem.new(2, 
		HydraulicPump.new(2, "a", "pump-a", "/systems/electrical/right-bus", 24, 28),
		HydraulicPump.new(2, "b", "pump-b", "/systems/electrical/left-bus", 24, 28),
		["rudder", "elevator", "aileron"], ["ib-ground-spoiler", "landing-gear", "nwsteering", "ib-brakes"],
	),
];

print("Hydraulic done.");
