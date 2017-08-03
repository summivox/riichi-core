/** Pack array of 9 numbers from 0 to 7 into an 9*3-bit octal number */
export function fromArray(a: ReadonlyArray<number>) {
    let result = 0;
    for (let i = 9 - 1; i >= 0; --i) {
        result = (result << 3) | a[i];
    }
    return result;
}

/** Unpack 9*3-bit octal number into array of 9 numbers from 0 to 7 */
export function toArray(x: number) {
    const result = new Array<number>(9);
    for (let i = 0; i < 9; ++i) {
        result[i] = x & 7;
        x >>= 3;
    }
    return result;
}
/** Unpack 9*3-bit octal number into array of 9 numbers from 0 to 7 */
export function toUint8Array(x: number) {
    const result = new Uint8Array(9);
    for (let i = 0; i < 9; ++i) {
        result[i] = x & 7;
        x >>= 3;
    }
    return result;
}
/** Unpack 9*3-bit octal number to zero-padded string (pretty-print) */
export function toString(x: number) {
    return x.toString(8).padStart(9, '0');
}

// all should be 9 digits
const enum Literal {
    SEVEN = 0o777777777,
    FOUR = 0o444444444,
    THREE = 0o333333333,
}

/**
 * Whether any digit of 9*3-bit octal is larger than 4.
 * Equivalent array form: `x.some(d => d > 4)`
 */
export function isOverflow(x: number) {
    return ((x & Literal.THREE) + (Literal.THREE | 0)) & x & Literal.FOUR;
}

/**
 * Pick `i`-th digit from the right (LSB-side) in a 9*3-bit octal.
 * Equivalent array form: `x[i]`
 */
export function get(x: number, i: number) {
    return (x >>> ((i | 0) + (i << 1))) & 7;
}

/**
 * Add `p` to the `i`-th digit from the right (LSB-side) in a 9*3-bit octal.
 * Equivalent array form: `x.slice()[i] += p`
 */
export function add(x: number, p: number, i: number) {
    return (x + (p << ((i | 0) + (i << 1)))) | 0;
}
