##
## Bombardier CRJ700 series
##
## Engine simulation module
##
##

var Engine = {};

# Default fuel density (for YASim jets this is 6.72 lb/gal).
Engine.FUEL_DENSITY = 6.72;

# Returns fuel density.
Engine.fuel_density = func
{
    var total_gal = getprop_safe("/consumables/fuel/total-fuel-gal_us");
    var total_lbs = getprop_safe("/consumables/fuel/total-fuel-lbs");
    if (total_gal != 0)
    {
        return total_lbs / total_gal;
    }
    else
    {
        return Engine.FUEL_DENSITY;
    }
};
# Array of valid (level > 0)  fuel tank nodes.
Engine.valid_fuel_tanks = [];
# Updates the array.
Engine.poll_fuel_tanks = func
{
    var valid_tanks = [];
    foreach (var tank; props.globals.getNode("/consumables/fuel").getChildren("tank"))
    {
        var levelN = tank.getNode("level-lbs", 0);
        if (levelN != nil)
        {
            var level = levelN.getValue();
            if (level != nil and level > 0 and tank.getNode("selected",
                                                            1).getBoolValue())
            {
                append(Engine.valid_fuel_tanks, tank);
            }
        }
    }
};
# True if bleed air is available for engine startup.
Engine.bleed_air = 0;
# Updates the bleed air variable.
Engine.poll_bleed_air = func
{
    var source = getprop("/controls/pneumatic/bleed-source");
    var apu_rpm = getprop_safe("/engines/apu/rpm");
    var eng1_rpm = getprop_safe("/engines/engine[0]/rpm");
    var eng2_rpm = getprop_safe("/engines/engine[1]/rpm");

    if (source == 0)
    {
        if (eng1_rpm > 20 or eng2_rpm > 20)
        {
            Engine.bleed_air = 1;
        }
        else
        {
            Engine.bleed_air = 0;
        }
    }
    elsif (source == 1)
    {
        if (eng2_rpm > 20)
        {
            Engine.bleed_air = 1;
        }
        else
        {
            Engine.bleed_air = 0;
        }
    }
    elsif (source == 2)
    {
        if (apu_rpm >= 100)
        {
            Engine.bleed_air = 1;
        }
        else
        {
            Engine.bleed_air = 0;
        }
    }
    elsif (source == 3)
    {
        if (eng1_rpm > 20)
        {
            Engine.bleed_air = 1;
        }
        else
        {
            Engine.bleed_air = 0;
        }
    }
    else
    {
        # Catch-all.
        Engine.bleed_air = 0;
    }
};

# APU class
#
#   n - index of APU: /engines/apu[n]
#
Engine.Apu = func(n)
{
    var apu = {};
    # Based on the fuel consumption of a 757 APU.
    apu.fuel_burn_pph = 200;

    apu.controls = {};

    apu.controls.ecu = 0;
    apu.controls.ecu_node = props.globals.getNode("/controls/APU[" ~ n ~
                                                  "]/electronic-control-unit", 1);
    apu.controls.ecu_node.setBoolValue(apu.controls.ecu);

    apu.controls.fire_ext = 0;
    apu.controls.fire_ext_node = props.globals.getNode("/controls/APU[" ~ n ~
                                                       "]/fire-switch", 1);
    apu.controls.fire_ext_node.setBoolValue(apu.controls.fire_ext);

    apu.controls.on = 0;
    apu.controls.on_node = props.globals.getNode("/controls/APU[" ~ n ~
                                                 "]/off-on", 1);
    apu.controls.on_node.setBoolValue(apu.controls.on);

    apu.rpm = 0;
    apu.rpm_node = props.globals.getNode("/engines/apu[" ~ n ~ "]/rpm", 1);
    apu.rpm_node.setValue(apu.rpm);

    apu.egt = 0;
    apu.egt_node = props.globals.getNode("/engines/apu[" ~ n ~ "]/egt", 1);
    apu.egt_node.setValue(apu.egt);

    apu.running = 0;
    apu.running_node = props.globals.getNode("/engines/apu[" ~ n ~ "]/running", 1);
    apu.running_node.setBoolValue(apu.running);

    apu.serviceable = 1;
    apu.serviceable_node = props.globals.getNode("/engines/apu[" ~ n ~
                                                 "]/serviceable", 1);
    apu.serviceable_node.setBoolValue(apu.serviceable);

    apu.on_fire = 0;
    apu.on_fire_node = props.globals.getNode("/engines/apu[" ~ n ~ "]/on-fire", 1);
    apu.on_fire_node.setBoolValue(apu.on_fire);

    var read_props = func
    {
        apu.controls.ecu = apu.controls.ecu_node.getValue();
        apu.controls.fire_ext = apu.controls.fire_ext_node.getValue();
        apu.controls.on = apu.controls.on_node.getValue();
        apu.on_fire = apu.on_fire_node.getBoolValue();
        apu.serviceable = apu.serviceable_node.getBoolValue();
    };
    var write_props = func
    {
        apu.rpm_node.setValue(apu.rpm);
        apu.egt_node.setValue(apu.egt);
        apu.running_node.setBoolValue(apu.running);
        apu.on_fire_node.setBoolValue(apu.on_fire);
        apu.serviceable_node.setBoolValue(apu.serviceable);
    };

    apu.update = func
    {
        read_props();

        if (apu.on_fire)
        {
            apu.serviceable = 0;
        }
        if (apu.controls.fire_ext)
        {
            apu.on_fire = 0;
            apu.serviceable = 0;
        }

        var time_delta = getprop_safe("sim/time/delta-realtime-sec");
        if (apu.serviceable and size(Engine.valid_fuel_tanks) > 0 and apu.controls.on)
        {
            apu.rpm = math.min(apu.rpm + 10 * time_delta, 100);
            if (apu.rpm >= 100)
            {
                apu.running = 1;
                # Fuel consumption.
                for (var i = 0; i < size(Engine.valid_fuel_tanks); i += 1)
                {
                    var level_node = Engine.valid_fuel_tanks[i].getNode("level-lbs", 1);
                    var level = level_node.getValue() - (apu.fuel_burn_pph / 3600
                                                         * time_delta) /
                                                         size(Engine.valid_fuel_tanks);
                    level_node.setValue(math.max(level, 0));
                }
            }
            else
            {
                apu.running = 0;
            }
        }
        else
        {
            apu.running = 0;
            apu.rpm = math.max(apu.rpm - 20 * time_delta, 0);
        }

        write_props();
    };

    return apu;
};

# Jet class
#
#   n - index of jet: /engines/engine[n]
#
Engine.Jet = func(n)
{
    var jet = {};
    jet.n1_max_start = 5.21;
    jet.fdm_throttle_idle = 0.02;

    jet.controls = {};

    jet.controls.cutoff = 0;
    jet.controls.cutoff_node = props.globals.getNode("/controls/engines/engine["
                                                     ~ n ~ "]/cutoff", 1);
    jet.controls.cutoff_node.setBoolValue(jet.controls.cutoff);

    jet.controls.fire_ext = 0;
    jet.controls.fire_ext_node = props.globals.getNode("/controls/engines/engine[" ~ n
                                                        ~ "]/fire-bottle-discharge", 1);
    jet.controls.fire_ext_node.setBoolValue(jet.controls.fire_ext);

    jet.controls.reverser_arm = 0;
    jet.controls.reverser_arm_node = props.globals.getNode("/controls/engines/engine["
                                                           ~ n ~ "]/reverser-arm", 1);
    jet.controls.reverser_arm_node.setBoolValue(jet.controls.reverser_arm);

    jet.controls.reverser_cmd = 0;
    jet.controls.reverser_cmd_node = props.globals.getNode("/controls/engines/engine["
                                                           ~ n ~ "]/reverser-cmd", 1);
    jet.controls.reverser_cmd_node.setBoolValue(jet.controls.reverser_cmd);

    jet.controls.starter = 0;
    jet.controls.starter_node = props.globals.getNode("/controls/engines/engine[" ~ n
                                                      ~ "]/starter", 1);
    jet.controls.starter_node.setBoolValue(jet.controls.starter);

    jet.controls.thrust_mode = 0;
    jet.controls.thrust_mode_node = props.globals.getNode("/controls/engines/engine["
                                                          ~ n ~ "]/thrust-mode", 1);
    jet.controls.thrust_mode_node.setIntValue(jet.controls.thrust_mode);

    jet.controls.throttle = 0;
    jet.controls.throttle_node = props.globals.getNode("/fcs/throttle-cmd-norm[" ~ n
                                                       ~ "]", 1);
    jet.controls.throttle_node.setValue(jet.controls.throttle);

    jet.fdm_throttle = 0;
    jet.fdm_throttle_node = props.globals.getNode("/controls/engines/engine[" ~ n ~
                                                  "]/throttle-lever", 1);

    jet.fdm_reverser = 0;
    jet.fdm_reverser_node = props.globals.getNode("/controls/engines/engine[" ~ n ~
                                                  "]/reverser", 1);

    jet.n1 = 0;
    jet.n1_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/rpm", 1);

    jet.fdm_n1 = 0;
    jet.fdm_n1_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/n1", 1);

    jet.fuel_flow_gph = 0;
    jet.fuel_flow_gph_node = props.globals.getNode("/engines/engine[" ~ n ~
                                                   "]/fuel-flow-gph", 1);

    jet.fuel_flow_pph_node = props.globals.getNode("/engines/engine[" ~ n ~
                                                   "]/fuel-flow_pph", 1);

    jet.out_of_fuel = 0;
    jet.out_of_fuel_node = props.globals.getNode("/engines/engine[" ~ n ~
                                                 "]/out-of-fuel", 1);

    jet.running = 0;
    jet.running_node = props.globals.getNode("/engines/engine[" ~ n ~
                                             "]/running", 1);

    jet.on_fire = 0;
    jet.on_fire_node = props.globals.getNode("/engines/engine[" ~ n ~
                                        "]/on-fire", 1);
    jet.on_fire_node.setBoolValue(jet.on_fire);

    jet.serviceable = 1;
    jet.serviceable_node = props.globals.getNode("/engines/engine[" ~ n ~
                                                 "]/serviceable", 1);
    jet.serviceable_node.setBoolValue(jet.serviceable);

    var read_props = func
    {
        jet.controls.cutoff = jet.controls.cutoff_node.getBoolValue();
        jet.controls.fire_ext = jet.controls.fire_ext_node.getBoolValue();
        jet.controls.reverser_arm = jet.controls.reverser_arm_node.getBoolValue();
        jet.controls.reverser_cmd = jet.controls.reverser_cmd_node.getBoolValue();
        jet.controls.starter = jet.controls.starter_node.getBoolValue();
        jet.controls.thrust_mode = jet.controls.thrust_mode_node.getValue();
        jet.controls.throttle = jet.controls.throttle_node.getValue();
        jet.fdm_n1 = jet.fdm_n1_node.getValue();
        jet.fuel_flow_gph = jet.fuel_flow_gph_node.getValue();
        jet.on_fire = jet.on_fire_node.getBoolValue();
        jet.serviceable = jet.serviceable_node.getBoolValue();
    };
    var write_props = func
    {
        jet.controls.reverser_cmd_node.setBoolValue(jet.controls.reverser_cmd);
        jet.controls.starter_node.setBoolValue(jet.controls.starter);
        jet.fdm_throttle_node.setDoubleValue(jet.fdm_throttle);
        jet.fdm_reverser_node.setBoolValue(jet.fdm_reverser);
        jet.n1_node.setValue(jet.n1);
        jet.fuel_flow_gph_node.setValue(jet.fuel_flow_gph);
        jet.fuel_flow_pph_node.setValue(jet.fuel_flow_gph * Engine.fuel_density());
        jet.running_node.setBoolValue(jet.running);
        jet.on_fire_node.setBoolValue(jet.on_fire);
        jet.serviceable_node.setBoolValue(jet.serviceable);
    };
    
    jet.update = func
    {
        read_props();

        if (jet.on_fire)
        {
            jet.serviceable = 0;
        }
        if (jet.controls.fire_ext)
        {
            jet.on_fire = 0;
            jet.serviceable = 0;
        }

        if (jet.controls.reverser_cmd and jet.controls.reverser_arm)
        {
            jet.fdm_reverser = 1;
        }
        else
        {
            jet.fdm_reverser = 0;
        }

        var time_delta = getprop_safe("sim/time/delta-realtime-sec");
        if (!jet.serviceable or jet.out_of_fuel or jet.controls.cutoff)
        {
            jet.running = 0;
            jet.n1 = math.max(jet.n1 - 8 * time_delta, 0);
            jet.fdm_throttle = 0;
        }
        elsif (jet.running)
        {
            jet.fdm_throttle = jet.fdm_throttle_idle + (1 - jet.fdm_throttle_idle)
                               * jet.controls.throttle;
            jet.n1 = jet.fdm_n1;
            jet.controls.starter = 0;
        }
        elsif (jet.controls.starter and Engine.bleed_air)
        {
            jet.n1 = math.min(jet.n1 + 4 * time_delta, jet.fdm_n1);
            if (jet.n1 >= jet.fdm_n1)
            {
                jet.running = 1;
            }
        }
        else
        {
            jet.running = 0;
            jet.n1 = math.max(jet.n1 - 8 * time_delta, 0);
            jet.fdm_throttle = 0;
        }

        write_props();
    };
    jet.toggle_reversers = func
    {
        if (jet.controls.throttle == 0 and jet.controls.thrust_mode == 0)
        {
            jet.controls.reverser_cmd = !jet.controls.reverser_cmd;
        }
    };

    return jet;
};
