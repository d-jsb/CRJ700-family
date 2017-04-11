## Lightmaps
var update_lightmaps = func
{
  var logo = props.globals.getNode("sim/model/lights/logo-lightmap");
  var wing = props.globals.getNode("sim/model/lights/wing-lightmap");
  var panel = props.globals.getNode("sim/model/lights/panel-lightmap");
  var cabin = props.globals.getNode("sim/model/lights/cabin-lightmap");
  var taxi = props.globals.getNode("sim/model/lights/taxi-lightmap");
  var ll = props.globals.getNode("sim/model/lights/landing-left-lightmap");
  var ln = props.globals.getNode("sim/model/lights/landing-nose-lightmap");
  var lr = props.globals.getNode("sim/model/lights/landing-right-lightmap");

  logo.setValue((getprop("systems/AC/outputs/logo-lights") > 108));
  wing.setValue(getprop("systems/DC/outputs/wing-lights") > 15);
  ll.setValue((getprop("systems/DC/outputs/landing-lights[0]") > 20));
  #ln.setValue((getprop("systems/DC/outputs/landing-lights[1]") > 20));
  lr.setValue((getprop("systems/DC/outputs/landing-lights[2]") > 20));

  if (getprop("systems/DC/outputs/instrument-flood-lights") > 15)
    panel.setDoubleValue(getprop("controls/lighting/panel-flood-norm"));
  else panel.setDoubleValue(0);
  if (getprop("systems/AC/outputs/cabin-lights") > 100)
    cabin.setDoubleValue(getprop("controls/lighting/cabin-norm"));
  else cabin.setDoubleValue(0);
};
