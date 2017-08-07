import { Pai } from "../pai";
import * as packedSuite from '../packed-suite';

/**
 * - `-1`: not kokushi tenpai
 * - `13`: kokushi-13 tenpai
 * - otherwise: tenpai is `[1, 9, 11, 19, 21, 29, 30, 31, 32, 33, 34, 35, 36][ret]`
 *
 * @export
 * @param {ArrayLike<number>} suites
 * @returns {number}
 */
export function kokushi(suites: ArrayLike<number>): number {
    let c0 = 0, c1 = 0, c2 = 0;
    let tenpai: Pai;
    function count(pai: Pai, n: number) {
        switch (n) {
            case 0:
                if (++c0 > 1) return false;
                tenpai = pai;
                return true;
            case 1:
                ++c1;
                return true;
            case 2:
                if (++c2 > 1) return false;
                return true;
            default:
                return false;
        }
    }
    const m = suites[0];
    if (!count(0, m & 7)) return -1;
    if (!count(1, (m >> 24) & 7)) return -1;
    const p = suites[1];
    if (!count(2, p & 7)) return -1;
    if (!count(3, (p >> 24) & 7)) return -1;
    const s = suites[2];
    if (!count(4, s & 7)) return -1;
    if (!count(5, (s >> 24) & 7)) return -1;
    let z = suites[3];
    if (!count(6, z & 7)) { return -1; } z >>= 3;
    if (!count(7, z & 7)) { return -1; } z >>= 3;
    if (!count(8, z & 7)) { return -1; } z >>= 3;
    if (!count(9, z & 7)) { return -1; } z >>= 3;
    if (!count(10, z & 7)) { return -1; } z >>= 3;
    if (!count(11, z & 7)) { return -1; } z >>= 3;
    if (!count(12, z & 7)) { return -1; } // z >>= 3;
    if (c1 === 13) return 13;
    return tenpai;
}

/**
 * - `-1`: not chiitoi tenpai
 * - otherwise: return unique chiitoi tenpai
 *
 * @export
 * @param {ArrayLike<number>} suites
 * @returns {(Pai | -1)}
 */
export function chiitoi(suites: ArrayLike<number>): Pai | -1 {
    let c1 = 0, c2 = 0;
    let tenpai: Pai;
    for (let s = 0; s < 4; ++s) {
        let suite = suites[s];
        for (let n = s * 10 + 1; suite !== 0; ++n, suite >>>= 3) {
            switch (suite & 7) {
                case 0: break;
                case 1:
                    if (++c1 > 1) return -1;
                    tenpai = n;
                    break;
                case 2:
                    ++c2;
                    break;
                default:
                    return -1;
            }
        }
    }
    if (c1 === 1 && c2 === 6) return tenpai;
    return -1;
}
