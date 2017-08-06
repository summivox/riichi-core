import { Pai } from "../pai";
import * as packedSuite from '../packed-suite';

/**
 * - `-1`: not kokushi tenpai
 * - `37`: kokushi-13 tenpai
 * - otherwise: return unique kokushi-1 tenpai
 *
 * @export
 * @param {ArrayLike<number>} suites
 * @returns {(Pai | -1 | 37)}
 */
export function kokushi(suites: ArrayLike<number>): Pai | -1 | 37 {
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
    if (!count(1, m & 7)) return -1;
    if (!count(9, (m >> 24) & 7)) return -1;
    const p = suites[1];
    if (!count(11, p & 7)) return -1;
    if (!count(19, (p >> 24) & 7)) return -1;
    const s = suites[2];
    if (!count(21, s & 7)) return -1;
    if (!count(29, (s >> 24) & 7)) return -1;
    let z = suites[3];
    if (!count(30, z & 7)) { return -1; } z >>= 3;
    if (!count(31, z & 7)) { return -1; } z >>= 3;
    if (!count(32, z & 7)) { return -1; } z >>= 3;
    if (!count(33, z & 7)) { return -1; } z >>= 3;
    if (!count(34, z & 7)) { return -1; } z >>= 3;
    if (!count(35, z & 7)) { return -1; } z >>= 3;
    if (!count(36, z & 7)) { return -1; } // z >>= 3;
    if (c1 === 13) return 37;
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
