; ------------------------------------------------------------------------------
; Scan Master
; Single timer ticks at SCAN_MASTER_INTERVAL_MS and dispatches to every
; subsystem registered as a scanner. Each tick takes at most one PrintWindow
; capture (lazily, only if a subscriber asks for one) and one ImageSearch per
; needle. Subsystems migrate from their own SetTimer to RegisterScanner +
; threading the shared ScanContext through their search calls.
;
; Same-tick semantics:
;   - Subscribers run sequentially in registration order.
;   - The PrintWindow capture is reused across every FindPrintWindow call
;     within one tick. If a subscriber clicks something, later subscribers
;     in the same tick see pre-click pixels. Call ctx.Invalidate() if a
;     subsystem needs a fresh capture mid-tick.
;   - The static `running` flag prevents same-timer re-entry across ticks.
;     The AHK v2 scheduler also drops re-entrant fires by default, so this
;     is belt-and-suspenders.
; ------------------------------------------------------------------------------

global SCAN_MASTER_INTERVAL_MS := 100

; Registered scanners. Each entry: { interval: ms, lastTick: 0, fn: callback(ctx) }
global g_scanSubscribers := []

; Register a scanner. `fn` is called with a ScanContext instance every time
; `intervalMs` has elapsed since its last fire. Order of registration is the
; order subscribers run within a tick.
RegisterScanner(intervalMs, fn) {
    global g_scanSubscribers
    g_scanSubscribers.Push({ interval: intervalMs, lastTick: 0, fn: fn })
}

class ScanContext {
    cap := 0  ; lazy PrintWindow capture; 0 = not taken yet or already released

    EnsureCapture() {
        if !this.cap
            this.cap := CaptureRobloxWindow()
        return this.cap
    }

    ; Search via PrintWindow capture. Works even if Roblox is backgrounded.
    ; Returns { x, y } screen-coord match center, or false.
    FindPrintWindow(imagePath, variation, region := "") {
        cap := this.EnsureCapture()
        if !cap
            return false
        return SearchCapture(cap, imagePath, variation, region)
    }

    ; Search via native ImageSearch on the live screen. Faster per scan but
    ; requires Roblox visible. Same { x, y } return shape.
    FindLive(imagePath, variation, region := "") {
        return FindPathTrigger(imagePath, variation, region)
    }

    ; Discard the current capture so the next FindPrintWindow takes a fresh
    ; one. Use after a click when a later subsystem in the same tick must
    ; not see stale pixels.
    Invalidate() {
        if this.cap {
            ReleaseCapture(this.cap)
            this.cap := 0
        }
    }

    Release() {
        this.Invalidate()
    }
}

ScanMasterTick() {
    global g_scanSubscribers
    static running := false
    if running
        return
    running := true
    try {
        now := A_TickCount
        toRun := []
        for sub in g_scanSubscribers {
            if (now - sub.lastTick >= sub.interval) {
                toRun.Push(sub)
                sub.lastTick := now
            }
        }
        if (toRun.Length = 0)
            return
        ctx := ScanContext()
        try {
            ; Use .Call() so AHK v2 doesn't treat sub.fn(ctx) as a method
            ; invocation and pass `sub` as the implicit first argument.
            for sub in toRun
                sub.fn.Call(ctx)
        } finally
            ctx.Release()
    } finally
        running := false
}
