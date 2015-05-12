## Bombardier CRJ700 series
## Nasal door system
###########################

var Door =
{
	new: func(name, transit_time)
	{
		return aircraft.door.new("sim/model/door-positions/" ~ name, transit_time);
	}
};
var doors =
{
	pax_left: Door.new("pax-left", 3),
	pax_right: Door.new("pax-right", 3),
	fwd_cargo: Door.new("fwd-cargo", 3),
	ctr_right: Door.new("ctr-cargo", 3),
	aft_right: Door.new("aft-cargo", 3),
	flight_deck: Door.new("flight-deck", 1),
	overhead_bins: Door.new("overhead-bins", 2)
};
