require! {
  './pai': Pai
  './decomp': {decompTenpai}
}

module.exports = class PlayerHidden
  (haipai) ->
    # juntehai and tsumohai: (maintained by methods)
    #   tsumohai: null or Pai
    #   juntehai: sorted array of Pai (excl. tsumohai)
    #   bins: counts both `juntehai` and `tsumohai`
    #   tenpaiDecomp: tenpai decomposition of latest (3n+1) juntehai state
    #
    # juntehai/tsumohai count changes as follows:
    # (* => tsumohai ; n = 0/1/2/3/4 ; N = n or n-1)
    #
    # - (3n+1)   : tsumo      => (3n+1)*
    #            : chi/pon    => (3N+2)   -> dahai  => (3N+1)
    #            : daiminkan  => (3N+1)   -> tsumo  => (3N+1)*
    #
    # - (3n+1)*  : dahai      => (3n+1)
    #            : an/kakan   => (3N+1)   -> tsumo  => (3N+1)*
    #
    @tsumohai = null
    @juntehai = haipai.slice!sort Pai.compare
    @bins = Pai.binsFromArray haipai
    @tenpaiDecomp = decompTenpai @bins

    # Furiten status flags: (managed externally by Kyoku logic)
    #
    #   `furiten`: if any of the sub-flags are true
    #
    #   `sutehaiFuriten`: if any pai in your tenpai set is also in your sutehai
    #
    #   `doujunFuriten`:
    #   - goes true when another player's dahai {discard} is in your tenpai set
    #     but you didn't or couldn't declare ron
    #   - goes false when you dahai
    #
    #   `riichiFuriten`:
    #   - goes and stays true when `doujunFuriten` goes true while in riichi
    @furiten = false
    @sutehaiFuriten = false
    @doujunFuriten = false
    @riichiFuriten = false

  # (3n+1) => (3n+1)*
  tsumo: (pai) !->
    if @tsumohai?
      # arriving at here means corrupt state => panic
      throw Error "riichi-core: kyoku: PlayerHidden: "+
        "already has tsumohai [#{@tsumohai}]"
    @bins[pai.S][pai.N]++
    @tsumohai = pai

  # (3n+1)* => (3n+1)
  # update tenpaiDecomp
  canTsumokiri: ->
    if not @tsumohai? then return valid: false, reason: "no tsumohai"
    return valid: true
  tsumokiri: ->
    {valid, reason} = @canTsumokiri!
    if not valid
      throw Error "riichi-core: kyoku: PlayerHidden: tsumokiri: #reason"
    pai = @tsumohai
    @bins[pai.S][pai.N]--
    @tenpaiDecomp = decompTenpai @bins
    @tsumohai = null
    return pai

  # (3n+1)* or (3n+2) => (3n+1)
  # update tenpaiDecomp
  canDahai: (pai) ->
    i = @juntehai.indexOf pai
    if i == -1 then return valid: false, reason:
      "[#pai] not in juntehai [#{Pai.stringFromArray @juntehai}]"
    return valid: true, i: i
  dahai: (pai) ->
    {valid, reason, i} = @canDahai pai
    if not valid
      throw Error "riichi-core: kyoku: PlayerHidden: dahai: #reason"
    @bins[pai.S][pai.N]--
    @tenpaiDecomp = decompTenpai @bins
    with @juntehai
      if @tsumohai # (3n+1)*
        ..[i] = @tsumohai
        ..sort Pai.compare
      else         # (3n+2)
        ..splice(i, 1)
      @tsumohai = null
    return pai

  # decompose (3n+1)* or (3n+2) hand excluding given pai
  decompTenpaiWithout: (pai) ->
    if !@tsumohai then return null
    bins = @bins
    if bins[pai.S][pai.N] <= 0 then return null
    bins[pai.S][pai.N]--
    decomp = decompTenpai bins
    bins[pai.S][pai.N]++
    return decomp

  # fuuro interface: count and remove

  # chi/pon: (3n+1)
  # kakan:   (3n+1)*
  # count given pai in juntehai
  count1: (pai) ->
    s = 0
    if @tsumohai == pai then s++
    for p in @juntehai => if p == pai then s++
    s
  # remove given 2 pai from juntehai => (3N+2)
  remove2: (pai0, pai1) !->
    @bins[pai0.S][pai0.N]--
    @bins[pai1.S][pai1.N]--
    with @juntehai
      ..splice(..indexOf(pai0), 1)
      ..splice(..indexOf(pai1), 1)

  # kan: (3n+1) [daiminkan] or (3n+1)* [ankan/kakan]
  # here akahai {red 5} == normal 5 (i.e. 0m/0p/0s == 5m/5p/5s)
  # count given pai in juntehai & tsumohai
  countEquiv: (pai) ->
    @bins[pai.S][pai.N]
  # remove n * given pai in juntehai & tsumohai
  #   daiminkan: (3n+1)  => (3N+1)
  #   an/kakan:  (3n+1)* => (3N+1)
  # update tenpaiDecomp
  # return all removed pai
  removeEquivN: (pai, n) ->
    ret = []
    pai .= equivPai
    @bins[pai.S][pai.N] -= n
    @tenpaiDecomp = decompTenpai @bins
    @juntehai = @juntehai.filter ->
      if it.equivPai == pai && --n >= 0
        ret.push it
        return false
      return true
    if @tsumohai?.equivPai == pai && --n >= 0
      ret.push @tsumohai
      @tsumohai = null
    # if tsumohai remains after removing, join it with juntehai to arrive at
    # (3N+1) form and make way for the incoming rinshan tsumo
    if @tsumohai
      @juntehai.push @tsumohai # <-- need to sort
      @tsumohai = null
      @juntehai.sort Pai.compare
    ret
