# TL;DR Example

In [LiveScript][] (note: not idiomatic for resemblence to JS):

```livescript
{Pai, Kyoku, Event} = require 'riichi-core'
kyoku = new Kyoku # creates a new game with default rules
kyoku.on 'event', (event) -> console.log JSON.stringify event # logs all executed events to console
kyoku.deal! # start it by shuffling the wall and dealing the initial hand
kyoku.go! # start 1st player's turn -- a tile is drawn from the wall
kyoku.exec new Event.dahai kyoku, tsumokiri: true # 1st player chooses to discard the tile he just drew...
kyoku.exec new Event.declare kyoku, what: 'chi', args: {dir: -1} # ...which is called for meld by the 2nd player (NOTE: will throw if rule does not allow him, which is likely to happen due to randomly generated wall)
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
kyoku.go();
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
* While open-source implementations of riichi mahjong exist, what I found are all rigidly coupled to a particular UI, not a generic library.
* There lacks a publicly available _algorithmic description_ of standard Riichi Mahjong, let alone implementation.
* Pure javascript (i.e. both nodejs and browser) enables isomorphic applications and reduces repetitive code.


# Architecture

## Game Overview

Riichi Mahjong is a card game. More specifically, a turn-based deterministic multi-player imperfect-information game. A game involves 4 players and consists of a number of [[kyoku]]s. The initial conditions of a [[kyoku]] is sufficiently determined by `{bakaze, chancha, honba, points}`, where `points` is a numerical score for each player. A [[kyoku]] begins with shuffle/deal, and ends with a potential change to the points of the players. The outcome of a [[kyoku]] sufficiently  determines (according to the specific rule used) whether the game should end, or another [[kyoku]] should be played; in the latter case, the initial conditions of the next [[kyoku]] is also determined.

## Representation

<figure>
<img src="http://i.imgur.com/iEYMumv.png" />
<figcaption>Example of game progression</figcaption>
</figure>

`class Kyoku` encapsulates a [[kyoku]]. It follows the **event-sourcing** pattern due to the deterministic turn-based nature of the game: applying a event to one game state results in the next game state; applying each event in temporal/causal order on the initial state (determined by `{bakaze, chancha, honba, points}`) gives the game state at each step. Figure above illustrates a part of a possible game progression. Each "node" in the figure indicates the game state at a timestep.


## Client-Server

This library is designed around a client-server model; it implements both client and server functionalities. All 4 clients (players) communicate with a single server, which maintains a `Kyoku` instance that serves as the **single source of truth**. This instance is called the "master". Each client may keep its own `Kyoku` instance, called a "replicate", which can be synchronized with the master by applying events from the master.

<figure>
<img src="http://i.imgur.com/j2NjfY7.png" />
<figcaption>Client-server model</figcaption>
</figure>

Information invisible to each player is filtered out when passing the event from master to a replicate.


## Finite State Machine

<figure>
<img src="http://i.imgur.com/QiAucLo.png)" />
<figcaption>The kyoku state machine (`Kyoku#phase`)</figcaption>
</figure>

NOTE: In this library, "state" refers to the state of the whole game (i.e. everything in a master `Kyoku` instance) while "phase" refers to only the explicit state-machine part.

The game flow (within a [[kyoku]]) is encoded as a [finite state machine (FSM)][FSM] shown in above diagram. The states are named intuitively:

- `begin`: initial state
- `preTsumo`: before a player's normal turn to [[tsumo]]
- `postTsumo`: after a player finishes [[tsumo]]
- `postDahai`: after a player's [[dahai]], awaiting declarations on his [[sutehai]]
- `postChiPon`: after declaration resolves to [[chi]] or [[pon]] by another player, who must [[dahai]] immediately (different from `postTsumo`)
- `postAnkan`, `postKakan`: after [[ankan]] or [[kakan]], awaiting ron declarations ([[chankan]] rule)

[FSM]: https://en.wikipedia.org/wiki/Finite-state_machine
[DFA]: https://en.wikipedia.org/wiki/Deterministic_finite_automaton

## Events

Events directly encode the main game logic. They are the transitions of the FSM (with one exception, see below). There are 3 types of events: master, own-turn, and declared. The following sections discuss the details of them.

### Master Events

Master events are marked as blue arrows in the FSM diagram. They represent the only valid changes that take place given the following phases:

- at `begin`: `deal` is always the initial event. It shuffles, builds the wall, then deals the initial hand to all players.
- at `preTsumo`: two possible outcomes
	- If tochuu-`ryoukyoku` or `howanpai` conditions are satisfied, then the kyoku must end in corresponding result.
	- Otherwise, current player does `tsumo` and proceeds to his own turn.

`deal` is generated by `Kyoku#deal`, while the `preTsumo` logic is handled by `Kyoku#go`.


### Own-turn Events

Own-turn events are marked as red arrows in the FSM diagram. They represent a player's move in his own turn (after {{tsumo}}) and have straightforward semantics.

- `dahai{pai, tsumokiri, riichi}`: includes [[riichi]] declaration. Note that this is *not* considered a "declared event" (see below) as it can be considered as a part of regular [[dahai]] and is done in player's own turn.
- `ankan{pai}`, `kakan{pai}`
- `tsumoAgari`
- `kyuushuuKyuuhai`: "9-9" in diagram. Note that this is the only way of forcing a [[ryoukyoku]] by a player directly in his own turn.


### Declared Events

`chi`, `pon`, `daiminkan`, and `ron` are all events originating from a player other than current on his action. They are marked as green arrows in the FSM diagram. In real life, they must be verbally declared before taking place. In the case multiple declarations are made at the same timestep, only one type will take place according to the following priority: `ron` > `daiminkan` = `pon` > `chi`. Additionally, multiple `ron` declarations may all come into effect or even end in `ryoukyoku` according to rule variations.

This game mechanics is implemented as a two-step process:

1. In a declaration-pending phase (`postDahai`, `postKakan`, `postAnkan`), declarations are wrapped in a special `declare` event, execution of which registers it to `Kyoku#currDecl`.
2. When all declarations have been registered, `Kyoku#resolve` is called. It determines which declarations are valid and applies the actual event (e.g. `chi`).

If no declarations are active, a default/placeholder event `nextTurn` is applied instead using the same mechanism to advance the game into next turn (same player in case of {{kan}}, next player otherwise).


## Cross Concerns

### (need a title for didNotHoujuu)

All declared events except for `ron` call `Kyoku#_didNotHoujuu` when applied, shown as `**` in the FSM diagram. This routine handles the common codepath that updates the following conditions flags:

- [[riichi]] acception: `PlayerPublic#riichi.accepted`
- [[riichi]] [[ippatsu]]: `PlayerPublic#riichi.ippatsu`
- first uninterrupted [[tsumo]] round: `Kyoku#virgin`
- [[furiten]]: `PlayerHidden#furiten`

While these flags might seem disjoint and unrelated, they share one thing in common: they are all conditioned on "player finished action without causing [[ron]]". This is reflected in the name of the method ([[houjuu]] == to cause a [[ron]]).

### Dora-hyoujihai revealing

(TBD)1



# API Reference

(work in progress)

`require('riichi-core')` returns the following sub-modules in an object:

* Game logic:
 	* `Pai`: Mahjong tile objects and related helper functions
	* `Kyoku`: main game engine class
	* `Event`: events/action classes
	* `rule`: default rules (see [`src/rulevar-default.ls`](../src/rulevar-default.ls) )
* Utilities:
	* `decomp`: functions that attempt to decompose a hand into building blocks according to rules
	* `util`: misc helper functions