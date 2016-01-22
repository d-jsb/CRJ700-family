## Aircraft-specific dialogs
var aircraft_path = "Aircraft/CRJ700-family/"~"Dialogs/";
var dialogs = {
    adc: gui.Dialog.new("sim/gui/dialogs/adc/dialog", aircraft_path~"adc-dlg.xml"),
    apdev: gui.Dialog.new("sim/gui/dialogs/apdev/dialog", aircraft_path~"autopilot-dev-dlg.xml"),
    autopilot: gui.Dialog.new("sim/gui/dialogs/autopilot/dialog", aircraft_path~"autopilot-dlg.xml"),
    autothrottle: gui.Dialog.new("sim/gui/dialogs/autothrottle/dialog", aircraft_path~"autothrottle-dlg.xml"),
    config: gui.Dialog.new("sim/gui/dialogs/config-crj700/dialog", aircraft_path~"config-dlg.xml"),
    debug: gui.Dialog.new("sim/gui/dialogs/debug/dialog", aircraft_path~"debug-dlg.xml"),
    developer: gui.Dialog.new("sim/gui/dialogs/developer/dialog", aircraft_path~"developer-dlg.xml"),
    doors: gui.Dialog.new("sim/gui/dialogs/doors/dialog", aircraft_path~"doors-dlg.xml"),
    eicas: gui.Dialog.new("sim/gui/dialogs/eicas/dialog", aircraft_path~"eicas-dlg.xml"),
    failures: gui.Dialog.new("sim/gui/dialogs/failures/dialog", aircraft_path~"failures-dlg.xml"),
    info: gui.Dialog.new("sim/gui/dialogs/info-crj700/dialog", aircraft_path~"info-dlg.xml"),
    lights: gui.Dialog.new("sim/gui/dialogs/lights/dialog", aircraft_path~"lights-dlg.xml"),
    radio: gui.Dialog.new("sim/gui/dialogs/radio-stack/dialog", aircraft_path~"radio-stack-dlg.xml"),
    tiller: gui.Dialog.new("sim/gui/dialogs/tiller/dialog", aircraft_path~"tiller-dlg.xml"),
    viewselect: gui.Dialog.new("sim/gui/dialogs/views-crj700/dialog", aircraft_path~"viewselect-dlg.xml"),
};
gui.menuBind("autopilot", "CRJ700.dialogs.autopilot.open();");
gui.menuBind("radio", "CRJ700.dialogs.radio.open();");
dialogs.eicas.open();