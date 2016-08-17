# EFIS for CRJ700 family 
# EICAS doors status page
# Author:  jsb
# Created: 03/2018
#

var EICASDoorsCanvas = {
    new: func(name, file) {
        var obj = { 
            parents: [EICASDoorsCanvas , EFISCanvas.new(name)],
            svg_keys: ["passenger", "fwdservice", "av-bay", "fwdcargo", "ctrcargo",
                    "aftcargo", "lfwdemer", "rfwdemer", "laftemer","raftemer"],
            prop_base: "sim/model/door-positions/",
            prop_names: ["pax-left", "pax-right", "av-bay", "fwd-cargo", "ctr-cargo", 
                "aft-cargo", "emer-l1", "emer-r1", "emer-l2", "emer-r2"],
            prop_sufix: "/position-norm",
        };
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        return obj;
    },

    init: func() {
        if (substr(getprop("sim/aero"), 0,6) == "CRJ700") {
            me["laftemer"].hide();
            me["raftemer"].hide();
            me["fwdcargo"].hide();
        }
        var color_warn = me.colors["red"];
        forindex (var i; me.prop_names) {
            if (i > 0) color_warn = me.colors["amber"];
            var prop = me.prop_base~me.prop_names[i]~me.prop_sufix;
            var element = me.svg_keys[i];
            setlistener(prop, me._makeListener_setColor(element, color_warn, "green"), 1, 0);
        }
    },
};
