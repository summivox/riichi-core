import { Pai } from "../pai";
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
const kokushi13Decomps = yaochuu.map(tenpai => <TenpaiDecomp>{
    type: TenpaiType.kokushi13, tenpai, anchor: tenpai, menjan: 0
});

export function decompTenpai(suites: ArrayLike<number>): TenpaiDecompSet {
    // kokushi before everything else
    const kokushi = k7.kokushi(suites);
    switch (kokushi) {
        case -1: break; // not kokushi
        case 13:
            return <TenpaiDecompSet>{
                decomps: kokushi13Decomps,
                tenpai: yaochuu,
            };
        default:
            return <TenpaiDecompSet>{
                decomps: kokushiDecomps[kokushi],
                tenpai: [yaochuu[kokushi]],
            };
    }

    const tenpai = new Uint16Array(4);
    const decomps: TenpaiDecomp[] = [];

    std: do {
        // tsuupai: handle specially because there can't be shuntsu
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
                    } else break std;
                    break;
                case 2:
                    if (j1 === 0) {
                        j1 = i; j1s = 3; j1n = i - 30;
                        typeZ = TenpaiType.shanpon;
                    } else if (j2 === 0) {
                        if (typeZ !== TenpaiType.shanpon) break std;
                        j2 = i; j2s = 3; j2n = i - 30;
                    } else break std;
                    break;
                case 3:
                    // populate in inverse order for direct concat with MPS later
                    mentsuZ |= i << shiftZ;
                    shiftZ += 6;
                    break;
                case 4: break std;
            }
        }
        const menjansM = lookupComplete.get(suites[0]);
        const menjansP = lookupComplete.get(suites[1]);
        const menjansS = lookupComplete.get(suites[2]);
        if (typeZ !== TenpaiType.kokushi) {
            // must be tanki Z, shanpon MPS-Z, or shanpon Z-Z
            // MPS must be complete
            if (menjansM == null || menjansP == null || menjansS == null) break std;
            // MPS must contain at most 1 pair
            const jM = menjansM[0] & 0xf, jMExist = jM !== 0;
            const jP = menjansP[0] & 0xf, jPExist = jP !== 0;
            const jS = menjansS[0] & 0xf, jSExist = jS !== 0;
            const jMPS = +jMExist + +jPExist + +jSExist;
            if (jMPS > 1) break std;
            if (jMPS === 1) {
                // MPS contain exactly 1 pair => must be shanpon MPS-Z
                if (j2 === 0) {
                    if (typeZ !== TenpaiType.shanpon) break std;

                    //////////////////////////////////////////////////////////////////////////////
                    // FIXME: this is wrong --- jM/P/S can change as we loop over menjanM/P/S
                    //////////////////////////////////////////////////////////////////////////////
                    if (jMExist) { j2 = jM; j2s = 0; j2n = jM - 1; }
                    else if (jPExist) { j2 = jP + 10; j2s = 1; j2n = jM - 1; }
                    else if (jSExist) { j2 = jS + 20; j2s = 2; j2n = jM - 1; }

                } else break std;
            }
            // loop over complete suites
            for (let iS = 0, ieS = menjansM.length; iS < ieS; ++iS) {
                const menjanS = menjansS[iS];
                const mentsuSZ = concat(mentsuZ, menjanS >> 4, 40);
                for (let iP = 0, ieP = menjansM.length; iP < ieP; ++iP) {
                    const menjanP = menjansP[iP];
                    const mentsuPSZ = concat(mentsuSZ, menjanP >> 4, 20);
                    for (let iM = 0, ieM = menjansM.length; iM < ieM; ++iM) {
                        const menjanM = menjansM[iM];
                        const mentsuMPSZ = concat(mentsuSZ, menjanM >> 4, 0);
                        switch (typeZ) {
                            case TenpaiType.tanki:
                                decomps.push({
                                    type: TenpaiType.tanki,
                                    tenpai: j1,
                                    anchor: j1,
                                    menjan: (mentsuMPSZ << 4),
                                });
                                tenpai[j1s] |= 1 << j1n;
                                break;
                            case TenpaiType.shanpon:
                                decomps.push({
                                    type: TenpaiType.shanpon,
                                    tenpai: j1,
                                    anchor: j1,
                                    menjan: (mentsuMPSZ << 4) | j2,
                                }, {
                                    type: TenpaiType.shanpon,
                                    tenpai: j2,
                                    anchor: j2,
                                    menjan: (mentsuMPSZ << 4) | j1,
                                });
                                tenpai[j1s] |= 1 << j1n;
                                tenpai[j2s] |= 1 << j2n;
                                break;
                            default:
                                throw Error("WTF");
                        }
                    }
                }
            }
        } else {

        }
    } while (false);



}
