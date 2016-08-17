# EFIS for CRJ700 family 
# EICAS primary page
# Author:  jsb
# Created: 03/2018
#

var EICASFuelCanvas = {
    new: func(name, file) {
        var obj = { 
            parents: [EICASFuelCanvas , EFISCanvas.new(name)],
            svg_keys: [
                "fuelTotal", "fuelUsed",
                "fuelQty0", "fuelQty1", "fuelQty2",
                "gravXflow", "gxflowline0", "gxflowline1", "gxflowline2",
                "xflowPump", "xfpumptxt", "xfpumparrow", "xflowline0", "xflowline1", "manualXflow",
                "scavengeEjector0", "scavengeEjector1", 
                "xferSOV0", "xferEjector0", "xferline01", "xferline02", "xferline03",
                "xferSOV1", "xferEjector1", "xferline11", "xferline12", "xferline13",
                "mainEjector0", "mainEjector1",
                "pump0", "pump1", "pump2",
                "sov0", "sov1", "sov2",
                "sov0line", "sov1line", "sov2line",
                "line23", "line26", "line27",
                "filter0", "filter1",
                "lopress0", "lopress1",
                "eng0", "eng1", "eng2",
            ],
            unusable: [],
            tankLevelLbsN: [],
            engRunning: [0,0,0],
        };
        foreach (var i; [0,1]) {
            foreach (var n; [0,1,2,3,4,5,6,7])
                append(obj.svg_keys, "line"~i~n);
        }
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        obj.addUpdateFunction(obj.update, 0.8);
        return obj;
    },

    #-- listeners for rare events --
    
    init: func() {
        var fdm = getprop("/sim/flight-model");
        foreach (var i; [0,1,2]) {
            append(me.unusable, getprop("consumables/fuel/tank["~i~"]/unusable-gal_us"));
            append(me.tankLevelLbsN, props.getNode("consumables/fuel/tank["~i~"]/level-lbs", 1));
            me._makeL_pump(i);
            me._makeL_sov(i);
            if (fdm == "yasim")
                setlistener("engines/engine["~i~"]/running-nasal", me._makeL_eng(i), 1, 0);
            else setlistener("engines/engine["~i~"]/running", me._makeL_eng(i), 1, 0);
            me["line"~i~"6"].setColorFill(me.colors["green"]);
        }
        foreach (var i; [0,1]) {
            me._makeL_addXferValve(i);
            me._makeL_pressure(i);
            me["lopress"~i].setColor(me.colors["amber"]);
            me["line"~i~"1"].setColorFill(me.colors["green"]);
        }
        me.totalFuelLbsN = props.getNode("consumables/fuel/total-fuel-lbs", 1);
        me.fuelImbalanceN = props.getNode("systems/fuel/imbalance", 1);
        me._makeL_pressure(2);
        setlistener("controls/fuel/xflow-manual", me._makeListener_showHide(["manualXflow"]), 1, 0);
        setlistener("controls/fuel/gravity-xflow", me._makeL_gxflow(), 1, 0);
        setlistener("systems/fuel/xflow-pump/running", me._makeL_xferPumpRun(), 1, 0);
        setlistener("systems/fuel/xflow-pump/inop", me._makeListener_setColor("xflowPump", me.colors["amber"], me.colors["white"]), 1, 0);
        
    },
    
     _makeL_eng: func(i) { 
        return func(n) {
                me.engRunning[i] = n.getValue();
                if (me.engRunning[i]) me["eng"~i].setColor(me.colors["blue"]);
                else me["eng"~i].setColor(me.colors["white"]);
        };
    },
       
    _makeL_gxflow: func() {
        return func(n) {
            var serviceable = getprop("systems/fuel/gravity-xflow/serviceable");
            if (serviceable) {
                if (n.getValue()) {
                    me["gravXflow"].setRotation(90*D2R);
                    me["gxflowline0"].setColorFill(me.colors["green"]);
                    me["gxflowline1"].setColorFill(me.colors["green"]);
                    me["gxflowline2"].setColorFill(me.colors["green"]);
                }
                else {
                    me["gravXflow"].setRotation(0);
                    me["gxflowline0"].set("fill", "none");
                    me["gxflowline1"].set("fill", "none");
                    me["gxflowline2"].set("fill", "none");
                }
            }
            else {
                me["gravXflow"].setRotation(45*D2R);
                me["gxflowline0"].set("fill", "none");
                me["gxflowline1"].set("fill", "none");
                me["gxflowline2"].set("fill", "none");
            }
        };
    },
    
    _makeL_xferPumpRun: func() {
        return func(n) {
            var state = n.getValue();
            if (state != 0) {
                me["xfpumparrow"].show();
                me["xfpumptxt"].hide();
                if (state < 0) me["xfpumparrow"].setRotation(180*D2R);
                else me["xfpumparrow"].setRotation(0);
            } else {
                me["xfpumparrow"].hide();
                me["xfpumptxt"].show();
            }
        };
    },
        
    _makeL_addXferValve: func(i) {
        setlistener("consumables/fuel/tank["~i~"]/xfer-valve", func(n) {
            if (n.getValue()) {
                me["xferSOV"~i].setRotation(90*D2R);
                me["xferEjector"~i].setColor(me.colors["green"]);
                me["xferline"~i~"1"].setColorFill(me.colors["green"]);
                me["xferline"~i~"2"].setColorFill(me.colors["green"]);
                me["xferline"~i~"3"].setColorFill(me.colors["green"]);
            }
            else {
                me["xferSOV"~i].setRotation(0);
                me["xferEjector"~i].setColor(me.colors["white"]);
                me["xferline"~i~"1"].set("fill", "none");
                me["xferline"~i~"2"].set("fill", "none");
                me["xferline"~i~"3"].set("fill", "none");
            }
        }, 1, 0);
    },
    
    _makeL_pump: func(i) {
        setlistener("systems/fuel/boost-pump["~i~"]/running", func(n) {
            if (n.getValue()) {
                me["pump"~i].setColor(me.colors["green"]);
                me["line"~i~"7"].setColorFill(me.colors["green"]);
            }
            else {
                me["pump"~i].setColor(me.colors["white"]);
                me["line"~i~"7"].set("fill", "none");
            }
        }, 1, 0);
        setlistener("systems/fuel/boost-pump["~i~"]/inop", func(n) {
            if (n.getValue()) {
                me["pump"~i].setColor(me.colors["amber"]);
                me["line"~i~"7"].setColorFill(me.colors["amber"]);
            }
            else {
                me["pump"~i].setColor(me.colors["white"]);
                me["line"~i~"7"].set("fill", "none");
            }
        }, 1, 0);
    },

    _makeL_sov: func(i) {
        if (i == 2) {
            var powered = props.globals.getNode("systems/fuel/boost-pump[2]/running");
        }
        else {
            var powered = props.globals.getNode("systems/fuel/circuit["~i~"]/powered");
        }
        setlistener("engines/engine["~i~"]/sov", func(n) {
            if (n.getValue()) {
                me["sov"~i].setRotation(90*D2R);
                if (i < 2 and powered.getValue()) {
                    me["sov"~i~"line"].setColorFill(me.colors["green"]);
                }
                if (i == 2 and powered.getValue()) {
                    me["sov2line"].setColorFill(me.colors["green"]);
                }
            }
            else {
                me["sov"~i].setRotation(0);
                me["sov"~i~"line"].set("fill", "none");
            }
            me.colorizeFuelLines(i, powered)
        }, 1, 0);
    },
    
    #i = engine, n = fuel pressure 
    colorizeFuelLines: func(i, n) {
        if (i == 0 or i == 1) {
            if (n.getValue()) {
                me["lopress"~i].hide();
                me["scavengeEjector"~i].setColor(me.colors["green"]);
                me["mainEjector"~i].setColor(me.colors["green"]);
                me["line"~i~"2"].setColorFill(me.colors["green"]);
                if (getprop("engines/engine["~i~"]/sov")) {
                    foreach (var n; [3,4,5]) {
                        me["line"~i~n].setColorFill(me.colors["green"]);
                    }
                }
                else {
                    foreach (var n; [3,4,5]) {
                        me["line"~i~n].set("fill", "none");
                    }
                }
            }
            else {
                me["lopress"~i].show();
                me["scavengeEjector"~i].setColor(me.colors["white"]);
                me["mainEjector"~i].setColor(me.colors["white"]);
                foreach (var n; [0,2,3,4])
                    me["line"~i~n].set("fill", "none");
                me["line"~i~"5"].setColorFill(me.colors["amber"]);
            }
        }
        elsif (i == 2) {
            if (n.getValue()) {
                if (getprop("engines/engine[2]/sov")) {
                    me["line23"].setColorFill(me.colors["green"]);
                }
                else {
                    me["line23"].set("fill", "none");
                }
                me["line27"].setColorFill(me.colors["green"]);
            }
            else {
                me["line23"].set("fill", "none");
                me["line27"].set("fill", "none");
            }
        }
    },
    
    #colorize fuel lines 
    _makeL_pressure: func(i) {
        #engines
        if (i == 0 or i == 1) {
            setlistener("systems/fuel/circuit["~i~"]/powered", func(n) {
                me.colorizeFuelLines(i, n);
            }, 1, 0);
        }
        #APU
        elsif (i == 2) {
            setlistener("systems/fuel/boost-pump[2]/running", func(n) {
                me.colorizeFuelLines(2,n);
            }, 1, 0);
        }
    },

    update: func() {
        var fuelQty = [        
            int(me.tankLevelLbsN[0].getValue() * LB2KG / 5) * 5,            
            int(me.tankLevelLbsN[1].getValue() * LB2KG / 5) * 5,
            int(me.tankLevelLbsN[2].getValue() * LB2KG / 5) * 5,
        ];
        var totalFuelKg = int(me.totalFuelLbsN.getValue() * LB2KG / 5) * 5;
        var color = "green";
        if (totalFuelKg < 408) color = "amber";
        me.updateTextElement("fuelTotal", sprintf("%3d", totalFuelKg), color);

        color = (fuelQty[2] <= 5) ? "white" : "green";
        me.updateTextElement("fuelQty2", sprintf("%3d", fuelQty[2]), color);

        color = (me.fuelImbalanceN.getValue() or totalFuelKg < 408) ? "amber" : "green";
        me.updateTextElement("fuelQty0", sprintf("%3d", fuelQty[0]), 
            fuelQty[0] < 204 ? "amber" : color);
        me.updateTextElement("fuelQty1", sprintf("%3d", fuelQty[1]), 
            fuelQty[1] < 204 ? "amber" : color);

    }, 
};
