## Bombardier CRJ700 series
##

# Utility functions.
var getprop_safe = func(node)
{
    var value = getprop(node);
    if (typeof(value) == "nil") return 0;
    else return value;
};

var Loop = func(interval, update)
{
    var loop = {};
    var timerId = -1;
    loop.interval = interval;
    loop.update = update;
    loop.loop = func(thisTimerId)
    {
        if (thisTimerId == timerId)
        {
            loop.update();
        }
        settimer(func {loop.loop(thisTimerId);}, loop.interval);
    };
	
    loop.start = func
    {
        timerId += 1;
        settimer(func {loop.loop(timerId);}, 0);
    };
	
    loop.stop = func {timerId += 1;};
    return loop;
};

var is_slave = 0;
if (getprop("/sim/flight-model") == "null")
{
    is_slave = 1;
}

# Engines and APU.
var apu = CRJ700.Engine.Apu();
var engines = [
    CRJ700.Engine.Jet(0),
    CRJ700.Engine.Jet(1)
];

# Wipers.
var wipers = [
    CRJ700.Wiper("/controls/anti-ice/wiper[0]",
                 "/surface-positions/left-wiper-pos-norm",
                 "/controls/anti-ice/wiper-power[0]",
                 "/systems/DC/outputs/wiper-left"),
    CRJ700.Wiper("/controls/anti-ice/wiper[1]",
                 "/surface-positions/right-wiper-pos-norm",
                 "/controls/anti-ice/wiper-power[1]",
                 "/systems/DC/outputs/wiper-right")
];



# Update loops.
var fast_loop = Loop(0, func {
	if (!is_slave)
	{
		# Engines and APU.
		CRJ700.Engine.poll_fuel_tanks();
		#CRJ700.Engine.poll_bleed_air();
		apu.update();
		engines[0].update();
		engines[1].update();
	}

	update_electrical();
	update_hydraulic();
	
	# Instruments.
	eicas_messages_page1.update();
	eicas_messages_page2.update();

	# Model.
	wipers[0].update();
	wipers[1].update();
});

var slow_loop = Loop(3, func {
	# Electrical.
	#rat1.update();

	# Instruments.
	update_tat;
	
	# Multiplayer.
	update_copilot_ints();

	# Model.
	update_lightmaps();
	update_pass_signs();
});

# When the sim is ready, start the update loops and create the crossfeed valve.
var gravity_xflow = {};
setlistener("sim/signals/fdm-initialized", func
{
	print("CRJ700 aircraft systems ... initialized");
	gravity_xflow = aircraft.crossfeed_valve.new(0.5, "controls/fuel/gravity-xflow", 0, 1);
	if (getprop("/sim/time/sun-angle-rad") > 1.57) 
		setprop("controls/lighting/dome", 1);
	fast_loop.start();
	slow_loop.start();
	settimer(func {
		setprop("sim/model/sound-enabled",1);
		print("Sound on.");
		}, 3);
}, 0, 0);



## Startup/shutdown functions
var startid = 0;
var startup = func {
    startid += 1;
    var id = startid;
	
	var items = [
		["controls/electric/battery-switch", 1, 0.8],
		["controls/lighting/nav-lights", 1, 0.4],
		["controls/lighting/beacon", 1, 0.8],
		["controls/APU/electronic-control-unit", 1, 0.4],
		["controls/APU/off-on", 1, 22],
		["controls/pneumatic/bleed-source", 2, 0.8],
		["controls/electric/engine[0]/generator", 1, 0.3],
		["controls/electric/APU-generator", 1, 0.3],
		["controls/electric/engine[1]/generator", 1, 1.5],
		["controls/engines/engine[0]/cutoff", 0, 0.1],
		["controls/engines/engine[1]/cutoff", 0, 2],
		["/consumables/fuel/tank[0]/selected", 1, 0.4],
		["/consumables/fuel/tank[1]/selected", 1, 0.8],
		["/controls/engines/engine[0]/starter", 1, 37],
		["/controls/engines/engine[1]/starter", 1, 38],
		["controls/pneumatic/bleed-source", 0, 0.8],
		["controls/APU/off-on", 0, 1],
		["controls/lighting/taxi-lights", 1, 0.8],
		["controls/hydraulic/system[0]/pump-b", 2, 0.1],
		["controls/hydraulic/system[2]/pump-a", 1, 0.3],							
		["controls/hydraulic/system[2]/pump-b", 2, 0.1],
		["controls/hydraulic/system[1]/pump-b", 2, 0.3],
	];
	var exec = func (idx)
	{
        if (id == startid and items[idx] != nil) {
			var item = items[idx];
			setprop(item[0], item[1]);
			if (size(items) > idx+1 and item[2] >= 0)
				settimer(func exec(idx+1), item[2]);
		}
	}
	exec(0);
};

var shutdown = func
{
    startid += 1;
    var id = startid;
	var items = [
		["controls/lighting/landing-lights[0]", 0, 0.3],
		["controls/lighting/landing-lights[1]", 0, 0.3],
		["controls/lighting/landing-lights[2]", 0, 0.3],
		["controls/lighting/taxi-lights", 0, 0.8],
		["controls/electric/engine[0]/generator", 0, 0.5],
		["controls/electric/engine[1]/generator", 0, 1.5],
		["controls/engines/engine[0]/cutoff", 1, 0.0],
		["controls/engines/engine[1]/cutoff", 1, 2],
		["/consumables/fuel/tank[0]/selected", 0, 0.4],
		["/consumables/fuel/tank[1]/selected", 0, 0.8],
		["controls/lighting/beacon", 0, 0.8],
		["controls/hydraulic/system[0]/pump-b", 0, 0.1],
		["controls/hydraulic/system[2]/pump-a", 0, 0.3],							
		["controls/hydraulic/system[2]/pump-b", 0, 0.1],
		["controls/hydraulic/system[1]/pump-b", 0, 0.3],
	];
	var exec = func (idx)
	{
        if (id == startid and items[idx] != nil) {
			var item = items[idx];
			setprop(item[0], item[1]);
			if (size(items) > idx+1 and item[2] >= 0)
				settimer(func exec(idx+1), item[2]);
		}
	}
	exec(0);
};

setlistener("sim/model/start-idling", func(v)
{
    var run = v.getBoolValue();
    if (run)
    {
        startup();
    }
    else
    {
        shutdown();
    }
}, 0, 0);

## Instant start for tutorials and whatnot
var instastart = func
{
	if (getprop("position/altitude-agl-ft") < 500 and !getprop("/sim/config/developer"))
		return;
	setprop("/consumables/fuel/tank[0]/selected", 1);
	setprop("/consumables/fuel/tank[1]/selected", 1);
    setprop("controls/electric/battery-switch", 1);
    setprop("controls/electric/engine[0]/generator", 1);
    setprop("controls/electric/engine[1]/generator", 1);
    setprop("controls/lighting/nav-lights", 1);
    setprop("controls/lighting/beacon", 1);
 	engines[0].on();
	engines[1].on();
	doors.close();
	setprop("controls/hydraulic/system[0]/pump-b", 2);
	setprop("controls/hydraulic/system[1]/pump-b", 2);
	setprop("controls/hydraulic/system[2]/pump-b", 2);
	setprop("controls/hydraulic/system[2]/pump-a", 1);							

	setprop("/controls/gear/brake-parking", 0);
	setprop("/controls/lighting/strobe", 1);
};

## Prevent the gear from being retracted on the ground
setlistener("controls/gear/gear-down", func(v)
{
    if (!v.getBoolValue())
    {
        var on_ground = 0;
        foreach (var gear; props.globals.getNode("gear").getChildren("gear"))
        {
            var wow = gear.getNode("wow", 0);
            if (wow != nil and wow.getBoolValue()) on_ground = 1;
        }
        if (on_ground) v.setBoolValue(1);
    }
}, 0, 0);

## Engines at cutoff by default (not specified in -set.xml because that means they will be set to 'true' on a reset)
setprop("controls/engines/engine[0]/cutoff", 1);
setprop("controls/engines/engine[1]/cutoff", 1);

## Aircraft-specific dialogs
var dialogs = {
    autopilot: gui.Dialog.new("sim/gui/dialogs/autopilot/dialog", "Aircraft/CRJ700-family/Systems/autopilot-dlg.xml"),
    doors: gui.Dialog.new("sim/gui/dialogs/doors/dialog", "Aircraft/CRJ700-family/Systems/doors-dlg.xml"),
    radio: gui.Dialog.new("sim/gui/dialogs/radio-stack/dialog", "Aircraft/CRJ700-family/Systems/radio-stack-dlg.xml"),
    lights: gui.Dialog.new("sim/gui/dialogs/lights/dialog", "Aircraft/CRJ700-family/Systems/lights-dlg.xml"),
    failures: gui.Dialog.new("sim/gui/dialogs/failures/dialog", "Aircraft/CRJ700-family/Systems/failures-dlg.xml"),
    tiller: gui.Dialog.new("sim/gui/dialogs/tiller/dialog", "Aircraft/CRJ700-family/Systems/tiller-dlg.xml"),
    info: gui.Dialog.new("sim/gui/dialogs/info-crj700/dialog", "Aircraft/CRJ700-family/Systems/info-dlg.xml"),
    config: gui.Dialog.new("sim/gui/dialogs/config-crj700/dialog", "Aircraft/CRJ700-family/Systems/config-dlg.xml"),
    debug: gui.Dialog.new("sim/gui/dialogs/debug/dialog", "Aircraft/CRJ700-family/Systems/debug-dlg.xml"),
    apdev: gui.Dialog.new("sim/gui/dialogs/apdev/dialog", "Aircraft/CRJ700-family/Systems/autopilot-dev-dlg.xml"),
};
gui.menuBind("autopilot", "CRJ700.dialogs.autopilot.open();");
gui.menuBind("radio", "CRJ700.dialogs.radio.open();");

var known = getprop("/sim/model/known-version");
var version = getprop("/sim/aircraft-version");
if (!getprop("/sim/config/hide-welcome-msg") or known != version) {
	if (known != version) setprop("/sim/config/hide-welcome-msg", 0);
	CRJ700.dialogs.info.open();
}


