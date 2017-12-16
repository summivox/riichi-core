import { Pai } from "../pai";
import * as pai from "../pai";
const {num: paiNum, sNum: paiSNum} = pai;

import { Mentsu } from "../mentsu";
import * as packedMentsu from "../packed-mentsu";
const {
    concatOffset: concat,
    top, pop,
    pushKoutsu,
} = packedMentsu;

import { TenpaiType } from "./tenpai-type";

import * as lookup from "./lookup";
const {
    complete: C, waiting: W,
    jFromMsj, msFromMsj,
} = lookup;

export interface TenpaiDecomp {
    type: TenpaiType;
    tenpai: Pai;
    anchor: Pai;

    /** packed mentsu's */
    ms: number;
    jantou: Pai;
}

export interface TenpaiDecompSet {
    decomps: ReadonlyArray<TenpaiDecomp>;
    tenpai: ArrayLike<number>;
}

const yaochuu: Pai[] = [1, 9, 11, 19, 21, 29, 30, 31, 32, 33, 34, 35, 36];

const kokushiDecomps = yaochuu.map(tenpai => [<TenpaiDecomp>{
    type: TenpaiType.kokushi, tenpai, anchor: tenpai, ms: 0
}]);
const kokushi13Decomps = yaochuu.map(tenpai => <TenpaiDecomp>{
    type: TenpaiType.kokushi13, tenpai, anchor: tenpai, ms: 0
});
const kokushiTenpai = [
    Uint16Array.of(0b000000001, 0b000000000, 0b000000000, 0b0000000),
    Uint16Array.of(0b100000000, 0b000000000, 0b000000000, 0b0000000),
    Uint16Array.of(0b000000000, 0b000000001, 0b000000000, 0b0000000),
    Uint16Array.of(0b000000000, 0b100000000, 0b000000000, 0b0000000),
    Uint16Array.of(0b000000000, 0b000000000, 0b000000001, 0b0000000),
    Uint16Array.of(0b000000000, 0b000000000, 0b100000000, 0b0000000),
    Uint16Array.of(0b000000000, 0b000000000, 0b000000000, 0b0000001),
    Uint16Array.of(0b000000000, 0b000000000, 0b000000000, 0b0000010),
    Uint16Array.of(0b000000000, 0b000000000, 0b000000000, 0b0000100),
    Uint16Array.of(0b000000000, 0b000000000, 0b000000000, 0b0001000),
    Uint16Array.of(0b000000000, 0b000000000, 0b000000000, 0b0010000),
    Uint16Array.of(0b000000000, 0b000000000, 0b000000000, 0b0100000),
    Uint16Array.of(0b000000000, 0b000000000, 0b000000000, 0b1000000),
];
const kokushi13Tenpai =
    Uint16Array.of(0b100000001, 0b100000001, 0b100000001, 0b1111111);
yaochuu.forEach(tenpai => kokushi13Tenpai[paiSNum(tenpai)] |= paiNum(tenpai));

const chiitoiDecomps = new Array<TenpaiDecomp>(Pai.MAX + 1);
for (let tenpai = Pai.MIN; tenpai <= Pai.MAX; ++tenpai) {
    chiitoiDecomps[tenpai] = <TenpaiDecomp>{
        type: TenpaiType.chiitoi, tenpai, anchor: tenpai, ms: 0
    };
}

/**
 * - `-1`: not kokushi tenpai
 * - `13`: kokushi-13 tenpai
 * - otherwise: tenpai is `[1, 9, 11, 19, 21, 29, 30, 31, 32, 33, 34, 35, 36][ret]`
 *
 * @export
 * @param {ArrayLike<number>} suites
 * @returns {number}
 */
function kokushi(suites: ArrayLike<number>): number {
    let c0 = 0, c1 = 0, c2 = 0;
    let tenpai: Pai = 37;
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
function chiitoi(suites: ArrayLike<number>): Pai | -1 {
    let c1 = 0, c2 = 0;
    let tenpai: Pai = 37;
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


export function decompTenpai(suites: ArrayLike<number>): TenpaiDecompSet {
    // kokushi: mutually exclusive with other forms
    const resultK = kokushi(suites);
    switch (resultK) {
    case -1: break; // not kokushi
    case 13:
        return <TenpaiDecompSet>{
            decomps: kokushi13Decomps,
            tenpai: kokushi13Tenpai,
        };
    default:
        return <TenpaiDecompSet>{
            decomps: kokushiDecomps[resultK],
            tenpai: kokushiTenpai[resultK],
        };
    }

    const decomps: TenpaiDecomp[] = [];
    const tenpai = new Uint16Array(4);
    const result = <TenpaiDecompSet>{decomps, tenpai};

    // chiitoi
    const result7 = chiitoi(suites);
    if (result7 !== -1) {
        decomps.push(chiitoiDecomps[result7]);
        tenpai[paiSNum(result7)] |= 1 << (paiNum(result7) - 1);
    }

    // standard (4 mentsu 1 jantou)

    /*
     * Some shorthands:
     * - w == DecompWaitingEntry == {c, hasJantou, tenpaiType, tenpai, anchor}
     * - c == complete == menjan[]
     * - mj == menjan == packed (mentsu's + jantou)
     * - ms == mentsu's == packed mentsu's
     */

    /*
     * tsuupai cannot form shuntsu, so:
     *
     * - all triples are koutsu
     * - no quads allowed
     *
     * then only one of the following are valid:
     *
     * | # || single | pair || complete | wait | type        |
     * |---||--------|------||----------|------|-------------|
     * | 0 ||   0    |  0   ||   yes    | no   |             |
     * | 1 ||   0    |  1   ||   yes    | yes  | shanpon     |
     * | 2 ||   0    |  2   ||   no     | yes  | shanpon     |
     * | 3 ||   1    |  0   ||   no     | yes  | tanki       |
     *
     *      wait  jan
     *   0: yes   yes
     *   1: yes   no
     *      no    yes
     *   2: no    no
     *   3: no    no
     */
    let suiteZ = suites[3];
    let pair1 = Pai.NULL, pair2 = Pai.NULL;
    let typeZ: 0|1|2|3 = 0;
    let msZ = 0;
    for (let i = Pai['1z']; suiteZ !== 0; ++i, suiteZ >>= 3) {
        switch (suiteZ & 0o7) {
        case 0:
            break;
        case 1:
            if (typeZ === 0) {
                pair1 = i;
                typeZ = 3;
            } else return result;
            break;
        case 2:
            switch (typeZ) {
            case 0:
                pair1 = i;
                typeZ = 1;
                break;
            case 1:
                pair2 = i;
                typeZ = 2;
                break;
            default:
                return result;
            }
            break;
        case 3:
            msZ = pushKoutsu(msZ, i);
            break;
        default:
            return result;
        }
    }
    switch (typeZ) {
    case 0:
        break;
    case 1:
        break;
    case 2:
        break;
    case 3:
        break;
    }
    const cM = C.get(suites[0]);
    const cP = C.get(suites[1]);
    const cS = C.get(suites[2]);

    return result;
}

function CCCM(
    cM: ArrayLike<number>,
    cP: ArrayLike<number>,
    cS: ArrayLike<number>,
    allowJantou: 0|1,
    msZ: number,
    result: Uint32Array,
) {
    // enforce max # of jantou limit
    let nJ = allowJantou; // original value used later
    const mjM0 = cM[0], jM0 = jFromMsj(mjM0);
    if (jM0 !== Pai.NULL && (nJ--) === 0) return 0;
    const mjP0 = cP[0], jP0 = jFromMsj(mjP0);
    if (jP0 !== Pai.NULL && (nJ--) === 0) return 0;
    const mjS0 = cS[0], jS0 = jFromMsj(mjS0);
    if (jS0 !== Pai.NULL && (nJ--) === 0) return 0;

    // at most 1 of M/P/S may have multiple complete decomps
    let cMulti, offsetMulti;
    //
    let msSingle = concat(0, msZ, Mentsu.Z);
    let jSingle = Pai.NULL;
    let n: number;
    if ((n = cM.length) > 1) {
        cMulti = cM;
        offsetMulti = Mentsu.M;
        msSingle = concat(concat(msSingle,
            pop(mjP0), Mentsu.P),
            pop(mjS0), Mentsu.S);
        if (jP0 !== Pai.NULL) jSingle = jP0 + Pai.P; else
        if (jS0 !== Pai.NULL) jSingle = jS0 + Pai.S;
    } else if (cP.length > 1) {
        cMulti = cP;
        offsetMulti = Mentsu.P;
        msSingle = concat(concat(msSingle,
            pop(mjM0), Mentsu.M),
            pop(mjS0), Mentsu.S);
        if (jM0 !== Pai.NULL) jSingle = jM0 + Pai.M; else
        if (jS0 !== Pai.NULL) jSingle = jS0 + Pai.S;
    } else if (cS.length > 1) {
        cMulti = cS;
        offsetMulti = Mentsu.S;
        msSingle = concat(concat(msSingle,
            pop(mjM0), Mentsu.M),
            pop(mjP0), Mentsu.P);
        if (jM0 !== Pai.NULL) jSingle = jM0 + Pai.M; else
        if (jP0 !== Pai.NULL) jSingle = jP0 + Pai.P;
    } else {
        const msResult = concat(concat(concat(msSingle,
            pop(mjM0), Mentsu.M),
            pop(mjP0), Mentsu.P),
            pop(mjS0), Mentsu.S);
        result[0] = allowJantou ? createMsj(msResult, jSingle) : msResult;
        return 1;
    }

    if (allowJantou) {
        if (jSingle !== Pai.NULL) {
            for (let i = 0; i < n; ++i) {
                result[i] = createMsj(concat(msSingle, pop(cMulti[i]), offsetMulti), jSingle);
            }
        } else {
            for (let i = 0; i < n; ++i) {
                const mj = cMulti[i];
                result[i] = createMsj(concat(msSingle, pop(mj), offsetMulti), jFromMsj(mj));
            }
        }
    } else {
        for (let i = 0; i < n; ++i) {
            result[i] = concat(msSingle, pop(cMulti[i]), offsetMulti);
        }
    }
    return n;
}

function createMsj(a: number, b: number): never { throw Error("NOT IMPL"); }
