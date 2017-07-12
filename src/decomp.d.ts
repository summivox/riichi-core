export interface DecompTenpai {
    mentsu: ReadonlyArray<number>,
    jantou: null | number,
    k7: 'kokushi' | 'chiitoi',
    tenpai: number,
    anchor: number,
}

declare function decompTenpai(bins: ArrayLike<number>): {
    decomps: ReadonlyArray<DecompTenpai>,
    tenpaiSet: ReadonlyArray<number>,
};
