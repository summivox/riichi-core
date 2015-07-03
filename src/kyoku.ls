# kyoku {round}
# A complete game {chan} consists of a number of mutually independent kyoku's.
# NOTE: this has inevitably become a God Class, partially due to the complex
# nature of the game itself.

require! {
  'events': {EventEmitter}
  './decomp.js': {decompDiscardTenpai, decompTenpai, decompAgari}
  './pai.js': Pai
}

# stub: emulated enums
function Enum(names) => o = {} ; for name in names => o[name] = [name] ; o

module.exports = class Kyoku implements EventEmitter::
  # start a new kyoku
  # analogous to shuffling and dealing process on an automatic table
  #
  # `init` (immutable):
  #   bakaze: 0/1/2/3 => E/S/W/N
  #   nKyoku: 1/2/3/4
  #   honba: >= 0
  #   kyoutaku: >= 0
  #   tenbou: array of score/points/sticks of each player
  # e.g. {1 3 2 1} =>
  # - Nan {South} 3 Kyoku {Round}
  # - current dealer = player 2
  # - 2 Honba (dealer has renchan'd twice)
  # - 1*1000 kyoutaku {riichi bet} on table
  #
  # NOTE:
  # - tenbou does not take into account of riichi kyoutaku within this round
  #   actual value is 1000 less if in valid riichi state
  #
  # TODO: doc rulevar
  (@init, @rulevar, wall = null) ->
    EventEmitter.call @
    # divide wall:                  136         cumulative sum
    #   haipai {initial deal}       13*4 = 52   52
    #   piipai {live wall}          70          122
    #   dora hyoujihai {indicator}  5*2         132
    #   rinshan {kan tsumo}         4           136
    #
    # NOTE:
    #
    # - wall defaults to shuffled (can be given instead e.g. for testing)
    #
    # - orders are different from table-top practices as shuffling is i.i.d.
    #   uniform and unpredictable (of course depending on PRNG quality)
    #   - both piipai and rinshan are drawn from tail (`.pop()`)
    #   - when rinshan is drawn, remove one from head of piipai (`.shift()`)
    #   - even though internal representation is simplified, client may choose
    #     to visualize in a way analogous to table-top play
    #
    # - dora handling:
    #   - @globalHidden.doraHyouji: always the original 5*2 tiles
    #     [0] => omote {up}, [1] => ura {down}
    #   - @globalPublic.doraHyouji: revealed ones
    #   - @globalPublic.dora: corresponding actually indicated dora
    if !wall?
      wall = Pai.shuffleAll @rulevar.dora.akapai
    if wall.haipai?
      {haipai, piipai, doraHyouji, rinshan} = wall
    else
      haipai =
        wall[0  til 13]
        wall[13 til 26]
        wall[26 til 39]
        wall[39 til 52]
      piipai = wall[52 til 122]
      doraHyouji =
        wall[122 til 127]
        wall[127 til 132]
      rinshan = wall[132 til 136]
    #TODO: add back "traditional" order for compatibility with Tenhou logs

    # player id:
    #   chancha {dealer}
    #   playerSeq: by jikaze {seat wind} order
    chancha = init.nKyoku - 1
    @playerSeq = seq =
      (chancha + 0)%4 #  ton   east  (chancha)
      (chancha + 1)%4 #  nan   south
      (chancha + 2)%4 #  shaa  west
      (chancha + 3)%4 #  pei   north

    # all mutable states

    @globalHidden =
      piipai
      rinshan
      doraHyouji

    @globalPublic =
      # table states
      kyoutaku: @init.kyoutaku # increases as riichi succeeds
      nPiipaiLeft: 70 # decreased even when drawn from rinshan
      nKan: 0 # increases as player completes kan (up to 4)
      doraHyouji: []
      dora: []

      # game progression states (see below for details)
      player: chancha
      state: @BEGIN
      lastAction:
        type: null
        player: null
        details: null
    @playerHidden = [new PlayerHidden i, haipai[i] for i til 4]
    @playerPublic = [new PlayerPublic i, seq[i]    for i til 4]

    @result = null

    # reveal initial dora {motodora}
    @_revealDoraHyouji\init

    # done


  # state machine
  #   BEGIN: player starts turn normally or after kan
  #   TURN : awaiting player decision after tsumo
  #   QUERY: awaiting other players' declaration (chi/pon/kan/ron)
  #   END  : game has finished
  import Enum <[ BEGIN TURN QUERY END ]> #
  advance: !->
    {player, state} = @globalPublic
    switch state
    | @BEGIN  => @_begin!
    | @TURN   => @emit \turn , player
    | @QUERY  => @emit \query, player
    | @END    => void
    | _ => throw new Error "riichi-core: kyoku: advance: bad state (#state)"

  # actions and associated details object:
  #   DAHAI: {pai: null/Pai, riichi: true/false}
  #   CHI/PON/KAN: fuuro object (see PlayerPublic)
  #
  # when an action finishes:
  # - `lastAction` is updated
  # - event `\action` is emitted
  import Enum <[ DAHAI CHI PON KAN ]> #


  # `_`-prefix method: internal
  # pair with & without `can`-prefix: user-facing action interface
  #
  # - `can`-method judge if the action is valid
  #   return: {valid, reason}
  #   DOES NOT depend on state hidden to the player
  #
  # - prefix-less method:
  #   - call `can`-method first to determine if the action is valid;
  #     invalid => throw error with reason
  #   - perform action & update state
  #   - update `lastAction` and emits event

  # preparation before a player's turn
  _begin: !->
    {player, lastAction} = @globalPublic
    @_tsumo lastAction.type == @KAN

    if @playerPublic[player].riichi\
    and not @canAnkan player\
    and not @canTsumohou player
      # forced tsumokiri during riichi
      @dahai player, null

    @globalPublic.state = @TURN
    @advance!

  # tsumo {draw} both from piipai and rinshan
  _tsumo: (rinshan) !->
    with @globalHidden
      if rinshan
        pai = ..rinshan.pop()
        ..piipai.shift()
      else
        pai = ..piipai.pop()
    with @globalPublic
      @playerHidden[..player].addTsumo pai
      ..state = @TURN
      ..nPiipaiLeft--
      ..activeAction = {type: null}

  # common check for `can`-methods: if it's the player's turn
  function checkTurn(player)
    with @globalPublic
      if player != ..player or ..state != @TURN
        return valid: false, reason: "not your turn"
    return valid: true
  function checkQuery(player)
    with @globalPublic
      # NOTE: not typo!
      if player == ..player or ..state != @QUERY
        return valid: false, reason: "not your turn"
    return valid: true

  # player actions available in normal turn:
  # - dahai (including riichi declaration)
  # - kakan/ankan
  # - tsumoho
  # - kyuushuukyuuhai (the only *optional* ryoukyoku)

  # dahai {discard}
  # - pai: null => tsumokiri
  # - riichi: true => declare riichi before discard
  canDahai: (player, pai, riichi = false) ->
    with checkTurn player => if not ..valid then return ..
    with @playerPrivate
      if pai? then ..canTsumokiri! else ..canDahai pai
  dahai: (player, pai, riichi = false) !->
    {valid, reason} = @canTsumokiri player, pai
    if not valid
      throw new Error "riichi-core: kyoku: dahai: #reason"
    if pai?
      @playerPublic.dahai @playerPrivate.dahai pai
      @emit \action, player, type: \dahai, 
    else
      @playerPublic.tsumokiri pai = @playerPrivate.tsumokiri!
    @_revealDoraHyouji\dahai
    @_updateFuriten player
    @_checkRyoukyoku!
    with @globalPublic
      ..state = switch ..state
      | @NORMAL_START, @CHI_PON_DAHAI => @NORMAL_QUERY
      | @RIICHI_DAHAI                 => @RIICHI_QUERY

  # ankan
  # see rule variations: `.yaku.kokushiAnkan`
  canAnkan: (player, pai) ->
    with checkTurn player => if not ..valid then return ..
    if n = @playerHidden.juntehaiBins[pai.equivNumber-1][pai.suiteNumber] < 4
      return valid: false, reason: "not enough [#pai] (you have #n, need 4)"
    #TODO:
    if @playerPublic.riichi then
    return valid: true
  ankan: (player, pai) !->
    {valid, reason} = @canAnkan player, pai
    if not valid
      throw new Error "riichi-core: kyoku: ankan: #reason"
    if @rulevar.yaku.kokushiAnkan
      # ankan chankan possible
      @globalPublic.state = @KAN_QUERY
    else
      @globalPublic.state = @KAN_SUCCESS
    @_advance!

  # kakan
  @KAKAN_VALID_STATES = [@NORMAL_START]
  canKakan: (player, pai) ->
    with checkTurn player, @KAKAN_VALID_STATES
      if not ..valid then return ..
    if n = @playerHidden.juntehaiBins[pai.equivNumber-1][pai.suiteNumber] != 1
      return valid: false, reason:
        "must have exactly one [#pai] in juntehai (you have #n)"
    # TODO: relies on fuuro handling

  # state updating routines indirectly associated with player action

  # update player's furiten {sacred discard} status flags
  # return: true if player is suffering from any kind of furiten
  _updateFuriten: (player) -> ...

  # reveal dora hyoujihai(s)
  # previously delayed kan-dora will always be revealed
  # kanType: \daiminkan, \kakan, \ankan
  #   anything else: treat as not delayed
  #
  # see rule variations: `.dora.kan`
  _revealDoraHyouji: (type) !->
    # shorthands (too messy using `with`)
    ghdh = @globalHidden.doraHyouji[0]
    gpdh = @globalPublic.doraHyouji
    gpd  = @globalPublic.dora
    rule = @rulevar.dora.kan

    begin = gpdh.length
    end = if rule then @globalPublic.nKan - (rule[type] ? 0) else 0
    for i from begin to end
      gpdh.push dh = ghdh[i]
      gpd.push dh.succ



  _finish: -> ...



  #############################################################################
  # GARBAGE BELOW
  #############################################################################

  # declare 9-9 ryoukyoku
  # see rule variations: `.ryoukyoku.kyuushuukyuuhai`
  @KYUUSHUUKYUUHAI_VALID_STATES = [@NORMAL_START]
  canKyuushuukyuuhai: (player) ->
    with checkTurn player, @KYUUSHUUKYUUHAI_VALID_STATES
      if not ..valid then return ..
    if !@rulevar.ryoukyoku.kyuushuukyuuhai
      return valid: false, reason: "not allowed by rulevar"
    with @playerPublic
      menzen = ..0.menzen && ..1.menzen && ..2.menzen && ..3.menzen
      if not menzen
        return valid: false, reason: "not menzen"
      if ..[player].sutehai.length > 0
        return valid: false, reason: "already discarded"
    nYaochuu = 0
    for pai in @playerHidden[player].juntehai
      if pai.isYaochuu then nYaochuu++
    if nYaochuu < 9
      return valid: false, reason: "only #nYaochuu*yaochuu (>= 9 needed)"
    return valid: true
  kyuushuukyuuhai: (player) !->
    {valid, reason} = @canKyuushuukyuuhai player
    if not valid
      throw new Error "riichi-core: kyoku: kyuushuukyuuhai: #reason"
    with @globalPublic
      ..state = @END
      ..result =
        type: \ryoukyoku
        player: ..player
        renchan

  # tsumohou
  @TSUMOHOU_VALID_STATES = [@NORMAL_START]
  canTsumohou: (player) ->
    with checkTurn player, @TSUMOHOU_VALID_STATES
      if not ..valid then return ..
    #TODO: relies on `agari`
    ...
    return valid: true
  tsumohou: (player) !->
    {valid, reason} = @canTsumohou player
    if not valid
      throw new Error "riichi-core: kyoku: tsumohou: #reason"
    ...
    with @globalPublic
      ..state = @END
      ..result =
        type: \tsumohou
        player: ..player

  # declare riichi
  # see rule variations: `.riichi`
  @RIICHI_VALID_STATES = [@NORMAL_START]
  canRiichi: (player) ->
    with checkTurn player, @RIICHI_VALID_STATES
      if not ..valid then return ..
    if not @playerPublic[player].menzen
      return valid: false, reason: "not menzen"
    if (tenbou = @init.tenbou[player]) < 1000
      return valid: false, reason: "bankrupt (you have #tenbou, need 1000)"
    decomps = decompDiscardTenpai @playerHidden[player].juntehaiBins
    #TODO
    ...
  riichi: (player) !->
    {valid, reason} = @canRiichi player
    if not valid
      throw new Error "riichi-core: kyoku: riichi: #reason"
    @globalPublic.state = @RIICHI_DAHAI
    @_advance!

    ...
  kakan: !->
    {valid, reason} = @canKakan player, pai
    if not valid
      throw new Error "riichi-core: kyoku: kakan: #reason"
    ...

  # dahai/tsumokiri (differences handled in player state objs)
  # pai: null => tsumokiri
  @DAHAI_VALID_STATES = [@NORMAL_START, @RIICHI_DAHAI, @CHI_PON_DAHAI]

  @END_QUERY_VALID_STATES = [@NORMAL_QUERY, @KAN_QUERY, @RIICHI_QUERY]
  endQuery: !->
    with @globalPublic
      switch ..state
      | @QUERY => ..state = @NORMAL_END
      | @QUERY_CHANKAN => ..state = @KAN
    @_advance!


class PlayerHidden
  (@id, haipai) ->
    # juntehai (updated through methods)
    # - (3*n+1) tiles (no tsumo)
    #   - action: `addTsumo`
    #   - decomp: tenpai
    # - (3*n+2) tiles (w/ tsumo)
    #   - action: `tsumokiri`/`dahai`
    #   - decomp: discardTenpai
    @juntehai = haipai
    @juntehaiBins = bins = Pai.binsFromArray haipai
    @tsumo = null

    # tenpai decompositions (updated through methods)
    @decompTenpai = decompTenpai bins
    @decompDiscardTenpai = null

    # furiten (updated externally)
    @furiten = false
    @sutehaiFuriten = false
    @doujunFuriten = false
    @riichiFuriten = false

  # NOTE: this is only used internally so no "can"-prefix method
  addTsumo: (pai) !->
    if @tsumo? then throw new Error "riichi-core: kyoku: PlayerHidden: "+
      "already has tsumo (#{@tsumo})"
    @juntehaiBins[pai.equivNumber-1][pai.suiteNumber]++
    @tsumo = pai
    # update decomp
    @decompTenpai = null
    @decompDiscardTenpai = decompDiscardTenpai @juntehaiBins

  canTsumokiri: ->
    if !@tsumo? then return valid: false, reason: "no tsumo"
    return valid: true
  tsumokiri: ->
    {valid, reason} = @canTsumokiri!
    if not valid
      throw new Error "riichi-core: kyoku: PlayerHidden: tsumokiri: #reason"
    pai = @tsumo
    @juntehaiBins[pai.equivNumber-1][pai.suiteNumber]--
    @tsumo = null
    # update decomp
    @decompTenpai = decompTenpai @juntehaiBins
    @decompDiscardTenpai = null
    return pai

  canDahai: (pai) ->
    if !@tsumo? then return valid: false, reason: "no tsumo"
    for p, i in @juntehai
      if p == pai then break
    if p != pai
      return valid: false, reason:
        "[#pai] not in juntehai [#{Pai.stringFromArray a}]"
    return valid: true, i: i
  dahai: (pai) ->
    {valid, reason, i} = @canDahai pai
    if not valid
      throw new Error "riichi-core: kyoku: PlayerHidden: dahai: #reason"
    @juntehaiBins[pai.equivNumber-1][pai.suiteNumber]--
    @juntehai
      ..[i] = @tsumo
      ..sort Pai.compare
    # update decomp
    @decompTenpai = decompTenpai @juntehaiBins
    @decompDiscardTenpai = null
    return pai

class PlayerPublic
  (@id, @jikaze) ->
    # sutehai {discarded tile}:
    #   fuuroPlayer:
    #     claimed by a player through chi/pon/kan => id of this player
    #     otherwise => null
    #   sutehaiBitmap: for fast check of `sutehaiFuriten` condition
    #     same convention as `Pai.binFromBitmap`
    #   lastSutehai == sutehai[*-1]
    @sutehai = []
    @sutehaiBitmaps = [0 0 0 0]
    @lastSutehai = null

    # fuuro {melds}:
    #   type: \shuntsu \koutsu \daiminkan \kakan \ankan
    #   pai: "representative" Pai (see below examples)
    #   ownPai: array of Pai from this player's juntehai
    #   otherPai: Pai taken from other player
    #   kakanPai: Pai from this player's juntehai that completed the kakan
    @fuuro = []
    @menzen = true # NOTE: menzen != no fuuro (due to ankan {concealed kan})
    @riichi = false
    @doubleRiichi = false
    @ippatsu = false
    @kan = null # valid: null, \daiminkan, \kakan, \ankan

  tsumokiri: (pai) -> @dahai pai, true
  dahai: (pai, tsumokiri = false) ->
    @sutehaiBitmaps[pai.suiteNumber] .|.= 1 .<<. (pai.equivNumber-1)
    with {pai, tsumokiri, fuuroPlayer: null}
      @sutehai.push ..
      @lastSutehai = ..
      return ..

# determine if a player has indeed tsumohou'd or ron'd, and if yes, determine
# the hand decomposition that maximizes tokuten {score/points gain}
function agari(kyoku, player)
  ...
