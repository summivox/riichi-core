import { Pai } from "../pai";
import * as pai from "../pai";
const {num: paiNum} = pai;
import { TenpaiType } from "./tenpai-type";
import * as k7 from './k7';
import * as lookup from "./lookup";
const {complete: lookupComplete, waiting: lookupWaiting} = lookup;
import * as packedMentsu from "../packed-mentsu";
const {concatOffset: concat} = packedMentsu;

export interface TenpaiDecomp {
    type: TenpaiType;
    tenpai: Pai;
    anchor: Pai;
    menjan: number;
}

export interface TenpaiDecompSet {
    decomps: ReadonlyArray<TenpaiDecomp>;
    tenpai: ArrayLike<number>;
}

const yaochuu: Pai[] = [1, 9, 11, 19, 21, 29, 30, 31, 32, 33, 34, 35, 36];

const kokushiDecomps = yaochuu.map(tenpai => [<TenpaiDecomp>{
    type: TenpaiType.kokushi, tenpai, anchor: tenpai, menjan: 0
}]);
const kokushiTenpai = yaochuu.map(tenpai => {
    const result = Uint8Array.of(0, 0, 0, 0);
    result[~~(tenpai / 10)] |= paiNum(tenpai);
    return result;
}); // FIXME: hardcode?

const kokushi13Decomps = yaochuu.map(tenpai => <TenpaiDecomp>{
    type: TenpaiType.kokushi13, tenpai, anchor: tenpai, menjan: 0
});
const kokushi13Tenpai = Uint8Array.of(0, 0, 0, 0);
yaochuu.forEach(tenpai => kokushi13Tenpai[~~(tenpai / 10)] |= paiNum(tenpai));

const chiitoiDecomps = new Array<TenpaiDecomp>(37);
for (let tenpai = 0; tenpai < 37; ++tenpai) {
    chiitoiDecomps[tenpai] = <TenpaiDecomp>{
        type: TenpaiType.chiitoi, tenpai, anchor: tenpai, menjan: 0
    };
}

export function decompTenpai(suites: ArrayLike<number>): TenpaiDecompSet {
    // kokushi is mutually exclusive, so get it out of the way first
    const kokushi = k7.kokushi(suites);
    switch (kokushi) {
        case -1: break; // not kokushi
        case 13:
            return <TenpaiDecompSet>{
                decomps: kokushi13Decomps,
                tenpai: yaochuu, // FIXME: should be bitmap, not list!
            };
        default:
            return <TenpaiDecompSet>{
                decomps: kokushiDecomps[kokushi],
                tenpai: [yaochuu[kokushi]],
            };
    }

    const decomps: TenpaiDecomp[] = [];
    const tenpai = new Uint16Array(4);
    const result = <TenpaiDecompSet>{decomps, tenpai};

    // chiitoi

    const chiitoi = k7.chiitoi(suites);
    if (chiitoi != -1) {
        decomps.push(chiitoiDecomps[chiitoi]);
        tenpai[~~(chiitoi / 10)] |= 1 << paiNum(chiitoi);
    }

    // standard (4 mentsu 1 jantou)

    // tsuupai cannot form shuntsu, so handle first
    let suiteZ = suites[3];
    let typeZ = TenpaiType.kokushi; // use obviously invalid for default
    let j1 = 0, j2 = 0;
    let j1s, j1n, j2s, j2n;
    let mentsuZ = 0, shiftZ = 1;
    for (let i = 30; suiteZ !== 0; ++i, suiteZ >>= 3) {
        switch (suiteZ & 0o7) {
            case 0: break;
            case 1:
                if (j1 === 0) {
                    j1 = i; j1s = 3; j1n = i - 30;
                    typeZ = TenpaiType.tanki;
                } else return result;
                break;
            case 2:
                if (j1 === 0) {
                    j1 = i; j1s = 3; j1n = i - 30;
                    typeZ = TenpaiType.shanpon;
                } else if (j2 === 0) {
                    if (typeZ !== TenpaiType.shanpon) return result;
                    j2 = i; j2s = 3; j2n = i - 30;
                } else return result;
                break;
            case 3:
                // populate in inverse order for direct concat with MPS later
                mentsuZ |= i << shiftZ;
                shiftZ += 6;
                break;
            case 4: return result;
        }
    }
    const menjansM = lookupComplete.get(suites[0]);
    const menjansP = lookupComplete.get(suites[1]);
    const menjansS = lookupComplete.get(suites[2]);

    return result;
}

function decompTenpaiStandard(suites: ArrayLike<number>, decomps: TenpaiDecomp[], tenpai: ArrayLike<number>) {
}
