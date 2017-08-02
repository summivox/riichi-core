import * as packedSuite from '../packed-suite';

export interface DecompCompleteEntry {
    /** -1 for no jantou; 0, 1, ..., 8 for jantou at this offset */
    jantou: number;
    /** Packed mentsu (4*7-bit) representation */
    mentsu: number;
}

export const completeAll = new Map<number, DecompCompleteEntry>();
export const completeKou = new Map<number, DecompCompleteEntry>();
