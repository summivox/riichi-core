# determine if a player has indeed tsumohou'd or ron'd, and if yes, determine
# the hand decomposition that maximizes tokuten {score/points gain}
# TODO: now it's dummy (only returns decompAgari)
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
    if ronPai then ..removeTsumo ronPai
    if decomps.length then return decomps[0] else return null
