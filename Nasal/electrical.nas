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
			parents: [IDG, EnergyConv.new(bus, name, 115, input, 52.5, 57, 95).setOutputMin(108)],
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
			parents: [APUGen, EnergyConv.new(bus, name, 115, input, 60, 99, 102).setOutputMin(108)],
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
		print("AC power center "~obj.parents[1].system_path);
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
			
			print("ACPC g1:"~g1~", g2:"~g2~", a:"~apu~", e:"~ep);
			var v = 0;
			
			#use ext. AC until APU avail
			if (apu < ep) apu = ep;
			#AC1
			if (g1 < apu) g1 = apu;
			me.outputs[0].setValue(g1);
			
			#AC2
			if (g2 < apu) g2 = apu;
			me.outputs[1].setValue(g2);
			
			#AC_ESS (prio: adg,ac1,ac2)
			v = (g1 >= g2) ? g1 : g2;
			v = (adg > v) ? adg : v;
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
		print("DC power center "~obj.parents[1].system_path);
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
			var ab = me.inputs[4].getValue();
			var mb = me.inputs[5].getValue();
			var batt = (ab > mb) ? ab : mb;
			
			print("DCPC "~t1~", "~t2~", "~et1~", "~et2~", "~batt);
			var v = 0;
			
			#Battery
			me.outputs[4].setValue(batt);

			#DC1
			v = (t1 >= batt) ? t1 : batt;
			me.outputs[0].setValue(v);
			
			#DC2
			v = (t2 >= batt) ? t2 : batt;
			me.outputs[1].setValue(v);
	
			#DC_SERVICE
			me.outputs[3].setValue(v);

			#DC_ESS
			v = (et1 >= batt) ? et1 : batt;
			me.outputs[2].setValue(v);
		}
		return me;
	},
};


print("Creating electrical system ...");

# Define electrical buses and their outputs. Output will be set to bus voltage.
# Output can be defined as ["output-name", "controls/path/to/switch"] or just 
# as "output-name" (always on).

var ac_buses = [ 
	ACBus.new(1, "AC1", ["aoa-heater-r", "egpws", "flaps-a", "hyd-pump2B", 
		"hyd-pump3B", "pitch-trim-1", "pitot-heater-r", "tru1", 
		]),
	ACBus.new(2, "AC2",	["copilot-panel-int-lights", "esstru2", "flaps-b", 
		"hyd-pump1B", "hyd-pump3A", "pitch-trim-2", "tru2", 
		]),
	ACBus.new(3, "AC-ESS", ["aoa-heater-l", "cabin-lights", 
		"center-panel-int-lights", "esstru1", "ignition-a", "ohp-int-lights", 
		"pilot-panel-int-lights", "pitot-heater-l", "tcas", "xflow-pump", 
		]),
	ACBus.new(4, "AC-Service", ["apu-charger", "cabin-lights",
		["logo-lights", "controls/lighting/logo-lights"], 
		]),
	ACBus.new(5, "ADG",["flaps-a", "flaps-b", "hyd-pump3B", "pitch-trim-2"]),
];

var dc_buses = [
	DCBus.new(1, "DC1", ["dme1", "eicas-disp", "gps1", 
		["landing-lights[1]", "controls/lighting/landing-lights[1]"],
		"nwsteering", "passenger-door", "radio-altimeter1", 
		["rear-ac-light", "sim/model/lights/strobe/state"],
		["taxi-lights", "controls/lighting/taxi-lights"],
		["wing-lights", "controls/lighting/wing-lights"],
		"wiper-left", 
		"wradar",
		]),
	DCBus.new(2, "DC2", ["clock2", "mfd2", "pfd2", "rtu2", "vhf2",
		["wing-ac-lights", "sim/model/lights/strobe/state"],
		]),
	DCBus.new(3, "DC-ESS", ["efis", "instrument-flood-lights", "mfd1", 
		"pfd1", "reversers", "rtu1", "transponder1", "vhf-nav1", 
		]),
	DCBus.new(4, "DC-Service", ["boarding-lights", "galley-lights",
		["beacon", "sim/model/lights/beacon/state"],
		["nav-lights", "controls/lighting/nav-lights"],
		"service-lights", 
		]),
	DCBus.new(5, "Battery", ["adg-deploy", "clock1", "eicas-disp", "fuel-sov",
		"gravity-xflow", 
		["landing-lights[0]", "controls/lighting/landing-lights[0]"],
		["landing-lights[2]", "controls/lighting/landing-lights[2]"],
		"left-fuelpump", 
		["ohp-lights", "controls/lighting/ind-lts-norm"],
		"passenger-signs", 
		"standby-instrument",
		"vhf-com1", 
		]),
	DCBus.new(6, "Utility", []),
];


var acpc = ACPC.new(0, ["bus1", "bus2", "bus3", "bus4", "bus5"]);
var dcpc = DCPC.new(0, ["bus1", "bus2", "bus3", "bus4", "bus5", "bus6"]);

acpc.addInput(IDG.new(acpc, "gen1", "/engines/engine[0]/rpm2").addSwitch("/controls/electric/engine[0]/generator"));
acpc.addInput(IDG.new(acpc, "gen2", "/engines/engine[1]/rpm2").addSwitch("/controls/electric/engine[1]/generator"));
acpc.addInput(APUGen.new(acpc, "apugen", "/engines/apu/rpm").addSwitch("/controls/electric/APU-generator"));
acpc.addInput(EnergyConv.new(acpc, "acext", 115).addSwitch("/controls/electric/ac-service-in-use"));
acpc.addInput(APUGen.new(acpc, "adg", "/systems/ram-air-turbine/rpm"));

dcpc.addInput(EnergyConv.new(dcpc, "tru1", 28, ac_buses[0].outputs_path~"tru1", 40));
dcpc.addInput(EnergyConv.new(dcpc, "tru2", 28, ac_buses[0].outputs_path~"tru2", 40));
dcpc.addInput(EnergyConv.new(dcpc, "esstru1", 28, ac_buses[0].outputs_path~"esstru1", 40));
dcpc.addInput(EnergyConv.new(dcpc, "esstru2", 28, ac_buses[0].outputs_path~"esstru2", 40));
dcpc.addInput(EnergyConv.new(dcpc, "apu-battery", 24).addSwitch("/controls/electric/battery-switch"));
dcpc.addInput(EnergyConv.new(dcpc, "main-battery", 24).addSwitch("/controls/electric/battery-switch"));

foreach (b; ac_buses) {
	print("input: "~acpc.outputs_path~"bus["~b.index~"]");
	b.addInput(EnergyConv.new(b, "acpc-"~b.index, 115, acpc.outputs_path~"bus"~b.index, 0, 115));
	b.init();
}


foreach (b; dc_buses) {
	b.addInput(EnergyConv.new(b, "dcpc-"~b.index, 28, dcpc.outputs_path~"bus"~b.index, 0, 28));
	b.init();
}

#init power controllers (setup listeners)
acpc.init();
dcpc.init();


#dummy for compatibility
update_electrical = func {
	#acpc.update();
}
print("Electrical system done.");
