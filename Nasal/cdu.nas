###############################################################################
##
##  Interactive CDU control script.
##  Version 1.0.1-09172011
##
##  Copyright (C) 2011  Ryan Miller
##
##  This file is licensed under the GPL license version 2 or later.
##
##  Changes:
##    1.0.0     initial version
##    1.0.1     fix lag from page switching due to bug in loop code
##
###############################################################################

var UPDATE_PERIOD = 1;
var TEST_PERIOD = 5;

## Main CDU object
var Cdu =
{
    new: func(node, path)
    {
        node = aircraft.makeNode(node);
        var obj = { parents: [me],
            node: node,
            testing: 0,
            loop_id: 0,
            page_live: 0,
            current_page: nil,
            enabled: node.getNode("enabled") == nil ? 
                props.globals.initNode(node.getPath() ~ "/enabled", 1, "BOOL") 
                : node.getNode("enabled"),
            serviceable: node.getNode("serviceable", 1),
            tree: io.read_properties(path),
            tree_path: path,
            input_prop: nil,
            input_maxlength: nil,
            input_minlength: nil,
            scroll: 0,
            scroll_pos: 0,
            scroll_minlimit: nil,
            scroll_maxlimit: nil,
        };
        obj.rows = obj.tree.getNode("rows").getValue();
        obj.cols = obj.tree.getNode("cols").getValue();
        obj.default_page = obj.tree.getNode("default-page").getValue();
            
        obj._update_timer = maketimer(UPDATE_PERIOD, obj, obj._update_);
        obj.go_to_page(obj.default_page);
        obj.init();
        return obj;
    },
    
    init: func {
        setlistener(me.enabled, func(n) {
            if (n.getBoolValue()) me._update_timer.start();
            else me._update_timer.stop();
        }, 1, 0);
    },
    
    reload: func(newpath = nil)
    {
        me.tree = io.read_properties(newpath == nil ? me.tree_path : newpath);
        me.input_prop = nil;
        me.rows = me.tree.getNode("rows").getValue();
        me.cols = me.tree.getNode("cols").getValue();
        me.default_page = me.tree.getNode("default-page").getValue();
        me.go_to_page(me.default_page);
    },
    go_to_page: func(v)
    {
        me.testing = 0;
        me.clear();
        me.deactivate_input();
        me.scroll_pos = 0;
        var pages = me.tree.getChildren("page");
        var foundpage = 0;
        foreach (var page; pages)
        {
            var name = page.getNode("name", 1).getValue();
            if (name == v)
            {
                foundpage = 1;
                me.current_page = page;
                break;
            }
        }
        if (foundpage)
        {
            var group = me.current_page.getNode("group", 1).getValue();
            if (group != nil and group != "")
                {
                var number = me.current_page.getNode("number", 1).getValue();
                if (number == nil) number = 0;
                var group_population = 0;
                foreach (var page; me.tree.getChildren("page"))
                {
                    var thisgroup = page.getNode("group", 1).getValue();
                    if (thisgroup != nil and thisgroup == group)
                    {
                        group_population += 1;
                    }
                }
                me._setpagemsg(number + 1 ~ "/" ~ group_population);
            }
            if (me.current_page.getNode("scroll", 1).getBoolValue())
            {
                me.scroll = 1;
                var minlimit = me.current_page.getNode("scroll-min-limit", 0);
                if (minlimit != nil) me.scroll_minlimit = minlimit.getValue();
                var maxlimit = me.current_page.getNode("scroll-max-limit", 0);
                if (maxlimit != nil) me.scroll_maxlimit = maxlimit.getValue();
            }
            else
            {
                me.scroll = 0;
                me.scroll_minlimit = nil;
                me.scroll_maxlimit = nil;
            }
            var nasal = me.current_page.getChildren("nasal");
            if (size(nasal) > 0)
            {
                foreach (var node; nasal)
                {
                    me._parse_nasal(node);
                }
            }
            me.page_live = me.current_page.getNode("live", 1).getBoolValue();
            me._update_();
        }
        else
        {
            if (v == me.default_page)
            {
                print("ERROR: Default CDU page '" ~ me.default_page ~ "' not found!");
            }
            else
            {
                print("CDU page '" ~ v ~ "' not found. Returning to default page.");
                me.go_to_page(me.default_page);
            }
        }
    },
    run_line: func(row, col)
    {
        if (me.current_page == nil) return;
        var page = me.current_page;
        foreach (var line; page.getChildren("line"))
        {
            var line_row = line.getNode("row").getValue();
            var line_col = line.getNode("col").getValue();
            var bindings = line.getChildren("binding");
            if (line_row == row and line_col == col and size(bindings) > 0)
            {
                var condition = line.getNode("condition");
                if (!props.condition(condition)) continue;
                foreach (var binding; bindings)
                {
                    props.runBinding(binding);
                }
                break;
            }
        }
    },
    activate_input: func(prop, clear = 0, maxlength = nil, minlength = nil)
    {
        me.node.getNode("input", 1).setValue("");
        prop = aircraft.makeNode(prop);
        if (clear) prop.setValue("");
        me.input_prop = prop;
        me.input_maxlength = maxlength;
        me.input_minlength = minlength;
        var input_prop = props.globals.initNode(me.node.getPath() ~ "/input", "", "STRING");
        var val = clear ? "" : prop.getValue();
        if (val == 0)
        {
            input_prop.setValue("0"); # needs to be forced to 0 in string form, or else you get 0.00000000
        }
        else
        {
            input_prop.setValue(val);
        }
    },
    deactivate_input: func
    {
        me.input_prop = nil;
    },
    previous_page: func
    {
        me.inc_page(-1);
    },
    next_page: func
    {
        me.inc_page(1);
    },
    inc_page: func(v)
    {
        if (me.current_page == nil) return;
        var group = me.current_page.getNode("group", 1).getValue();
        var number = me.current_page.getNode("number", 1).getValue();
        if (group == nil or number == nil) return;
        foreach (var page; me.tree.getChildren("page"))
        {
            var thisgroup = page.getNode("group", 1).getValue();
            var thisnumber = page.getNode("number", 1).getValue();
            if (thisgroup == group and thisnumber == number + v)
            {
                me.go_to_page(page.getNode("name").getValue());
                return;
            }
        }
    },
    input: func(v)
    {
        var input_prop = me.node.getNode("input", 0);
        if (input_prop == nil) input_prop = props.globals.initNode(me.node.getPath() ~ "/input", "", "STRING");
        var input_prop_val = input_prop.getValue();
        if (me.input_maxlength == nil or size(input_prop_val) <= me.input_maxlength - 1)
        {
            input_prop_val ~= v;
            input_prop.setValue(input_prop_val);
        }
        var default_input_prop = me.node.getNode("display/input/value", 1);
        if (me.input_prop != nil)
        {
            me._setinputmsg("");
            if (me.input_minlength == nil or size(input_prop_val) >= me.input_minlength)
            {
                var type = me.input_prop.getType();
                if (type == "DOUBLE" or type == "FLOAT")
                {
                    var val = num(input_prop.getValue());
                    if (val == nil) val = 0;
                    me.input_prop.setDoubleValue(val);
                }
                elsif (type == "INT" or type == "LONG")
                {
                    var val = num(input_prop.getValue());
                    if (val == nil) val = 0;
                    me.input_prop.setIntValue(val);
                }
                else
                {
                    me.input_prop.setValue(input_prop.getValue());
                }
            }
        }
        else
        {
            me._setinputmsg(input_prop.getValue());
        }
    },
    clear_input: func
    {
        if (me.input_prop != nil) me.input_prop.setValue("");
        me._setinputmsg("");
        me.node.getNode("input", 1).setValue("");
    },
    delete_input: func
    {
        var input_prop = me.node.getNode("input", 1);
        var val = input_prop.getValue();
        input_prop.setValue(substr(val, 0, size(val) - 1));
        if (me.input_prop != nil)
        {
            var type = me.input_prop.getType();
            if (type == "DOUBLE" or type == "FLOAT")
            {
                var val = num(input_prop.getValue());
                if (val == nil) val = 0;
                me.input_prop.setDoubleValue(val);
            }
            elsif (type == "INT" or type == "LONG")
            {
                var val = num(input_prop.getValue());
                if (val == nil) val = 0;
                me.input_prop.setIntValue(val);
            }
            else
            {
                me.input_prop.setValue(input_prop.getValue());
            }
        }
        else
        {
            me._setinputmsg(input_prop.getValue());
        }
    },
    invert_input: func
    {
        if (me.input_prop == nil) return;
        var input_prop = me.node.getNode("input", 1);
        var input_val = input_prop.getValue();
        if (input_val == "" or input_val == nil) return;
        var type = me.input_prop.getType();
        if (type == "DOUBLE" or type == "FLOAT")
        {
            var val = num(string.replace("-" ~ input_val, "--", ""));
            if (val == nil) val = 0;
            me.input_prop.setDoubleValue(val);
        }
        elsif (type == "INT" or type == "LONG")
        {
            var val = num(string.replace("-" ~ input_val, "--", ""));
            if (val == nil) val = 0;
            me.input_prop.setIntValue(val);
        }
        else
        {
            return;
        }
        input_prop.setValue(val);
    },
    scroll_up: func
    {
        me.inc_scroll(1);
    },
    scroll_down: func
    {
        me.inc_scroll(-1);
    },
    inc_scroll: func(v)
    {
        if (me.scroll)
        {
            v = me.scroll_pos + v;
            if (me.scroll_minlimit != nil)
            {
                if (v < me.scroll_minlimit) v = me.scroll_minlimit;
            }
            if (me.scroll_maxlimit != nil)
            {
                if (v > me.scroll_maxlimit) v = me.scroll_maxlimit;
            }
            me.scroll_pos = v;
        }
        else
        {
            me.scroll_pos = 0;
        }
    },
    # _loop_: func(loop_id)
    # {
        # if (loop_id != me.loop_id) return;
        # if (!me.testing and me.current_page != nil and me.serviceable.getBoolValue() and me.page_live)
        # {
            # me._update_();
        # }
        # settimer(func me._loop_(loop_id), UPDATE_PERIOD);
    # },
    _update_: func
    {
        if (me.testing or me.current_page == nil or !me.serviceable.getBoolValue() or !me.page_live)
            return;
        me.clear();
        var page = me.current_page;
        var titleN = page.getNode("title", 1);
        var title_chunks = titleN.getChildren("chunk");
        var title_nasal = titleN.getChildren("nasal");
        if (size(title_chunks) > 0 or size(title_nasal) > 0)
        {
            var title = "";
            foreach (var node; title_chunks)
            {
                title ~= me._parse_chunk(node);
            }
            foreach (var node; title_nasal)
            {
                var result = me._parse_nasal(node);
                title ~= result == nil ? "" : result;
            }
            me._settitlemsg(title);
        }
        else
        {
            me._settitlemsg(titleN.getValue());
        }
        if (page.getNode("page") != nil) me._setpagemsg(page.getNode("page").getValue());
        foreach (var line; page.getChildren("line"))
        {
            var val = "";
            var font = line.getNode("font", 1);
            var row = line.getNode("row", 1).getValue();
            var col = line.getNode("col", 1).getValue();
            var condition = line.getNode("condition");
            if (props.condition(condition))
            {
                var text = line.getNode("text");
                if (text != nil) val = text.getValue();
                else
                {
                    var chunks = line.getChildren("chunk");
                    foreach (var node; chunks)
                    {
                        val ~= me._parse_chunk(node);
                    }
                    var nasal = line.getChildren("nasal");
                    foreach (var node; nasal)
                    {
                        var result = me._parse_nasal(node);
                        val ~= result == nil ? "" : result;
                    }
                }
                me._setrowcolmsg(val, row, col, me._getfont(font, "red"), me._getfont(font, "green"), me._getfont(font, "blue"));
            }
        }
    },
    _getfont: func(n, v)
    {
        var val = n == nil ? nil : n.getNode(v);
        return val == nil ? me._getdefaultfont(v) : val.getValue();
    },
    _getdefaultfont: func(v)
    {
        return me.tree.getNode("default-font/" ~ v, 1).getValue();
    },
    _settitlemsg: func(v)
    {
        var n = me.node.getNode("display/title", 1);
        n.getNode("value", 1).setValue(v);
        n.getNode("color-red-norm", 1).setValue(me._getfont(me.tree.getNode("title-font"), "red"));
        n.getNode("color-green-norm", 1).setValue(me._getfont(me.tree.getNode("title-font"), "green"));
        n.getNode("color-blue-norm", 1).setValue(me._getfont(me.tree.getNode("title-font"), "blue"));
    },
    _setpagemsg: func(v)
    {
        var n = me.node.getNode("display/page", 1);
        n.getNode("value", 1).setValue(v);
        n.getNode("color-red-norm", 1).setValue(me._getfont(me.tree.getNode("page-font"), "red"));
        n.getNode("color-green-norm", 1).setValue(me._getfont(me.tree.getNode("page-font"), "green"));
        n.getNode("color-blue-norm", 1).setValue(me._getfont(me.tree.getNode("page-font"), "blue"));
    },
    _setinputmsg: func(v)
    {
        var n = me.node.getNode("display/input", 1);
        n.getNode("value", 1).setValue(v);
        n.getNode("color-red-norm", 1).setValue(me._getfont(me.tree.getNode("input-font"), "red"));
        n.getNode("color-green-norm", 1).setValue(me._getfont(me.tree.getNode("input-font"), "green"));
        n.getNode("color-blue-norm", 1).setValue(me._getfont(me.tree.getNode("input-font"), "blue"));
    },
    _setrowcolmsg: func(v, row, col, red = nil, green = nil, blue = nil)
    {
        red = red == nil ? me._getdefaultfont("red") : red;
        green = green == nil ? me._getdefaultfont("green") : green;
        blue = blue == nil ? me._getdefaultfont("blue") : blue;

        var n = me.node.getNode("display/row[" ~ row ~ "]/col[" ~ col ~ "]", 1);
        n.getNode("value", 1).setValue(v);
        n.getNode("color-red-norm", 1).setValue(red);
        n.getNode("color-green-norm", 1).setValue(green);
        n.getNode("color-blue-norm", 1).setValue(blue);
    },
    _parse_chunk: func(node)
    {
        var format = node.getNode("format", 1).getValue();
        var prop = props.globals.getNode(node.getNode("property", 1).getValue(), 1);
        var prop_type = prop.getType();
        if (prop_type == "DOUBLE" or prop_type == "INT" or prop_type == "FLOAT" or prop_type == "LONG")
        {
            var factor = node.getNode("scale");
            factor = factor == nil ? 1 : factor.getValue();
            var offset = node.getNode("offset");
            offset = offset == nil ? 0 : offset.getValue();
            return sprintf(format, prop.getValue() * factor + offset);
        }
        else
        {
            return sprintf(format, prop.getValue() == nil ? "" : prop.getValue());
        }
    },
    _parse_nasal: func(node)
    {
        var script = node.getValue();
        var exec = compile(script);
        return exec();
    },
    clear: func(clear_input = 0)
    {
        me._settitlemsg("");
        me._setpagemsg("");
        if (clear_input) me._setinputmsg("");
        for (var i = 0; i < me.rows; i += 1)
        {
            for (var j = 0; j < me.cols; j += 1)
            {
                me._setrowcolmsg("", i, j);
            }
        }
    },
    test: func
    {
        me.testing = 1;
        me._settitlemsg("TITLE");
        me._setpagemsg("PG");
        me._setinputmsg("TEST");
        for (var i = 0; i < me.rows; i += 1)
        {
            for (var j = 0; j < me.cols; j += 1)
            {
                me._setrowcolmsg("ROW " ~ i ~ " COL " ~ j, i, j);
            }
        }
        settimer(func me.go_to_page(me.default_page), TEST_PERIOD);
    }
};

## Route Manager utility functions
var rm_node = props.globals.getNode("autopilot/route-manager", 1);
var rm_input = rm_node.getNode("input", 1);
var RouteManager =
{
    input: func(v)
    {
        rm_input.setValue("@" ~ v);
    },
    load_flightplan: func
    {
        RouteManager._load_selector.open();
    },
    save_flightplan: func
    {
        RouteManager._save_selector.open();
    },
    clear: func
    {
        RouteManager.input("clear");
    },
    insert: func(i, v)
    {
        RouteManager.input("insert" ~ i ~ ":" ~ v);
    },
    delete: func(i)
    {
        RouteManager.input("delete" ~ i);
    },
    jump_to: func(i)
    {
        RouteManager.input("jump" ~ i);
    },
    route: func(i)
    {
        RouteManager.input("route" ~ i);
    },
    activate: func
    {
        RouteManager.input("activate");
    },
    set_waypoint_altitude: func(i, v)
    {
        var wpN = props.globals.getNode("autopilot/route-manager/route/wp[" ~ i ~ "]", 1);
        var id = wpN.getNode("id", 1).getValue();
        if (id == nil) return;
        RouteManager.delete(i);
        RouteManager.insert(i, id ~ "@" ~ v);
    },
    swap_waypoints: func(i1, i2)
    {
        var routeN = props.globals.getNode("autopilot/route-manager/route", 1);

        var wp1N = routeN.getChild("wp", i1, 1);
        var id1 = wp1N.getNode("id", 1).getValue();
        if (id1 == nil) return;
        var alt1 = wp1N.getNode("altitude-ft", 1).getValue();

        var wp2N = routeN.getChild("wp", i2, 1);
        var id2 = wp2N.getNode("id", 1).getValue();
        if (id2 == nil) return;
        var alt2 = wp2N.getNode("altitude-ft", 1).getValue();

        RouteManager.delete(i1);
        RouteManager.insert(i1, id2 ~ "@" ~ alt2);
        RouteManager.delete(i2);
        RouteManager.insert(i2, id1 ~ "@" ~ alt1);
    }
};

# create the file selectors after all other Nasal has been loaded, otherwise
# we end up with strange nonexistent variable errors
settimer(func()
{
    RouteManager._load_selector = gui.FileSelector.new(func(path)
    {
        rm_node.getNode("file-path", 1).setValue(path.getValue());
        RouteManager.input("load");
    }, "Load flight-plan", "Load");
    RouteManager._save_selector = gui.FileSelector.new(func(path)
    {
        rm_node.getNode("file-path", 1).setValue(path.getValue());
        RouteManager.input("save");
    }, "Save flight-plan", "Save");
}, 0);
