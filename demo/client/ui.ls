# UI

require! {
  './conf': {PAI_H, PAI_PATH}
}

# react and DOM
{
  DOM: $
  createElement: $new
  createClass: $class
  render: $render
} = window.React
qS = -> document.querySelector it
qSA = -> document.querySelectorAll it
$HTML = -> dangerouslySetInnerHTML: __html: it

# single pai
#   x, y: bottom-left corner
#   pai: e.g. \1m, \3s, ...
#     special: \8z => backside
#   rot:
#     -1: 90 degrees CCW
#      0: no rotation (default)
#     +1: 90 degrees CW
#   className: (default: '')
export Pai = $class do
  displayName: 'Pai'
  render: ->
    {pai, x, y, rot, className} = @props
    className ?= ''
    className += ' pai'
    if pai != /^\d[mpsz]$/ then return null
    switch rot
    | -1 => transform = "rotate(-90)"
    |  0 => transform = "translate(0, -#PAI_H)"
    | +1 => transform = "translate(#PAI_H, -1) rotate(+90)"
    $\g {transform: "translate(#x #y)", className} <<<< $HTML """
      <image xlink:href="#PAI_PATH/#pai.svg"
        width="1" height="#PAI_H" preserveAspectRatio="xMidYMid slice"
        transform="#transform"/>
    """

# horizontal row of pai, bottom-justified
#   x, y: bottom-left/bottom-right corner
#   list: array of:
#     pos: if the upside of pai is pointing:
#       \u => up (default)
#       \l => left (riichi, fuuro)
#       \r => right (fuuro)
#       \L => left, stacked (kakan)
#       \R => right, stacked (kakan)
#     space: after the pai (default: 0)
#     className: (default: '')
#   right:
#     false => bottom-left justified (default)
#     true  => bottom-right justified
export PaiRow = $class do
  displayName: 'PaiRow'
  render: ->
    xNext = 0
    {right, x, y} = @props
    $\g do
      transform: "translate(#x #y)"
      @props.list.map ({pai, pos, space, className}, i) ->
        switch pos
        | \l, \r =>
          x = if right then -xNext - PAI_H else xNext
          y = 0
          rot = if pos == \l then -1 else +1
          xNext += PAI_H
        | \L, \R =>
          x = if right then -xNext else xNext - PAI_H
          y = -1
          rot = if pos == \L then -1 else +1
        | _ =>
          x = if right then -xNext - 1 else xNext
          y = 0
          rot = 0
          xNext++
        if space then xNext += space
        $new Pai, {pai, x, y, rot, className ? '', key: i}

# sutehai area
#   x, y: top-left corner
#   maxCol: max # of pai per row (except for last row)
#   maxRow: max # of rows
#   sutehai: see kyoku/PlayerPublic::sutehai
#   showFuuro: if chi/pon/kan'd pai is shown (default: no)
export Sutehai = $class do
  displayName: 'Sutehai'
  render: ->
    rows = []
    row = []
    {x, y, maxCol, maxRow, sutehai, showFuuro} = @props
    for {pai, fuuroPlayer, tsumokiri, riichi}, i in sutehai
      className = ''
      if fuuroPlayer? and not showFuuro then continue
      if tsumokiri then className += ' pai-tsumokiri'
      if riichi
        className += ' pai-riichi'
        pos = \l
      else
        pos = \u
      if row.push({pai, pos, className}) == maxCol
      and rows.length <= maxRow - 2
        rows.push row
        row = []
    if row.length then rows.push row
    $\g {},
      rows.map (row, i) -> $new PaiRow,
        list: row
        x: x
        y: y + (i+1)*PAI_H
        right: false
        key: i

# fuuro: translate to PaiRow list
export function rowFromFuuro(fuuro, player)
  ret = []
  for f in fuuro
    own = f.ownPai.sort! # so that akahai will go to front
    other = f.otherPai
    dP = (f.otherPlayer - player + 4)%4
    switch f.type.toString!toLowerCase!
    | \shuntsu, \minko =>
      if dP == 1 then ret.push pai: other, pos: \r
      ret.push pai: own.1, pos: \u
      if dP == 2 then ret.push pai: other, pos: \l
      ret.push pai: own.0, pos: \u
      if dP == 3 then ret.push pai: other, pos: \l
    | \daiminkan =>
      if dP == 1 then ret.push pai: other, pos: \r
      ret.push pai: own.2, pos: \u
      ret.push pai: own.1, pos: \u
      if dP == 2 then ret.push pai: other, pos: \l
      ret.push pai: own.0, pos: \u
      if dP == 3 then ret.push pai: other, pos: \l
    | \kakan =>
      if dP == 1
        ret.push pai: other, pos: \r
        ret.push pai: f.kakanPai, pos: \R
      ret.push pai: own.1, pos: \u
      if dP == 2
        ret.push pai: other, pos: \l
        ret.push pai: f.kakanPai, pos: \L
      ret.push pai: own.0, pos: \u
      if dP == 3
        ret.push pai: other, pos: \l
        ret.push pai: f.kakanPai, pos: \L
    | \ankan =>
      ret.push pai: \8z, pos: \u
      ret.push pai: own.1, pos: \u
      ret.push pai: own.0, pos: \u
      ret.push pai: \8z, pos: \u
    | _ => throw Error "wtf type #{f.type}"
  ret

# juntehai + tsumo: also translate to PaiRow list
export function rowFromJuntehai(juntehai, tsumo)
  ret = juntehai.map -> pai: it, pos: \u, space: 0
  if tsumo
    ret[*-1].space = 1/6
    ret.push pai: tsumo, pos: \u, space: 0
  ret

# other player's juntehai + tsumo: covered
export function rowBack(n, tsumo)
  ret = [{pai: \8z, pos: \u, space: 0} for i til n]
  if tsumo
    ret[*-1].space = 1/6
    ret.push {pai: \8z, pos: \u, space: 0}
  ret

