import { Pai } from "../pai";
import * as packedSuite from '../packed-suite';
const {add: suiteAdd, isOverflow: suiteOverflow, get: suiteGet} = packedSuite;
import * as packedMentsu from '../packed-mentsu';
const {push: mentsuPush, pop: mentsuPop} = packedMentsu;
import * as now from 'performance-now';

/*
 * NOTE: The lookup tables are used only internally for accelerating decomposition algorithm,
 * which makes it hard to describe tables without also describing the algorithm.
 */

export interface DecompCompleteEntry {
    /** 0 for no jantou; 1, 2, 3, ..., 9 for jantou */
    jantou: Pai;
    /** Packed mentsu (4*7-bit) */
    mentsu: number;
    /** # of mentsu */
    nMentsu: number;
    /** if `mentsu` contains any shuntsu */
    hasShuntsu: boolean;
}

/** map from packed suite (9*3-bit octal) to ways to decompose it into (koutsu + shuntsu + jantou) */
export const completeAll = new Map<number, ReadonlyArray<DecompCompleteEntry>>();
/** map from packed suite (9*3-bit octal) to ways to decompose it into (koutsu + jantou) */
export const completeKou = new Map<number, ReadonlyArray<DecompCompleteEntry>>();

export type TenpaiType = 'tanki' | 'shanpon' | 'kanchan' | 'penchan' | 'ryanmen';
export interface DecompWaitingEntry {
    complete: ReadonlyArray<DecompCompleteEntry>;
    hasJantou: boolean;
    allHasShuntsu: boolean;
    tenpaiType: TenpaiType;
    tenpai: Pai;
    anchor: Pai;
}

export const waiting = new Map<number, ReadonlyArray<DecompWaitingEntry>>();

function makeComplete() {
    let jantou = 0;
    function dfsKou(n: number, i: number, suite: number, mentsu: number) {
        for (; i < 9; ++i) {
            const newSuite = suiteAdd(suite, 0o3, i);
            if (suiteOverflow(newSuite)) continue;
            const newMentsu = mentsuPush(mentsu, false, i + 1);
            const entry: DecompCompleteEntry = {jantou, mentsu: newMentsu, nMentsu: n, hasShuntsu: false};
            if (completeKou.has(newSuite)) {
                (completeKou.get(newSuite) as DecompCompleteEntry[]).push(entry);
            } else {
                completeKou.set(newSuite, [entry]);
            }
            if (completeAll.has(newSuite)) {
                (completeAll.get(newSuite) as DecompCompleteEntry[]).push(entry);
            } else {
                completeAll.set(newSuite, [entry]);
            }
            if (n < 4) {
                dfsKou(n + 1, i + 1, newSuite, newMentsu);
                dfsShun(n + 1, 0, newSuite, newMentsu);
            }
        }
    }
    function dfsShun(n: number, i: number, suite: number, mentsu: number) {
        for (; i < 7; ++i) {
            const newSuite = suiteAdd(suite, 0o111, i);
            if (suiteOverflow(newSuite)) continue;
            const newMentsu = mentsuPush(mentsu, true, i + 1);
            const entry: DecompCompleteEntry = {jantou, mentsu: newMentsu, nMentsu: n, hasShuntsu: true};
            if (completeAll.has(newSuite)) {
                (completeAll.get(newSuite) as DecompCompleteEntry[]).push(entry);
            } else {
                completeAll.set(newSuite, [entry]);
            }
            if (n < 4) {
                dfsShun(n + 1, i, newSuite, newMentsu);
            }
        }
    }
    completeKou.set(0, [{jantou: -1, mentsu: 0, nMentsu: 0, hasShuntsu: false}]);
    completeAll.set(0, [{jantou: -1, mentsu: 0, nMentsu: 0, hasShuntsu: false}]);
    dfsKou(1, 0, 0, 0);
    dfsShun(1, 0, 0, 0);
    let suiteJantou = 0o2;
    for (jantou = 1; jantou <= 9; ++jantou, suiteJantou <<= 3) {
        completeKou.set(suiteJantou, [{jantou, mentsu: 0, nMentsu: 0, hasShuntsu: false}]);
        completeAll.set(suiteJantou, [{jantou, mentsu: 0, nMentsu: 0, hasShuntsu: false}]);
        dfsKou(1, 0, suiteJantou, 0);
        dfsShun(1, 0, suiteJantou, 0);
    }
}

function makeWaiting() {
    for (const [suiteComplete, complete] of completeAll.entries()) {
        makeWaitingFromOneComplete(suiteComplete, complete);
    }
}

function makeWaitingFromOneComplete(suiteComplete, complete) {
    const {jantou, nMentsu} = complete[0];
    let hasJantou = jantou > 0;
    // EXPAND: let allHasShuntsu = complete.every(c => c.hasShuntsu);
    let allHasShuntsu = true;
    for (let i = 0, ie = complete.length; i < ie; ++i) {
        if (!complete[i].hasShuntsu) {
            allHasShuntsu = false;
            break;
        }
    }
    if (!hasJantou) {
        hasJantou = true;
        for (let i = 1; i <= 9; ++i) expand('tanki', 0o1, 0, 0, i);
        hasJantou = false;
    }
    if (nMentsu < 4) {
        for (let i = 1; i <= 9; ++i) expand('shanpon', 0o2, 0, 0, i);
        allHasShuntsu = true;
        for (let i = 1; i <= 7; ++i) expand('kanchan', 0o101, 1, 0, i);
        expand('penchan', 0o11, 2, 0, 0);
        for (let i = 2; i <= 7; ++i) {
            expand('ryanmen', 0o11, -1, -1, i);
            expand('ryanmen', 0o11, 2, 0, i);
        }
        expand('penchan', 0o11, -1, -1, 8);
    }
    function expand(tenpaiType, pat, dTenpai, dAnchor, i) {
        const suite = suiteAdd(suiteComplete, pat, i - 1);
        const tenpai = i + dTenpai;
        const anchor = i + dAnchor;
        if (!suiteOverflow(suite) && suiteGet(suite, tenpai - 1) < 4) {
            const entry: DecompWaitingEntry = {
                complete, hasJantou, allHasShuntsu,
                tenpaiType, tenpai, anchor,
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
