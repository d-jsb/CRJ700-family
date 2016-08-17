# EFIS for CRJ700 family
# EICAS status page
# Author:  jsb
# Created: 03/2018
#

var EICASStatCanvas = {
    MAX_MSG: 26,    #number of message lines without APU indicators
    MAX_MSG2: 16,    #number of message lines with APU active

    new: func(name, file) {
        var obj = {
            parents: [me, EFISCanvas.new(name)],
            svg_keys: [
                "elevTrim", "elevTrimValue", "ailTrim", "rudderTrim",
                "gAPU", "rpm", "rpmPointer", "egt", "egtPointer",
                "doorMsg", "apuoff",
            ],
            #msgsys: MessageSystem.new(me.MAX_MSG, "instrumentation/eicas/msgsys2"),
            _eng_props: {},
            _surf_props: {},
        };
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        obj.addUpdateFunction(obj.update, 0.100);
        return obj;
    },

    init: func() {
        setlistener("controls/APU/electronic-control-unit", me._makeL_APU(), 1, 0);
        setlistener("engines/engine[2]/door-msg", me._makeL_APUDoor(), 1);
        setlistener("controls/flight/rudder-trim", me._makeListener_rotate("rudderTrim", -1), 1, 0);
        setlistener("controls/flight/aileron-trim", me._makeListener_rotate("ailTrim"), 1, 0);
        me.apu_rpmN = props.getNode("engines/engine[2]/rpm", 1);
        me.apu_egtN = props.getNode("engines/engine[2]/egt-degc", 1);
        me.update();
    },

    _makeL_APU: func() {
        return func(n) {
            me._apu = n.getValue();
            if (me._apu) {
                me["gAPU"].show();
                me["apuoff"].hide();
                EICASMsgSys2.setPageLength(me.MAX_MSG2)
            }
            else {
                me["gAPU"].hide();
                me["apuoff"].show();
                EICASMsgSys2.setPageLength(me.MAX_MSG)
            }
        };
    },

    _makeL_APUDoor: func() {
        return func(n) {
            var value = n.getValue();
            me["doorMsg"].setText(value);
            if (value == "----") me["doorMsg"].setColor(me.colors["amber"]);
            else me["doorMsg"].setColor(me.colors["white"]);
        };
    },

    update: func() {
        if (me._apu) {
            var value = me.apu_rpmN.getValue();
            me["rpm"].setText(sprintf("%3.0f", value));
            me["rpmPointer"].setRotation(value * 0.04189);
            value = me.apu_egtN.getValue();
            me["egt"].setText(sprintf("%3.0f", value));
            me["egtPointer"].setRotation(value * 0.003696);
        }
        var trim = num(me.getInstr("eicas", "hstab-trim")) or 0;
        if (trim < 0) {
            me["elevTrim"].hide();
        } else {
            me["elevTrim"].show();
            me["elevTrim"].setTranslation(0, -9.4785 * trim);
        }
        me["elevTrimValue"].setText(sprintf("%1.1f", trim));
    },
};
