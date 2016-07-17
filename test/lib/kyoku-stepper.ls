require! {
  'chai': {assert}:chai
}
chai.use require 'chai-shallow-deep-equal'

root = require 'app-root-path'
{
  Pai
  Kyoku
  Event
  util: {OTHER_PLAYERS}
} = require "#root"

# convert object to plain-old-data
function POD(obj)
  JSON.parse JSON.stringify obj

KYOKU_PUBLIC_ATTR = <[
  seq phase currPlayer rinshan virgin nTsumoLeft nKan doraHyouji
  playerPublic endstate
]>#

function startStateToTitle({bakaze, chancha, honba}:startState)
  "#{<[E S W N]>[bakaze]}#{chancha + 1}.#honba"

function say
  console.log JSON.stringify it

module.exports = class KyokuStepper
  ({rulevar, startState}:init = {}) ->
    @master = new Kyoku init
    @replay = new Kyoku init
    @replicate = for p til 4
      new Kyoku {rulevar, startState, forPlayer: p}

    title = startStateToTitle startState

    # check consistency across all instances
    @master.on \event, (e) !~>
      # common header for assertion message
      H = "#title\##{e.seq}"
      #console.log "#H #{JSON.stringify e.toMinimal!}" # DEBUG

      # feed the event to replay and replicates
      @replay.exec Event.reconstruct(e).init(@replay)
      partials = e.toPartials!
      for p til 4
        @replicate[p].exec Event.reconstruct(partials[p]).init(@replicate[p])

      # check only the last event in a multi-ron series
      if e.type == \ron and not e.isLast then return

      # kyoku public attributes: all equal
      for k in KYOKU_PUBLIC_ATTR
        v = @master[k]
        assert.deepEqual @replay[k], v, "#H replay[#k]"
        for p til 4
          assert.deepEqual @replicate[p][k], v, "#H replicate[#p][#k]"

      # wallParts: check replay only
      assert.deepEqual @master.wallParts, @replay.wallParts, "#H"

      # currPai: null in replicate-other after tsumo/tsumoAgari
      v = @master.currPai
      assert.equal @replay.currPai, v, "#H"
      if @master.phase == \postTsumo
      or @master.phase == \end and @master.result.type == \tsumoAgari
        p0 = @master.currPlayer
        assert.equal @replicate[p0].currPai, v, "#H"
        for p in OTHER_PLAYERS[p0]
          assert.isNull @replicate[p].currPai, "#H replicate[#p].currPai"
      else if @master.phase != \end
        for p til 4
          assert.equal @replicate[p].currPai, v, "#H replicate[#p].currPai"

      # currDecl: check only {what, player}
      # NOTE: `args` is canonicalized in replay while master might still keep
      # convenience constructor form
      assert.deepEqual POD(@master.currDecl), POD(@replay.currDecl), "#H"
      for k, decl of @master.currDecl
        if !decl? then continue
        {what, player} = decl
        with @replay.currDecl[k]
          assert.isNotNull ..,
            "#H replay.currDecl[#k]"
          assert.equal ..what, what,
            "#H replay.currDecl[#k].what"
          assert.equal ..player, player,
            "#H replay.currDecl[#k].player"
        for p til 4
          with @replicate[p].currDecl[k]
            assert.isNotNull ..,
              "#H replicate[#p].currDecl[#k]"
            assert.equal ..what, what,
              "#H replicate[#p].currDecl[#k].what"
            assert.equal ..player, player,
              "#H replicate[#p].currDecl[#k].player"
      # also check internal consistency
      with @master.currDecl
        for what in <[chi pon daiminkan ron]>
          if ..[what]?
            assert.equal ..[what].what, what,
              "#H master.currDecl[#what]"
        for player til 4
          if ..[player]?
            assert.equal ..[player].player, player,
              "#H master.currDecl[#player]"

      # result: only at kyoku end
      # compared after converting to POD due to ghetto member functions
      #
      # NOTE: `result.agari.uraDoraHyouji` is not present in replicates
      if @master.phase == \end
        r = POD(@master.result)
        assert.deepEqual POD(@replay.result), r
        for p til 4
          assert.shallowDeepEqual r, POD(@replicate[p].result)

      # playerHidden and playerHiddenMock
      for p0 til 4
        PH = @master.playerHidden[p0]
        assert.deepEqual @replay.playerHidden[p0], PH
        assert.deepEqual @replicate[p0].playerHidden[p0], PH
        for p in OTHER_PLAYERS[p0]
          PHM = @replicate[p].playerHidden[p0]
          assert.equal PHM.hasTsumohai, PH.tsumohai?
          assert.equal PHM.nJuntehai, PH.juntehai.length
        # also check internal consistency
        juntehai =
          if PH.tsumohai?
          then PH.juntehai ++ PH.tsumohai
          else PH.juntehai
        assert.deepEqual PH.bins, Pai.binsFromArray(juntehai) # [][]Number
        assert.equal PH.furiten,
          PH.sutehaiFuriten or PH.doujunFuriten or PH.riichiFuriten


  # run a common sequence in a game:
  # - construct replicate-initiated event on replicate-me
  # - send to master
  # - reconstruct on master and apply
  #
  # see `src/kyoku-event` description on replicate-initiated events
  play: (player, type, args) ->
    e = new Event[type] @replicate[player], args
    if type in <[chi pon daiminkan ron]>#
      # wrap declaration
      # FIXME: which is better?
      argsDecl = {what: type, args}
      # argsDecl = {what: type, e.toMinimal!}

      ed = new Event.declare @replicate[player], argsDecl
      em = new Event.declare @master, argsDecl

    else
      em = new Event[type] @master, args
    @master.exec em
