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
        // start with tsuupai
        let suiteZ = suites[3];
        let z1 = 0, z2 = 0;
        let mentsuZ = 0;
        for (let i = 30; suiteZ !== 0; ++i, suiteZ >>= 3) {
            switch (suiteZ & 0o7) {
                case 0: break;
                case 1:
                    if (z2 >= 1 && ++z1 >= 2) break std;
                    break;
                case 2:
                    if (z1 >= 1 && ++z2 >= 2) break std;
                    break;
                case 3:
                    mentsuZ = (mentsuZ << 6) | (i << 1);
                    break;
                case 4: break std;
            }
        }
        // const suiteM = suites[0], suiteP = suites[1], suiteS = suites[2];
    } while (false);



}
