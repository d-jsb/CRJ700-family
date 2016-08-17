#-------------------------------------------------------------------------------
# Bombardier CRJ700 series
# autopilot.nas
# - MCP handling
# - AP mode logic
# - annunciators
#-------------------------------------------------------------------------------

# Properties:
# /controls/mcp/*                     used for MCP push buttons and status LEDs
# /controls/autoflight/autopilot/engage           autopilot on/off
# /controls/autoflight/flight-director/engage     flight director on/off

# /autopilot/internal/roll-mode               basic roll mode
# /autopilot/ref/roll-hdg                     basic roll mode heading setting
# /autopilot/ref/roll-deg                     basic roll mode roll setting
# /controls/autoflight/pitch-select           basic pitch mode setting
# /controls/autoflight/altitude-select        altitude setting
# /autopilot/internal/bank-limit-deg          bank angle setting
# /controls/autoflight/heading-select         heading setting
# /controls/autoflight/mach-select            mach speed setting
# /controls/autoflight/speed-select           IAS speed setting
# /controls/autoflight/vertical-speed-select  vertical speed seting

# /controls/autoflight/lat-mode               lateral mode
# /controls/autoflight/vert-mode              vertical mode
# /controls/autoflight/speed-mode             speed mode
# /controls/autoflight/nav-source             nav mode

var NAV_SRC = ["", "NAV1", "NAV2", "FMS1", "FMS2"];

var ap_speed_mode = {
    IAS: 0,
    mach: 1,
};

var ap_lat_mode = {
    basic: 0,
    hdg: 1,         # heading mode
    nav: 2,
    appr: 3,        # approach mode
    back: 4,
    half_bank: 5,   # (inhibited when in TO/GA, approach or nav mode)
    TO: 6,          # take off mode
    GA: 7,          # go around mode
};

var ap_vert_mode = {
    basic: 0,
    alth: 1,        # altitude (hold)
    VS: 2,          # vertical speed
    alt: 3,         # altitude (track)
    speed: 4,       # speed mode (this is NOT an auto throttle but a vertical (pitch) mode!)
    GS: 5,          # glideslope mode
    TO: 6,          # take off mode
    GA: 7,          # go around mode
};
#-------------------------------------------------------------------------------
var mcp_prefix = "controls/mcp/";
var ap_prefix = "controls/autoflight/";

var N = {
    vert_mode:  props.getNode(ap_prefix~"vert-mode", 1),
    lat_mode:   props.getNode(ap_prefix~"lat-mode", 1),
    speed_mode: props.getNode(ap_prefix~"speed-mode", 1),
    ind_hdg:    props.getNode("instrumentation/heading-indicator/indicated-heading-deg", 1),
    gs_armed:   props.getNode("/autopilot/annunciators/gs-armed", 1),
};
#-- MCP toggles  ---------------------------------------------------------------
setlistener(mcp_prefix~"fd-pressed", func(n) {
    if (n.getValue())
        setprop(ap_prefix~"flight-director/engage",
        !getprop(ap_prefix~"flight-director/engage"));
},0,1);

setlistener(mcp_prefix~"ap-pressed", func(n) {
    if (n.getValue() and !getprop(mcp_prefix~"disc-pos")) {
        setprop(ap_prefix~"autopilot/engage",
        !getprop(ap_prefix~"autopilot/engage"));
    }
},0,1);

setlistener(mcp_prefix~"disc-pos", func(n) {
    if (n.getValue())
        setprop(ap_prefix~"autopilot/engage", 0);
},0,1);

setlistener(mcp_prefix~"bank-pressed", func(n) {
    if (n.getValue()) {
        var lm = N["lat_mode"].getValue();
        if (lm != ap_lat_mode["nav"] and lm != ap_lat_mode["appr"] and
            lm != ap_lat_mode["TO"] and lm != ap_lat_mode["GA"]) {
            var hb = !getprop(ap_prefix~"half-bank");
            setprop(ap_prefix~"half-bank", hb);
        }
    }
},0,1);

#-- MCP lateral mode selectors -------------------------------------------------
var _makeL_lat_mode_btn = func(id) {
    return func(n) {
        if (n.getValue()) {
            setprop(ap_prefix~"flight-director/engage", 1);
            if (N["lat_mode"].getValue() != ap_lat_mode[id]) {
                N["lat_mode"].setValue(ap_lat_mode[id]);
            } else {
                N["lat_mode"].setValue(ap_lat_mode["basic"]);
            }
        }
    };
};

setlistener(mcp_prefix~"appr-pressed", _makeL_lat_mode_btn("appr") , 0, 1);
setlistener(mcp_prefix~"hdg-pressed", _makeL_lat_mode_btn("hdg"), 0, 1);
setlistener(mcp_prefix~"nav-pressed", _makeL_lat_mode_btn("nav"), 0, 1);

#-- MCP vertical mode selectors ------------------------------------------------
var _makeL_vert_mode_btn = func(id) {
    return func(n) {
        if (n.getValue()) {
            setprop(ap_prefix~"flight-director/engage", 1);
            if (N["vert_mode"].getValue() != ap_vert_mode[id]) {
                N["vert_mode"].setValue(ap_vert_mode[id]);
            } else {
                N["vert_mode"].setValue(ap_vert_mode["basic"]);
            }
        }
    }
};
setlistener(mcp_prefix~"speed-pressed", _makeL_vert_mode_btn("speed"), 0, 1);
setlistener(mcp_prefix~"vs-pressed", _makeL_vert_mode_btn("VS"), 0, 1);
setlistener(mcp_prefix~"alt-pressed", func(n) {
    if (n.getValue()) {
        setprop(ap_prefix~"flight-director/engage", 1);
        var vm = N["vert_mode"].getValue();
        # selection of ALT hold mode is inhibited in GS mode
        if (vm != ap_vert_mode["GS"]) {
            if (vm != ap_vert_mode["alth"]) {
                N["vert_mode"].setValue(ap_vert_mode["alth"]);
            } else {
                N["vert_mode"].setValue(ap_vert_mode["basic"]);
            }
        }
    }
}, 0, 1);

#-- MCP rotate selector knobs --------------------------------------------------
setlistener(mcp_prefix~"speed-selector-pressed", func(n) {
    if (n.getValue()) {
        N["speed_mode"].setValue(!N["speed_mode"].getValue());
    }
},0,1);

setlistener(mcp_prefix~"hdg-selector-pressed", func(n) {
    if (n.getValue()) {
        setprop("controls/autoflight/heading-select", N["ind_hdg"].getValue());
    }
},0,1);

#-- reference synchronisation --------------------------------------------------
# Basic roll mode sync
var roll_sync = func()
{
    #print("sync roll/hdg");
    var roll = getprop("instrumentation/attitude-indicator[0]/indicated-roll-deg") or 0;
    if (math.abs(roll) > 5)
    {
        setprop("autopilot/internal/roll-mode", 1);
        setprop("autopilot/ref/roll-deg", roll);
    }
    else
    {
        var heading = N["ind_hdg"].getValue() or 0;
        setprop("autopilot/internal/roll-mode", 0);
        setprop("autopilot/ref/roll-hdg", heading);
    }
};

# Basic pitch mode sync
var pitch_sync = func()
{
    var vmode = N["vert_mode"].getValue();
    #print("sync pitch (m:"~vmode~")");
    if (vmode == ap_vert_mode["alth"]) { 
        setprop("autopilot/ref/alt-hold", int(getprop("instrumentation/altimeter[0]/indicated-altitude-ft")));
    } elsif (vmode == ap_vert_mode["VS"]) { 
        setprop(ap_prefix~"vertical-speed-select",
            getprop("instrumentation/vertical-speed-indicator[0]/indicated-speed-fpm"));
        interpolate(ap_prefix~"vertical-speed-select",
            int(getprop("instrumentation/vertical-speed-indicator[0]/indicated-speed-fpm")/100)*100, 0.5);
    } elsif (vmode == ap_vert_mode["alt"]) {
        setprop("autopilot/ref/alt-hold", getprop(ap_prefix~"altitude-select"));
    } elsif (vmode == ap_vert_mode["speed"]) {
        setprop(ap_prefix~"speed-select",
            int(getprop("instrumentation/airspeed-indicator/indicated-speed-kt")));
        setprop(ap_prefix~"mach-select",
            getprop("instrumentation/airspeed-indicator/indicated-mach"));
    } elsif (vmode == ap_vert_mode["basic"]) { 
        var pitch = getprop("instrumentation/attitude-indicator[0]/indicated-pitch-deg");
        setprop(ap_prefix~"pitch-select", pitch);
        interpolate(ap_prefix~"pitch-select",
            int((pitch / 0.5) + 0.5) * 0.5, 0.5); # round to 0.5 steps
    }
};

# sync
setlistener(ap_prefix~"flight-director/sync", func(n)
{
    if (!n.getBoolValue()) return;
    if (getprop(ap_prefix~"autopilot/engage")) return;
    #print("sync");
    roll_sync();
    pitch_sync();
    n.setBoolValue(0);
}, 0, 0);

setlistener("autopilot/internal/autoflight-engaged", func(n)
{
    if (n.getBoolValue()) {
        var lm = N["lat_mode"].getValue();
        var vm = N["vert_mode"].getValue();
        setprop(ap_prefix~"flight-director/engage", 1);
        #clear toga
        if (lm == ap_lat_mode["TO"] or lm == ap_lat_mode["GA"]) {
            lm = ap_lat_mode["basic"];
            N["lat_mode"].setValue(lm);
        }
        if (vm == ap_vert_mode["TO"] or vm == ap_vert_mode["GA"]) {
            vm = ap_vert_mode["basic"];
            N["vert_mode"].setValue(vm);
        }
        if (lm == 0) roll_sync();
        if (vm == 0) pitch_sync();
    }
}, 0, 0);

setlistener(ap_prefix~"flight-director/engage", func(n) {
    if (!n.getValue()) {
        setprop(ap_prefix~"autopilot/engage", 0);
        }
    N["lat_mode"].setValue(ap_lat_mode["basic"]);
    N["vert_mode"].setValue(ap_vert_mode["basic"]);
}, 0, 0);

#-- TO/GA mode -----------------------------------------------------------------
setlistener(ap_prefix~"toga-button", func (n)
{
    var on_ground = getprop("gear/gear[1]/wow");
    if (n.getValue()) {
        setprop(ap_prefix~"autopilot/engage", 0);
        setprop(ap_prefix~"flight-director/engage", 1);
        setprop(ap_prefix~"half-bank", 0);
        if (on_ground) {
            N["lat_mode"].setValue(ap_lat_mode["TO"]);
            N["vert_mode"].setValue(ap_vert_mode["TO"]);
        }
        else {
            N["lat_mode"].setValue(ap_lat_mode["GA"]);
            N["vert_mode"].setValue(ap_vert_mode["GA"]);
        }
        setprop(ap_prefix~"pitch-select", 10);
        setprop("autopilot/internal/roll-mode", 0);
        setprop("autopilot/ref/roll-hdg",
            N["ind_hdg"].getValue());
        n.setBoolValue(0);
    }
}, 1, 0);

var gs_rangeL = nil;
var gs_captureL = nil;
# catch GS if in range and FD in approach mode
var gs_mon = func(n)
{
    if (getprop("instrumentation/nav[0]/gs-in-range") == 0) return;

    var lm = N["lat_mode"].getValue();
    #if not in APPR mode, cancel GS monitoring
    if (lm != ap_lat_mode["appr"] and gs_captureL != nil) {
        removelistener(gs_captureL);
        gs_captureL = nil;
        print("cancel GS capture");
        return;
    }
    
    var gsdefl = n.getValue();
    if (gsdefl < 0.1 and gsdefl > -0.1) {
        print("GS capture");
        N["vert_mode"].setValue(ap_vert_mode["GS"]);
        N["gs_armed"].setValue(0);
        if (gs_captureL != nil) {
            removelistener(gs_captureL);
            gs_captureL = nil;
        }
    }
}

var gs_in_range = func (n) {
    N["gs_armed"].setValue(1);
    if (n.getBoolValue()) {
        print("GS in range");
        if (gs_rangeL != nil) {
            removelistener(gs_rangeL);
            gs_rangeL = nil;
        }
        # if GS in range, wait some seconds and track GS
        settimer(func {
            gs_captureL = setlistener("instrumentation/nav[0]/gs-needle-deflection-deg", gs_mon, 0, 0);
        }, 3);
    }
}
#-- lateral mode handler -------------------------------------------------------
#2do: arm/capture logic
var latModeL = func(n) {
    var mode = n.getValue();
    var mode_txt = {
        0: "ROLL",
        1: "HDG",
        2: "", 3: "", 4: "", 5: "",
        6: "TO",
        7: "GA",
    };

    #-- update MCP status LEDs --
    setprop(mcp_prefix~"hdg-on", mode == ap_lat_mode["hdg"]);
    setprop(mcp_prefix~"speed-on", mode == ap_lat_mode["speed"]);
    setprop(mcp_prefix~"appr-on", mode == ap_lat_mode["appr"]);
    setprop(mcp_prefix~"nav-on", mode == ap_lat_mode["nav"]);
    setprop(ap_prefix~"toga-on",
        mode == ap_lat_mode["TO"] or mode == ap_lat_mode["GA"]);
    
    if (mode != ap_lat_mode["basic"]) {
        setprop("autopilot/internal/roll-mode", 0);
    }
    if (mode == ap_lat_mode["basic"] or
        mode == ap_lat_mode["TO"] or mode == ap_lat_mode["GA"]) {
        roll_sync();
    }
    #-- adjust bank limit --
    if (mode == ap_lat_mode["nav"] or mode == ap_lat_mode["appr"]) {
        setprop(ap_prefix~"half-bank", 0);
    }
    if (mode == ap_lat_mode["TO"] or mode == ap_lat_mode["GA"]) {
        setprop(ap_prefix~"half-bank", 0);
        setprop("autopilot/internal/bank-limit-deg", 5);
    } else {
        if (getprop(ap_prefix~"half-bank"))
            setprop("autopilot/internal/bank-limit-deg", 15);
        else setprop("autopilot/internal/bank-limit-deg", 30);
    }
    if (mode == ap_lat_mode["appr"]) {
        #-- GS arming for APPR mode
        if (gs_rangeL == nil) {
            gs_rangeL = setlistener("instrumentation/nav[0]/gs-in-range", gs_in_range, 1, 0);
            print("GS armed");
        }
    } else {
        #-- remove GS arm if leaving APPR mode
        print("vert mode ",mode);
        N["gs_armed"].setValue(0);
        if (gs_rangeL != nil) {
            removelistener(gs_rangeL);
            gs_rangeL = nil;
            print("gs_rangeL nil");
        }
        if (N["vert_mode"].getValue() == ap_vert_mode["GS"])
            N["vert_mode"].setValue(ap_vert_mode["basic"]);
    }
    setprop("autopilot/annunciators/lat-capture", mode_txt[mode]);
    setprop("autopilot/annunciators/lat-armed", "");
    if (mode == ap_lat_mode["nav"] or mode == ap_lat_mode["appr"]) {
        nav_annunciator();
    }
};
setlistener(N["lat_mode"], latModeL, 0, 1);

#-- vertical mode handler ------------------------------------------------------
#2do: arm/capture logic
var vertModeL = func(n) {
    var mode = n.getValue();
    setprop(mcp_prefix~"vs-on", mode == ap_vert_mode["VS"]);
    setprop(mcp_prefix~"speed-on", mode == ap_vert_mode["speed"]);
    setprop(mcp_prefix~"alt-on", mode == ap_vert_mode["alth"]);

    # capture text
    # vertical arm only ALTS or GS
    var mode_txt = {
        0: "PTCH",
        1: "ALT", #hold!
        2: "VS",
        3: "ALTS",
        4: "IAS",
        5: "GS",
        6: "TO",
        7: "GA",
    };
    #print("v:"~mode);
    pitch_sync();
    setprop("autopilot/annunciators/vert-capture", mode_txt[mode]);
    if (mode == ap_vert_mode["alth"])
        setprop("autopilot/annunciators/altitude-flash-cmd", 0);
    if (mode == ap_vert_mode["VS"])
        vs_annunciator();
    if (mode == ap_vert_mode["speed"])
        speed_annunciator();
}
setlistener(N["vert_mode"], vertModeL, 0, 1);

#-- annunciators ---------------------------------------------------------------
setlistener("/instrumentation/nav[0]/nav-loc", func(n) {
    if (n.getValue()) NAV_SRC[1] = "LOC1";
    else NAV_SRC[1] = "VOR1";
}, 1, 0);
setlistener("/instrumentation/nav[1]/nav-loc", func(n) {
    if (n.getValue()) NAV_SRC[2] = "LOC2";
    else NAV_SRC[2] = "VOR2";
}, 1, 0);

var nav_annunciator = func ()
{
    var nsrc = getprop(ap_prefix~"nav-source");
    var lm = N["lat_mode"].getValue();

    if (lm == ap_lat_mode["nav"] or lm == ap_lat_mode["appr"])
    {
        if (nsrc == 1 and getprop("autopilot/internal/vor1-captured") or
            nsrc == 2 and getprop("autopilot/internal/vor2-captured") or
            nsrc == 3 and getprop("autopilot/internal/fms1-captured"))
        {
            setprop("autopilot/annunciators/lat-capture", NAV_SRC[nsrc]);
            setprop("autopilot/annunciators/lat-armed", "");
        } else {
            setprop("autopilot/annunciators/lat-capture", "HDG");
            setprop("autopilot/annunciators/lat-armed", NAV_SRC[nsrc]);
        }
    }
}
setlistener("autopilot/internal/vor1-captured", nav_annunciator, 0, 0);
setlistener("autopilot/internal/vor2-captured", nav_annunciator, 0, 0);

#indicated altitude within +-200ft preselected altitude
setlistener("autopilot/internal/alts-capture", func(n) {
    var vm = N["vert_mode"].getValue();
    var val = n.getValue();
    if (vm != ap_vert_mode["GS"] and
        (!val or (val and vm == ap_vert_mode["alth"]))) 
    {
        setprop("autopilot/annunciators/vert-armed", "ALTS");
    }
    else setprop("autopilot/annunciators/vert-armed", "");
}, 0, 1);

var vs_annunciator = func () {
    var ref = sprintf("%1.1f", getprop(ap_prefix~"vertical-speed-select")/1000);
    if (N["vert_mode"].getValue() == ap_vert_mode["VS"]) {
        setprop("autopilot/annunciators/vert-capture", "VS "~ref);
    }
}
setlistener("controls/autoflight/vertical-speed-select", vs_annunciator, 0, 0);

var speed_annunciator = func () {
    var ref = int(getprop(ap_prefix~"speed-select"));
    if (N["vert_mode"].getValue() == ap_vert_mode["speed"]) {
        setprop("autopilot/annunciators/vert-capture", "IAS "~ref);
    }
}
setlistener("controls/autoflight/speed-select", speed_annunciator, 0, 0);

# Altitude alert
var flash_alt_bug = func()
{
    setprop("autopilot/annunciators/altitude-flash-cmd", 1);
    settimer(func { setprop("autopilot/annunciators/altitude-flash-cmd", 0); }, 10);
}

setlistener("autopilot/internal/alts-alert", func(n) {
    var vm = N["vert_mode"].getValue();
    if (n.getBoolValue() and vm != ap_vert_mode["alth"] and
        vm != ap_vert_mode["alt"] and vm != ap_vert_mode["GS"])
    {
        setprop("sim/alarms/altitude-alert", 1);
        settimer(func { setprop("sim/alarms/altitude-alert", 0); }, 1.5);
        flash_alt_bug();
    }
}, 0, 0);

var mda_alert = func(n)
{
    if (n.getBoolValue())
    {
        setprop("sim/alarms/altitude-alert", 1);
        settimer(func { setprop("sim/alarms/altitude-alert", 0); }, 1.5);
    }
}
setlistener("autopilot/annunciators/mda-alert", mda_alert, 0, 0);

var altitude_capture = func(n)
{
    #capture = within 200ft of preselected alt and not in alt hold mode
    var vm = N["vert_mode"].getValue();
    if (vm == ap_vert_mode["alth"])
        return;
    #capture
    if (n.getBoolValue() and vm != ap_vert_mode["alt"] and vm != ap_vert_mode["GS"])
    {
        setprop("autopilot/annunciators/altitude-flash-cmd", 0);
        setprop("autopilot/annunciators/vert-capture", "ALTS CAP");
        N["vert_mode"].setValue(ap_vert_mode["alt"]);
    }
}
setlistener("autopilot/internal/alts-capture", altitude_capture, 0, 0);

#ALTS rearm / ALT hold
var alts_rearm = func () {
    if (N["vert_mode"].getValue() == ap_vert_mode["alt"]) {
        N["vert_mode"].setValue(ap_vert_mode["alth"]);
    }
}
setlistener(ap_prefix~"altitude-select",alts_rearm, 0, 0);

#-- DME hold --
var _dmehL = func(i) {
    return func(n) {
        if (n.getBoolValue()) {
            setprop("/instrumentation/dme["~i~"]/frequencies/source",
                "/instrumentation/dme["~i~"]/frequencies/selected-mhz");
        }
        else
            setprop("/instrumentation/dme["~i~"]/frequencies/source",
                "/instrumentation/nav["~i~"]/frequencies/selected-mhz");
    };
}

foreach (i; [0,1]) {
    setlistener("/instrumentation/dme["~i~"]/hold", _dmehL(i),1,0);
}
