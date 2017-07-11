export interface DecompCompleteEntry {
    shuntsu: number;
    jantou: null | number;
    mentsu: ReadonlyArray<number>;
}

export type TenpaiTypeMentsu = 'tanki' | 'shanpon' | 'kanchan' | 'penchan' | 'ryanmen';
export type TenpaiTypeK7 =  'chiitoi' | 'kokushi' | 'kokushi13';
export type K7 = 'kokushi' | 'chiitoi';
export type TenpaiType = TenpaiTypeMentsu | TenpaiTypeK7;

export interface DecompWaitingEntry {
    /** index into decomp1C */
    binC: number;
    cs: ReadonlyArray<DecompCompleteEntry>;
    hasJantou: boolean;
    allHasShuntsu: boolean;
    tenpaiType: TenpaiType;
}

declare const STARTUP_TIME: {c: number, w: number, cw: number};

export interface DecompTenpai {
    mentsu: ReadonlyArray<number>,
    jantou: null | number,
    k7: K7,
    tenpai: number,
    anchor: number,
}

declare function decompTenpai(bins: ArrayLike<number>): {
    decomps: ReadonlyArray<DecompTenpai>,
    tenpaiSet: ReadonlyArray<number>,
};
