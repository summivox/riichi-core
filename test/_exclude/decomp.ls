require! {
  'chai': {assert}:chai
  'fs-extra-promise': fs
  path
  'globby': glob
}
#chai.use require 'chai-shallow-deep-equal'

function globAndRequire(...pattern)
  glob.sync ...pattern .map (filename) ->
    {filename, file: require filename}

root = require 'app-root-path'
{
  decomp: {
    decomp1C, makeDecomp1C
    decomp1W, makeDecomp1W, countDecomp1W
    decompTenpai
  }:decomp,
  Pai
}:pkg = require "#root"

D = describe
I = it

D 'decomp', ->
  function binToString(key)
    s = Number key .toString 8
    return ('0' * (9 - s.length)) + s

  var C, Ck, Wk
  before ->
    console.log '\n\n=== startup timing ==='
    with decomp.STARTUP_TIME
      console.log "C: #{..c.toFixed 2} ms"
      console.log "W: #{..w.toFixed 2} ms"
      console.log "total: #{..cw.toFixed 2} ms"
    console.log '\n\n'
    C := {[bin, cs] for bin, cs of decomp1C}
    Ck := [Number bin for bin, cs of decomp1C].sort!
    Wk := [binToString bin for bin, ws of decomp1W].sort!

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

    # TODO: just moved here; need to use them
    function printDecomp1C
      outs = []
      for bin, cs of decomp1C
        bs = binToString bin
        for {jantou, mentsu} in cs
          out = bs
          for x in mentsu
            out += if x.&.2~10000 then ',1' + (x.&.2~1111) else ',0' + x
          if jantou?
            out += ',2' + jantou
          outs.push out
      outs .sort! .join '\n'
    function dumpDecomp1C
      fs
        ..writeFileSync 'c-all.txt', printDecomp1C!
        ..writeFileSync 'c-keys.txt', Ck.join '\n'

  D.skip 'W-table', ->
    I 'correct # of entries', ->
      assert.equal do
        [cs.length for binW, ws of decomp1W for {cs} in ws].reduce (+)
        161738
    function dumpDecomp1W
      fs
        ..writeFileSync 'w-keys-uniq.txt', Wk.join '\n'

  D 'decompTenpai', ->
    function canonicalTenpaiDecomp({decomps, tenpaiSet}:td)
      tenpaiSet.sort Pai.compare
      decomps.forEach ->
        it.mentsu.sort (a, b) ->
          if Pai.compare(a.anchor, b.anchor) then return that
          if a.type < b.type then -1 else +1
        it.k7 ?= null
      decomps.sort (a, b) ->
        if Pai.compare(a.tenpai, b.tenpai) then return that
        if a.tenpaiType < b.tenpaiType then -1 else +1
      return JSON.parse JSON.stringify td
    base = path.posix.normalize "#__dirname/data/decomp"
    files = globAndRequire "#base/tenpai/*.json.ls"
    for let {filename, file} in files
      {desc, str, partial, tenpaiSet, decomps} = file
      I desc, ->
        actual = canonicalTenpaiDecomp decompTenpai Pai.binsFromString str
        expected = canonicalTenpaiDecomp Pai.cloneFix {tenpaiSet, decomps}
        assert.deepEqual actual, expected

  D.skip 'decompAgari', ->
    void # TODO
    # NOTE: I don't think this is necessary because the code is very straight-
    # forward; correctness directly depends on `decompTenpai`.
