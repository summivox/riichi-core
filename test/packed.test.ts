import 'mocha';
import { assert } from 'chai';
import * as PM from '../lib/packed-mentsu';
const {sort} = PM;

describe("packed-mentsu", () => {
    it("sort", () => {
        for (let x = 0o0100; x <= 0o7777; ++x) {
            let ms = x;
            let a0 = ms & 0o77; ms >>= 6;
            let a1 = ms;
            [a0, a1] = [a0, a1].sort((a, b) => a - b);
            const y = a0 | (a1 << 6);
            if (sort(x) !== y) {
                console.assert(false,
                    "x = " + x.toString(8).padStart(8, '0') + ", " +
                    "y = " + y.toString(8).padStart(8, '0'));
            }
        }
        for (let x = 0o010000; x <= 0o777777; ++x) {
            let ms = x;
            let a0 = ms & 0o77; ms >>= 6;
            let a1 = ms & 0o77; ms >>= 6;
            let a2 = ms;
            [a0, a1, a2] = [a0, a1, a2].sort((a, b) => a - b);
            const y = a0 | (a1 << 6) | (a2 << 12);
            if (sort(x) !== y) {
                console.assert(false,
                    "x = " + x.toString(8).padStart(8, '0') + ", " +
                    "y = " + y.toString(8).padStart(8, '0'));
            }
        }
        for (let x = 0o01000000; x <= 0o77777777; ++x) {
            let ms = x;
            let a0 = ms & 0o77; ms >>= 6;
            let a1 = ms & 0o77; ms >>= 6;
            let a2 = ms & 0o77; ms >>= 6;
            let a3 = ms;
            [a0, a1, a2, a3] = [a0, a1, a2, a3].sort((a, b) => a - b);
            const y = a0 | (a1 << 6) | (a2 << 12) | (a3 << 18);
            if (sort(x) !== y) {
                console.assert(false,
                    "x = " + x.toString(8).padStart(8, '0') + ", " +
                    "y = " + y.toString(8).padStart(8, '0'));
            }
        }
    });
});
