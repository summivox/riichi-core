import { Pai } from "./pai";
import * as pai from "./pai";
const {toString: paiToString} = pai;
import { Mentsu } from './mentsu';
import * as mentsu from "./mentsu";
const {toString: mentsuToString, koutsu, shuntsu} = mentsu;

const enum Literal {
    MASK = 0b111111,
    SHIFT = 6,
}

/** Packed mentsu's => array of mentsu's */
export function toArray(ms: number) {
    const result = new Array<number>();
    while (ms !== 0) {
        result.push((ms + 1) & Literal.MASK);
        ms >>>= Literal.SHIFT;
    }
}

/** Packed mentsu's => string */
export function toString(ms: number) {
    let result = "";
    while (ms !== 0) {
        result += mentsuToString(top(ms)) + ',';
        ms >>>= Literal.SHIFT;
    }
    return result;
}

/** Packed mentsu's + Jantou => string*/
export function toStringJ(msj: number) {
    const j = paiToString(topJ(msj));
    return j[0] + j + '|' + toString(pop(msj));
}

/** Get LSB in packed mentsu's */
export function top(ms: number): Mentsu {
    return ((ms & Literal.MASK) - 1) & Literal.MASK;
}
/** Get Jantou in packed mentsu's + jantou */
export function topJ(msj: number): Pai {
    return msj & Literal.MASK;
}

/** Push mentsu into LSB of packed mentsu's */
export function push(ms: number, m: Mentsu) {
    return (ms << Literal.SHIFT) | ((m + 1) & Literal.MASK);
}
/** Push koutsu with given anchor into LSB of packed mentsu's */
export function pushKoutsu(ms: number, anchor: Pai) {
    return (ms << Literal.SHIFT) | (koutsu(anchor) + 1);
}
/** Push shuntsu with given anchor into LSB of packed mentsu's */
export function pushShuntsu(ms: number, anchor: Pai) {
    return (ms << Literal.SHIFT) | (shuntsu(anchor) + 1);
}
/** Combine packed mentsu's with jantou */
export function pushJantou(ms: number, jantou: Pai) {
    return (ms << Literal.SHIFT) | jantou; // NOTE: no offset or conversion needed
}

/**
 * For packed mentsu's without jantou: pop off LSB mentsu.
 * For packed mentsu's with jantou: pop off jantou.
 */
export function pop(ms: number) {
    return ms >>> Literal.SHIFT;
}

/** Pop from `src`, add `offset`, push to `dest`, repeat. (no jantou) */
export function concatOffset(dest: number, src: number, offset: number) {
    while (src !== 0) {
        dest = (dest << Literal.SHIFT) | ((src & Literal.MASK) + offset);
        src >>>= Literal.SHIFT;
    }
    return dest;
}
