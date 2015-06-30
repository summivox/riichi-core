Pai = require './pai.js'

module.exports = class Tehai


  constructor: ->
    @juntehai = []
    @tsumo = null
    @fuuro = []
    @tenpai = []
    @menzen = true

  dahai: (pai) ->
    if !@tsumo? then throw new Error 'riichi-core: tehai: cannot dahai without tsumo'
    i = @juntehai.indexOf pai
    @juntehai[i] = @tsumo
    @juntehai.sort Pai.compare
