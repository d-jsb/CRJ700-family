# Fuel handling for the CRJ700 family YASim FDM. Note that other FDMs (e.g. JSBSim)
# handle fuel within the FDM itself.
#
# Properties under /consumables/fuel/tank[n]:
# + level-lbs       - Current fuel load.  Can be set by user code.
# + selected        - boolean indicating tank selection.
# + capacity-gal_us - Tank capacity
#
# Properties under /engines/engine[n]:
# + fuel-consumed-lbs - Output from the FDM, zeroed by this script
# + out-of-fuel       - boolean, set by this code.


var UPDATE_PERIOD = 0.5;

var tanks = [];
var engines = [];
var fuel_freeze = nil;
var freeze_fuel_listener = nil;
var initialized = 0;

# fuel ejector
# rate in gal_us/second, valve switch
var fuel_ejector = {
	new: func(rate, switch, from, to) {
		var obj = {parents : [fuel_ejector], 
			rate: rate, 
			from: from, 
			to: to,
			switch: switch,
			from_unusable: 0,
			to_cap: 0,
		};		
		return obj;
	},
	
	init: func() {
		me.from_unusable = getprop("consumables/fuel/tank["~me.from~"]/unusable-gal_us");
		me.to_cap = getprop("consumables/fuel/tank["~me.to~"]/capacity-gal_us");
	},
	
	update: func() {		
		if (getprop(me.switch)) {
			var amount = me.rate * UPDATE_PERIOD;
			var from_level = getprop("consumables/fuel/tank["~me.from~"]/level-gal_us");
			var to_level = getprop("consumables/fuel/tank["~me.to~"]/level-gal_us");
			if (from_level - me.from_unusable > amount and me.to_cap - to_level > amount) {
				setprop("consumables/fuel/tank["~me.from~"]/level-gal_us", from_level - amount);
				setprop("consumables/fuel/tank["~me.to~"]/level-gal_us", to_level + amount);
			}
		}
	},
};

var update = func {
	if (fuel_freeze)
		return;

	var consume = func(t,e) {
		var consumed_fuel = e.getNode("fuel-consumed-lbs").getValue();
		e.getNode("fuel-consumed-lbs").setDoubleValue(0);
		#yasim uses "out-of-fuel" to turn the engine on/off; "running" is always re-set to true (by yasim?!)
		# "running-nasal" is set by engine.nas
		if (e.getNode("running-nasal").getBoolValue()) {
			t.getNode("level-lbs").setDoubleValue(t.getNode("level-lbs").getValue() - consumed_fuel);
		}
		var empty = t.getNode("empty");
		if (empty == nil)
			empty = (t.getNode("level-gal_us").getValue() <= t.getNode("unusable-gal_us").getValue());
		else
			empty = empty.getBoolValue();
		e.getNode("out-of-fuel").setBoolValue(empty);	
	};

	consume(tanks[0], engines[0]);
	consume(tanks[1], engines[1]);
}


var xfer_left = fuel_ejector.new(0.2, "/consumables/fuel/tank[0]/xfer-valve", 2, 0);
var xfer_right = fuel_ejector.new(0.2, "/consumables/fuel/tank[1]/xfer-valve", 2, 1);


var loop = func {
		update();
		xfer_left.update();
		xfer_right.update();
		settimer(loop, UPDATE_PERIOD);
}

_setlistener("/sim/signals/fdm-initialized", func {
	# Fuel sub-system is only used by YASim. Other FDMs (e.g. JSBSim)
	# handle fuel themselves.
	if (getprop("/sim/flight-model") != "yasim") { return; }
	xfer_left.init();
	xfer_right.init();
	loop();
});


