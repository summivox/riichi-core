/**
 * Convert string Pai to int Pai.
 *
 * - 0m, 1m, 2m, ..., 9m => 0, 1, 2, ... 9
 * - 0p, 1p, 2p, ..., 9p => 10, 11, 12, ..., 19
 * - 0s, 1s, 2s, ..., 9s => 20, 21, 22, ..., 29
 * - 1z, 2z, 3z, ..., 7z => 30, 31, 32, ..., 36
 *
 * @export
 * @param {string} str
 * @returns
 */
export function fromString(paiStr: string) {
    const n = paiStr.codePointAt(0) - 0x30; // '0'.codePointAt(0)
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
            if (1 <= n && n <= 7) return n + 29;
            break;
    }
    throw Error(`${paiStr} is not valid pai`);
}

/**
 * Convert int Pai to string Pai.
 *
 * - 0, 1, 2, ... 9 => 0m, 1m, 2m, ..., 9m
 * - 10, 11, 12, ..., 19 => 0p, 1p, 2p, ..., 9p
 * - 20, 21, 22, ..., 29 => 0s, 1s, 2s, ..., 9s
 * - 30, 31, 32, ..., 36 => 1z, 2z, 3z, ..., 7z
 *
 * @export
 * @param {number} pai
 * @returns
 */
export function toString(pai: number) { return paiStringLookup[pai]; }
const paiStringLookup: ReadonlyArray<string> = [
    '0m', '1m', '2m', '3m', '4m', '5m', '6m', '7m', '8m', '9m',
    '0p', '1p', '2p', '3p', '4p', '5p', '6p', '7p', '8p', '9p',
    '0s', '1s', '2s', '3s', '4s', '5s', '6s', '7s', '8s', '9s',
    '1z', '2z', '3z', '4z', '5z', '6z', '7z',
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

    0b00010000, 0b00010000, 0b00010000, 0b00010000,
    0b00100000, 0b00100000, 0b00100000,
);

/** 19mps */
export function isRaotou(x: number) {
    return (paiKindLookup[x] & PaiKind.raotou) !== 0;
}
/** 0mps | 2~8mps */
export function isChunchan(x: number) {
    return (paiKindLookup[x] & PaiKind.chunchan) !== 0;
}
/** 0mps */
export function isZero(x: number) {
    return (paiKindLookup[x] & PaiKind.zero) !== 0;
}
/** 5mps */
export function isFive(x: number) {
    return (paiKindLookup[x] & PaiKind.five) !== 0;
}
/** 05mps */
export function isFiveish(x: number) {
    return (paiKindLookup[x] & PaiKind.fiveish) !== 0;
}
/** 1234z (ESWN) */
export function isFon(x: number) {
    return 30 <= x && x < 34;
}
/** 567z (PFC) */
export function isSangen(x: number) {
    return 34 <= x && x < 37;
}
/** 0~9mps == 19mps | 2~8mps */
export function isSuu(x: number) {
    return 0 <= x && x < 30;
}
/** 1~7z == 1234z | 567z */
export function isTsuu(x: number) {
    return 30 <= x && x < 37;
}
/** 19mps | 1~7z */
export function isYaochuu(x: number) {
    return (paiKindLookup[x] & PaiKind.yaochuu) !== 0;
}
/** 1~9mps | 1~7z */
export function isValid(pai: number) {
    return 0 <= pai && pai < 37;
}

/**
 * 0mps => 5mps, otherwise no change
 *
 * @export
 * @param {Number} x
 */
export function zeroToFive(x: number) { return isZero(x) ? x + 5 : x; }
/**
 * 5mps => 0mps, otherwise no change
 *
 * @export
 * @param {number} x
 */
export function fiveToZero(x: number) { return isFive(x) ? x - 5 : x; }

/**
 * Get dora from given doraHyouji.
 * e.g. 1m => 2m, 0p => 6p, 9s => 1s, 1z => 2z, 4z => 1z, 5z => 6z, 7z => 5z
 *
 * @export
 * @param {number} x - doraHyouji
 * @returns dora
 */
export function dora(x: number) { return doraLookup[x]; }
const doraLookup = Uint8Array.of(
    6, 2, 3, 4, 5, 6, 7, 8, 9, 1,
    16, 12, 13, 14, 15, 16, 17, 18, 19, 11,
    26, 22, 23, 24, 25, 26, 27, 28, 29, 21,
    31, 32, 33, 30, 35, 36, 34,
);

/**
 * Comparison function for sorting array of int Pai.
 * Integer order is used, except for 0m/0p/0s, which are ordered between
 * 4m/4p/4s and 5m/5p/5s, respectively.
 *
 * @export
 * @param {number} l
 * @param {number} r
 * @returns
 */
export function compare(l: number, r: number) {
    const d2 = zeroToFive(l) - zeroToFive(r);
    if (d2 !== 0) return d2;
    return l - r;
}

/**
 * Whether 3 pai given in sorted order form a shuntsu.
 * e.g. (4m, 0m, 6m) => true, (8m, 9m, 1m) => false,
 *      (1m, 2p, 3s) => false, (5z, 6z, 7z) => false
 *
 * @export
 * @param {number} a
 * @param {number} b
 * @param {number} c
 * @returns
 */
export function isShuntsu(a: number, b: number, c: number) {
    if (!isSuu(a) || !isSuu(c)) return false;
    const p = zeroToFive(a), q = zeroToFive(b), r = zeroToFive(c);
    // NOTE: omitted redundant `~~(p / 10) === ~~(r / 10)` check as 0ps serve
    // as sentry elements across suite boundaries
    return p + 1 === q && q + 1 === r;
}
