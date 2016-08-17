## Lightmaps
var logo = props.globals.getNode("sim/model/lights/logo-lightmap");
var wing = props.globals.getNode("sim/model/lights/wing-lightmap");
var panel0 = props.globals.getNode("sim/model/lights/panel0-lightmap");
var panel1 = props.globals.getNode("sim/model/lights/panel1-lightmap");
var panel2 = props.globals.getNode("sim/model/lights/panel2-lightmap");
var cabin = props.globals.getNode("sim/model/lights/cabin-lightmap");
var taxi = props.globals.getNode("sim/model/lights/taxi-lightmap");
var ll = props.globals.getNode("sim/model/lights/landing-left-lightmap");
var ln = props.globals.getNode("sim/model/lights/landing-nose-lightmap");
var lr = props.globals.getNode("sim/model/lights/landing-right-lightmap");

var update_lightmaps = func
{
    logo.setValue((getprop("systems/AC/outputs/logo-lights") > 108));
    wing.setValue(getprop("systems/DC/outputs/wing-lights") > 15);
    ll.setValue((getprop("systems/DC/outputs/landing-lights[0]") > 20));
    #ln.setValue((getprop("systems/DC/outputs/landing-lights[1]") > 20));
    lr.setValue((getprop("systems/DC/outputs/landing-lights[2]") > 20));

    if (getprop("systems/DC/outputs/instrument-flood-lights") > 15) {
        panel0.setDoubleValue(getprop("controls/lighting/panel-flood-norm"));
        panel1.setDoubleValue(getprop("controls/lighting[1]/panel-flood-norm"));
        panel2.setDoubleValue(getprop("controls/lighting[2]/panel-flood-norm"));
    }
    else {
        panel0.setDoubleValue(0);
        panel1.setDoubleValue(0);
        panel2.setDoubleValue(0);
    }
    if (getprop("systems/AC/outputs/cabin-lights") > 100)
        cabin.setDoubleValue(getprop("controls/lighting/cabin-norm"));
    else cabin.setDoubleValue(0);
};
