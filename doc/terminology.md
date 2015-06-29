# Introduction

There are many equivalent yet confusing ways to refer to the same thing in the Riichi Mahjong game: Japanese Katakana/Romaji/Kanji with both Chinese-inspired and native pronunciations, Chinese (Traditional), and various English terms of Japanese and Chinese origin. On top of this, we wish to have shorthands compatible with [Tenhou notations][tenhou2] to be used in API, even as internal representation. Additionally, this project follows the [Robustness Principle][robust], which means the API should be tolerant in what it accepts. All these call for a consistent terminology system.

[robust]: https://en.wikipedia.org/wiki/Robustness_principle
[tenhou2]: http://tenhou.net/2/

This document lists all canonical terms (bold) and shorthands (in code blocks) adopted in this project, as well as their commonly-used equivalent terms and shorthands (in curly braces).

The main policy for choosing canonical term:
*   Prefer original Japanese term (from Wikipedia) written in full Romaji
*   Allow convenience shorthands as long as they do not cause ambiguity

# General

*   __Pai__ {牌, hai, tile}
    *   __Tehai__ {手牌, hand}
        *   __Juntehai__ {純手牌, concealed part of hand}
    *   __Dora__ {ドラ, bonus tile}
        *   __Ura~__ {裏ドラ, hidden dora}
        *   __Kan~__ {槓ドラ, dora revealed by quad}
        *   __~Hyoujihai__ {ドラ表示牌, dora indicator}
    *   __Tsumo__ {自摸, self draw (tile)}
    *   __Dahai__ {打牌, discard (tile)}
*   __Toitsu__ {対子, pair}
    *   __Jantou__ {雀頭, pair in normal winning hand}
*   __Mentsu__ {面子, meld}
    *   __Shuntsu__ {順子, run}
    *   __Koutsu__ {刻子, triplet}
        *   __Minko__ {明刻, open triplet}
        *   __Anko__ {暗刻, concealed triplet}
    *   __Kantsu__ {槓子, quad}
        *   __Minkan__ {明槓, open quad}
        *   __Ankan__ {暗槓, concealed quad}
*   __Fuuro__ {副露, open meld}
    *   __Chii__ {吃, チー, make run}
    *   __Pon__ {碰, ポン, make triplet}
    *   __Kan__ {槓, カン, make quad}
        *   __Daiminkan__ {大明槓, (make) open quad}
        *   __Kakan__ {加槓, (make) added open quad}
        *   __Ankan__ {暗槓, (make) concealed quad}
*   __Menzen__ {門前, fully concealed hand}
*   __Tenpai__ {聴牌, ready, waiting}
    *   __Keishiki~__ {形式聴牌, ready (only in form)}
    *   __Karaten__ {空聴, hopeless ready}
    *   __Furiten__ {振聴, sacred discard}
*   __Agari__ {和了, houra, win}
    *   __Tsumo__ {自摸和, win on self draw}
    *   __Ron__ {栄和, ロン, win on discard/meld}
    *   __Hyoujunkei__ {標準形, standard form}
    *   __Chiitoitsu__ {七対子, seven pairs}
    *   __Kokushimusou__ {国士無双, thirteen orphans}
*   __Yama__ {山, 牌山, 壁牌, (live) wall}
*   __Wanpai__ {王牌, dead wall}
*   __Kawa__ {河, ホー, river, discard zone}


## Pai

Main hierarchy:
*   `/[0-9][mps]/` __Shuupai__ {数牌, suupai, numerals, suites}
    *   `/[0-9]m/` __Manzu__ {萬子, man, characters}
    *   `/[0-9]p/` __Pinzu__ {筒子, pin, cookies, dots, circles}
    *   `/[0-9]s/` __Souzu__ {索子, sou, bamboos, bars}
    *   `/0[mps]/` __Akahai__ {赤牌, 赤ドラ, akadora} : denotes red 5 of the same suite
    *   `/[02-8][mps]/` __Chunchanpai__ {中張牌, non-terminals}
    *   `/[19][mps]/` __Raotoupai__ {老頭牌, routouhai, terminals}
*   `/[1-7]z|[ESWNBGRPFCDHT]/` __Tsuupai__ {字牌, jihai, honors}
    *   `/[1-4z]|[ESWN]/` __Fonpai__ {風牌, kazehai, winds}
        *   `/1z|E/` __Ton__ {東, higashi, east}
        *   `/2z|S/` __Nan__ {南, minami, south}
        *   `/3z|W/` __Shaa__ {西, nishi, west}
        *   `/4z|N/` __Peii__ {北, kita, north}
        *   __Chanfonpai__ {圏/荘/場風牌, bakazehai, prevailing/round wind}
        *   __Menfonpai__ {門/自風牌, jikazehai, seat wind}
    *   `/[5-7]z|[BGRPFCDHTZ]/` __Sangenpai__ {三元牌, dragons}
        *   `/5z|[BPD]/` __Haku__ {白板, paipan, white, blue, frame}
        *   `/6z|[GFH]/` __Hatsu__ {緑發, green}
        *   `/7z|[RCTZ]/` __Chun__ {紅中, red}

Other categories:
*   `/[19][mps]|[1-7]z/` __Yaochuupai__ {么九牌, 幺九牌, terminals and honors}

Note:
*   `/[1-7]z/` are the canonical shorthands; `/[ESWNBGRPFCDHT]/` (single capitals) are permitted alternative shorthands.

# References

*   https://ja.wikipedia.org/wiki/麻雀
*   https://ja.wikipedia.org/wiki/麻雀牌
*   https://ja.wikipedia.org/wiki/麻雀のルール
*   https://ja.wikipedia.org/wiki/手牌
*   https://ja.wikipedia.org/wiki/面子
*   https://ja.wikipedia.org/wiki/副露
*   https://ja.wikipedia.org/wiki/槓
*   https://ja.wikipedia.org/wiki/聴牌
*   https://ja.wikipedia.org/wiki/麻雀用語一覧
*   https://en.wikipedia.org/wiki/Mahjong_tiles
