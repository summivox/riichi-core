Pai = require './pai.js'
trie = require './agari-trie.js'

module.exports = class Tehai

  # contracted hand representation => array of pai
  # e.g. 3347m40p11237s26z5m
  @parse: (s) ->
    ret = []
    for run in s.match /\d*\D/g
      l = run.length
      if l <= 2
        # not contracted
        ret.push Pai[run]
      else
        # contracted
        suite = run[l-1]
        for i in [0...(l-1)]
          number = run[i]
          ret.push Pai[number + suite]
    ret.sort Pai.compare
    ret

  @stringify: (paiList) ->
    if !paiList? then throw Error 'riichi-core: tehai: stringify: null input'
    l = paiList.length
    if l == 0 then return ''

    # make a sorted copy
    paiList = paiList.slice().sort Pai.compare
    ret = ''
    run = [paiList[0].number]
    suite = paiList[0].suite
    flush = -> ret += run.join('') + suite

    for i in [1...l]
      pai = paiList[i]
      if pai.suite == suite
        run.push pai.number
      else
        flush()
        run = [pai.number]
        suite = pai.suite
    flush()
    return ret

  constructor: ->
    @junteihai = []
    @tsumo = null
    @fuuro = []
    @tenpai = []
    @menzen = true

  dahai: (pai) ->
    if !@tsumo? then throw new Error 'riichi-core: tehai: cannot dahai without tsumo'
    i = @junteihai.indexOf pai
    @junteihai[i] = @tsumo
    @junteihai.sort Pai.compare
