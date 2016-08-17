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


# APU class
#
var Apu = {
    new: func() {
        var obj = {
            parents: [me],
            fuel_burn_pps: 270/3600,   # Honeywell RE220
            serviceable: 1,
            door: 0,
            running: 0,
            rpm: 0,
            eicas_door_msg:  ["----", "CLSD", "OPEN"],
            controls: { ecu: 0, on: 0},
            dt: 0.5, #intervall for fuel consumption
        };
        obj.fuel_consumer = maketimer(obj.dt, obj, obj.consume_fuel);
        obj.fuel_consumer.simulatedTime = 1;
        return obj;
    },

    init: func() {
        # create property objects
        me.controls.ecuN = props.getNode("/controls/APU/electronic-control-unit", 1);
        me.controls.fire_exN = props.getNode("/controls/APU/fire-switch", 1);
        me.controls.onN = props.getNode("/controls/APU/off-on", 1);
        me.controls.ecuN.setBoolValue(me.controls.ecu);
        me.controls.onN.setBoolValue(me.controls.on);

        me.serviceableN = props.getNode("/engines/engine[2]/serviceable", 1);
        me.serviceableN.setBoolValue(me.serviceable);
        #abusing unused engine[2] MP enabled property to make door pos visible via MP
        me.doorN = props.getNode("/engines/engine[2]/n1", 1);
        me.doorN.setValue(me.door);
        me.eicas_doorN = props.getNode("/engines/engine[2]/door-msg", 1);
        me.eicas_doorN.setValue(me.eicas_door_msg[0]);

        me.runningN = props.getNode("/engines/engine[2]/running-nasal", 1);
        me.runningN.setBoolValue(me.running);

        me.rpmN = props.getNode("/engines/engine[2]/rpm", 1);
        me.rpmN.setValue(0);

        me.sovN = props.getNode("/engines/engine[2]/sov", 1);
        me.sovN.setValue(0);

        me.egtN = props.getNode("/engines/engine[2]/egt-degc", 1);
        me.egtN.setValue(getprop_safe("/environment/temperature-degc"));

        me.on_fireN = props.getNode("/engines/engine[2]/on-fire", 1);
        me.on_fireN.setBoolValue(0);

        me.fuel_consumedN = props.globals.initNode("/engines/engine[2]/fuel-consumed-lbs", 0, "DOUBLE");
        me.oofN = props.globals.getNode("/engines/engine[2]/out-of-fuel", 1);

        #-- set listeners for rare events, e.g. not necessary to poll in the update loop
        # APU master switch (ECU = electronic control unit)
        setlistener(me.controls.ecuN, func(n) {
            me.controls.ecu = n.getBoolValue();
            if (me.controls.ecu) {
                # init value
                #me.egtN.setValue(getprop("/environment/temperature-degc"));
                #me.doorN.setValue(0);
                me.open_door();
                setprop("systems/fuel/boost-pump[2]/running",1);
            }
            else {
                # unset start/stop switch, in case the pilot did not
                me.controls.on = 0;
                me.controls.onN.setBoolValue(0);
                setprop("systems/fuel/boost-pump[2]/running",0);
                me.sovN.setBoolValue(0);
            }
        }, 1);

        setlistener(me.controls.onN, func(n) {
            print("APU on/off");
            me.controls.on = n.getBoolValue();
            if (me.controls.on) {
                me.sovN.setBoolValue(1);
                me.start();
            }
            else {
                me.stop();
            }
        }, 1);

        #listener to update door indication for EICAS
        setlistener(me.doorN, func(n) {
            me.door = n.getValue();
            if (me.door == 0)
                me.eicas_doorN.setValue(me.eicas_door_msg[1]);
            if (me.door == 1)
                me.eicas_doorN.setValue(me.eicas_door_msg[2]);
        }, 1);

        setlistener(me.on_fireN, func(n) {
            if (n.getBoolValue()) {
                print("APU fire");
                me.serviceableN.setBoolValue(0);
            }
        });

        setlistener(me.controls.fire_exN, func(n) {
            if (n.getBoolValue())
            {
                print("APU fire bottle discharge");
                me.on_fireN.setBoolValue(0);
                me.serviceableN.setBoolValue(0);
            }
        });

        setlistener(me.oofN, func(n) {
            if (n.getBoolValue()) {
                me.stop();
            }
        });

        setlistener(me.serviceableN, func(n) {
            me.serviceable = n.getBoolValue();
            if (!me.serviceable) {
                me.stop();
            }
        }, 1);

        #-- monitor RPM to set running (available) flag;
        rpm_timer_lock = 0;
        setlistener(me.rpmN, func(n) {
            #print("apu rpm");
            me.rpm = n.getValue() or 0;
            if (me.rpm < 99) {
                me.runningN.setBoolValue(me.running = 0);
                me.fuel_consumer.stop();
                if (me.rpm < 12 and !me.controls.on)
                    interpolate(me.doorN, 0, 2);
            }
            elsif (99 <= me.rpm and me.rpm <= 106)
            {
                #set running flag after 2s
                if (rpm_timer_lock == 0)
                {
                    rpm_timer_lock = 1;
                    me.fuel_consumer.start();
                    settimer(func {
                        rpm_timer_lock = 0;
                        if (me.rpm >= 99) {
                            me.runningN.setBoolValue(me.running = 1);
                        }
                    }, 2);
                }
            }
        }, 0, 0);

    },

    open_door: func {
        # on gnd. open to 45 deg (=1) in 2s
        var pos = 1;
        # if (altitude < limit) #TODO
        interpolate(me.doorN, pos, 2);
    },

    #-- spin up --
    start: func
    {
        if (!me.running and me.serviceable and me.controls.ecu and me.controls.on and !me.oofN.getValue())
        {
            if (!me.door)
                me.open_door();
            interpolate(me.rpmN, 100, 20 * (100 - me.rpm)/100, 103, 0.5, 100, 0.5);
            interpolate(me.egtN, 400, 4, 517, 3.5, 468, 2, 485, 1.5, 415, 9, 384, 4);
        }
    },

    #-- spin down --
    stop: func {
        if (!me.rpm) {
            return;
        }
        print("APU off");
        #-- spin down (20s), will trigger rpm listener --
        interpolate(me.rpmN, 0, 20 * me.rpm / 100);
        #-- cool down, depending on current rpm --
        var outside_temperature = getprop("/environment/temperature-degc") or 10;
        if (me.rpm >=100) {
            interpolate(me.egtN, 231,4, 197,4, outside_temperature, (197 - outside_temperature)/2);
        }
        elsif (me.rpm >=50) {
            interpolate(me.egtN, 197,4, outside_temperature, (197 - outside_temperature)/2);
        }
        else {
            cooling_time = (me.egtN.getValue() - outside_temperature)/2;
            if (cooling_time < 1) cooling_time = 1;
            #print("APU cool down to " ~ outside_temperature ~ " in " ~ cooling_time ~ "s");
            interpolate(me.egtN, outside_temperature, cooling_time);
        }
    },

    consume_fuel: func {
        #ignores consumption at startup, but that should be ok
        if (me.running) {
            me.fuel_consumedN.setValue(me.fuel_consumedN.getValue() + me.fuel_burn_pps * me.dt);
        }
    },
    
    update: func {},
};

# Jet class
#
var Jet = {
    flight_model: getprop("/sim/flight-model"),

    new: func(idx) {
        var obj = {
            parents: [me],
            idx: idx,
            serviceable: 1,
            fdm_reverser: 0,
            n1: 0, n2: 0,
            fdm_n1: 0, fdm_n2: 0,
            running: 0,
            on_fire: 0,
            out_of_fuel: 1,
            fdm_throttle_idle: 0.01,
            #-- controls --
            cutoff: 0,
            starter_cmd: 0,
            has_bleed_air: 0,
        };
        return obj;
    },

    init: func() {
        var prefix = "/controls/engines/engine["~me.idx~"]/";
        me.cutoffN = props.getNode(prefix~"cutoff", 1);
        me.cutoffN.setBoolValue(me.cutoff);
        
        me.fire_exN = props.getNode(prefix~"fire-bottle-discharge", 1);
        me.reverser_armN = props.getNode(prefix~"reverser-armed", 1);
        me.reverser_cmdN = props.getNode(prefix~"reverser-cmd", 1);
        
        me.starter_cmdN = props.getNode(prefix~"starter-cmd", 1);
        me.starter_cmdN.setBoolValue(me.starter_cmd);
        
        me.thrust_modeN = props.getNode(prefix~"thrust-mode", 1);
        
        me.throttleN = props.getNode("/fcs/throttle-cmd-norm["~me.idx~"]", 1);
        
        me.fdm_throttleN = props.getNode(prefix~"throttle-lever", 1);
        me.fdm_reverserN = props.getNode(prefix~"reverser", 1);

        prefix = "/engines/engine["~me.idx~"]/";
        me.starterN = props.getNode(prefix~"starter", 1);
        me.sovN = props.getNode(prefix~"sov", 1);
        me.sovN.setValue(1);        

        # EICAS display uses separate nodes for n1,n2 because YASim sets n1,n2 
        # to minimum values from XML if engine is off 
        me.n1N = props.getNode(prefix~"rpm", 1);
        me.n2N = props.getNode(prefix~"rpm2", 1);

        #YASim FDM values
        me.fdm_n1N = props.getNode(prefix~"n1", 1);
        me.fdm_n2N = props.getNode(prefix~"n2", 1);

        if (me.flight_model == "yasim")
        {
            # with yasim "running" is always reset to true, so unusable here
            # running-nasal indicates engine is running to other CRJ systems
            me.runningN = props.getNode(prefix~"running-nasal", 1, "BOOL");
            me.runningN.setBoolValue(me.running);
            # yasim uses out-of-fuel to determine if engine is active
            me.yasimOOFN = props.getNode(prefix~"out-of-fuel", 1, "BOOL");
            me.yasimOOFN.setBoolValue(!me.running);
    }
        elsif (me.flight_model == "jsb")
        {
            #for jsbsim
            me.starterN = props.getNode("/controls/engines/engine["~me.idx~"]/starter", 1);
            me.runningN = props.getNode(prefix~"running",1);
            props.getNode(prefix~"running-nasal",1).alias(prefix~"running");
            
        }
        # in yasim: !out-of-fuel means running. Fuel system uses "out-of-fuel-nasal"
        # to indicate if fuel is avail to start/run engine
        me.out_of_fuelN = props.getNode(prefix~"out-of-fuel-nasal", 1);
        
        me.on_fireN = props.getNode(prefix~"on-fire", 1);
        me.on_fireN.setBoolValue(me.on_fire);
        
        me.serviceableN = props.getNode(prefix~"serviceable", 1);
        me.serviceableN.setBoolValue(me.serviceable);

        #-- set listeners for rare events,
        setlistener(me.serviceableN, func(n) {
            me.serviceable = n.getValue();
        }, 1, 0);

        setlistener(me.runningN, func(n) {
            me.running = n.getValue();
        }, 1, 0);

        # grab changes from fuel system (CRJ700-fuel.nas)
        setlistener(me.out_of_fuelN, func(n) {
            me.out_of_fuel = n.getValue();
        }, 1, 0);

        setlistener(me.cutoffN, func(n) {
            me.cutoff = n.getValue();
        }, 1, 0);

        setlistener(me.starter_cmdN, func(n) {
            me.starter_cmd = n.getValue();
        }, 1, 0);

        setlistener(me.on_fireN, func(n) {
            if (n.getBoolValue())
            {
                settimer(func {me.serviceableN.setBoolValue(0); }, 10);
            }
        }, 1, 0);

        setlistener(me.fire_exN, func(n) {
            if (n.getBoolValue())
            {
                me.sovN.setBoolValue(0);
                me.on_fireN.setBoolValue(0);
                me.serviceableN.setBoolValue(0);
            }
        }, 1, 0);

        setlistener(me.reverser_cmdN, func(v) {
            if (v.getBoolValue() and me.reverser_armN.getBoolValue())
                me.fdm_reverserN.setBoolValue(1);
            else
                me.fdm_reverserN.setBoolValue(0);
        }, 1, 0);
    
        if (me.idx == 0) {
            setlistener("systems/pneumatic/pressure-left", func(n) {
                me.has_bleed_air = n.getValue();
            }, 1, 0);
        } elsif (me.idx == 1) {
            setlistener("systems/pneumatic/pressure-right", func(n) {
                me.has_bleed_air = n.getValue();
            }, 1, 0);
        }
    }, #init

    toggle_reversers: func {
        print("Engine toggle_reversers");
        if (me.throttleN.getValue() <= 0.01 and me.thrust_modeN.getValue() == 0) {
            me.reverser_cmdN.setBoolValue(!me.reverser_cmdN.getBoolValue());
        }
    },
    
    #instant on
    on: func {
        if (me.flight_model == "yasim") {
          me.cutoffN.setBoolValue(me.cutoff = 0);
          me.yasimOOFN.setBoolValue(me.out_of_fuel = 0);
          me.runningN.setBoolValue(me.running = 1);
          me.n1 = me.fdm_n1;
          me.n2 = me.fdm_n2;
          me.n1N.setValue(me.n1);
          me.n2N.setValue(me.n2);
        }
        elsif (me.flight_model == "jsb") {
          me.starter_cmd = 0;
          me.cutoff = 0;

          me.cutoffN.setBoolValue(1);
          me.starterN.setBoolValue(1);
          settimer(func() {
            me.cutoffN.setBoolValue(0);
          }, 1);
        }
    },

    update: func {
        me.fdm_n1 = me.fdm_n1N.getValue();
        me.fdm_n2 = me.fdm_n2N.getValue();
        var throttle = me.throttleN.getValue();
        var fdm_throttle = 0;
        var time_delta = getprop_safe("sim/time/delta-sec");
        
        # possible states:
        # running
        # starting
        # off/spin down
        if (!me.serviceable or me.out_of_fuel or me.cutoff) {
            me.running = 0;
        }

        if (me.flight_model == "yasim") {
            if (me.running) {
                fdm_throttle = throttle;
                me.n1 = me.fdm_n1;
                me.n2 = me.fdm_n2;
                #me.starter_cmd = 0;
            }
            elsif (me.serviceable and me.starter_cmd and me.has_bleed_air) {
                me.starterN.setValue(1);
                me.n2 = math.min(me.n2 + 1.99 * time_delta, me.fdm_n2);
                if (me.n2 >= 25 and (me.cutoff or me.out_of_fuel)) me.n2 = 25;
                if (me.n2 > 25) {
                    # tell yasim engine 'on' to get oil pressure
                    me.yasimOOFN.setBoolValue(0); 
                }
                if (me.n2 > 30) {
                    me.n1 = math.min(me.n1 + 1.3 * time_delta, me.fdm_n1);
                }
                if (me.n1 >= me.fdm_n1) {
                    me.running = 1;
                    me.starter_cmd = 0;
                    me.starterN.setValue(0); #write status of starter, used by OHP switch light
                }
            }
            else {
                #shutdown: N1 25->0 ~15s; N2 60
                me.running = 0;
                me.yasimOOFN.setBoolValue(1); 
                me.starter_cmd = 0;
                me.starterN.setValue(0); #write status of starter, used by OHP switch light
                me.n1 = math.max(me.n1 - 1.66 * time_delta, 0);
                if (me.n2 > 28) me.n2 = math.max(me.n2 - 4 * time_delta, 0);
                else me.n2 = math.max(me.n2 - 1.1 * time_delta, 0);
                fdm_throttle = 0;
            }
            me.runningN.setBoolValue(me.running);   # tell EFIS etc. engine on
        }
        
        elsif (me.flight_model == "jsb") {
            me.n1 = me.fdm_n1;
            me.n2 = me.fdm_n2;
            if (me.running) {
                me.starter_cmd = 0;
                fdm_throttle = me.fdm_throttle_idle + (1 - me.fdm_throttle_idle) * throttle;
            }
            elsif (me.has_bleed_air and me.starter_cmd) {
                me.starterN.setValue(1); #activate jsbsim starter
            }
        }
        me.starter_cmdN.setBoolValue(me.starter_cmd);
        me.fdm_throttleN.setDoubleValue(fdm_throttle);
        #update properties for EICAS
        me.n1N.setValue(me.n1);
        me.n2N.setValue(me.n2);
    },
};
