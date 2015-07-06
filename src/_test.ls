require! {
  'events': {EventEmitter}
  './decomp': {decompDahaiTenpai, decompTenpai, decompAgari}
  './pai': Pai
  './wall': splitWall
  './agari': _agari
  './kyoku': Kyoku
  './rulevar-default': rulevar
}

window.Pai = Pai
window.Kyoku = Kyoku
window.rulevar = rulevar
window.decompDahaiTenpai = decompDahaiTenpai
window.decompTenpai = decompTenpai
window.decompAgari = decompAgari

init =
  bakaze: 1
  nKyoku: 3
  honba: 2
  kyoutaku: 1000
  tenbou: [25000 25000 25000 25000]

debugger
module.exports = K = new Kyoku(init, rulevar)
K.on \turn , (player) ->
  console.log "### #{player}P turn"
K.on \query, (player, lastAction) ->
  console.log ">>> #{player}P query: " + JSON.stringify lastAction
K.on \end, (result) ->
  console.log "### END"
  console.log JSON.stringify result
K.on \action, (player, action) ->
  console.log "<<< #{player}P action: " + JSON.stringify action
K.on \declare, (player, type) ->
  console.log "!!! #{player}P declare: #type"

window.tehai = ->
  ret = ""
  with K.playerHidden[it]
    ret += Pai.stringFromArray(..juntehai)
    if ..tsumo then ret += " : #{..tsumo}"
  ret
window.dahai = (i, p) -> K.dahai(i, Pai[p])
