import 'mocha';
import { assert } from 'chai';
import * as lookup from '../lib/decomp/lookup';

describe("lookup", () => {
    it("startup time", () => {
        console.log(JSON.stringify(lookup.STARTUP_TIME));
    });
    it("number of entries in complete table", () => {
        assert.equal(lookup.complete.size, 21743);
        assert.equal(Array.from(lookup.complete.values()).map(x => x.length).reduce((a, b) => a + b), 23533);
    });
    it("number of entries in waiting table", () => {
        assert.equal(lookup.waiting.size, 66913);
    });
});

