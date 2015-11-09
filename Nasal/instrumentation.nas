## Bombardier CRJ700 series
## Aircraft instrumentation
###########################

## Control display unit (CDU)
var cdu1 = interactive_cdu.Cdu.new("instrumentation/cdu", "Aircraft/CRJ700-family/Systems/CRJ700-cdu.xml");

## Autopilot
setlistener("autopilot/internal/autoflight-engaged", func(v)
{
	var lm = getprop("controls/autoflight/lat-mode");
	var vm = getprop("controls/autoflight/vert-mode");
	#clear toga
	if (v.getBoolValue()) {
		setprop("controls/autoflight/flight-director/engage", 1);
		if (lm == 6 or lm == 7) setprop("controls/autoflight/lat-mode", 0);
		if (vm == 6 or vm == 7) setprop("controls/autoflight/vert-mode", 0);
	}
}, 0, 0);

# sync
setlistener("controls/autoflight/flight-director/sync", func(v)
{
    if (!v.getBoolValue()) return;
	if (getprop("controls/autoflight/autopilot/engage")) return;
	print("sync");
    var roll = getprop("instrumentation/attitude-indicator[0]/indicated-roll-deg");
	var heading = getprop("instrumentation/heading-indicator[0]/indicated-heading-deg");
	setprop("autopilot/ref/roll-deg", roll);
	setprop("autopilot/ref/roll-hdg", heading);

	var vmode = getprop("controls/autoflight/vert-mode");
	if (vmode == 1) { #ALT
		setprop("controls/autoflight/altitude-select", getprop("instrumentation/altimeter[0]/indicated-altitude-ft"));
	} elsif (vmode == 2) { #VS
		setprop("controls/autoflight/vertical-speed-select", getprop("instrumentation/vertical-speed-indicator[0]/indicated-speed-fpm"));
	} elsif (vmode == 4) { #SPEED
		setprop("controls/autoflight/speed-select", getprop("instrumentation/airspeed-indicator/indicated-speed-kt"));	
		setprop("controls/autoflight/mach-select", getprop("instrumentation/airspeed-indicator/indicated-mach"));	
	} else {
		var pitch = getprop("instrumentation/attitude-indicator[0]/indicated-pitch-deg");
		setprop("controls/autoflight/pitch-select", int((pitch / 0.5) + 0.5) * 0.5); # round to 0.5 steps
	}
	v.setBoolValue(0);
}, 0, 0);

# Basic roll mode controller
setlistener("autopilot/internal/roll-mode-engage", func(v)
{
    if (!v.getBoolValue()) return;
	#print("roll mode engage");
    var roll = getprop("instrumentation/attitude-indicator[0]/indicated-roll-deg");
    if (math.abs(roll) > 5)
    {
        setprop("controls/autoflight/roll-mode", 1);
        setprop("autopilot/ref/roll-deg", roll);
    }
    else
    {
        var heading = getprop("instrumentation/heading-indicator[0]/indicated-heading-deg");
        setprop("controls/autoflight/roll-mode", 0);
        setprop("autopilot/ref/roll-hdg", heading);
    }
}, 0, 0);

# Basic pitch mode controller
setlistener("autopilot/internal/basic-pitch-mode-engage", func(v)
{
    if (!v.getBoolValue()) return;
	#print("Basic pitch mode");
	if (getprop("controls/autoflight/vert-mode") != 0) return; #toga
    var pitch = getprop("instrumentation/attitude-indicator[0]/indicated-pitch-deg");
    setprop("controls/autoflight/pitch-select", int((pitch / 0.5) + 0.5) * 0.5); # round to 0.5 steps
}, 0, 0);

#prevent half-bank in certain lateral modes
setlistener("controls/autoflight/half-bank", func(v)
{
	var lm = getprop("controls/autoflight/lat-mode");
    if (lm == 2 or lm == 3 or lm == 6 or lm == 7)
		v.setValue(0);
}, 0, 1);

#TO/GA mode
setlistener("controls/autoflight/toga-button", func (n) {
	var on_ground = getprop("gear/gear[1]/wow");
	if (n.getValue()) {
		setprop("controls/autoflight/autopilot/engage", 0);
		setprop("controls/autoflight/flight-director/engage", 1);		
		setprop("controls/autoflight/half-bank", 0);
		if (on_ground) {
			setprop("controls/autoflight/lat-mode", 6);
			setprop("controls/autoflight/vert-mode", 6);
		}
		else {
			setprop("controls/autoflight/lat-mode", 7);
			setprop("controls/autoflight/vert-mode", 7);
		}
		# setprop("autopilot/internal/bank-limit-deg", 5);
		setprop("controls/autoflight/pitch-select", 10);
        setprop("controls/autoflight/roll-mode", 0);
        setprop("autopilot/ref/roll-hdg", getprop("instrumentation/heading-indicator[0]/indicated-heading-deg"));
 		n.setBoolValue(0);
	}
}, 1, 0);

var gs_rangeL = nil;
var gs_rateL = nil;
# catch GS if in range and FD in approach mode
var gs_mon = func(v) {
	if (getprop("instrumentation/nav[0]/gs-in-range") == 0) return;
	if (getprop("controls/autoflight/lat-mode") == 3 and getprop("instrumentation/nav[0]/gs-needle-deflection-norm") <= 0) {
		print("GS capture");
		setprop("controls/autoflight/vert-mode", 0);
		if (gs_rateL != nil) {
			removelistener(gs_rateL);
			gs_rateL = nil;	
		}
	}
	#if not in APPR mode, cancel GS monitoring
	if (getprop("controls/autoflight/lat-mode") != 3 and gs_rateL != nil) {
		removelistener(gs_rateL);
		gs_rateL = nil;		
	}
}

setlistener("controls/autoflight/lat-mode", func (n) {
	var mode = n.getValue();
	var bank = getprop("autopilot/internal/bank-limit-deg");

    if (mode == 2 or mode == 3)
		setprop("controls/autoflight/half-bank", 0);
	
	#GS handling in APPR mode 
	if (mode == 3 and gs_rangeL == nil) {
		gs_rangeL = setlistener("instrumentation/nav[0]/gs-in-range", func (v) {
				if (v.getBoolValue()) {
					if (gs_rangeL != nil) {
						removelistener(gs_rangeL);
						gs_rangeL = nil;
					}
					# if GS in range, wait 1s and track GS
					settimer(func { gs_rateL = setlistener("instrumentation/nav[0]/gs-needle-deflection-norm", gs_mon, 1, 0); }, 1);	
				}
			}, 1, 0);
		print("gs_rangeL "~gs_rangeL);
	}
	#remove GS capture if leaving APPR mode
	if (mode != 3 and gs_rangeL != nil) {
		removelistener(gs_rangeL);
		gs_rangeL = nil;
		print("gs_rangeL nil");
	}
}, 1, 1);


## EICAS message system
var Eicas_messages =
{
    messages: [],
    new: func(node, file, lines)
    {
        var m = { parents: [Eicas_messages] };
        m.lines = lines;
        m.node = aircraft.makeNode(node);
        m.file = file;
        m._line_number = 0;
        m._current_level = 0;
        m._current_message = 0;
        m._last_used_line = 0;
        m.reload();
        return m;
    },
    reload: func(file = nil)
    {
        me.file = file == nil ? me.file : file;
        me.root = io.read_properties(me.file);
        me.messages = [];
        var messages = me.root.getChildren("message");
        foreach (var message; messages)
        {
            var message_object =
            {
                line_id: nil,
                text: string.uc(message.getNode("text", 1).getValue()),
                color:
                [
                    message.getNode("color/red", 1).getValue(),
                    message.getNode("color/green", 1).getValue(),
                    message.getNode("color/blue", 1).getValue()
                ],
                condition: message.getNode("condition", 1)
            };
            var priority = message.getNode("priority", 1).getValue() or 0;
            while (size(me.messages) <= priority)
            {
                append(me.messages, []);
            }
            append(me.messages[priority], message_object);
        }
    },
    update: func
    {
        # loop through one message each frame
        # this makes updates less responsive, but doesn't kill the framerate like the old system

        # first, acquire the current message element
        var this_priority_level = me.messages[me._current_level];
        var this_message = this_priority_level[me._current_message];
	
        # decide whether or not to display it
        if (props.condition(this_message.condition))
        {
            this_message.line_id = me._line_number;
            me._display_line (me._line_number, this_message.text, this_message.color);
            me._line_number += 1;
        }
        else
        {
            this_message.line_id = nil;
        }

        # finally increment variables and ensure we're not out-of-range
        me._current_message += 1;
        if (me._current_message >= size(this_priority_level))
        {
            me._current_message = 0;
            me._current_level += 1;
            if (me._current_level >= size(me.messages))
            {
                me._current_level = 0;
                # FIXME: this is probably the bottleneck at this point
                var i = me._line_number;
                while (i <= me._last_used_line)
                {
                    me._hide_line(i);
                    i += 1;
                }
                me._last_used_line = me._line_number;
                me._line_number = 0;
            }
        }
    },
    _display_line: func(index, text, color)
    {
        if (index < me.lines)
        {
            var line = me.node.getChild("line", index, 1);
            line.getNode("message", 1).setValue(text);
            line.getNode("enabled", 1).setBoolValue(1);
            line.getNode("color-red-norm", 1).setDoubleValue(color[0]);
            line.getNode("color-green-norm", 1).setDoubleValue(color[1]);
            line.getNode("color-blue-norm", 1).setDoubleValue(color[2]);
            return 1;
        }
        else
        {
            return 0;
        }
    },
    _hide_line: func(index)
    {
        if (index < me.lines)
        {
            var line = me.node.getChild("line", index, 1);
            line.getNode("enabled", 1).setBoolValue(0);
            return 1;
        }
        else
        {
            return 0;
        }
    }
};
var eicas_messages_page1 = Eicas_messages.new("instrumentation/eicas-messages/page[0]", "Aircraft/CRJ700-family/Systems/CRJ700-EICAS-1.xml", 12);
var eicas_messages_page2 = Eicas_messages.new("instrumentation/eicas-messages/page[1]", "Aircraft/CRJ700-family/Systems/CRJ700-EICAS-2.xml", 13);

## MFDs
var Mfd =
{
    new: func(n)
    {
        var m = {};
        m.number = n;
        m.page = props.globals.getNode("instrumentation/mfd[" ~ n ~ "]/page", 1);
        m.tcas = props.globals.getNode("instrumentation/mfd[" ~ n ~ "]/tcas", 1);
        m.wx = props.globals.getNode("instrumentation/mfd[" ~ n ~ "]/wx", 1);
        setlistener(m.page, func(v)
        {
            var page = v.getValue();
            var tcas = props.globals.getNode("instrumentation/radar[" ~ m.number ~ "]/display-controls/tcas", 1);
            tcas.setBoolValue(page == 3 ? m.tcas.getBoolValue() : 0);
            var wx = props.globals.getNode("instrumentation/radar[" ~ m.number ~ "]/display-controls/WX", 1);
            wx.setBoolValue(page == 6 ? m.wx.getBoolValue() : 0);
        }, 1, 0);
        return m;
    }
};
var Mfd0 = Mfd.new(0);
var Mfd1 = Mfd.new(1);

## Timers
var _normtime_ = func(x)
{
    while (x >= 60) x -= 60;
    return x;
};
# chronometer
var _gettimefmt_ = func(x)
{
    if (x >= 3600)
    {
        return sprintf("%02.f:%02.f", int(x / 3600), _normtime_(int(x / 60)));
    }
    return sprintf("%02.f:%02.f", _normtime_(int(x / 60)), _normtime_(x));
};
var chrono_prop = "instrumentation/clock/chronometer-time-sec";
var chrono_timer = aircraft.timer.new(chrono_prop, 1);
setlistener(chrono_prop, func(v)
{
    var fmtN = props.globals.getNode("instrumentation/clock/chronometer-time-fmt", 1);
    fmtN.setValue(_gettimefmt_(v.getValue()));
}, 0, 0);

# elapsed flight time (another chronometer)
var et_prop = "instrumentation/clock/elapsed-time-sec";
var et_timer = aircraft.timer.new(et_prop, 1, 0);
setlistener(et_prop, func(v)
{
    var fmtN = props.globals.getNode("instrumentation/clock/elapsed-time-fmt", 1);
    fmtN.setValue(_gettimefmt_(v.getValue()));
}, 0, 0);

setlistener("gear/gear[1]/wow", func(v)
{
    if (v.getBoolValue())
    {
        et_timer.stop();
    }
    else
    {
        et_timer.start()
    }
}, 0, 0);

## Format date
setlistener("sim/time/real/day", func(v)
{
    # wait one frame to avoid nil property errors
    settimer(func
    {
        var day = v.getValue();
        var month = getprop("sim/time/real/month");
        var year = getprop("sim/time/real/year");

        var date_node = props.globals.getNode("instrumentation/clock/indicated-date-string", 1);
        date_node.setValue(sprintf("%02.f %02.f", day, month));
        var year_node = props.globals.getNode("instrumentation/clock/indicated-short-year", 1);
        year_node.setValue(substr(year ~ "", 2, 4));
    }, 0);
}, 1, 0);

## Total air temperature (TAT) calculator
# formula is
#  T = S + (1.4 - 1)/2 * M^2
var update_tat = func
{
    var node = props.globals.getNode("environment/total-air-temperature-degc", 1);
    var sat = getprop("environment/temperature-degc");
    var mach = getprop("velocities/mach");
    var tat = sat + 0.2 * mach * mach;#math.pow(mach, 2);
    node.setDoubleValue(tat);
};

## Update copilot's integer properties for transmission
var update_copilot_ints = func
{
    var instruments = props.globals.getNode("instrumentation", 1);
    
    var vsi = instruments.getChild("vertical-speed-indicator", 1, 1);
    vsi.getChild("indicated-speed-fpm-int", 0, 1).setIntValue(int(vsi.getChild("indicated-speed-fpm", 0, 1).getValue()));
    
    var ra = instruments.getChild("radar-altimeter", 1, 1);
    var ra_value = ra.getChild("radar-altitude-ft", 0, 1).getValue();
    if (typeof(ra_value) != "nil")
    {
        ra.getChild("radar-altitude-ft-int", 0, 1).setIntValue(int(ra_value));
    }
};

## Spool up instruments every 5 seconds
var update_spin = func
{
    setprop("instrumentation/attitude-indicator[0]/spin", 1);
    setprop("instrumentation/attitude-indicator[2]/spin", 1);
    setprop("instrumentation/heading-indicator[0]/spin", 1);
    setprop("instrumentation/heading-indicator[1]/spin", 1);
    settimer(update_spin, 5);
};
settimer(update_spin, 2);
