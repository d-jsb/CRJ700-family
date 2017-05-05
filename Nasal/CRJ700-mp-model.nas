#
# CRJ700 MP model nasal module
#

var CRJ700_mp_model = {
  new: func(model) {
    var obj = { parents: [CRJ700_mp_model],
      listeners: [],
      aliases: [],
      model: model,
    };
    
    return obj;
  },


  start: func() {
    printf("MP model "~me.model.getPath());
    var node = model.getNode("systems/DC/outputs/rear-ac-light", 1);
    node.alias(me.model.getPath()~"/systems/DC/outputs/wing-ac-lights");
    append(me.aliases, node);
  },
  
  stop: func() {
    foreach (l; me.listeners) {
      removelistener(l);
    }
    me.listeners = [];
    foreach (n; me.aliases) {
      n.unalias();
    }
    me.aliases = [];
  },
}