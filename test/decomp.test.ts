import 'mocha';
import { assert } from 'chai';
import * as lookup from '../lib/decomp/lookup';
import * as lookupOld from '../src-old/decomp-lookup';

describe("lookup", () => {
    it("time", () => {
        console.log(lookup.STARTUP_TIME.c.toFixed(3));
        console.log(lookupOld.STARTUP_TIME.c.toFixed(3));
    });
});
