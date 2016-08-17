#
# CRJ700 familiy - AirDataComputer reference auto-setup
#
var auto_setup_enabledN = props.getNode("/config/adc-autoconf", 1);
var ac_model = getprop("/sim/aero");
var fdm = getprop("/sim/flight-model");
var weight_lbsN = nil;

if (fdm == "yasim") { 
    weight_lbsN = props.getNode("/fdm/yasim/gross-weight-lbs",1);
} elsif (fdm == "jsb") { 
    weight_lbsN = props.getNode("/fdm/jsbsim/inertia/weight-lbs",1);
} else {
    return;
}

var prop_base = "instrumentation/adc/reference/";

var autoconf = func() {
    print("ADC auto config");
    var st = globals[CRJ700.speedbook_namespace].getSpeedTable();
    var speeds = st.getPage(st.getPageNumberByWeight(weight_lbsN.getValue() * LB2KG));
    setprop(prop_base~"v1", speeds["v1_8"]);
    setprop(prop_base~"v2", speeds["v2_8"]);
    setprop(prop_base~"vr", speeds["vr_8"]);
    setprop(prop_base~"vt", speeds["vt"]);
}

#setlistener(weight_lbsN, autoconf, 0, 0);

# FlightGear command
var fgc_adc_autoconf = func(node) {
    autoconf();
}

var main = func() {
    addcommand("adc_autoconf", fgc_adc_autoconf);
}

var unload = func() {
    removecommand("adc_autoconf");
}
