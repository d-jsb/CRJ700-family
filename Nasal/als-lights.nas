#
# CRJ700 familiy - ALS landing lights
#
var LL_MIN_VOLTS = 24;

var update_als_landinglights = func ()
{
    var cv = getprop("sim/current-view/view-number-raw");
    var path = "/systems/DC/outputs/";
    var tl = getprop(path~"taxi-lights");
    var ll = getprop(path~"landing-lights");
    var ln = getprop(path~"landing-lights[1]");
    var lr = getprop(path~"landing-lights[2]");

    if (cv == 0 or cv == 101 or cv == 109) {
        if (ll >= LL_MIN_VOLTS) setprop("/sim/rendering/als-secondary-lights/landing-light1-offset-deg", -4);
        elsif (ln >= LL_MIN_VOLTS) setprop("/sim/rendering/als-secondary-lights/landing-light1-offset-deg", -1);
        else setprop("/sim/rendering/als-secondary-lights/landing-light1-offset-deg", 0);
        if (lr >= LL_MIN_VOLTS) setprop("/sim/rendering/als-secondary-lights/landing-light2-offset-deg", 4);
        elsif (ln >= LL_MIN_VOLTS) setprop("/sim/rendering/als-secondary-lights/landing-light2-offset-deg", 1);
        else setprop("/sim/rendering/als-secondary-lights/landing-light2-offset-deg", 0);
        setprop("/sim/rendering/als-secondary-lights/use-landing-light", (ll >= LL_MIN_VOLTS or ln >= LL_MIN_VOLTS or tl >= LL_MIN_VOLTS));
        setprop("/sim/rendering/als-secondary-lights/use-alt-landing-light", (lr >= LL_MIN_VOLTS or ll >= LL_MIN_VOLTS and ln >= LL_MIN_VOLTS));

        #setprop("/sim/rendering/als-secondary-lights/use-landing-light", (ln >= LL_MIN_VOLTS));
    }
    else {
        setprop("/sim/rendering/als-secondary-lights/use-landing-light", 0);
        setprop("/sim/rendering/als-secondary-lights/use-alt-landing-light", 0);
    }
}

settimer(func {
    var path = "/systems/DC/outputs/";
    props.globals.initNode(path~"taxi-lights", 0, "DOUBLE");
    props.globals.initNode(path~"landing-lights", 0, "DOUBLE");
    props.globals.initNode(path~"landing-lights[1]", 0, "DOUBLE");
    props.globals.initNode(path~"landing-lights[2]", 0, "DOUBLE");

    setlistener(path~"taxi-lights", update_als_landinglights, 1, 0);
    setlistener(path~"landing-lights", update_als_landinglights, 0, 0);
    setlistener(path~"landing-lights[1]", update_als_landinglights, 0, 0);
    setlistener(path~"landing-lights[2]", update_als_landinglights, 0, 0);
    setlistener("/sim/current-view/view-number", update_als_landinglights, 0, 0);
}, 1);