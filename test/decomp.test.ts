import 'mocha';
import { assert } from 'chai';
import * as lookup from '../lib/decomp/lookup';
// import * as lookupOld from '../src-old/decomp-lookup';

describe("lookup", () => {
    it("number of entries in complete", () => {
        assert.equal(lookup.completeAll.size, 21743);
        assert.equal(Array.from(lookup.completeAll.values()).map(x => x.length).reduce((a, b) => a + b), 23533);
    });
    it("time", () => {
        console.log(JSON.stringify(lookup.STARTUP_TIME));
        // console.log(JSON.stringify(lookupOld.STARTUP_TIME));
    });
});
