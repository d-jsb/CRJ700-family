##
## Bombardier CRJ700 series
##
## Wiper module simulation
##

# Wiper class
#
#  control - pilot's wiper control
#     0: off/park
#     1: hold position
#     2: run slow
#     3: run fast
#  position - output node to model
#  power_signal - tells the electrical system when the wiper requires power
#  power_avail - electrical power from electrical system
#
var Wiper = func(control, position, power_signal, power_avail)
{
    var wiper = {};

    wiper.control = 0;
    wiper.control_node = aircraft.makeNode(control);
    wiper.position = 0.0;
    wiper.position_node = aircraft.makeNode(position);
    wiper.power_signal = 0;
    wiper.power_signal_node = aircraft.makeNode(power_signal);
    wiper.power_avail = 0.0;
    wiper.power_avail_node = aircraft.makeNode(power_avail);

    var going_down = 1;
    var position = 0.0;

    var read_props = func
    {
        wiper.control = wiper.control_node.getValue();
        wiper.power_avail = wiper.power_avail_node.getValue();
    };
    var write_props = func
    {
        wiper.position_node.setDoubleValue(wiper.position);
        wiper.power_signal_node.setBoolValue(wiper.power_signal);
    };
    var compute_position = func(current_position, control, going_down)
    {
        var time_delta = getprop_safe("sim/time/delta-realtime-sec");
        var delta = 0.0;
        if (control == 0)
        {
            delta = time_delta * 2;
        }
        # This method does not need to handle control == 1.
        elsif (control == 2)
        {
            delta = time_delta * 2;
        }
        elsif (control == 3)
        {
            delta = time_delta * 4;
        }
        if (going_down)
        {
            return math.min(current_position + delta, 1);
        }
        else
        {
            return math.max(current_position - delta, 0);
        }
    };
    wiper.update = func
    {
        read_props();

        if (wiper.control == 0)
        {
            # Move the wiper until it reaches the "park" position.
            if (wiper.position == 0)
            {
                wiper.power_signal = 0;
            }
            else
            {
                wiper.power_signal = 1;
                if (wiper.position == 1)
                {
                    going_down = 0;
                }
                if (wiper.power_avail >= 15)
                {
                    wiper.position = compute_position(wiper.position, wiper.control,
                                                      going_down);
                }
            }
        }
        elsif (wiper.control == 1)
        {
            # Do nothing. :-)
            wiper.power_signal = 0;
        }
        else
        {
            # Move the wiper back and forth.
            wiper.power_signal = 1;
            if (wiper.position == 0)
            {
                going_down = 1;
            }
            elsif (wiper.position == 1)
            {
                going_down = 0;
            }
            if (wiper.power_avail >= 15)
            {
                wiper.position = compute_position(wiper.position, wiper.control,
                                                  going_down);
            }
        }

        write_props();
    };

    return wiper;
};
