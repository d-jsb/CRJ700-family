#
# Abstract classes for energy systems like electrical, hydraulic etc.
# Contains:
# - EnergyConv
# - EnergyBus
#

# EnergyConv
# (subsystem of EnergyBus)
# A switchable device 'converting' energy from an input to an output
# Examples: AC generator, AC2DC converter, hydraulic pump
#
# Output value will be calculated from input, switch and serviceable flag.
# Transfer function:
# out
#  |             
#  |             /
#  |      /-----/ out_nominal
#  |     /
#  |    /
# -0--min--lo--hi-------> in
#
# Output is constant, if input is between input_lo and input_hi,
# otherwise output will be linear scaled input.
#
# bus (EnergyBus)		the bus that is feeded by this device
# name (string)			name of device ("generator1", "pump-B", ...)
#
# Optional:
# input 				numeric constant or property path,
# output_nominal (num)	normal output level, if input_lo < input < input_hi
# output_min (num)		to calculate isRunning (0: off, 1: ok, 2: low)
# input_min	(num)		cutoff, input < min --> output = 0
# input_lo (num)		min input for nominal output
# input_hi (num)		max input for nominal output (0 -> no limit)
#

var EnergyConv = {
	new: func (bus, name, output_nominal=1, input=1, input_min = 0, input_lo=0, input_hi=0) {
		var obj = { parents: [EnergyConv],
			bus: bus,
			name: name,
			switch: 1,
			running: 0,
			input: 0,
			output: 0,
			input_min: 0,
			input_lo: 0,
			input_hi: 0,
			output_min: 1,
			output_nominal: 1,
			listeners: [],
			switchN: nil,
		};

		obj.serviceableN = props.globals.getNode(bus.system_path~name~"-serviceable", 1);
		obj.serviceableN.setBoolValue(1);
		obj.runningN = props.globals.getNode(bus.system_path~name~"-running", 1);
		obj.runningN.setBoolValue(0);
		obj.outputN = props.globals.getNode(bus.system_path~name~"-value", 1);
		obj.outputN.setValue(0);
		#input it either a numerical constant or a prop path
		if (num(input) != nil) {
			obj.inputN = props.globals.getNode(bus.system_path~name~"-input", 1);
			obj.inputN.setValue(input);
		}
		else
			obj.inputN = props.globals.getNode(input, 1);
		if (output_nominal != nil and output_nominal >= 0)
			obj.output_nominal = output_nominal;
		
		if (input_min != nil and input_min >= 0)
			obj.input_min = input_min;
		if (input_lo != nil and input_lo >= 0)
			obj.input_lo = input_lo;
		if (input_hi != nil and input_hi >= 0)
			obj.input_hi = input_hi;
		return obj;
	},

	init: func {
		#print(" "~me.name~".init input:"~me.inputN.getName());
		foreach (l; me.listeners) {
			#print("remove listener "~l);
			removelistener(l);
		}
		me.listeners = [];
		if (me.switchN != nil) {
			append(me.listeners, setlistener(me.switchN, func(v) {me._switch_listener(v);}, 1, 0));
		}
		append(me.listeners, setlistener(me.serviceableN, func(v) {me._update_output();}, 0, 0));
		append(me.listeners, setlistener(me.inputN, func(v) {me._update_output();}, 1, 0));
		return me;
	},

	setOutputMin: func (n) {
		if (num(n) >= 0)
			me.output_min = n;
		return me;
	},

	getOutputMin: func () {
		return me.output_min;
	},
	
	setInputMin: func (n) {
		if (num(n) >= 0)
			me.input_min = n;
		return me;
	},

	getInputMin: func () {
		return me.input_min;
	},

	setInputLo: func (n) {
		if (num(n) >= 0)
			me.input_lo = n;
		return me;
	},

	getInputLo: func () {
		return me.input_lo;
	},
	
	setInputHi: func (n) {
		if (num(n) >= 0)
			me.input_hi = n;
		return me;
	},

	getInputHi: func () {
		return me.input_hi;
	},
	
	addSwitch: func(name = "") {
		var path = "";
		if (name) me.switchN = props.globals.getNode(name, 1);
		else {
			var path = "/controls/"~me.bus.type~"/system["~me.bus.index~"]/"~me.name;
			me.switchN = props.globals.getNode(path, 1);
		}
		#print("Adding switch "~me.switchN.getName());
		return me;
	},

	_switch_listener: func(v){
		me.switch = v.getValue();
		print(me.name~" "~me.switch);
		me._update_output();
	},

	getSwitch: func { me.switch; },

	getValue: func { me.output; },

	isRunning: func {
		#update running: 0=off, 2=low output, 1=good output
		me.running = 0;
		if (me.output > 0) me.running = 2;
		if (me.output >= me.output_min) me.running = 1;
		me.runningN.setValue(me.running);
		return me.running;
	},

	_update_output: func {
		me.input = me.inputN.getValue();
		me.serviceable = me.serviceableN.getValue();
		if (me.input == nil) me.input = 0;
		me.output = 0;
		if (me.serviceable and me.switch and me.input >= me.input_min) {
			me.output = me.output_nominal;
			if (me.input_lo > 0 and me.input < me.input_lo) {
				me.output = me.output_nominal * (me.input - me.input_min) / (me.input_lo - me.input_min);
			}
			if (me.input_hi > 0 and me.input > me.input_hi) {
				me.output = me.output_nominal * me.input / me.input_hi;
			}
		}
		me.outputN.setValue(me.output);
		me.isRunning();
		#if (me.name == "gen1")
		#print("EnergyConv.update name: "~me.name~" sw:"~me.switch~" nom:"~me.output_nominal~" in: "~me.inputN.getName()~" "~me.input~" out:"~me.output);
		me.bus.update();
		return me;
	},
};


# EnergyBus
#
# Models an energy distribution system .
# Multiple energy sources and drains can be connected.
# The energy level (voltage, pressure,...) of the bus is max(inputs[]), which assumes sources are
# connected by a "one-way valve" (diode) to the bus.
#
# systype (string)		e.g. electrical, hydraulic
# sysid (int)			number of system (0,1,2,...)
# outputs[]	(string)	array of element names
# outputs_bool			0: outputs are set to the bus level
# 						1: outputs are set to 0 or 1
# output_min			threshold level to set bool outputs to true

var EnergyBus = {
	new: func (systype, sysid, name, outputs, outputs_bool = 0, output_min = 0) {
		var obj = {parents: [EnergyBus],
			type: systype,
			index: sysid,
			system_path: "/systems/"~systype~"/system["~sysid~"]/",
			outputs_path: "/systems/"~systype~"/outputs/",
			inputs: [],
			outputs: [],
			switches: [],
			listeners: [],
			outputs_bool: outputs_bool,
			output_min: output_min,
			params: [],
		};
		if (name) {
			var p = props.globals.getNode(obj.system_path~"_name", 1);
			p.setValue(name);
		}
		obj.serviceableN = props.globals.getNode(obj.system_path~"serviceable",1, "BOOL");
		obj.serviceableN.setBoolValue(1);
		obj.outputN = props.globals.getNode(obj.system_path~"value", 1, "FLOAT");
		obj.outputN.setValue(0);
		foreach (elem; outputs) {
			if (typeof(elem) == "scalar") {
				var o = props.globals.getNode(obj.outputs_path~elem, 1, "FLOAT");
				append(obj.switches, nil);
			}
			else {
				var o = props.globals.getNode(obj.outputs_path~elem[0], 1, "FLOAT");
				append(obj.switches, props.globals.getNode(elem[1], 1));
			}
			o.setValue(0);
			append(obj.outputs, o);			
		}
		return obj;
	},

	init: func {
		foreach (i; me.inputs) {
			if (isa(i, EnergyConv)) 
				i.init();
			elsif (isa(i,props.Node)) {
				print("Node listener");
				setlistener(i, func {me.update;}, 1,0);
			}
			else print("Unnown input type");
		}
		foreach (l; me.listeners)
			removelistener(l);
			
		foreach (s; me.switches)
			if (s != nil)
			append(me.listeners, setlistener(s, func(v) {
				me.update(); 
				#print("switch "~me.type~" "~v.getValue());
			}, 0, 0));
		return me;
	},

	addInput: func(obj) {
		if (obj != nil) append(me.inputs, obj);
		return me;
	},

	addOutput: func (name) {
		var n = props.globals.getNode(me.outputs_path~name, 1);
		if (n != nil) append(me.outputs, n);
		return me;
	},

	readProps: func {
		me.output = me.outputN.getValue();
		me.serviceable = me.serviceableN.getValue();
	},

	getLevel: func {
		me.readProps();
		return me.output;
	},

	update: func {
		me.readProps();
		if (me.serviceable) {
			me.output = 0;
			foreach (in; me.inputs) {
				var i = in.getValue();
				me.output = (me.output < i) ? i : me.output;
			}
			for (i = 0; i < size(me.outputs); i += 1) {
				if (me.switches[i] == nil or me.switches[i].getValue()) {
					if (me.outputs_bool == 1)
						me.outputs[i].setValue((me.output >= me.output_min));
					else
						me.outputs[i].setValue(me.output);
				}
				else me.outputs[i].setValue(0);
			}
			me.outputN.setValue(me.output);
		}
		return me;
	},
};

var Logic = {
	new: func(op, out = nil) {
		var valid_ops = ["and", "or", "not"];
		var obj = {parents: [Logic],
			listeners: [],
			operator: nil,
			inputs: [],
			output: out,
		};
		foreach (elem; valid_ops) {
			if (elem == op)
				obj.operator = op;
		}
		if (obj.operator == nil)
			print("Logic.new: Invalid operator");
		else 
		return obj;
	},

	init: func {
		foreach (l; me.listeners)
			removelistener(l);
		me.listeners = [];
		foreach (i; me.inputs) {
			append(me.listeners, setlistener(i, func(v) {me._update();}, 0, 0));
		}
		return me;
	},
	
	# add input if not already added
	input: func(prop) {
		foreach (i; me.inputs) {
			if (i == prop) return me;
		}
		if (me.operator != "not" or size(me.inputs) == 0) {
			append(me.inputs, prop);
			props.globals.getNode(prop, 1, "BOOL");
		}
		return me;
	},
	
	
	_update: func {
		var out = 0;
		if (me.operator == "and") {
			out = 1;
			foreach (i; me.inputs) {
				if (!getprop(i)) {
					out = 0;
					break;
				}
			}
			setprop(me.output, out);
		} elsif (me.operator == "or") {
			out = 0;
			foreach (i; me.inputs) {
				if (getprop(i)) {
					out = 1;
					break;
				}
			}
			setprop(me.output, out);
		} elsif (me.operator == "not") {
			setprop(me.output, !getprop(me.inputs[0]));
		}		
	},		
};