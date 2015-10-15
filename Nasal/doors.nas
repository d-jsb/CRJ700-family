## Bombardier CRJ700 series
## Nasal door system
###########################

var Door =
{
	new: func(name, transit_time, pos = 0)
	{
		return aircraft.door.new("sim/model/door-positions/" ~ name, transit_time, pos);
	}
};

var doors =
{
	pax_left: Door.new("pax-left", 3, 1),
	fwd_service: Door.new("pax-right", 2),
	av_bay: Door.new("av-bay", 2.3),
	fwd_cargo: Door.new("fwd-cargo", 1.7),
	ctr_cargo: Door.new("ctr-cargo", 2.1),
	aft_cargo: Door.new("aft-cargo", 2.5),
	flight_deck: Door.new("flight-deck", 1),
	overhead_bins: Door.new("overhead-bins", 2),

	close: func {
		me.pax_left.close();
		me.fwd_service.close();
		me.av_bay.close();
		me.fwd_cargo.close();
		me.ctr_cargo.close();
		me.aft_cargo.close();
		me.flight_deck.close();
		me.overhead_bins.close();		
	},
};
