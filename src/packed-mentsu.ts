import { Pai } from "./pai";
import { Mentsu } from './mentsu';
import * as mentsu from "./mentsu";
const {toString: mentsuToString, koutsu, shuntsu} = mentsu;

/** Packed mentsu's => array of mentsu's */
export function toArray(ms: number) {
    const result = [];
    while (ms !== 0) {
        result.push(top(ms));
        ms = pop(ms);
    }
    return result;
}

/** Packed mentsu's => string (pretty print) */
export function toString(ms: number) {
    let result = "";
    while (ms !== 0) {
        result += mentsuToString(top(ms));
        ms = pop(ms);
        if (ms) result += ',';
    }
    return result;
}

/** Get LSB in packed mentsu's */
export function top(ms: number): Mentsu {
    return ((ms & Mentsu.MASK) - 1) & Mentsu.MASK;
}

/** Push mentsu into LSB of packed mentsu's */
export function push(ms: number, m: Mentsu) {
    return (ms << Mentsu.SHIFT) | ((m + 1) & Mentsu.MASK);
}
/** Push koutsu with given anchor into LSB-side of packed mentsu's */
export function pushKoutsu(ms: number, anchor: Pai) {
    return (ms << Mentsu.SHIFT) | (koutsu(anchor) + 1);
}
/** Push shuntsu with given anchor into LSB-side of packed mentsu's */
export function pushShuntsu(ms: number, anchor: Pai) {
    return (ms << Mentsu.SHIFT) | (shuntsu(anchor) + 1);
}

/** Pop off LSB-side of packed mentsu's */
export function pop(ms: number) {
    return ms >>> Mentsu.SHIFT;
}

/** Pop from `src`, add `offset`, push to `dest`, repeat. */
export function concatOffset(dest: number, src: number, offset: number) {
    while (src !== 0) {
        dest = (dest << Mentsu.SHIFT) | ((src & Mentsu.MASK) + offset);
        src >>>= Mentsu.SHIFT;
    }
    return dest;
}

export function sort(ms: number) {
    const orig = ms;

    let a0 = ms & 0o77; ms >>= 6;
    if (ms === 0) return ms;

    let a1 = ms & 0o77; ms >>= 6;
    if (ms === 0) {
        if (a0 <= a1) return orig;
        return a1 | (a0 << 6);
    }

    let a2 = ms & 0o77; ms >>= 6;
    if (ms === 0) {
        if (a0 > a1) { const t = a0; a0 = a1; a1 = t; }
        if (a1 > a2) { const t = a1; a1 = a2; a2 = t; }
        if (a0 > a1) { const t = a0; a0 = a1; a1 = t; }
        return a0 | (a1 << 6) | (a2 << 12);
    }

    let a3 = ms & 0o77; ms >>= 6;
    if (ms === 0) {
        if (a0 > a1) { const t = a0; a0 = a1; a1 = t; }
        if (a2 > a3) { const t = a2; a2 = a3; a3 = t; }
        if (a0 > a2) { const t = a0; a0 = a2; a2 = t; }
        if (a1 > a3) { const t = a1; a1 = a3; a3 = t; }
        if (a1 > a2) { const t = a1; a1 = a2; a2 = t; }
        return a0 | (a1 << 6) | (a2 << 12) | (a3 << 18);
    }

    throw Error("too many");
}

export function length(ms: number) {
    if (ms === 0) return 0;
    if (ms <= 0o7777) {
        if (ms <= 0o77) return 1;
        else return 2;
    } else {
        if (ms <= 0o777777) return 3;
        else return 4;
    }
}
