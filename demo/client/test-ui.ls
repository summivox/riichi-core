# game

require! {
  './util': {b64_to_utf8}
  './conf': {SERVER, PREFIX}
  './ui': ui
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

fuuroTest =
  * type: [\SHUNTSU], ownPai: <[4m 6m]>
    otherPai: \0m, otherPlayer: 1
  * type: [\MINKO], ownPai: <[6z 6z]>
    otherPai: \6z, otherPlayer: 0
  * type: [\KAKAN], ownPai: <[1s 1s]>
    otherPai: \9z, kakanPai: \1s, otherPlayer: 3
  * type: [\ANKAN], ownPai: <[2m 2m 2m 2m]>

sutehaiTest = 
  * pai: \1m, tsumokiri: true
  * pai: \2s, riichi: true
  * pai: \3p
  * pai: \4z, fuuroPlayer: 3
  * pai: \0m
  * pai: \6p
  * pai: \7s
  * pai: \1s
  * pai: \2s
  * pai: \3s
  * pai: \4s
  * pai: \5s
  * pai: \6s
  * pai: \7s
  * pai: \8s
  * pai: \7p, riichi: true
  * pai: \9s
  * pai: \1p
  * pai: \2p
  * pai: \3p
  * pai: \4p
  * pai: \0p

juntehaiTest = <[ 1m 3m 1p 5p 6p 8p 8p 9p 9p 2s 3s 0s 7z ]> #

$render do
  $\g {},
    $new(ui.PaiRow, {
      x: 11.5, y: 11.5, list: ui.rowFromFuuro(fuuroTest, 2), right: true
    })
    $new(ui.PaiRow, {
      x: -8, y: 11.5, list: ui.rowFromJuntehai([\2s], \1m), right: false
    })
  qS \#pp0
$render do
  $\g {},
    $new(ui.Sutehai, {
      x: -3, y: +3, sutehai: sutehaiTest
      maxCol: 6, maxRow: 3
    })
    $new(ui.PaiRow, {
      x: -8, y: 11.5, list: ui.rowBack(13, 1), right: false
    })
  qS \#pp1
$render do
  $\g {},
    $new(ui.PaiRow, {
      x: -8, y: 11.5, list: ui.rowFromJuntehai(juntehaiTest, null), right: false
    })
  qS \#pp2
