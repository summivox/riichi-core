import * as packedSuite from '../packed-suite';
import * as packedMentsu from '../packed-mentsu';
import * as now from 'performance-now';

const {add: suiteAdd, isOverflow: suiteOverflow} = packedSuite;
const {push: mentsuPush, pop: mentsuPop} = packedMentsu;

export interface DecompCompleteEntry {
    /** 0 for no jantou; 1, 2, 3, ..., 9 for jantou at this offset */
    jantou: number;
    /** Packed mentsu (4*7-bit) representation */
    mentsu: number;
}

/** map from packed suite (9*3-bit octal) to ways to decompose it into (koutsu + shuntsu + jantou) */
export const completeAll = new Map<number, ReadonlyArray<DecompCompleteEntry>>();
/** map from packed suite (9*3-bit octal) to ways to decompose it into (koutsu + jantou) */
export const completeKou = new Map<number, ReadonlyArray<DecompCompleteEntry>>();

export function makeComplete() {
    // TODO: jantou: (-1, 0 to 8) => (-1, 1 to 9) for consistency
    let jantou = 0;
    function dfsKou(n: number, i: number, suite: number, mentsu: number) {
        for (; i < 9; ++i) {
            const newSuite = suiteAdd(suite, 0o3, i);
            if (suiteOverflow(newSuite)) continue;
            const newMentsu = mentsuPush(mentsu, false, i + 1);
            const entry: DecompCompleteEntry = {jantou, mentsu: newMentsu};
            /*
            if (completeKou.has(newSuite)) {
                (completeKou.get(newSuite) as DecompCompleteEntry[]).push(entry);
            } else {
                completeKou.set(newSuite, [entry]);
            }
            */
            if (completeAll.has(newSuite)) {
                (completeAll.get(newSuite) as DecompCompleteEntry[]).push(entry);
            } else {
                completeAll.set(newSuite, [entry]);
            }
            if (n < 3) {
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
            const entry: DecompCompleteEntry = {jantou, mentsu: newMentsu};
            if (completeAll.has(newSuite)) {
                (completeAll.get(newSuite) as DecompCompleteEntry[]).push(entry);
            } else {
                completeAll.set(newSuite, [entry]);
            }
            if (n < 3) {
                dfsShun(n + 1, i, newSuite, newMentsu);
            }
        }
    }
    completeKou.set(0, [{jantou: -1, mentsu: 0}]);
    completeAll.set(0, [{jantou: -1, mentsu: 0}]);
    dfsKou(0, 0, 0, 0);
    dfsShun(0, 0, 0, 0);
    let suiteJantou = 0o2;
    for (jantou = 1; jantou <= 9; ++jantou, suiteJantou <<= 3) {
        completeKou.set(suiteJantou, [{jantou, mentsu: 0}]);
        completeAll.set(suiteJantou, [{jantou, mentsu: 0}]);
        dfsKou(0, 0, suiteJantou, 0);
        dfsShun(0, 0, suiteJantou, 0);
    }
}

const t0 = now();
makeComplete();
const t1 = now();
console.log((t1 - t0).toFixed(2));
