const enum Literal {
    MASK = 0b1111111,
}

export function toArray(ms: number) {
    const result = new Array<number>();
    while (true) {
        const m = ms & Literal.MASK;
        if (m === Literal.MASK) {
            return result;
        }
        result.push(m);
        ms >>>= 7;
    }
}

export function addSuite(x: number, suite: number) {
    // TODO
}
