import 'mocha';
import { assert } from 'chai';
import * as lookup from '../lib/decomp/lookup';
// import * as lookupOld from '../src-old/decomp-lookup';

describe("lookup", () => {
    it("number of entries in complete", () => {
        assert.equal(lookup.completeSuu.size, 21743);
        assert.equal(Array.from(lookup.completeSuu.values()).map(x => x.length).reduce((a, b) => a + b), 23533);
        // Sum[Binomial[7, i], {i, 0, 4}] + 7*Sum[Binomial[6, i], {i, 0, 4}] == 498
        assert.equal(lookup.completeTsuu.size, 498);
    });
    it("time", () => {
        console.log(JSON.stringify(lookup.STARTUP_TIME));
        // console.log(JSON.stringify(lookupOld.STARTUP_TIME));
    });
});
