#
# EFIS for CRJ700 family
# PFD (Primary Flight Display)
# Author:  jsb
# Created: 11/2018
#-----------------------------------------------------------------------------
# Note
# PFD and MFD share some of the navigation information, e.g. Nav source info,
# HSI, bearing sources etc.
# Shared code is in a separate file
#-----------------------------------------------------------------------------

var speedtape_inputs = [
    {
        #tape: "/instrumentation/airspeed-indicator/indicated-speed-kt",
        tape: "/_test/speed-kt",
        speed_bug: "/controls/autoflight/speed-select",
    },    
    {
        #tape: "/instrumentation/airspeed-indicator/indicated-speed-kt",
        tape: "/_test/speed-kt",
        speed_bug: "/controls/autoflight/speed-select",
    },
];

var style_speedtape = canvas.Scale.Style.new();
style_speedtape.setSpacing(20)
    .setBaselineWidth(2)
    .setMarkWidth(2)
    .setMarkLength(0.4)
    .setMarkOffset(style_speedtape.MARK_LEFT)
    .setSubdivisions(1);

var PFDCanvas = {
    __class_name: "PFDCanvas",
    
    # id: {0,1}
    new: func(name, file, id, nav_data_controller) {
        var obj = {
            parents: [me , EFISCanvas.new(name)],
            id: id,
            nav_data_controller: nav_data_controller,
            svg_keys: [
                "horizon","rollpointer","rollpointer2","asi.tape","vmo.tape",
                "lowspeed.tape","predict.up","predict.down",
                "iasref.text","iasref.bug", "mach_readout",
                "vrefs", "v1.ref", "vr.ref", "v2.ref", "vt.ref",
                "vsi.needle","vsi.text",
                "altimeter-setting", "altimeter-unit",
                "halfbank",
                "alt.tape","alt1000", "alt.bug", "selected_alt",
                "preselected.meter","ind.meter","metricalt",
                "radioalt.text","radioalt.tape",
                "dh.text","dh.flag",
                "FD", "GS",
                #"ADF1.flag","ADF1.needle","ADF2.flag","ADF2.needle",
                "navsrc","nav.src","nav.crs","nav.dist", "nav.distunit",
                "nav.name",
                "navIndicator", "navNeedle","navDeviationBar", "toFromFlag",
                "marker","marker.text","marker.box",
                "mda.flag","mda.text",
                "hdgBug","selHdg",
                "preselected.1000","preselected.100",
                "lat.act","vert.act",
                "vert.arm","lat.arm",
                "GSarmed",
                "ap.flag",
                "gBrgInd0", "gBrgInd1",
                "brgSrc0", "brgSrc1",
                "brgPtr0", "brgPtr1",
            ],

            asi_timers: {},  #timers to hide speed ref bugs
            
            #scaling factors for animations
            asi_scale: 6.38,
            alt_scale: 1.188,
            alt_scroll_range: 100,

            #cached properties
            asi_ref: {},
            dmeh: 0,
            fd: 0,
            gs: 0,
            dh: 300,
            mda: 3000,
            nav_source: 0,
            alt_sel: 0,
            hdg_sel: 0,
            use_metric: 0,
            use_QNH: 1,
            wow1: 0,

            hsi_center: [500, 1200-180],
            hsi_radius: 260,
        };
        obj.alt_scroll_stop = obj.alt_scroll_range * 0.25;
        obj.alt_scroll_start = obj.alt_scroll_range * 0.75;
        obj.loadSVG(file, obj.svg_keys);
        obj.init();
        obj.addUpdateFunction(obj.update, 0.033);
        obj.addUpdateFunction(obj.updateSlow, 0.2);
        return obj;
    },

    init: func(){
        setprop("/devel/pfd/pitch", 0);
        setprop("/devel/pfd/roll", 0);
        setprop("/devel/pfd/ias", 170);
        me.h_trans = me["horizon"].createTransform();
        me.h_rot = me["horizon"].createTransform();
        me["rollpointer"].setCenter(me["horizon"].getCenter());
        var mbtxt = me["marker.text"];
        mbtxt.setDrawMode(mbtxt.TEXT + mbtxt.BOUNDINGBOX);
        var indent = 0;
        foreach (var key; ["v1.bug", "vr.bug", "v2.bug", "vt.bug"]) {
            if (indent == 0) indent = 15;
            else indent = 0;
            me[key] = me["asi.tape"].createChild("group", key);
            me[key].createChild("path", key~".bar")
                .move(0,0).lineTo(40,0)
                .setStrokeLineWidth(3);
            me[key].createChild("text", key~".txt")
                .setText(string.uc(chr(key[1])))
                .setAlignment("left-center")
                .setFontSize(36)
                .setFont(canvas.font_mapper("", "bold"))
                .setTranslation(40 + indent, 0);
            me[key].setColor(me.colors["cyan"]);
        }
        # me["asi.tape"].hide();
        # me["_speedtape"] = canvas.instruments.SpeedTape.new(
                # me.getRoot().createChild("group", "speedtape"),
                # [12, 500], [130, 512], style_speedtape)
            # .addInputs(speedtape_inputs[me.id])
            # .draw();
        # debug.dump(me["_speedtape"]);
        # animation is handled by the object instead of me.update()
        #me["_speedtape"].start();

        me["alt1000"].setText(sprintf("%2d\n%2d", 1, 0));
        me["alt1000"].updateCenter();
        var tmp = me["alt1000"].getBoundingBox();
        var sy = tmp[3] - tmp[1];
        me.alt1000_scale = 0.5 * sy / me.alt_scroll_range;
        
        me["compass"] = me.getRoot().createChild("group", "compass");
        me["_HSI"] = canvas.instruments.CompassInstrument
            .new(me["compass"], me.hsi_radius, me.hsi_center, style_HSI)
            .addInputs(HSI_inputs[me.id])
            .draw()
            ;
        #me._updateClip("compass");
        #me["_HSI"].start();
        me["gBrgInd"] = [me.gBrgInd0, me.gBrgInd1];
        me["brgSrc"] = [me.brgSrc0, me.brgSrc1];
        me["brgPtr"] = [me.brgPtr0, me.brgPtr1];

        #simple show/hide
        setlistener("/autopilot/internal/autoflight-engaged", me._makeListener_showHide("ap.flag"), 0, 0);
        setlistener("/autopilot/annunciators/altitude-flash/state", me._makeListener_showHide("selected_alt", 0), 0, 0);
        setlistener("/autopilot/annunciators/gs-armed", me._makeListener_showHide("GSarmed"), 1, 0);
        setlistener("/controls/autoflight/half-bank", me._makeListener_showHide("halfbank"), 1, 0);
        setlistener("/controls/autoflight/flight-director/engage", me._makeListener_showHide("FD"), 1, 0);
        setlistener("/instrumentation/nav["~me.id~"]/gs-in-range", me._makeListener_showHide("GS"), 1, 0);

        #cache some prop values for update()
        setlistener("/controls/autoflight/altitude-select", me._makeL_altSelect(), 1, 0);
        setlistener("/controls/autoflight/flight-director/engage", func(n) { me.fd = n.getValue() or 0;}, 1, 0);
        #setlistener("/controls/autoflight/nav-source", func(n) { me.nav_source = n.getValue() or 0; }, 1, 0);
        setlistener("/gear/gear[1]/wow", func(n) { me.wow1 = n.getValue() or 0; }, 1, 0);
        setlistener("/instrumentation/use-metric-altitude", func(n) { me.use_metric = n.getValue() or 0; }, 1, 0);
        setlistener("/instrumentation/nav["~me.id~"]/gs-in-range", func(n) { me.gs = n.getValue() or 0;}, 1, 0);
        #
        setlistener("/controls/autoflight/heading-select", me._makeL_hdgSelect(), 1, 0);
        setlistener("/controls/autoflight/speed-select", me._makeListener_updateText("iasref.text", "%d", 0), 1, 0);
        setlistener("/instrumentation/adc["~me.id~"]/reference/dh", me._makeL_dh(), 1, 0);
        setlistener("/instrumentation/adc["~me.id~"]/reference/mda", me._makeL_mda(), 1, 0);
        setlistener("/instrumentation/dme["~me.id~"]/hold", me._makeL_dmeh(), 1, 0);
        setlistener("/instrumentation/marker-beacon/outer", me._makeL_markerBeacon(0), 1, 0);
        setlistener("/instrumentation/marker-beacon/middle", me._makeL_markerBeacon(1), 1, 0);
        setlistener("/instrumentation/marker-beacon/inner", me._makeL_markerBeacon(2), 1, 0);
        setlistener("/instrumentation/adc/reference/v1", me._makeL_asiref("1", "V1 %3d", 0), 1, 0);
        setlistener("/instrumentation/adc/reference/vr", me._makeL_asiref("r", "VR %3d", 0), 1, 0);
        setlistener("/instrumentation/adc/reference/v2", me._makeL_asiref("2", "V2 %3d", 0), 1, 0);
        setlistener("/instrumentation/adc/reference/vt", me._makeL_asiref("t", "VT %3d", 0), 1, 0);
        me.qnhN = props.getNode("/instrumentation/altimeter["~me.id~"]/setting-hpa");
        setlistener(me.qnhN, me._makeL_altimeterSetting(), 1, 1);
        setlistener("/controls/efis/sidepanel["~me.id~"]/use-QNH", me._makeL_altimeterUnit(), 1);

        setlistener("/autopilot/annunciators/lat-armed", me._makeListener_updateText("lat.arm"), 1, 0);
        setlistener("/autopilot/annunciators/vert-armed", me._makeListener_updateText("vert.arm"), 1, 0);
        setlistener("/autopilot/annunciators/lat-capture", me._makeListener_updateText("lat.act"), 1, 0);
        setlistener("/autopilot/annunciators/vert-capture", me._makeListener_updateText("vert.act"), 1, 0);

    },

    _makeL_asiref: func(x) {
        var X = string.uc(x);
        var ref = "v"~x~".ref";
        var bug = "v"~x~".bug";
        me.asi_timers[x] = maketimer(7, me, func { me[bug].hide();});
        me.asi_timers[x].singleShot = 1;
        return func(n) {
            me.asi_ref[x] = n.getValue() or 100;
            me.updateTextElement(ref, sprintf("V"~X~" %3d", me.asi_ref[x]));
            me[bug].setTranslation(110, (me.asi_ref[x] - 55) * -me.asi_scale);
        };
    },

    _makeL_altSelect: func {
        return func(n) {
            me.alt_sel = n.getValue() or 0;
            me.updateTextElement("preselected.1000", sprintf("%2d",math.floor(me.alt_sel/1000)));
            me.updateTextElement("preselected.100", sprintf("%03d",math.mod(me.alt_sel, 1000)));
            me.updateTextElement("preselected.meter", sprintf("%5d", me.alt_sel*FT2M));
        };
    },

    _makeL_dh: func {
        return func(n) {
            me.dh = n.getValue() or 0;
            me.updateTextElement("dh.text", sprintf("%3.0f", me.dh));
        };
    },

    _makeL_mda: func {
        return func(n) {
            me.mda = n.getValue() or 0;
            me.updateTextElement("mda.text", sprintf("%4d", me.mda));
        };
    },

    _makeL_dmeh: func {
        return func(n) {
            me.dmeh = n.getValue() or 0;
            if (me.dmeh) {
                me.updateTextElement("nav.distunit", "H", me.colors["yellow"]);
                me["nav.name"].hide();
            }
            else {
                var ns = getprop("/controls/autoflight/nav-source");
                me.updateTextElement("nav.distunit", "NM", 
                    me.nav_data_controller.getNavSrcColor(me.id));
                me["nav.name"].show();
            }
        };
    },

    _makeL_markerBeacon: func(type) {
        var beacons = [
            {text: "OM", color: me.colors["cyan"]},
            {text: "MM", color: me.colors["yellow"]},
            {text: "IM", color: me.colors["white"]},
        ];
        return func(n) {
            var value = n.getValue() or 0;
            if (value) me["marker"].show();
            else me["marker"].hide();
            me["marker.text"].setText(beacons[type].text);
            me["marker.text"].setColor(beacons[type].color);
        };
    },

    _makeL_hdgSelect: func() {
        return func(n) {
            me.hdg_sel = n.getValue() or 0;
            me["selHdg"].setText(sprintf("%3d",me.hdg_sel));
        };
    },

    _makeL_altimeterUnit: func() {
        return func(n) {
            me.use_QNH = n.getValue(); 
            me.qnhN.setValue(me.qnhN.getValue()); #trigger listener
        };
    },

    _makeL_altimeterSetting: func() {
        return func(n) {
            me.altimeter_setting = me.use_QNH ? n.getValue() :
                    n.getParent().getChild("setting-inhg").getValue();
            if (me.use_QNH) me.updateTextElement("altimeter-setting", sprintf("%0d", me.altimeter_setting));
            else me.updateTextElement("altimeter-setting", sprintf("%2.2f", me.altimeter_setting));
            me.updateTextElement("altimeter-unit", me.use_QNH ? "hPa" : "IN");
        };
    },

    updateSlow: func() {
        var asi = me.getInstr("airspeed-indicator", "indicated-speed-kt");
        if (asi > me.asi_ref["1"] and !me.asi_timers["1"].isRunning) {
            me.asi_timers["1"].start();
            me["_asi_has_hidden"] = 1;
        }
        if (asi > me.asi_ref["r"] and !me.asi_timers["r"].isRunning) 
            me.asi_timers["r"].start();
        if (asi > me.asi_ref["2"] and !me.asi_timers["2"].isRunning) 
            me.asi_timers["2"].start();
        if (asi < 50 and me["_asi_has_hidden"]) {
            me["v1.bug"].show();
            me["v2.bug"].show();
            me["vr.bug"].show();
            me["_asi_has_hidden"] = 0;
        }
    },

    update: func() {
        #-- Attitude indicator
        var pitch = me.getInstr("attitude-indicator", "indicated-pitch-deg");
        var roll =  me.getInstr("attitude-indicator", "indicated-roll-deg") * -D2R;
        var heading = me.getInstr("heading-indicator", "indicated-heading-deg");

        if (me.debugN.getValue()) {
            pitch = getprop("/devel/pfd/pitch");
            roll = getprop("/devel/pfd/roll")*-D2R;
        }
        me.h_trans.setTranslation(0, 12.8 * pitch);
        me.h_rot.setRotation(roll, me["horizon"].getCenter());
        #me["horizon"].setTranslation(0, 12.8 * pitch);
        #me["horizon"].setRotation(roll);

        #-- Flightdirector
        if (me.fd) {
            me["FD"].setTranslation(0, 12.8 * me.getInstr("efis/pfd", "fd-pitch-deg"));
            me["FD"].setRotation(me.getInstr("efis/pfd", "fd-roll-deg") * D2R);
        }

        me["rollpointer"].setRotation(roll);
        me["rollpointer2"].setTranslation(math.round(me.getInstr("slip-skid-ball", "indicated-slip-skid",0))*5, 0);

        #-- AirSpeedIndicator
        var asi = me.getInstr("airspeed-indicator", "indicated-speed-kt");
        if (me.debugN.getValue()) asi = getprop("/devel/pfd/ias");
        var mach = me.getInstr("airspeed-indicator", "indicated-mach");
        var a = (asi < 40) ? 40 : asi;

        me["asi.tape"].setTranslation(0, a * me.asi_scale);
        me["vrefs"].setTranslation(0, a * me.asi_scale);
        var vmo = me.getInstr("efis/pfd", "vmo",0);
        me["vmo.tape"].setTranslation(0,vmo*(-me.asi_scale));

        if (mach < 0.40) {
            me["mach_readout"].hide();
        }
        else {
            me["mach_readout"].setText(sprintf("M .%3d", 1000*mach));
            if (mach > 0.45) me["mach_readout"].show();
        }
        #fixme: find/use better value for Vstall, 120kt is just a guess
        if (getprop("/gear/gear[1]/wow") == 0) {
            me["lowspeed.tape"].show();
            me["lowspeed.tape"].setTranslation(0, -110 * me.asi_scale);
        } else {
            me["lowspeed.tape"].hide();
        }

        if (asi > 40) {
            var predict = me.getInstr("efis/pfd", "asi-predict-diff-damped");
            if (predict > 0) {
                me["predict.up"].show();
                me["predict.down"].hide();
                if (predict < 39) {
                    me["predict.up"].setTranslation(0, -predict * me.asi_scale);
                } 
                else {
                    me["predict.up"].setTranslation(0, -39 * me.asi_scale);
                }
            }
            elsif (predict < 0) {
                me["predict.up"].hide();
                me["predict.down"].show();
                if (predict > -39) {
                    me["predict.down"].setTranslation(0, -predict * me.asi_scale);
                } else {
                    me["predict.down"].setTranslation(0, 39 * me.asi_scale);
                }
            }
        }
        else {
            me["predict.up"].hide();
            me["predict.down"].hide();
        }
        var ias_ref_diff = me.getInstr("efis/pfd", "ias-ref-diff");
        me["iasref.bug"].setTranslation(0, -ias_ref_diff * me.asi_scale);

        # me["v1.bug"].setTranslation(0, me.getInstr("adc", "v1-diff") * -me.asi_scale);
        # me["vr.bug"].setTranslation(0, me.getInstr("adc", "vr-diff") * -me.asi_scale);
        # me["v2.bug"].setTranslation(0, me.getInstr("adc", "v2-diff") * -me.asi_scale);
        # me["vt.bug"].setTranslation(0, me.getInstr("adc", "vt-diff") * -me.asi_scale);

        if (me.gs) {
            me["GS"].setTranslation(0,-187.683 * 
                me.getInstr("nav", "gs-needle-deflection-norm"));
        }

        #-- Altimeter
        var altitude = me.getInstr("altimeter", "indicated-altitude-ft");
        var amod1000 = math.mod(altitude, 1000);
        me["alt.tape"].setTranslation(0, amod1000 * me.alt_scale);
        amod1000 -= math.mod(me.alt_sel, 1000);
        me["alt.bug"].setTranslation(0, amod1000 * me.alt_scale);
        if (math.abs(altitude - me.alt_sel) > 300) {
            me["alt.bug"].hide();
        } else {
            me["alt.bug"].show();
        }
        #scroll the altitude thousands near 1000-boundary
        var alt_k = math.floor((altitude - me.alt_scroll_stop)/1000);
        me["alt1000"].setText(sprintf("%2d\n%2d", alt_k + 1, alt_k));
        var scroll = math.mod((altitude + me.alt_scroll_start), 1000);
        if (scroll <= me.alt_scroll_range) {
            me["alt1000"].setTranslation(0, me.alt1000_scale * scroll);
        }
        else {
            me["alt1000"].setTranslation(0,0);
        }

        if (me.use_metric) {
            me["metricalt"].show();
            me["ind.meter"].setText(sprintf("%5d", altitude*FT2M));
        } else {
            me["metricalt"].hide();
        }

        #Radio Altimeter
        #var radioalt = getprop("/position/gear-agl-ft") or 0;
        var radio_altitude = me.getInstr("radar-altimeter", "radar-altitude-ft");
        if (radio_altitude < 2500 and me.wow1 == 0) {
            me["radioalt.text"].show();
            if (radio_altitude < 1225) {
                me["radioalt.tape"].show();
                me["radioalt.tape"].setTranslation(0,radio_altitude*0.934);
            }
            else me["radioalt.tape"].hide();

            if (radio_altitude < me.dh) {
                me.updateTextElement("radioalt.text", sprintf("%4d FT", radio_altitude) , me.colors["yellow"]);
                me["dh.flag"].show();
            }
            else {
                me.updateTextElement("radioalt.text", sprintf("%4d FT", radio_altitude) , me.colors["green"]);
                me["dh.flag"].hide();
            }
        }
        else me["radioalt.text"].hide();

        #MDA
        if (me.wow1 == 0 and altitude < me.mda) {
            me["mda.flag"].show();
        }
        else me["mda.flag"].hide();

        #-- Compass --
        me["_HSI"].update();
        me["hdgBug"].setRotation((me.hdg_sel - heading) * D2R);

        #-- bearing pointers
        foreach (var i; [PILOT_SIDE, COPILOT_SIDE]) {
            if (me.nav_data_controller.bearingIndicatorIsVisible(me.id, i)) {
                var brgsrc = me.nav_data_controller.getBearingSrc(me.id, i);
                me["gBrgInd"][i].show();
                me["brgSrc"][i].setText(brgsrc);
                me["brgPtr"][i].setRotation(me.nav_data_controller.getBearing(me.id, i)*D2R);
            }
            else me["gBrgInd"][i].hide();
        }

        #FMS 1/2, NAV 1/2
        var nav_data = me.nav_data_controller.getOnSideNavData(me.id);
        var nsn = me.nav_data_controller.getNavSourceName(me.id);
        if (nsn == nil or nsn == "") {
            me["navsrc"].hide();
            me["navIndicator"].hide();
        }
        else {
            me["navsrc"].show();
            me["navIndicator"].show();
            var color = me.nav_data_controller.getNavSrcColor(me.id);
            color = me.colors[color];
            if (!me.dmeh) me["nav.distunit"].setColor(color);
            me.updateTextElement("nav.src", nav_data.src, color);
            me.updateTextElement("nav.crs", sprintf("CRS %03d", nav_data.crs), color);
            me.updateTextElement("nav.dist", nav_data.distance ? sprintf("%3.1f", nav_data.distance) : "XX", color);
            me.updateTextElement("nav.name", nav_data.id, color);
            me["navNeedle"].setColor(color);
            me["toFromFlag"].setRotation(nav_data.from_flag ? 180*D2R : 0);
            
            if (nsn == "FMS"){
                me["navIndicator"].setRotation(bearing*D2R);
                me["navDeviationBar"].setTranslation((getprop("/autopilot/route-manager/deviation-deg")or 0)*32.5,0);
            }
            else {
                me["navIndicator"].setRotation((nav_data.crs - heading)*D2R);
                me["navDeviationBar"].setTranslation(nav_data.deviation * 130,0);
            }
        }

        #-- VSI --
        var vsi = me.getInstr("efis/pfd", "vsi");
        me["vsi.needle"].setRotation(vsi*D2R);
        var vsi_value = me.getInstr("vertical-speed-indicator","indicated-speed-fpm");
        if (vsi < 1000 and vsi > -1000) {
            me["vsi.text"].setText(sprintf("%.1f", vsi_value/1000));
        }
        else me["vsi.text"].setText(sprintf("%2d", vsi_value/1000));
    }, #end update()
};
