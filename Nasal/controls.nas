## Bombardier CRJ700 series
## Nasal control wrappers
###########################

incAileron = func(v, a)
{
    var norm_hdg = func(x)
    {
        while (x > 360)
        {
            x -= 360;
        }
        while (x <= 0)
        {
            x += 360;
        }
        return x;
    };
    if (props.globals.getNode("controls/autoflight/autopilot/engage", 1).getBoolValue())
    {
        var mode = props.globals.getNode("controls/autoflight/lateral-mode", 1).getValue();
        if (mode == 0)
        {
            var roll_mode = props.globals.getNode("controls/autoflight/basic-roll-mode", 1).getValue();
            if (roll_mode == 0)
            {
                # incAileron() was only designed to adjust autopilot heading settings
                # so for roll, just hardcode an increment of 1
                var roll_step = 1.0;
                if (a > 0)
                {
                    fgcommand("property-adjust", props.Node.new(
                                  {
                                    property: "controls/autoflight/basic-roll-select",
                                    step: roll_step
                                  }));
                }
                elsif (a < 0)
                {
                    fgcommand("property-adjust", props.Node.new(
                                  {
                                    property: "controls/autoflight/basic-roll-select",
                                    step: -roll_step
                                  }));
                }
            }
            elsif (roll_mode == 1)
            {
                fgcommand("property-assign", props.Node.new(
                              {
                                property: "controls/autoflight/basic-roll-heading-select",
                                value: norm_hdg(getprop("controls/autoflight/basic-roll-heading-select") + a)
                              }));
            }
        }
        elsif (mode == 1)
        {
            fgcommand("property-assign", props.Node.new(
                          {
                            property: "controls/autoflight/heading-select",
                            value: norm_hdg(getprop("controls/autoflight/heading-select") + a)
                          }));
        }
    }
    else
    {
        fgcommand("property-adjust", props.Node.new(
                      {
			property: "controls/flight/aileron",
			step: v,
			min: -1,
			max: 1
                      }));
    }
}
incElevator = func(v, a)
{
    if (props.globals.getNode("controls/autoflight/autopilot/engage", 1).getBoolValue())
    {
        var mode = props.globals.getNode("controls/autoflight/vertical-mode", 1).getValue();
        if (mode == 0)
        {
            # incElevator() was only designed to adjust autopilot altitude settings
            # so for pitch, just hardcode an increment of 1
            var pitch_step = 1.0;
            if (a > 0)
            {
                fgcommand("property-adjust", props.Node.new(
                              {
                                property: "controls/autoflight/pitch-select",
                                step: pitch_step
                              }));
            }
            elsif (a < 0)
            {
                fgcommand("property-adjust", props.Node.new(
                              {
                                property: "controls/autoflight/pitch-select",
                                step: -pitch_step
                              }));
            }
        }
        elsif (mode == 1)
        {
            fgcommand("property-adjust", props.Node.new(
                          {
                            property: "controls/autoflight/altitude-select",
                            step: a
                          }));
        }
        elsif (mode == 2)
        {
            # incElevator() normally doesn't adjust vertical speed settings
            # but why not? :)
            fgcommand("property-adjust", props.Node.new(
                          {
                            property: "controls/autoflight/vertical-speed-select",
                            step: a
                          }));
        }
    }
    else
    {
        fgcommand("property-adjust", props.Node.new(
                      {
			property: "controls/flight/elevator",
			step: v,
			min: -1,
			max: 1
                      }));
    }
};
incThrottle = func(v, a)
{
    if (props.globals.getNode("controls/autoflight/autothrottle-engage", 1).getBoolValue())
    {
        var mode = props.globals.getNode("controls/autoflight/speed-mode", 1).getValue();
        if (mode == 0)
        {
            fgcommand("property-adjust", props.Node.new(
                          {
                            property: "controls/autoflight/speed-select",
                            step: a
                          }));
        }
        elsif (mode == 1)
        {
            # incThrottle() was only designed to adjust autopilot IAS settings
            # so for Mach, just hardcode an increment of .01
            var mach_step = 0.01;
            if (a > 0)
            {
                fgcommand("property-adjust", props.Node.new(
                              {
                                property: "controls/autoflight/mach-select",
                                step: mach_step
                              }));
            }
            elsif (a < 0)
            {
                fgcommand("property-adjust", props.Node.new(
                              {
                                property: "controls/autoflight/mach-select",
                                step: -mach_step
                              }));
            }
        }
    }
    else
    {
        for (var i = 0; i < 2; i += 1)
        {
            var selected = props.globals.getNode("sim/input/selected").getChild("engine", i, 1);
            if (selected.getBoolValue())
            {
                fgcommand("property-adjust", props.Node.new(
                              {
                                property: "controls/engines/engine[" ~ i ~ "]/throttle",
                                step: v,
                                min: 0,
                                max: 1
                              }));
            }
        }
    }
};
var cycleSpeedbrake = func
{
    var vals =
	[
         0,
         0.25,
         0.5,
         0.75,
         1
	];
    fgcommand("property-cycle", props.Node.new(
                  {
                    property: "controls/flight/speedbrake",
                    value: vals
                  }));
};
var stepGroundDump = func(v)
{
    fgcommand("property-adjust", props.Node.new(
                  {
                    property: "controls/flight/ground-lift-dump",
                    step: v,
                    min: 0,
                    max: 2
                  }));
};
var stepTiller = func(v)
{
    fgcommand("property-adjust", props.Node.new(
                  {
                    property: "controls/gear/tiller-steer-deg",
                    step: v,
                    min: -80,
                    max: 80
                  }));
};
var setTiller = func(v)
{
    fgcommand("property-assign", props.Node.new(
                  {
                    property: "controls/gear/tiller-steer-deg",
                    value: v
                  }));
};
var toggleArmReversers = func
{
    fgcommand("property-toggle", props.Node.new({ property: "controls/engines/engine[0]/reverser-armed" }));
    fgcommand("property-toggle", props.Node.new({ property: "controls/engines/engine[1]/reverser-armed" }));
};
var reverseThrust = func
{
    CRJ700.engines[0].toggle_reversers();
    CRJ700.engines[1].toggle_reversers();
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
                    fgcommand("property-adjust", props.Node.new(
                                  {
                                    property: mode.getPath(),
                                    step: v,
                                    min: 0,
                                    max: 3
                                  }));
                }
            }
            else
            {
                fgcommand("property-adjust", props.Node.new(
                              {
                                property: mode.getPath(),
                                step: v,
                                min: 0,
                                max: 3
                              }));
            }
        }
    }
};
