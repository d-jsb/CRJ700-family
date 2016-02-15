## Bombardier CRJ700 series
## Aircraft instrumentation
###########################

## Control display unit (CDU)
var cdu1 = interactive_cdu.Cdu.new("instrumentation/cdu", "Aircraft/CRJ700-family/Systems/CRJ700-cdu.xml");

## Autopilot

# Basic roll mode sync
var roll_sync = func()
{
	#print("sync roll/hdg");
    var roll = getprop("instrumentation/attitude-indicator[0]/indicated-roll-deg");
    if (math.abs(roll) > 5)
    {
        setprop("autopilot/internal/roll-mode", 1);
        setprop("autopilot/ref/roll-deg", roll);
    }
    else
    {
        var heading = getprop("instrumentation/heading-indicator[0]/indicated-heading-deg");
        setprop("autopilot/internal/roll-mode", 0);
        setprop("autopilot/ref/roll-hdg", heading);
    }
};

# Basic pitch mode sync
var pitch_sync = func()
{
	var vmode = getprop("controls/autoflight/vert-mode");
	#print("sync pitch (m:"~vmode~")");    
	if (vmode == 1) { #ALT
		setprop("autopilot/ref/alt-hold", int(getprop("instrumentation/altimeter[0]/indicated-altitude-ft")));
	} elsif (vmode == 2) { #VS
		#setprop("controls/autoflight/vertical-speed-select", int(getprop("instrumentation/vertical-speed-indicator[0]/indicated-speed-fpm")/100)*100);
		setprop("controls/autoflight/vertical-speed-select", getprop("instrumentation/vertical-speed-indicator[0]/indicated-speed-fpm"));
		interpolate("controls/autoflight/vertical-speed-select", int(getprop("instrumentation/vertical-speed-indicator[0]/indicated-speed-fpm")/100)*100, 0.5);
	} elsif (vmode == 3) { #ALTS
		setprop("autopilot/ref/alt-hold", getprop("controls/autoflight/altitude-select"));
	} elsif (vmode == 4) { #SPEED
		setprop("controls/autoflight/speed-select", int(getprop("instrumentation/airspeed-indicator/indicated-speed-kt")));	
		setprop("controls/autoflight/mach-select", getprop("instrumentation/airspeed-indicator/indicated-mach"));	
	} elsif (vmode == 0) { #PTCH
		var pitch = getprop("instrumentation/attitude-indicator[0]/indicated-pitch-deg");
		setprop("controls/autoflight/pitch-select", pitch); 
		interpolate("controls/autoflight/pitch-select", int((pitch / 0.5) + 0.5) * 0.5, 0.5); # round to 0.5 steps
	}
};

# sync
setlistener("controls/autoflight/flight-director/sync", func(n)
{
    if (!n.getBoolValue()) return;
	if (getprop("controls/autoflight/autopilot/engage")) return;
	#print("sync");
	roll_sync();
	pitch_sync();
	n.setBoolValue(0);
}, 0, 0);

setlistener("autopilot/internal/autoflight-engaged", func(n)
{
	if (n.getBoolValue()) {
		var lm = getprop("controls/autoflight/lat-mode");
		var vm = getprop("controls/autoflight/vert-mode");
		setprop("controls/autoflight/flight-director/engage", 1);
		#clear toga
		if (lm == 6 or lm == 7) {
			setprop("controls/autoflight/lat-mode", 0);
			lm = 0;
		}
		if (vm == 6 or vm == 7) {
			setprop("controls/autoflight/vert-mode", 0);
			vm = 0;
		}
		if (lm == 0) roll_sync();
		if (vm == 0) pitch_sync();
	}
}, 0, 0);

#TO/GA mode
setlistener("controls/autoflight/toga-button", func (n) 
{
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
        setprop("autopilot/internal/roll-mode", 0);
        setprop("autopilot/ref/roll-hdg", getprop("instrumentation/heading-indicator[0]/indicated-heading-deg"));
 		n.setBoolValue(0);
	}
}, 1, 0);

var gs_rangeL = nil;
var gs_captureL = nil;
# catch GS if in range and FD in approach mode
var gs_mon = func(n) 
{
	if (getprop("instrumentation/nav[0]/gs-in-range") == 0) return;
	var lm = getprop("controls/autoflight/lat-mode");
	var gsdefl = n.getValue(); 
	if (lm == 3 and (gsdefl < 0.1 and gsdefl > -0.1)) 
	{
		#print("GS capture");
		setprop("controls/autoflight/vert-mode", 5);
		setprop("autopilot/annunciators/gs-armed", 0);
		if (gs_captureL != nil) {
			removelistener(gs_captureL);
			gs_captureL = nil;	
		}
	}
	#if not in APPR mode, cancel GS monitoring
	if (getprop("controls/autoflight/lat-mode") != 3 and gs_captureL != nil) {
		removelistener(gs_captureL);
		gs_captureL = nil;		
	}
}

# lateral mode handler
#2do: arm/capture logic
setlistener("controls/autoflight/lat-mode", func (n) 
{
	var mode = n.getValue();
	var mode_txt = {
		0: "ROLL",
		1: "HDG",
		6: "TO",
		7: "GA",
	};
	#print("l:"~mode);
	if (mode != 0)
        setprop("autopilot/internal/roll-mode", 0);
	if (mode == 0 or mode == 6 or mode == 7) 
		roll_sync();

	#GS arming for APPR mode 
	if (mode == 3 and gs_rangeL == nil) 
	{
		gs_rangeL = setlistener("instrumentation/nav[0]/gs-in-range", func (n) {
				setprop("autopilot/annunciators/gs-armed", 1);
				if (n.getBoolValue()) {
					if (gs_rangeL != nil) {
						removelistener(gs_rangeL);
						gs_rangeL = nil;
					}
					# if GS in range, wait some seconds and track GS
					settimer(func { gs_captureL = setlistener("instrumentation/nav[0]/gs-needle-deflection-deg", gs_mon, 0, 0); }, 4);	
				}
			}, 1, 0);
		#print("gs_rangeL "~gs_rangeL);
	}
	#remove GS arm if leaving APPR mode
	if (mode != 3) 
	{
		setprop("autopilot/annunciators/gs-armed", 0);
		if (gs_rangeL != nil) {
			removelistener(gs_rangeL);
			gs_rangeL = nil;
			#print("gs_rangeL nil");
		}
		if (getprop("/controls/autoflight/vert-mode") == 5)
			setprop("/controls/autoflight/vert-mode", 0);
	}
	if (mode == 0 or mode == 1 or mode == 6 or mode == 7) {
		setprop("autopilot/annunciators/lat-capture", mode_txt[mode]);
		setprop("autopilot/annunciators/lat-armed", "");
	}
	#nav/appr
	if (mode == 2 or mode == 3) 
		nav_annunciator();
}, 0, 1);

# vertical mode handler
#2do: arm/capture logic
setlistener("controls/autoflight/vert-mode", func (n) {
	var mode = n.getValue();
	#capture txt # vert arm only ALTS or GS
	var mode_txt = {
		0: "PTCH",
		1: "ALT", #hold!
		2: "VS",
		3: "ALTS",
		4: "IAS",
		5: "GS",
		6: "TO",
		7: "GA",
	};
	#print("v:"~mode);
	pitch_sync();
	setprop("autopilot/annunciators/vert-capture", mode_txt[mode]);
	if (mode == 1)
		setprop("autopilot/annunciators/altitude-flash-cmd", 0);
	if (mode == 2)
		vs_annunciator();
	if (mode == 4)
		speed_annunciator();
}, 0, 1);

var nav_annunciator = func ()
{
	var nsrc = getprop("controls/autoflight/nav-source");
	var nav_src = ["VOR1", "VOR2", "FMS1", "FMS2"];
	var lm = getprop("controls/autoflight/lat-mode");

	if (lm == 2 or lm == 3) 
	{
		if (nsrc == 0 and getprop("autopilot/internal/vor1-captured") or 
			nsrc == 1 and getprop("autopilot/internal/vor2-captured") or
			nsrc == 2 and getprop("autopilot/internal/fms1-captured"))
		{
			setprop("autopilot/annunciators/lat-capture", nav_src[nsrc]);
			setprop("autopilot/annunciators/lat-armed", "");
		}
		else 
		{
			setprop("autopilot/annunciators/lat-capture", "HDG");
			setprop("autopilot/annunciators/lat-armed", nav_src[nsrc]);
		}
	}	
}
setlistener("autopilot/internal/vor1-captured", nav_annunciator, 0, 0);
setlistener("autopilot/internal/vor2-captured", nav_annunciator, 0, 0);

var vs_annunciator = func () 
{
	var ref = sprintf("%1.1f", getprop("controls/autoflight/vertical-speed-select")/1000);
	if (getprop("controls/autoflight/vert-mode") == 2)
		setprop("autopilot/annunciators/vert-capture", "VS "~ref);
}
setlistener("controls/autoflight/vertical-speed-select", vs_annunciator, 0, 0);

var speed_annunciator = func () 
{
	var ref = int(getprop("controls/autoflight/speed-select"));
	if (getprop("controls/autoflight/vert-mode") == 4) 
		setprop("autopilot/annunciators/vert-capture", "IAS "~ref);
	
}
setlistener("controls/autoflight/speed-select", speed_annunciator, 0, 0);

# Altitude alert
var flash_alt_bug = func()
{
	setprop("autopilot/annunciators/altitude-flash-cmd", 1);
	settimer(func { setprop("autopilot/annunciators/altitude-flash-cmd", 0); }, 10);
}
var altitude_alert = func(n) 
{
	var vm = getprop("controls/autoflight/vert-mode");
	if (n.getBoolValue() and vm != 1 and vm != 3)
	{
		#print("ALT alert ");
		setprop("sim/alarms/altitude-alert", 1);
		settimer(func { setprop("sim/alarms/altitude-alert", 0); }, 1.5);
		flash_alt_bug();
	}
}
setlistener("autopilot/internal/alts-threshold", altitude_alert, 0, 0);

var mda_alert = func(n) 
{
	if (n.getBoolValue())
	{
		setprop("sim/alarms/altitude-alert", 1);
		settimer(func { setprop("sim/alarms/altitude-alert", 0); }, 1.5);		
	}
}
setlistener("autopilot/annunciators/mda-alert", mda_alert, 0, 0);

var altitude_capture = func(n)
{
	#capture = within 200ft of preselected alt and not in alt hold mode
	var vm = getprop("controls/autoflight/vert-mode");
	if (vm == 1) 
		return;
	#capture
	if (n.getBoolValue() and vm != 3 and vm != 5)
	{
		#print("ALT capture 200");
		setprop("autopilot/annunciators/altitude-flash-cmd", 0);
		setprop("autopilot/annunciators/vert-capture", "ALTS CAP");
		setprop("controls/autoflight/vert-mode", 3); #alt track
	}

}
setlistener("autopilot/internal/alts-capture", altitude_capture, 0, 1);

#ALTS rearm / ALT hold
var alts_rearm = func ()
{
	var vm = getprop("controls/autoflight/vert-mode");
	if (vm == 3) 
	{
		setprop("controls/autoflight/vert-mode", 1);
	}	
}
setlistener("controls/autoflight/altitude-select",alts_rearm, 0, 0);

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

## DME-H
setlistener("/instrumentation/dme[0]/hold", func(n) {
	if (n.getBoolValue()) {
		setprop("/instrumentation/dme[0]/frequencies/source", "/instrumentation/dme[0]/frequencies/selected-mhz");
		#setprop("/instrumentation/dme[0]/frequencies/selected-mhz", getprop("/instrumentation/nav[0]/frequencies/selected-mhz"));
	}
	else
		setprop("/instrumentation/dme[0]/frequencies/source", "/instrumentation/nav[0]/frequencies/selected-mhz");
},1,0);

setlistener("/instrumentation/dme[1]/hold", func(n) {
	if (n.getBoolValue()) {
		setprop("/instrumentation/dme[1]/frequencies/source", "/instrumentation/dme[1]/frequencies/selected-mhz");
		#setprop("/instrumentation/dme[1]/frequencies/selected-mhz", getprop("/instrumentation/nav[1]/frequencies/selected-mhz"));
	}
	else
		setprop("/instrumentation/dme[1]/frequencies/source", "/instrumentation/nav[1]/frequencies/selected-mhz");
},1,0);

var view_indices = {};
forindex (var i; view.views) {
	var n = view.views[i].getIndex();
	view_indices[n] = i;
}

var update_als_landinglights = func () 
{
	var cv = getprop("sim/current-view/view-number");
	var tl = getprop("/systems/DC/outputs/taxi-lights");
	var ll = getprop("/systems/DC/outputs/landing-lights");
	var lr = getprop("/systems/DC/outputs/landing-lights[2]");
	var ln = getprop("/systems/DC/outputs/landing-lights[1]");
	
	if (cv == 0 or cv == view_indices[101]) {
		if (ll >= 24) setprop("/sim/rendering/als-secondary-lights/landing-light1-offset-deg", -4);
		elsif (ln >= 24) setprop("/sim/rendering/als-secondary-lights/landing-light1-offset-deg", -1);
		else setprop("/sim/rendering/als-secondary-lights/landing-light1-offset-deg", 0);
		if (lr >= 24) setprop("/sim/rendering/als-secondary-lights/landing-light2-offset-deg", 4);
		elsif (ln >= 24) setprop("/sim/rendering/als-secondary-lights/landing-light2-offset-deg", 1);
		else setprop("/sim/rendering/als-secondary-lights/landing-light2-offset-deg", 0);
		setprop("/sim/rendering/als-secondary-lights/use-landing-light", (ll >= 24 or ln >= 24 or tl >= 24));
		setprop("/sim/rendering/als-secondary-lights/use-alt-landing-light", (lr >= 24 or ll >= 24 and ln >= 24));
		
		#setprop("/sim/rendering/als-secondary-lights/use-landing-light", (ln >= 24));
	}
	else {
		setprop("/sim/rendering/als-secondary-lights/use-landing-light", 0);
		setprop("/sim/rendering/als-secondary-lights/use-alt-landing-light", 0);
	}
}

setlistener("/systems/DC/outputs/taxi-lights", update_als_landinglights, 1, 0);
setlistener("/systems/DC/outputs/landing-lights", update_als_landinglights, 0, 0);
setlistener("/systems/DC/outputs/landing-lights[1]", update_als_landinglights, 0, 0);
setlistener("/systems/DC/outputs/landing-lights[2]", update_als_landinglights, 0, 0);
setlistener("/sim/current-view/view-number", update_als_landinglights, 0, 0);
