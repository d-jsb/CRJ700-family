#-------------------------------------------------------------------------------
# Bombardier CRJ700 series
# Aircraft instrumentation
#
# autopilot code moved to autopilot.nas
#-------------------------------------------------------------------------------

## Control display unit (CDU)
var cdu1 = interactive_cdu.Cdu.new("instrumentation/cdu", "Systems/CRJ700-cdu.xml");

## Timers
var _normtime_ = func(x) {
    #while (x >= 60) x -= 60;
    return math.mod(x, 60); #x;
};

# chronometer
var _gettimefmt_ = func(x)
{
    if (x >= 3600) {
        return sprintf("%02.f:%02.f", int(x / 3600), _normtime_(int(x / 60)));
    }
    return sprintf("%02.f:%02.f", _normtime_(int(x / 60)), _normtime_(x));
};

var chrono_prop = "instrumentation/clock/chronometer-time-sec";
var chrono_timer = aircraft.timer.new(chrono_prop, 1);
var fmtN = props.globals.getNode("instrumentation/clock/chronometer-time-fmt", 1);
setlistener(chrono_prop, func(v)
{
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
    if (v.getBoolValue()) { et_timer.stop(); }
    else { et_timer.start(); }
}, 0, 0);

## Format date
var time = {
    day: props.getNode("sim/time/real/day",1),
    month: props.getNode("sim/time/real/month",1),
    year: props.getNode("sim/time/real/year",1),
};

var clock = {
    date: props.getNode("instrumentation/clock/indicated-date-string", 1),
    year: props.getNode("instrumentation/clock/indicated-short-year", 1),
};

time.year.setValue(0);  #init value to avoid error in listener
setlistener(time.day, func(v)
{
    clock.date.setValue(sprintf("%02.f %02.f", v.getValue(), time.month.getValue()));
    clock.year.setValue(substr(time.year.getValue()~"", 2, 4));
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

var spin_timer = maketimer(5, func{
    setprop("instrumentation/attitude-indicator[0]/spin", 1);
    setprop("instrumentation/attitude-indicator[1]/spin", 1);
    setprop("instrumentation/heading-indicator[0]/spin", 1);
    setprop("instrumentation/heading-indicator[1]/spin", 1);
});
spin_timer.simulatedTime = 1;
spin_timer.start();
