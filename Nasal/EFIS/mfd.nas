#
# EFIS for CRJ700 family
# MFD page
# Author:  jsb
# Created: 11/2018
#-----------------------------------------------------------------------------
# Note
# PFD and MFD share some of the navigation information, e.g. Nav source info,
# HSI, bearing sources etc.
# Shared code is in a separate file
#-----------------------------------------------------------------------------

var MFDCanvas = {
    MFD_FORMATS: [
        "HSI",
        "NAV",      # Nav aid sector
        "PLAN",     # FMS plan
        "MAP",      # FMS present position map
        "RADAR",
        "TCAS",
    ],

    # id: 0=Pilot, 1=Copilot
    new: func(name, file, id, nav_data_controller) {
        var obj = {
            parents: [me , EFISCanvas.new(name)],
            id: id,
            map_ctrl_sid: "CRJ700-"~id,
            nav_data_controller: nav_data_controller,
            svg_keys: [
                "aircraft",
                "layer_HSI", "layer_NAV", "layer_PLAN", "layer_MAP", "layer_RADAR", "layer_TCAS",
                #"hsi",
                "tRadarMode", "gTimePerformance",
                "tUTC", "tTAS", "tGS", "tSAT", "tTAT",
                "utc", "tas", "gndSpeed", "sat", "tat",
                "gNavInfo", "gOnsideNav", "gXsideNav","gFMSinfo",
                "gHSI", "gNAV",
                "navSrc0", "navid0", "crs0", "distance0", "tDistUnit0", "tCRS0",
                "navSrc1", "navid1", "crs1", "distance1", "tDistUnit1", "tCRS1",
                "wind", "windPointer",
                "hdg_hsi", "hdgBug_hsi", "selHdg",
                "hdg_nav", "hdgBug_nav", "hdgMarker_nav",
                "gGS", "gsDiamond",
                "gCrsPtr0", "CRSNeedle0", "deviation0", "toFromFlag0",
                "gCrsPtr1", "CRSNeedle1", "deviation1",
                "gBrgInd0", "gBrgInd1",
                "brgSrc0", "brgSrc1",
                "brgPtr0", "brgPtr1", "brgPtr0_big", "brgPtr1_big",
                "radarRange", "radarRange2",
            ],
            format: 0,      #current display format (HSI, NAV, PLAN etc)
            nav_center: [500, 900],
            nav_radius: 520,
            bbox_navcmps: [],
            hsi_center: [500, 1200-435],
            hsi_radius: 360,
            plan_center: [500,700],
            plan_radius: 420,
            bearing_src0: 0,
            bearing_src1: 0,
            # cached props
            _hdg: 0,
            _wind: {from: 0, speed: 0},
            gs: 0,
            FMS: {wp_count: 0,},
            xside: 0,
        };
        obj.bbox_navcmps = [50, obj.nav_center[1] - obj.nav_radius * 1.15, 
                            940, obj.nav_center[1] - obj.nav_radius * 0.5];
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        obj.addUpdateFunction(obj.updateSlow, 1.2);
        obj.addUpdateFunction(obj.update, 0.166);
        return obj;
    },

    #-- setup listeners --
    init: func() {
        #setup colors
        foreach (var i; ["tUTC", "tTAS", "tGS", "tSAT", "tTAT"]) {
            me[i].setColor(me.colors["green"])
        }
        foreach (var i; ["tRadarMode","tUTC"]) {
            me[i].setColor(me.colors["cyan"])
        }
        me["gBrgInd"] = [me.gBrgInd0, me.gBrgInd1];
        me["brgSrc"] = [me.brgSrc0, me.brgSrc1];
        me["brgPtr_hsi"] = [me.brgPtr0, me.brgPtr1];
        me["brgPtr_big"] = [me.brgPtr0_big, me.brgPtr1_big];
        me["brgPtr"] = me["brgPtr_hsi"];
        
        me["brgPtr0_big"].setTranslation(me.nav_center);
        me["brgPtr1_big"].setTranslation(me.nav_center);
        #initially one layer per mode in SVG file, maybe cleanup later
        me.layers = [
            me["layer_HSI"],
            me["layer_NAV"],
            me["layer_PLAN"],
            me["layer_MAP"],
            me["layer_RADAR"],
            me["layer_TCAS"],
        ];
#-- FIXME: including the map code for ND functionality is work in progress
#-- map code ---------------------------------
        me.map = me.getRoot().createChild("map", "mymap")
            .set("screen-range", me.nav_radius)
            .set('z-index', 5);
        me.map.setClipByBoundingBox([50,400,950,1050]);
        me.map_ctrl = canvas.Map.Controller.get("Aircraft position");
        
        if (me.map_ctrl.SOURCES[me.map_ctrl_sid] == nil) {
            me.map_ctrl.SOURCES[me.map_ctrl_sid] = {
                getPosition: func subvec(geo.aircraft_position().latlon(), 0, 2),
                getAltitude: func getprop('/position/altitude-ft'),
                getHeading:  func {
                    if (me.aircraft_heading)
                        getprop('/orientation/heading-deg')
                    else 0
                },
                aircraft_heading: 1,
            };
        }
        me.map.setController("Aircraft position", me.map_ctrl_sid);

        # this will center the map
        me.map.setTranslation(me.nav_center);
        var r = func(name,vis=1,zindex=nil) return caller(0)[0];
        # TFC, APT and APS are the layer names as per $FG_ROOT/Nasal/canvas/map
        # and the names used in each .lcontroller file in this case, it will load
        # the traffic layer (TFC), airports (APT) 
        var map_layers = [
            r("WPT"), #waypoints
            r("RTE"), #route (magenta line)
            r('APT'), #airports
            r('TFC'),
            #r('RWY'), #runways (seems missaligned and CPU intensive )
        ];
        foreach(var type; map_layers) {
            me.map.addLayer(factory: canvas.SymbolLayer, type_arg: type.name, 
                visible: type.vis, priority: type.zindex,);
        }
#-- /end map code ---------------------------
        
        #-- HSI/compass is hybrid (SVG + canvas.draw code) --
        # HSI display mode 
        # create CompassInstrument for HSI
        me["_HSI"] = canvas.instruments.CompassInstrument
            .new(
                me["layer_HSI"].createChild("group", "hsi-compass"),
                me.hsi_radius, me.hsi_center, style_HSI)
            #.addElement("bp1" )
            .addInputs(HSI_inputs[me.id])
            .draw();
        # animation is handled by the object instead of me.update()
        me["_HSI"].start();
        
        # other display modes (NAV etc.)
        #hdgBug_nav is at [0,0] in SVG so move it into big-compass group 
        me["gNAV"].setTranslation([me.nav_center[0], me.nav_center[1]]);
        #me["gNAV"].setCenter([0, me.nav_radius]);
        #me["hdgBug_nav"].setTranslation([me.nav_center[0], me.nav_center[1] - me.nav_radius]);
        me["hdgBug_nav"].setTranslation([0, -me.nav_radius]);
        me["hdgBug_nav"].setCenter([0, me.nav_radius]);
        
        var navcompass = me["layer_NAV"].createChild("group", "big-compass")
                    .setClipByBoundingBox(me.bbox_navcmps);
        me["_NAVCOMP"] = canvas.instruments.CompassInstrument
            .new(navcompass, me.nav_radius, me.nav_center, style_NAV)
            .addInputs(HSI_inputs[me.id])
            #.addElement("hdgBug", me["hdgBug_nav"])
            .draw();
        
        canvas.draw.arc(me["layer_NAV"], me.nav_radius / 2, me.nav_center, -60, 285)
            .setVisible(1).setColor(me.colors["white"])
            .setStrokeLineWidth(3);
        me["hdgMarker_nav"].set("z-index", 1);
        
        
        #fixme: unsure about color coding 
        me["CRSNeedle1"].setColor(me.id ? me.colors["cyan"] : me.colors["magenta"]);
        me["gCrsPtr1"].hide();

        # PLAN 
        canvas.draw.circle(me["layer_PLAN"], me.plan_radius, me.plan_center)
            .setVisible(1).setColor(me.colors["white"])
            .setStrokeLineWidth(3);
        me["layer_PLAN"].createChild("text", "N")
            .setTranslation(me.plan_center[0], me.plan_center[1] - me.plan_radius)
            .setFontSize(40)
            .setText("N");
            
        var left = 60;
        var top = 164;
        var lineheight = 36;

        me["gFMSInfo"] = me.getRoot().createChild("group", "FMSInfo");
        me["FMSInfoLines"] = me["gFMSInfo"].createChildren("group", 4);
        forindex (var i; me["FMSInfoLines"]) {
            var l = me["FMSInfoLines"][i];
            me["FMSInfoLines"][i] = {
                grp: l, 
                id: l.createChild("text", "id"),
                dist: l.createChild("text", "dist"),
                eta: l.createChild("text", "eta"),
            };
            foreach (var key; ["id", "dist", "eta"]) {
                me["FMSInfoLines"][i][key]
                .setAlignment("left-top")
                .setFont("LiberationFonts/LiberationSans-Regular.ttf")
                .setFontSize(34);
            }            
            me["FMSInfoLines"][i].id
                .setTranslation(left, top + i*lineheight);
            me["FMSInfoLines"][i].dist
                .setAlignment("right-top")
                .setTranslation(left+300, top + i*lineheight);
            me["FMSInfoLines"][i].eta
                .setTranslation(left+350, top + i*lineheight);
        }
        me["FMSInfoLines"][0].grp.setColor(me.colors["cyan"]);
        me["FMSInfoLines"][1].grp.setColor(me.colors["magenta"]);
        me.FMS["currentN"] = props.getNode("/autopilot/route-manager/current-wp",1);
        me.FMS["routeN"] = props.getNode("/autopilot/route-manager/route",1);
        me.FMS["wp0N"] = props.getNode("/autopilot/route-manager/wp",1);
        me.FMS["wp1N"] = props.getNode("/autopilot/route-manager/wp[1]",1);
        me.FMS["wplastN"] = props.getNode("/autopilot/route-manager/wp-last",1);
        

        
        setlistener("/sim/time/utc/minute", func { me.updateUTC(); }, 1, 0);
        setlistener("controls/autoflight/heading-select", me._makeL_HdgSel(), 1, 0);
        setlistener("controls/efis/sidepanel["~me.id~"]/mfd-format", me._makeL_format(), 1, 0);
        setlistener("controls/efis/sidepanel["~me.id~"]/range-nm", me._makeL_range(), 1, 0);
        setlistener("controls/efis/sidepanel["~me.id~"]/nav-xside", me._makeL_xside(), 1, 0);
        setlistener("/autopilot/route-manager/route/num", me.updateFMSDestination(), 1, 0);
        setlistener("/instrumentation/nav["~me.id~"]/gs-in-range", func(n) {
            me.gs = n.getValue() or 0;
            me["gGS"].setVisible(me.gs);
        }, 1, 0);

        me.nav_data_controller.addCallback("dmeh", func(n) {});
    },

    #-- display format change --------------------------------------------------
    # Mode  Rdr Gen Nav Map BPt Cmp comment
    # PLAN  -   -   -   y   -   -   fms plan, North up, one circle+range 
    # MAP   y   y   -   y   (y) y   fms present pos map
    # NAV   y   y   y   -   (y) y   navaid sector map
    # HSI   y   y   y   -   (y) hsi     
    # RADAR y   y   -   -   -   -   weather/terrain (not implemented)
    # TCAS  y   y   -   -   -   -   TCAS circles
    #
    # Rdr   = Radar status line
    # Gen   = UTC,TAS,GS...
    # Nav   = Nav source info
    # Map   = waypoints and course lines
    # BPt   = Bearing pointers

    _makeL_format: func() {
        var wp = me.map.getLayer("WPT");
        var rte = me.map.getLayer("RTE");
        #-- show/hide elements depending on selected format
        return func(n) {
            me.format = n.getValue() or 0;
            var f = me.MFD_FORMATS[me.format];
            var visible = 0;
            
            me["tRadarMode"].setText(f); #for development

            visible = !(f == "PLAN");
            me["tRadarMode"].setVisible(visible);
            me["gTimePerformance"].setVisible(visible);
            me.map_ctrl.SOURCES[me.map_ctrl_sid].aircraft_heading = visible;
            me["aircraft"].setVisible(visible);

            if (!visible) {
                me.map.set("screen-range", me.plan_radius);
                me.map.setTranslation(me.plan_center);
            }
            else {
                me.map.set("screen-range", me.nav_radius);
                me.map.setTranslation(me.nav_center);
            }
            me["layer_PLAN"].setVisible(!visible);
            
            visible = (f == "PLAN" or f == "MAP");
            me.map.setVisible(visible);
            # wp.setVisible(visible);
            # rte.setVisible(visible);
            
            visible = (f == "HSI");
            if (visible) {
                me["aircraft"].setTranslation(me.hsi_center);
                me["brgPtr0"].setVisible(me["brgPtr"][0].getVisible());
                me["brgPtr1"].setVisible(me["brgPtr"][1].getVisible());
                me["brgPtr"] = me["brgPtr_hsi"];
                me._HSI.start();
            }
            else {
                me._HSI.stop();
            }
            me["layer_HSI"].setVisible(visible);
            me["gXsideNav"].setVisible(visible and me.xside);
            me["gCrsPtr1"].setVisible(visible and me.xside);
            
            visible = (f == "HSI" or f == "NAV");
            me["gNavInfo"].setVisible(visible);

            visible = (f == "MAP");
            me["gFMSInfo"].setVisible(visible);

            visible = (f == "NAV" or f == "MAP");
            if (visible) {
                me["aircraft"].setTranslation(me.nav_center);
                # switch elements for update()
                me["brgPtr0_big"].setVisible(me["brgPtr"][0].getVisible());
                me["brgPtr1_big"].setVisible(me["brgPtr"][1].getVisible());                
                me["brgPtr"] = me["brgPtr_big"];
                me._NAVCOMP.start();
            }
            else {
                me._NAVCOMP.stop();
            }
            me["layer_NAV"].setVisible(visible);
            #me["big-compass"].setVisible(visible);
        };
    },

    
    _makeL_range: func() {
        var apt = me.map.getLayer("APT");
        #var rwy = me.map.getLayer("RWY");
        return func(n) {
            var range = n.getValue();
            me["radarRange"].setText(sprintf("%d", range));
            me["radarRange2"].setText(sprintf("%d", range/2));
            #limit range for map code or it will hang loading tons of data
            if (range > 320) range = 320;
            apt.setVisible((range <= 80));
            #rwy.setVisible((range <= 20));
            me.map.setRange(range);
        };
    },

    _makeL_xside: func() {
        return func(n) {
            me.xside = n.getValue() or 0;
            if (me.MFD_FORMATS[me.format] == "HSI") {
                me["gXsideNav"].setVisible(me.xside);
                me["gCrsPtr1"].setVisible(me.xside);
            }
        };
    },

    updateUTC: func() {
        var pfx = "/sim/time/utc/";
        me.updateTextElement("utc", sprintf("%d:%d", getprop(pfx~"hour"), getprop(pfx~"minute")));
    },

    _makeL_HdgSel: func() {
        # selected heading readout shall be visible 3s on change
        var timer = maketimer(3, me, func {me["selHdg"].hide(); });
        timer.singleShot = 1;
        return func(n) {
            timer.stop();
            me.hdg_sel = n.getValue();
            me.updateTextElement("selHdg", sprintf("HDG %.0f", me.hdg_sel));
            me["selHdg"].show();
            me["hdgBug_hsi"].setRotation((me.hdg_sel) * D2R);
            me["hdgBug_nav"].setRotation((me.hdg_sel) * D2R);
            timer.start();
        };
    },

    #update nav readouts
    #param xside: 0 = onside, 1 = cross side
    #FIXME: split this into callback functions for nav_data_controller
    updateNav: func(xside, nav_data) {
        var color = (xside == ON_SIDE) ? "green" : "amber";
        if (!nav_data.valid) {
            if (xside) {
                me["gXsideNav"].hide();
                me["gCrsPtr1"].hide();
            }
            else {
                me["gOnsideNav"].hide();
                me["gCrsPtr0"].hide();
            }
            return;
        } else {
            if (xside and me.xside) {
                me["gXsideNav"].show();
                me["gCrsPtr1"].show();
            }
            else {
                me["gOnsideNav"].show();
                me["gCrsPtr0"].show();
            }
        }
        me.updateTextElement("navSrc"~xside, nav_data.src, color);
        me.updateTextElement("navid"~xside, nav_data.id, color);
        me.updateTextElement("crs"~xside, sprintf("%.0f", nav_data.crs), color);
        me["tCRS"~xside].setColor(color);
        me.updateTextElement("distance"~xside, sprintf("%.0f", nav_data.distance), color);
        if (nav_data.dmeh)
            me.updateTextElement("tDistUnit"~xside, "H", "amber");
        else
            me.updateTextElement("tDistUnit"~xside, "NM", color);
        me["gCrsPtr"~xside].setRotation(nav_data.crs * D2R);
        me["deviation"~xside].setTranslation(nav_data.deviation * 151, 0);
    },

    updateFMSDestination: func() {
        return func(num_wpN) {
            me.FMS.wp_count = num(num_wpN.getValue()) or 0;
            if (me.FMS.wp_count > 0) {
                var lastwp = me.FMS.routeN.getChild("wp", me.FMS.wp_count-1);
                me.FMS["last_idN"] = lastwp.getChild("id");
                debug.dump("MFDCanvas.updateFMSDestination:", me.FMS["last_idN"].getValue());
            }
            else me.FMS["last_idN"] = nil;
        };
    },
    
    etaSecondsToString: func(seconds) {
        if (seconds == nil or int(seconds) == nil)
            return "-:--";
        var h = int(seconds/3600);
        var m = int(seconds/60);
        return sprintf("%d:%02d", h, m);
    },

    updateFMSInfo: func() {
        var id = "";
        var distance = 0;
        var eta = "";
        var lineformat = "%-10s  %4d NM  %s";
        var current_wp = me.FMS.currentN.getValue();

        var updateLine = func (line, id, dist, eta) {
            me["FMSInfoLines"][line].id.setText(id);
            me["FMSInfoLines"][line].dist.setText(sprintf("%3d NM", dist));
            me["FMSInfoLines"][line].eta.setText(eta);
        }
        #-- active WP --
        id = me.FMS.wp0N.getChild("id").getValue();
        eta = me.etaSecondsToString(me.FMS.wp0N.getChild("eta-seconds").getValue());
        distance = me.FMS.wp0N.getChild("dist").getValue() or 0;
        updateLine(1, id, distance, eta);
        
        #-- previous WP (if available) --
        if (current_wp > 0) {
            id = getprop("/autopilot/route-manager/route/wp["~(current_wp-1)~"]/id");
            #compute distance as current leg - dist to active WP
            distance = getprop("/autopilot/route-manager/route/wp["~(current_wp)~"]/leg-distance-nm")
                - distance;
            eta = "";
            me["FMSInfoLines"][0].grp.show();
            updateLine(0, id, distance, eta);
        }
        else me["FMSInfoLines"][0].grp.hide();
        
        #-- next WP --
        id = me.FMS.wp1N.getChild("id").getValue();
        eta = me.etaSecondsToString(me.FMS.wp1N.getChild("eta-seconds").getValue());
        distance = me.FMS.wp1N.getChild("dist").getValue() or 0;
        updateLine(2, id, distance, eta);
        
        #-- destination WP --
        idlast = (me.FMS.last_idN != nil) ? me.FMS.last_idN.getValue() : "---";
        if (id != idlast) {
            distance = getprop("/autopilot/route-manager/wp-last/dist") or 0;
            eta = me.etaSecondsToString(getprop("/autopilot/route-manager/wp-last/eta-seconds"));
            me["FMSInfoLines"][3].grp.show();
            updateLine(3, idlast, distance, eta);
        }
        else me["FMSInfoLines"][3].grp.hide();
    },

    updateBrgSrcChanged: func(bs) {
        if (me.nav_data_controller.bearingIndicatorIsVisible(me.id, bs)) {
            var brgsrc = me.nav_data_controller.getBearingSrc(me.id, bs);
            me["gBrgInd"][bs].show();
            me["brgSrc"][bs].setText(brgsrc);
            me["brgPtr"][bs].show();
        }
        else {
            me["gBrgInd"][bs].hide();
            me["brgPtr"][bs].hide();
        }
    },

    updateSlow: func() {
        me._wind.from = getprop("environment/wind-from-heading-deg");
        me._wind.speed = getprop("environment/wind-speed-kt");
        me.updateTextElement("tas", sprintf("%.0f", getprop("instrumentation/airspeed-indicator/true-speed-kt")));
        me.updateTextElement("gndSpeed", sprintf("%.0f", getprop("velocities/groundspeed-kt")));
        me.updateTextElement("sat", sprintf("%.0fC", getprop("environment/temperature-degc")));
        me.updateTextElement("tat", sprintf("%.0fC", getprop("environment/total-air-temperature-degc")));
        me.updateTextElement("wind", sprintf("%d/%d", me._wind.from, me._wind.speed));
        me["windPointer"].setRotation((me._wind.from - me._hdg)*D2R);
        if (me.MFD_FORMATS[me.format] == "MAP") {
            me.updateFMSInfo();
        }    
    },
    
    update: func() {
        me._hdg = me.getInstr("heading-indicator", "indicated-heading-deg");
        me.updateTextElement("hdg_hsi", sprintf("%.0f", me._hdg));
        me.updateTextElement("hdg_nav", sprintf("%.0f", me._hdg));
        me["gHSI"].setRotation(-me._hdg * D2R);
        me["gNAV"].setRotation(-me._hdg * D2R);
        me.updateNav(ON_SIDE, me.nav_data_controller.getOnSideNavData(me.id));
        me.updateNav(X_SIDE, me.nav_data_controller.getXSideNavData(me.id));
        
        
        me["CRSNeedle0"].setColor(me.colors[me.nav_data_controller.getNavSrcColor(me.id)]);
        
        if (me.nav_data_controller.bsChanged(me.id, 0)) { me.updateBrgSrcChanged(0); }        
        if (me.nav_data_controller.bsChanged(me.id, 1)) { me.updateBrgSrcChanged(1); }
        me["brgPtr"][0].setRotation(me.nav_data_controller.getBearing(me.id, 0)*D2R);
        me["brgPtr"][1].setRotation(me.nav_data_controller.getBearing(me.id, 1)*D2R);

        if (me.gs) {
            me["gsDiamond"].setTranslation(0, -187.683 *
            me.getInstr("nav", "gs-needle-deflection-norm"));
        }
    },
};
