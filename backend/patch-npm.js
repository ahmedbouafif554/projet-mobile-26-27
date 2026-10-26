const Module = require('module');
const origRequire = Module.prototype.require;
Module.prototype.require = function (id) {
  const res = origRequire.apply(this, arguments);
  if (typeof res === 'function' && !res.Minipass && (id === 'minipass' || id.endsWith('/minipass') || id.endsWith('\\minipass') || id.includes('minipass'))) {
    res.Minipass = res;
  }
  return res;
};
