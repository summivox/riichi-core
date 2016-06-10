require! {
  'chai': {assert}

  './pai': Pai
  './kyoku': Kyoku
  './kyoku-event': Event
  './util': {OTHER_PLAYER}
}

# shortcut for serialize
# NOTE: All deep comparison is done by comparing serialization instead of
# `assert.deepEqual` due to circular ref in `pai` literals.
S = JSON.~serialize

KYOKU_PUBLIC_ATTR = <[
  seq phase currPlayer rinshan virgin nTsumoLeft nKan doraHyouji
  playerPublic result endstate
]>#

module.exports = class Testrig
  ({rulevar, startState}:init) ->
    @master = new Kyoku init
    @replay = new Kyoku init
    @replicate = for p til 4
      new Kyoku {rulevar, startState, forPlayer: p}

    # check consistency across all instances
    @master.on \event, (e) !~>
      @replay.exec e
      partials = e.toPartials!
      for p til 4 => @replicate[p].exec partials[p]

      # check only the last event in a multi-ron series
      if e.type == \ron and e.isLast then return

      # kyoku public attributes: all equal
      for k in KYOKU_PUBLIC_ATTR
        v = S(@master[k])
        assert.equal S(@replay[k]), v
        for p til 4 => assert.equal S(@replicate[p][k]), v

      # wallParts: check replay only
      assert.equal S(@master.wallParts), S(@replay.wallParts)

      # currPai: null in replicate-other after tsumo
      v = @master.currPai
      assert.equal @replay.currPai, v
      if @master.phase == \postTsumo
        p0 = @master.currPlayer
        assert.isNull @replicate[p0].currPai
        for p in OTHER_PLAYER[p0]
          assert.equal @replicate[p].currPai, v
      else
        for p til 4 => assert.equal @replicate[p].currPai, v

      # currDecl: check only {what, player}
      # NOTE: `args` is canonicalized in replay while master might still keep
      # convenience constructor form
      assert.equal S(@master.currDecl), S(@replay.currDecl)
      for k, {what, player} of @master.currDecl
        with @replay.currDecl[k]
          assert.equal ..what, what
          assert.equal ..player, player
        for p til 4
          with @replicate[p].currDecl[k]
            assert.equal ..what, what
            assert.equal ..player, player
      # also check internal consistency
      with @master.currDecl
        for what in <[chi pon daiminkan ron]>#
          assert.equal ..[what].what, what
        for player til 4
          assert.equal ..[player].player, player

      # playerHidden and playerHiddenMock
      for p0 til 4
        PH = @master.playerHidden[p0]
        assert.equal S(@replay.playerHidden[p0]), PH
        assert.equal S(@replicate[p0].playerHidden[p0]), PH
        for p in OTHER_PLAYER[p0]
          PHM = @replicate[p].playerHidden[p0]
          assert.equal PHM.hasTsumohai, PH.tsumohai?
          assert.equal PHM.nJuntehai, PH.juntehai.length
        # also check internal consistency
        juntehai =
          if PH.tsumohai?
          then PH.juntehai ++ PH.tsumohai
          else PH.juntehai
        assert.deepEqual PH.bins, Pai.binsFromArray(juntehai)
        assert.equal PH.furiten,
          PH.sutehaiFuriten or PH.doujunFuriten or PH.riichiFuriten


  # run a common sequence in a game:
  # - construct replicate-initiated event on replicate-me
  # - send to master
  # - reconstruct on master and apply
  #
  # see `./kyoku-event` description on replicate-initiated events
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
