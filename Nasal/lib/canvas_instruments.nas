#
# canvas.instruments library - beta
# created 09/2019 by jsb
#
# WARNING: this is still under development, interfaces may change
# It is planed to move this code to FGDATA once it is more mature

var DataSource = {
    LISTENER: 0,
    POLL: 1,
    
    new: func(var_name, namespace) {
        var obj = {
            parents: [me],
            _callbacks: [],
            _mode: nil,
            _L: nil,
            node: nil,
            value: nil,
            ns: namespace,
            var_name: var_name,
        };
        return obj;
    },
    
    del: func() {
        if (me["_L"] != nil) {
            removelistener(me._L);
        }
        if (me["timer"] != nil) {
            me.timer.stop();
            me.timer = nil;
        }        
    },
    
    setSource: func(path, mode, poll_interval = 0) {
        me.node = props.getNode(path, 1);
        me.value = me.node.getValue();# or 0;
        if (me["_L"] != nil) {
            removelistener(me.L);
        }
        if (me["timer"] != nil) {
            me.timer.stop();
            me.timer = nil;
        }
        if (mode == DataSource.LISTENER) {
            me._L = setlistener(me.node.resolveAlias(), func me._update(), 0, 0);
        }
        elsif (mode == DataSource.POLL) {
            me.interval = num(poll_interval) or 0.1;
            # limit to 60/s
            if (me.interval < 0.0167) me.interval = 0.0167;
            me.timer = maketimer(me.interval, me, me._update);
        }
        else {
            logprint(DEV_ALERT, "dataSource.setSource(): Invalid mode argument.");
        }
        return me;
    },
    
    _update: func() { 
        me.value = me.node.getValue() or 0; 
        foreach (cb; me._callbacks) {
            cb();
        }
    },
    
    # for max performance use obj.value instead of obj.getValue()
    getValue: func() { 
        if (me._mode == me.POLL)
            me.value = me.node.getValue();
        return me.value; 
    },
    
    # register a function to call on update
    # returns ID for removeCallback()
    registerCallback: func(f) {
        if (!isfunc(f)) { return nil; }
        append(me._callbacks, f);
        return size(me._callbacks) - 1;
    },
    
    # remove a callback registered earlier
    # id returned by registerCallback()
    removeCallback: func(id) {
        if (me._callbacks[id] != nil and isfunc(me._callbacks[id])) {
            me._callbacks[id] = func; # replace with no-op
        }
    },
        
    start: func() { 
        if (me["timer"] != nil) me.timer.start(); 
    },
    
    stop: func() { 
        if (me["timer"] != nil) me.timer.stop(); 
    },
};

# canvas.Instrument 
# This class provides a basic structure to build canvas based instrument.
# 
var Instrument = {
    _classname: "Instrument",
    
    # cgroup: canvas group in which the instrument will be created
    new: func(cgroup) { 
        var obj = {
            parents: [me],
            cgroup: cgroup,         # top level canvas group for this instrument
            _elements: {},          # canvas elements to animate
            _update_funcs: {},      # functions to animate additional elements
            inputs: {},             # data sources for animation
            update_interval: 0.033,
        }; 
        return obj;
    },
    
    #addElement extends an instrument with additional elements
    #name:           unique name
    #canvas_element: valid canvas element
    addElement: func(name, canvas_element, update_func = nil) {
        if (me._elements[name] != nil) {
            logprint(DEV_ALERT, "Instrument.addElement() cannot add '"~name~
                "', name is already in use.");
            return nil;
        }
        if (!isa(canvas_element, canvas.Element)) {
            logprint(DEV_ALERT, "Instrument.addElement() argument is not a canvas element.");
            return nil;
        }
        if (isfunc(update_func)) {
            me._update_funcs[name] = update_func;
        }
        me._elements[name] = canvas_element;
        me._elements[name].show();
        return me;
    },
    
   
    # set multiple inputs from a hash { input_id: input, ...}
    addInputs: func(inputs) {
        foreach (var i; keys(inputs)) {
            me.addInput(i,inputs[i])
        }
        return me;
    },
    
    # (re-)sets an named input to a (new) property 
    # name: name of input, avail as me.inputs[name] in update functions
    addInput: func (name, input, mode=0) {
        if (me.inputs[name] == nil) {
            me.inputs[name] = DataSource.new(name, me);
        }
        #me.inputs[name].setSource(input, DataSource.POLL, 0.016).start();
        me.inputs[name].setSource(input, DataSource.LISTENER);
        return me;
    },
    
    # draw instrument elements into canvas group me.cgroup
    # virtual function, implement this in derived classes
    # call this only once when creating the instrument
    draw: func() {
        logprint(DEV_ALERT, "Error: call to virtual function Instrument.draw()");
        return me;
    },
    
    # virtual function, implement this in derived classes
    # can be used with the update timer (see start()) or called from other code 
    update: func() {
        #logprint(DEV_ALERT, "Warning: call to virtual function Instrument.update()");
        foreach (var key; keys(me._update_funcs)) {
            call(me._update_funcs[key], [me._elements[key]], me, var err = []);
            if (size(err)) {
                debug.printerror(err);
            }
        }
    },

    # start timer based animation 
    # alternatively call update() in your aircrafts update loop
    start: func(interval = 0.033) {
        if (me["timer"] == nil) {
            if (!num(interval) or num(interval) < 1/60) 
                me.update_interval = 1/60;
            me.timer = maketimer(me.update_interval, me, me.update);
        }
        me.timer.start();
        return me;
    },

    # restart - change update timer interval
    restart: func (interval) {
        me.update_interval = num(interval) or 1/30;
        if (me["timer"] != nil) {
            me.timer.restart(me.update_interval);
        } 
        else {
            logprint(DEV_ALERT, "Instrument.restart() called but no timer exists.");
        }
        return me;
    },
    
    # stop timer based animation
    stop: func {
        if (me["timer"] != nil) { 
            me.timer.stop(); 
        }
        else {
            logprint(DEV_WARN, "Instrument.stop() called but no timer exists.");
        }
        return me;
    },
};

var instruments = {};
# CompassInstrument - base class for compase rose instruments (ADF, CDI, HSI)
# can be used for directional gyro (heading indicator)
instruments.CompassInstrument = {
    # position: [center_x, center_y]
    new: func(cgroup, radius, position, style=nil) { 
        var obj = {
            parents: [me, Instrument.new(cgroup)],
            pos: position,
            radius: radius,
        }; 
        obj.style = (isa(style, canvas.CompassRose.Style)) ? style : canvas.CompassRose.Style.new();
        return obj;
    },
  
    draw: func() {
        me.rose = canvas.CompassRose.draw(me.cgroup, me.radius, me.style);
        me.cgroup.setTranslation(me.pos[0], me.pos[1]);
        return me;
    },
    
    update: func() {
        call(canvas.Instrument.update, arg, me);
        me.rose.setRotation(-me.inputs["heading"].value * D2R);
    },
};