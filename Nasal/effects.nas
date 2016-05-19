## Bombardier CRJ700 series
## Nasal effects
###########################

## Livery select
aircraft.livery.init("Aircraft/CRJ700-family/Models/Liveries/" ~ getprop("sim/aircraft"));

## Switch sounds
var Switch_sound = {
    new: func(sound_prop, time, prop_list...)
    {
        var m = { parents: [Switch_sound] };
        m.soundid = 0;
        m.node = aircraft.makeNode(sound_prop);
        m.time = time;
        m.props = prop_list;
        foreach (var node; prop_list)
        {
            setlistener(node, func m.sound(), 0, 0);
        }
        return m;
    },
    sound: func
    {
        var soundid = me.soundid += 1;
        if (me.node.getBoolValue())
        {
            me.node.setBoolValue(0);
            settimer(func
            {
                if (soundid != me.soundid)
                {
                    return;
                }
                me.node.setBoolValue(1);
                me._setstoptimer_(soundid);
            }, 0.05);
        }
        else
        {
            me.node.setBoolValue(1);
            me._setstoptimer_(soundid);
        }
    },
    _setstoptimer_: func(soundid)
    {
        settimer(func
        {
            if (soundid != me.soundid) return;
            me.node.setBoolValue(0);
        }, me.time);
    }
};
var sound_flapslever = Switch_sound.new("sim/sound/flaps-lever", 0.18,
   "controls/flight/flaps");
var sound_passalert = Switch_sound.new("sim/sound/passenger-sign", 2,
   "sim/model/lights/no-smoking-sign",
   "sim/model/lights/seatbelt-sign");
var sound_switchclick = Switch_sound.new("sim/sound/click", 0.1,
	 "instrumentation/use-metric-altitude",
	 "controls/anti-ice/wiper[0]",
	 "controls/anti-ice/wiper[1]",
	 "controls/anti-ice/wing-heat",
	 "controls/anti-ice/engine[0]/inlet-heat",
	 "controls/anti-ice/engine[1]/inlet-heat",
	 "controls/electric/dc-service-switch",
	 "controls/electric/battery-switch",
	 "controls/electric/engine[0]/generator",
	 "controls/electric/APU-generator",
	 "controls/electric/engine[1]/generator",
	 "controls/electric/ADG",
	 "controls/gear/enable-tiller",
	 "controls/hydraulic/system[0]/pump-b",
	 "controls/hydraulic/system[1]/pump-b",
	 "controls/hydraulic/system[2]/pump-a",
	 "controls/hydraulic/system[2]/pump-b",	 
	 "controls/lighting/nav-lights",
	 "controls/lighting/beacon",
	 "controls/lighting/strobe",
	 "controls/lighting/logo-lights",
	 "controls/lighting/wing-lights",
	 "controls/lighting/landing-lights[0]",
	 "controls/lighting/landing-lights[1]",
	 "controls/lighting/landing-lights[2]",
	 "controls/lighting/taxi-lights",
	 "controls/lighting/lt-test",
	 "controls/lighting/ind-lts-dim",
	 "controls/flight/ground-lift-dump",
	 "controls/emer-flaps",
	 "controls/lighting/dome",
	 "controls/lighting/standby-compass",
	 "controls/engines/engine[0]/reverser-armed",
	 "controls/engines/engine[1]/reverser-armed",
);
var sound_switchclick2 = Switch_sound.new("sim/sound/click2", 0.1,
	"controls/lighting/display-norm",
	"controls/lighting/panel-norm",
	"controls/lighting/panel-flood-norm",
	"controls/anti-ice/wiper",
	"controls/autoflight/nav-source",
	"instrumentation/use-QNH",
	"instrumentation/altimeter/setting-hpa",
	"instrumentation/efis/mfd/mode-num",
	"instrumentation/efis/inputs/range",
	"instrumentation/mfd[0]/tcas",
	"instrumentation/mfd[0]/wx",
	"instrumentation/mfd[1]/tcas",
	"instrumentation/mfd[1]/wx",
	"instrumentation/use-QNH",
	"instrumentation/brg-src1",
	"instrumentation/brg-src2",
	"instrumentation/eicas[0]/page",
	"instrumentation/eicas[1]/page",
	"controls/pneumatic/cross-bleed", 
	"controls/pneumatic/bleed-valve", 
	"controls/pneumatic/bleed-source",
	"instrumentation/nav[0]/radials/selected-deg",
	"instrumentation/nav[1]/radials/selected-deg",
	"controls/autoflight/speed-select",
	"controls/autoflight/mach-select",
	"controls/autoflight/heading-select",
	"controls/autoflight/altitude-select",
	"controls/autoflight/ani/fd-pressed",
	"controls/autoflight/ani/ap-pressed",
	"controls/autoflight/ani/speed-pressed",
	"controls/autoflight/ani/appr-pressed",
	"controls/autoflight/ani/hdg-pressed",
	"controls/autoflight/ani/nav-pressed",
	"controls/autoflight/ani/alt-pressed",
	"controls/autoflight/ani/vst-pressed",
	"controls/autoflight/ani/bank-pressed",	
);
var sound_switchlightclick = Switch_sound.new("sim/sound/swl-click", 0.1,
	 "controls/electric/ac-service-selected",
	 "controls/electric/ac-service-selected-ext",
	 "controls/electric/idg1-disc",
	 "controls/electric/ac-ess-xfer",
	 "controls/electric/idg2-disc",
	 "controls/electric/auto-xfer1",
	 "controls/electric/auto-xfer2",
	 "controls/hydraulic/system[0]/pump-a",
	 "controls/hydraulic/system[1]/pump-a",		
	 "consumables/fuel/tank[0]/selected",
	 "controls/fuel/gravity-xflow",
	 "consumables/fuel/tank[1]/selected",
	 "controls/fuel/xflow-left",
	 "controls/fuel/xflow-manual",
	 "controls/fuel/xflow-right",
	 "controls/APU/electronic-control-unit",
	 "controls/APU/off-on",
	 "controls/engines/cont-ignition",
	 "controls/engines/engine[0]/starter",
	 "controls/engines/engine[1]/starter",
	 "controls/ECS/ram-air",
	 "controls/ECS/emer-depress",
	 "controls/ECS/press-man",
	 "controls/ECS/pack-l-off",
	 "controls/ECS/pack-r-off",
	 "controls/ECS/pack-l-man",
	 "controls/ECS/pack-r-man",  
	 "controls/anti-ice/det-test",

	 "controls/gear/mute-horn",
	 "instrumentation/mk-viii/inputs/discretes/gpws-inhibit",
	 "instrumentation/mk-viii/inputs/discretes/momentary-flap-override",
	 "controls/autoflight/yaw-damper[0]/engage",
	 "controls/autoflight/yaw-damper[1]/engage",
	 "controls/firex/fwd-cargo-switch",
	 "controls/firex/aft-cargo-switch",
	 "controls/firex/firex-switch",
	 "controls/APU/fire-switch-armed",
);

## Tire smoke
var tiresmoke_system = aircraft.tyresmoke_system.new(0, 1, 2);

## Lights
# Exterior lights; sim/model/lights/... is used by electrical system to switch outputs
var beacon_light = aircraft.light.new("sim/model/lights/beacon", [0.05, 2.1], "controls/lighting/beacon");
var strobe_light = aircraft.light.new("sim/model/lights/strobe", [0.05, 2], "controls/lighting/strobe");

# cockpit
var altitude_flash = aircraft.light.new("autopilot/annunciators/altitude-flash", [0.4, 0.8], "autopilot/annunciators/altitude-flash-cmd");

# No smoking/seatbelt signs
var nosmoking_controlN = props.globals.getNode("controls/switches/no-smoking-sign", 1);
var nosmoking_signN = props.globals.getNode("sim/model/lights/no-smoking-sign", 1);
var seatbelt_controlN = props.globals.getNode("controls/switches/seatbelt-sign", 1);
var seatbelt_signN = props.globals.getNode("sim/model/lights/seatbelt-sign", 1);
var update_pass_signs = func
{
    var nosmoking = nosmoking_controlN.getValue();
    if (nosmoking == 0) # auto
    {
        var gear_down = props.globals.getNode("controls/gear/gear-down", 1);
        var altitude = props.globals.getNode("instrumentation/altimeter[0]/indicated-altitude-ft");
        if (gear_down.getBoolValue()
            or altitude.getValue() < 10000)
        {
            nosmoking_signN.setBoolValue(1);
        }
        else
        {
            nosmoking_signN.setBoolValue(0);
        }
    }
    elsif (nosmoking == 1) # off
    {
        nosmoking_signN.setBoolValue(0);
    }
    elsif (nosmoking == 2) # on
    {
        nosmoking_signN.setBoolValue(1);
    }
    var seatbelt = seatbelt_controlN.getValue();
    if (seatbelt == 0) # auto
    {
        var gear_down = props.globals.getNode("controls/gear/gear-down", 1);
        var flaps = props.globals.getNode("controls/flight/flaps", 1);
        var altitude = props.globals.getNode("instrumentation/altimeter[0]/indicated-altitude-ft");
        if (gear_down.getBoolValue()
            or flaps.getValue() > 0
            or altitude.getValue() < 10000)
        {
            seatbelt_signN.setBoolValue(1);
        }
        else
        {
            seatbelt_signN.setBoolValue(0);
        }
    }
    elsif (seatbelt == 1) # off
    {
        seatbelt_signN.setBoolValue(0);
    }
    elsif (seatbelt == 2) # on
    {
        seatbelt_signN.setBoolValue(1);
    }
};

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
