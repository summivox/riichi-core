import { Pai } from "../pai";
import { TenpaiType } from "./tenpai-type";
import * as k7 from './k7';
import * as lookup from "./lookup";
const {complete: lookupComplete, waiting: lookupWaiting} = lookup;

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

export function decompTenpai(suites: ArrayLike<number>) {
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

    std: do {
        // tsuupai: handle specially because there can't be shuntsu
        let suiteZ = suites[3];
        let typeZ = TenpaiType.kokushi; // use obviously invalid for default
        let j1 = 0, j2 = 0;
        let mentsuZ = 0;
        for (let i = 30; suiteZ !== 0; ++i, suiteZ >>= 3) {
            switch (suiteZ & 0o7) {
                case 0: break;
                case 1:
                    if (j1 === 0) {
                        j1 = i;
                        typeZ = TenpaiType.tanki;
                    } else break std;
                    break;
                case 2:
                    if (j1 === 0) {
                        j1 = i;
                        typeZ = TenpaiType.shanpon;
                    } else if (j2 === 0) {
                        if (typeZ !== TenpaiType.shanpon) break std;
                        j2 = i;
                    } else break std;
                    break;
                case 3:
                    // INLINE: packedMentsu.push(mentsuZ, i, 0)
                    mentsuZ = (mentsuZ << 6) | (i << 1);
                    break;
                case 4: break std;
            }
        }
        const csM = lookupComplete.get(suites[0]);
        const csP = lookupComplete.get(suites[1]);
        const csS = lookupComplete.get(suites[2]);
        if (typeZ !== TenpaiType.kokushi) {
            // must be tanki Z, shanpon MPS-Z, or shanpon Z-Z
            // MPS must be complete
            if (csM == null || csP == null || csS == null) break std;
            // MPS must contain at most 1 pair
            const jM = csM[0] & 0xf;
            const jP = csP[0] & 0xf;
            const jS = csS[0] & 0xf;
            const jMPS = +(jM !== 0) + +(jP !== 0) + +(jS !== 0);
            if (jMPS > 1) break std;
            // MPS contain exactly 1 pair => must be shanpon MPS-Z
            if (jMPS === 1) {
                if (j2 === 0) {
                    if (typeZ !== TenpaiType.shanpon) break std;
                    j2 = jM + jP + jS;
                } else break std;
            }
        } else {

        }
    } while (false);



}
