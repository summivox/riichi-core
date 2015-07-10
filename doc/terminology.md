# Introduction

There are many equivalent yet confusing ways to refer to the same thing in the Riichi Mahjong game: Japanese Katakana/Romaji/Kanji with both Chinese-inspired and native pronunciations, Chinese (Traditional), and various English terms of Japanese and Chinese origin. On top of this, we wish to have shorthands compatible with [Tenhou notations][tenhou2] to be used in API, even as internal representation. Additionally, this project follows the [Robustness Principle][robust], which means the API should be tolerant in what it accepts. All these call for a consistent terminology system.

[robust]: https://en.wikipedia.org/wiki/Robustness_principle
[tenhou2]: http://tenhou.net/2/

This document lists all canonical terms (bold) and shorthands (in code blocks) adopted in this project, as well as their commonly-used equivalent terms and shorthands (in curly braces).

The main policy for _naming things_:
*   Prefer Japanese terms (from Wikipedia) with Chinese-inspired pronunciation written in [Hepburn Romaji][romaji]
*   Unless as a part of another (compound) term (usually also listed here or in references), Romaji words are either not inflected, or inflected like other foreign words **in English**. Basically these terms can be treated verbatim (modulo case, see below). This avoids needless confusion and simplifies code searching.
*   `camelCase`, `CamelCase`, and `ALL_CAPS` also apply to Romaji words (e.g. `uraDoraHyoujihai`)
*   English-derived Japanese is usually written in original English
*   Allow convenience shorthands as long as they do not introduce ambiguity

[romaji]: https://en.wikipedia.org/wiki/Hepburn_romanization

**Big hint: "pai" == "hai"**. This pair is a particularly common one, considering that the entire game is about them!

> There are two hard things in computer science: cache invalidation, naming things, and off-by-one errors.  &nbsp;&nbsp;&nbsp;  _ -- Phil Karlton_


# General

*   __Pai/Hai__ {牌, tile}
    *   __Tehai__ {手牌, hand}
        *   __Juntehai__ {純手牌, concealed part of hand}
    *   __Dora__ {ドラ, bonus tile}
        *   __Omo(te)~__ {表ドラ, revealed dora}
        *   __Ura~__ {裏ドラ, hidden dora}
        *   __Kan~__ {槓ドラ, dora revealed by quad}
        *   __~Hyoujihai__ {ドラ表示牌, dora indicator}
        *   __Moto~__ {元ドラ, original dora/indicator}
*   __Toitsu__ {対子, pair}
    *   __Jantou__ {雀頭, pair in normal winning hand}
    *   __Tanki__ {単騎, single tile wait (for jantou)}
*   __Mentsu__ {面子, meld}
    *   __Shuntsu__ {順子, run}
    *   __Koutsu__ {刻子, triplet}
        *   __Minko__ {明刻, open triplet}
        *   __Anko__ {暗刻, concealed triplet}
    *   __Kantsu__ {槓子, quad}
        *   __Minkan__ {明槓, open quad}
        *   __Ankan__ {暗槓, concealed quad}
*   __Menzen__ {門前, fully concealed hand}
*   __Yama__ {山, 牌山, yama, wall}
    *   __Piipai__ {壁牌, (live) wall}
    *   __Wanpai__ {王牌, dead wall}
*   __Hou__ {河, kawa, river, discard zone}


## Pai Categories

Main hierarchy:
*   `/[0-9][mps]/` __Shuupai__ {数牌, suupai, numerals, suites}
    *   `/[0-9]m/` __Manzu__ {萬子, man, characters}
    *   `/[0-9]p/` __Pinzu__ {筒子, pin, cookies, dots, circles}
    *   `/[0-9]s/` __Souzu__ {索子, sou, bamboos, bars}
    *   `/0[mps]/` __Akahai__ {赤牌, 赤ドラ, akadora} : denotes red 5 of the same suite
    *   `/[02-8][mps]/` __Chunchanpai__ {中張牌, non-terminals}
    *   `/[19][mps]/` __Raotoupai__ {老頭牌, routouhai, terminals}
*   `/[1-7]z|[ESWNBGRPFCZ]/` __Tsuupai__ {字牌, jihai, honors}
    *   `/[1-4z]|[ESWN]/` __Fonpai__ {風牌, kazehai, winds}
        *   `/1z|E/` __Ton__ {東, higashi, east}
        *   `/2z|S/` __Nan__ {南, minami, south}
        *   `/3z|W/` __Shaa__ {西, nishi, west}
        *   `/4z|N/` __Pei__ {北, kita, north}
        *   __Bakazehai__ {圏/荘/場風牌, chanfonpai, prevailing/round wind}
        *   __Jikazehai__ {門/自風牌, menfonpai, seat wind}
    *   `/[5-7]z|[BGRPFCZ]/` __Sangenpai__ {三元牌, dragons}
        *   `/5z|[BP]/` __Haku__ {白板, パイパン, white, blank, blue, frame}
        *   `/6z|[GF]/` __Hatsu__ {緑發, リューファ, green}
        *   `/7z|[RCZ]/` __Chun__ {紅中, ホンチュン, red}

Other categories:
*   `/[19][mps]|[1-7]z/` __Yaochuupai__ {么九牌, 幺九牌, terminals and honors}

Note:
*   `/[1-7]z/` are the canonical shorthands; `/[ESWNBGRPFCDHT]/` (single capitals) are permitted alternative shorthands.


## Game Organization

*   __Player__ {プレイヤー}
    *   __\[Ton/Nan/Shaa/Pei\]cha__ {\[東/南/西/北\]家, E/S/W/N}
    *   __Chancha__ {荘家, 親, oya, dealer} == __Toncha__ {east}
    *   __Sancha__ {散家, 子, ko}
    *   `player 0` __Chiicha__ {起家, first dealer}
    *   __Taacha__ {他家, other players}
        *   `prev` __Kamicha__ {上家, player to your left (previous)}
        *   `next` __Shimocha__ {下家, player to your right (next)}
        *   `oppo` __Toimen__ {対面, player opposite to you}
*   __Kyoku__ {局, round}
    *   __[Ton/Nan]Ba__ {[東/南]場, east/south stage}
    *   __Renchan__ {連荘, bonus hand, dealer hold}
        *   __Honba__ {本場, # of renchan}
    *   __Ryoukyoku__ {流局, aborative draw}


## Game Flow

*   __Tsumo__ {自摸, (to) self draw (tile)}
    *   __TsumoPai__ {自摸牌, tile drawn}
*   __Dahai__ {打牌, (to) discard tile}
    *   __Sutehai__ {捨て牌, discarded tile}
    *   __Tsumokiri__ {自摸切り, ツモ切り, (to) discard self draw tile}
*   __Fuuro__ {副露, 鳴く, 喰う, (make/declare) open meld}
    *   __Chii__ {吃, チー, (to) declare open run}
        *   __Kuikae__ {喰い替え, swap call}
    *   __Pon__ {碰, ポン, (to) declare open triplet}
    *   __Kan__ {槓, カン, (to) declare open quad}
        *   __Daiminkan__ {大明槓, (to declare) open quad}
        *   __Kakan__ {加槓, (to declare) added open quad}
        *   __Ankan__ {暗槓, (to declare) concealed quad}
*   __Tenpai__ {聴牌, ready, waiting hand}
    *   __Keiten__ {形聴, 形式聴牌, ready only in form}
    *   __Karaten__ {空聴, void ready}
    *   __Furiten__ {振聴, sacred discard}
        *   __Sutehai~__ {捨て牌(による)振聴, ~ due to discard, permanent ~}
        *   __Doujun~__ {同巡(内)振聴, temporary ~}
        *   __Riichi~__ {リーチ(後の)フリテン, ~ after riichi}
*   __Agari__ {和了, houra, win}
    *   `TSUMO_AGARI` __Tsumo~__ {自摸(和), ツモ, (to) win on self draw}
    *   `RON` __Ron~__ {栄(和), ロン, (to) win on discard/meld}
        *   __Houjuu__ {放銃, 振り込む, (to) play into someone's hand/ron}


## Point/Score/Value ...

Japanese terms regarding "point"-related concepts are potentially confusing especially when used in an English context: "Ten", "Tensuu", "Tenbou", "Tokuten", "Kihonten"... We use as few as possible while replacing some with equivalent yet easily-understood English terms:

*   __Points__ {点}: total value of chips {点棒, tenbou, "point sticks"} in a player's possession; a non-negative number divisible by 100
    *   __Basic Points__ {基本点, kihonten}: value associated with a winning hand itself
    *   __Distribution__ {負担額, fudangaku}: how many points each player should "pay" to the winning player; calculated from basic points
*   `delta`: final change of points after one kyoku of game (i.e. \[points at end\] - \[points at start\])
*   __Kyoutaku__ {供託, riichi bet}: total value of chips set aside on the table as bet from accepted riichi. A player who wins shall take all kyoutaku currently on table.

*   __Han__ {飜}
*   __Fu__ {符, mini-points}
*   __Yaku__ {役}


*   __Hourakei__ {和了形, form of winning hand}
    *   __Hyoujunkei__ {標準形, standard form}
    *   `7`, `chiitoi` __Chiitoitsu__ {七対子, seven pairs}
    *   `k`, `kokushi` __Kokushimusou__ {国士無双, thirteen orphans}

## Misc Concepts

*   __True First Tsumo__ {純粋な初巡+第1ツモ}


# References

*   https://ja.wikipedia.org/wiki/麻雀
*   https://ja.wikipedia.org/wiki/麻雀牌
*   https://ja.wikipedia.org/wiki/麻雀のルール
*   https://ja.wikipedia.org/wiki/手牌
*   https://ja.wikipedia.org/wiki/面子
*   https://ja.wikipedia.org/wiki/副露
*   https://ja.wikipedia.org/wiki/槓
*   https://ja.wikipedia.org/wiki/聴牌
*   https://ja.wikipedia.org/wiki/振聴
*   https://ja.wikipedia.org/wiki/麻雀用語一覧
*   https://ja.wikipedia.org/wiki/連荘
*   https://ja.wikipedia.org/wiki/流局
*   https://en.wikipedia.org/wiki/Mahjong_tiles
