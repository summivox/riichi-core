import { toString as paiToString, dora, Pai } from './pai';

const enum Literal {
    SHUNTSU = 0b000001,
    ANCHOR = 0b111110,
    MASK = 0b111111,
    SHIFT = 6,
}

export function toArray(ms: number) {
    const result = new Array<number>();
    while (ms !== 0) {
        result.push(ms & Literal.MASK);
        ms >>>= Literal.SHIFT;
    }
}

export function toString(ms: number) {
    let result = "";
    while (ms !== 0) {
        const m = ms & Literal.MASK;
        const pai = m >>> 1;
        if (m & Literal.SHUNTSU) {
            result += paiToString(pai) + paiToString(pai + 1) + paiToString(pai + 2) + ',';
        } else {
            const paiS = paiToString(pai);
            result += paiS + paiS + paiS + ',';
        }
        ms >>>= Literal.SHIFT;
    }
    return result;
}

export function push(ms: number, anchor: Pai, isShuntsu: 0 | 1) {
    return (ms << Literal.SHIFT) | (anchor << 1) | isShuntsu;
}

export function pop(ms: number) {
    return ms >>> Literal.SHIFT;
}

/** Equivalent array form: `b.map(x => x + c).reverse().concat(a)` */
export function concatOffset(a: number, b: number, c: number) {
    while (b !== 0) {
        a = (a << Literal.SHIFT) | ((b & Literal.MASK) + c);
        b >>>= Literal.SHIFT;
    }
    return a;
}

/*
 * Example:
 * ```
 * a = push(0, 1, 0); // 0o02 => 1m1m1m,
 * a = push(a, 2, 0); // 0o0204 => 2m2m2m,1m1m1m,
 * b = push(0, 3, 1); // 0o07 => 3m4m5m,
 * b = push(b, 4, 1); // 0o0711 => 4m5m6m,3m4m5m,
 * x = concatOffset(0, b, 20); // 0o3533 => 3p4p5p,4p5p6p,
 * x = concatOffset(x, a, 40); // 0o35335452 => 1s1s1s,2s2s2s,3p4p5p,4p5p6p,
 * ```
 */
