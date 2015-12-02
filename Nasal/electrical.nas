## Electrical system for CRJ700 family ##
## Author:		Henning Stahlke
## Created:		May 2015

# The CRJ700 electrical system consists of an AC part and a DC part.
# Multiple redundant buses distribute the power to the electrical loads.
#
# AC (115V@400Hz) 
# Feed by APU generator, engine generators or ext. power while on ground.
# 
#
# DC (24V - 28V)
# Feed by battery, external power and four TRUs (ac/dc converters)
# For simplification some parts are skipped.


## FG properties used
# controls/AC/system[n]/
# systems/AC/system[]/* 
# systems/AC/outputs/*	
#
# controls/DC/system[n]/
# systems/DC/system[]/* 
# systems/DC/outputs/*	
#		
#

# IDG (engine generator)
#
#

var IDG = {
	new: func (bus, name, input) {
		var obj = {
			parents: [IDG, EnergyConv.new(bus, name, 115, input, 52.5, 60, 95).setOutputMin(108)],
			freq: 0,
			load: 0,
		};
		obj.freqN = props.globals.getNode(bus.system_path~name~"-freq",1);
		obj.freqN.setValue(0);
		return obj;
	},

	_update_output: func {
		me.parents[1]._update_output();
		me.freq = 0;
		if (me.input > me.input_min) {			
			if (me.input < 57.5) 
				#me.freq = 375 * (me.input - me.input_min)/5;
				me.freq = 75 * int(me.input - me.input_min);
			elsif (me.input < me.input_lo) 
				#me.freq = 375 + 25 * (me.input - 57.5)/2.5;
				me.freq = 375 + int(10 * (me.input - 57.5));
		}
		me.freqN.setValue(me.freq);
		return me;
	},
};

var APUGen = {
	new: func (bus, name, input) {
		var obj = {
			parents: [APUGen, EnergyConv.new(bus, name, 115, input, 60, 99, 100).setOutputMin(108)],
			freq: 0,
			load: 0,
		};
		obj.freqN = props.globals.getNode(bus.system_path~name~"-freq",1);
		obj.freqN.setValue(0);
		return obj;
	},

	_update_output: func {
		me.parents[1]._update_output();
		me.freq = 0;
		if (me.input > 60) {			
			if (me.input < 70) 
				me.freq = 37.5 * int(me.input - 60);
			elsif (me.input < 100) 
				me.freq = 375 + int(0.83333 * (me.input - 70));
			else me.freq = 400;
		}
		me.freqN.setValue(me.freq);
		return me;
	},
};
# ACBus
# add freq [Hz] and load [kVA]

var ACBus = {
	new: func (sysid, name, outputs) {
		obj = { parents : [ACBus, EnergyBus.new("AC", sysid, name, outputs)],
			freq: 0, #Hz
			load: 0, #kVA
		};		
		return obj;
	},
};

var DCBus = {
	new: func (sysid, name, outputs) {
		obj = { parents : [DCBus, EnergyBus.new("DC", sysid, name, outputs)],
		};		
		return obj;
	},
};

# ACPC (AC power center)
# connection logic from AC sources to AC buses

var ACPC = {
	new: func (sysid, outputs) {
		obj = { parents : [ACPC, EnergyBus.new("AC", sysid, "acpc", outputs)],
			buses: [],
		};
		print(obj.parents[1].system_path);
		return obj;		
	},

	readProps: func {		
		me.output = me.outputN.getValue();
		me.serviceable = me.serviceableN.getValue();
	},
		
	update: func {
		me.readProps();
		if (me.serviceable) {
			var g1 = me.inputs[0].getValue();
			var g2 = me.inputs[1].getValue();
			var apu = me.inputs[2].getValue();
			var ep = me.inputs[3].getValue();
			var adg = me.inputs[4].getValue();
			
			print("ACPC "~g1~", "~g2~", "~apu~", "~ep);
			var v = 0;
			
			#use ext. AC until APU avail
			if (apu < ep) apu = ep;
			#AC1
			v = (g1 >= apu) ? g1 : apu;
			me.outputs[0].setValue(v);
			
			#AC2
			v = (g2 >= apu) ? g2 : apu;
			me.outputs[1].setValue(v);
			
			#AC_ESS
			v = (g1 >= g2) ? g1 : g2;
			v =(adg > v) ? adg : v;
			me.outputs[2].setValue(v);
			
			#AC_SERVICE
			v = (g2 >= apu) ? g2 : apu;
			me.outputs[3].setValue(v);
			
			#ADG			
			me.outputs[4].setValue(adg);			
		}
		return me;
	},
};

var DCPC = {
	new: func (sysid, outputs) {
		obj = { parents : [DCPC, EnergyBus.new("DC", sysid, "dcpc", outputs)],
			buses: [],
		};
		print(obj.parents[1].system_path);
		return obj;		
	},
	
	readProps: func {		
		me.output = me.outputN.getValue();
		me.serviceable = me.serviceableN.getValue();
	},
		
	update: func {
		me.readProps();
		if (me.serviceable) {
			var t1 = me.inputs[0].getValue();
			var t2 = me.inputs[1].getValue();
			var et1 = me.inputs[2].getValue();
			var et2 = me.inputs[3].getValue();
			var bat1 = me.inputs[4].getValue();

			print("DCPC "~t1~", "~t2~", "~et1~", "~et2~", "~bat1);
			var v = 0;
			
			#Battery
			me.outputs[4].setValue(bat1);

			#DC1
			v = (t1 >= bat1) ? t1 : bat1;
			me.outputs[0].setValue(v);
			
			#DC2
			v = (t2 >= bat1) ? t2 : bat1;
			me.outputs[1].setValue(v);
	
			#DC_SERVICE
			me.outputs[3].setValue(v);

			#DC_ESS
			v = (et1 >= bat1) ? et1 : bat1;
			me.outputs[2].setValue(v);
		}
		return me;
	},
};


print("Creating electrical system ...");

var ac_buses = [ 
	ACBus.new(1, "AC1", ["tru1", "flaps-a", "pitch-trim-1", "hyd-pump2B", "hyd-pump3B","aoa-heater-r", "pitot-heater-r", "egpws"]),
	ACBus.new(2, "AC2 ", ["tru2", "esstru2", "flaps-b", "pitch-trim-2", "hyd-pump1B", "hyd-pump3A", "copilot-panel-lights"]),
	ACBus.new(3, "AC-ESS", ["esstru1", "xflow-pump", "pitot-heater-l", "aoa-heater-l", "cabin-lights", "ohp-lights", "pilot-panel-lights", "center-panel-lights", "tcas", "ignition-a"]),
	ACBus.new(4, "AC-Service", ["apu-charger", "logo-lights", "cabin-lights"]),
	ACBus.new(5, "ADG", ["hyd-pump3B", "pitch-trim-2", "flaps-a", "flaps-b"]),
];

var dc_buses = [
	DCBus.new(1, "DC1", ["eicas-disp", "radio-altimeter1", "passenger-door", "wiper-left", "nwsteering", "taxi-lights", "landing-lights[1]", "rear-ac-light", "wing-lights", "gps1", "dme1", "wradar"]),
	DCBus.new(2, "DC2", ["vhf2", "rtu2", "pfd2", "mfd2", "wing-ac-lights"]),
	DCBus.new(3, "DC-ESS", ["efis", "rtu1", "pfd1", "mfd1", "instrument-flood-lights", "transponder1", "vhf-nav1", "reversers"]),
	DCBus.new(4, "DC-Service", ["service-lights", "boarding-lights", "nav-lights", "beacon", "galley-lights"]),
	DCBus.new(5, "Battery", ["eicas-disp", "vhf-com1", "adg-deploy", "left-fuelpump", "gravity-xflow", "fuel-sov", "landing-lights[0]", "landing-lights[2]", "passenger-signs", "ohp-lights"]),
	DCBus.new(6, "Utility", []),
];


var acpc = ACPC.new(0, ["bus0","bus1","bus2","bus3","bus4"]);

acpc.addInput(IDG.new(acpc, "gen1", "/engines/engine[0]/N2").addSwitch("/controls/electric/engine[0]/generator"));
acpc.addInput(IDG.new(acpc, "gen2", "/engines/engine[1]/N2").addSwitch("/controls/electric/engine[1]/generator"));
acpc.addInput(APUGen.new(acpc, "apugen", "/engines/apu/rpm").addSwitch("/controls/electric/APU-generator"));
acpc.addInput(EnergyConv.new(acpc, "acext", 115).addSwitch("/controls/electric/ac-service-in-use"));
acpc.addInput(APUGen.new(acpc, "adg", "/systems/ram-air-turbine/rpm"));


foreach (b; ac_buses) {
	print("input: "~acpc.outputs_path~"bus["~b.index~"]");
	b.addInput(EnergyConv.new(b, "acpc-"~b.index, 115, acpc.outputs_path~"bus"~b.index, 0, 120));
	b.init();
}

acpc.init();


var dcpc = DCPC.new(0, ["bus0", "bus1", "bus2", "bus3", "bus4", "bus5"]);

dcpc.addInput(EnergyConv.new(dcpc, "tru1", 28, ac_buses[0].outputs_path~"tru1", 40));
dcpc.addInput(EnergyConv.new(dcpc, "tru2", 28, ac_buses[0].outputs_path~"tru2", 40));
dcpc.addInput(EnergyConv.new(dcpc, "esstru1", 28, ac_buses[0].outputs_path~"esstru1", 40));
dcpc.addInput(EnergyConv.new(dcpc, "esstru2", 28, ac_buses[0].outputs_path~"esstru2", 40));
dcpc.addInput(EnergyConv.new(dcpc, "apu-battery", 24).addSwitch("/controls/electric/battery-switch"));
dcpc.addInput(EnergyConv.new(dcpc, "main-battery", 24).addSwitch("/controls/electric/battery-switch"));

foreach (b; dc_buses) {
	b.addInput(EnergyConv.new(b, "dcpc-"~b.index, 28, dcpc.outputs_path~"bus"~b.index, 0,));
	b.init();
}

#dummy for compatibility
update_electrical = func {
	#acpc.update();
}
print("Electrical system done.");
