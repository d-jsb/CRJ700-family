## Electrical system for CRJ700 family ##
## Author:		Henning Stahlke
## Created:		May 2015

# The CRJ700 electrical system consists of an AC part and a DC part.
# Multiple redundant buses distribute the power to the electrical loads.
#
# AC (115V@400Hz) 
# Feed by APU generator, engine generators or ext. power while on ground.
# If all regular AC power fails, the ADG will generate AC power in flight
# while airspeed >= 135kt
#
# DC (24V - 28V)
# Feed by battery, external power and four TRUs (ac/dc converters)
# For simplification some parts are skipped.


## FG properties used
# controls/AC/system[n]/
# systems/AC/system[]/* 
# systems/AC/outputs/bus<n>		the outputs of the AC power center feeding AC bus<n>
# systems/AC/outputs/*	
#
# controls/DC/system[n]/
# systems/DC/system[]/* 
# systems/DC/outputs/bus<n>		the outputs of the DCC power center feeding DC bus<n>
# systems/DC/outputs/*	
#

# IDG (engine generator)
#
#
var IDG = {
	new: func (bus, name, input, discN) {
		var obj = {
			parents: [IDG, EnergyConv.new(bus, name, 115, input, 52.5, 60.0, 95).setOutputMin(108)],
			freq: 0,
			load: 0,
			discN: discN,
			disc: 0,
		};
		obj.freqN = props.globals.getNode(bus.system_path~name~"-freq", 1, "FLOAT");
		obj.freqN.setValue(0);
		obj.fakeinputN = props.globals.getNode(bus.system_path~name~"-fi", 1, "FLOAT");
		obj.fakeinputN.setValue(0);
		return obj;
	},

	init: func {
		call(EnergyConv.init,[], me);
		append(me.listeners, setlistener(me.discN, func(v) {me._disconnectL(v);}, 0 , 0));
		return me;
	},

	_disconnectL: func(v) {
		me.disc = v.getBoolValue();
		if (me.disc) {
			me.fakeinputN.setValue(me.inputN.getValue());
			var tmp = me.inputN;
			me.inputN = me.fakeinputN;
			me.fakeinputN = tmp;
			interpolate(me.inputN, 0, 10);
		}
		else {
			#"repair" (re-connect) IDG; in reality only possible on ground
			var tmp = me.inputN;
			me.inputN = me.fakeinputN;
			me.fakeinputN = tmp;
		}
	},
	
	_update_output: func {
		#var i = int(me.inputN.getValue());
		#if (me.running and int(me.input) == i) return;
		
		call(EnergyConv._update_output, [], me);
		#simulate frequency
		me.freq = 0;
		if (me.output and me.input > me.input_min) {			
			if (!me.input_lo) me.freq = 400;
			elsif (me.input < 57.5) 
				#me.freq = 375 * (me.input - me.input_min)/5;
				me.freq = 75 * int(me.input - me.input_min);
			elsif (me.input < me.input_lo) 
				#me.freq = 375 + 25 * (me.input - 57.5)/2.5;
				me.freq = 375 + int(10 * (me.input - 57.5));
			else me.freq = 400;
		}
		me.freqN.setValue(me.freq);
		return me;
	},
};

# APU generator
# needs ~5s from 0 - 115V
# needs ~10s from 0 - 400 Hz
var APUGen = {
	new: func (bus, name, input) {
		var obj = {
			parents: [APUGen, EnergyConv.new(bus, name, 115, input, 80, 90, 102).setOutputMin(108)],
			freq: 0,
			load: 0,
		};
		obj.freqN = props.globals.getNode(bus.system_path~name~"-freq", 1, "FLOAT");
		obj.freqN.setValue(0);
		return obj;
	},

	_update_output: func {
		#var i = int(me.inputN.getValue());
		#if (me.running and int(me.input) == i) return;
		call(EnergyConv._update_output, [], me);
		me.freq = 0;
		if (me.output and me.input > 80) {
			if (me.input < 90)
				me.freq = 37.5 * int(me.input - 80);
			elsif (me.input < 100)
				me.freq = 375 + int(2.5 * (me.input - 90));
			else me.freq = 400;
		}
		me.freqN.setValue(me.freq);
		return me;
	},
};

# ADG will work down to 135kt airspeed (according to FOM)
# 
var ADG = {
	new: func (bus, name="adg" , input="/instrumentation/airspeed-indicator/indicated-speed-kt") {
		var obj = {
			parents: [ADG, EnergyConv.new(bus, name, 115, input, 120, 135).setOutputMin(108)],
			freq: 0,
			rpm: 0,
		};
		obj.freqN = props.globals.getNode(bus.system_path~name~"-freq",1);
		obj.freqN.setValue(0);
		obj.rpmN = props.globals.getNode(bus.system_path~name~"-rpm",1);
		obj.rpmN.setValue(0);
		obj.positionN = props.globals.getNode(bus.system_path~name~"-position-norm",1);
		obj.positionN.setValue(0);
		return obj;
	},

	#will deploy on first "switch on"
	_switch_listener: func(v){
		me.switch = v.getValue();
		if (me.serviceableN.getBoolValue() and me.switch) 
			interpolate(me.positionN, 1, 2);
		me._update_output();
	},
		
	_update_output: func {
		#var i = int(me.inputN.getValue());
		#if (me.running and int(me.input) == i) return;
		#print("ADG.update: "~me.input~","~me.output);
		call(EnergyConv._update_output, [], me);
		me.freq = 0;
		if (me.input > 120) {
			if (me.input < 130) 
				me.freq = 37.5 * int(me.input - 120);
			elsif (me.input < 135) 
				me.freq = 375 + int(5 * (me.input - 130));
			else me.freq = 400;
		}
		me.freqN.setValue(me.freq);
		me.rpmN.setValue(me.freq*20);
		return me;
	},
};

#
# external AC should not be available if aircraft moves ;)
#
var ACext = {
	new: func (bus, name="acext", input=115) {
		var obj = {
			parents: [ACext, EnergyConv.new(bus, name, input)],
			freq: 0,
			gear_cnt: 0,
			parking_brake: 0,
			selected: 0,
		};
		obj.freqN = props.globals.getNode(bus.system_path~name~"-freq",1);
		obj.freqN.setValue(0);
		return obj;
	},

	init: func {
		call(EnergyConv.init,[], me);
		var gear = props.getNode("gear").getChildren("gear");
		me.gear_cnt = size(gear);
		#foreach(g; gear) {			
		#	append(me.listeners, setlistener(g.getChild("has-brake"), func(v) {me._gearL(v);}, 1 , 0));			
		#}
		append(me.listeners, setlistener(props.globals.getNode("controls/gear/brake-parking"), func(v) {me._gearL(v);}, 1 , 0));			
		append(me.listeners, setlistener(props.globals.getNode("controls/electric/ac-service-selected"), func(v) {me._selectedL(v);}, 1 , 0));			
		return me;
	},

	_selectedL: func(v){
			me.selected = v.getValue();
			setprop("controls/electric/ac-service-in-use", me.selected);
			me._update_output();
	},
	
	
	_gearL: func(v) {
		if (v.getBoolValue()) {
			if  (me.parking_brake < me.gear_cnt) me.parking_brake += 1;
		}
		else if (me.parking_brake > 0) me.parking_brake -= 1;
		if (me.parking_brake) {
			setprop("controls/electric/ac-service-avail", 1);
		}			
		else {
			setprop("controls/electric/ac-service-avail", 0);
		}
	},
		
	_update_output: func {
		#var i = int(me.inputN.getValue());
		#if (me.running and int(me.input) == i) return;
		call(EnergyConv._update_output, [], me);
		if (me.running) me.freq = 400;
			else me.freq = 0;
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
			acext_selected: 0,
			in_flight: 0,
		};
		print("AC power center "~obj.parents[1].system_path);
		return obj;		
	},
	
	readProps: func {		
		me.output = me.outputN.getValue();
		me.serviceable = me.serviceableN.getValue();
		me.acext_selected = getprop("controls/electric/ac-service-selected");
		me.in_flight = (getprop("velocities/airspeed-kt") > 120 );
	},
		
	#
	# ACPC logic
	#
	# On ground ext. AC can be used. Ext. AC will automatically disconnect on 
	# any on-board AC generator comming online.
	# The APU generator will auto disconnect when 2nd IDG comes online
	#
	update: func {
		me.readProps();
		if (me.serviceable) {
			var g1 = me.inputs[0].getValue();
			var g2 = me.inputs[1].getValue();
			var apu = me.inputs[2].getValue();
			var ep = me.inputs[3].getValue();
			var adg = me.inputs[4].getValue();
			
			#print("ACPC g1:"~g1~", g2:"~g2~", a:"~apu~", e:"~ep~", adg:"~adg);
			if (me.acext_selected) {
				if (apu > 90 or g1 or g2) {
					setprop("controls/electric/ac-service-in-use", 0);
					ep = 0;
				}
				else setprop("controls/electric/ac-service-in-use", 1);
			}
			else ep = 0;

			var v = 0;
			#ADG			
			me.outputs[4].setValue(adg);
			
			#use ext. AC until APU avail
			if (!apu) apu = ep;
			if (g1 < apu) g1 = apu;
			if (g2 < apu) g2 = apu;
			if (g1 < g2) g1 = g2;
			if (g2 < g1) g2 = g1;

			#AC1
			me.outputs[0].setValue(g1);
			#AC2
			me.outputs[1].setValue(g2);
			
			#AC_ESS (prio: adg,ac1,ac2)
			v = (g1 >= g2) ? g1 : g2;
			v = (adg > v) ? adg : v;
			me.outputs[2].setValue(v);			

			#AC_SERVICE
			v = (g2 >= ep) ? g2 : ep;
			me.outputs[3].setValue(v);
			if (!me.inputs[0].isRunning() and 
				!me.inputs[1].isRunning() and 
				!me.inputs[2].isRunning() and 
				!me.inputs[4].isRunning() and 
				me.in_flight)
			{
				print("ACPC: !! ADG auto deploy !!");
				setprop("controls/electric/ADG", 1);
				setprop("controls/hydraulic/system[2]/pump-b", 1);
			}
		}
		return me;
	},
};

# DCPC (DC power center)
# connection logic from DC sources to DC buses

var DCPC = {
	new: func (sysid, outputs) {
		obj = { parents : [DCPC, EnergyBus.new("DC", sysid, "dcpc", outputs)],
			buses: [],
			dcservice: 0,
		};
		print("DC power center "~obj.parents[1].system_path);
		return obj;		
	},
	
	readProps: func {		
		me.output = me.outputN.getValue();
		me.serviceable = me.serviceableN.getValue();
		me.dcservice = getprop("controls/electric/dc-service-switch");
	},
		
	update: func {
		me.readProps();
		if (me.serviceable) {
			var t1 = me.inputs[0].getValue();
			var t2 = me.inputs[1].getValue();
			var et1 = me.inputs[2].getValue();
			var et2 = me.inputs[3].getValue();
			var apubatt = me.inputs[4].getValue();
			var mainbatt = me.inputs[5].getValue();
			var batt = (apubatt > mainbatt) ? apubatt : mainbatt;
			
			#print("DCPC "~t1~", "~t2~", "~et1~", "~et2~", "~batt);
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
			if (me.dcservice) me.outputs[3].setValue(apubatt);
			else me.outputs[3].setValue(v);

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
	ACBus.new(1, "AC1", ["aoa-heater-r", "egpws", "flaps-a-1",
		["hyd-pump2B", "controls/hydraulic/system[1]/pump-b"],
		["hyd-pump3B-1", "controls/hydraulic/system[2]/pump-b"],
		"pitch-trim1", "pitot-heater-r", "tru1", 
		]),
	ACBus.new(2, "AC2",	["copilot-panel-int-lights", "esstru2", "flaps-b-1", 
		["hyd-pump1B", "controls/hydraulic/system[0]/pump-b"], 
		["hyd-pump3A", "controls/hydraulic/system[2]/pump-a"],
		"pitch-trim2-1", "tru2", 
		]),
	ACBus.new(3, "AC-ESS", ["aoa-heater-l", "cabin-lights", 
		"center-panel-int-lights", "esstru1", "ignition-a", "ohp-int-lights", 
		"pilot-panel-int-lights", "pitot-heater-l", "tcas", "xflow-pump", 
		]),
	ACBus.new(4, "AC-Service", ["apu-charger", "cabin-lights",
		["logo-lights", "controls/lighting/logo-lights"], 
		]),
	ACBus.new(5, "ADG",["flaps-a-2", "flaps-b-2", "hyd-pump3B-2", "pitch-trim2-2"]),
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
	DCBus.new(2, "DC2", ["afcs-r", "clock2", "fuel-pump-right", "mfd2", "pfd2",
		"rtu2",	"vhf-com2", "vhf-nav2",
		["wing-ac-lights", "sim/model/lights/strobe/state"],
		]),
	DCBus.new(3, "DC-ESS", ["efis", "instrument-flood-lights", "mfd1", 
		"pfd1", "reversers", "rtu1", "transponder1", "vhf-nav1", "wiper-right",
		]),
	DCBus.new(4, "DC-Service", ["boarding-lights", "galley-lights",
		["beacon", "sim/model/lights/beacon/state"],
		["nav-lights", "controls/lighting/nav-lights"],
		"service-lights", 
		]),
	DCBus.new(5, "Battery", ["adg-deploy", "afcs-l", "clock1", "eicas-disp", "fuel-sov",
		"fuel-pump-left",
		"gravity-xflow", 
		["landing-lights[0]", "controls/lighting/landing-lights[0]"],
		["landing-lights[2]", "controls/lighting/landing-lights[2]"],
		["ohp-lights", "controls/lighting/ind-lts-norm"],
		"passenger-signs", 
		"standby-instrument",
		"vhf-com1", 
		]),
	DCBus.new(6, "Utility", []),
];

#
# the power centers are the switch logic between serveral inputs and outputs
#
var acpc = ACPC.new(0, ["bus1", "bus2", "bus3", "bus4", "bus5"]);
var dcpc = DCPC.new(0, ["bus1", "bus2", "bus3", "bus4", "bus5", "bus6"]);
var generators = [
	IDG.new(acpc, "gen1", "/engines/engine[0]/rpm2", "controls/electric/idg1-disc").addSwitch("/controls/electric/engine[0]/generator"),
	IDG.new(acpc, "gen2", "/engines/engine[1]/rpm2", "controls/electric/idg2-disc").addSwitch("/controls/electric/engine[1]/generator"),
	APUGen.new(acpc, "apugen", "/engines/engine[2]/rpm").addSwitch("/controls/electric/APU-generator"),
];

acpc.addInput(generators[0]);
acpc.addInput(generators[1]);
acpc.addInput(generators[2]);
acpc.addInput(ACext.new(acpc, "acext", 115).addSwitch("/controls/electric/ac-service-avail"));
acpc.addInput(ADG.new(acpc).addSwitch("/controls/electric/ADG"));


var flapsA = ACBus.new(10,"flaps-a", ["flaps-a"]);
flapsA.addInput(EnergyConv.new(flapsA, "flaps-a1", 115, "/systems/AC/outputs/flaps-a-1", 0, 115));
flapsA.addInput(EnergyConv.new(flapsA, "flaps-a2", 115, "/systems/AC/outputs/flaps-a-2", 0, 115));
flapsA.init();
var flapsB = ACBus.new(11,"flaps-b", ["flaps-b"]);
flapsB.addInput(EnergyConv.new(flapsB, "flaps-b1", 115, "/systems/AC/outputs/flaps-b-1", 0, 115));
flapsB.addInput(EnergyConv.new(flapsB, "flaps-b2", 115, "/systems/AC/outputs/flaps-b-2", 0, 115));
flapsB.init();
var h3b = ACBus.new(12,"hyd-3B", ["hyd-pump3B"]);
h3b.addInput(EnergyConv.new(h3b, "hyd-3B1", 115, "/systems/AC/outputs/hyd-pump3B-1", 0, 115));
h3b.addInput(EnergyConv.new(h3b, "hyd-3B2", 115, "/systems/AC/outputs/hyd-pump3B-2", 0, 115));
h3b.init();
var pt2 = ACBus.new(13,"pitch-trim2", ["pitch-trim2"]);
pt2.addInput(EnergyConv.new(pt2, "pt21", 115, "/systems/AC/outputs/pitch-trim2-1", 0, 115));
pt2.addInput(EnergyConv.new(pt2, "pt22", 115, "/systems/AC/outputs/pitch-trim2-2", 0, 115));
pt2.init();

dcpc.addInput(EnergyConv.new(dcpc, "tru1", 28, ac_buses[0].outputs_path~"tru1", 40));
dcpc.addInput(EnergyConv.new(dcpc, "tru2", 28, ac_buses[0].outputs_path~"tru2", 40));
dcpc.addInput(EnergyConv.new(dcpc, "esstru1", 28, ac_buses[0].outputs_path~"esstru1", 40));
dcpc.addInput(EnergyConv.new(dcpc, "esstru2", 28, ac_buses[0].outputs_path~"esstru2", 40));
dcpc.addInput(EnergyConv.new(dcpc, "apu-battery", 24).addSwitch("/controls/electric/battery-switch"));
dcpc.addInput(EnergyConv.new(dcpc, "main-battery", 24).addSwitch("/controls/electric/battery-switch"));

#
# after acpc/dcpc init connect buses to the pc outlets
#
foreach (b; ac_buses) {
	#print("input: "~acpc.outputs_path~"bus["~b.index~"]");
	b.addInput(EnergyConv.new(b, "acpc-"~b.index, 115, acpc.outputs_path~"bus"~b.index, 0, 115));
	#b.addInput(props.globals.getNode(acpc.outputs_path~"bus"~b.index));
	b.init();
}


foreach (b; dc_buses) {
	b.addInput(EnergyConv.new(b, "dcpc-"~b.index, 28, dcpc.outputs_path~"bus"~b.index, 0, 28));
	b.init();
}

#init power controllers (setup listeners)
acpc.init();
dcpc.init();


var mkviii = EnergyBus.new("electrical", 0, "mk-viii-compat", ["mk-viii"]);
mkviii.addInput(EnergyConv.new(mkviii,"ac-in", 28, "systems/AC/outputs/egpws", 40));
mkviii.init();


# dummy for compatibility, called from update loop
# should not be needed if all listeners work correctly
update_electrical = func {
	acpc.update();
}
print("Electrical system done.");
