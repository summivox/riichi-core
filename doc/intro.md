<!-- A Brutal and Swift Intro to Riichi Mahjong -->

# Foreword

Mahjong in general can be a confusing game to learn. While Riichi Mahjong features a relatively complex rule, it is one of the best-standardized variant thanks to its widespread adoption in competitive play. For new players, however, the fact that the primary sources for learning Riichi are mostly in Japanese, with Chinese closely following, makes learning difficult. Also, they are prone to getting confused by the details of the rules without a big picture. This document attempts to give a clear "crash course" introduction of Riichi assuming only basic knowledge of western playing cards.


# Stuff Used in the Game


## Tiles

Riichi is played with tiles, which are just cards in disguise. A deck consists of **4 identical copies** of 34 unique tile designs:

**3 regular "numeral" suites:**

  | suite | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
  |-------|---|---|---|---|---|---|---|---|---|
  | 萬子 {万子, manzu, m} | <img src="http://imgh.us/1m.svg" width="25"/> | <img src="http://imgh.us/2m.svg" width="25"/> | <img src="http://imgh.us/3m.svg" width="25"/> | <img src="http://imgh.us/4m.svg" width="25"/> | <img src="http://imgh.us/5m.svg" width="25"/> | <img src="http://imgh.us/6m.svg" width="25"/> | <img src="http://imgh.us/7m.svg" width="25"/> | <img src="http://imgh.us/8m.svg" width="25"/> | <img src="http://imgh.us/9m.svg" width="25"/> |
  | 筒子 {饼子, pinzu, p} | <img src="http://imgh.us/1p.svg" width="25"/> |<img src="http://imgh.us/2p.svg" width="25"/> | <img src="http://imgh.us/3p.svg" width="25"/> | <img src="http://imgh.us/4p.svg" width="25"/> | <img src="http://imgh.us/5p.svg" width="25"/> | <img src="http://imgh.us/6p.svg" width="25"/> | <img src="http://imgh.us/7p.svg" width="25"/> | <img src="http://imgh.us/8p.svg" width="25"/> | <img src="http://imgh.us/9p.svg" width="25"/> |
  | 索子 {souzu, s} | <img src="http://imgh.us/1s.svg" width="25"/> | <img src="http://imgh.us/2s.svg" width="25"/> | <img src="http://imgh.us/3s.svg" width="25"/> | <img src="http://imgh.us/4s.svg" width="25"/> | <img src="http://imgh.us/5s.svg" width="25"/> | <img src="http://imgh.us/6s.svg" width="25"/> | <img src="http://imgh.us/7s.svg" width="25"/> | <img src="http://imgh.us/8s.svg" width="25"/> | <img src="http://imgh.us/9s.svg" width="25"/> |

**4 winds:**

  | East | South | West | North |
  |:-:|:-:|:-:|:-:|
  | <img src="http://imgh.us/1z.svg" width="25"/> | <img src="http://imgh.us/2z.svg" width="25"/> | <img src="http://imgh.us/3z.svg" width="25"/> | <img src="http://imgh.us/4z.svg" width="25"/> |

**3 honors:**

  | Blank | Green | Red |
  |:-:|:-:|:-:|
  | <img src="http://imgh.us/5z.svg" width="25"/> | <img src="http://imgh.us/6z.svg" width="25"/> | <img src="http://imgh.us/7z_1.svg" width="25"/> |


There are therefore ((3 \* 9 + 4 + 3) \* 4 = 34 \* 4 = 136 tiles in a Riichi deck.


## Points and Chips

Each player holds some points, represented physically by chips. Points are in increments of 100. The chips look like:

![](http://imgh.us/tenbou.png)

From left to right: 10,000 points; 5,000 points; 1,000 points; 100 points. Usually all players start with 25,000 points, represented by exactly the chips in above picture (10,000 x 1 + 5,000 x 2 + 1,000 x 4 + 100 x 10 = 25,000).



# The First Walk-through

In this section we will go through a part of a game step by step and explain the concepts along the way. While there are some real-life photos, most pictures will be screenshots of online Riichi Mahjong games designed to resemble a real Riichi Mahjong table.


## Preparation

1. 4 players sit at 4 edges of a square table.
   ![](http://vignette1.wikia.nocookie.net/zh.uncyclopedia/images/4/43/%E7%8B%97%E6%89%93%E9%BA%BB%E5%B0%86.jpg/revision/latest?cb=201008271311200)
   Cute dogs aside, let's assume the players are named Alice, Bob, Charlie, and Dave, seated in this way:
	```c
	          Charlie
	
	      +-------------+
	      |             |
	      |             |
	      |             |
	Dave  |             |  Bob
	      |             |
	      |             |
	      |             |
	      +-------------+
	
	           Alice
	```
   The natural turn order of the players is *counter-clockwise*, meaning that **your "next" player sits to your right**, and your "previous" player sits to your left. Basically Bob's turn follows Alice's, Charlie's after Bob's, etc.
    In every round, each player is associated with a wind tile called 自風 {jikaze}, literally "self wind". **The dealer {庄家, chancha} of the round is always East.** His next player becomes South, opposite player West, and the last player North. Note that this assignment is a mirror-image of real-life. [This is intentional due to historical/cultural reasons.][wind-mirror] Assuming Alice is the dealer of the first round, then we have:
	```c
	          Charlie
	
	      +-------------+
	      |    West     |
	      |             |
	      |             |
	Dave  |North   South|  Bob
	      |             |
	      |             |
	      |    East     |
	      +-------------+
	
	           Alice
	```
   
   [wind-mirror]: https://ja.wikipedia.org/wiki/%E9%BA%BB%E9%9B%80%E3%81%AE%E3%83%AB%E3%83%BC%E3%83%AB#.E3.83.97.E3.83.AC.E3.82.A4.E3.83.A4.E3.83.BC

2. Shuffle the deck on the table. Then line them up into a square wall with 17 stacks of 2 tiles on each of the 4 sides, face down.
   ![](http://imgh.us/19300001208974134371919914507.jpg)
   Automatic-shuffling tables like this can do all this chore for you and guarantees randomness.
3. Break the wall at a random location --- this turns the "O"-shaped wall into a "C". Tiles clockwise to the breaking point (lower end of the "C") are referred to as the *head* of the wall, and those counter-clockwise to the breaking point (upper end of the "C") the *tail*.
   ![](http://imgh.us/Haipai2Btumo.png)
   Players' initial hands are **dealt from the head (i.e. clockwise from the breaking point)** in the following way:
   1. Repeat 3 times: each player draws 4 tiles (2 stacks), starting from the dealer.
   2. Each player then draws 1 tile. Now everyone should have 13 closed tiles (visible only to the player holding them) in hand.
4. Set aside 7 stacks at the *tail* of the wall as "dead wall" {王牌, wanpai}, and reveal (turn face-up) the top tile of the 3rd stack from tail. This group of tiles serve a special purpose and are set aside from the rest of the wall. We will cover their purpose later.
   ![](https://upload.wikimedia.org/wikipedia/commons/f/f3/Dora_and_Wanpai.jpg)
   NOTE: the top tile of the 1st stack from tail is usually displaced as shown in above photo to make it easier to tell the tail from the head.

## Start

The dealer (Alice) takes the first turn in a round.

1. Alice draws a tile (from the head of the wall). Alice now has 14 closed tiles in her hand and is ready to play. In general, when it is a player's turn, he has (3n + 2) closed tiles in hand; otherwise he has (3n + 1).
2. She chooses a tile from her hand and discards it onto the table, in hope that this exchange brings her hand closer to matching one of the winning patterns. After this, she holds 13 closed tiles again.
3. After a short wait (we will see why later), the next player (Bob) draws a tile (again from the head of the wall). He now has 14 closed tiles.
4. (Bob takes action, rinse and repeat...)

While discarding a tile is the most common action taken after drawing a tile, it is not the only one. Also, after a discard, other players might be able to *interrupt* the normal game flow. The following sections introduce what these actions are and when they can be taken.


## Actions: my own turn




## Actions: someone else's turn







# Defekt



## Overview

Riichi {リーチ, 立直} Mahjong {麻雀, 麻将} is a multi-player (usually 4) card game. Instead of cards, tiles {牌, pai} are used. The goal of each player is to **assemble his hand into a winning pattern before everyone else** (Agari {和了, Houra}).


 A game consists of a number of independent rounds {局, kyoku}. In each round, players take turns to draw a tile then discard a tile.  After a player discards a tile, other players may have a chance to "steal" this tile either for completing a winning hand (Ron {ロン, 荣，荣和}), or for completing a part of his hand towards a winning one (Fuuro {副露}).