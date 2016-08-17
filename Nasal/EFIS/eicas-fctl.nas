# EFIS for CRJ700 family 
# EICAS status page
# Author:  jsb
# Created: 03/2018
#

var EICASFctlCanvas = {
    new: func(name, file) {
        var obj = { 
            parents: [EICASFctlCanvas , EFISCanvas.new(name)],
            svg_keys: [
                "ail0", "ail1", "ailTrim",
                "slats0", "slats1",
                "FltSpOB0", "FltSpIB0", 
                "FltSpOB1", "FltSpIB1", 
                "GndSpOB0", "GndSpIB0", 
                "GndSpOB1", "GndSpIB1",
                "spoilerIndL1", "spoilerIndL2", "spoilerIndL3", "spoilerIndL4",
                "spoilerIndR1", "spoilerIndR2", "spoilerIndR3", "spoilerIndR4",
                "flaps0", "flaps1", 
                "elev0",  "elev1", "elevTrim", "elevTrimValue",
                "rudder", "rudderTrim", "rudderLimit0", "rudderLimit1",
                "tStabTrim",
            ],
            _surf_props: {},
        };
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        obj.addUpdateFunction(obj.update, 0.07);
        return obj;
    },

    init: func() {
        setlistener("/surface-positions/spoiler-ob-ground-pos-norm", me._makeListener_translate(["spoilerIndL3","spoilerIndR3"], 0, -139.46), 1, 0);
        setlistener("/surface-positions/spoiler-ib-ground-pos-norm", me._makeListener_translate(["spoilerIndL4","spoilerIndR4"], 0, -139.46), 1, 0);
        setlistener("/surface-positions/flap-pos-norm", me._makeL_SlatFlap("flaps", 45), 1, 0);
        setlistener("/surface-positions/slat-pos-norm", me._makeL_SlatFlap("slats", 25), 1, 0);
        
        setlistener("controls/flight/rudder-trim", me._makeListener_rotate("rudderTrim", -1), 1, 0);
        setlistener("controls/flight/aileron-trim", me._makeListener_rotate("ailTrim"), 1, 0);
        
        setlistener("systems/stab-trim/engaged", me._makeListener_showHide("tStabTrim", 0), 1, 0);
    },
      
    _makeL_SlatFlap: func(svgkey, scale) {
        return func(n) {
            var degree = math.round((n.getValue() or 0)*scale);
            foreach (var i; [0,1]) {
                me[svgkey~i].setText(sprintf("%2d", degree));
            }
        };
    },
    
    getSurf: func(name, default=0) {
        if (me._surf_props[name] == nil) {
            me._surf_props[name] =
                props.getNode("/surface-positions/"~name, 1);
        }
        var value = me._surf_props[name].getValue();
        if (value != nil) return value;
        else return default;
    },
    
    update: func() {
        var ail = [0,0];
        ail[0] = me.getSurf("left-aileron-pos-norm");
        ail[1] = me.getSurf("right-aileron-pos-norm");
        var elev = me.getSurf("elevator-pos-norm"); # modelled as only one ctrl.srf.
        if (elev > 0) elev *= 55; #push
        else elev *= 83; #pull

        foreach (var i; [0,1]) {
            if (ail[i] > 0) ail[i] *= 55;
            else ail[i] *= 81.5;
        }
        me["ail0"].setTranslation(0, ail[0]);
        me["ail1"].setTranslation(0, ail[1]);
        me["elev0"].setTranslation(0,elev);
        me["elev1"].setTranslation(0,elev);
        #-- rudder: full = 33deg, may be limited by SCCU 4deg - 33deg (not yet implemented)
        me["rudder"].setTranslation(-162.71 * me.getSurf("rudder-pos-norm"), 0);
        #-- spoilerons --
        me["spoilerIndL1"].setTranslation(0, -153.53 * me.getSurf("left-ob-mfs-pos-norm"));
        me["spoilerIndL2"].setTranslation(0, -144.47 * me.getSurf("left-ib-mfs-pos-norm"));
        me["spoilerIndR2"].setTranslation(0, -144.47 * me.getSurf("right-ib-mfs-pos-norm"));
        me["spoilerIndR1"].setTranslation(0, -153.53 * me.getSurf("right-ob-mfs-pos-norm"));

        var trim = me.getInstr("eicas", "hstab-trim");
        me["elevTrimValue"].setText(sprintf("%1.1f", trim));
        me["elevTrim"].setTranslation(0, -9.4785*trim);
    }, 
};
