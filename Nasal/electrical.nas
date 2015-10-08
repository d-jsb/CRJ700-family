####    jet engine electrical system    ####
####    Syd Adams    ####
var count=0;
var ammeter_ave = 0.0;
var Lbus = props.globals.initNode("/systems/electrical/left-bus",0,"DOUBLE");
var Rbus = props.globals.initNode("/systems/electrical/right-bus",0,"DOUBLE");
var Amps = props.globals.initNode("/systems/electrical/amps",0,"DOUBLE");
var EXT  = props.globals.initNode("/controls/electric/external-power",0,"DOUBLE");
var XTie  = props.globals.initNode("/systems/electrical/xtie",0,"BOOL");
var APUgen=props.globals.initNode("controls/electric/APU-generator",0,"BOOL");
var extpwr=props.globals.initNode("controls/electric/external-power",0,"BOOL");
var lbus_volts = 0.0;
var rbus_volts = 0.0;

var lbus_input=[];
var lbus_output=[];
var lbus_load=[];

var rbus_input=[];
var rbus_output=[];
var rbus_load=[];

var lights_input=[];
var lights_output=[];
var lights_load=[];

#var battery = Battery.new(switch-prop,volts,amps,amp_hours,charge_percent,charge_amps);
var Battery = {
    new : func(swtch,vlt,amp,hr,chp,cha){
    m = { parents : [Battery] };
            m.switch = props.globals.getNode(swtch,1);
            m.switch.setBoolValue(0);
            m.ideal_volts = vlt;
            m.ideal_amps = amp;
            m.amp_hours = hr;
            m.charge_percent = chp;
            m.charge_amps = cha;
    return m;
    },

    apply_load : func(load,dt) {
        if(me.switch.getValue()){
        var amphrs_used = load * dt / 3600.0;
        var percent_used = amphrs_used / me.amp_hours;
        me.charge_percent -= percent_used;
        if ( me.charge_percent < 0.0 ) {
            me.charge_percent = 0.0;
        } elsif ( me.charge_percent > 1.0 ) {
        me.charge_percent = 1.0;
        }
        var output =me.amp_hours * me.charge_percent;
        return output;
        }else return 0;
    },

    get_output_volts : func {
        if(me.switch.getValue()){
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        var output =me.ideal_volts * factor;
        return output;
        }else return 0;
    },

    get_output_amps : func {
        if(me.switch.getValue()){
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        var output =me.ideal_amps * factor;
        return output;
        }else return 0;
    }
};

# var alternator = Alternator.new(num,switch,gen_output,rpm_source,rpm_threshold,volts,amps);
var Alternator = {
    new : func (num,switch,gen_output,src,thr,vlt,amp){
        m = { parents : [Alternator] };
        m.switch =  props.globals.getNode(switch,1);
        m.switch.setBoolValue(0);
        m.meter =  props.globals.getNode("systems/electrical/gen-load["~num~"]",1);
        m.meter.setDoubleValue(0);
        m.gen_output =  props.globals.getNode(gen_output,1);
        m.gen_output.setDoubleValue(0);
        m.meter.setDoubleValue(0);
        m.rpm_source =  props.globals.getNode(src,1);
        m.rpm_threshold = thr;
        m.ideal_volts = vlt;
        m.ideal_amps = amp;
        return m;
    },

    apply_load : func(load) {
        var cur_volt=me.gen_output.getValue();
        var cur_amp=me.meter.getValue();
        if(cur_volt >1){
            var factor=1/cur_volt;
            gout = (load * factor);
            if(gout>1)gout=1;
        }else{
            gout=0;
        }
        me.meter.setValue(gout);
    },

    get_output_volts : func {
        var out = 0;
        if(me.switch.getBoolValue()){
            var factor = me.rpm_source.getValue() / me.rpm_threshold or 0;
            if ( factor > 1.0 )factor = 1.0;
            var out = (me.ideal_volts * factor);
        }
        me.gen_output.setValue(out);
        return out;
    },

    get_output_amps : func {
        var ampout =0;
        if(me.switch.getBoolValue()){
            var factor = me.rpm_source.getValue() / me.rpm_threshold or 0;
            if ( factor > 1.0 ) {
                factor = 1.0;
            }
            ampout = me.ideal_amps * factor;
        }
        return ampout;
    }
};

var battery = Battery.new("/controls/electric/battery-switch",24,30,34,1.0,7.0);
var alternator1 = Alternator.new(0,"controls/electric/engine[0]/generator","/engines/engine[0]/amp-v","/engines/engine[0]/rpm",20.0,28.0,60.0);
var alternator2 = Alternator.new(1,"controls/electric/engine[1]/generator","/engines/engine[1]/amp-v","/engines/engine[1]/rpm",20.0,28.0,60.0);
var alternator3 = Alternator.new(2,"controls/electric/APU-generator","/engines/apu/amp-v","/engines/apu/rpm",80.0,28.0,60.0);
var alternator4 = Alternator.new(3,"controls/pneumatic/ram-air-turbine","/systems/ram-air-turbine/amp-v","/systems/ram-air-turbine/rpm",3000,18.0,10.0); # RPM threshold is a guess

#####################################
setlistener("/sim/signals/fdm-initialized", func {
    init_switches();
    print("Electrical System ... ok");
});

var init_switches = func{
    var AVswitch=props.globals.initNode("controls/electric/avionics-switch",1,"BOOL");
    props.globals.initNode("controls/electric/ammeter-switch",0,"BOOL");
    props.globals.getNode("systems/electrical/serviceable",0,"BOOL");

    append(lights_input,props.globals.initNode("controls/lighting/landing-lights[0]",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/landing-lights[0]",0,"INT"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/landing-lights[1]",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/landing-lights[1]",0,"INT"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/landing-lights[2]",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/landing-lights[2]",0,"INT"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/nav-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/nav-lights",0,"INT"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/taxi-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/taxi-lights",0,"INT"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/wing-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/wing-lights",0,"INT"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/logo-lights",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/logo-lights",0,"INT"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("controls/lighting/panel-lights",1,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/panel-lights",0,"DOUBLE"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("sim/model/lights/beacon/state",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/beacon",0,"INT"));
    append(lights_load,1);
    append(lights_input,props.globals.initNode("sim/model/lights/strobe/state",0,"BOOL"));
    append(lights_output,props.globals.initNode("systems/electrical/outputs/strobe",0,"INT"));
    append(lights_load,1);

    append(rbus_input,AVswitch);
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/autopilot",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/electric/cabin-power",1,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/cabin",0,"INT"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/anti-ice/wiper-power[0]",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/wiper[0]",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/anti-ice/wiper-power[1]",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/wiper[1]",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/engines/engine[0]/fuel-pump",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/fuel-pump[0]",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/engines/engine[1]/fuel-pump",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/fuel-pump[1]",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/engines/engine[0]/starter",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/starter",0,"DOUBLE"));
    append(rbus_load,1);
    append(rbus_input,props.globals.initNode("controls/engines/engine[1]/starter",0,"BOOL"));
    append(rbus_output,props.globals.initNode("systems/electrical/outputs/starter[1]",0,"DOUBLE"));
    append(rbus_load,1);

    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/adf[0]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/adf[1]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/dme[0]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/dme[1]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/gps",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/efis",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/transponder",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/mk-viii",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/magnetic-compass",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/standby-instrument",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/comm[0]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/comm[1]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/nav",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/nav[1]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/dme[0]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/dme[1]",0,"DOUBLE"));
    append(lbus_load,1);
    append(lbus_input,AVswitch);
    append(lbus_output,props.globals.initNode("systems/electrical/outputs/clock",0,"DOUBLE"));
    append(lbus_load,1);
}


update_virtual_bus = func( dt ) {
    var PWR = getprop("systems/electrical/serviceable");
    var xtie=0;
    load = 0.0;
    power_source = nil;
    setprop("systems/electrical/external-power-amp-v", 0);
    if(count==0){
        var battery_volts = battery.get_output_volts();
        lbus_volts = battery_volts;
        power_source = "battery";
        var alternator = nil;
        if (extpwr.getBoolValue() and getprop("velocities/groundspeed-kt") < 1)
        {
            power_source = "external";
            lbus_volts = 28;
            setprop("systems/electrical/external-power-amp-v", 28);
        }
        var alternator1_volts = alternator1.get_output_volts();
        if (alternator1_volts > lbus_volts) {
            lbus_volts = alternator1_volts;
            power_source = "alternator1";
            alternator = alternator1;
        }
        var alternator3_volts = alternator3.get_output_volts();
        if (APUgen.getBoolValue() and alternator3_volts > lbus_volts)
        {
            lbus_volts = alternator3_volts;
            power_source = "APU";
            alternator = alternator3;
        }
        var alternator4_volts = alternator4.get_output_volts();
        if (alternator4_volts > lbus_volts)
        {
            lbus_volts = alternator4_volts;
            power_source = "RAT";
            alternator = alternator4;
        }
        lbus_volts *=PWR;
        Lbus.setValue(lbus_volts);
        load += lh_bus(lbus_volts);
        if (alternator != nil) alternator.apply_load(load);
    }else{
        var battery_volts = battery.get_output_volts();
        rbus_volts = battery_volts;
        power_source = "battery";
        var alternator = nil;
        if (extpwr.getBoolValue() and getprop("velocities/groundspeed-kt") < 1)
        {
            power_source = "external";
            rbus_volts = 28;
            setprop("systems/electrical/external-power-amp-v", 28);
        }
        var alternator2_volts = alternator2.get_output_volts();
        if (alternator2_volts > rbus_volts) {
            rbus_volts = alternator2_volts;
            power_source = "alternator2";
            alternator = alternator2;
        }
        var alternator3_volts = alternator3.get_output_volts();
        if (APUgen.getBoolValue() and alternator3_volts > rbus_volts)
        {
            rbus_volts = alternator3_volts;
            power_source = "APU";
            alternator = alternator3;
        }
        var alternator4_volts = alternator4.get_output_volts();
        if (alternator4_volts > rbus_volts)
        {
            rbus_volts = alternator4_volts;
            power_source = "RAT";
            alternator = alternator4;
        }
        rbus_volts *=PWR;
        Rbus.setValue(rbus_volts);
        load += rh_bus(rbus_volts);
        if (alternator != nil) alternator.apply_load(load);
    }
    count=1-count;
    if(rbus_volts > 5 and  lbus_volts>5) xtie=1;
    XTie.setValue(xtie);
    load += lighting(rbus_volts > 5 or lbus_volts > 5 ? 24 : 0);

    ammeter = 0.0;

return load;
}

rh_bus = func(bv) {
    var bus_volts = bv;
    var load = 0.0;
    var srvc = 0.0;

    for(var i=0; i<size(rbus_input); i+=1) {
        var srvc = rbus_input[i].getValue();
        load += rbus_load[i] * srvc;
        rbus_output[i].setValue(bus_volts * srvc);
    }
    return load;
}

lh_bus = func(bv) {
    var load = 0.0;
    var srvc = 0.0;

    for(var i=0; i<size(lbus_input); i+=1) {
        var srvc = lbus_input[i].getValue();
        load += lbus_load[i] * srvc;
        lbus_output[i].setValue(bv * srvc);
    }

    setprop("systems/electrical/outputs/flaps",bv);
    return load;
}

lighting = func(bv) {
    var load = 0.0;
    var srvc = 0.0;
    var ac=bv*4.29;

    for(var i=0; i<size(lights_input); i+=1) {
        var srvc = lights_input[i].getValue();
        load += lights_load[i] * srvc;
        lights_output[i].setValue(bv * srvc);
    }

return load;

}

update_electrical = func {
    var scnd = getprop("sim/time/delta-sec");
    update_virtual_bus( scnd );
}
