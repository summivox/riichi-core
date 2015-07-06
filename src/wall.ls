# wall splitting and dealing
#
#                          _______________      ______________
#                         <--- TAIL (CCW) |    / HEAD (CW) --->
#      piipai |  dora hyoujihai   |rinshan|   |            haipai {deal}            | piipai
#      118 120|122 124 126 128 130|132 134|   | 0   2   4   6   8  10        48  50 |52  54
# ... +---+---*---+---+---+---+###*---+---+   +---+---+---+---+---+---+ ... +---+---*---+---+ ...
#     |#66|#68| D4| D3| D2| D1| D0|RS2|RS0|   |E0 |E2 |S0 |S2 |W0 |W2 |     |E12|W12|#00|#02|      TOP
# ... +===+===*===+===+===+===+===*===+===+   +===+===+===+===+===+===+ ... +===+===*===+===+ ...
#     |#67|#69|UD4|UD3|UD2|UD1|UD0|RS3|RS1|   |E1 |E3 |S1 |S3 |W1 |W3 |     |S12|N12|#01|#03|      BOTTOM
# ... +---+---*---+---+---+---+---*---+---+   +---+---+---+---+---+---+ ... +---+---*---+---+ ...
#      119 121|123 125 127 129 131|133 135|   | 1   3   5   7   9  11        49  51 |53  55
#      piipai | uradora-hyoujihai |rinshan|   |            haipai {deal}            | piipai
#
#
# table-top common practice:
# 1.  Shuffle: 136 pai {tiles} => 4 sides * 17 stacks * 2 pai per stack
# 2.  Throw dice to decide spliting point on the wall (rule varies on this).
# 3.  From splitting point: clockwise => head, counterclockwise => tail
# 4.  Flip top of 3rd stack from tail => dora hyoujihai {indicator}
#     (figure: `###`)
# 5.  Deal: take turns (E->S->W->N->E->...) to take 2 stacks (4*pai) from head
#     until everyone has 12; then each player draws a single pai.
#     (figure: E0~E3 ; S0~S3 ; ... ; W8~W11 ; N8~N11 ; E12 ; S12 ; W12 ; N12)
# 6.  Chancha takes his tsumopai and game starts
#     (figure: "#00" => 1st piipai)
# 7.  Rinshan-tsumo after kan is taken from the tail, counterclockwise
#     (figure: RS0, RS1, RS2, RS3)
# 8.  Kan-dora hyoujihai(s) are flipped counterclockwise from the original dora
#     hyoujihai (figure: D1, D2, D3, D4)
#
# implementation in this project:
# 1.  Assuming wall is split: label the pai top-bottom then clockwise from head
#     (figure: 0, 1, 2, ..., 133, 134, 135 on top/bottom)
# 2.  haipai: first 13*4 tiles from wall
# 3.  piipai/rinshan: Since `.pop()` is used to "draw" a tile (for efficiency),
#     both arrays are reversed. In figure:
#     -   piipai: [#69, #68, ..., #01, #00]
#     -   rinshan: [RS3, RS2, RS1, RS0]
# 4.  doraHyouji/uraDoraHyouji:
#     [0] => original (ura-)dora hyoujihai {motodora}
#     [1] => 1st (ura-)kan-dora hyoujihai
#     [2] => 2nd ...

module.exports = (w) ->
  haipai =
    w[0x00 0x01 0x02 0x03, 0x10 0x11 0x12 0x13, 0x20 0x21 0x22 0x23, 0x30]
    w[0x04 0x05 0x06 0x07, 0x14 0x15 0x16 0x17, 0x24 0x25 0x26 0x27, 0x31]
    w[0x08 0x09 0x0A 0x0B, 0x18 0x19 0x1A 0x1B, 0x28 0x29 0x2A 0x2B, 0x32]
    w[0x0C 0x0D 0x0E 0x0F, 0x1C 0x1D 0x1E 0x1F, 0x2C 0x2D 0x2E 0x2F, 0x33]
  piipai = w[121 to 52 by -1]

  rinshan = w[133 132 135 134]
  doraHyouji    = w[130 to 122 by -2]
  uraDoraHyouji = w[131 to 123 by -2]

  {haipai, piipai, rinshan, doraHyouji, uraDoraHyouji}
