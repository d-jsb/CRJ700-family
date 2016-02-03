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

# Prevent IDG voltage drop on engine idle while in flight 
# (idle N1,N2 can be much lower in flight than on ground)
var idg1_ref = 0;
var idg2_ref = 0;
setlistener("engines/engine[0]/running-nasal", func(n)
{
	if (n.getBoolValue()) {
		idg1_ref = generators[0].getInputLo();
		generators[0].setInputLo(0);
		#print("IDG1 set 0, was "~idg1_ref);
	}
	else {
		generators[0].setInputLo(idg1_ref);
		#print("IDG1 idg1_ref "~idg1_ref);
	}
}, 0, 0);

setlistener("engines/engine[1]/running-nasal", func(n)
{
	if (n.getBoolValue()) {
		idg2_ref = generators[1].getInputLo();
		generators[1].setInputLo(0);
		#print("IDG2 set 0, was "~idg2_ref);
	}
	else {
		generators[1].setInputLo(idg2_ref);
		#print("IDG2 idg2_ref "~idg2_ref);
	}
}, 0, 0);

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

var reload_checklists = func()
{
	var path = getprop("/sim/aircraft-dir")~"Checklists/checklists.xml";
	io.read_properties(path,"/sim/checklists");
};

# Cockpit position is different for C7/C9/C10 so we have to update all 
# tutorial markes in all checklist items.	
var update_offsets = func()
{
	var c_offset = getprop("/sim/model/dimensions/cockpit-offset-x");
	var update_checklists = func {
		print("Updating checklists...");
		foreach (var cl; props.globals.getNode("sim/checklists").getChildren("checklist"))
		{
			#print("==="~cl.getNode("title").getValue());
			var pages = cl.getChildren("page");
			var items = [];
			if (size(pages))
				foreach (var p; pages)
				{
					items ~= p.getChildren("item");
				}
			else items = cl.getChildren("item");
			foreach (var i; items)
			{
				var m = i.getNode("marker");
				if (m != nil)
				{					
					#print("  Item " ~ i.getNode("name").getValue());
					var x = m.getNode("x-m");
					x.setValue(x.getValue()+c_offset);
				}
			}						
		}
	}
	var update_tutorials = func {
		print("Updating tutorials...");
		foreach (var t; props.globals.getNode("sim/tutorials").getChildren("tutorial"))
		{
			#print("==="~t.getNode("name").getValue());
			var steps = [];
			steps = t.getChildren("step");
			foreach (var step; steps)
			{
				#print(step.getNode("message").getValue());
				var m = step.getNode("marker");
				if (m != nil)
				{					
					var x = m.getNode("x-m");
					x.setValue(x.getValue()+c_offset);
				}
				var v = step.getNode("view");
				if (v != nil)
				{					
					var z = v.getNode("z-offset-m");
					if (z != nil)
						z.setValue(z.getValue()+c_offset);
				}
			}						
		}
	}
	if (c_offset)
	{
		settimer(update_checklists,1);
		settimer(update_tutorials,2);
	}
};
update_offsets();

var tiller_last = 0;
setlistener("controls/gear/tiller-steer-deg", func(n) 
{
	var enabled = getprop("/sim/config/view-follows-tiller");
	if (enabled) {
		var hdg = getprop("/sim/current-view/heading-offset-deg");
		var dt = n.getValue() - tiller_last;
		tiller_last = n.getValue();
		setprop("/sim/current-view/heading-offset-deg", hdg-dt);
	}
}, 1, 0);

## Engines at cutoff by default (not specified in -set.xml because that means they will be set to 'true' on a reset)
setprop("controls/engines/engine[0]/cutoff", 1);
setprop("controls/engines/engine[1]/cutoff", 1);

var known = getprop("/sim/model/known-version");
var version = getprop("/sim/aircraft-version");
if (!getprop("/sim/config/hide-welcome-msg") or known != version) {
	if (known != version) setprop("/sim/config/hide-welcome-msg", 0);
	CRJ700.dialogs.info.open();
}

if (getprop("/sim/config/allow-autothrottle") ) {
	CRJ700.dialogs.autothrottle.open();
}

if (getprop("/sim/config/developer") ) {
	CRJ700.dialogs.developer.open();
}
