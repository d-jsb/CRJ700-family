#------------------------------------------
# speedbooklet.nas
# author:       jsb
# created:      06/2020
#------------------------------------------
var canvas_settings = {
    "size": [1024,1024],
    "view": [1024,1024],
};
var window_size = [512,512];

var speedbooklet_svg = "/Checklists/speedbooklet.svg";

var Speedtable = {
    _instances: {},

    new: func(id) {
        var obj = {
            parents: [me,],
            id: id,
            weights: [],
            tables: [],
            MLW: 0,
        };
        me._instances[id] = obj;
        return obj;
    },

    #speeds: hash with speeds
    addTable: func(weight, speeds) {
        weight = int(weight) or 0;
        append(me.weights, weight);
        append(me.tables, speeds);
        return me;
    },
    
    setMLW: func(w) {
        me.MLW = int(w);
        return me;
    },

    getMLW: func() {
        return me.MLW;
    },
    
    isOverMLW: func(w) {
        return (w > me.MLW) ? 1 : 0;
    },

    getNumberOfPages: func() {
        return size(me.tables);
    },
    
    getPage: func(i) {
        return me.tables[i];
    },
    
    findWeight: func(weight) {
        var lo = 0;
        var hi = 999000;
        foreach (var w; me.weights) {
            if (w < weight and w > lo) lo = w;
            if (w >= weight and w < hi) hi = w;
        }
        return hi < 999000 ? hi : lo;
    },

    getPageNumberByWeight: func(weight) {
        return vecindex(me.weights, me.findWeight(weight));
    },
};

var _interpolate = func(x, x0, x1, v0, v1) {
    x = math.clamp(x, x0, x1) - x0;
    return v0 + x * (v1-v0)/(x1-x0);
}

var speedtables = { 
    "CRJ7": Speedtable.new("CRJ700"),
    "CRJ9": Speedtable.new("CRJ900"),
    "CRJ1": Speedtable.new("CRJ1000"),
};

var dkg = 500;
# CRJ700
var kg0 = 23000;
var kg1 = 34000;
for (var i=0; i <= (kg1-kg0)/dkg; i += 1) {
    var kg = kg0 + i * dkg;
    var speeds = {
        weight: kg,
        v1_8:  _interpolate(kg, 29000, kg1, 124, 135),
        vr_8:  _interpolate(kg, 29000, kg1, 124, 135),
        v2_8:  _interpolate(kg, 30000, kg1, 138, 145),
        v1_20: _interpolate(kg, 31000, kg1, 123, 129),
        vr_20: _interpolate(kg, 31000, kg1, 123, 129),
        v2_20: _interpolate(kg, 31000, kg1, 136, 138),
        vt:    _interpolate(kg, 26000, kg1, 174, 199),
        vref_0: _interpolate(kg, 26000, kg1, 165, 183),
        vref_1: _interpolate(kg, 26000, kg1, 149, 167),
        vref_8: _interpolate(kg, 26000, kg1, 143, 161),
        vref_20: _interpolate(kg, 26000, kg1, 137, 155),
        vref_30: _interpolate(kg, 26000, kg1, 133, 151),
        vref_45: _interpolate(kg, 26000, kg1, 125, 143),
    };
    speedtables["CRJ7"].addTable(kg, speeds);
}
speedtables["CRJ7"].setMLW(30000);

# CRJ900
var kg0 = 25000;
var kg1 = 38500;
for (var i=0; i <= (kg1-kg0)/dkg; i += 1) {
    var kg = kg0 + i * dkg;
    var speeds = {
        weight: kg,
        v1_8:  _interpolate(kg, kg0, kg1, 121, 145), #guess
        vr_8:  _interpolate(kg, kg0, kg1, 124, 151),
        v2_8:  _interpolate(kg, kg0, kg1, 138, 161),
        v1_20: _interpolate(kg, kg0, kg1, 115, 135), #guess
        vr_20: _interpolate(kg, kg0, kg1, 118, 144),
        v2_20: _interpolate(kg, kg0, kg1, 135, 150),
        vt:    _interpolate(kg, kg0, kg1, 170, 212),
        vref_0: _interpolate(kg, kg0, kg1, 160, 191),
        vref_1: _interpolate(kg, kg0, kg1, 144, 175),
        vref_8: _interpolate(kg, kg0, kg1, 138, 169),
        vref_20: _interpolate(kg, kg0, kg1, 132, 163),
        vref_30: _interpolate(kg, kg0, kg1, 128, 159),
        vref_45: _interpolate(kg, kg0, kg1, 121, 151),
    };
    speedtables["CRJ9"].addTable(kg, speeds);
}
speedtables["CRJ9"].setMLW(33500);

# CRJ1000
var kg0 = 28000; # low weight for speed calculation > 25000 "empty" weight
var kg1 = 41500;
for (var i=0; i <= (kg1-25000)/dkg; i += 1) {
    var kg = kg0 + i * dkg;
    var speeds = {
        weight: kg,
        v1_8:  _interpolate(kg, kg0, kg1, 120, 150), 
        vr_8:  _interpolate(kg, kg0, kg1, 122, 152),
        v2_8:  _interpolate(kg, kg0, kg1, 134, 161),
        v1_20: _interpolate(kg, kg0, kg1, 111, 140), 
        vr_20: _interpolate(kg, kg0, kg1, 115, 141),
        v2_20: _interpolate(kg, kg0, kg1, 125, 147),
        vt:    _interpolate(kg, kg0, kg1, 169, 204),
        vref_0: _interpolate(kg, kg0, kg1, 162, 181),
        vref_1: _interpolate(kg, kg0, kg1, 151, 177),
        vref_8: _interpolate(kg, kg0, kg1, 140, 166),
        vref_20: _interpolate(kg, kg0, kg1, 134, 160),
        vref_30: _interpolate(kg, kg0, kg1, 130, 156),
        vref_45: _interpolate(kg, kg0, kg1, 125, 148),
    };
    speedtables["CRJ1"].addTable(kg, speeds);
}
speedtables["CRJ1"].setMLW(37000);


var Booklet =
{
    bgcolor: [0.9, 0.9, 0.9, 1],
    new: func(name, svgfile, speedtable) {
        var obj = {
            parents: [me, canvas.SVGCanvas.new(name, canvas_settings)],
            svg_keys: [
                "title", "tonns", "kilogram", "weight_unit", "overweight",
                "v1_8", "vr_8", "v2_8", "vt",
                "v1_20", "vr_20", "v2_20",
                "vref_0", "vref_1", "vref_8", "vref_20", "vref_30", "vref_45",
                "page", "left", "right",
            ],
            _pageN: props.getNode("/sim/gui/speedbooklet/page",1),
            speedtable: speedtable,
        };

        obj.getCanvas().setColorBackground(me.bgcolor);
        obj.loadSVG(svgfile, obj.svg_keys);
        obj.init();
        #obj.addUpdateFunction(obj.update, 60);
        return obj;
    },

    init: func() {
        me["left"].addEventListener("click", func(e) { me.prevPage(); });
        me["right"].addEventListener("click", func(e) { me.nextPage(); });
        me._pageN.setIntValue(0);
        me._L = setlistener("/fdm/yasim/gross-weight-lbs", func(n) {
            var kg = n.getValue() * LB2KG;
            me._pageN.setIntValue(me.speedtable.getPageNumberByWeight(kg));
            me.update();
        }, 1, 0);
        var weight = getprop("/fdm/yasim/gross-weight-lbs") * LB2KG;
        return ;
    },

    del: func() {
        if (me._L) removelistener(me._L);
        call(canvas.SVGCanvas.del, [], me, var err = []);
        return nil;
    },
    
    nextPage: func() {
        if (me._pageN.getValue() < me.speedtable.getNumberOfPages() - 1) {
            me._pageN.increment();
            me.update();
        }
        return me;
    },

    prevPage: func() {
        if (me._pageN.getValue() > 0) {
            me._pageN.decrement();
            me.update();
        }
        return me;
    },
    
    update: func() {
        var number = me._pageN.getValue();
        var speeds = me.speedtable.getPage(number);
        foreach (var key; keys(speeds)) {
            if (vecindex(me.svg_keys, key) != nil)
                me[key].setText(sprintf("%d", speeds[key]));
        }
        me["overweight"].setVisible(me.speedtable.isOverMLW(speeds.weight));
        me["tonns"].setText(sprintf("%d", int(speeds.weight/1000)));
        me["kilogram"].setText(sprintf("%03d", math.mod(speeds.weight, 1000)));
        me["page"].setText(sprintf("%2d", number + 1));
    },

};

var getSpeedTable = func() {
    var aero = getprop("/sim/aero") or "CRJ700";
    return speedtables[left(aero,4)];
}
var book = nil;

# FlightGear command
var fgc_speedbooklet = func(node) {
    print("speedbooklet");
    var aero = getprop("/sim/aero") or "CRJ700";
    var st = getSpeedTable();
    book = Booklet.new("Speedbooklet "~aero, speedbooklet_svg, st);
    book["title"].setText(aero~" Speed Book");
    book.asWindow(window_size);
    #b.startUpdates();
}

addcommand("speedbooklet", fgc_speedbooklet);

var unload = func() {
    print("Unloading speedbooklet");
    removecommand("speedbooklet");
    if (book != nil) {
        book.del();
        book = nil;
    }
}