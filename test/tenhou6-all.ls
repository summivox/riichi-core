require! {
  'chai': {assert}
  'fs-extra-promise': fs
  'globby': glob
  path

  "./lib/kyoku-stepper.ls": KyokuStepper
}
root = require 'app-root-path'
{Event} = require "#root"
tenhou6 = require "#root/src/tenhou6"

D = describe
I = it

function say
  console.log JSON.stringify it

# convert object to plain-old-data
function POD(obj)
  JSON.parse JSON.stringify obj

function sortedYaku(yaku)
  if !yaku? then return []
  yaku.slice!sort (a, b) -> a.name < b.name

function canonicalAgari(agari)
  ret = POD agari{
    isTsumo, isRon, delta
    agariPlayer, houjuuPlayer
    han, fu, basicPoints
    dora, doraTotal
    yakuTotal, yakumanTotal
  }
  with ret
    if ..basicPoints >= 2000 then ..fu = null
    ..yaku = sortedYaku agari.yaku
    ..yakuman = sortedYaku agari.yakuman
    ..yakuTotal ?= 0
    ..yakumanTotal ?= 0
    if ..yakumanTotal > 0
      # tenhou6 does not mark out dora explicitly if yakuman
      # simply ignore this when comparing
      ..dora = []
      ..doraTotal = 0


replayGame = ({rulevar, kyokus}) !->
  endState = null
  for let {startState, events, result: retB}, i in kyokus
    if endState then assert.deepEqual startState, endState
    {master} = stepper = new KyokuStepper {rulevar, startState}
    for eRaw in events
      e = Event.import eRaw
      master.exec e.init master
    assert.equal master.seq, events.length
    assert.equal master.phase, \end
    retA = master.result
    switch retA.type
    | \tsumoAgari
      assert.equal retA.renchan, retB.renchan
      assert.deepEqual do
        canonicalAgari retA.agari
        canonicalAgari retB.agari
    | \ron
      assert.equal retA.renchan, retB.renchan
      assert.deepEqual do
        retA.agari.map canonicalAgari
        retB.agari.map canonicalAgari
    | \ryoukyoku
      if retB.renchan? then assert.equal retA.renchan, retB.renchan
      assert.equal retA.reason, retB.reason
    endState = master.endState

simGame = (filename, {title, rulevar, kyokus}) ->
  ...

function globAndRead(pattern)
  glob.sync pattern .map (filename) ->
    {filename, file: fs.readJsonSync filename}

D 'tenhou6', ->
  base = path.posix.normalize "#__dirname/data/tenhou6"
  files = globAndRead "#base/*/*.json"
  for let {filename, file} in files
    I path.relative(base, filename), ->
      replayGame tenhou6.parseGame file