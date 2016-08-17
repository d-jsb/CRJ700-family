# EFIS for CRJ700 family
# EICAS primary page
# Author:  jsb
# Created: 03/2018
#

var EICASPriCanvas = {
    MAX_MSG: 16,    #number of message lines

    new: func(name, file) {
        var obj = {
            parents: [EICASPriCanvas , EFISCanvas.new(name)],
            svg_keys: [
                "N10", "N11", "N1pointer0", "N1pointer1",
                "rev0", "rev1", "apr0", "apr1", "thrustMode",
                "ITT0", "ITT1", "ITTpointer0", "ITTpointer1",
                "N20", "N21", "N2pointer0", "N2pointer1",
                "fuelFlow0", "fuelFlow1",
                "oilTemp0", "oilTemp1",
                "oilPress0", "oilPress1",
                "gOil", "oilPointer0", "oilPointer1",
                "gFanVib", "fanPointer0", "fanPointer1", "fanArcAmber0", "fanArcAmber1",
                "gGear", "gear0", "gear1", "gear2", "tGear0", "tGear1", "tGear2", "gearInTransit0", "gearInTransit1", "gearInTransit2",
                "slatsBar", "slatsBar_clip", "flapsBar", "flapsPos",
                "gFuelValues", "fuelQty0", "fuelQty1", "fuelQty2", "fuelTotal",
            ],
            #msgsys: MessageSystem.new(me.MAX_MSG, "instrumentation/eicas/msgsys1"),
            gearPosN: [1,1,1],
            gearPos: [-1,-1,-1],
            show_oilp: 1,
            oilp: [0,0],
        };
        for (var i = 0; i < EICASMsgSys1.getPageLength(); i += 1)
            append(obj.svg_keys, "message"~i);
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        obj.addUpdateFunction(obj.update, 0.050);
        obj.addUpdateFunction(obj.updateSlow, 0.500);
        return obj;
    },

    init: func() {
        var amber = me.colors["amber"];
        foreach (var i; [0,1]) {
            me["fanArcAmber"~i].setColor(amber);
            me._addThrustModeL(i);
            me._addReverseL(i);
        }
        me["gFanVib"].hide();
        me._addFlapsL();
        me._addEnginesL();
        me.hideGearT = maketimer(30, me, func() {me["gGear"].hide();});
        me.hideGearT.singleShot = 1;
        me.msgOil0 = EICASMsgSys1.getMessageID(EICASMsgClsWarning, "L ENG OIL PRESS");
        me.msgOil1 = EICASMsgSys1.getMessageID(EICASMsgClsWarning, "R ENG OIL PRESS");
        me.flapsCtrl = props.getNode("controls/flight/flaps");
        me.engineN = [ props.getNode("engines/engine[0]"), 
                       props.getNode("engines/engine[1]")];
        foreach (var i; [0,1,2]) {
            me.gearPosN[i] = props.getNode("gear/gear[0]/position-norm", 1);
        }
        me.updateSlow();
        me.update();
    },

    #-- listeners for rare events --
    _addThrustModeL: func(engine) {
        var apr = "apr"~engine;
        setlistener("controls/engines/engine["~engine~"]/thrust-mode", func(n) {
            var m = n.getValue();
            if (m == 3) {
                me["thrustMode"].setText("APR");
                me[apr].show();
                return;
            }
            else me[apr].hide();
            if (m == 0) me["thrustMode"].setText("");
            if (m == 1) me["thrustMode"].setText("CLB");
            if (m == 2) me["thrustMode"].setText("TO");
        }, 1);
    },

    _addReverseL: func(engine) {
        var rev = "rev"~engine;
        setlistener("engines/engine["~engine~"]/reverser-pos-norm", func(n) {
            var pos = n.getValue();
            if (pos) me[rev].show();
            else me[rev].hide();
        }, 1, 0);
    },

    _addFlapsL: func() {
        setlistener("surface-positions/slat-pos-norm", func(n) {
            me["slatsBar_clip"].setTranslation(-100 * n.getValue(), 0);
            me._updateClip("slatsBar");
        }, 1, 0);
        setlistener("surface-positions/flap-pos-norm", func(n) {
            var value = n.getValue();
            me["flapsBar"].setTranslation(296 * value, 0);
            me["flapsPos"].setText(sprintf("%2d", math.round(45*value)));
        }, 1, 0);
    },

    _addEnginesL: func() {
        var L = func(n) {
            if (n.getValue()) EICASMsgSys1.auralAlert("door");
        };
        setlistener("engines/engine[0]/running-nasal", L, 0, 0);
        setlistener("engines/engine[1]/running-nasal", L, 0, 0);
    },

    getEngine: func(idx, prop) {
        return me.engineN[idx].getChild(prop,0,1).getValue() or 0;
        #return (getprop("engines/engine["~idx~"]/"~prop) or 0);
    },

    getTank: func(idx) {
        var lbs = getprop("consumables/fuel/tank["~idx~"]/level-lbs") or 0;
        return lbs * LB2KG;
    },

    updateOilGauge: func(i, value) {
        if (value < 25) {
            value *= 0.01396;
            me["oilPointer"~i].setColor(me.colors["red"]);
            me["oilPress"~i].setColor(me.colors["red"]);
        }
        else {
            value *= 0.00959;
            me["oilPointer"~i].setColor(me.colors["green"]);
            me["oilPress"~i].setColor(me.colors["green"]);
        }
        me["oilPointer"~i].setRotation(value);
    },

    updateGear: func(idx, pos) {
        if (pos == 0) {
            me["tGear"~idx].setText("UP");
            me["gear"~idx].setColor(me.colors["white"]);
            me["gearInTransit"~idx].hide();
        }
        elsif (pos == 1) {
            me["tGear"~idx].setText("DN");
            me["gear"~idx].setColor(me.colors["green"]);
            me["gearInTransit"~idx].hide();
        }
        else {
            me["gearInTransit"~idx].show();
            me["tGear"~idx].setText("");
        }
    },

    updateGearIndicators: func() {
        var flapsCtrl = me.flapsCtrl.getValue();
        var update = 0;
        var tmp = 0;
        foreach (var i; [0,1,2]) {
            tmp = me.gearPosN[i].getValue();
            if (me.gearPos[i] != tmp) {
                me.gearPos[i] = tmp;
                update = 1;
            } 
        }
        if (flapsCtrl or update) {
            me.hideGearT.stop();
            me["gGear"].show();
            me.updateGear(0, me.gearPos[0]);
            me.updateGear(1, me.gearPos[1]);
            me.updateGear(2, me.gearPos[2]);
        }
        else if(!me.hideGearT.isRunning) me.hideGearT.start();
    },

    updateFuel: func() {
        me["fuelQty0"].setText(sprintf("%3d", me.getTank(0)));
        me["fuelQty1"].setText(sprintf("%3d", me.getTank(1)));
        me["fuelQty2"].setText(sprintf("%3d", me.getTank(2)));
        var totalFuel = getprop("consumables/fuel/total-fuel-lbs");
        var imba = getprop("systems/fuel/imbalance");
        me["fuelTotal"].setText(sprintf("%3d", totalFuel*LB2KG));
        if (imba or totalFuel < 900) {
            me["gFuelValues"].setColor(me.colors["amber"]);
        }
        else me["gFuelValues"].setColor(me.colors["green"]);
    },

    updateSlow: func() {
        me.updateGearIndicators();
        me.updateFuel();
        var show_oilp = 0;
        if (CRJ700.engines[0].running and CRJ700.engines[1].running) {
            if(me.oilp[0] > 24 and me.oilp[1] > 24) {
                show_oilp = 0;
            }
        }
        else show_oilp = 1;
        
        if (show_oilp != me.show_oilp) {
            me["gOil"].setVisible(show_oilp);
            me["gFanVib"].setVisible(!show_oilp);
            me.show_oilp = show_oilp;
        }
        
    },

    update: func() {
        me.oilp = [0,0];
        var val_e0 = me.getEngine(0, "rpm");
        var val_e1 = me.getEngine(1, "rpm");
        me["N10"].setText(sprintf("%3.1f", val_e0));
        me["N11"].setText(sprintf("%3.1f", val_e1));
        me["N1pointer0"].setRotation(val_e0 * 0.04189);
        me["N1pointer1"].setRotation(val_e1 * 0.04189);
        
        val_e0 = me.getEngine(0, "itt-norm")*100;
        val_e1 = me.getEngine(1, "itt-norm")*100;
        me["ITT0"].setText(sprintf("%3d", val_e0*10));
        me["ITT1"].setText(sprintf("%3d", val_e1*10));
        me["ITTpointer0"].setRotation(val_e0 * 0.04189);
        me["ITTpointer1"].setRotation(val_e1 * 0.04189);
        
        val_e0 = me.getEngine(0, "rpm2");
        val_e1 = me.getEngine(1, "rpm2");
        me["N20"].setText(sprintf("%3.1f", val_e0));
        me["N21"].setText(sprintf("%3.1f", val_e1));
        me["N2pointer0"].setRotation(val_e0 * 0.04189);
        me["N2pointer1"].setRotation(val_e1 * 0.04189);
        
        me["fuelFlow0"].setText(sprintf("%4d", me.getEngine(0, "fuel-flow-pph")));
        me["fuelFlow1"].setText(sprintf("%4d", me.getEngine(1, "fuel-flow-pph")));
        me["oilTemp0"].setText(sprintf("%3d", me.getEngine(0, "oilt-norm")*163));
        me["oilTemp1"].setText(sprintf("%3d", me.getEngine(1, "oilt-norm")*163));
        me.oilp[0] = me.getEngine(0, "oilp-norm")*780;
        me.oilp[1] = me.getEngine(1, "oilp-norm")*780;
        me["oilPress0"].setText(sprintf("%3d", me.oilp[0]));
        me["oilPress1"].setText(sprintf("%3d", me.oilp[1]));
        if (me.oilp[0] < 24) EICASMsgSys1.setMessage(EICASMsgClsWarning, me["msgOil0"], 1);
        else EICASMsgSys1.setMessage(EICASMsgClsWarning, me["msgOil0"], 0);

        if (me.oilp[1] < 24) EICASMsgSys1.setMessage(EICASMsgClsWarning, me["msgOil1"], 1);
        else EICASMsgSys1.setMessage(EICASMsgClsWarning, me["msgOil1"], 0);

        me.updateOilGauge(0, me.oilp[0]);
        me.updateOilGauge(1, me.oilp[1]);
        
    },
};
