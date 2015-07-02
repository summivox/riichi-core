# magic numbers:
#   range of numerals: [0, N)
#   max # of single pai in game: M
#   max # of pai in juntehai: K
#   max # of jantou: CAP_JANTOU = 1
#   max # of mentsu (= shuntsu + koutsu): CAP_MENTSU
export const N = 9, M = 4, K = 14
export const CAP_JANTOU = 1
export const CAP_MENTSU = calcCapMentsu K
export function calcCapMentsu => Math.floor((it - 2)/3)
