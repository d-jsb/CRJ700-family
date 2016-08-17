# EFIS for CRJ700 family 
# EICAS DC electrical page
# Author:  jsb
# Created: 03/2018
#

var EICASDCCanvas = {
    new: func(name, file) {
        var obj = { 
            parents: [EICASDCCanvas , EFISCanvas.new(name)],
            svg_keys: [
                "input4", "line51",
                "gEmerBus", "dc2toserv",
                "xtie", "esstie", "maintie", "utilconnect",
                "tCharger0", "tCharger1", "tBattOff0", "tBattOff1",
            ],
            prop_base: "systems/DC/",
            prop_names: [],
            inputN: [],
            outputN: [],            
        };
        foreach (var i; [0,1,2,3]) {
            append(obj.svg_keys, "input"~i);
            append(obj.svg_keys, "output"~i);
            append(obj.svg_keys, "volts"~i);
            append(obj.svg_keys, "load"~i);
        }
        foreach (var i; [1,2,3,4,5,6]) {
            append(obj.svg_keys, "bus"~i);
            append(obj.svg_keys, "line"~i);
        }
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        return obj;
    },
    
    #-- listeners for rare events --
    init: func() {
        setlistener("systems/DC/system/tru1-value", me._makeL_output(0), 1, 0);
        setlistener("systems/DC/system/tru2-value", me._makeL_output(1), 1, 0);
        setlistener("systems/DC/system/esstru1-value", me._makeL_output(2), 1, 0);
        setlistener("systems/DC/system/esstru1-value", me._makeL_output(3), 1, 0);
        setlistener("systems/AC/outputs/tru1", me._makeL_ACinput(0), 1, 0);
        setlistener("systems/AC/outputs/tru2", me._makeL_ACinput(1), 1, 0);
        setlistener("systems/AC/outputs/esstru1", me._makeL_ACinput(2), 1, 0);
        setlistener("systems/AC/outputs/esstru2", me._makeL_ACinput(3), 1, 0);
        foreach (var key; ["xtie", "esstie", "maintie", "utilconnect"])
            me[key].setColorFill(me.colors["green"]);
        foreach (var key; ["gEmerBus", "input4", "xtie","esstie","maintie"])
            me[key].hide();
        setlistener("systems/DC/system/esstie", me._makeListener_showHide("esstie"), 1,0);
        setlistener("systems/DC/system/maintie", me._makeListener_showHide(["maintie","utilconnect"]), 1,0);
        setlistener("systems/DC/system/xtie", me._makeListener_showHide("xtie"), 1,0);
        me["tBattOff0"].setColor(me.colors["amber"]);
        me["tBattOff1"].setColor(me.colors["amber"]);
        foreach (var i; [1,2,3,4,5]) {
            setlistener(me.prop_base~"outputs/bus"~i, me._makeL_bus(i), 1, 0);
        }
    },
    
    _makeL_bus : func(i) {
        return func(n) {
            if (num(n.getValue()) >= 18) {
                me["bus"~i].setColor(me.colors["green"]);
                me["line"~i].setColorFill(me.colors["green"]);
                if (i == 5) {
                    me["line"~i~"1"].setColorFill(me.colors["green"]);
                }
            } else {
                me["bus"~i].setColor(me.colors["amber"]);                
                me["line"~i].set("fill", "none");
                if (i == 5) {
                    me["line"~i~"1"].set("fill", "none");
                }
            }
        };
    },
    
    _makeL_ACinput: func(i) {
        var svgkey = "input"~i;
        return func(n) {
            var in = n.getValue();
            if (in > 40) {
                me[svgkey].setColorFill(me.colors["green"]);
            } else {
                me[svgkey].set("fill", "none");
            }
        };
    },
    
    _makeL_output: func(i) {
        return func(n) {
            var volts = n.getValue();
            me["volts"~i].setText(sprintf("%2d", volts));
            if (volts > 0) {
                me["output"~i].setColorFill(me.colors["green"]);
                me["load"~i].setText(sprintf("%2d", 20+i));
            } else {
                me["output"~i].set("fill", "none");
                me["load"~i].setText(sprintf("%2d", 0));
            }
        };
    },
};
