export interface DecompCompleteEntry {
    shuntsu: number;
    jantou: null | number;
    mentsu: ReadonlyArray<number>;
}

declare const decomp1C: ReadonlyArray<DecompCompleteEntry>;

export const enum TenpaiType {
    tanki = 'tanki',
    shanpon = 'shanpon',
    kanchan = 'kanchan',
    penchan = 'penchan',
    ryanmen = 'ryanmen',
    chiitoi = 'chiitoi',
    kokushi = 'kokushi',
    kokushi13 = 'kokushi13',
}

export interface DecompWaitingEntry {
    /** index into decomp1C */
    binC: number;
    cs: ReadonlyArray<DecompCompleteEntry>;
    hasJantou: boolean;
    allHasShuntsu: boolean;
    tenpaiType: TenpaiType;
}

declare const decomp1W: ReadonlyArray<DecompWaitingEntry>;

/** lookup computation time in nanoseconds */
declare const STARTUP_TIME: {
    /** time to build decomp1C */
    c: number,
    /** time to build decomp1W */
    w: number,
    /** time to build decomp1C and decomp1W */
    cw: number,
};
