#-------------------------------------------------------------------------------
# EFIS for CRJ700 family (Rockwell Collins Proline 4)
# Author:  jsb
# Created: 02/2018
#-------------------------------------------------------------------------------
var DEBUG_LEVEL=0;

setprop ("/sim/startup/terminal-ansi-colors",0);
if (DEBUG_LEVEL) {
    logprint(DEV_ALERT, "-- begin CRJ700-efis.nas --");
    modules.setDebug("canvas_efis", DEBUG_LEVEL);
}

var efis_module = modules.load("canvas_efis");
var instrument_module = modules.load("canvas_instruments");

var unload = func() {
    instrument_module.unload();
    efis_module.unload();
}

# FIXME: once the canvas_instruments is commited to fgdata the local version 
# should be removed
if (canvas["instruments"] == nil) {    
    io.load_nasal(getprop("/sim/aircraft-dir")~"/Nasal/lib/canvas_instruments.nas", "canvas");
}

# import classes into local namespace
var _namespace = efis_module.getNamespace();
var EFIS = _namespace.EFIS;
var EFISCanvas = _namespace.EFISCanvas;

var svg_path = "Models/Instruments/EFIS/";
var nasal_path = "Nasal/EFIS/";

# "constants" for better readability
var ON_SIDE = 0;
var X_SIDE = 1;
var PILOT_SIDE = 0;
var COPILOT_SIDE = 1;

var nasal_files = [
    "crj700-hsi.nas",
    "pfd.nas",
    "mfd.nas",
    "eicas-pri.nas",
    "eicas-stat.nas",
    "eicas-ecs.nas",
    "eicas-hydraulics.nas",
    "eicas-ac.nas",
    "eicas-dc.nas",
    "eicas-fuel.nas",
    "eicas-fctl.nas",
    "eicas-aice.nas",
    "eicas-doors.nas",
];

# identifiers for display units
var display_names = ["PFD1", "MFD1", "EICAS1", "EICAS2", "MFD2", "PFD2"];
# names of 3D objects that will take the canvas texture
var display_objects = ["EFIS1", "EFIS2", "EFIS3", "EFIS4", "EFIS5", "EFIS6"];
var canvas_settings = {
    "size": [1024,1024],
    "view": [1000,1200],
};
var window_size = [400,480];

#reference value for display power (22 volts for CRJ700)
var minimum_power = 22;
var EICAS_powerP = "/instrumentation/efis/power";

# little hack to avoid duplicate "EFIS on" event when changing from 24V Batt. to 28V AC2DC
setlistener("/systems/DC/outputs/eicas-disp", func(n) {
    var val = n.getValue() or 0;
    if (val >= 24) setprop(EICAS_powerP, 24);
    else setprop(EICAS_powerP, 0);
}, 1, 0);

# power source for each display unit
var display_power_props = [
    "/systems/DC/outputs/pfd1",
    "/systems/DC/outputs/mfd1",
    EICAS_powerP,
    EICAS_powerP,
    "/systems/DC/outputs/mfd2",
    "/systems/DC/outputs/pfd2"
];

# add/override colors for our aircraft
EFIS.colors["green"] = [0.133,0.667,0.133];
EFIS.colors["blue"] = [0.133,0.133,1];

# create EFIS system and add power prop to en-/dis-able efis
var efis = EFIS.new(display_names, display_objects, canvas_settings);
efis.setWindowSize(window_size);
efis.setPowerProp(EICAS_powerP);
efis.setDUPowerProps(display_power_props, minimum_power);

io.include(nasal_path~"eicas-crj700.nas");
foreach (var filename; nasal_files)
{
    io.include(nasal_path~filename);
#    io.load_nasal(nasal_path~filename, CRJ700.EFIS_namespace);
}

var eicas_sources = [];

#-- EFISSetup is called after FDM init 
var EFISSetup = func() {
    print("== CRJ700 EFIS setup ==");
    #-- create primary flight displays --
    pfd1 = PFDCanvas.new("PFD1", svg_path~"PFD.svg", PILOT_SIDE, efis_ndc);
    pfd2 = PFDCanvas.new("PFD2", svg_path~"PFD.svg", COPILOT_SIDE, efis_ndc);

    #-- create multi function displays --
    mfd1 = MFDCanvas.new("MFD1", svg_path~"mfd.svg", PILOT_SIDE, efis_ndc);
    mfd2 = MFDCanvas.new("MFD2", svg_path~"mfd.svg", COPILOT_SIDE, efis_ndc);

    #-- create EICAS pages --
    var eicas_pri = EICASPriCanvas.new("PRI", svg_path~"eicas-pri.svg");
    var eicas_stat = EICASStatCanvas.new("STAT", svg_path~"eicas-stat.svg");
    append(eicas_sources, eicas_pri);
    append(eicas_sources, eicas_stat);
    append(eicas_sources, EICASECSCanvas.new("ECS", svg_path~"eicas-ecs.svg"));
    append(eicas_sources, EICASHydraulicsCanvas.new("HYD", svg_path~"eicas-hydraulic.svg"));
    append(eicas_sources, EICASACCanvas.new("AC", svg_path~"eicas-ac.svg"));
    append(eicas_sources, EICASDCCanvas.new("DC", svg_path~"eicas-dc.svg"));
    append(eicas_sources, EICASFuelCanvas.new("FUEL", svg_path~"eicas-fuel.svg"));
    append(eicas_sources, EICASFctlCanvas.new("F-CTL", svg_path~"eicas-fctl.svg"));
    append(eicas_sources, EICASAIceCanvas.new("A-ICE", svg_path~"eicas-aice.svg"));
    append(eicas_sources, EICASDoorsCanvas.new("Doors", svg_path~"eicas-doors.svg"));
    
    #-- create EICAS message systems
    var line_spacing = 36;
    var font_size = 34;
    EICASMsgSys1.setCanvasGroup(eicas_pri.getRoot());
    EICASMsgSys1.createCanvasTextLines(580, 65, line_spacing, font_size);
    EICASMsgSys2.setCanvasGroup(eicas_stat.getRoot());
    EICASMsgSys2.createCanvasTextLines(60, 65, line_spacing, font_size);
    
    var pi1 = EICASMsgSys1.createPageIndicator(950,65 + line_spacing * 16, 32);
    pi1.setDrawMode(pi1.TEXT + pi1.BOUNDINGBOX)
        .setAlignment("right-top").setPadding(4)
        .setColor(efis.colors["amber"]).setColorFill(efis.colors["amber"]);

    var pi2 = EICASMsgSys2.createPageIndicator(380,65 + line_spacing * 16, 32);
    pi2.setDrawMode(pi2.TEXT + pi2.BOUNDINGBOX)
        .setAlignment("right-top").setPadding(4)
        .setColor(efis.colors["white"]).setColorFill(efis.colors["white"]);
        
    # added the updateCanvas to EICASPriCanvas and EICASStatCanvas
    eicas_pri.addUpdateFunction(EICASMsgSys1.updateCanvas, 0.5, EICASMsgSys1);
    eicas_stat.addUpdateFunction(EICASMsgSys2.updateCanvas, 0.5, EICASMsgSys2);

    #-- add sources to EFIS --
    var pfd1_sid = efis.addSource(pfd1);
    var pfd2_sid = efis.addSource(pfd2);
    var mfd1_sid = efis.addSource(mfd1);
    var mfd2_sid = efis.addSource(mfd2);
    var eicas_source_ids = [];
    foreach (var p; eicas_sources) {
        append(eicas_source_ids, efis.addSource(p));
    }

    var default_mapping = {
        PFD1: pfd1_sid, MFD1: mfd1_sid,
        PFD2: pfd2_sid, MFD2: mfd2_sid,
        EICAS1: eicas_source_ids[0], EICAS2: eicas_source_ids[1],
    };
    efis.setDefaultMapping(default_mapping);

    # mappings per src_selector
    var mappings = [
        [ {PFD1: -1, MFD1: pfd1_sid}, {PFD1: pfd1_sid, MFD1: mfd1_sid}, {PFD1: pfd1_sid, MFD1: eicas_source_ids[1] }],
        [ {PFD2: -1, MFD2: pfd2_sid}, {PFD2: pfd2_sid, MFD2: mfd2_sid}, {PFD2: pfd2_sid, MFD2: eicas_source_ids[1]} ],
        [ {EICAS1: eicas_source_ids[1], EICAS2: -1}, {EICAS1: eicas_source_ids[0], EICAS2: eicas_source_ids[1]}, {EICAS1: -1, EICAS2: eicas_source_ids[0]} ],
    ];
    efis.addSourceSelector(eicas_pageP, ecp_targetN, eicas_source_ids);

    #-- add display routing controls
    forindex (var i; src_selectors) {
        var prop_path = src_selector_base~src_selectors[i];
        # init to default=1 (3D model knobs in middle position)
        setprop(prop_path,1);
        efis.addDisplaySwapControl(prop_path, mappings[i], callbacks[i]);
    }

    #-- EICAS master warning/caution --
    # reset new-msg flags to trigger sounds again
    var new_warnP = "instrumentation/eicas/msgsys1/new-msg-warning";
    var new_cautionP = "instrumentation/eicas/msgsys1/new-msg-caution";
    var t_new_warn = maketimer(1.7, func { setprop(new_warnP, 0); });
    t_new_warn.singleShot = 1;
    var t_new_caution = maketimer(0.6, func { setprop(new_cautionP, 0); });
    t_new_caution.singleShot = 1;
    
    setlistener(new_warnP, func(n) {
        var val = n.getValue();
        if (val > 0) {
            t_new_warn.start();
            setprop("instrumentation/eicas/master-warning",1);
        }
        elsif (val < 0)
            setprop("instrumentation/eicas/master-warning",0);
    },1, 0);
    setlistener(new_cautionP, func(n) {
        var val = n.getValue();
        if (val > 0) {
            t_new_caution.start();
            setprop("instrumentation/eicas/master-caution",1);
        }
        elsif (val < 0)
            setprop("instrumentation/eicas/master-caution",0);
    },1, 0);
    efis.boot();
}; #EFISSetup

EFISSetup();

var eicas_recipient = emesary.Recipient.new("EICAS-page-select")
    .setReceive(func(ntf) {
        if (!isa(ntf, emesary.Notification)) {
            logprint(DEV_ALERT, "Recipient: argument is not a Notification!");
            return emesary.Transmitter.ReceiptStatus_NotProcessed; 
        }
        if (ntf.NotificationType != "CRJ-input") {
            return emesary.Transmitter.ReceiptStatus_NotProcessed; 
        }
        
        if (ntf.Ident == "eicas-page") {
            var p = getprop("instrumentation/eicas/page");
            if (ntf["page"] == "ac-dc") {
                if (p == vecindex(EICAS_PAGES, "ac")) {
                    p = vecindex(EICAS_PAGES, "dc");
                }
                else p = vecindex(EICAS_PAGES, "ac")
            }
            else p = vecindex(EICAS_PAGES, ntf["page"]);
            setprop("instrumentation/eicas/page", p);
        }
        return emesary.Transmitter.ReceiptStatus_OK; 
    });


emesary.GlobalTransmitter.Register(eicas_recipient);
