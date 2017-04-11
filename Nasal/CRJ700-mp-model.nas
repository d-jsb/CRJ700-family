#
# CRJ700 MP model nasal module
#
io.include("Nasal/lightmaps.nas");
var Loop = func(interval, update)
{
  var loop = {};
  var timerId = -1;
  loop.interval = interval;
  loop.update = update;
  loop.loop = func(thisTimerId)
  {
      if (thisTimerId == timerId)
      {
          loop.update();
      }
      settimer(func {loop.loop(thisTimerId);}, loop.interval);
  };

  loop.start = func
  {
      timerId += 1;
      settimer(func {loop.loop(timerId);}, 0);
  };

  loop.stop = func {timerId += 1;};
  return loop;
};

var slow_loop = Loop(2, func {
	update_lightmaps();
});


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
    slow_loop.start();
  },
  
  stop: func() {
    slow_loop.stop();
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