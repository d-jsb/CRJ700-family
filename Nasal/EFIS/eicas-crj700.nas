#-- CRJ700 family - EICAS Message Systems --------------------------------------
# CRJ700 EICAS has four message classes, warning and caution messages are 
# displayed on EICAS primary page, advisory and status messages are displayed
# on status page. Messages may be inhibited during takeoff and landing.
# Some warnings have a distinct aural alert.


# EICAS Control Panel (ECP) 
var eicas_baseP = "instrumentation/eicas/";
var eicas_pageP = eicas_baseP~"page";
var ecp_targetN = props.globals.getNode(eicas_baseP~"ecp-target",1);
var EICAS_PAGES = ["pri", "stat", "ecs", "hyd", "ac", "dc", 
                    "fuel", "f-ctl", "a-ice", "doors"];

# page selector buttons by default change src of DU 3 (EICAS2)
ecp_targetN.setIntValue(3); 

# display selectors allow to re-route certain displays
# e.g. each MFD can be set to display the adjacent PFD or EICAS
# control values 0,1,2 1=default
var src_selector_base = "/controls/efis/";
var src_selectors = ["src-mfd-pilot", "src-mfd-copilot", "src-eicas"];
var callbacks = [
    # pilot side selector
    func(val) { 
        if (val == 2) ecp_targetN.setValue(1); #MFD1
        elsif (getprop(src_selector_base~src_selectors[2]) == 0)
            ecp_targetN.setValue(2); #EICAS1
        else ecp_targetN.setValue(3); #EICAS2
    },
    # copilot side selector
    func(val) { 
        if (val == 2) ecp_targetN.setValue(4); #MFD2
        elsif (getprop(src_selector_base~src_selectors[2]) == 0)
            ecp_targetN.setValue(2); #EICAS1
        else ecp_targetN.setValue(3); #EICAS2
    },
    # eicas selector on pedestal panel
    func(val) { 
        if (val == 0) ecp_targetN.setValue(2); #EICAS1
        else ecp_targetN.setValue(3); #EICAS2
    },
];
io.include("eicas-messages-crj700.nas");

var MessageSystem = canvas_efis.MessageSystem;
var EICAS_MAX_MESSAGES = 16;

#-- on primary page --
var EICASMsgSys1 = MessageSystem.new(EICAS_MAX_MESSAGES, eicas_baseP~"msgsys1");
EICASMsgSys1.setPowerProp(EICAS_powerP);
EICASMsgSys1.setSoundPath(sound_dir);
EICASMsgSys1.addAuralAlerts(EICASAural);

EICASMsgClsWarning = EICASMsgSys1.addMessageClass("warning", 
                    MessageSystem.NO_PAGING, efis.colors["red"]);
EICASMsgClsCaution = EICASMsgSys1.addMessageClass("caution", 
                    MessageSystem.PAGING, efis.colors["amber"]);

EICASMsgSys1.addMessages(EICASMsgClsWarning, EICASWarningMessages);
EICASMsgSys1.addMessages(EICASMsgClsCaution, EICASCautionMessages);

#-- on status page --
EICAS_MAX_MESSAGES = 26;
var EICASMsgSys2 = MessageSystem.new(EICAS_MAX_MESSAGES, eicas_baseP~"msgsys2");
EICASMsgSys2.setPowerProp(EICAS_powerP);

EICASMsgClsAdvisory = EICASMsgSys2.addMessageClass("advisory", 
                    MessageSystem.NO_PAGING, efis.colors["green"]);
EICASMsgClsStatus = EICASMsgSys2.addMessageClass("status", MessageSystem.PAGING);

EICASMsgSys2.addMessages(EICASMsgClsAdvisory, EICASAdvisoryMessages);
EICASMsgSys2.addMessages(EICASMsgClsStatus, EICASStatusMessages);

#-- message inhibits
setlistener(eicas_baseP~"inhibits/landing-set", func(n) {
    var val = n.getValue() or 0;
    setprop(eicas_baseP~"inhibits/landing", val);
}, 1,0);

# additional air-ground / ground-air transition handling - see also property rules
var onground_timer = maketimer(30, func {
    if (getprop("gear/on-ground")) {
        setprop(eicas_baseP~"inhibits/landing",0);
    } else {
        setprop(eicas_baseP~"inhibits/final-takeoff",0);
    }
});
onground_timer.singleShot = 1;

setlistener("gear/on-ground", func(n) {
    onground_timer.start();
}, 1, 0);
#-- end EICAS Message Systems -------------------------------------------------
