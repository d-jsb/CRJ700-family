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
var sound_passalert = Switch_sound.new("sim/sound/passenger-sign", 2,
   "sim/model/lights/no-smoking-sign",
   "sim/model/lights/seatbelt-sign");
var sound_switchclick = Switch_sound.new("sim/sound/click", 0.5,
	 "instrumentation/mfd[0]/page",
	 "instrumentation/mfd[0]/tcas",
	 "instrumentation/mfd[0]/wx",
	 "instrumentation/mfd[1]/page",
	 "instrumentation/mfd[1]/tcas",
	 "instrumentation/mfd[1]/wx",
	 "instrumentation/eicas[0]/page",
	 "instrumentation/eicas[1]/page",
	 "instrumentation/mk-viii/inputs/discretes/gpws-inhibit",
	 "instrumentation/mk-viii/inputs/discretes/momentary-flap-override",
	 "instrumentation/use-metric-altitude",
	 "instrumentation/use-QNH",
	 "controls/anti-ice/wiper[0]",
	 "controls/anti-ice/wiper[1]",
	 "controls/anti-ice/wing-heat",
	 "controls/anti-ice/engine[0]/inlet-heat",
	 "controls/anti-ice/engine[1]/inlet-heat",
	 "controls/anti-ice/det-test",
	 "controls/autoflight/yaw-damper[0]/engage",
	 "controls/autoflight/yaw-damper[1]/engage",
	 "controls/APU/electronic-control-unit",
	 "controls/APU/off-on",
	 "controls/APU/fire-switch-armed",
	 "controls/electric/dc-service-switch",
	 "controls/electric/battery-switch",
	 "controls/electric/ac-service-selected",
	 "controls/electric/ac-service-selected-ext",
	 "controls/electric/idg1-disc",
	 "controls/electric/ac-ess-xfer",
	 "controls/electric/idg2-disc",
	 "controls/electric/auto-xfer1",
	 "controls/electric/auto-xfer2",
	 "controls/electric/engine[0]/generator",
	 "controls/electric/APU-generator",
	 "controls/electric/engine[1]/generator",
	 "controls/electric/ADG",
	 "controls/ECS/ram-air",
	 "controls/ECS/emer-depress",
	 "controls/ECS/press-man",
	 "controls/ECS/pack-l-off",
	 "controls/ECS/pack-r-off",
	 "controls/ECS/pack-l-man",
	 "controls/ECS/pack-r-man",  
	 "controls/hydraulic/system[0]/pump-a",
	 "controls/hydraulic/system[0]/pump-b",
	 "controls/hydraulic/system[1]/pump-a",		
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
	 "consumables/fuel/tank[0]/selected",
	 "controls/fuel/gravity-xflow",
	 "consumables/fuel/tank[1]/selected",
	 "controls/fuel/xflow-left",
	 "controls/fuel/xflow-manual",
	 "controls/fuel/xflow-right",
	 "controls/pneumatic/bleed-source", 
	 "controls/engines/cont-ignition",
	 "controls/engines/engine[0]/reverser-armed",
	 "controls/engines/engine[1]/reverser-armed",
	 "controls/engines/engine[0]/starter",
	 "controls/engines/engine[1]/starter",
	 "controls/emer-flaps",
	 "controls/firex/fwd-cargo-switch",
	 "controls/firex/aft-cargo-switch",
	 "controls/firex/firex-switch",
	 "controls/lighting/dome");

## Tire smoke
var tiresmoke_system = aircraft.tyresmoke_system.new(0, 1, 2);

## Lights
# Exterior lights
var beacon_light = aircraft.light.new("sim/model/lights/beacon", [0.05, 2.1], "controls/lighting/beacon");
var strobe_light = aircraft.light.new("sim/model/lights/strobe", [0.05, 2], "controls/lighting/strobe");

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
    var fuse = props.globals.getNode("sim/model/lights/fuselage-lightmap");
    fuse.setBoolValue(getprop("systems/AC/outputs/logo-lights") > 108);
    var wing = props.globals.getNode("sim/model/lights/wing-lightmap");
    wing.setBoolValue(getprop("systems/DC/outputs/wing-lights") > 15);
    var panel = props.globals.getNode("sim/model/lights/panel-lightmap");
    if (getprop("systems/DC/outputs/instrument-flood-lights") > 15)
    {
        panel.setDoubleValue(getprop("controls/lighting/panel-flood-norm"));
    }
    else
    {
        panel.setDoubleValue(0);
    }
    var cabin = props.globals.getNode("sim/model/lights/cabin-lightmap");
    if (getprop("systems/AC/outputs/cabin-lights") > 100)
    {
        cabin.setDoubleValue(getprop("controls/lighting/cabin-norm"));
    }
    else
    {
        cabin.setDoubleValue(0);
    }
};
