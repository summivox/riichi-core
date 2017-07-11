require! {
  'chalk'
  'text-canvas': TextCanvas
  'esrever': {reverse}
  'fs-extra-promise': fs

  './kyoku': Kyoku
  './pai': Pai
}

PLATE_FRAME = """
  +----------------+
  |                |
  |                |
  +----------------+
  |                |
  |                |
  |                |
  +----------------+
"""

getWind = -> 'ESWN'[(it + 4) % 4]
FRIENDLY_PAI =
  \1z : 'EE'
  \2z : 'SS'
  \3z : 'WW'
  \4z : 'NN'
  \5z : 'PP'
  \6z : 'FF'
  \7z : 'CC'
getFriendlyPai = (pai) ->
  if FRIENDLY_PAI[pai] then that else pai.toString!

function buildStyle(attrs)
  open = ''
  close = ''
  for attr in attrs => with chalk.styles[attr]
    open = open + ..open
    close = ..close + close
  {open, close}

with chalk.styles
  styles =
    frameBorder: null
    frameContent: null
    frameContentDim: ..dim
    getPai: (pai) ->
      switch pai.S
      | 0 => buildStyle <[bold red]>
      | 1 => buildStyle <[bold cyan]>
      | 2 => buildStyle <[bold green]>
      | 3 => switch pai.N
        | 0, 1, 2, 3 => null # buildStyle <[bold gray]>
        | 4 => buildStyle <[bold white]>
        | 5 => buildStyle <[bold green]>
        | 6 => buildStyle <[bold red]>
    getPaiTsumokiri: (pai) ->
      switch pai.S
      | 0 => buildStyle <[red]>
      | 1 => buildStyle <[cyan]>
      | 2 => buildStyle <[green]>
      | 3 => switch pai.N
        | 0, 1, 2, 3 => buildStyle <[gray]>
        | 4 => buildStyle <[white]>
        | 5 => buildStyle <[green]>
        | 6 => buildStyle <[red]>

/*
# NOTE: defekt -- due to the way we paint style

# reverse a text block semi-smartly
# - keeps pai notation /\d[mpsz]/
# - reverses brackets and arrows ()[]{}<>^v
function rot180(src, padChar ? ' ')
  # NOTE: copied from text-canvas source
  # text block => array of lines
  # NOTE: EOL on the last line is stripped
  if typeof src is \string
    src .= split '\n'
    if src[*-1].trim!length == 0 then src.pop!

  # special: we need rows to be strings (for find and replace)
  if src.0.join then src .= map -> it.join ''

  # src bounding box
  srcWs = src.map (.length)
  srcW = Math.max ...srcWs
  srcH = src.length

  # flip it
  DICT =
    \( : \), \) : \), \[ : \], \] : \[
    \< : \>, \> : \<, \^ : \v, \v : \^
  for r from srcH - 1 to 0 by -1
    s = src[r]
      .replace /\d[mpsz]/g, -> it.1 + it.0
      .replace /[()\[\]{}<>\^v]/g, ->
        DICT[it]
    padChar.repeat(srcW - srcWs[r]) + reverse(s)
*/

module.exports = disp
function disp(kyoku, {
  color # Boolean
  me # 0/1/2/3 -- id of the player displayed at bottom
  sutehaiShowFuuro # Boolean -- leave the room of fuuro'd pai in sutehai area
} = {})
  color ?= chalk.enabled
  me ?= if kyoku.isReplicate then kyoku.me else 0
  sutehaiShowFuuro ?= false

  C = new TextCanvas 24, 80
  D = C.~draw

  {
    startState: {bakaze, chancha, honba}
    nTsumoLeft
    doraHyouji
    result: {kyoutaku, points}
    playerPublic
    playerHidden
  } = kyoku
  # central plate frame
  D PLATE_FRAME,
    top: 8, left: 31
    style: styles.frameBorder
  # overview row
  D "#{getWind bakaze}#{chancha + 1}.#{honba} $#{kyoutaku}k",
    top: 9, left: 32, right: 42, hMargin: 1
    style: styles.frameContent
  if nTsumoLeft < 10 then nTsumoLeft = '0' + nTsumoLeft.toString!
  D "[#nTsumoLeft]",
    top: 9, left: 43
    style: styles.frameContent
  # dora row
  for i til 5
    if doraHyouji[i]?
      D "#{getFriendlyPai that}",
        top: 10, left: 33 + i*3
        style: styles.getPai that
    else
      D '##',
        top: 10, left: 33 + i*3
        style: styles.frameContentDim

  # handle each player on canvas
  # d[rc]R: pai row offset vector on canvas
  # d[rc]C: pai col offset vector on canvas
  function drawSutehai(p, r0, c0, drR, dcR, drC, dcC)
    R = 0
    C = 0
    riichiState = 0
    for {pai, fuuroPlayer, tsumokiri, riichi} in kyoku.playerPublic[p].sutehai
      r = r0 + drR*R + drC*C
      c = c0 + dcR*R + dcC*C
      text = getFriendlyPai pai.toString!
      style = styles.getPai pai
      if fuuroPlayer?
        if not sutehaiShowFuuro then continue # NOTE: R/C remain unchanged
        text = "##" # TODO: use directional placeholder
        if riichi
          c -= 1
          text = "[#text]"
      if riichiState
        c -= 1
        text = "[#text]"
      if tsumokiri
        style = styles.getPaiTsumokiri pai

      D text, top: r, left: c, style: style

      if R < 2 and C == 5
        R++
        C = 0
      else
        C++

  # create sub-canvas of 1 fuuro
  function subFuuro(fuuro, i)
    p = (me + i)%4


  let p = (me + 0)%4
    # score block (TODO: wind on frame)
    D (getWind(p - chancha) + points[p]),
      top: 14, left: 32, right: 47, hAlign: \center
      style: styles.frameContent
    # sutehai
    drawSutehai p, 16, 31, +1, 0, 0, +3
  let p = (me + 1)%4
    D (points[p] + getWind(p - chancha)),
      top: 13, right: 47
      style: styles.frameContent
    drawSutehai p, 14, 50, 0, +3, -1, 0
  let p = (me + 2)%4
    D (points[p] + getWind(p - chancha)),
      top: 12, left: 32, right: 47, hAlign: \center
      style: styles.frameContent
    drawSutehai p, 7, 47, -1, 0, 0, -3
  let p = (me + 3)%4
    D (getWind(p - chancha) + points[p]),
      top: 13, left: 32
      style: styles.frameContent
    drawSutehai p, 9, 28, 0, -3, +1, 0



  console.log C.renderTerm!
#end function disp

k = Pai.cloneFix fs.readJsonSync 'test-canvas-3.json'
disp k, sutehaiShowFuuro: false

void
