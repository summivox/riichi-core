import 'mocha';
import { assert } from 'chai';
import * as Wall from '../lib/wall';
import { randomShuffle } from '../lib/util';

describe('wall', () => {
    it('toParts', () => {
        const wall = Wall.create(1, 2, 3);
        const parts = Wall.toParts(wall);
        const {
            haipai: [e, s, w, n],
            piipai,
            rinshan,
            doraHyouji,
            uraDoraHyouji,
        } = parts;
        assert.deepEqual(e, [1, 1, 1, 1, 0, 5, 5, 5, 9, 9, 9, 9, 14] as any);
        assert.deepEqual(s, [2, 2, 2, 2, 6, 6, 6, 6, 11, 11, 11, 11, 14]);
        assert.deepEqual(w, [3, 3, 3, 3, 7, 7, 7, 7, 12, 12, 12, 12, 14]);
        assert.deepEqual(n, [4, 4, 4, 4, 8, 8, 8, 8, 13, 13, 13, 13, 14]);
        assert.deepEqual(piipai, [
            10, 10, 15, 15, 16, 16, 16, 16, 17, 17,
            17, 17, 18, 18, 18, 18, 19, 19, 19, 19,
            21, 21, 21, 21, 22, 22, 22, 22, 23, 23,
            23, 23, 24, 24, 24, 24, 20, 20, 20, 25,
            26, 26, 26, 26, 27, 27, 27, 27, 28, 28,
            28, 28, 29, 29, 29, 29, 30, 30, 30, 30,
            31, 31, 31, 31, 32, 32, 32, 32, 33, 33,
        ].reverse());
        assert.deepEqual(doraHyouji, [35, 35, 34, 34, 33]);
        assert.deepEqual(uraDoraHyouji, [35, 35, 34, 34, 33]);
        assert.deepEqual(rinshan, [36, 36, 36, 36]);
    });

    it('fromParts', () => {
        const wall = Wall.create(2, 1, 0);
        const wallR = randomShuffle(wall);
        const parts = Wall.toParts(wallR);
        const wallR2 = Wall.fromParts(parts);
        assert.deepEqual(wallR2, wallR);
    });
});
