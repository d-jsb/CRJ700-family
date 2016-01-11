## Walk view
## From http://wiki.flightgear.org/Walk_view
############################################

# view nodes and offsets
var zViewNode = props.globals.getNode("sim/current-view/y-offset-m", 1);
var xViewNode = props.globals.getNode("sim/current-view/z-offset-m", 1);
var yViewNode = props.globals.getNode("sim/current-view/x-offset-m", 1);
var hViewNode = props.globals.getNode("sim/current-view/heading-offset-deg", 1);

var walk_about = func(wa_distance)
{
#	var internal = props.globals.getNode("sim/current-view/internal");
#	if (internal != nil and internal.getBoolValue())
#	{
		var wa_heading_rad = hViewNode.getValue() * 0.01745329252;
		var new_x_position = xViewNode.getValue() - (math.cos(wa_heading_rad) * wa_distance);
		var new_y_position = yViewNode.getValue() - (math.sin(wa_heading_rad) * wa_distance);
		xViewNode.setValue(new_x_position);
		yViewNode.setValue(new_y_position);
#	}
}

setlistener("sim/current-view/crouch", func(v) {
	if (v.getBoolValue())
		zViewNode.setValue(zViewNode.getValue() - 0.8);
	else
		zViewNode.setValue(zViewNode.getValue() + 0.8);	
},0,0);

setlistener("sim/current-view/raise", func(v) {
	if (v.getBoolValue())
		zViewNode.setValue(zViewNode.getValue() + 0.2);
	else
		zViewNode.setValue(zViewNode.getValue() - 0.2);	
},0,0);
