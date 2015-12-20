##
## Bombardier CRJ700 series
##
## Engine simulation module
##
# GE CF34-8C5		CRJ700 (705), CRJ900, CRJ 900 NextGen
# GE CF34-8C5A1		CRJ1000 NextGen
# GE CF34-8C5B1		CRJ700 NextGen
#
# GE CF34-8C
# dry weight			2,408 lb (1,092 kg) - 2,600 lb (1,200 kg) / 1125 kg
# Thrust at see level	13,790 lbf (61.3 kN) - 14,510 lbf (64.5 kN)
# Thrust to weight		5.3 : 1
# Pressure ratio at max 28:1
# bypass ratio			5:1
# specific fuel cons.   0.68 (lb /h /lbf) -> 9239.3 - 9866.8 lb/h or 2.566 - 2.741 lb/s
# specific-fuel-consumption, which is calculated with kg/h/kN and data refers to TO --> max thrust
#

var Engine = {};

# Default fuel density (for YASim jets this is 6.72 lb/gal).
Engine.FUEL_DENSITY = 6.72;
Engine.FUEL_UNUSABLE = 62; #lbs

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
    Engine.valid_fuel_tanks = [];
    foreach (var tank; props.globals.getNode("/consumables/fuel").getChildren("tank"))
    {
        var levelN = tank.getNode("level-lbs", 0);
        if (levelN != nil)
        {
            var level = levelN.getValue();
            if (level != nil and level > Engine.FUEL_UNUSABLE) # and tank.getNode("selected",1).getBoolValue()
            {
                append(Engine.valid_fuel_tanks, tank);
            }
        }
        setprop("/consumables/fuel/valid-tanks", size(Engine.valid_fuel_tanks));
    }
};


# APU class
#
#   n - index of APU: /engines/apu[n]
#
Engine.Apu = func() {
    var apu = { serviceable : 1, door : 0, running : 0, rpm : 0, egt : 0, on_fire : 0 };
    # Based on the fuel consumption of a 757 APU.
    apu.fuel_burn_pph = 200;
	apu.eicas_door_msg = ["----", "CLSD", "OPEN"];
    apu.controls = { ecu : 0, on : 0, fire_ex : 0 };

    apu.controls.ecu_node = props.globals.getNode("/controls/APU/electronic-control-unit", 1);
    apu.controls.ecu_node.setBoolValue(apu.controls.ecu);

    apu.controls.fire_ex_node = props.globals.getNode("/controls/APU/fire-switch", 1);
    apu.controls.fire_ex_node.setBoolValue(apu.controls.fire_ex);

    apu.controls.on_node = props.globals.getNode("/controls/APU/off-on", 1);
    apu.controls.on_node.setBoolValue(apu.controls.on);

    apu.serviceable_node = props.globals.getNode("/engines/apu/serviceable", 1);
    apu.serviceable_node.setBoolValue(apu.serviceable);
	#abusing unused engine[2] MP enabled property to make door pos visible via MP
    apu.door_node = props.globals.getNode("/engines/engine[2]/n1", 1);
    apu.door_node.setValue(apu.door);
    apu.eicas_door_node = props.globals.getNode("/engines/apu/door-msg", 1);
    apu.eicas_door_node.setValue(apu.eicas_door_msg[0]);

    apu.running_node = props.globals.getNode("/engines/apu/running", 1);
    apu.running_node.setBoolValue(apu.running);

    apu.rpm_node = props.globals.getNode("/engines/engine[2]/rpm", 1);
    apu.rpm_node.setValue(apu.rpm);

    apu.egt = getprop_safe("/environment/temperature-degc");
    apu.egt_node = props.globals.getNode("/engines/apu/egt-degc", 1);
    apu.egt_node.setValue(apu.egt);

    apu.on_fire_node = props.globals.getNode("/engines/apu/on-fire", 1);
    apu.on_fire_node.setBoolValue(apu.on_fire);

    var read_props = func
    {
        apu.controls.ecu = apu.controls.ecu_node.getValue();
        apu.controls.on = apu.controls.on_node.getValue();
        apu.controls.fire_ex = apu.controls.fire_ex_node.getValue();
        apu.serviceable = apu.serviceable_node.getBoolValue();
		apu.door = apu.door_node.getValue();
		apu.running = apu.running_node.getBoolValue();
		apu.rpm = apu.rpm_node.getValue();
		apu.egt = apu.egt_node.getValue();
        apu.on_fire = apu.on_fire_node.getBoolValue();
    };

    var write_props = func
    {
    #    apu.rpm_node.setValue(apu.rpm);
        apu.egt_node.setValue(apu.egt);
        apu.running_node.setBoolValue(apu.running);
        apu.on_fire_node.setBoolValue(apu.on_fire);
        apu.serviceable_node.setBoolValue(apu.serviceable);
    };

	#-- for debugging
	apu.controls_listener = func
	{
		read_props();
		print("APU ecu " ~ apu.controls.ecu );
		print("APU on/off " ~ apu.controls.on );
		print("APU fire ex " ~ apu.controls.fire_ex );
	}
	#setlistener("/controls/APU", apu.controls_listener, 1, 2);

	#-- for debugging
	apu.state_listener = func
	{
		read_props();
		print("APU serviceable " ~ apu.serviceable);
		print("APU running " ~ apu.running);
		print("APU rpm " ~ apu.rpm );
		print("APU egt " ~ apu.egt );
	}
	#setlistener("/engines/apu", apu.state_listener, 1, 2);

	apu.open_door = func
	{
		# on gnd. open to 45 deg (=1) in 2s
		var pos = 1;
		# if (altitude < limit)		
		interpolate(apu.door_node, pos, 2);
	}
	#-- spin up --
	apu.start = func
	{
		read_props();
        if (apu.serviceable and apu.controls.ecu and apu.controls.on and size(Engine.valid_fuel_tanks) > 0)
        {
			if (!apu.door) 
				apu.open_door();
			interpolate(apu.rpm_node, 100, 20 * (100 - apu.rpm)/100, 103,0.5, 100,0.5 );
			interpolate(apu.egt_node, 400, 4, 517,3.5, 468,2, 485,1.5, 415,9, 384,4);
		}
	}

	#-- spin down --
	apu.stop = func
	{
		read_props();
        if (!apu.controls.on)
        {
			#print("APU off");
			#apu.running = 0; # done by rpm listener
			#-- spin down (20s) --
			interpolate(apu.rpm_node, 0, 20 * apu.rpm / 100);
			#-- cool down --
			var outside_temperature = getprop("/environment/temperature-degc");
			if (outside_temperature == nil)
				outside_temperature = 10;

			if (apu.rpm >=100) {
				interpolate(apu.egt_node, 231,4, 197,4, outside_temperature, (197 - outside_temperature)/2);
			}
			elsif (apu.rpm >=50) {
				interpolate(apu.egt_node, 197,4, outside_temperature, (197 - outside_temperature)/2);
			}
			else {
				cooling_time = (apu.egt - outside_temperature)/2;
				if (cooling_time < 1) cooling_time = 1;
				#print("APU cool down to " ~ outside_temperature ~ " in " ~ cooling_time ~ "s");
				interpolate(apu.egt_node, outside_temperature, cooling_time);
			}
        }
#        write_props();
	}

    apu.update = func
    {
        read_props();

        var time_delta = getprop_safe("sim/time/delta-sec");
        if (apu.serviceable and size(Engine.valid_fuel_tanks) > 0 and apu.controls.on and apu.controls.ecu)
        {
			# Fuel consumption.
			for (var i = 0; i < size(Engine.valid_fuel_tanks); i += 1)
			{
				var level_node = Engine.valid_fuel_tanks[i].getNode("level-lbs", 1);
				var level = level_node.getValue() - (apu.fuel_burn_pph / 3600 * time_delta) / size(Engine.valid_fuel_tanks);
				if (level >= 0) {level_node.setValue(level);}
				else {level_node.setValue(0);}
			}
        }
#        write_props();
    };

#-- set listeners for rare events, e.g. not necessary to poll in the update loop

	# APU master switch (ECU = electronic control unit)
	setlistener(apu.controls.ecu_node, func (node)
	{
		if (node.getBoolValue())
		{
			# init value
			apu.egt_node.setValue(getprop("/environment/temperature-degc"));			
			apu.door_node.setValue(0);
			apu.open_door();
		}
		else
		{
			# unset start/stop switch, in case the pilot didn't
			apu.controls.on = 0;
			apu.controls.on_node.setBoolValue(apu.controls.on);
		}
	});

	setlistener(apu.controls.on_node, func (node)
	{
        if (node.getBoolValue())
			apu.start();
		else
			apu.stop();
	});

	setlistener(apu.on_fire_node, func (node)
	{
		if (node.getBoolValue())
            apu.serviceable_node.setBoolValue(0);
	});

	setlistener(apu.controls.fire_ex_node, func(node)
	{
        if (node.getBoolValue())
        {
            apu.on_fire_node.setBoolValue(0);
            apu.serviceable_node.setBoolValue(0);
        }
	});

	#-- monitor RPM to set running (available) flag;
	var rpm_timer = 0;
	setlistener(apu.rpm_node, func(node)
	{
		rpm = node.getValue();
		if (rpm < 99) {
			apu.running_node.setBoolValue(0);
			var on = apu.controls.on_node.getBoolValue();
			if (rpm < 12 and !on)
				interpolate(apu.door_node, 0, 2);
		}
		elsif (99 <= rpm and rpm <= 106)
		{
			if (rpm_timer == 0)
			{
				timer = 1;
				settimer(func
				{
					apu.running_node.setBoolValue(1);
					rpm_timer=0;
				}, 2);
			}
		}
	});

	setlistener(apu.door_node, func(node)
	{
		var door = node.getValue();
		if (door == 0)
			apu.eicas_door_node.setValue(apu.eicas_door_msg[1]);
		if (door == 1)
			apu.eicas_door_node.setValue(apu.eicas_door_msg[2]);
	});

    return apu;
};

# Jet class
#
#   n - index of jet: /engines/engine[n]
#
Engine.Jet = func(n)
{
    var jet = {serviceable: 1, fdm_throttle: 0, fdm_reverser: 0, n1: 0, n2: 0, fdm_n1: 0, fdm_n2: 0, running: 0, on_fire: 0, out_of_fuel: 0};
    jet.fdm_throttle_idle = 0.01;

    jet.controls = {cutoff: 0, fire_ex: 0, reverser_arm: 0, reverser_cmd: 0, starter: 0, thrust_mode: 0, throttle: 0};

    jet.controls.cutoff_node = props.globals.getNode("/controls/engines/engine[" ~ n ~ "]/cutoff", 1);
    jet.controls.cutoff_node.setBoolValue(jet.controls.cutoff);

    jet.controls.fire_ex_node = props.globals.getNode("/controls/engines/engine[" ~ n ~ "]/fire-bottle-discharge", 1);
    jet.controls.fire_ex_node.setBoolValue(jet.controls.fire_ex);

    jet.controls.reverser_arm_node = props.globals.getNode("/controls/engines/engine[" ~ n ~ "]/reverser-armed", 1);
    jet.controls.reverser_arm_node.setBoolValue(jet.controls.reverser_arm);

    jet.controls.reverser_cmd_node = props.globals.getNode("/controls/engines/engine[" ~ n ~ "]/reverser-cmd", 1);
    jet.controls.reverser_cmd_node.setBoolValue(jet.controls.reverser_cmd);

    jet.controls.starter_node = props.globals.getNode("/controls/engines/engine[" ~ n ~ "]/starter", 1);
    jet.controls.starter_node.setBoolValue(jet.controls.starter);

    jet.controls.thrust_mode_node = props.globals.getNode("/controls/engines/engine[" ~ n ~ "]/thrust-mode", 1);
    jet.controls.thrust_mode_node.setIntValue(jet.controls.thrust_mode);

    jet.controls.throttle_node = props.globals.getNode("/fcs/throttle-cmd-norm[" ~ n ~ "]", 1);
    jet.controls.throttle_node.setValue(jet.controls.throttle);

    jet.fdm_throttle_node = props.globals.getNode("/controls/engines/engine[" ~ n ~ "]/throttle-lever", 1);
    jet.fdm_reverser_node = props.globals.getNode("/controls/engines/engine[" ~ n ~ "]/reverser", 1);
    jet.n1_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/rpm", 1);
    jet.n2_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/rpm2", 1);
    jet.fdm_n1_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/n1", 1);
    jet.fdm_n2_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/n2", 1);

    jet.fuel_flow_gph = 0;
    jet.fuel_flow_gph_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/fuel-flow-gph", 1);
    jet.fuel_flow_pph_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/fuel-flow_pph", 1);

    jet.out_of_fuel_node = props.globals.getNode("/engines/engine[" ~ n ~  "]/out-of-fuel", 1);
    jet.running_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/running-nasal", 1, "BOOL");
	jet.running_node.setBoolValue(jet.running);
    jet.on_fire_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/on-fire", 1);
    jet.on_fire_node.setBoolValue(jet.on_fire);
    jet.serviceable_node = props.globals.getNode("/engines/engine[" ~ n ~ "]/serviceable", 1);
    jet.serviceable_node.setBoolValue(jet.serviceable);


	#instant on
	jet.on = func
	{
		jet.controls.cutoff = 0;
		jet.controls.cutoff_node.setBoolValue(jet.controls.cutoff);
		jet.n1 = jet.fdm_n1;
		jet.n2 = jet.fdm_n2;
        jet.n1_node.setValue(jet.n1);
        jet.n2_node.setValue(jet.n2);
		jet.running = 1;
        jet.running_node.setBoolValue(jet.running);
		jet.controls.starter = 0;
        jet.controls.starter_node.setBoolValue(jet.controls.starter);
	};

    jet.update = func
    {
		jet.serviceable = jet.serviceable_node.getBoolValue();
		jet.out_of_fuel = jet.out_of_fuel_node.getBoolValue();
        jet.fdm_n1 = jet.fdm_n1_node.getValue();
        jet.fdm_n2 = jet.fdm_n2_node.getValue();
        jet.fuel_flow_gph = jet.fuel_flow_gph_node.getValue();
        jet.controls.cutoff = jet.controls.cutoff_node.getBoolValue();
        jet.controls.starter = jet.controls.starter_node.getBoolValue();
        jet.controls.throttle = jet.controls.throttle_node.getValue();
		jet.running = jet.running_node.getBoolValue();

        var time_delta = getprop_safe("sim/time/delta-sec");
		# possible states: 
		# off/spin down
		# starting
		# running
		if (!jet.serviceable or jet.out_of_fuel or jet.controls.cutoff)	jet.running = 0;
		
		if (jet.running) {
			jet.controls.starter = 0;
			jet.fdm_throttle = jet.fdm_throttle_idle + (1 - jet.fdm_throttle_idle) * jet.controls.throttle;
			jet.n1 = jet.fdm_n1;
			jet.n2 = jet.fdm_n2;
		}
		elsif (jet.serviceable and !jet.out_of_fuel and jet.controls.starter and jet._has_bleed_air()) {
			jet.n2 = math.min(jet.n2 + 1.99 * time_delta, jet.fdm_n2);
			if (jet.n2 > 25 and jet.controls.cutoff) jet.controls.starter = 0;
			if (jet.n2 > 32) jet.n1 = math.min(jet.n1 + 1.0 * time_delta, jet.fdm_n1);
			if (jet.n1 >= jet.fdm_n1) {
				jet.running = 1;
				jet.controls.starter = 0;
			}
		}
		else {
			#shutdown: N1 25->0 ~15s; N2 60
            jet.running = 0;
            jet.n1 = math.max(jet.n1 - 1.66 * time_delta, 0);
			if (jet.n2 > 28) jet.n2 = math.max(jet.n2 - 4 * time_delta, 0);
			else jet.n2 = math.max(jet.n2 - 1.1 * time_delta, 0);
            jet.fdm_throttle = 0;
		}

		jet.running_node.setBoolValue(jet.running);
        jet.controls.starter_node.setBoolValue(jet.controls.starter);
        jet.fdm_throttle_node.setDoubleValue(jet.fdm_throttle);
        jet.n1_node.setValue(jet.n1);
        jet.n2_node.setValue(jet.n2);
        jet.fuel_flow_gph_node.setValue(jet.fuel_flow_gph);
        jet.fuel_flow_pph_node.setValue(jet.fuel_flow_gph * Engine.fuel_density());
    };

    jet.toggle_reversers = func
    {
		print("Engine toggle_reversers");
        jet.controls.throttle = jet.controls.throttle_node.getValue();
        jet.controls.thrust_mode = jet.controls.thrust_mode_node.getValue();
        if (jet.controls.throttle <= 0.01 and jet.controls.thrust_mode == 0)
        {
            jet.controls.reverser_cmd = !jet.controls.reverser_cmd;
        }
        jet.controls.reverser_cmd_node.setBoolValue(jet.controls.reverser_cmd);
	};


    jet._has_bleed_air = func
    {
		var bleed_source = getprop("/controls/pneumatic/bleed-source");
		var apu_rpm = getprop_safe("/engines/engine[2]/rpm");
		var eng1_rpm = getprop_safe("/engines/engine[0]/rpm");
		var eng2_rpm = getprop_safe("/engines/engine[1]/rpm");
		#print("Bleed source " ~ bleed_source~" a:"~apu_rpm~" 1:"~eng1_rpm~" 2:"~eng2_rpm);
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

#-- set listeners for rare events, e.g. not necessary to poll in the update loop
	setlistener(jet.on_fire_node, func (v)
	{
		print("Engine on fire listener");
		if (v.getBoolValue())
        {
			print("Engine " ~ n ~ " on fire!");
            jet.serviceable_node.setBoolValue(0);
        }
	},0,0);

	setlistener(jet.controls.fire_ex_node, func(v)
	{
		print("Engine fire ex listener");
        if (v.getBoolValue())
        {
			print("Engine " ~ n ~ " fire ext discharge");
            jet.on_fire_node.setBoolValue(0);
            jet.serviceable_node.setBoolValue(0);
        }
	});

	setlistener(jet.controls.reverser_cmd_node, func(v)
	{
		print("Engine reverser listener");
        if (v.getBoolValue() and jet.controls.reverser_arm_node.getBoolValue())
            jet.fdm_reverser_node.setBoolValue(1);
        else
            jet.fdm_reverser_node.setBoolValue(0);
	},0,0);

    return jet;
};
