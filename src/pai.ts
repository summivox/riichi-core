/**
 * Encode Pai (including akahai 0m/0p/0s) into 6-bit integer.
 * '--' is used as a null/reserved value.
 *
 * @export
 * @enum {number}
 */
export const enum Pai {
    M = 0,
    '0m' =  0, '1m' =  1, '2m' =  2, '3m' =  3, '4m' =  4,
    '5m' =  5, '6m' =  6, '7m' =  7, '8m' =  8, '9m' =  9,

    P = 10,
    '0p' = 10, '1p' = 11, '2p' = 12, '3p' = 13, '4p' = 14,
    '5p' = 15, '6p' = 16, '7p' = 17, '8p' = 18, '9p' = 19,

    S = 20,
    '0s' = 20, '1s' = 21, '2s' = 22, '3s' = 23, '4s' = 24,
    '5s' = 25, '6s' = 26, '7s' = 27, '8s' = 28, '9s' = 29,

    Z = 30,
    '--' = 30, '1z' = 31, '2z' = 32, '3z' = 33, '4z' = 34,
    '5z' = 35, '6z' = 36, '7z' = 37,

    NULL = 30, MIN = 0, MAX = 37,
}

/**
 * Convert string Pai to int Pai.
 * @export
 * @param {string} str
 * @returns
 */
export function fromString(paiStr: string): Pai {
    const n = paiStr.codePointAt(0)! - 0x30; // '0'.codePointAt(0)
    const s = paiStr[1];
    switch (s) {
        case 'm':
            if (0 <= n && n <= 9) return n;
            break;
        case 'p':
            if (0 <= n && n <= 9) return n + 10;
            break;
        case 's':
            if (0 <= n && n <= 9) return n + 20;
            break;
        case 'z':
            if (1 <= n && n <= 7) return n + 30;
            break;
    }
    throw Error(`'${paiStr}' is not valid pai`);
}

/**
 * Convert int Pai to string Pai.
 * @export
 * @param {Pai} pai
 * @returns
 */
export function toString(pai: Pai) { return paiStringLookup[pai]; }
const paiStringLookup: ReadonlyArray<string> = [
    '0m', '1m', '2m', '3m', '4m', '5m', '6m', '7m', '8m', '9m',
    '0p', '1p', '2p', '3p', '4p', '5p', '6p', '7p', '8p', '9p',
    '0s', '1s', '2s', '3s', '4s', '5s', '6s', '7s', '8s', '9s',
    '--', '1z', '2z', '3z', '4z', '5z', '6z', '7z',
];

const enum PaiKind {
    none = 0,

    /** 19mps */
    raotou = 1 << 0,
    /** 0mps | 2~8mps */
    chunchan = 1 << 1,
    /** 0mps */
    zero = 1 << 2,
    /** 5mps */
    five = 1 << 3,
    /** 1234z (ESWN) */
    fon = 1 << 4,
    /** 567z (PFC) */
    sangen = 1 << 5,

    /////////////////////////////////

    /** 0~9mps == 19mps | 2~8mps */
    suu = raotou | chunchan,
    /** 1~7z == 1234z | 567z */
    tsuu = fon | sangen,
    /** 19mps | 1~7z */
    yaochuu = raotou | tsuu,
    /** 05mps */
    fiveish = zero | five,

    all = suu | tsuu,
}
const paiKindLookup = Uint8Array.of(
    0b00000110, 0b00000001, 0b00000010, 0b00000010, 0b00000010,
    0b00001010, 0b00000010, 0b00000010, 0b00000010, 0b00000001,

    0b00000110, 0b00000001, 0b00000010, 0b00000010, 0b00000010,
    0b00001010, 0b00000010, 0b00000010, 0b00000010, 0b00000001,

    0b00000110, 0b00000001, 0b00000010, 0b00000010, 0b00000010,
    0b00001010, 0b00000010, 0b00000010, 0b00000010, 0b00000001,

    0b00000000, 0b00010000, 0b00010000, 0b00010000, 0b00010000,
    0b00100000, 0b00100000, 0b00100000,
);

/** 19mps */
export function isRaotou(x: Pai) {
    return (paiKindLookup[x] & PaiKind.raotou) !== 0;
}
/** 0mps | 2~8mps */
export function isChunchan(x: Pai) {
    return (paiKindLookup[x] & PaiKind.chunchan) !== 0;
}
/** 0mps */
export function isZero(x: Pai) {
    return (paiKindLookup[x] & PaiKind.zero) !== 0;
}
/** 5mps */
export function isFive(x: Pai) {
    return (paiKindLookup[x] & PaiKind.five) !== 0;
}
/** 05mps */
export function isFiveish(x: Pai) {
    return (paiKindLookup[x] & PaiKind.fiveish) !== 0;
}
/** 1234z (ESWN) */
export function isFon(x: Pai) {
    return (paiKindLookup[x] & PaiKind.fon) !== 0;
}
/** 567z (PFC) */
export function isSangen(x: Pai) {
    return (paiKindLookup[x] & PaiKind.sangen) !== 0;
}
/** 0~9mps == 19mps | 2~8mps */
export function isSuu(x: Pai) {
    return (paiKindLookup[x] & PaiKind.suu) !== 0;
}
/** 1~7z == 1234z | 567z */
export function isTsuu(x: Pai) {
    return (paiKindLookup[x] & PaiKind.tsuu) !== 0;
}
/** 19mps | 1~7z */
export function isYaochuu(x: Pai) {
    return (paiKindLookup[x] & PaiKind.yaochuu) !== 0;
}
/** 1~9mps | 1~7z */
export function isValid(x: Pai) {
    return (paiKindLookup[x] | 0) !== 0;
}

/**
 * 0mps => 5mps, otherwise no change
 *
 * @export
 * @param {Pai} x
 */
export function zeroToFive(x: Pai): Pai { return isZero(x) ? x + 5 : x; }
/**
 * 5mps => 0mps, otherwise no change
 *
 * @export
 * @param {Pai} x
 */
export function fiveToZero(x: Pai): Pai { return isFive(x) ? x - 5 : x; }

/**
 * Get face number of Pai.
 * e.g. 2m => 2, 0p => 5, 6z => 6
 * @param {Pai} x
 */
export function num(x: Pai) { return numLookup[x]; }
const numLookup = Uint8Array.of(
    5, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    5, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    5, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    0, 1, 2, 3, 4, 5, 6, 7,
);

/**
 * Get suite number of Pai (mpsz => 0123).
 * @export
 * @param {Pai} x
 */
export function sNum(x: Pai) { return ~~(x / 10); }

/**
 * Get dora from given doraHyouji.
 * e.g. 1m => 2m, 0p => 6p, 9s => 1s, 1z => 2z, 4z => 1z, 5z => 6z, 7z => 5z
 *
 * @export
 * @param {Pai} x - doraHyouji
 * @returns dora
 */
export function dora(x: Pai): Pai { return doraLookup[x]; }
const doraLookup = Uint8Array.of(
    6, 2, 3, 4, 5, 6, 7, 8, 9, 1,
    16, 12, 13, 14, 15, 16, 17, 18, 19, 11,
    26, 22, 23, 24, 25, 26, 27, 28, 29, 21,
    30, 32, 33, 34, 31, 36, 37, 35,
);

/**
 * Comparison function for sorting array of int Pai.
 * Integer order is used, except for 0m/0p/0s, which are ordered between
 * 4m/4p/4s and 5m/5p/5s, respectively.
 *
 * @export
 * @param {Pai} l
 * @param {Pai} r
 * @returns
 */
export function compare(l: Pai, r: Pai) {
    const d2 = zeroToFive(l) - zeroToFive(r);
    if (d2 !== 0) return d2;
    return l - r;
}

/**
 * Whether 3 Pai given in sorted order form a Shuntsu.
 * e.g. (4m, 0m, 6m) => true, (8m, 9m, 1m) => false,
 *      (1m, 2p, 3s) => false, (5z, 6z, 7z) => false
 *
 * @export
 * @param {Pai} a
 * @param {Pai} b
 * @param {Pai} c
 * @returns
 */
export function isShuntsu(a: Pai, b: Pai, c: Pai) {
    if (!isSuu(a) || !isSuu(c)) return false;
    const p = zeroToFive(a), q = zeroToFive(b), r = zeroToFive(c);
    // NOTE: omitted redundant `~~(p / 10) === ~~(r / 10)` check as 0ps serve
    // as sentry elements across suite boundaries
    return p + 1 === q && q + 1 === r;
}
