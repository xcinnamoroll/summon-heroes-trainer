; ------------------------------------------------------------------------------
; Idle / Spam Click Logic
; ------------------------------------------------------------------------------
CheckMouseIdle() {
    global lastMouseX, lastMouseY
    global idleTimeMs, isSpamClicking, isAutomationEnabled
    global IDLE_THRESHOLD_MS, IDLE_CHECK_INTERVAL_MS

    if !isAutomationEnabled {
        ; No reason: StopAllAutomation sets a specific "Stopped" message,
        ; and by the time we reach this branch isSpamClicking is already
        ; false anyway (StopAllAutomation stopped it first).
        StopSpamClicking()
        return
    }

    if !IsRobloxActive() {
        StopSpamClicking("Roblox inactive")
        return
    }

    MouseGetPos &currentX, &currentY

    wasdPressed := GetKeyState("w", "P") || GetKeyState("a", "P") || GetKeyState("s", "P") || GetKeyState("d", "P")

    if (currentX != lastMouseX || currentY != lastMouseY || wasdPressed) {
        lastMouseX := currentX
        lastMouseY := currentY
        idleTimeMs := 0
        StopSpamClicking(wasdPressed ? "WASD pressed" : "mouse moved")
        return
    }

    idleTimeMs += IDLE_CHECK_INTERVAL_MS

    if (idleTimeMs >= IDLE_THRESHOLD_MS && !isSpamClicking && spamClickEnabled)
        StartSpamClicking()
}

StartSpamClicking() {
    global isSpamClicking, SPAM_CLICK_INTERVAL_MS, spamClickEnabled

    if !spamClickEnabled
        return

    isSpamClicking := true
    SetTimer SpamClick, SPAM_CLICK_INTERVAL_MS
}

StopSpamClicking(reason := "") {
    global isSpamClicking, lastAction

    if !isSpamClicking
        return

    isSpamClicking := false
    SetTimer SpamClick, 0
    if (reason != "")
        lastAction := "Spam stopped: " reason
}

SpamClick() {
    global isClickingButton, lastAction
    if isClickingButton
        return
    MouseGetPos(,, &hoverHwnd)
    if (hoverHwnd = mainGui.Hwnd)
        return
    EnsureRobloxFocused()
    Click
    lastAction := "Spam clicking"
}

; ------------------------------------------------------------------------------
; Toggle Handlers
; ------------------------------------------------------------------------------
OnToggleTeleport(*) {
    global teleportEnabled, chkTeleport, isAutomationEnabled
    teleportEnabled := chkTeleport.Value
    if !teleportEnabled
        SetTimer WatchForTeleportButton, 0
    else if isAutomationEnabled
        SetTimer WatchForTeleportButton, TELEPORT_INTERVAL_MS
    SaveSettings()
}

OnToggleSpamClick(*) {
    global spamClickEnabled, chkSpamClick
    spamClickEnabled := chkSpamClick.Value
    if !spamClickEnabled
        StopSpamClicking("toggled off")
    SaveSettings()
}

; ------------------------------------------------------------------------------
; Apply Settings (from GUI edits)
; ------------------------------------------------------------------------------
ApplySettings(*) {
    global AUTO_RETRIES_BEFORE_ADVANCE, TELEPORT_INTERVAL_MS, IDLE_THRESHOLD_MS, SPAM_CLICK_INTERVAL_MS
    global autoRetryCount
    global edtMaxRetries, edtCurrentRetry, edtTeleport, edtIdle, edtSpamClick, isAutomationEnabled, isSpamClicking

    try {
        val := Integer(edtMaxRetries.Value)
        if (val >= 0) {
            AUTO_RETRIES_BEFORE_ADVANCE := val
            if (autoRetryCount > AUTO_RETRIES_BEFORE_ADVANCE)
                autoRetryCount := AUTO_RETRIES_BEFORE_ADVANCE
        }
    } catch {
    }

    try {
        val := Integer(edtCurrentRetry.Value)
        if (val >= 0) {
            autoRetryCount := val
            if (autoRetryCount > AUTO_RETRIES_BEFORE_ADVANCE)
                autoRetryCount := AUTO_RETRIES_BEFORE_ADVANCE
        }
    } catch {
    }

    try {
        val := Integer(edtTeleport.Value)
        if (val >= 100) {
            TELEPORT_INTERVAL_MS := val
            if (isAutomationEnabled && teleportEnabled)
                SetTimer WatchForTeleportButton, TELEPORT_INTERVAL_MS
        }
    } catch {
    }

    try {
        val := Integer(edtIdle.Value)
        if (val >= 100)
            IDLE_THRESHOLD_MS := val
    } catch {
    }

    try {
        val := Integer(edtSpamClick.Value)
        if (val >= 50) {
            SPAM_CLICK_INTERVAL_MS := val
            if isSpamClicking
                SetTimer SpamClick, SPAM_CLICK_INTERVAL_MS
        }
    } catch {
    }

    SaveSettings()
}

; ------------------------------------------------------------------------------
; Stop All Automation
; ------------------------------------------------------------------------------
StopAllAutomation() {
    global isAutomationEnabled, idleTimeMs, automationMode, lastAction
    global autoRetryCount, autoPhase, autoAdvanceStartTick
    global btnAuto, btnRetry

    if !isAutomationEnabled
        return

    isAutomationEnabled := false
    automationMode := ""
    autoRetryCount := 0
    autoPhase := "retry"
    autoAdvanceStartTick := 0
    SetTimer WatchForRetryButton, 0
    SetTimer WatchForAutoCycle, 0
    SetTimer WatchForTeleportButton, 0
    SetTimer UpdateStatusTip, 0
    StopSpamClicking()
    StopAutoChestScan()
    idleTimeMs := 0
    SetModeBtn(btnAuto, false)
    SetModeBtn(btnRetry, false)
    lastAction := "Stopped"
    UpdateStatusTip()
}

; ------------------------------------------------------------------------------
; Automation Toggle
; ------------------------------------------------------------------------------
ToggleAutomation(mode) {
    global isAutomationEnabled, idleTimeMs, automationMode
    global autoRetryCount, autoPhase, autoAdvanceStartTick
    global RETRY_SEARCH_INTERVAL_MS, TELEPORT_INTERVAL_MS, STATUS_UPDATE_MS
    global btnAuto, btnRetry, txtStatus

    if (isAutomationEnabled && automationMode = mode) {
        StopAllAutomation()
        return
    }

    ; Validate required button images for the selected mode
    missing := []
    if !FileExist(RETRY_IMAGE)
        missing.Push("Retry Stage")
    if (mode = "auto") {
        if !FileExist(NEXT_STAGE_IMAGE)
            missing.Push("Next Stage")
        if !FileExist(NEXT_MAP_IMAGE)
            missing.Push("Play Next Map")
    }
    if (teleportEnabled && !FileExist(TELEPORT_IMAGE))
        missing.Push("Teleport")
    if (missing.Length > 0) {
        list := ""
        for i, name in missing
            list .= "  - " name "`n"
        MsgBox("Please capture the following button images first:`n`n" list, "Missing Button Images", "Icon! Owner" mainGui.Hwnd)
        return
    }

    SetTimer WatchForRetryButton, 0
    SetTimer WatchForAutoCycle, 0

    isAutomationEnabled := true
    automationMode := mode
    autoRetryCount := edtCurrentRetry.Value = "" ? 0 : Integer(edtCurrentRetry.Value)
    autoPhase := "retry"
    autoAdvanceStartTick := 0

    if (mode = "retry") {
        SetTimer WatchForRetryButton, RETRY_SEARCH_INTERVAL_MS
    } else if (mode = "auto") {
        SetTimer WatchForAutoCycle, RETRY_SEARCH_INTERVAL_MS
    }

    SetModeBtn(btnAuto, mode = "auto")
    SetModeBtn(btnRetry, mode = "retry")

    if teleportEnabled
        SetTimer WatchForTeleportButton, TELEPORT_INTERVAL_MS
    SetTimer UpdateStatusTip, STATUS_UPDATE_MS
    UpdateStatusTip()
    StartAutoChestScan()
}

; ------------------------------------------------------------------------------
; Window Capture + Image Search
; ------------------------------------------------------------------------------

; Capture the Roblox window into a locked GDI+ bitmap for pixel searching.
; Returns a capture object, or false if Roblox isn't available.
; Caller must call ReleaseCapture() when done.
CaptureRobloxWindow() {
    global ROBLOX_EXE

    hwnd := WinExist(ROBLOX_EXE)
    if !hwnd
        return false

    try {
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)
    } catch {
        return false
    }
    if (clientW <= 0 || clientH <= 0)
        return false

    ; PW_CLIENTONLY (0x1) | PW_RENDERFULLCONTENT (0x2) = 0x3
    hScreenDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    hMemDC    := DllCall("CreateCompatibleDC", "Ptr", hScreenDC, "Ptr")
    hBitmap   := DllCall("CreateCompatibleBitmap", "Ptr", hScreenDC, "Int", clientW, "Int", clientH, "Ptr")
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hScreenDC)
    DllCall("SelectObject", "Ptr", hMemDC, "Ptr", hBitmap)
    pwOk := DllCall("PrintWindow", "Ptr", hwnd, "Ptr", hMemDC, "UInt", 0x3)
    DllCall("DeleteDC", "Ptr", hMemDC)

    if !pwOk {
        DllCall("DeleteObject", "Ptr", hBitmap)
        return false
    }

    pHaystack := 0
    gdipStatus := DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pHaystack)
    DllCall("DeleteObject", "Ptr", hBitmap)
    if (gdipStatus != 0 || !pHaystack)
        return false

    rectH := Buffer(16, 0)
    NumPut("Int", clientW, rectH, 8), NumPut("Int", clientH, rectH, 12)
    bdataH := Buffer(32, 0)
    gdipStatus := DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pHaystack, "Ptr", rectH, "UInt", 1, "Int", 0x26200A, "Ptr", bdataH)
    if (gdipStatus != 0) {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pHaystack)
        return false
    }

    return {
        pHaystack: pHaystack,
        bdataH:    bdataH,
        hStride:   NumGet(bdataH, 8, "Int"),
        hScan0:    NumGet(bdataH, 16, "Ptr"),
        clientX:   clientX,
        clientY:   clientY,
        clientW:   clientW,
        clientH:   clientH
    }
}

ReleaseCapture(cap) {
    DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", cap.pHaystack, "Ptr", cap.bdataH)
    DllCall("gdiplus\GdipDisposeImage",     "Ptr", cap.pHaystack)
}

; Search a pre-captured window for an image. Returns coords or false.
SearchCapture(cap, imagePath, variation, region := "") {
    global missingImageWarned, g_needleCache, g_needleLastFound
    global SEARCH_CACHE_TIGHT_PX, SEARCH_CACHE_RELAXED_MULT, SEARCH_CACHE_RELAXED_MIN_PX

    if !FileExist(imagePath) {
        if !missingImageWarned.Has(imagePath)
            missingImageWarned[imagePath] := true
        return false
    }
    if missingImageWarned.Has(imagePath)
        missingImageWarned.Delete(imagePath)

    ; Load needle from cache, or from disk on first use
    if !g_needleCache.Has(imagePath) {
        pNeedle := 0
        DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", imagePath, "Ptr*", &pNeedle)
        nW := 0, nH := 0
        DllCall("gdiplus\GdipGetImageWidth",  "Ptr", pNeedle, "UInt*", &nW)
        DllCall("gdiplus\GdipGetImageHeight", "Ptr", pNeedle, "UInt*", &nH)

        rectN := Buffer(16, 0)
        NumPut("Int", nW, rectN, 8), NumPut("Int", nH, rectN, 12)
        bdataN := Buffer(32, 0)
        DllCall("gdiplus\GdipBitmapLockBits", "Ptr", pNeedle, "Ptr", rectN, "UInt", 1, "Int", 0x26200A, "Ptr", bdataN)
        nStride := NumGet(bdataN, 8, "Int")
        nScan0  := NumGet(bdataN, 16, "Ptr")

        ; Copy pixel data into an AHK Buffer so we can dispose the GDI+ bitmap
        absStride := Abs(nStride)
        actualStart := nStride >= 0 ? nScan0 : nScan0 + (nH - 1) * nStride
        buf := Buffer(absStride * nH)
        DllCall("RtlMoveMemory", "Ptr", buf.Ptr, "Ptr", actualStart, "UPtr", absStride * nH)

        DllCall("gdiplus\GdipBitmapUnlockBits", "Ptr", pNeedle, "Ptr", bdataN)
        DllCall("gdiplus\GdipDisposeImage",     "Ptr", pNeedle)

        g_needleCache[imagePath] := { buf: buf, nW: nW, nH: nH, stride: absStride }
    }

    needle := g_needleCache[imagePath]
    nW     := needle.nW
    nH     := needle.nH
    maxHX  := cap.clientW - nW
    maxHY  := cap.clientH - nH

    ; Tiered fast path around the last-known location, expanding on miss:
    ;   Tier 1 (tight): catches stationary UI in microseconds.
    ;   Tier 2 (relaxed, scaled to needle size): catches small drift.
    ;   Tier 3 (full haystack below): catches moves/reappearances.
    ; Tier 2 re-scans Tier 1's area for simplicity — the waste is bounded by
    ; the small Tier 1 box and is negligible compared to a full-haystack scan.
    if g_needleLastFound.Has(imagePath) {
        last := g_needleLastFound[imagePath]

        tolTight := SEARCH_CACHE_TIGHT_PX
        hit := ScanHaystackRegion(cap, needle, variation
            , Max(0, last.x - tolTight), Max(0, last.y - tolTight)
            , Min(maxHX, last.x + tolTight), Min(maxHY, last.y + tolTight))
        if hit {
            g_needleLastFound[imagePath] := { x: hit.x, y: hit.y }
            return { x: cap.clientX + hit.x + (nW // 2), y: cap.clientY + hit.y + (nH // 2) }
        }

        tolRelaxed := Max(SEARCH_CACHE_RELAXED_MIN_PX, Integer(Max(nW, nH) * SEARCH_CACHE_RELAXED_MULT))
        hit := ScanHaystackRegion(cap, needle, variation
            , Max(0, last.x - tolRelaxed), Max(0, last.y - tolRelaxed)
            , Min(maxHX, last.x + tolRelaxed), Min(maxHY, last.y + tolRelaxed))
        if hit {
            g_needleLastFound[imagePath] := { x: hit.x, y: hit.y }
            return { x: cap.clientX + hit.x + (nW // 2), y: cap.clientY + hit.y + (nH // 2) }
        }
    }

    ; Fallback: region-constrained (or full) haystack scan.
    resolvedRegion := ResolveEffectiveRegion(imagePath, region)
    fullXMin := 0, fullYMin := 0, fullXMax := maxHX, fullYMax := maxHY
    if IsObject(resolvedRegion) {
        fullXMin := Integer(cap.clientW * resolvedRegion.xFrac)
        fullYMin := Integer(cap.clientH * resolvedRegion.yFrac)
        fullXMax := Min(maxHX, Integer(cap.clientW * (resolvedRegion.xFrac + resolvedRegion.wFrac)) - nW)
        fullYMax := Min(maxHY, Integer(cap.clientH * (resolvedRegion.yFrac + resolvedRegion.hFrac)) - nH)
    }
    hit := ScanHaystackRegion(cap, needle, variation, fullXMin, fullYMin, fullXMax, fullYMax)
    if !hit {
        if g_needleLastFound.Has(imagePath)
            g_needleLastFound.Delete(imagePath)
        return false
    }
    g_needleLastFound[imagePath] := { x: hit.x, y: hit.y }
    return { x: cap.clientX + hit.x + (nW // 2), y: cap.clientY + hit.y + (nH // 2) }
}

; Scans `cap` for `needle` within the inclusive [xMin..xMax] × [yMin..yMax]
; haystack-top-left coordinate range. Returns { x, y } of the match's
; top-left in client coords, or false on miss.
ScanHaystackRegion(cap, needle, variation, xMin, yMin, xMax, yMax) {
    if (xMax < xMin || yMax < yMin)
        return false

    hStride := cap.hStride
    hScan0  := cap.hScan0
    nW      := needle.nW
    nH      := needle.nH
    nStride := needle.stride
    nScan0  := needle.buf.Ptr

    firstNPx := NumGet(nScan0 + 0, "UInt")
    fnR := (firstNPx >> 16) & 0xFF
    fnG := (firstNPx >>  8) & 0xFF
    fnB :=  firstNPx        & 0xFF

    loop yMax - yMin + 1 {
        hy := yMin + A_Index - 1
        loop xMax - xMin + 1 {
            hx := xMin + A_Index - 1

            hPx := NumGet(hScan0 + hy * hStride + hx * 4, "UInt")
            if (Abs(fnR - ((hPx >> 16) & 0xFF)) > variation
             || Abs(fnG - ((hPx >>  8) & 0xFF)) > variation
             || Abs(fnB - ( hPx        & 0xFF)) > variation)
                continue

            match := true
            loop nH {
                ny := A_Index - 1
                loop nW {
                    nx := A_Index - 1
                    nPx  := NumGet(nScan0 + ny * nStride + nx * 4, "UInt")
                    hPx2 := NumGet(hScan0 + (hy + ny) * hStride + (hx + nx) * 4, "UInt")
                    if (Abs(((nPx >> 16) & 0xFF) - ((hPx2 >> 16) & 0xFF)) > variation
                     || Abs(((nPx >>  8) & 0xFF) - ((hPx2 >>  8) & 0xFF)) > variation
                     || Abs(( nPx        & 0xFF) - ( hPx2        & 0xFF)) > variation) {
                        match := false
                        break
                    }
                }
                if !match
                    break
            }

            if match
                return { x: hx, y: hy }
        }
    }
    return false
}

FindButton(imagePath, variation, region := "") {
    cap := CaptureRobloxWindow()
    if !cap
        return false
    result := SearchCapture(cap, imagePath, variation, region)
    ReleaseCapture(cap)
    return result
}

; Resolve the effective region for a given imagePath:
;   1. explicit caller-supplied region (if non-empty)
;   2. per-image sidecar file <imagePath>.region (if exists, contents = name)
;   3. NEEDLE_REGIONS default (config.ahk)
;   4. "" (no constraint)
ResolveEffectiveRegion(imagePath, explicitRegion) {
    global NEEDLE_REGIONS
    if (explicitRegion != "")
        return ResolveRegion(explicitRegion)
    sidecar := imagePath ".region"
    if FileExist(sidecar) {
        try {
            name := Trim(FileRead(sidecar))
            if (name != "")
                return ResolveRegion(name)
        }
    }
    if NEEDLE_REGIONS.Has(imagePath)
        return ResolveRegion(NEEDLE_REGIONS[imagePath])
    return ""
}

ClickFoundButton(coords, preDelay := 0, postDelay := 0) {
    global isClickingButton
    isClickingButton := true
    try {
        MouseGetPos &origX, &origY
        prevWin := !WinActive(ROBLOX_EXE) ? WinExist("A") : 0
        EnsureRobloxFocused()
        HumanMove(coords.x, coords.y)
        if preDelay
            Sleep preDelay
        MouseClick "left", coords.x, coords.y
        if postDelay
            Sleep postDelay
        HumanMove(origX, origY)
        if (prevWin && !WinActive("ahk_id " prevWin)) {
            try WinActivate "ahk_id " prevWin
        }
    } finally {
        isClickingButton := false
    }
}

; ------------------------------------------------------------------------------
; Auto-Cycle Logic (retry N times, then advance to next stage, repeat)
; ------------------------------------------------------------------------------
WatchForAutoCycle() {
    global isAutomationEnabled, autoRetryCount, autoPhase, autoAdvanceStartTick
    global AUTO_RETRIES_BEFORE_ADVANCE, AUTO_ADVANCE_GRACE_MS
    global RETRY_CLICK_COOLDOWN_MS, RETRY_SEARCH_INTERVAL_MS
    global automationMode, btnAuto, btnRetry, lastAction

    if !isAutomationEnabled || !WinExist(ROBLOX_EXE)
        return

    cap := CaptureRobloxWindow()
    if !cap
        return

    if (autoPhase = "retry") {
        coords := SearchCapture(cap, RETRY_IMAGE, RETRY_IMAGE_VARIATION)
        if !coords {
            ReleaseCapture(cap)
            return
        }

        if (autoRetryCount >= AUTO_RETRIES_BEFORE_ADVANCE) {
            advCoords := SearchCapture(cap, NEXT_STAGE_IMAGE, NEXT_STAGE_IMAGE_VARIATION)
            if !advCoords
                advCoords := SearchCapture(cap, NEXT_MAP_IMAGE, NEXT_MAP_IMAGE_VARIATION)
            ReleaseCapture(cap)
            if advCoords {
                lastAction := "Clicked next stage"
                ClickFoundButton(advCoords)
                autoRetryCount := 0
                autoAdvanceStartTick := 0
                Sleep RETRY_CLICK_COOLDOWN_MS
            } else {
                autoPhase := "advance"
                autoAdvanceStartTick := A_TickCount
            }
            return
        }

        ReleaseCapture(cap)
        lastAction := "Clicked retry"
        ClickFoundButton(coords)
        autoRetryCount++
        Sleep RETRY_CLICK_COOLDOWN_MS
        return
    }

    if (autoPhase = "advance") {
        coords := SearchCapture(cap, NEXT_STAGE_IMAGE, NEXT_STAGE_IMAGE_VARIATION)
        if !coords
            coords := SearchCapture(cap, NEXT_MAP_IMAGE, NEXT_MAP_IMAGE_VARIATION)
        ReleaseCapture(cap)
        if coords {
            lastAction := "Clicked next stage"
            ClickFoundButton(coords)
            autoRetryCount := 0
            autoPhase := "retry"
            autoAdvanceStartTick := 0
            Sleep RETRY_CLICK_COOLDOWN_MS
            return
        }

        if (A_TickCount - autoAdvanceStartTick < AUTO_ADVANCE_GRACE_MS)
            return

        ; Grace period expired — fall back to retry-only mode
        autoRetryCount := 0
        autoPhase := "retry"
        autoAdvanceStartTick := 0
        automationMode := "retry"
        SetTimer WatchForAutoCycle, 0
        SetTimer WatchForRetryButton, RETRY_SEARCH_INTERVAL_MS
        SetModeBtn(btnAuto, false)
        SetModeBtn(btnRetry, true)
    }
}

; ------------------------------------------------------------------------------
; Retry Button Watcher
; ------------------------------------------------------------------------------
WatchForRetryButton() {
    global isAutomationEnabled, RETRY_CLICK_COOLDOWN_MS, lastAction

    if !isAutomationEnabled || !WinExist(ROBLOX_EXE)
        return

    coords := FindButton(RETRY_IMAGE, RETRY_IMAGE_VARIATION)
    if !coords
        return

    lastAction := "Clicked retry"
    ClickFoundButton(coords)
    Sleep RETRY_CLICK_COOLDOWN_MS
}

; ------------------------------------------------------------------------------
; Teleport Button Watcher
; ------------------------------------------------------------------------------
WatchForTeleportButton() {
    global isAutomationEnabled, TELEPORT_HOLD_MS, idleTimeMs, IDLE_THRESHOLD_MS, teleportEnabled, lastAction

    if !isAutomationEnabled || !teleportEnabled || !WinExist(ROBLOX_EXE)
        return
    if (g_armedPaths.Length > 0 || pathActive)
        return

    if (idleTimeMs < IDLE_THRESHOLD_MS)
        return

    coords := FindButton(TELEPORT_IMAGE, TELEPORT_IMAGE_VARIATION)
    if !coords
        return

    lastAction := "Clicked teleport"
    ClickFoundButton(coords, 100, TELEPORT_HOLD_MS)
}
