module.exports = class PlayerHiddenMock
  (@hasTsumohai = false, @nJuntehai = 13) ->
    @isMock = true
    # Juntehai and tsumohai: (maintained by methods)
    #   hasTsumohai <=> `PlayerHidden::tsumohai?`
    #   nJuntehai   <=> `PlayerHidden::juntehai.length`
    #
    # see: juntehai/tsumohai state transition diagram in `PlayerHidden`

  # TODO: assert

  # (3n+1) => (3n+1)*
  tsumo: !->
    @hasTsumohai = true

  # (3n+1)* => (3n+1)
  tsumokiri: !->
    @hasTsumohai = false

  # (3n+1)* or (3n+2) => (3n+1)
  dahai: (pai) !->
    if @hasTsumohai # (3n+1)*
      @hasTsumohai = false
    else            # (3n+2)
      @nJuntehai--

  # fuuro interface: remove only

  # chi/pon: (3n+1) (no tsumohai)
  # remove given 2 pai from juntehai => (3N+2)
  remove2: !-> @nJuntehai -= 2

  # kan: (3n+1) [daiminkan] or (3n+1)* [ankan/kakan]
  # remove n * given pai in juntehai & tsumohai
  #   daiminkan: (3n+1)  => (3N+1)
  #   an/kakan:  (3n+1)* => (3N+1)
  removeEquivN: (pai, n) !->
    @nJuntehai = @nJuntehai - n + @hasTsumohai
    @hasTsumohai = false
