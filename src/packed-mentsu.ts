import { toString as paiToString, dora } from './pai';

const enum Literal {
    SHUNTSU = 0b1000000,
    OFFSET = 0b0111111,
    MASK = 0b1111111,
}

/** (0 to 4) 7-bit zero-terminated int pack => array */
export function toArray(ms: number) {
    const result = new Array<number>();
    while (ms !== 0) {
        result.push(ms & Literal.MASK);
        ms >>>= 7;
    }
}

/** pretty print as mentsu array */
export function toString(ms: number) {
    let result = "";
    while (ms !== 0) {
        const m = ms & Literal.MASK;
        ms >>>= 7;
        const pai = m & Literal.OFFSET;
        if (m & Literal.SHUNTSU) {
            const pai2 = dora(pai);
            const pai3 = dora(pai2);
            result += paiToString(pai) + paiToString(pai2) + paiToString(pai3) + ',';
        } else {
            const paiS = paiToString(pai);
            result += paiS + paiS + paiS + ',';
        }
    }
    return result;
}

/** Equivalent array form: `ms.slice().unshift((isShuntsu << 6) | offset)` */
export function push(ms: number, isShuntsu: boolean, offset: number) {
    return (ms << 7) | (+isShuntsu << 6) | offset;
}
/** Equivalent array form: `ms.slice(1)` */
export function pop(ms: number) {
    return ms >>> 7;
}

/**
 * Equivalent array form:
 * `a.map(x => x + ai).concat(b.map(x => x + bi), c.map(x => x + ci), d.map(x => x + di))`
 */
export function concatAdd(
    a: number, ai: number,
    b: number, bi: number,
    c: number, ci: number,
    d: number, di: number) {

    let result = 0, j = 0;
    while (a) {
        const m = a & Literal.MASK;
        result |= (m + ai) << j;
        a >>>= 7;
        j += 7;
    }
    while (b) {
        const m = b & Literal.MASK;
        result |= (m + bi) << j;
        b >>>= 7;
        j += 7;
    }
    while (c) {
        const m = c & Literal.MASK;
        result |= (m + ci) << j;
        c >>>= 7;
        j += 7;
    }
    while (d) {
        const m = d & Literal.MASK;
        result |= (m + di) << j;
        d >>>= 7;
        j += 7;
    }
    return result;
}
