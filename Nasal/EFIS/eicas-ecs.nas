# EFIS for CRJ700 family 
# EICAS primary page
# Author:  jsb
# Created: 03/2018
#

var EICASECSCanvas = {
    new: func(name, file) {
        var obj = { 
            parents: [EICASECSCanvas , EFISCanvas.new(name)],
            svg_keys: [
                "line0", "line1", "line2", 
                "line30", "line31",
                "line40", "line41", "line42", "line43",
                "line50", "line51", "line52", "line53",
                "bleedmanual", "manualL", "manualR", "psiL", "psiR",
            ],
        };
        foreach (var i; [0,1,2,3,4]) {
            append(obj.svg_keys, "sov"~i);
            append(obj.svg_keys, "sov"~i~"line");
        }
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        return obj;
    },
    
    init: func() {
        foreach (var i; [0,1,2,3,4]) {
            setlistener("systems/pneumatic/sov"~i, me._makeL_sov(i), 1, 0);
        }
        foreach (var i; [0,1,2]) {
            setlistener("engines/engine["~i~"]/running-nasal", me._makeL_line(i), 1, 0);
        }
        setlistener("systems/pneumatic/sov3", me._makeL_line(3), 1,0);
        setlistener("systems/pneumatic/pressure-left", me._makeL_line(4), 1, 0);
        setlistener("systems/pneumatic/pressure-right", me._makeL_line(5), 1, 0);
        setlistener("controls/ECS/pack-l-man", me._makeListener_showHide(["manualL"]), 1, 0);
        setlistener("controls/ECS/pack-r-man", me._makeListener_showHide(["manualR"]), 1, 0);
    },
    
    _makeL_sov: func(i) {
        if (i < 3) return func(n) {
            if (n.getValue()) {
                me["sov"~i].setRotation(90*D2R);
                if (CRJ700.engines[i].running)
                    me["sov"~i~"line"].setColorFill(me.colors["green"]);
                else
                    me["sov"~i~"line"].set("fill", "none");
            }
            else {
                me["sov"~i].setRotation(0);
                me["sov"~i~"line"].set("fill", "none");
            }
        };
        if (i >= 3) return func(n) {
            if (n.getValue()) {
                me["sov"~i].setRotation(90*D2R);
                if ((i == 3) or
                    (i == 4 and (getprop("systems/pneumatic/pressure-left") or getprop("systems/pneumatic/pressure-right")))
                   )
                me["sov"~i~"line"].setColorFill(me.colors["green"]);
            }
            else {
                me["sov"~i].setRotation(0);
                me["sov"~i~"line"].set("fill", "none");
            }
        };
    },
    
    _makeL_line: func(i) {
        #engines/apu
        if (i < 3) return func(n) {
            if (n.getValue()) {
                me["line"~i].setColorFill(me.colors["green"]);
                if (getprop("systems/pneumatic/sov"~i))
                    me["sov"~i~"line"].setColorFill(me.colors["green"]);
            }
            else {
                me["line"~i].set("fill", "none");
                me["sov"~i~"line"].set("fill", "none");
            }
        };
        else return func(n) {
            if (n.getValue()) {
                if (i == 3) {
                    me["line30"].setColorFill(me.colors["green"]);
                    me["line31"].setColorFill(me.colors["green"]);
                }
                else {
                    foreach (var ii; [0,1,2,3]) 
                        me["line"~(10*i+ii)].setColorFill(me.colors["green"]);
                    if (getprop("systems/pneumatic/sov4"))
                        me["sov4line"].setColorFill(me.colors["green"]);
                    if (i == 4) me["psiL"].setText("54");
                    if (i == 5) me["psiR"].setText("54");
                }
            }
            else {
                if (i == 3) {
                    me["line30"].set("fill", "none");
                    me["line31"].set("fill", "none");
                }
                else {
                    #isolation valve
                    me["sov4line"].set("fill", "none"); 
                    foreach (var ii; [0,1,2,3])
                        me["line"~(10*i+ii)].set("fill", "none");
                    if (i == 4) me["psiL"].setText("0");
                    if (i == 5) me["psiR"].setText("0");
                }
            }
        };
    },
};
