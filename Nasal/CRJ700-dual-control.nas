###############################################################################
##
## Nasal for dual control of the CRJ700 over the multiplayer network.
##
##  Copyright (C) 2008 - 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##                       2011  Ryan Miller
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

var CONTROL_SEND_TIME = 1.0;
var mp_props = props.globals.getNode("sim/multiplay/generic");

# Renaming (almost :)
var DCT = dual_control_tools;

# Utility functions
var fireControl = func(n)
{
	n = aircraft.makeNode(n);
	n.setBoolValue(1);
	settimer(func
	{
		n.setBoolValue(0);
	}, CONTROL_SEND_TIME);
};

######################################################################
# Pilot/copilot aircraft identifiers. Used by dual_control.
var pilot_type = nil;
var copilot_type = "Aircraft/CRJ700-family/Models/CRJ700-firstofficer.xml";

props.globals.initNode("/sim/remote/pilot-callsign", "", "STRING");

######################################################################
# MP enabled properties.
# NOTE: These must exist very early during startup - put them
#       in the -set.xml file.

######################################################################
# Useful local property paths.

# Flight controls
var pilot_aileron = "controls/flight/aileron";
var pilot_elevator = "controls/flight/elevator";
var pilot_rudder = "controls/flight/rudder";
var copilot_fcs_active = "fcs/copilot/active";
var copilot_aileron = "fcs/copilot/aileron-cmd-norm";
var copilot_elevator = "fcs/copilot/elevator-cmd-norm";
var copilot_rudder = "fcs/copilot/rudder-cmd-norm";
var copilot_tiller = "fcs/copilot/tiller-steer-deg";
var copilot_brake_left = "fcs/copilot/brake-left-cmd-norm";
var copilot_brake_right = "fcs/copilot/brake-right-cmd-norm";

# Engines
var pilot_throttle_1 = "controls/engines/engine[0]/throttle";
var pilot_throttle_2 = "controls/engines/engine[1]/throttle";
var copilot_throttle_1 = "fcs/copilot/throttle-cmd-norm[0]";
var copilot_throttle_2 = "fcs/copilot/throttle-cmd-norm[1]";

######################################################################
# Slow state properties for replication.
var pilot_send_TDM_properties =
[
	# electrical
	"systems/electrical/outputs/panel-lights",
	"systems/electrical/outputs/efis",
	# autoflight
	"controls/autoflight/altitude-select",
	"autopilot/internal/bank-limit-deg",
	"controls/autoflight/heading-select",
	"controls/autoflight/mach-select",
	"controls/autoflight/speed-select",
	"controls/autoflight/vertical-speed-select",
	# instrumentation
	"instrumentation/altimeter[0]/setting-inhg",
	"instrumentation/altimeter[1]/setting-inhg",
	"instrumentation/altimeter[2]/setting-inhg",
	# radios
	"instrumentation/nav[0]/frequencies/selected-mhz",
	"instrumentation/nav[0]/frequencies/standby-mhz",
	"instrumentation/comm[0]/frequencies/selected-mhz",
	"instrumentation/comm[0]/frequencies/standby-mhz",
	"instrumentation/adf[0]/frequencies/selected-khz",
	"instrumentation/adf[0]/frequencies/standby-khz",
	"instrumentation/transponder/id-code",
	"instrumentation/transponder/standby-id-code"
];
var pilot_send_S_properties =
[
	# autoflight
	"controls/autoflight/autopilot/engage",
	"controls/autoflight/yaw-damper[0]/engage",
	"controls/autoflight/yaw-damper[1]/engage",
	"controls/autoflight/autothrottle-engage",
	"controls/autoflight/disengage-pos-norm",
	"controls/autoflight/lat-mode",
	"controls/autoflight/nav-source",
	"controls/autoflight/speed-mode",
	"controls/autoflight/vert-mode",
	# flight controls
	"controls/engines/engine[0]/thrust-mode",
	"controls/engines/engine[1]/thrust-mode",
	"controls/engines/engine[0]/reverser-armed",
	"controls/engines/engine[1]/reverser-armed",
	"controls/engines/engine[0]/starter",
	"controls/engines/engine[1]/starter",
	"controls/flight/speedbrake",
	"controls/flight/ground-lift-dump",
	# instrumentation
	"instrumentation/eicas[0]/page",
	"instrumentation/eicas[1]/page",
	"instrumentation/mfd[0]/page",
	"instrumentation/mfd[0]/tcas",
	"instrumentation/mfd[0]/wx",
	"instrumentation/mfd[1]/page",
	"instrumentation/mfd[1]/tcas",
	"instrumentation/mfd[1]/wx",
	"instrumentation/use-metric-altitude",
	# systems controls
	"controls/anti-ice/wiper[0]",
	"controls/anti-ice/wiper[1]",
	"controls/anti-ice/wing-heat",
	"controls/anti-ice/engine[0]/inlet-heat",
	"controls/anti-ice/engine[1]/inlet-heat",
	"controls/lighting/nav-lights",
	"controls/lighting/beacon",
	"controls/lighting/strobe",
	"controls/lighting/logo-lights",
	"controls/lighting/wing-lights",
	"controls/lighting/landing-lights[0]",
	"controls/lighting/landing-lights[1]",
	"controls/lighting/landing-lights[2]",
	"controls/lighting/taxi-lights",
	"controls/electric/dc-service-switch",
	"controls/electric/battery-switch",
	"controls/electric/engine[0]/generator",
	"controls/electric/APU-generator",
	"controls/electric/engine[1]/generator",
	"controls/pneumatic/bleed-source",
	"controls/pneumatic/ram-air-turbine",
	"controls/APU/electronic-control-unit",
	"controls/APU/off-on"
];
# all of these use SwitchEncoder's
var copilot_send_properties =
[
	"controls/flight/flaps-up",
	"controls/flight/flaps-down",
	"controls/gear/gear-down",
	"controls/gear/brake-parking-toggle",
	"controls/flight/speedbrake-cycle",
	"controls/flight/ground-lift-dump-up",
	"controls/flight/ground-lift-dump-down",
	"controls/engines/arm-reversers",
	"controls/engines/reversers",
	"controls/engines/thrust-modes-up",
	"controls/engines/thrust-modes-down"
];

## split these lists of properties into usable lists for encoder/decoder creation
var pilot_send_TDM_encoders = [];
var array = [];
var i = 0;
foreach (var n; pilot_send_TDM_properties)
{
	append(array, aircraft.makeNode(n));
	# hardcode a TDM encoder limit of 10 properties
	if (size(array) >= 10 and i < 4) # strings 16-19 are reserved so only 4 can be used
	{
		append(pilot_send_TDM_encoders, array);
		array = [];
		i += 1;
	}
}
if (size(array) > 0)
{
	append(pilot_send_TDM_encoders, array);
}

var pilot_send_S_encoders = [];
array = [];
i = 0;
foreach (var n; pilot_send_S_properties)
{
	append(array, aircraft.makeNode(n));
	if (size(array) >= 32 and i < 4) # strings 16-19 are reserved so only 4 can be used
	{
		append(pilot_send_S_encoders, array);
		array = [];
		i += 1;
	}
}
if (size(array) > 0)
{
	append(pilot_send_S_encoders, array);
}

###############################################################################
# Pilot MP property mappings and specific copilot connect/disconnect actions.

var get_pilot_encoders = func
{
	var encoders = [];
	for (var i = 0; i < size(pilot_send_TDM_encoders); i += 1)
	{
		append(encoders, DCT.TDMEncoder.new(pilot_send_TDM_encoders[i], mp_props.getChild("string", i + 16, 1)));
	}
	for (i = 0; i < size(pilot_send_S_encoders); i += 1)
	{
		append(encoders, DCT.SwitchEncoder.new(pilot_send_S_encoders[i], mp_props.getChild("int", i + 16, 1)));
	}
	return encoders;
};
var get_pilot_decoders = func(copilot)
{
	return
	[
		DCT.SwitchDecoder.new(copilot.getNode("sim/multiplay/generic").getChild("int", 2, 1),
		[
			func(v)
			{
				if (v) controls.flapsDown(-1);
			},
			func(v)
			{
				if (v) controls.flapsDown(1);
			},
			func(v)
			{
				if (v) controls.gearToggle();
			},
			func(v)
			{
				if (v) controls.applyParkingBrake(1);
			},
			func(v)
			{
				if (v) controls.cycleSpeedbrake();
			},
			func(v)
			{
				if (v) controls.stepGroundDump(1);
			},
			func(v)
			{
				if (v) controls.stepGroundDump(-1);
			},
			func(v)
			{
				if (v) controls.toggleArmReversers();
			},
			func(v)
			{
				if (v) controls.reverseThrust();
			},
			func(v)
			{
				if (v) controls.incThrustModes(1);
			},
			func(v)
			{
				if (v) controls.incThrustModes(-1);
			}
		])
	];
};

var get_copilot_encoders = func
{
	var n_array = [];
	foreach (var prop; copilot_send_properties)
	{
		append(n_array, props.globals.getNode(prop, 1));
	}
	return [ DCT.SwitchEncoder.new(n_array, mp_props.getChild("int", 0, 1)) ];
};
var get_copilot_decoders = func(pilot)
{
	var decoders = [];
	for (var i = 0; i < size(pilot_send_TDM_encoders); i += 1)
	{
		var encoder_prop = pilot.getNode("sim/multiplay/generic").getChild("string", i + 16, 1);
		var action_array = [];
		foreach (var propN; pilot_send_TDM_encoders[i])
		{
			var prop_type = propN.getType();
			var prop = propN.getPath();
			prop = substr(prop, 1, size(prop) - 1);
			var _get_action = func(prop)
			{
				return func(v)
				{
					pilot.getNode(prop, 1).setValue(v);
				};
			};
			append(action_array, _get_action(prop));
		}
		append(decoders, DCT.TDMDecoder.new(encoder_prop, action_array));
	}
	for (i = 0; i < size(pilot_send_S_encoders); i += 1)
	{
		var encoder_prop = pilot.getNode("sim/multiplay/generic").getChild("int", i + 16, 1);
		var action_array = [];
		foreach (var propN; pilot_send_S_encoders[i])
		{
			var prop = propN.getPath();
			prop = substr(prop, 1, size(prop) - 1);
			var _get_action = func(prop)
			{
				return func(v)
				{
					pilot.getNode(prop, 1).setValue(v);
				};
			};
			append(action_array, _get_action(prop));
		}
		append(decoders, DCT.SwitchDecoder.new(encoder_prop, action_array));
	}
	return decoders;
};

######################################################################
# Used by dual_control to set up the mappings for the pilot.
var pilot_connect_copilot = func(copilot)
{
	# tell the FCS that the copilot yoke is connected and alias the control inputs.
	settimer(func
	{
		props.globals.getNode(copilot_fcs_active, 1).setBoolValue(1);

		var copilot_aileron_n = props.globals.getNode(copilot_aileron, 1);
		copilot_aileron_n.unalias();
		copilot_aileron_n.alias(copilot.getNode("sim/multiplay/generic/float[0]", 1));

		var copilot_elevator_n = props.globals.getNode(copilot_elevator, 1);
		copilot_elevator_n.unalias();
		copilot_elevator_n.alias(copilot.getNode("sim/multiplay/generic/float[1]", 1));

		var copilot_rudder_n = props.globals.getNode(copilot_rudder, 1);
		copilot_rudder_n.unalias();
		copilot_rudder_n.alias(copilot.getNode("sim/multiplay/generic/float[2]", 1));

		var copilot_throttle_1_n = props.globals.getNode(copilot_throttle_1, 1);
		copilot_throttle_1_n.unalias();
		copilot_throttle_1_n.alias(copilot.getNode("sim/multiplay/generic/float[3]", 1));

		var copilot_throttle_2_n = props.globals.getNode(copilot_throttle_2, 1);
		copilot_throttle_2_n.unalias();
		copilot_throttle_2_n.alias(copilot.getNode("sim/multiplay/generic/float[4]", 1));
		
		var copilot_tiller_n = props.globals.getNode(copilot_tiller, 1);
		copilot_tiller_n.unalias();
		copilot_tiller_n.alias(copilot.getNode("sim/multiplay/generic/float[5]", 1));
		
		var copilot_brake_left_n = props.globals.getNode(copilot_brake_left, 1);
		copilot_brake_left_n.unalias();
		copilot_brake_left_n.alias(copilot.getNode("sim/multiplay/generic/float[6]", 1));
		
		var copilot_brake_right_n = props.globals.getNode(copilot_brake_right, 1);
		copilot_brake_right_n.unalias();
		copilot_brake_right_n.alias(copilot.getNode("sim/multiplay/generic/float[7]", 1));

		props.globals.getNode("instrumentation/nav[1]/frequencies/selected-mhz", 1).alias(copilot.getNode("sim/multiplay/generic/float[8]", 1));
		props.globals.getNode("instrumentation/nav[1]/frequencies/standby-mhz", 1).alias(copilot.getNode("sim/multiplay/generic/float[9]", 1));
		props.globals.getNode("instrumentation/comm[1]/frequencies/selected-mhz", 1).alias(copilot.getNode("sim/multiplay/generic/float[10]", 1));
		props.globals.getNode("instrumentation/comm[1]/frequencies/standby-mhz", 1).alias(copilot.getNode("sim/multiplay/generic/float[11]", 1));
		props.globals.getNode("instrumentation/adf[1]/frequencies/selected-khz", 1).alias(copilot.getNode("sim/multiplay/generic/int[0]", 1));
		props.globals.getNode("instrumentation/adf[1]/frequencies/standby-khz", 1).alias(copilot.getNode("sim/multiplay/generic/int[1]", 1));
	}, 1);
	return get_pilot_encoders() ~ get_pilot_decoders(copilot);
};

######################################################################
var pilot_disconnect_copilot = func
{
	# tell the FCS that the copilot yoke is disconnected and un-alias the control inputs.
	props.globals.getNode(copilot_fcs_active, 1).setBoolValue(0);
	var copilot_aileron_n = props.globals.getNode(copilot_aileron, 1);
	copilot_aileron_n.unalias();
	copilot_aileron_n.alias(props.globals.getNode(pilot_aileron, 1));

	var copilot_elevator_n = props.globals.getNode(copilot_elevator, 1);
	copilot_elevator_n.unalias();
	copilot_elevator_n.alias(props.globals.getNode(pilot_elevator, 1));

	var copilot_rudder_n = props.globals.getNode(copilot_rudder, 1);
	copilot_rudder_n.unalias();
	copilot_rudder_n.alias(props.globals.getNode(pilot_rudder, 1));

	var copilot_throttle_1_n = props.globals.getNode(copilot_throttle_1, 1);
	copilot_throttle_1_n.unalias();
	copilot_throttle_1_n.alias(props.globals.getNode(pilot_throttle_1, 1));

	var copilot_throttle_2_n = props.globals.getNode(copilot_throttle_2, 1);
	copilot_throttle_2_n.unalias();
	copilot_throttle_2_n.alias(props.globals.getNode(pilot_throttle_2, 1));

	props.globals.getNode("fcs/copilot/active").setBoolValue(0);
	props.globals.getNode("instrumentation/nav[1]/frequencies/selected-mhz").unalias();
	props.globals.getNode("instrumentation/nav[1]/frequencies/standby-mhz").unalias();
	props.globals.getNode("instrumentation/comm[1]/frequencies/selected-mhz").unalias();
	props.globals.getNode("instrumentation/comm[1]/frequencies/standby-mhz").unalias();
	props.globals.getNode("instrumentation/adf[1]/frequencies/selected-khz").unalias();
	props.globals.getNode("instrumentation/adf[1]/frequencies/standby-khz").unalias();
};

######################################################################
# Used by dual_control to set up the mappings for the copilot.
var copilot_connect_pilot = func(pilot)
{
	copilot_alias_aimodel(pilot);
	# Initialize Nasal wrappers for copilot pick anaimations.
	set_copilot_wrappers(pilot);
	
	props.globals.getNode("instrumentation/nav[0]/frequencies/selected-mhz", 1).alias(pilot.getNode("instrumentation/nav[0]/frequencies/selected-mhz", 1));
	props.globals.getNode("instrumentation/nav[0]/frequencies/standby-mhz", 1).alias(pilot.getNode("instrumentation/nav[0]/frequencies/standby-mhz", 1));
	props.globals.getNode("instrumentation/comm[0]/frequencies/selected-mhz", 1).alias(pilot.getNode("instrumentation/comm[0]/frequencies/selected-mhz", 1));
	props.globals.getNode("instrumentation/comm[0]/frequencies/standby-mhz", 1).alias(pilot.getNode("instrumentation/comm[0]/frequencies/standby-mhz", 1));
	props.globals.getNode("instrumentation/adf[0]/frequencies/selected-khz", 1).alias(pilot.getNode("instrumentation/adf[0]/frequencies/selected-khz", 1));
	props.globals.getNode("instrumentation/adf[0]/frequencies/standby-khz", 1).alias(pilot.getNode("instrumentation/adf[0]/frequencies/standby-khz", 1));
	props.globals.getNode("instrumentation/transponder/id-code", 1).alias(pilot.getNode("instrumentation/transponder/id-code", 1));
	props.globals.getNode("instrumentation/transponder/standby-id-code", 1).alias(pilot.getNode("instrumentation/transponder/standby-id-code", 1));
	
	return get_copilot_encoders() ~ get_copilot_decoders(pilot);
};

######################################################################
var copilot_disconnect_pilot = func
{
	props.globals.getNode("instrumentation/nav[0]/frequencies/selected-mhz", 1).unalias();
	props.globals.getNode("instrumentation/nav[0]/frequencies/standby-mhz", 1).unalias();
	props.globals.getNode("instrumentation/comm[0]/frequencies/selected-mhz", 1).unalias();
	props.globals.getNode("instrumentation/comm[0]/frequencies/standby-mhz", 1).unalias();
	props.globals.getNode("instrumentation/adf[0]/frequencies/selected-khz", 1).unalias();
	props.globals.getNode("instrumentation/adf[0]/frequencies/standby-kkz", 1).unalias();
	props.globals.getNode("instrumentation/transponder/id-code", 1).unalias();
	props.globals.getNode("instrumentation/transponder/standby-id-code", 1).unalias();
};

######################################################################
# Copilot Nasal wrappers

var set_copilot_wrappers = func(pilot)
{
	#######################################################
	# controls.nas wrapper overrides.
	controls.flapsDown = func(v)
	{
		if (v < 0)
		{
			fireControl(copilot_send_properties[0]);
		}
		elsif (v > 0)
		{
			fireControl(copilot_send_properties[1]);
		}
	};
	controls.gearToggle = func
	{
		fireControl(copilot_send_properties[2]);
	};
	controls.gearDown = controls.gearToggle; # ugly hack, I know...
	controls.applyParkingBrake = func(v)
	{
		if (v) fireControl(copilot_send_properties[3]);
	};
	controls.cycleSpeedbrake = func
	{
		fireControl(copilot_send_properties[4]);
	};
	controls.stepGroundDump = func(v)
	{
		if (v > 0)
		{
			fireControl(copilot_send_properties[5]);
		}
		elsif (v < 0)
		{
			fireControl(copilot_send_properties[6]);
		}
	};
	controls.toggleArmReversers = func
	{
		fireControl(copilot_send_properties[7]);
	};
	controls.reverseThrust = func
	{
		fireControl(copilot_send_properties[8]);
	};
	controls.incThrustModes = func(v)
	{
		if (v > 0)
		{
			fireControl(copilot_send_properties[9]);
		}
		elsif (v < 0)
		{
			fireControl(copilot_send_properties[10]);
		}
	};
};

######################################################################
# More property aliases to animate the MP/AI model for the copilot.
#  Contains all 1:1 mappings that are not provided by other modules
#  (e.g. instruments).
var copilot_alias_aimodel = func(pilot)
{
	pilot.getNode("sim/model/yokes", 1).alias(props.globals.getNode("sim/model/yokes", 1));
	pilot.getNode("sim/current-view/internal", 1).alias(props.globals.getNode("sim/current-view/internal"));
	pilot.getNode("sim/virtual-cockpit", 1).alias(props.globals.getNode("sim/virtual-cockpit"));
};

