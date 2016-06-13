# TL;DR Example

In [LiveScript][] (note: not idiomatic for resemblence to JS):

```livescript
{Pai, Kyoku, Event} = require 'riichi-core'
kyoku = new Kyoku # creates a new game with default rules
kyoku.on 'event', (event) -> console.log JSON.stringify event # logs all executed events to console
kyoku.deal! # start it by shuffling the wall and dealing the initial hand
kyoku.begin! # start 1st player's turn -- a tile is drawn from the wall
kyoku.exec new Event.dahai kyoku, tsumokiri: true # 1st player chooses to discard the tile he just drew
kyoku.exec new Event.declare kyoku, what: 'chi', args: {dir: -1} # which is called for meld by the 2nd player (NOTE: will throw if rule does not allow him, which is likely to happen due to randomly generated wall)
/* ... */
```

Compiled to Javascript:

```javascript
var ref$, Pai, Kyoku, Event, kyoku;
ref$ = require('riichi-core'), Pai = ref$.Pai, Kyoku = ref$.Kyoku, Event = ref$.Event;
kyoku = new Kyoku;
kyoku.on('event', function(it){
  return console.log(JSON.stringify(it));
});
kyoku.deal();
kyoku.begin();
kyoku.exec(new Event.dahai(kyoku, {
  tsumokiri: true
}));
kyoku.exec(new Event.declare(kyoku, {
  what: 'chi',
  args: {
    dir: -1
  }
}));
/* ... */
```

[LiveScript]: http://livescript.net/

# Motivation

* Riichi Mahjong is predominantly played offline (on table) in Japan, and online on sites offering only Japanese UI. Most reference material (e.g. on rules) are in Japanese.
* While open-source implementations of riichi mahjong exists, what I found are all rigidly coupled to a particular UI, not a generic library
* There lacks a publicly available algorithmic description of standard Riichi Mahjong, let alone implementation.

# The Game

See (TBD) for a brutal-and-swift introduction to the game with references to its implementation in this library.

# Library API

`require('riichi-core')` returns the following sub-modules in an object:

* Game logic:
 	* `Pai`: Mahjong tile objects and related helper functions
	* `Kyoku`: main game engine class
	* `Event`: events/action classes
	* `rule`: default rules (see [`src/rulevar-default.ls`](../src/rulevar-default.ls) )
* Utilities:
	* `decomp`: functions that attempt to decompose a hand into building blocks according to rules
	* `util`: misc helper functions