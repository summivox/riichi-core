import * as packedSuite from '../packed-suite';

export interface DecompCompleteEntry {
    /** 0 for no jantou; 1, 2, 3, ..., 9 for jantou at this offset */
    jantou: number;
    /** Packed mentsu (4*7-bit) representation */
    mentsu: number;
}

/** map from packed suite (9*3-bit octal) to ways to decompose it into (koutsu + shuntsu + jantou) */
export const completeAll = new Map<number, ReadonlyArray<DecompCompleteEntry>>();
/** map from packed suite (9*3-bit octal) to ways to decompose it into (koutsu + jantou) */
export const completeKou = new Map<number, ReadonlyArray<DecompCompleteEntry>>();

export function makeComplete() {
    let jantou = -1;

}
