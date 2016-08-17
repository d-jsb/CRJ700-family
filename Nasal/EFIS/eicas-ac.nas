# EFIS for CRJ700 family 
# EICAS doors status page
# Author:  jsb
# Created: 03/2018
#

var EICASACCanvas = {
    __class_name: "EICASACCanvas",
    AC_MIN_VOLTS: 108,
    
    new: func(name, file) {
        var obj = { 
            parents: [EICASACCanvas , EFISCanvas.new(name)],
            svg_keys: ["gen0", "gen1", "gen2", "gen3", "gen4", #2:apu, 3: ext, 4: adg
                    "eng0", "eng1", "eng2", 
                    "idg0", "idg1", "idgdisc0", "idgdisc1",
                    "bus1","bus2","bus3", "bus4", "bus5", #3: ess, 4: serv, 5: adg
                    "line13", "line23", "line24", #bus2bus
                    "line1", "line2", "line31", "line32", #apu2bus
                    "gADG", "gExternal",
                    "axfail1", "axfail2", "axoff1", "axoff2", "shed", "servicecfg",
                ],
            prop_base: "systems/ac/",
            prop_names: [],
            engRunning: [0,0,0,0,0],
            idgdisc: [0,0,0],
            gen: [0,0,0,0,0], 
            volts: [0,0,0,0,0],
            essxfer: 0,
        };
        foreach (var i; [0,1,2,3,4]) {
            append(obj.svg_keys,"gen"~i~"line0");
            append(obj.svg_keys,"gen"~i~"line1");
        }
        foreach (var i; [1,2,3,4,5]) {        
            append(obj.svg_keys,"load"~i);
            append(obj.svg_keys,"freq"~i);
            append(obj.svg_keys,"value"~i);
        }
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        obj.addUpdateFunction(obj.update, 0.2);
        return obj;
    },

    getKeys: func() {
        return me.svg_keys;
    },

    init: func() {
        foreach (var key; ["gADG", "gExternal", "shed", "servicecfg"])
            me[key].hide();
        foreach (var i; [1,2,31,32]) {
            me["line"~i].setColorFill(me.colors["green"]);
            me["line"~i].hide();
        }
        foreach (var i; [13,23,24])
            me["line"~i].set("fill", "none");
        setlistener("controls/electric/idg1-disc", me._makeL_IDGdisc(0), 1, 0);
        setlistener("controls/electric/idg2-disc", me._makeL_IDGdisc(1), 1, 0);
        foreach (var i; [1,2,3,4,5]) {
            setlistener("systems/AC/system/gen"~i~"-value", me._makeL_readoutVolts(i), 1, 0);
            setlistener("systems/AC/system/gen"~i~"-freq", me._makeL_readoutHz(i), 1, 0);
            setlistener("systems/AC/outputs/bus"~i, me._makeL_bus(i), 1, 0);
        }
        var fdm = getprop("/sim/flight-model");
        foreach (var i; [0,1,2]) {
            if (fdm == "yasim")
                setlistener("engines/engine["~i~"]/running-nasal", me._makeL_eng(i), 1, 0);
            else setlistener("engines/engine["~i~"]/running", me._makeL_eng(i), 1, 0);
            setlistener("controls/electric/engine["~i~"]/generator", me._makeL_gen(i), 1, 0);
        }
        # ground power
        setlistener("controls/electric/ac-service-avail", func(n) { me.engRunning[3] = n.getValue(); }, 1, 0);
        setlistener("controls/electric/ac-service-in-use", func(n) { me["acext"] = (n.getValue()) ? 1 : 0; }, 1, 0);
        
        foreach (var i; [1,2]) {
            me["axfail"~i].setColor(me.colors["amber"]);
            me["axfail"~i].hide();
            me["axoff"~i].hide();
            setlistener("controls/electric/auto-xfer"~i, me._makeListener_showHide(["axoff"~i], 0), 1, 0);
            setlistener("systems/AC/system["~i~"]/serviceable", me._makeListener_showHide(["axfail"~i], 0), 1, 0);
        }
        setlistener("controls/electric/ADG", me._makeListener_showHide("gADG"), 1, 0);
        setlistener("controls/electric/ac-ess-xfer", func(n) {
             me.essxfer = n.getValue() or 0;
             me.update();
        }, 1, 0);
        setlistener("systems/AC/outputs/bus4", me._makeL_shed(), 1, 0);
    },
    
    _makeL_shed: func() {
        return func(n) {
            if (n.getValue() < me.AC_MIN_VOLTS) me["shed"].show();
            else me["shed"].hide();
        };
    },
    
    _makeL_bus: func(i) {
        return func(n) {
            var volts = n.getValue() or 0;
            if (volts > 108 and volts < 130) me["bus"~i].setColor(me.colors["green"]);
            else me["bus"~i].setColor(me.colors["amber"]);
            
        };
    },
    
    _makeL_IDGdisc: func(i) { 
        return func(n) {
            me.idgdisc[i] = n.getValue();
            if (me.idgdisc[i]) {
                me["idgdisc"~i].show();
                me["idg"~i].setColor(me.colors["white"]);
            }
            else {
                me["idgdisc"~i].hide();
                if (me.engRunning[i]) me["idg"~i].setColor(me.colors["green"]);
                else me["idg"~i].setColor(me.colors["white"]);
            }
        };
    },
    
    _makeL_readoutVolts: func(i) {
        return func(n) {
            var j=i-1;
            me.volts[j] = n.getValue() or 0;
            me.updateTextElement("value"~i, sprintf("%3d", me.volts[j]), (me.volts[j] > 108 and me.volts[j] < 130) ? "green" : "white");
        };
    },
    
    _makeL_readoutHz: func(i) {
        return func(n) {
            var v = n.getValue() or 0;
            me.updateTextElement("freq"~i, sprintf("%3d", v), (v > 360 and v < 440) ? "green" : "white");
        };
    },
    
    _makeL_eng: func(i) { 
        return func(n) {
                me.engRunning[i] = n.getValue();
                #print("EICAS AC: engine"~i~" = "~me.engRunning[i]);
                if (me.engRunning[i]) {
                    me["eng"~i].setColor(me.colors["blue"]);
                    if (i<2) me["idg"~i].setColor(me.colors["green"]);
                }
                else {
                    me["eng"~i].setColor(me.colors["white"]);
                    if (i<2) me["idg"~i].setColor(me.colors["white"]);
                }
                setprop("controls/electric/engine["~i~"]/generator", 
                    getprop("controls/electric/engine["~i~"]/generator"));
                me.update();
            };
    },
    
    # gen0..2 (engine+apu)
    # green: gen on, amber: gen off with engine on, white: gen and engine off
    _makeL_gen: func(i) { 
        return func(n) {
            me.gen[i] = n.getValue();
            me.update();
        };
    },
       
    update: func() {
        if (me.engRunning[3]) {
            me["gExternal"].show();
            if (getprop("controls/electric/ac-service-selected-ext"))
                me["servicecfg"].show();
            if (me["acext"]) me["gen3line1"].setColorFill(me.colors["green"]);
            else me["gen3line1"].set("fill", "none");
        }
        else {
            me["gExternal"].hide();
            me["servicecfg"].hide();
        }

        # no AC at all
        if (!me["acext"] and me.volts[0] < me.AC_MIN_VOLTS and me.volts[1] < me.AC_MIN_VOLTS and me.volts[2] < me.AC_MIN_VOLTS) {
            me["line1"].hide(); 
            me["line2"].hide();
            me["line31"].hide();
            me["line32"].hide();
            me["gen0line1"].set("fill", "none");
            me["gen1line1"].set("fill", "none");
            me["gen2line1"].set("fill", "none");
            me["line13"].set("fill", "none");
            me["line23"].set("fill", "none");
        }
        # AC avail
        else {
            me["line1"].show();
            me["line2"].show();
            if (me.essxfer) {
                me["line23"].setColorFill(me.colors["green"]);
                me["line13"].set("fill", "none");
            } 
            else {
                me["line13"].setColorFill(me.colors["green"]);
                me["line23"].set("fill", "none");
            }
            # generator output markers
            #2DO check IDG disconnect
            if (me.volts[0] > me.AC_MIN_VOLTS) { 
                me["gen0line1"].setColorFill(me.colors["green"]);
            }
            else {
                me["gen0line1"].set("fill", "none"); 
            }
            if (me.volts[1] > me.AC_MIN_VOLTS) {
                me["gen1line1"].setColorFill(me.colors["green"]);
            }
            else {
                me["gen1line1"].set("fill", "none");
            }
            if (me.volts[2] > me.AC_MIN_VOLTS and (me.volts[0] < me.AC_MIN_VOLTS or me.volts[1] < me.AC_MIN_VOLTS)) {
                me["gen2line1"].setColorFill(me.colors["green"]);
            }
            else {
                me["gen2line1"].set("fill", "none");
            }
            # APU / gnd lines
            if (me.volts[2] > me.AC_MIN_VOLTS or me["acext"]) {
                if (me.volts[0] < me.AC_MIN_VOLTS) {
                    me["line31"].show();
                }
                else {
                    me["line31"].hide();
                }
                if (me.volts[1] < me.AC_MIN_VOLTS) {
                    me["line32"].show();
                }
                else {
                    me["line32"].hide();
                }
            } 
            #
            else {
                # one engine feeds both sides
                if ((me.volts[0] > me.AC_MIN_VOLTS and me.volts[1] < me.AC_MIN_VOLTS) or
                   (me.volts[0] < me.AC_MIN_VOLTS and me.volts[1] > me.AC_MIN_VOLTS)) {
                    me["line31"].show();
                    me["line32"].show();
                }
                else {
                    me["line31"].hide();
                    me["line32"].hide();
                }
            }
        }
        # generators
        foreach (var i; [0,1,2]) {
            if (me.volts[i] > me.AC_MIN_VOLTS)
            {
                me["gen"~i].setColor(me.colors["green"]);
                me["gen"~i~"line0"].setColorFill(me.colors["green"]);
            }
            else {
                if (me.engRunning[i] and !me.idgdisc[i]) {
                    me["gen"~i].setColor(me.colors["amber"]);
                    me["gen"~i~"line0"].set("fill", "none");
                }
                else {
                    me["gen"~i].setColor(me.colors["white"]);
                    me["gen"~i~"line0"].set("fill", "none");
                }
            }        
        }        
    }, 
};
