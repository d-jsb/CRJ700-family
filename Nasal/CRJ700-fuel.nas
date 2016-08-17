# Fuel handling for the CRJ700 family YASim FDM. Note that other FDMs (e.g. JSBSim)
# handle fuel within the FDM itself. 
#
#
#    !!! This file overloads the FGDATA/Nasal/fuel.nas implementation !!!
#
#
# Properties under /consumables/fuel/tank[n]:
# + level-lbs       - Current fuel load.  Can be set by user code.
# + selected        - boolean indicating tank selection.
# + capacity-gal_us - Tank capacity
#
# Properties under /engines/engine[n]:
# + fuel-consumed-lbs - Output from the FDM, zeroed by this script
# + out-of-fuel       - boolean, set by this code.


var UPDATE_PERIOD = 0.3;

var tanks = [];
var engines = [];
var fuel_freeze = nil;
var freeze_fuel_listener = nil;
var initialized = 0;

var fuel_consumers = [];

# fuel ejector
# rate in gal_us/second, valve open prop, powered, from tank index, to tank index
var fuel_transfer = {
    new: func(rate, switch, powered, from, to) {
        var obj = {
            parents : [me],
            rate: rate,
            from: from,
            to: to,
            switch: switch,
            powered : powered,
            from_unusable: 0,
            to_cap: 0,
        };
        return obj;
    },

    init: func() {
        me.from_unusable = getprop("consumables/fuel/tank["~me.from~"]/unusable-gal_us");
        me.to_cap = getprop("consumables/fuel/tank["~me.to~"]/capacity-gal_us");
        me.from_levelN = props.getNode("consumables/fuel/tank["~me.from~"]/level-gal_us",1);
        me.to_levelN = props.getNode("consumables/fuel/tank["~me.to~"]/level-gal_us",1);
    },

    update: func() {
        var switch = getprop(me.switch);
        if (switch and getprop(me.powered)) {
            #print(me.switch~" "~switch);
            var amount = me.rate * UPDATE_PERIOD * switch;
            var from_level = me.from_levelN.getValue();
            var to_level = me.to_levelN.getValue();
            if (from_level - me.from_unusable > amount and me.to_cap - to_level > amount) {
                me.from_levelN.setValue(from_level - amount);
                me.to_levelN.setValue(to_level + amount);
            }
        }
    },
};

var fuel_consumer = {
    new: func(tank, engine, pressure) {
        var obj = {
            parents: [me],
            tankN: tank,
            levelN: tank.getNode("level-lbs"),
            emptyN: tank.getNode("empty",1),
            consumedN: engine.getNode("fuel-consumed-lbs"),
            runningN: engine.getNode("running-nasal"),
            oofN: engine.getNode("out-of-fuel-nasal",1),
            pressureN: props.getNode(pressure,1),
        };
        obj.unusable_lbs = tank.getNode("unusable-gal_us").getValue() * 6; # density in lbs/gal
        return obj;
    },
    
    consume: func() {
        var consumed_fuel = me.consumedN.getValue();
        me.consumedN.setDoubleValue(0);
        #yasim uses "out-of-fuel" to turn the engine on/off; "running" is always re-set to true (by yasim?!)
        # "running-nasal" is set by engine.nas
        if (me.runningN.getBoolValue()) {
            me.levelN.setDoubleValue(me.levelN.getValue() - consumed_fuel);
        }
        return me.oofN.setBoolValue(me.emptyN.getBoolValue() or !me.pressureN.getBoolValue());
    },
};

var fuel_update = func {
    xfer_left.update();
    xfer_right.update();
    xflow_pump.update();
    
    if (getprop("/sim/flight-model") != "yasim" or fuel_freeze) {
        return;
    }
    foreach (var fc; fuel_consumers) {
        fc.consume();
    }
}

var fuel_update_timer = maketimer(UPDATE_PERIOD, fuel_update);
fuel_update_timer.simulatedTime = 1;

#xfer valves control fuel transfer from center tank to wing tanks (this is not the wing tanks xflow; left-right)
var xfer_left = fuel_transfer.new(0.2, "/consumables/fuel/tank[0]/xfer-valve", "systems/fuel/circuit[0]/powered", 2, 0);
var xfer_right = fuel_transfer.new(0.2, "/consumables/fuel/tank[1]/xfer-valve", "systems/fuel/circuit[1]/powered", 2, 1);
#powered xfer pump (left-right); alternative to gravity xflow
var xflow_pump = fuel_transfer.new(0.2, "systems/fuel/xflow-pump/running", "systems/AC/outputs/xflow-pump", 0, 1);

# disable FGDATA fuel system
var loop = func {};

# init fuel system after FDM
_setlistener("/sim/signals/fdm-initialized", func {
    xfer_left.init();
    xfer_right.init();
    xflow_pump.init();
    engines = props.globals.getNode("engines", 1).getChildren("engine");
    foreach (var e; engines) {
        e.getNode("fuel-consumed-lbs", 1).setDoubleValue(0);
        e.getNode("out-of-fuel", 1).setBoolValue(0);
    }
    foreach (var t; props.globals.getNode("/consumables/fuel", 1).getChildren("tank")) {
        if (!t.getAttribute("children"))
            continue;           # skip native_fdm.cxx generated zombie tanks
        append(tanks, t);
        #t.initNode("selected", 1, "BOOL");
    }    
    
    append(fuel_consumers, fuel_consumer.new(tanks[0], engines[0], "systems/fuel/circuit[0]/powered"));
    append(fuel_consumers, fuel_consumer.new(tanks[1], engines[1], "systems/fuel/circuit[1]/powered"));
    append(fuel_consumers, fuel_consumer.new(tanks[0], engines[2], "systems/fuel/boost-pump[2]/running"));
    fuel_update_timer.start();
});


