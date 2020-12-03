## Bombardier CRJ700 series
## Nasal effects
###########################

## Livery select
var model_name = "CRJ" ~ substr(getprop("sim/aircraft"), 3);
aircraft.livery.init("Models/Liveries/" ~ model_name);

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

    #sound is called for each property change
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
    "controls/flight/flaps"
);
var sound_gearlever = Switch_sound.new("sim/sound/gear-lever", 0.5,
    "controls/gear/gear-lever-moved"
);
var sound_passalert = Switch_sound.new("sim/sound/passenger-sign", 2,
    "sim/model/lights/no-smoking-sign",
    "sim/model/lights/seatbelt-sign"
);
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
    "controls/efis/src-mfd-pilot",
    "controls/efis/src-mfd-copilot",
);

var sound_switchclick2 = Switch_sound.new("sim/sound/click2", 0.1,
    "controls/anti-ice/wiper",
    "instrumentation/altimeter[0]/setting-hpa",
    "controls/efis/sidepanel[0]/nav-xside",
    "controls/efis/sidepanel[0]/brg-src0",
    "controls/efis/sidepanel[0]/brg-src1",
    "controls/efis/sidepanel[0]/nav-src",
    "controls/efis/sidepanel[0]/mfd-format",
    "controls/efis/sidepanel[0]/range-nm",
    "controls/efis/sidepanel[0]/tcas",
    "controls/efis/sidepanel[0]/rtb",
    "controls/efis/sidepanel[0]/use-QNH",
    "instrumentation/altimeter[1]/setting-hpa",
    "controls/efis/sidepanel[1]/nav-xside",
    "controls/efis/sidepanel[1]/brg-src0",
    "controls/efis/sidepanel[1]/brg-src1",
    "controls/efis/sidepanel[1]/nav-src",
    "controls/efis/sidepanel[1]/mfd-format",
    "controls/efis/sidepanel[1]/range-nm",
    "controls/efis/sidepanel[1]/tcas",
    "controls/efis/sidepanel[1]/rtb",
    "controls/efis/sidepanel[1]/use-QNH",
    "instrumentation/eicas[0]/page",
    "controls/pneumatic/cross-bleed",
    "controls/pneumatic/bleed-valve",
    "controls/pneumatic/bleed-source",
    "instrumentation/nav[0]/radials/selected-deg",
    "instrumentation/nav[1]/radials/selected-deg",
    "controls/autoflight/speed-select",
    "controls/autoflight/mach-select",
    "controls/autoflight/heading-select",
    "controls/autoflight/altitude-select",
    "controls/mcp/fd-pressed",
    "controls/mcp/ap-pressed",
    "controls/mcp/speed-pressed",
    "controls/mcp/appr-pressed",
    "controls/mcp/hdg-pressed",
    "controls/mcp/nav-pressed",
    "controls/mcp/alt-pressed",
    "controls/mcp/vst-pressed",
    "controls/mcp/bank-pressed",
);
var sound_switchlightclick = Switch_sound.new("sim/sound/swl-click", 0.1,
    "controls/switchlight-click",
    "controls/electric/ac-service-selected",
    "controls/electric/ac-service-selected-ext",
    "controls/electric/idg1-disc",
    "controls/electric/ac-ess-xfer",
    "controls/electric/idg2-disc",
    "controls/electric/auto-xfer1",
    "controls/electric/auto-xfer2",
    "controls/hydraulic/system[0]/pump-a",
    "controls/hydraulic/system[1]/pump-a",
    "systems/fuel/boost-pump[0]/selected",
    "controls/fuel/gravity-xflow",
    "systems/fuel/boost-pump[1]/selected",
    "controls/fuel/xflow-left",
    "controls/fuel/xflow-manual",
    "controls/fuel/xflow-right",
    "controls/APU/electronic-control-unit",
    "controls/APU/off-on",
    "controls/engines/cont-ignition",
    "controls/engines/engine[0]/starter-cmd",
    "controls/engines/engine[1]/starter-cmd",
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
    "controls/stab-trim/ch1-engage",
    "controls/stab-trim/ch2-engage",
);

## Tire smoke
var tiresmoke_system = aircraft.tyresmoke_system.new(0, 1, 2);

## Lights
# Exterior lights; sim/model/lights/... is used by electrical system to switch outputs
var beacon_light = aircraft.light.new("sim/model/lights/beacon", [0.05, 2.1], "controls/lighting/beacon");
var strobe_light = aircraft.light.new("sim/model/lights/strobe", [0.05, 2], "controls/lighting/strobe");

# cockpit
var altitude_flash = aircraft.light.new("autopilot/annunciators/altitude-flash", [0.4, 0.8], "autopilot/annunciators/altitude-flash-cmd");
var master_warning_flash = aircraft.light.new("instrumentation/eicas/master-warning-light", [1.0, 0.4], "instrumentation/eicas/master-warning");
var master_caution_flash = aircraft.light.new("instrumentation/eicas/master-caution-light", [1.0, 0.4], "instrumentation/eicas/master-caution");

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

