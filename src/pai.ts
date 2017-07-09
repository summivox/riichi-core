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
export function toString(pai: number) { return paiToStringLookup[pai]; }
const paiToStringLookup: ReadonlyArray<string> = [
    '0m', '1m', '2m', '3m', '4m', '5m', '6m', '7m', '8m', '9m',
    '0p', '1p', '2p', '3p', '4p', '5p', '6p', '7p', '8p', '9p',
    '0s', '1s', '2s', '3s', '4s', '5s', '6s', '7s', '8s', '9s',
    '1z', '2z', '3z', '4z', '5z', '6z', '7z'
];

export function isValid(pai: number) { return 0 <= pai && pai < 37; }

/**
 * Comparison function for int Pai for e.g. array sorting.
 * Integer order is used, except for 0m/0p/0s, which are ordered between
 * 4m/4p/4s and 5m/5p/5s, respectively.
 *
 * @export
 * @param {number} l
 * @param {number} r
 * @returns
 */
export function compare(l: number, r: number) {
    const l2 = (l === 0 || l === 10 || l === 20) ? l + 5 : l;
    const r2 = (r === 0 || r === 10 || r === 20) ? r + 5 : r;
    const d2 = l2 - r2;
    if (d2 !== 0) return d2;
    return l - r;
}
