# Copyright (C) 2014  onox
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

var TakeoffRunwayAnnounceConfig = {
	diff_runway_heading_deg: 20,
	diff_approach_heading_deg: 40,
	# Maximum angle at which the aircraft should approach the runway.
	# Must be higher than 0 and lower than 90.
	distance_center_line_m: 10,
	# The distance in meters from the center line of the runway
	distance_edge_min_m: 20,
	distance_edge_max_m: 80,
	# Minimum and maximum distance in meters from the edge of the runway
	# for announcing approaches.
	nominal_distance_takeoff_m: 3000,
	# Minimum distance in meters required for a normal takeoff. If
	# remaining distance when entering the runway is less than the distance
	# required for a normal takeoff, then the on-short-runway instead of
	# on-runway signal will be emitted.

	nominal_distance_landing_m: 2000,
	# Minimum distance in meters required for a normal landing. If
	# runway length when approaching the runway is less than the distance
	# required for a normal landing, then the approaching-short-runway
	# instead of approaching-runway signal will be emitted.

	distances_unit: "meter",
	# The unit to use for the remaining distance of short runways. Can
	# be "meter" or "feet".

	groundspeed_max_kt: 40,
	# Maximum groundspeed in knots for approaching runway callouts

	approach_afe_min_ft: 300,
	approach_afe_max_ft: 750,
	# Minimum and maximum altitude Above Field Elevation in feet. Used to
	# decide whether to announce that the aircraft is approaching a runway.

	approach_distance_max_nm: 3.0,
};
#var LandingRunwayAnnounceConfig = {
#	distances_meter: [100,  300,  600,  900, 1200, 1500],
#	distances_feet:  [500, 1000, 2000, 3000, 4000, 5000],
#	distances_unit: "meter",    # unit for remaining distance. Can be "meter" or "feet"
#	distance_center_nose_m: 0,    # Distance from the center to the nose in meters
#	diff_runway_heading_deg: 20,
#	groundspeed_min_kt: 40,
#	agl_max_ft: 100,
#};



var copilot_say = func (message) {
    setprop("/sim/messages/copilot", message);
#    logger.info(sprintf("Announcing '%s'", message));
};

var on_short_runway_format = func {
    var distance = takeoff_announcer.get_short_runway_distance();
    return sprintf("On runway .. %%s .. %d %s remaining", distance, takeoff_config.distances_unit);
};

var approaching_short_runway_format = func {
    var distance = takeoff_announcer.get_short_runway_distance();
    return sprintf("Approaching .. %%s .. %d %s available", distance, takeoff_config.distances_unit);
};

var remaining_distance_format = func {
    return sprintf("%%d %s remaining", landing_config.distances_unit);
};

var takeoff_config = { parents: [raas.TakeoffRunwayAnnounceConfig] };

# Will cause the announcer to emit the "on-runway" signal if the
# aircraft is at most 20 meters from the center line of the runway
takeoff_config.distance_center_line_m = 20;

# Let the announcer emit the "approaching-runway" signal if the
# aircraft comes within 120 meters of the runway
takeoff_config.distance_edge_max_m = 120;

var landing_config = { parents: [raas.LandingRunwayAnnounceConfig] };

var tmp = getprop("sim/model/dimensions/nose-distance-m");
if (tmp != nil and typeof(tmp) == "int") 
	landing_config.distance_center_nose_m = tmp;

var tmp = getprop("sim/model/limits/mtow-rw-m");
if (tmp != nil and typeof(tmp) == "int") 
	takeoff_config.nominal_distance_takeoff_m = tmp;

var tmp = getprop("sim/model/limits/mlw-rw-m");
if (tmp != nil and typeof(tmp) == "int") 
	takeoff_config.nominal_distance_landing_m = tmp;

# Create announcers
var takeoff_announcer = raas.TakeoffRunwayAnnounceClass.new(takeoff_config);
var landing_announcer = raas.LandingRunwayAnnounceClass.new(landing_config);

var stop_announcer    = raas.make_stop_announcer_func(takeoff_announcer, landing_announcer);
var switch_to_takeoff = raas.make_switch_to_takeoff_func(takeoff_announcer, landing_announcer);

takeoff_announcer.connect("on-runway", raas.make_betty_cb(copilot_say, "On runway .. %s", switch_to_takeoff, raas.runway_number_filter));
takeoff_announcer.connect("on-short-runway", raas.make_betty_cb(copilot_say, on_short_runway_format, switch_to_takeoff, raas.runway_number_filter));
takeoff_announcer.connect("approaching-runway", raas.make_betty_cb(copilot_say, "Approaching .. %s", nil, raas.runway_number_filter));
takeoff_announcer.connect("approaching-short-runway", raas.make_betty_cb(copilot_say, approaching_short_runway_format, nil, raas.runway_number_filter));

landing_announcer.connect("remaining-distance", raas.make_betty_cb(copilot_say, remaining_distance_format));
landing_announcer.connect("vacated-runway", raas.make_betty_cb(nil, nil, stop_announcer));
landing_announcer.connect("landed-outside-runway", raas.make_betty_cb(nil, nil, stop_announcer));

var set_on_ground = raas.make_set_ground_func(takeoff_announcer, landing_announcer);
var init_takeoff  = raas.make_init_func(takeoff_announcer);

var init_announcers = func {
    setlistener("/gear/on-ground", func (node) {
        set_on_ground(node.getBoolValue());
    }, 0, 0);
    init_takeoff();
};

setlistener("/sim/signals/fdm-initialized", func {
    var timer = maketimer(5.0, func init_announcers());
    timer.singleShot = 1;
    timer.start();
});
