# PlayerHiddenMock: part of KyokuView logic
# Imitates the behavior of `PlayerHidden` for other players in KyokuView,
# without knowing what's actually in their hands.
#
# NOTE: all `can`-methods are removed
# See: `PlayerHidden`, `KyokuView`

require! {
  './pai': Pai
  './decomp': {decompTenpai}
}

module.exports = class PlayerHiddenMock
  (!!@hasTsumohai, +@nJuntehai) ->
    # Juntehai and tsumohai: (maintained by methods)
    #   hasTsumohai <=> `PH::tsumohai?`
    #   nJuntehai   <=> `PH::juntehai.length`
    #
    # see: juntehai/tsumohai state transition diagram in `PlayerHidden`
    
    # fake return values for:
    # - tsumokiri/dahai
    # - removeEquivN
    @nextDahai = null
    @nextRemoved = []

    # fake decompTenpai: empty wait
    @decompTenpai = wait: []

    # fake declaredAction: always null
    @declaredAction = null

  # (3n+1) => (3n+1)*
  tsumo: !-> @hasTsumohai = true

  # (3n+1)* => (3n+1)
  tsumokiri: -> @hasTsumohai = false ; @nextDahai

  # (3n+1)* or (3n+2) => (3n+1)
  dahai: -> @nJuntehai-- ; @nextDahai

  # fuuro interface: remove only

  # chi/pon: (3n+1) (no tsumohai)
  # remove given 2 pai from juntehai => (3N+2)
  remove2: !-> @nJuntehai -= 2

  # kan: (3n+1) [daiminkan] or (3n+1)* [ankan/kakan]
  # remove n * given pai in juntehai & tsumohai
  #   daiminkan: (3n+1)  => (3N+1)
  #   an/kakan:  (3n+1)* => (3N+1)
  removeEquivN: (pai, n) ->
    @nJuntehai = @nJuntehai - n + @hasTsumohai
    @hasTsumohai = false
    @nextRemoved
