#
# CRJ700 shared NAV/HSI code for PFD and MFD
# Author:  jsb
# Created: 11/2018
#-----------------------------------------------------------------------------

# NavData record for a navigation source (VOR, DME)
var NavData = {
    new: func() {
        var obj = {
            parents: [me],
            src: 0,
            valid: 0,
            id: "---",      # Station ID
            crs: 1,         # 1..360
            distance: 0,    # DME distance
            dmeh: 0,        # DME hold
            deviation: 0,
            from_flag: 0,
        };
        return obj;
    },
};

#-- define styles for the CompassRose
var style_HSI = canvas.CompassRose.Style.new();
style_HSI.set("fontsize", 44)
    .setMarkLength(0.1)
    .setMarkOffset(style_HSI.MARK_IN)
    .setSubdivisions(1)
    .setMarkWidth(4);
#style_HSI.setSubdivisionLength(0.5);

var style_NAV = canvas.CompassRose.Style.new();
style_NAV.setMarkLength(0.05)
    .setSubdivisions(1)
    .setSubdivisionLength(0.5)
    .setMarkOffset(style_NAV.MARK_OUT)
    .setMarkWidth(4)
    .setBaselineWidth(5)
    .set("fontsize", 44);

#tmp for development
var HSI_inputs = [
    {
        heading: "/instrumentation/heading-indicator/indicated-heading-deg",
        bearing: "/instrumentation/adf[0]/indicated-bearing-deg",
        bearing2: "/instrumentation/adf[1]/indicated-bearing-deg",
        obs: "/instrumentation/nav[0]/radials/selected-deg",
        deviation: "/instrumentation/nav[0]/heading-needle-deflection-norm",
    },
    {
        heading: "/instrumentation/heading-indicator/indicated-heading-deg",
        bearing: "/instrumentation/adf[0]/indicated-bearing-deg",
        bearing2: "/instrumentation/adf[1]/indicated-bearing-deg",
        obs: "/instrumentation/nav[1]/radials/selected-deg",
        deviation: "/instrumentation/nav[1]/heading-needle-deflection-norm",
    },
];

#-- controller for the nav data selectors on the side panels
var NavDataController = {
    # definition of bearing sources - filled below
    BEARING_SRC: ["", "ADF", "NAV", "FMS"],
    BEARING_PROPNAMES: [
        ["/instrumentation/adf[0]/indicated-bearing-deg",
        "/instrumentation/adf[1]/indicated-bearing-deg",],
        ["/instrumentation/nav[0]/heading-error-deg",
        "/instrumentation/nav[1]/heading-error-deg",],
    ],
    
    NAV_SRC_COLOR: [
        ["red", "green", "amber", "white", "amber"], #PILOT_SIDE
        ["red", "amber", "green", "amber", "white"], #COPILOT_SIDE
    ],
    new: func() {
        var obj = {
            parents: [me],
            _get_bearing: [func 0;],
            _callbacks: {},
            base_path: "controls/efis/",
            bearing_src_selected: [[0,0],[0,0]],
            bearing_src_name: [["", ""], ["", ""]],
            _bs_changed: [[1,1],[1,1]],
            #bearing: [0,0],
            nav_src: [0,0],                     # idx of the selected nav source
            nav_data: [[nil, nil],[nil, nil]],  # NavData
            nav_radio: [{},{}],                 # prop nodes for the nav radios
            fms: {},                            # prop nodes for the nav radios
            adf: [{},{}],         
        };
        obj.nav_data[PILOT_SIDE][0] = NavData.new(); # on-side
        obj.nav_data[PILOT_SIDE][1] = NavData.new(); # x-side
        obj.nav_data[COPILOT_SIDE][0] = NavData.new(); # on-side
        obj.nav_data[COPILOT_SIDE][1] = NavData.new(); # x-side
        return obj;
    },

    init: func {
        var wp0 = "autopilot/route-manager/wp/";
        me.fms.wp0_idN = props.getNode(wp0~"id");
        me.fms.wp0_bearingN = props.getNode(wp0~"bearing-deg");
        me.fms.wp0_distN = props.getNode(wp0~"dist");
        me.fms.cdi_deflectionN = props.getNode("instrumentation/gps/cdi-deflection");
        # get property nodes for nav radios
        foreach (var i; [0,1]) {
            me.nav_radio[i].distanceN = 
                props.getNode("instrumentation/dme["~i~"]/indicated-distance-nm");
            me.nav_radio[i].deviationN = 
                props.getNode("instrumentation/nav["~i~"]/heading-needle-deflection");

            #-- setup listeners for low change rate props --
            setlistener("/instrumentation/adf["~i~"]/in-range", me._makeL_adf(i, "in_range"), 1, 0);
            setlistener("/instrumentation/dme["~i~"]/hold", me._makeL_nav(i, "dmeh"), 1, 0);
            
            setlistener("/instrumentation/nav["~i~"]/from-flag", me._makeL_nav(i, "from_flag"), 1, 0);
            #FIXME: what is the difference btw. valid and in-range
            #setlistener("/instrumentation/nav["~i~"]/in-range", me._makeL_nav(i, "valid"), 1, 0);
            setlistener("/instrumentation/nav["~i~"]/data-is-valid", me._makeL_nav(i, "valid"), 1, 0);
            setlistener("/instrumentation/nav["~i~"]/nav-id", me._makeL_nav(i, "id"), 1, 0);
            setlistener("/instrumentation/nav["~i~"]/nav-loc", me._makeL_nav(i, "isLoc"), 1, 0);
            setlistener("/instrumentation/nav["~i~"]/radials/selected-deg", me._makeL_nav(i, "crs"), 1, 0);
        }
        foreach (var side; [PILOT_SIDE, COPILOT_SIDE]) {
            setlistener(me.base_path~"sidepanel["~side~"]/brg-src0",
                me._makeL_bearing_src(side,0), 1, 0);
            setlistener(me.base_path~"sidepanel["~side~"]/brg-src1", 
                me._makeL_bearing_src(side,1), 1, 0);
            setlistener(me.base_path~"sidepanel["~side~"]/nav-src", 
                me._makeL_nav_src(side), 1, 0);
        }

        append(me._get_bearing, func(i) {
            return (getprop(me.BEARING_PROPNAMES[0][i]) or 0);
        });
        append(me._get_bearing, func(i) {
            return (getprop(me.BEARING_PROPNAMES[1][i]) or 0);
        });
        append(me._get_bearing, func(i) {
            var b = me.fms.wp0_bearingN.getValue() or 0;
            return b - getprop("/orientation/heading-deg") or 0;
        });
        me["_update_timer"] = maketimer(0.1, me, me.update);
        me["_update_timer"].start();
        return me;
    },

    _makeL_nav: func(i, name) {
        return func(n) {
            me.nav_radio[i][name] = n.getValue();
        };
    },

    # ADF in range
    _makeL_adf: func(i, name) {
        return func(n) {
            me.adf[i][name] = n.getValue();
            me._bs_changed[0][i] = 1;
            me._bs_changed[1][i] = 1;
        };
    },

    # _makeL_bearing_src - creates handler for bearing src selector button
    # pilot: PILOT_SIDE, COPILOT_SIDE
    # bs: 0 = source 1 (magenta), 1 = source 2 (cyan)
    _makeL_bearing_src: func(pilot, bs) {
        return func(n) {
            var val = n.getValue() or 0;
            me._bs_changed[pilot][bs] = 1;
            me["bearing_src_selected"][pilot][bs] = val;
            me["bearing_src_name"][pilot][bs] = me.BEARING_SRC[val] ~ (bs ? "2" : "1");
        };
    },

    # _makeL_nav_src - creates handler for nav src selector knob
    # pilot: PILOT_SIDE, COPILOT_SIDE
    _makeL_nav_src: func(pilot) {
        return func(n) {
            me.nav_src[pilot] = n.getValue() or 0;
            me._update(pilot, ON_SIDE);
            me._update(!pilot, X_SIDE);
        };
    },

    # update nasal vars from props
    # pilot: update (0 = pilot side, 1 = copilot side) data
    # x_side: update (0 = on side, 1 = cross side) data
    _update: func(pilot = 0, x_side = 0) {
        var src = me.nav_src[pilot];
        if (x_side) src = me.nav_src[!pilot];
        var src_name = CRJ700.NAV_SRC[src];
        var radio = -1;
        var fms_id = -1;
        if (src == 1) radio = 0;
        if (src == 2) radio = 1;
        if (src == 3) fms_id = 0;
        if (src == 4) fms_id = 1;

        #print("update (",pilot,",",x_side,") ",src," ",src_name," radio:",radio);
        me.nav_data[pilot][x_side].src = src_name;
        if (src == 0) {
            me.nav_data[pilot][x_side].valid = 0
        } elsif (radio >= 0 and radio <= 1) {
            me.nav_data[pilot][x_side].id = me.nav_radio[radio].id or "---";
            me.nav_data[pilot][x_side].crs = me.nav_radio[radio].crs or 360;
            me.nav_data[pilot][x_side].dmeh = me.nav_radio[radio].dmeh;
            me.nav_data[pilot][x_side].from_flag = me.nav_radio[radio].from_flag;
            me.nav_data[pilot][x_side].valid = me.nav_radio[radio].valid;
            me.nav_data[pilot][x_side].distance = me.nav_radio[radio].distanceN.getValue() or 0;
            # full deflection: VOR 2 dot = 10 deg; LOC 2 dot = 2 deg 
            var cdi_scale = (me.nav_radio[radio].isLoc) ? 0.5 : 0.1;
            me.nav_data[pilot][x_side].deviation = math.clamp(
                (me.nav_radio[radio].deviationN.getValue() or 0) * cdi_scale, -1, 1);
        } elsif (fms_id >= 0 and fms_id <= 1) {
            # FMS1/2
            me.nav_data[pilot][x_side].valid = 1;
            me.nav_data[pilot][x_side].dmeh = 0;
            me.nav_data[pilot][x_side].id = me.fms.wp0_idN.getValue() or "---";
            me.nav_data[pilot][x_side].crs = me.fms.wp0_bearingN.getValue() or 360;
            me.nav_data[pilot][x_side].distance = me.fms.wp0_distN.getValue() or 0;
            # according to docs instrumentation/gps/config/cdi-max-deflection-nm 
            # set to 5 in CRJ700-main.xml so no scaling needed here
            me.nav_data[pilot][x_side].deviation = 
                (me.fms.cdi_deflectionN.getValue() or 0) * 0.2;
        }        
        return me.nav_data[pilot][x_side];
    },

    update: func() {
        me._update(PILOT_SIDE, ON_SIDE);
        me._update(PILOT_SIDE, X_SIDE);
        me._update(COPILOT_SIDE, ON_SIDE);
        me._update(COPILOT_SIDE, X_SIDE);
    },

    getOnSideNavData: func(pilot) {
        return me.nav_data[pilot][0];
    },

    getXSideNavData: func(pilot) {
        return me.nav_data[pilot][1];
    },

    getBearingSrc: func(pilot, src) {
        if (me["bearing_src_selected"][pilot][src]) {
            return me["bearing_src_name"][pilot][src];
        }
        else return "";
    },

    bearingIndicatorIsVisible: func(pilot, src) {
        me["bearing_src_selected"][pilot][src];
    },

    #get bearing from currently selected b.source; src_num 0,1
    getBearing: func(pilot, src) {
        me._get_bearing[me["bearing_src_selected"][pilot][src]](src);
    },
    
    getNavSource: func(pilot) {
        return me.nav_src[pilot];
    },
    
    getNavSourceName: func(pilot, xside = 0) {
        if (!xside) return CRJ700.NAV_SRC[me.nav_src[pilot]];
    },
    
    getNavSrcColor: func(pilot) {
        return me.NAV_SRC_COLOR[pilot][me.nav_src[pilot]];
    },
    
    bsChanged: func (pilot,bs) {
        if (me._bs_changed[pilot][bs]) {
            me._bs_changed[pilot][bs] = 0;
            return 1;
        }
        return 0;
    },
    # not implemented yet
    addCallback: func(id, cb_func) {
        if (me._callbacks[id] == nil)
            me._callbacks[id] = [];
        append(me._callbacks[id], cb_func);
    },
};

#-- create one instance for pilot and one for copilot
var efis_ndc = NavDataController.new(PILOT_SIDE);
efis_ndc.init();
