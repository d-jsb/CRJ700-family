## Bombardier CRJ700 series
## Multiplayer nasal
###########################

## Publish our properties over the MP network via /sim/multiplay/generic
var mp_generic = props.globals.getNode("sim/multiplay/generic", 1);
var mp_props_file = io.read_properties("Aircraft/CRJ700-family/Systems/CRJ700-multiplayer.xml");
foreach (var ref; mp_props_file.getChildren("reference"))
{
	var prop = props.globals.getNode(ref.getNode("property").getValue(), 1);
	var val = mp_generic.getChild(ref.getNode("type").getValue(), ref.getNode("index").getValue(), 1);
	val.alias(prop);
}
