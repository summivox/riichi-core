# determine if a player has indeed tsumohou'd or ron'd, and if yes, determine
# the hand decomposition that maximizes tokuten {score/points gain}
require! {
  './decomp': {decompTenpai, decompAgari}
}
module.exports = (player, ronPai) ->
  with @playerHidden[player]
    # NOTE: simplifies logic (can still tell if tsumo by testing ronPai)
    # TODO: rename?
    if ronPai then ..addTsumo ronPai
    bins = ..juntehaiBins
    decomps = decompAgari bins
    if ronPai then ..tsumokiri
    if decomps.length == 0 then return null
    return {
      player: player
      delta: [1, 1, 1, 1]
    }
