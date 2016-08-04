require! {
  'chai': {assert}
  'fs-extra-promise': fs
}
root = require 'app-root-path'
{
  decomp1C, makeDecomp1C
  decomp1W, makeDecomp1W, countDecomp1W
}:decomp = require "#root/src/decomp-next/decomp-next.ls"

D = describe
I = it

D 'decomp-next', ->
  function binStr(key)
    s = Number key .toString 8
    return ('0' * (9 - s.length)) + s

  var C, Ck, Wk
  before ->
    console.log '\n--- timing ---'
    console.time 'make total'
    console.time 'make C'
    makeDecomp1C!
    console.timeEnd 'make C'
    console.time 'make W'
    makeDecomp1W!
    console.timeEnd 'make W'
    console.timeEnd 'make total'
    console.log '\n'
    C := {[bin, cs] for bin, cs of decomp1C}
    Ck := [Number bin for bin, cs of decomp1C].sort!
    Wk := [binStr bin for bin, ws of decomp1W].sort!

  # TODO: actually load the ref files and compare
  D 'C-table', ->
    I 'correct # of keys', ->
      assert.equal Ck.length, 21743
    I 'correct # of entries', ->
      assert.equal ([cs.length for bin, cs of C].reduce (+)), 23533
    I 'same bin => same # of jantou, same # of mentsu', ->
      for bin, cs of decomp1C
        assert ((cs.every -> it.jantou?) or (cs.every -> !it.jantou?))
        l = cs.0.mentsu.length
        assert cs.every (.mentsu.length == l)
  D 'W-table', ->
    I 'correct # of entries', ->
      assert.equal do
        [cs.length for binW, ws of decomp1W for {cs} in ws].reduce (+)
        161738
