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
# systems/hydraulic/system[0..2]
#


var HydraulicPump = {
	new: func (sys, pid, switch, pwr_input, pwr_min) {
		var obj = {parents: [HydraulicPump], sys: sys, pid: pid};
		obj.serviceable_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pump-"~pid~"-serviceable", 1);
		obj.on_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pump-"~pid~"-on", 1); 
		obj.switch_node = props.globals.getNode("/controls/hydraulic/system["~sys~"]/"~switch, 1);
		obj.running = obj.on_node.getBoolValue();
		obj.pwr_input_node = props.globals.getNode(pwr_input, 1);
		obj.pwr_min = pwr_min;
		setlistener(obj.switch_node, me._switch_listener);
		return obj;
	},
	
	get_switch: func { return me.switch_node.getValue(); },

	set_on_off:  func (on) {
		me.running = (on > 0) ? 1 : 0;
		me.on_node.setValue(me.running); 
		return me.running;
	},	
	
	get_pressure: func {
		me.input = me.pwr_input_node.getValue();
		if (me.input == nil) me.input = 0;
		if (!me.running) return 0;
		if (me.input > me.pwr_min) return 3000;
		return 3000 * me.input / me.pwr_min;
	},
	
	_switch_listener: func(v) {
		print("hp sw: "~v.getValue());
		if (v.getValue() == 0) me.set_on_off(0);
		if (v.getValue() == 1) me.set_on_off(1);
	},
};

var HydraulicSystem = {
	new : func (sys, pa, pb ) {
		obj = { parents : [HydraulicSystem], sys: sys, pump_a: pa, pump_b: pb };		
		obj.pressure_psi_node = props.globals.getNode("/systems/hydraulic/system["~sys~"]/pressure-psi", 1); 
		print("HydraulicSystem.new "~sys);
		return obj;
	},
	
	read_props: func {		
		me.pressure_psi = me.pressure_psi_node.getValue();
		print("read_props: pressure "~me.sys~": "~me.pressure_psi);
	},
	
	write_props: func {
		me.pressure_psi_node.setValue(me.pressure_psi);
	},

	update: func() {		
		me.read_props();
		var flaps = getprop("controls/flight/flaps");
		
		if (me.pump_b.get_switch() == 2) {
			if (me.pump_b != nil) me.pump_b.set_on_off(flaps);
		}
		var p1 = me.pump_a.get_pressure();
		var p2 = me.pump_b.get_pressure();
		me.pressure_psi = (p1 < p2) ? p2 : p1;
		print("HydS "~me.sys~": psi "~me.pressure_psi);
		
		me.write_props();
	},
};

print("Creating hydraulic system ...");

#ACMPs have to be fixed after rework of electrical system
var hydraulics = [ 
	HydraulicSystem.new(0, 
		HydraulicPump.new(0, "a", "hyd-sov-open", "/engines/engine[0]/n2", 57),
		HydraulicPump.new(0, "b", "pump-b", "/systems/electrical/right-bus", 24)
	),
	HydraulicSystem.new(1,
		HydraulicPump.new(1, "a", "hyd-sov-open", "/engines/engine[1]/n2", 57),
		HydraulicPump.new(1, "b", "pump-b", "/systems/electrical/left-bus", 24),
	),
	HydraulicSystem.new(2, 
		HydraulicPump.new(2, "a", "pump-a", "/systems/electrical/right-bus", 24),
		HydraulicPump.new(2, "b", "pump-b", "/systems/electrical/left-bus", 24),
	)
];

hydraulics[0].update();
print("Hydraulic system done.");

##############################################################
# development
##############################################################

# creates a listener for pump switch
var pump_switch_handler = func (sys, element) {
	return func (n) {
		var value = n.getValue();
		if (value == 0)
			setprop("systems/hydraulic/system["~sys~"]/"~element, 0);
		if (value == 1)
			setprop("systems/hydraulic/system["~sys~"]/"~element, 1);
	};
};

#setlistener("controls/hydraulic/system[0]/sov-open", pump_switch_handler(0,"pump-a-on"), 1);
#setlistener("controls/hydraulic/system[1]/sov-open", pump_switch_handler(1,"pump-a-on"), 1);
#setlistener("controls/hydraulic/system[0]/pump-b", pump_switch_handler(0,"pump-b-on"), 1);
#setlistener("controls/hydraulic/system[1]/pump-b", pump_switch_handler(1,"pump-b-on"), 1);
#setlistener("controls/hydraulic/system[2]/pump-a", pump_switch_handler(2,"pump-a-on"), 1);
#setlistener("controls/hydraulic/system[2]/pump-b", pump_switch_handler(2,"pump-b-on"), 1);

#setlistener("systems/hydraulic/system[0]", hydraulics[0].update, 1,2);
#setlistener("systems/hydraulic/system[1]", hydraulics[1].update, 1,2);
#setlistener("systems/hydraulic/system[2]", hydraulics[2].update, 1,2);

#setlistener("controls/flight/flaps", func { foreach (h; hydraulics)	h.update();});