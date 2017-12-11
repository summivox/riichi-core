import { Pai, toString as paiToString, isSuu } from "./pai";

/**
 * Encode all koutsu and shuntsu (excluding akahai 0m/0p/0s) into 6-bit integer.
 */
export const enum Mentsu {
    '111m' = 0x00, '123m' = 0x01, '222m' = 0x02, '234m' = 0x03,
    '333m' = 0x04, '345m' = 0x05, '444m' = 0x06, '456m' = 0x07,
    '555m' = 0x08, '567m' = 0x09, '666m' = 0x0a, '678m' = 0x0b,
    '777m' = 0x0c, '789m' = 0x0d, '888m' = 0x0e, '999m' = 0x0f,

    '111p' = 0x10, '123p' = 0x11, '222p' = 0x12, '234p' = 0x13,
    '333p' = 0x14, '345p' = 0x15, '444p' = 0x16, '456p' = 0x17,
    '555p' = 0x18, '567p' = 0x19, '666p' = 0x1a, '678p' = 0x1b,
    '777p' = 0x1c, '789p' = 0x1d, '888p' = 0x1e, '999p' = 0x1f,

    '111s' = 0x20, '123s' = 0x21, '222s' = 0x22, '234s' = 0x23,
    '333s' = 0x24, '345s' = 0x25, '444s' = 0x26, '456s' = 0x27,
    '555s' = 0x28, '567s' = 0x29, '666s' = 0x2a, '678s' = 0x2b,
    '777s' = 0x2c, '789s' = 0x2d, '888s' = 0x2e, '999s' = 0x2f,

    '111z' = 0x30,                '222z' = 0x32,
    '333z' = 0x34,                '444z' = 0x36,
    '555z' = 0x38,                '666z' = 0x3a,
    '777z' = 0x3c,                '----' = 0x3e,
}

/**
 * Convert int Mentsu to string mentsu.
 * @export
 * @param {Mentsu} mentsu
 * @returns
 */
export function toString(mentsu: Mentsu) { return mentsuStringLookup[mentsu]; }
const mentsuStringLookup: ReadonlyArray<string | undefined> = [
    '111m', '123m', '222m', '234m',
    '333m', '345m', '444m', '456m',
    '555m', '567m', '666m', '678m',
    '777m', '789m', '888m', '999m',

    '111p', '123p', '222p', '234p',
    '333p', '345p', '444p', '456p',
    '555p', '567p', '666p', '678p',
    '777p', '789p', '888p', '999p',

    '111s', '123s', '222s', '234s',
    '333s', '345s', '444s', '456s',
    '555s', '567s', '666s', '678s',
    '777s', '789s', '888s', '999s',

    '111z', undefined, '222z', undefined,
    '333z', undefined, '444z', undefined,
    '555z', undefined, '666z', undefined,
    '777z', undefined, undefined, '----',
];

export function isValid(mentsu: Mentsu) {
    return mentsu !== 0x3e && !!mentsuStringLookup[mentsu];
}

/**
 * Smallest Pai in Mentsu
 * @param {Mentsu} mentsu
 */
export function anchor(mentsu: Mentsu) { return anchorLookup[mentsu]; }
const anchorLookup: ArrayLike<Pai> = Uint8Array.of(
     1,  1,  2,  2,  3,  3,  4,  4,  5,  5,  6,  6,  7,  7,  8,  9,
    11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 19,
    21, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26, 27, 27, 28, 29,
    31, 31, 32, 32, 33, 33, 34, 34, 35, 35, 36, 36,
);
// NOTE: typed array cannot have holes, so e.g. '123z' is included despite invalid

/**
 * Convert Pai to corresponding Koutsu (e.g. 1m => 111m)
 * @param {Pai} anchor
 */
export function koutsu(anchor: Pai) { return koutsuLookup[anchor]; }
const koutsuLookup: ArrayLike<Mentsu> = Uint8Array.of(
    0x08, 0x00, 0x02, 0x04, 0x06, 0x08, 0x0a, 0x0c, 0x0e, 0x0f,
    0x18, 0x10, 0x12, 0x14, 0x16, 0x18, 0x1a, 0x1c, 0x1e, 0x1f,
    0x28, 0x20, 0x22, 0x24, 0x26, 0x28, 0x2a, 0x2c, 0x2e, 0x2f,
          0x30, 0x32, 0x34, 0x36, 0x38, 0x3a, 0x3c,
);

/**
 * Convert Pai to corresponding Shuntsu (e.g. 5m => 567m)
 * @param {Pai} anchor
 */
export function shuntsu(anchor: Pai) { return shuntsuLookup[anchor]; }
const shuntsuLookup: ArrayLike<Mentsu> = Uint8Array.of(
    0x09, 0x01, 0x03, 0x05, 0x07, 0x09, 0x0b, 0x0d, 0x3e, 0x3e,
    0x19, 0x11, 0x13, 0x15, 0x17, 0x19, 0x1b, 0x1d, 0x3e, 0x3e,
    0x29, 0x21, 0x23, 0x25, 0x27, 0x29, 0x2b, 0x2d,
);
