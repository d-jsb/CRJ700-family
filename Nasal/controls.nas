## Bombardier CRJ700 series
## Nasal control wrappers
###########################

incAileron = func(v, a)
{
    var norm_hdg = func(x)
    {
        while (x > 360) x -= 360;
        while (x <= 0) x += 360;
        return x;
    };
	print("incAileron ");
    if (props.globals.getNode("controls/autoflight/autopilot/engage", 1).getBoolValue())
    {
        var lat_mode = props.globals.getNode("controls/autoflight/lat-mode", 1).getValue();
        if (lat_mode == 0)
        {
            var roll_mode = props.globals.getNode("autopilot/internal/roll-mode", 1).getValue();
            if (roll_mode == 1)
            {
                # incAileron() was only designed to adjust autopilot heading settings
                # so for roll, just hardcode an increment of 1
                var roll_step = 1.0;
				if (a < 0) roll_step = -1.0;
				fgcommand("property-adjust", props.Node.new(
							  { property: "autopilot/ref/roll-deg",
								step: roll_step
							  }));
            }
            elsif (roll_mode == 0)
            {
                fgcommand("property-assign", props.Node.new(
                              { property: "autopilot/ref/roll-hdg",
                                value: norm_hdg(getprop("autopilot/ref/roll-hdg") + a)
                              }));
            }
        }
        elsif (lat_mode == 1)
        {
            fgcommand("property-assign", props.Node.new(
                          { property: "controls/autoflight/heading-select",
                            value: norm_hdg(getprop("controls/autoflight/heading-select") + a)
                          }));
        }
    }
    else
    {
        fgcommand("property-adjust", props.Node.new({property: "controls/flight/aileron", step: v, min: -1, max: 1}));
    }
}

incElevator = func(v, a)
{
    if (props.globals.getNode("controls/autoflight/autopilot/engage", 1).getBoolValue())
    {
        var mode = props.globals.getNode("controls/autoflight/vert-mode", 1).getValue();
        if (mode == 0)
        {
            # incElevator() was only designed to adjust autopilot altitude settings
            # so for pitch, just hardcode an increment of 1
            var pitch_step = 1.0;
			if (a < 0) pitch_step = -1.0;
			fgcommand("property-adjust", props.Node.new({property: "controls/autoflight/pitch-select",step: pitch_step}));
        }
        elsif (mode == 1)
        {
            fgcommand("property-adjust", props.Node.new({property: "controls/autoflight/altitude-select",step: a}));
        }
        elsif (mode == 2)
        {
            # incElevator() normally doesn't adjust vertical speed settings
            # but why not? :)
            fgcommand("property-adjust", props.Node.new({property: "controls/autoflight/vertical-speed-select",step: a}));
        }
    }
    else
    {
        fgcommand("property-adjust", props.Node.new({property: "controls/flight/elevator",step: v,min: -1,max: 1}));
    }
};

incThrottle = func(v, a)
{
    if (props.globals.getNode("controls/autoflight/autothrottle-engage", 1).getBoolValue())
    {
        var mode = props.globals.getNode("controls/autoflight/speed-mode", 1).getValue();
        if (mode == 0)
        {
            fgcommand("property-adjust", props.Node.new({property: "controls/autoflight/speed-select",step: a}));
        }
        elsif (mode == 1)
        {
            # incThrottle() was only designed to adjust autopilot IAS settings
            # so for Mach, just hardcode an increment of .01
            var mach_step = 0.01;
			if (a < 0) mach_step = -0.01;
            fgcommand("property-adjust", props.Node.new({property: "controls/autoflight/mach-select",step: mach_step}));
        }
    }
    else
    {
        for (var i = 0; i < 2; i += 1)
        {
            var selected = props.globals.getNode("sim/input/selected").getChild("engine", i, 1);
            if (selected.getBoolValue())
            {
                fgcommand("property-adjust", props.Node.new({property: "controls/engines/engine[" ~ i ~ "]/throttle",step: v,min: 0,max: 1}));
            }
        }
    }
};

var cycleSpeedbrake = func(offset=1)
{
    var vals = [0,0.25,0.5,0.75,1];
    fgcommand("property-cycle", props.Node.new({property: "controls/flight/speedbrake",value: vals, offset: offset}));
};

var stepGroundDump = func(v)
{
    fgcommand("property-adjust", props.Node.new({property: "controls/flight/ground-lift-dump",step: v,min: 0,max: 2}));
};

var stepTiller = func(v)
{
		fgcommand("property-adjust", props.Node.new({property: "controls/gear/tiller-steer-deg",step: v,min: -80,max: 80 }));
};

var setTiller = func(v)
{
		fgcommand("property-assign", props.Node.new({property: "controls/gear/tiller-steer-deg",value: v}));
};

var toggleArmReversers = func
{
    fgcommand("property-toggle", props.Node.new({ property: "controls/engines/engine[0]/reverser-armed" }));
    fgcommand("property-toggle", props.Node.new({ property: "controls/engines/engine[1]/reverser-armed" }));
};

var reverseThrust = func
{
	if (getprop("systems/hydraulic/outputs/left-reverser")) CRJ700.engines[0].toggle_reversers();
    if (getprop("systems/hydraulic/outputs/right-reverser")) CRJ700.engines[1].toggle_reversers();
};

var incThrustModes = func(v)
{
    for (var i = 0; i < 2; i += 1)
    {
        var selected = props.globals.getNode("sim/input/selected").getChild("engine", i, 1);
        if (selected.getBoolValue())
        {
            var engine = props.globals.getNode("controls/engines").getChild("engine", i, 1);
            var mode = engine.getChild("thrust-mode", 0, 1);
            if (mode.getValue() == 0)
            {
                if (!engine.getChild("cutoff", 0, 1).getBoolValue() and !engine.getChild("reverser", 0, 1).getBoolValue())
                {
                    fgcommand("property-adjust", props.Node.new({property: mode.getPath(),step: v,min: 0,max: 3}));
                }
            }
            else
            {
				fgcommand("property-adjust", props.Node.new({property: mode.getPath(),step: v,min: 0,max: 3}));
            }
        }
    }
};

#-- slats/flaps handling -- 
# wrap default handler: 
# flaps cmd > 0.022 (= 1 deg) will be postponed until slats are fully extended
# flaps cmd = 0 will retract flaps and only after this retract slats to 0
# flap-stop1.wav 1.326s ~3.567deg (norm: 0.079273)
# time for 0-45: 16.72s -> 1deg = 0.3717111s

#var stoptime = 0.0793;
#Calculated time did not match sound to 3D animation on my PC - needs testing on other PCs
var stoptime = 0.1;
var step1_norm = 0.022;
#It is said some models have no slats, so slats can be switched on/off in CRJ*-set.xml files
var has_slats = getprop("sim/model/has-slats");
var _flapsDown = controls.flapsDown;

controls.flapsDown = func(step) {
	_flapsDown(step);
    var curr = getprop("sim/flaps/current-setting");
	var f_pos = getprop("surface-positions/flap-pos-norm");
	var s_pos = getprop("surface-positions/slat-pos-norm");
	var has_power = getprop("/systems/AC/outputs/flaps-a") or getprop("/systems/AC/outputs/flaps-b");
	#print("Flaps CMD ("~has_slats~"): "~curr~" f:"~f_pos~" s:"~s_pos);

	if (step != 0)	setprop("controls/flight/flaps-stop-snd",0); #abort stop sound
	# command slats if flaps are retracted (1deg counts as retracted to have EICAS show "1" while extending flaps) (and slats are not moving; <- reality check needed)
	#if (f_pos <= step1_norm and (s_pos == 0 or s_pos == 1)) {
	if (has_power and has_slats and f_pos <= step1_norm) {
		setprop("controls/flight/slats-cmd", curr > 0 ? 1 : 0);	
	}
	#command flaps if slats are extended or model has no slats 
	if (has_power and (s_pos == 1.0 or !has_slats)) {
		var f_cmd = getprop("controls/flight/flaps");
		setprop("controls/flight/flaps-cmd", f_cmd);
		# flap sound; 1deg move is to short so skip it
		var diff = f_pos - f_cmd;
		if (diff < 0) diff = -diff;
		if (diff > step1_norm)	
			setprop("controls/flight/flaps-start-snd",1);
	}
};

# monitor slats; trigger flaps handler when slats are fully extended
setlistener("surface-positions/slat-pos-norm", func (n) {
	var pos = n.getValue();
	if (pos == 1.0) {
		#print("slats " ~ pos);
		settimer(func { flapsDown(0); }, 1);
	}	
	if (pos == 0) {
		#print("slats " ~ pos);
		flapsDown(0);
	}	
}, 0, 0);			

# monitor flaps; trigger flaps handler to retract slats
setlistener("surface-positions/flap-pos-norm", func (n) {
	var pos = n.getValue();
	var target = getprop("controls/flight/flaps");
	# calculate when to switch flaps sound
	var diff = target - pos;
	if (diff < 0) diff = -diff;
	if (diff < stoptime) {
		setprop("controls/flight/flaps-start-snd",0);
		if (diff > step1_norm){
			setprop("controls/flight/flaps-stop-snd",1);
		}
	}
	# call cmd handler to check slats
	if (pos <= step1_norm) {
		settimer(func { flapsDown(0); }, 1);
	}	
}, 0, 0);			


## elevator trim handler
## hack to deactivate trim on hydraulic fault.
## could not get the YAsim to work with a different property for elevator-trim :(

var _elevatorTrim = controls.elevatorTrim;

controls.elevatorTrim = func(x) {
	if (getprop("/systems/hydraulic/outputs/elevator") > 0)
		_elevatorTrim(x);
};
