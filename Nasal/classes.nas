#
# Abstract classes for energy systems like electrical, hydraulic etc.
# Contains:
# - EnergyConv
# - EnergyBus
#

# EnergyConv
# A switchable device converting energy from an input to an output
# subsystem of EnergyBus
# Examples: AC generator, AC2DC converter, hydraulic pump
# Output value will be nominal, if input is between input_min and input_max
# otherwise output will be linear scaled input.
# 
# bus (EnergyBus)		the bus that is feeded by this src
# name (string)			name of device ("generator", "pump", ...)
# input 				numeric constant or property path, 
# output_nominal (num)	normal output level, if input_min < input < input_max
# output_min (num)		to calculate isRunning (0: off, 1: ok, 2: low)


var EnergyConv = {
	new: func (bus, name, output_nominal=1, output_min=0, input=1, input_min=0, input_max=0) {
		var obj = {parents: [EnergyConv], 
			bus: bus,
			name: name,
			switch: 0,
			input: 0,
			output: 0,
			input_min: 0,
			input_max: 0,
			output_min: 1,
			output_nominal: 1,
			params: arg,
		};
		
		obj.serviceableN = props.globals.getNode(bus.system_path~name~"-serviceable", 1);
		obj.switchN = props.globals.getNode("/controls/"~bus.type~"/system["~bus.index~"]/"~name, 1);
		obj.runningN = props.globals.getNode(bus.system_path~name~"-running", 1); 
		obj.outputN = props.globals.getNode(bus.system_path~name~"-value", 1); 
		#input it either a numerical constant or a prop path
		if (num(input) != nil)
			obj.inputN = props.globals.getNode(bus.system_path~"input", 1).setValue(input);
		else 
			obj.inputN = props.globals.getNode(input, 1);
		if (output_nominal != nil and output_nominal >= 0)
			obj.output_nominal = output_nominal;
		if (output_min != nil and output_min >= 0)
			obj.output_min = output_min;
		if (input_min != nil and input_min >= 0)
			obj.input_min = input_min;
		if (input_max != nil and input_max >= 0)
			obj.input_max = input_max;
		return obj;
	},
	
	init: func {
		me.serviceableL = setlistener(me.serviceableN, func(v) {me._update_output();}, 1, 0);
		me.switchL = setlistener(me.switchN, func(v) {me._switch_listener(v);}, 1, 0);
		me.inputL = setlistener(me.inputN, func(v) {me._update_output();}, 1, 0);
	},
	
	_switch_listener: func(v){
		me.switch = v.getValue();
		me._update_output();
	},
	
	getSwitch: func { me.switch; },

	getValue: func { me.output; },

	#update running 0=off, 2=low output, 1=good output
	isRunning: func { 
		me.running = 0;
		if (me.output > 0) me.running = 2;
		if (me.output >= me.output_min) me.running = 1;
		me.runningN.setValue(me.running);	
		return me.running;
	},
	
	_update_output: func {
		print("EnergyBus.update");
		me.input = me.inputN.getValue();
		me.serviceable = me.serviceableN.getValue();
		if (me.input == nil) me.input = 0;
		if (me.serviceable and me.switch) {
			me.output = me.output_nominal;
			if (me.input_min > 0 and me.input < me.input_min) {
				me.output = me.output_nominal * me.input / me.input_min;
			}
			if (me.input_max > 0 and me.input > me.input_max) {
				me.output = me.output_nominal * me.input / me.input_max;
			}
		}
		else me.output = 0;
		me.outputN.setValue(me.output);
		me.isRunning();
		return me;
	},
};

#
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
	new: func (systype, sysid, outputs, outputs_bool = 0, output_min = 0) {
		var obj = {parents: [EnergyBus], 
			type: systype, 
			index: sysid,
			system_path: "/systems/"~systype~"/system["~sysid~"]/",
			outputs_path: "/systems/"~systype~"/outputs/",
			inputs: [],
			outputs: [],
			outputs_bool: outputs_bool,
			output_min: output_min,
			params: [],
		};
		
		obj.serviceableN = props.globals.getNode(obj.system_path~"serviceable",1); 
		obj.serviceableN.setBoolValue(1);
		obj.outputN = props.globals.getNode(obj.system_path~"value", 1); 
		obj.outputN.setValue(0);
		foreach (elem; outputs) {
			append(obj.outputs, props.globals.getNode(obj.outputs_path~elem, 1));
		}
		if (size(arg) > 0) {
			obj.params = arg[0];
			print(obj.params);
			forindex (i; obj.params) print("p "~i~ ": "~obj.params[i]);
		}
		return obj;
	},
	
	init: func {
		foreach (i; me.inputs)
			i.init();
	},

	addInput: func(name, output_nominal=1, output_min=0, input=1, input_min=0, input_max=0) {
		print("add EnergyConv "~name);
		var s = EnergyConv.new(me, name, output_nominal, output_min, input, input_min, input_max);
		if (s != nil) append(me.inputs, s);
	},
	
	addOutput: func (name) {
		var n = props.globals.getNode(me.outputs_path~name, 1);
		if (n != nil) append(me.outputs, n);
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
			foreach (out; me.outputs) {
				if (me.outputs_bool == 1)
					out.setValue((me.output >= me.output_min));
				else
					out.setValue(me.output);
			}
			me.outputN.setValue(me.output);
		}
		return me;
	},
};

