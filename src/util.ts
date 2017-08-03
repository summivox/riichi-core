/**
 * Player id lookup by natural turn after given player
 * [next, oppo, prev]
 */
export const OTHER_PLAYERS: ReadonlyArray<ReadonlyArray<number>> = [
    [1, 2, 3], [2, 3, 0], [3, 0, 1], [0, 1, 2]
];

/**
 * floor positive number `x` to multiple of `N`
 * e.g.:
 *
 * - floorTo(999, 100) == 900
 * - floorTo(1000, 100) == 1000
 * - floorTo(1001, 100) == 1000
 *
 * @export
 * @param {number} x
 * @param {number} N
 * @returns
 */
export function floorTo(x: number, N: number) { return Math.floor(x / N) * N; }
/**
 * ceil positive number `x` to multiple of `N`
 * e.g.:
 *
 * - ceilTo(999, 100) == 1000
 * - ceilTo(1000, 100) == 1000
 * - ceilTo(1001, 100) == 1100
 *
 * @export
 * @param {number} x
 * @param {number} N
 * @returns
 */
export function ceilTo(x: number, N: number) { return Math.ceil(x / N) * N; }

export function sum(arr: ReadonlyArray<number>) {
  let s = 0;
  for (const x of arr) s += x;
  return s;
}
export function max(arr: ReadonlyArray<number>) {
  let m = -Infinity;
  for (const x of arr) if (x > m) m = x;
  return m;
}
export function min(arr: ReadonlyArray<number>) {
  let m = +Infinity;
  for (const x of arr) if (x < m) m = x;
  return m;
}
/**
 * number of element `x` in array `arr` satisfying `f(x)` is truthy
 *
 * @export
 * @param {any} arr
 * @param {any} f
 */
export function count(arr: Array<any>, f: (any) => boolean) {
    let n = 0;
    for (const x of arr) if (f(x)) ++n;
    return n;
}
export function invert(obj: object) {
    const result = {};
    for (const k in obj) {
        result[obj[k]] = k;
    }
    return result;
}

/**
 * Shuffle array in-place. Optionally provide RNG.
 *
 * @export
 * @callback randInt
 * @param {Array<any>} arr
 * @param {randInt} [randInt] - 0 <= randInt(x) < x
 * @returns
 */
export function randomShuffle<T>(arr: Array<T>, randInt?: (hi: number) => number) {
    if (randInt == null) randInt = mathRandomInt;
    const l = arr.length;
    for (let i = l - 1; i > 0; --i) {
        const j = randInt(i + 1);
        if (j !== i) {
            const t = arr[j]; arr[j] = arr[i]; arr[i] = t;
        }
    }
    return arr;
}
function mathRandomInt(hi: number) { return ~~(Math.random() * hi); }

/**
 * `minus(a, b) == a - b`.
 * For sorting number array
 *
 * @export
 * @param {number} a
 * @param {number} b
 * @returns
 */
export function minus(a: number, b: number) { return a - b; }
