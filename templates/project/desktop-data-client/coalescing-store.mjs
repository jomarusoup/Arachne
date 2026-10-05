/*#############################################################################
FILE NAME   : coalescing-store.mjs
DESCRIPTION : 키별 최신값 병합 스토어 — 화면 주기마다 한 번 반영·통지 (useSyncExternalStore 호환)
DATA        : 2026-10-06
Modification: 2026-10-06
#############################################################################*/

/*-----------------------------------------------------------------------------
손실 정책: 최신값 병합이다. 한 주기 안에 같은 키가 여러 번 오면 마지막 값만 남는다.
병합으로 버린 건수는 Stats().merged로 센다. 전량 보존이 필요한 채널에는 쓰지 않는다.
값 객체는 불변으로 다룬다. 갱신은 새 객체로 Put한다.
-----------------------------------------------------------------------------*/
const FRAME_INTERVAL_MS = 16;

/*=============================================================================
FUNCTION    : DefaultSchedule
DESCRIPTION : 렌더러에서는 requestAnimationFrame, 그 밖에서는 16ms 타이머로 예약한다
PARAMETERS  : function callback - 다음 화면 주기에 부를 함수
=============================================================================*/
function DefaultSchedule(callback) {
    if (typeof globalThis.requestAnimationFrame === "function") {
        globalThis.requestAnimationFrame(() => callback());
        return;
    }
    setTimeout(callback, FRAME_INTERVAL_MS);
}

/*=============================================================================
FUNCTION    : DefaultListenerError
DESCRIPTION : 구독자 예외를 운영 경고로 남긴다. 다른 구독자 통지는 계속한다.
PARAMETERS  : unknown error - 구독자가 던진 값
=============================================================================*/
function DefaultListenerError(error) {
    console.error("[desktop-data-client] 구독자 오류", error);
}

export class CoalescingStore {
    #pending   = new Map();
    #spare     = new Map();
    #values    = new Map();
    #listeners = new Set();
    #version   = 0;
    #scheduled = false;
    #merged    = 0;
    #applied   = 0;
    #schedule;
    #onListenerError;

    /*=========================================================================
    FUNCTION    : constructor
    PARAMETERS  : function options.schedule        - 주기 예약 함수 (기본 rAF 또는 16ms)
                  function options.onListenerError - 구독자 예외 처리 (기본 console.error)
    =========================================================================*/
    constructor({ schedule = DefaultSchedule, onListenerError = DefaultListenerError } = {}) {
        this.#schedule        = schedule;
        this.#onListenerError = onListenerError;
    }

    /*=========================================================================
    FUNCTION    : Put
    DESCRIPTION : 키의 새 값을 대기열에 둔다. 같은 키의 대기 값은 덮어쓴다.
                  주기 예약은 대기열이 빌 때까지 한 번만 한다.
    PARAMETERS  : unknown key   - 행 키 (정수 ID 권장)
                  unknown value - 불변 값 객체
    =========================================================================*/
    Put(key, value) {
        if (this.#pending.has(key)) {
            this.#merged++;
        }
        this.#pending.set(key, value);
        if (!this.#scheduled) {
            this.#scheduled = true;
            this.#schedule(this.#Flush);
        }
    }

    Get(key) {
        return this.#values.get(key);
    }

    /*=========================================================================
    FUNCTION    : Subscribe
    DESCRIPTION : 주기 반영 후 통지받을 구독자를 등록한다. 떼어 넘겨도 되게 화살표 함수다.
                  changed는 이번 주기에 바뀐 키와 값의 Map이다. 통지 동안만 유효하다.
    PARAMETERS  : function listener - (changed: Map<key, value>) => void
    RETURNED    : 구독 해제 함수
    =========================================================================*/
    Subscribe = (listener) => {
        this.#listeners.add(listener);
        return () => { this.#listeners.delete(listener); };
    };

    /*=========================================================================
    FUNCTION    : GetSnapshot
    DESCRIPTION : 반영 횟수(버전)를 돌려준다. 반영이 없으면 같은 값이므로 불필요한 렌더가 없다.
    RETURNED    : 정수 버전
    =========================================================================*/
    GetSnapshot = () => this.#version;

    Stats() {
        return { merged: this.#merged, applied: this.#applied, pending: this.#pending.size };
    }

    /*=========================================================================
    FUNCTION    : #Flush
    DESCRIPTION : 대기 값을 한 번에 반영하고 구독자에게 한 번 통지한다.
                  대기 Map 두 개를 번갈아 써서 주기마다 Map을 새로 만들지 않는다.
    =========================================================================*/
    #Flush = () => {
        this.#scheduled = false;
        if (this.#pending.size === 0) {
            return;
        }
        const changed = this.#pending;
        this.#pending = this.#spare;

        for (const [key, value] of changed) {
            this.#values.set(key, value);
        }
        this.#applied += changed.size;
        this.#version++;

        for (const listener of this.#listeners) {
            try {
                listener(changed);
            } catch (error) {
                this.#onListenerError(error);
            }
        }
        changed.clear();
        this.#spare = changed;
    };
}
