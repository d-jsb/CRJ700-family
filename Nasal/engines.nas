## Bombardier CRJ700 series
## Engine control system
###########################

# NOTE: Update functions are called in systems.nas

# default fuel density (for YASim jets this is 6.72 lb/gal)
var fuel_density = 6.72;
var Apu = {
    new: func(no)
    {
        var m = { parents: [Apu] };
        m.number = no;
        m.has_fuel = 1;
        m.fuel_burn_pph = 200; # a 757 APU consumes about 200 lb/hr on the ground, let's just use this value for our APU

        m.ecu = props.globals.getNode("controls/APU[" ~ no ~ "]/electronic-control-unit", 1);
        m.ecu.setBoolValue(0);
        m.egt = props.globals.getNode("engines/apu[" ~ no ~ "]/egt-degc", 1);
        m.egt.setValue(0);
        m.fire_switch = props.globals.getNode("controls/APU[" ~ no ~ "]/fire-switch", 1);
        m.fire_switch.setBoolValue(0);
        m.on_fire = props.globals.getNode("engines/apu[" ~ no ~ "]/on-fire", 1);
        m.on_fire.setBoolValue(0);
        m.off_on = props.globals.getNode("controls/APU[" ~ no ~ "]/off-on", 1);
        m.off_on.setBoolValue(0);
        m.out_of_fuel = props.globals.getNode("engines/apu[" ~ no ~ "]/out-of-fuel", 1);
        m.out_of_fuel.setBoolValue(0);
        m.rpm = props.globals.getNode("engines/apu[" ~ no ~ "]/rpm", 1);
        m.rpm.setValue(0);
        m.running = props.globals.getNode("engines/apu[" ~ no ~ "]/running", 1);
        m.running.setBoolValue(0);
        m.serviceable = props.globals.getNode("engines/apu[" ~ no ~ "]/serviceable", 1);
        m.serviceable.setBoolValue(1);

        return m;
    },
    update: func
    {
        if (me.on_fire.getBoolValue())
        {
            me.serviceable.setBoolValue(0);
        }
        if (me.fire_switch.getBoolValue())
        {
            me.on_fire.setBoolValue(0);
        }
        var rpm = me.rpm.getValue();
        if (me.serviceable.getBoolValue() and me.off_on.getBoolValue() and me.has_fuel)
        {
            var timeD = getprop("sim/time/delta-realtime-sec");
            rpm += timeD * 10;
            if (rpm >= 100)
            {
                rpm = 100;
                me.running.setBoolValue(1);
                var selected_tanks = [];
                foreach (var tank; props.globals.getNode("consumables/fuel").getChildren("tank"))
                {
                    var levelN = tank.getNode("level-lbs", 0);
                    if (levelN == nil) continue;
                    var level = levelN.getValue();
                    if (level == nil) continue;
                    if (level > 0 and tank.getNode("selected", 1).getBoolValue()) append(selected_tanks, tank);
                }
                if (size(selected_tanks) == 0)
                {
                    me.has_fuel = 0;
                }
                else
                {
                    for (var i = 0; i < size(selected_tanks); i += 1)
                    {
                        var levelN = selected_tanks[i].getNode("level-lbs");
                        var newlevel = levelN.getValue() - (me.fuel_burn_pph / 3600 * timeD) / size(selected_tanks);
                        levelN.setValue(newlevel >= 0 ? newlevel : 0);
                    }
                }
            }
        }
        else
        {
            me.running.setBoolValue(0);
            rpm -= getprop("sim/time/delta-realtime-sec") * 20;
            if (rpm <= 0)
            {
                rpm = 0;
                var selected_tanks = [];
                foreach (var tank; props.globals.getNode("consumables/fuel").getChildren("tank"))
                {
                    var levelN = tank.getNode("level-lbs", 0);
                    if (levelN == nil) continue;
                    var level = levelN.getValue();
                    if (level != nil and level > 0 and tank.getNode("selected", 1).getBoolValue()) append(selected_tanks, tank);
                }
                if (size(selected_tanks) > 0)
                {
                    me.has_fuel = 1;
                }
            }
        }
        me.rpm.setValue(rpm);
        me.egt.setValue(rpm * 4); # not the best way to "simulate" this
        me.out_of_fuel.setBoolValue(!me.has_fuel);
    }
};
var apu1 = Apu.new(0);

var Engine = {
    new: func(no)
    {
        var m = { parents: [Engine] };
        m.number = no;
        m.started = 0;
        m.starting = 0;
        m.max_start_n1 = 5.21;
        m.throttle_at_idle = 0.02;

        m.cutoff = props.globals.getNode("controls/engines/engine[" ~ no ~ "]/cutoff", 1);
        m.cutoff.setBoolValue(0);
        m.fire_bottle_discharge = props.globals.getNode("controls/engines/engine[" ~ no ~ "]/fire-bottle-discharge", 1);
        m.fire_bottle_discharge.setBoolValue(0);
        m.fuel_flow_gph = props.globals.getNode("engines/engine[" ~ no ~ "]/fuel-flow-gph", 1);
        m.fuel_flow_gph.setValue(0);
        m.fuel_flow_pph = props.globals.getNode("engines/engine[" ~ no ~ "]/fuel-flow_pph", 1);
        m.fuel_flow_pph.setValue(0);
        m.n1 = props.globals.getNode("engines/engine[" ~ no ~ "]/n1", 1);
        m.n1.setValue(0);
        m.out_of_fuel = props.globals.getNode("engines/engine[" ~ no ~ "]/out-of-fuel", 1);
        m.out_of_fuel.setBoolValue(0);
        m.on_fire = props.globals.getNode("engines/engine[" ~ no ~ "]/on-fire", 1);
        m.on_fire.setBoolValue(0);
        m.reverser = props.globals.getNode("controls/engines/engine[" ~ no ~ "]/reverser", 1);
        m.reverser.setBoolValue(0);
        m.reverser_arm = props.globals.getNode("controls/engines/engine[" ~ no ~ "]/reverser-armed", 1);
        m.reverser_arm.setBoolValue(0);
        m.reverser_cmd = props.globals.getNode("controls/engines/engine[" ~ no ~ "]/reverser-cmd", 1);
        m.reverser_cmd.setBoolValue(0);
        m.rpm = props.globals.getNode("engines/engine[" ~ no ~ "]/rpm", 1);
        m.rpm.setValue(0);
        m.running = props.globals.getNode("engines/engine[" ~ no ~ "]/running", 1);
        m.running.setBoolValue(0);
        m.serviceable = props.globals.getNode("sim/failure-manager/engines/engine[" ~ no ~ "]/serviceable", 1);
        m.serviceable.setBoolValue(1);
        m.starter = props.globals.getNode("controls/engines/engine[" ~ no ~ "]/starter", 1);
        m.starter.setBoolValue(0);
        m.thrust_mode = props.globals.getNode("controls/engines/enigne[" ~ no ~ "]/thrust-mode", 1);
        m.thrust_mode.setValue(0);
        m.throttle = props.globals.getNode("fcs/throttle-cmd-norm[" ~ no ~ "]", 1);
        m.throttle.setValue(0);
        m.throttle_lever = props.globals.getNode("controls/engines/engine[" ~ no ~ "]/throttle-lever", 1);
        m.throttle_lever.setValue(0);

        return m;
    },
    update: func
    {
        me.starter.setBoolValue(me.starting);
        if (me.running.getBoolValue() and !me.started)
        {
            me.running.setBoolValue(0);
        }
        if (me.fire_bottle_discharge.getBoolValue())
        {
            me.on_fire.setBoolValue(0);
        }
        if (me.on_fire.getBoolValue())
        {
            me.serviceable.setBoolValue(0);
        }
        if (me.cutoff.getBoolValue() or !me.serviceable.getBoolValue() or me.out_of_fuel.getBoolValue())
           {
            var rpm = me.rpm.getValue();
            rpm -= getprop("sim/time/delta-realtime-sec") * 8;
            me.rpm.setValue(rpm <= 0 ? 0 : rpm);
            me.running.setBoolValue(0);
            me.throttle_lever.setValue(0);
            me.thrust_mode.setValue(0);
            me.starting = 0;
            me.started = 0;
        }
        elsif (me.starting)
        {
            if (me._has_bleed_air())
            {
                var rpm = me.rpm.getValue();
                rpm += getprop("sim/time/delta-realtime-sec") * 4;
                me.rpm.setValue(rpm);
                if (rpm >= me.n1.getValue())
                {
                    me.running.setBoolValue(1);
                    me.starting = 0;
                    me.started = 1;
                }
                else
                {
                    me.running.setBoolValue(0);
                }
            }
            else
            {
                me.starting = 0;
            }
        }
        elsif (me.running.getBoolValue())
        {
            me.starting = 0;
            if (me.reverser_cmd.getBoolValue())
            {
                if (me.reverser_arm.getBoolValue())
                {
                    me.reverser.setBoolValue(1);
                }
                else
                {
                    me.reverser_cmd.setBoolValue(0);
                }
            }
            else
            {
                me.reverser.setBoolValue(0);
            }
            me.throttle_lever.setValue(me.throttle_at_idle + (1 - me.throttle_at_idle) * me.throttle.getValue());
            me.rpm.setValue(me.n1.getValue());
        }

        var total_fuel_gal = props.globals.getNode("consumables/fuel/total-fuel-gal_us", 1).getValue();
        var total_fuel_lbs = props.globals.getNode("consumables/fuel/total-fuel-lbs", 1).getValue();
        var density = total_fuel_lbs / total_fuel_gal or fuel_density;
        me.fuel_flow_pph.setValue(me.fuel_flow_gph.getValue() * density);
    },
    start: func
    {
        me.starting = 1;
    },
    abort_start: func
    {
        me.starting = 0;
    },
    reverse_thrust: func
    {
        if (me.throttle.getValue() == 0 and me.thrust_mode.getValue() == 0) me.reverser_cmd.setBoolValue(!me.reverser_cmd.getBoolValue());
    },
    _has_bleed_air: func
    {
        var bleed_source = getprop("controls/pneumatic/bleed-source");
        var apu_rpm = props.globals.getNode("engines/apu/rpm", 1).getValue();
        var eng1_rpm = props.globals.getNode("engines/engine[0]/rpm", 1).getValue();
        var eng2_rpm = props.globals.getNode("engines/engine[1]/rpm", 1).getValue();
        # both engines
        if (bleed_source == 0) return eng1_rpm > 20 or eng2_rpm > 20;
        # right engine
        elsif (bleed_source == 1) return eng2_rpm > 20;
        # APU
        elsif (bleed_source == 2) return apu_rpm >= 100;
        # left engine
        elsif (bleed_source == 3) return eng1_rpm > 20;
        # invalid value, return 0
        return 0;
    }
};
var engine1 = Engine.new(0);
var engine2 = Engine.new(1);
