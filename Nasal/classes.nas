#
# Abstract classes for energy systems like electrical, hydraulic etc.
# Contains:
# - EnergySrc
# - EnergyBus
#

# EnergySrc
# A switchable device converting energy from an input to an output
# subsystem of EnergyBus
# Examples: AC generator, AC2DC converter, hydraulic pump
# 

var EnergySrc = {
	new: func (bus, name, input) {
		var obj = {parents: [EnergySrc], 
			bus: bus,
			#name: name,
			input: 0,
			output: 0,
			input_min: 1,
			input_max: 1,
			output_min: 1,
			output_nominal: 1,
			params: arg,
		};
		
		obj.serviceableN = props.globals.getNode(bus.system_path~name~"-serviceable", 1);
		obj.switchN = props.globals.getNode("/controls/"~bus.type~"/system["~bus.index~"]/"~name~"-switch", 1);
		obj.runningN = props.globals.getNode(bus.system_path~name~"-running", 1); 
		obj.outputN = props.globals.getNode(bus.system_path~name~"-output", 1); 
		obj.inputN = props.globals.getNode(input, 1);
		if (obj.params["input_min"] != nil)
			obj.input_min = (obj.params["input_min"] > 0) ? obj.params["input_min"] : 1;
		if (obj.params["input_max"] != nil)
			obj.input_max = (obj.params["input_max"] > 0) ? obj.params["input_max"] : 1;
		setlistener(obj.switchN, func(v) {obj._switch_listener(v);},1,0);
		setlistener(obj.inputN, func(v) {obj._update_output();},1,0);
		setlistener(obj.serviceableN, func(v) {obj._update_output();},1,0);
		return obj;
	},
	
	_switch_listener: func(v){
		me.switch = v.getValue();
		me._update_output();
	},
	
	getSwitch: func { me.switch; },

	getValue: func { me.output; },
	isRunning: func { me.running },
	
	_update_output: func {
		me.input = me.inputN.getValue();
		me.serviceable = me.serviceableN.getValue();
		if (me.input == nil) me.input = 0;
		if (me.serviceable and me.switch) {
			me.output = me.output_nominal;
			if (me.input < me.input_min) {
				me.output = me.output_nominal * me.input / me.input_min;
			}
			if (me.input > me.input_max) {
				me.output = me.output_nominal * me.input / me.input_max;
			}
		}
		else me.output = 0;
		me.outputN.setValue(me.output);

		#update running 0=off, 2=low output, 1=good  output
		me.running = 0;
		if (me.output > 0) me.running = 2;
		if (me.output >= me.output_min) me.running = 1;
		me.runningN.setValue(me.running);
		return me;
	},
};


# EnergyBus 
# Models an energy distribution system (voltage, pressure).
# Multiple energy sources and drains can be connected.
# The energy level of the bus is max(inputs[]), which assumes sources are
# connected by a "one-way valve" to the bus.
# Outputs are set to the bus level, which will sink due to load.

var EnergyBus = {
	new: func (systype, sysid, outputs) {
		var obj = {parents: [EnergyBus], 
			type: systype, 
			index: sysid,
			system_path: "/systems/"~systype~"/system["~sysid~"]/",
			outputs_path: "/systems/"~systype~"/outputs/",
			inputs: [],
			outputs: [],
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
	
	#name: name of property 
	#switch: path/name of control node
	addSrc: func(name, switch) {
		var s = EnergySrc.new(me, name, switch, arg);
		if (s != nil) append(me.inputs, s);
	},
	
	addOutput: func (name) {
		var n = props.globals.getNode("/systems/"~me.type~"/outputs/"~name, 1);
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
				if (me.params["output_bool"])
					out.setValue((me.output >= me.params["output_min"]));
				else
					out.setValue(me.output);
			}
			me.outputN.setValue(me.output);
		}
		return me;
	},
};

