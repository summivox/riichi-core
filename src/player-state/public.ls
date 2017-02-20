module.exports = class PlayerPublic
  (@jikaze) ->
    # sutehai {discarded tile}: (maintained by methods)
    #   pai
    #   fuuroPlayer: (only property that can be set externally)
    #     claimed by a player through chi/pon/kan => id of this player
    #     otherwise => null
    #   tsumokiri
    #   riichi: if used to *declare* riichi
    # sutehaiBitmap: for fast check of `sutehaiFuriten` condition
    #   same convention as `Pai.binFromBitmap`
    # lastSutehai == sutehai[*-1]
    @sutehai = []
    @sutehaiBitmaps = [0 0 0 0]
    @lastSutehai = null

    # fuuro {melds}: (managed externally by Kyoku logic)
    #   type: <[minjun minko daiminkan ankan kakan]>
    #   pai: equiv. Pai with smallest number (e.g. 67m chi 0m => 5m)
    #   ownPai: array of Pai from this player's juntehai
    #   otherPai: Pai taken from other player
    #   fromPlayer
    #   kakanPai: last Pai that makes the kakan
    @fuuro = []
    @menzen = true # NOTE: menzen != no fuuro (due to ankan)

    # riichi flags: (managed externally by Kyoku logic)
    @riichi =
      declared: false # goes and stays true immediately after player declares
      accepted: false # goes and stays true if riichi dahai did not cause ron
      double:   false # goes and stays true if declared during true first tsumo
      ippatsu:  false # true only during ippatsu period; false otherwise

  dahai: (pai, tsumokiri, riichi) ->
    @sutehaiBitmaps[pai.S].|.= 1.<<.pai.N
    @sutehai.push @lastSutehai = {pai, tsumokiri, riichi, fuuroPlayer: null}

  # check if pai has been discarded before
  sutehaiContains: (pai) ->
    !!(@sutehaiBitmaps[pai.S].&.(1.<<.pai.N))
