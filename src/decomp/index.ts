import { Pai } from "../pai";
import { TenpaiType } from "./tenpai-type";
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

export function decompTenpai(suites: ArrayLike<number>) {
    const decomps: TenpaiDecomp[] = [];
    const tenpai = new Uint16Array(4);
}
