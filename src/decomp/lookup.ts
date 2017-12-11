import { Pai } from "../pai";
import { TenpaiType } from "./tenpai-type";
import * as packedSuite from '../packed-suite';
const {isOverflow: suiteOverflow, add: suiteAdd, get: suiteGet} = packedSuite;
import * as packedMentsu from '../packed-mentsu';
const {pushKoutsu, pushShuntsu, pushJantou} = packedMentsu;
import now = require('performance-now');

/** map from packed suite (9*3-bit octal) to ways to decompose it into (koutsu + shuntsu + jantou) */
export const complete = new Map<number, ArrayLike<number>>();

export interface DecompWaitingEntry {
    menjans: ArrayLike<number>;
    hasJantou: boolean;
    tenpaiType: TenpaiType;
    tenpai: Pai;
    anchor: Pai;
}

export const waiting = new Map<number, ReadonlyArray<DecompWaitingEntry>>();

function makeComplete() {
    let jantou = 0;
    function dfsKou(n: number, i: Pai, suite: number, ms: number) {
        for (; i <= 9; ++i) {
            const newSuite = suiteAdd(suite, 0o3, i - 1)
            if (suiteOverflow(newSuite)) continue;
            const newMs = pushKoutsu(ms, i);
            const entry = pushJantou(newMs, jantou);
            if (complete.has(newSuite)) {
                (complete.get(newSuite) as number[]).push(entry);
            } else {
                complete.set(newSuite, [entry]);
            }
            if (n < 4) {
                dfsKou(n + 1, i + 1, newSuite, newMs);
                dfsShun(n + 1, 1, newSuite, newMs);
            }
        }
    }
    function dfsShun(n: number, i: Pai, suite: number, ms: number) {
        for (; i <= 7; ++i) {
            const newSuite = suiteAdd(suite, 0o111, i - 1)
            if (suiteOverflow(newSuite)) continue;
            const newMs = pushShuntsu(ms, i);
            const entry = pushJantou(newMs, jantou);
            if (complete.has(newSuite)) {
                (complete.get(newSuite) as number[]).push(entry);
            } else {
                complete.set(newSuite, [entry]);
            }
            if (n < 4) {
                dfsShun(n + 1, i, newSuite, newMs);
            }
        }
    }
    complete.set(0, [0]);
    dfsKou(1, 1, 0, 0);
    dfsShun(1, 1, 0, 0);
    let suiteJantou = 0o2;
    for (jantou = 1; jantou <= 9; ++jantou, suiteJantou <<= 3) {
        complete.set(suiteJantou, [jantou]);
        dfsKou(1, 1, suiteJantou, 0);
        dfsShun(1, 1, suiteJantou, 0);
    }
}

function makeWaiting() {
    for (const [suite, cs] of complete.entries()) {
        makeWaitingFromOneComplete(suite, cs);
    }
}

function makeWaitingFromOneComplete(suiteComplete: number, menjans: ArrayLike<number>) {
    const menjan = menjans[0];
    let hasJantou = (menjan & 0xf) !== 0;
    if (!hasJantou) {
        hasJantou = true;
        for (let i = 1; i <= 9; ++i) expand(TenpaiType.tanki, 0o1, 0, 0, i);
        hasJantou = false;
    }
    const mentsu = menjan >> 4;
    if (mentsu < 0o777777) {
        // only 3 or less mentsu in complete part
        // try add mentsu-based tenpai pattern
        for (let i = 1; i <= 9; ++i) expand(TenpaiType.shanpon, 0o2, 0, 0, i);
        for (let i = 1; i <= 7; ++i) expand(TenpaiType.kanchan, 0o101, 1, 0, i);
        expand(TenpaiType.penchan, 0o11, 2, 0, 1);
        for (let i = 2; i <= 7; ++i) {
            expand(TenpaiType.ryanmen, 0o11, -1, -1, i);
            expand(TenpaiType.ryanmen, 0o11, 2, 0, i);
        }
        expand(TenpaiType.penchan, 0o11, -1, -1, 8);
    }
    function expand(tenpaiType: TenpaiType, pat: number, dTenpai: number, dAnchor: number, i: Pai) {
        const suite = suiteComplete + (pat << (3 * (i - 1))); // INLINE: packedSuite.add(suiteComplete, pat, i - 1)
        const tenpai = i + dTenpai;
        const anchor = i + dAnchor;
        if (!suiteOverflow(suite) && suiteGet(suite, tenpai - 1) < 4) {
            const entry = <DecompWaitingEntry>{
                menjans, hasJantou, tenpaiType, tenpai, anchor
            };
            if (waiting.has(suite)) {
                (waiting.get(suite) as DecompWaitingEntry[]).push(entry);
            } else {
                waiting.set(suite, [entry]);
            }
        }
    }
}

const t0 = now();
makeComplete();
const t1 = now();
makeWaiting();
const t2 = now();

export const STARTUP_TIME = {
    c: t1 - t0,
    w: t2 - t1,
    cw: t2 - t0,
};

/*
import { writeFileSync } from 'fs';
import * as path from 'path';
const completeKeys =
    Array.from(complete.keys())
        .sort((a, b) => a - b)
        .map(x => x.toString(8).padStart(9, '0'))
        .join('\n');
writeFileSync(path.join(__dirname, '../../test/data/decomp/lookup/c-keys-uniq.txt'), completeKeys, 'utf-8');
const waitingKeys =
    Array.from(waiting.keys())
        .sort((a, b) => a - b)
        .map(x => x.toString(8).padStart(9, '0'))
        .join('\n');
writeFileSync(path.join(__dirname, '../../test/data/decomp/lookup/w-keys-uniq.txt'), waitingKeys, 'utf-8');
*/
