module.exports = {
  util: require('./src/util'),
  Pai: require('./src/pai'),
  decomp: require('./src/decomp'),
  Kyoku: require('./src/kyoku'),
  Event: require('./src/kyoku-event'),
  rule: require('./src/rulevar-default'),

  init: function() { module.exports.decomp.init(); }
};
