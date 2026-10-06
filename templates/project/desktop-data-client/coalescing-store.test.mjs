/*#############################################################################
FILE NAME   : coalescing-store.test.mjs
DESCRIPTION : CoalescingStore 계약 테스트 — 키별 최신값 병합·주기 통지·스냅샷 안정성
#############################################################################*/

import { test } from "node:test";
import assert from "node:assert/strict";

import { CoalescingStore } from "./coalescing-store.mjs";

/*=============================================================================
FUNCTION    : ManualScheduler
DESCRIPTION : 테스트가 직접 "화면 주기"를 돌리는 스케줄러를 만든다
RETURNED    : { schedule, Tick, Pending } — schedule은 스토어 옵션으로 넘긴다
=============================================================================*/
function ManualScheduler() {
    let queued = [];
    return {
        schedule: (callback) => { queued.push(callback); },
        Tick: () => {
            const run = queued;
            queued = [];
            run.forEach((callback) => callback());
        },
        Pending: () => queued.length,
    };
}

test("같은_키를_여러_번_넣으면_주기마다_최신값_하나만_반영", () => {
    /* Arrange */
    const clock = ManualScheduler();
    const store = new CoalescingStore({ schedule: clock.schedule });

    /* Act */
    store.Put("A", { price: 100n });
    store.Put("A", { price: 101n });
    store.Put("A", { price: 102n });
    store.Put("B", { price: 7n });
    clock.Tick();

    /* Assert */
    assert.deepEqual(store.Get("A"), { price: 102n });
    assert.deepEqual(store.Get("B"), { price: 7n });
    assert.equal(store.Stats().merged, 2);
    assert.equal(store.Stats().applied, 2);
});

test("주기_전에는_값이_보이지_않고_예약은_한_번만", () => {
    /* Arrange */
    const clock = ManualScheduler();
    const store = new CoalescingStore({ schedule: clock.schedule });

    /* Act */
    store.Put("A", 1);
    store.Put("B", 2);

    /* Assert */
    assert.equal(store.Get("A"), undefined);
    assert.equal(clock.Pending(), 1);
});

test("구독자는_주기마다_한_번_통지받고_바뀐_키를_받는다", () => {
    /* Arrange */
    const clock   = ManualScheduler();
    const store   = new CoalescingStore({ schedule: clock.schedule });
    const changes = [];
    store.Subscribe((changed) => { changes.push([...changed.keys()].sort()); });

    /* Act */
    store.Put("B", 1);
    store.Put("A", 1);
    store.Put("A", 2);
    clock.Tick();
    clock.Tick();   /* 대기 중인 갱신이 없으면 통지하지 않는다 */

    /* Assert */
    assert.deepEqual(changes, [["A", "B"]]);
});

test("스냅샷_버전은_반영_사이에_같은_값을_유지", () => {
    /* Arrange */
    const clock  = ManualScheduler();
    const store  = new CoalescingStore({ schedule: clock.schedule });
    const before = store.GetSnapshot();

    /* Act */
    store.Put("A", 1);
    const pending = store.GetSnapshot();
    clock.Tick();
    const after = store.GetSnapshot();

    /* Assert — useSyncExternalStore는 바뀌지 않았으면 같은 값을 기대한다 */
    assert.equal(pending, before);
    assert.notEqual(after, before);
    assert.equal(store.GetSnapshot(), after);
});

test("구독_해제_후에는_통지받지_않는다", () => {
    /* Arrange */
    const clock       = ManualScheduler();
    const store       = new CoalescingStore({ schedule: clock.schedule });
    let   calls       = 0;
    const unsubscribe = store.Subscribe(() => { calls++; });

    /* Act */
    unsubscribe();
    store.Put("A", 1);
    clock.Tick();

    /* Assert */
    assert.equal(calls, 0);
});

test("메서드를_떼어_넘겨도_동작한다_useSyncExternalStore_형태", () => {
    /* Arrange */
    const clock = ManualScheduler();
    const store = new CoalescingStore({ schedule: clock.schedule });
    const { Subscribe, GetSnapshot } = store;
    let   seen  = -1;

    /* Act */
    Subscribe(() => { seen = GetSnapshot(); });
    store.Put("A", 1);
    clock.Tick();

    /* Assert */
    assert.equal(seen, store.GetSnapshot());
});

test("한_통지자가_던져도_나머지_구독자는_통지받는다", () => {
    /* Arrange */
    const clock = ManualScheduler();
    const store = new CoalescingStore({ schedule: clock.schedule, onListenerError: () => {} });
    let   calls = 0;
    store.Subscribe(() => { throw new Error("구독자 오류"); });
    store.Subscribe(() => { calls++; });

    /* Act */
    store.Put("A", 1);
    clock.Tick();

    /* Assert */
    assert.equal(calls, 1);
});

test("기본_스케줄러로도_약_16ms_뒤_반영된다", async () => {
    /* Arrange */
    const store = new CoalescingStore();

    /* Act */
    store.Put("A", 1);
    await new Promise((resolve) => { store.Subscribe(resolve); });

    /* Assert */
    assert.equal(store.Get("A"), 1);
});
