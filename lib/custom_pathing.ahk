; ------------------------------------------------------------------------------
; Custom Pathing
; Records W/A/S/D/E/Space presses with timing, saves to a shareable .path file,
; and plays them back when a trigger image appears in Roblox. The trigger
; image is embedded as base64-encoded PNG bytes so each .path file is fully
; self-contained (no dependency on AppData\buttons).
; ------------------------------------------------------------------------------

DirCreate PATHS_DIR
DirCreate PATHS_DIR "\.tmp"

; ==============================================================================
; Base64 + raw bytes helpers (used to embed trigger images in .path files)
; ==============================================================================
Base64EncodeBuffer(buf, byteCount) {
    flags := 0x40000001  ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    outLen := 0
    DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", byteCount, "UInt", flags, "Ptr", 0, "UInt*", &outLen)
    outBuf := Buffer(outLen * 2)
    DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", byteCount, "UInt", flags, "Ptr", outBuf, "UInt*", &outLen)
    return StrGet(outBuf, outLen, "UTF-16")
}

Base64DecodeToBuffer(base64Str) {
    flags := 0x1  ; CRYPT_STRING_BASE64
    outLen := 0
    DllCall("crypt32\CryptStringToBinaryW", "WStr", base64Str, "UInt", 0, "UInt", flags, "Ptr", 0, "UInt*", &outLen, "Ptr", 0, "Ptr", 0)
    outBuf := Buffer(outLen)
    DllCall("crypt32\CryptStringToBinaryW", "WStr", base64Str, "UInt", 0, "UInt", flags, "Ptr", outBuf, "UInt*", &outLen, "Ptr", 0, "Ptr", 0)
    return { buf: outBuf, size: outLen }
}

ReadFileAsBase64(filePath) {
    f := FileOpen(filePath, "r")
    if !f
        return ""
    size := f.Length
    buf := Buffer(size)
    f.RawRead(buf, size)
    f.Close()
    return Base64EncodeBuffer(buf, size)
}

WriteBase64ToFile(base64Str, filePath) {
    decoded := Base64DecodeToBuffer(base64Str)
    f := FileOpen(filePath, "w")
    if !f
        return false
    f.RawWrite(decoded.buf, decoded.size)
    f.Close()
    return true
}

GetImageDimensionsFromFile(filePath) {
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", filePath, "Ptr*", &pBitmap)
    if !pBitmap
        return { w: 0, h: 0 }
    w := 0, h := 0
    DllCall("gdiplus\GdipGetImageWidth",  "Ptr", pBitmap, "UInt*", &w)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &h)
    DllCall("gdiplus\GdipDisposeImage",   "Ptr", pBitmap)
    return { w: w, h: h }
}

; ------------------------------------------------------------------------------
; File I/O
; ------------------------------------------------------------------------------
ListPaths() {
    global PATHS_DIR
    paths := []
    Loop Files, PATHS_DIR "\*.path" {
        SplitPath A_LoopFileName, , , , &nameNoExt
        paths.Push(nameNoExt)
    }
    return paths
}

; trigger: { type: "image", imageData: "<base64>" } or
;          { type: "timer", intervalMs: <ms> }
SavePath(name, trigger, events) {
    global PATHS_DIR
    filePath := PATHS_DIR "\" name ".path"
    out := "[Meta]`r`nName=" name "`r`n`r`n"
    out .= "[Trigger]`r`nType=" trigger.type "`r`n"
    if (trigger.type = "image")
        out .= "ImageData=" trigger.imageData "`r`n"
    else if (trigger.type = "timer")
        out .= "IntervalMs=" trigger.intervalMs "`r`n"
    if (trigger.HasProp("region") && trigger.region != "" && trigger.region != "whole")
        out .= "Region=" trigger.region "`r`n"
    out .= "`r`n[Events]`r`n"
    for e in events
        out .= (e.type = "down" ? "keydown" : "keyup") " " e.key " " e.t "`r`n"
    f := FileOpen(filePath, "w")
    if !f
        return false
    f.Write(out)
    f.Close()
    return true
}

LoadPath(name) {
    global PATHS_DIR
    filePath := PATHS_DIR "\" name ".path"
    if !FileExist(filePath)
        return false
    result := { name: name, trigger: { type: "manual", imageData: "", intervalMs: 0, tempPath: "", region: "" }, events: [] }
    section := ""
    Loop Read filePath {
        line := Trim(A_LoopReadLine)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        if (SubStr(line, 1, 1) = "[" && SubStr(line, StrLen(line), 1) = "]") {
            section := SubStr(line, 2, StrLen(line) - 2)
            continue
        }
        if (section = "Meta") {
            parts := StrSplit(line, "=", , 2)
            if (parts.Length >= 2 && parts[1] = "Name")
                result.name := parts[2]
        } else if (section = "Trigger") {
            parts := StrSplit(line, "=", , 2)
            if (parts.Length >= 2) {
                if (parts[1] = "Type")
                    result.trigger.type := parts[2]
                else if (parts[1] = "ImageData")
                    result.trigger.imageData := parts[2]
                else if (parts[1] = "IntervalMs")
                    result.trigger.intervalMs := Integer(parts[2])
                else if (parts[1] = "Region")
                    result.trigger.region := parts[2]
            }
        } else if (section = "Events") {
            parts := StrSplit(line, " ", , 3)
            if (parts.Length >= 3 && (parts[1] = "keydown" || parts[1] = "keyup")) {
                result.events.Push({
                    type: parts[1] = "keydown" ? "down" : "up",
                    key:  parts[2],
                    t:    Integer(parts[3])
                })
            }
        }
    }
    return result
}

DeletePath(name) {
    global PATHS_DIR
    filePath := PATHS_DIR "\" name ".path"
    if FileExist(filePath)
        FileDelete filePath
}

RenamePath(oldName, newName) {
    global PATHS_DIR
    oldFile := PATHS_DIR "\" oldName ".path"
    newFile := PATHS_DIR "\" newName ".path"
    if !FileExist(oldFile)
        return false
    if FileExist(newFile)
        return false
    path := LoadPath(oldName)
    if !path
        return false
    if !SavePath(newName, path.trigger, path.events)
        return false
    try FileDelete oldFile
    return true
}

; ------------------------------------------------------------------------------
; Trigger image capture / upload — both return base64-encoded PNG bytes or ""
; ------------------------------------------------------------------------------
CaptureTriggerImageAsBase64() {
    global mainGui, PATHS_DIR
    mainGui.Hide()
    Sleep 200
    ToolTip "Click TOP-LEFT corner of trigger image (right-click to cancel)"
    if !WaitForClick(&x1, &y1) {
        ToolTip
        mainGui.Show()
        return ""
    }
    ToolTip "Click BOTTOM-RIGHT corner (right-click to cancel)"
    if !WaitForClick(&x2, &y2) {
        ToolTip
        mainGui.Show()
        return ""
    }
    ToolTip
    if (x2 <= x1 || y2 <= y1) {
        mainGui.Show()
        MsgBox("Invalid selection — bottom-right must be below and right of top-left.", "Capture Trigger", "Icon! Owner" mainGui.Hwnd)
        return ""
    }
    tempPath := PATHS_DIR "\.tmp\capture_temp.png"
    if !CaptureScreenRegion(x1, y1, x2 - x1, y2 - y1, tempPath) {
        mainGui.Show()
        MsgBox("Failed to capture screen region.", "Capture Trigger", "Icon! Owner" mainGui.Hwnd)
        return ""
    }
    mainGui.Show()
    base64 := ReadFileAsBase64(tempPath)
    try FileDelete tempPath
    return base64
}

UploadTriggerImageAsBase64() {
    global mainGui, PATHS_DIR
    filePath := FileSelect("1", , "Select trigger image", "Images (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")
    if !filePath
        return ""

    ; Load via GDI+, save as PNG to normalize, then read bytes back
    pBitmap := 0
    status := DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", filePath, "Ptr*", &pBitmap)
    if (status != 0 || !pBitmap) {
        MsgBox("Failed to load image: " filePath, "Upload Trigger", "Icon! Owner" mainGui.Hwnd)
        return ""
    }

    tempPath := PATHS_DIR "\.tmp\upload_temp.png"
    pEncoder := Buffer(16)
    DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", pEncoder)
    saveStatus := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Str", tempPath, "Ptr", pEncoder, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)

    if (saveStatus != 0) {
        MsgBox("Failed to convert image to PNG.", "Upload Trigger", "Icon! Owner" mainGui.Hwnd)
        return ""
    }

    base64 := ReadFileAsBase64(tempPath)
    try FileDelete tempPath
    return base64
}

; Return {w, h} from a base64 string by writing/reading a short-lived PNG
GetImageDimensionsFromBase64(base64Str) {
    global PATHS_DIR
    tempPath := PATHS_DIR "\.tmp\dims_temp.png"
    WriteBase64ToFile(base64Str, tempPath)
    dims := GetImageDimensionsFromFile(tempPath)
    try FileDelete tempPath
    return dims
}

; Delete every temp file in paths\.tmp\ — called on disarm and on exit
ClearPathTempFiles() {
    global PATHS_DIR
    Loop Files, PATHS_DIR "\.tmp\*.png"
        try FileDelete A_LoopFileFullPath
}

; ------------------------------------------------------------------------------
; Recording
; ------------------------------------------------------------------------------
StartRecordingPath() {
    global isRecordingPath, pathRecordStartTick, pathRecordEvents
    global pathRecordingStopRequested, PATH_KEYS, g_pathRecordingHeld
    if isRecordingPath
        return
    pathRecordEvents := []
    g_pathRecordingHeld := Map()
    pathRecordingStopRequested := false
    pathRecordStartTick := A_TickCount
    for key in PATH_KEYS {
        Hotkey "~*" key, OnPathKeyDown.Bind(key), "On"
        Hotkey "~*" key " up", OnPathKeyUp.Bind(key), "On"
    }
    Hotkey "F8", OnPathRecordingStopHotkey, "On"
    isRecordingPath := true
}

StopRecordingPath() {
    global isRecordingPath, pathRecordEvents, PATH_KEYS
    if !isRecordingPath
        return []
    for key in PATH_KEYS {
        Hotkey "~*" key, "Off"
        Hotkey "~*" key " up", "Off"
    }
    Hotkey "F8", "Off"
    isRecordingPath := false
    return pathRecordEvents
}

OnPathKeyDown(key, *) {
    global pathRecordEvents, pathRecordStartTick, isRecordingPath, g_pathRecordingHeld
    if !isRecordingPath
        return
    ; Skip OS auto-repeat — only record the transition from up -> down.
    if g_pathRecordingHeld.Has(key)
        return
    g_pathRecordingHeld[key] := true
    pathRecordEvents.Push({ type: "down", key: key, t: A_TickCount - pathRecordStartTick })
}

OnPathKeyUp(key, *) {
    global pathRecordEvents, pathRecordStartTick, isRecordingPath, g_pathRecordingHeld
    if !isRecordingPath
        return
    ; Only record the transition from down -> up — ignore stray ups.
    if !g_pathRecordingHeld.Has(key)
        return
    g_pathRecordingHeld.Delete(key)
    pathRecordEvents.Push({ type: "up", key: key, t: A_TickCount - pathRecordStartTick })
}

OnPathRecordingStopHotkey(*) {
    global pathRecordingStopRequested
    pathRecordingStopRequested := true
}

; ------------------------------------------------------------------------------
; Playback
; ------------------------------------------------------------------------------
; User-facing label for the keys currently held in g_pathHeldKeys —
; Space becomes "Spacebar", arrow keys become arrow glyphs, other keys
; uppercased, joined with "+". Returns "Wait" when nothing is held so the
; step row always has a word.
FormatHeldKeysLabel() {
    global g_pathHeldKeys
    parts := ""
    for keyStr in g_pathHeldKeys {
        switch keyStr {
            case "Space": label := "Spacebar"
            case "Up":    label := "↑"
            case "Down":  label := "↓"
            case "Left":  label := "←"
            case "Right": label := "→"
            default:      label := StrUpper(keyStr)
        }
        parts .= (parts = "" ? "" : "+") label
    }
    return parts = "" ? "Wait" : parts
}

UpdatePathStepDisplay(idx, total) {
    global txtPathStep, COLOR_STATE_INFO
    if IsSet(txtPathStep)
        SetShadowText(txtPathStep, FormatHeldKeysLabel() " " idx "/" total, "c" COLOR_STATE_INFO)
}

; Async playback: instead of holding the main thread in a Sleep loop, each
; event schedules the next via a one-shot SetTimer. Timer callbacks fire off
; the Windows timer queue independent of the main thread, so other script
; work (GUI events, spam click ticks, the armed-path watcher) can't push
; path events off-rhythm. Each callback computes its delay from an absolute
; deadline (startTick + e.t), so any overshoot of one event doesn't
; accumulate into the next.
PlayPath(path) {
    global pathActive, g_pathHeldKeys, g_pathPlayback
    if pathActive
        return
    pathActive := true
    g_pathHeldKeys := Map()
    g_pathPlayback := {
        path:      path,
        startTick: A_TickCount,
        idx:       0,
        total:     path.events.Length,
        stopped:   false
    }
    SchedulePathEvent()
}

SchedulePathEvent() {
    global g_pathPlayback, pathActive
    if (!pathActive || g_pathPlayback.stopped || g_pathPlayback.idx >= g_pathPlayback.total) {
        FinishPathPlayback("")
        return
    }
    nextE := g_pathPlayback.path.events[g_pathPlayback.idx + 1]
    elapsed := A_TickCount - g_pathPlayback.startTick
    delay := nextE.t - elapsed
    if (delay < 1)
        delay := 1  ; AHK's minimum is effectively 10ms; 1ms means "ASAP"
    SetTimer FirePathEvent, -delay
}

FirePathEvent() {
    global g_pathPlayback, pathActive, g_pathHeldKeys, ROBLOX_EXE
    if (!pathActive || g_pathPlayback.stopped)
        return
    if !WinActive(ROBLOX_EXE) {
        FinishPathPlayback("Stopped: Roblox not active")
        return
    }
    g_pathPlayback.idx++
    e := g_pathPlayback.path.events[g_pathPlayback.idx]
    keyStr := e.key = "space" ? "Space" : e.key
    ; Tolerate paths recorded before the auto-repeat fix: skip a redundant
    ; "down" for an already-held key or "up" for a key that isn't held.
    if (e.type = "down") {
        if !g_pathHeldKeys.Has(keyStr) {
            Send "{" keyStr " down}"
            g_pathHeldKeys[keyStr] := true
        }
    } else {
        if g_pathHeldKeys.Has(keyStr) {
            Send "{" keyStr " up}"
            g_pathHeldKeys.Delete(keyStr)
        }
    }
    UpdatePathStepDisplay(g_pathPlayback.idx, g_pathPlayback.total)
    SchedulePathEvent()
}

FinishPathPlayback(lastActionMsg) {
    global g_pathPlayback, pathActive, txtPathLastAction, COLOR_STATE_WARNING
    if IsSet(g_pathPlayback)
        g_pathPlayback.stopped := true
    SetTimer FirePathEvent, 0
    ReleaseAllPathKeys()
    pathActive := false
    if (lastActionMsg != "" && IsSet(txtPathLastAction))
        SetShadowText(txtPathLastAction, lastActionMsg, "c" COLOR_STATE_WARNING)
    UpdatePathStatusIdle()
}

StopPathPlayback() {
    global pathActive
    if !pathActive
        return
    FinishPathPlayback("")
}

ReleaseAllPathKeys() {
    global g_pathHeldKeys
    for key, _ in g_pathHeldKeys
        Send "{" key " up}"
    g_pathHeldKeys := Map()
}

; ------------------------------------------------------------------------------
; Path trigger detection — uses native ImageSearch instead of the PrintWindow
; + pixel-loop SearchCapture. Faster per scan, but requires the Roblox window
; to be visible (not covered). Pathing requires active Roblox anyway, so
; that's an acceptable tradeoff here (story mode still uses SearchCapture).
;
; Applies the same tiered cache around g_needleLastFound that SearchCapture
; uses: tight box → relaxed box → region-constrained fallback.
;
; Returns { x, y } screen-center coords of a match, or false.
; ------------------------------------------------------------------------------
FindPathTrigger(imagePath, variation, region := "") {
    global ROBLOX_EXE, g_needleLastFound
    global SEARCH_CACHE_TIGHT_PX, SEARCH_CACHE_RELAXED_MULT, SEARCH_CACHE_RELAXED_MIN_PX

    if !FileExist(imagePath)
        return false
    hwnd := WinExist(ROBLOX_EXE)
    if !hwnd
        return false
    try
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " hwnd)
    catch
        return false
    if (clientW <= 0 || clientH <= 0)
        return false

    dims := GetImageDimensionsFromFile(imagePath)
    nW := dims.w, nH := dims.h
    if (nW <= 0 || nH <= 0 || nW > clientW || nH > clientH)
        return false
    maxHX := clientW - nW, maxHY := clientH - nH

    ; Resolve region into client-coord bounds for the fallback tier.
    resolved := ResolveRegion(region)
    regionX1 := 0, regionY1 := 0, regionX2 := maxHX, regionY2 := maxHY
    if IsObject(resolved) {
        regionX1 := Integer(clientW * resolved.xFrac)
        regionY1 := Integer(clientH * resolved.yFrac)
        regionX2 := Min(maxHX, Integer(clientW * (resolved.xFrac + resolved.wFrac)) - nW)
        regionY2 := Min(maxHY, Integer(clientH * (resolved.yFrac + resolved.hFrac)) - nH)
    }
    if (regionX2 < regionX1 || regionY2 < regionY1)
        return false

    ; Build ordered list of tiers to try (client-coord top-left bounds).
    tiers := []
    if g_needleLastFound.Has(imagePath) {
        last := g_needleLastFound[imagePath]
        tolTight := SEARCH_CACHE_TIGHT_PX
        tiers.Push({
            x1: Max(regionX1, last.x - tolTight),
            y1: Max(regionY1, last.y - tolTight),
            x2: Min(regionX2, last.x + tolTight),
            y2: Min(regionY2, last.y + tolTight)
        })
        tolRelaxed := Max(SEARCH_CACHE_RELAXED_MIN_PX, Integer(Max(nW, nH) * SEARCH_CACHE_RELAXED_MULT))
        tiers.Push({
            x1: Max(regionX1, last.x - tolRelaxed),
            y1: Max(regionY1, last.y - tolRelaxed),
            x2: Min(regionX2, last.x + tolRelaxed),
            y2: Min(regionY2, last.y + tolRelaxed)
        })
    }
    tiers.Push({ x1: regionX1, y1: regionY1, x2: regionX2, y2: regionY2 })

    for _, t in tiers {
        if (t.x2 < t.x1 || t.y2 < t.y1)
            continue
        sx1 := clientX + t.x1
        sy1 := clientY + t.y1
        sx2 := clientX + t.x2 + nW
        sy2 := clientY + t.y2 + nH
        foundX := 0, foundY := 0
        try {
            if ImageSearch(&foundX, &foundY, sx1, sy1, sx2, sy2, "*" variation " " imagePath) {
                g_needleLastFound[imagePath] := { x: foundX - clientX, y: foundY - clientY }
                return { x: foundX + (nW // 2), y: foundY + (nH // 2) }
            }
        }
    }

    if g_needleLastFound.Has(imagePath)
        g_needleLastFound.Delete(imagePath)
    return false
}

; ------------------------------------------------------------------------------
; Trigger Watcher
; ------------------------------------------------------------------------------
; Multiple paths can be armed simultaneously. Only one plays at a time — new
; triggers are ignored while something is already playing, and each path uses
; its own edge-detection flag so it fires once per appearance of its trigger.
ArmPath(path) {
    global g_armedPaths, PATH_TRIGGER_INTERVAL_MS, PATHS_DIR, g_needleCache, g_needleLastFound

    ; Validate trigger
    if (path.trigger.type = "image") {
        if (path.trigger.imageData = "")
            return false
    } else if (path.trigger.type = "timer") {
        if (path.trigger.intervalMs <= 0)
            return false
    } else {
        return false
    }

    ; No-op if this path is already armed (by name)
    for armed in g_armedPaths
        if (armed.path.name = path.name)
            return true

    entry := { path: path, tempPath: "", lastFound: false, nextFireTick: 0 }

    if (path.trigger.type = "image") {
        tempPath := PATHS_DIR "\.tmp\armed_" path.name ".png"
        if !WriteBase64ToFile(path.trigger.imageData, tempPath)
            return false
        if g_needleCache.Has(tempPath)
            g_needleCache.Delete(tempPath)
        if g_needleLastFound.Has(tempPath)
            g_needleLastFound.Delete(tempPath)
        path.trigger.tempPath := tempPath
        entry.tempPath := tempPath
    } else if (path.trigger.type = "timer") {
        entry.nextFireTick := A_TickCount + path.trigger.intervalMs
    }

    g_armedPaths.Push(entry)

    if (g_armedPaths.Length = 1) {
        global g_armedScanCount
        g_armedScanCount := 0
    }
    return true
}

DisarmPath(name) {
    global g_armedPaths, g_needleCache, g_needleLastFound
    for i, armed in g_armedPaths {
        if (armed.path.name = name) {
            if g_needleCache.Has(armed.tempPath)
                g_needleCache.Delete(armed.tempPath)
            if g_needleLastFound.Has(armed.tempPath)
                g_needleLastFound.Delete(armed.tempPath)
            try FileDelete armed.tempPath
            g_armedPaths.RemoveAt(i)
            return true
        }
    }
    return false
}

DisarmAllPaths() {
    global g_armedPaths, g_needleCache, g_needleLastFound
    for armed in g_armedPaths {
        if g_needleCache.Has(armed.tempPath)
            g_needleCache.Delete(armed.tempPath)
        if g_needleLastFound.Has(armed.tempPath)
            g_needleLastFound.Delete(armed.tempPath)
        try FileDelete armed.tempPath
    }
    g_armedPaths := []
}

IsPathArmed(name) {
    global g_armedPaths
    for armed in g_armedPaths
        if (armed.path.name = name)
            return true
    return false
}

WatchArmedPathsTick(ctx) {
    global g_armedPaths, pathActive, ROBLOX_EXE, PATH_TRIGGER_VARIATION
    global txtPathState, txtPathActive, txtPathStep, txtPathLastAction
    global COLOR_STATE_SUCCESS, COLOR_STATE_INFO, COLOR_STATE_WARNING
    global g_armedScanCount

    if (g_armedPaths.Length = 0)
        return
    if pathActive
        return
    if !WinActive(ROBLOX_EXE) {
        if IsSet(txtPathStep)
            SetShadowText(txtPathStep, "Paused (Roblox not active)", "c" COLOR_STATE_WARNING)
        return
    }

    g_armedScanCount += 1
    ; Live scan feedback goes in the Step row so it doesn't clobber the
    ; Last action row (where Test Trigger / Saved / etc. messages live).
    if IsSet(txtPathStep)
        SetShadowText(txtPathStep, "Scanning… " g_armedScanCount, "c" COLOR_STATE_INFO)

    ; Iterate a snapshot in case playback below triggers a disarm on GUI thread
    snapshot := []
    for armed in g_armedPaths
        snapshot.Push(armed)

    for armed in snapshot {
        if pathActive
            return
        ; Skip if this entry was disarmed during a previous play this tick
        if !IsPathArmed(armed.path.name)
            continue

        shouldFire := false
        triggerType := armed.path.trigger.type

        if (triggerType = "image") {
            imagePath := armed.tempPath
            if (imagePath = "" || !FileExist(imagePath))
                continue
            regionHint := armed.path.trigger.HasProp("region") ? armed.path.trigger.region : ""
            coords := ctx.FindLive(imagePath, PATH_TRIGGER_VARIATION, regionHint)
            if coords {
                if !armed.lastFound {
                    armed.lastFound := true
                    shouldFire := true
                }
            } else {
                armed.lastFound := false
            }
        } else if (triggerType = "timer") {
            if (A_TickCount >= armed.nextFireTick) {
                shouldFire := true
                armed.nextFireTick := A_TickCount + armed.path.trigger.intervalMs
            }
        }

        if shouldFire {
            if IsSet(txtPathState) {
                SetShadowText(txtPathState, "Playing", "c" COLOR_STATE_SUCCESS)
                SetShadowText(txtPathActive, armed.path.name)
                SetShadowText(txtPathLastAction, "Trigger matched: " armed.path.name, "c" COLOR_STATE_SUCCESS)
            }
            ; Async playback — returns immediately; FinishPathPlayback calls
            ; UpdatePathStatusIdle when the last event fires.
            PlayPath(armed.path)
            return
        }
    }
}

; ------------------------------------------------------------------------------
; GUI Handlers
; ------------------------------------------------------------------------------
RefreshPathLists() {
    global ddPaths
    ddPaths.Delete()
    for p in ListPaths()
        ddPaths.Add([p])
    RefreshChestPathDropdowns()
}

UpdateNewPathTriggerStatus() {
    global txtPathTriggerStatus, g_newPathTriggerDesc, COLOR_TEXT_PRIMARY
    if IsSet(txtPathTriggerStatus)
        SetShadowText(txtPathTriggerStatus, g_newPathTriggerDesc, "c" COLOR_TEXT_PRIMARY)
}

ClearNewPathTrigger() {
    global g_newPathTriggerBase64, g_newPathTriggerDesc, g_newPathTriggerType
    global g_newPathTriggerIntervalMs, g_newPathTriggerRegion
    global edtNewPathInterval, ddNewPathRegion, REGION_CHOICES
    g_newPathTriggerType       := "none"
    g_newPathTriggerBase64     := ""
    g_newPathTriggerIntervalMs := 0
    g_newPathTriggerDesc       := "(none)"
    g_newPathTriggerRegion     := "whole"
    if IsSet(edtNewPathInterval)
        edtNewPathInterval.Value := 0
    if IsSet(ddNewPathRegion)
        ddNewPathRegion.Choose(1)
    UpdateNewPathTriggerStatus()
}

OnPathCaptureNewTriggerClick() {
    global g_newPathTriggerBase64, g_newPathTriggerDesc, g_newPathTriggerType
    global g_newPathTriggerIntervalMs, edtNewPathInterval
    base64 := CaptureTriggerImageAsBase64()
    if (base64 = "")
        return
    dims := GetImageDimensionsFromBase64(base64)
    g_newPathTriggerType       := "image"
    g_newPathTriggerBase64     := base64
    g_newPathTriggerIntervalMs := 0
    g_newPathTriggerDesc       := "Captured " dims.w "x" dims.h
    ; Clear timer input since image just won
    if IsSet(edtNewPathInterval)
        edtNewPathInterval.Value := 0
    UpdateNewPathTriggerStatus()
}

OnPathUploadNewTriggerClick() {
    global g_newPathTriggerBase64, g_newPathTriggerDesc, g_newPathTriggerType
    global g_newPathTriggerIntervalMs, edtNewPathInterval
    base64 := UploadTriggerImageAsBase64()
    if (base64 = "")
        return
    dims := GetImageDimensionsFromBase64(base64)
    g_newPathTriggerType       := "image"
    g_newPathTriggerBase64     := base64
    g_newPathTriggerIntervalMs := 0
    g_newPathTriggerDesc       := "Uploaded " dims.w "x" dims.h
    if IsSet(edtNewPathInterval)
        edtNewPathInterval.Value := 0
    UpdateNewPathTriggerStatus()
}

; Fired when the user picks a value in the "Search region" dropdown for a
; new path being recorded. Stored in g_newPathTriggerRegion so SavePath in
; CheckPathRecordingDone picks it up.
OnNewPathRegionChange(*) {
    global ddNewPathRegion, g_newPathTriggerRegion, REGION_CHOICES
    idx := ddNewPathRegion.Value
    if (idx < 1 || idx > REGION_CHOICES.Length)
        return
    g_newPathTriggerRegion := REGION_CHOICES[idx][2]
}

; Dialog to change the search region on an already-saved path.
OnPathSetRegionClick() {
    global ddPaths, txtPathLastAction, g_armedPaths, pathActive, isRecordingPath
    global REGION_CHOICES, COLOR_STATE_SUCCESS, COLOR_STATE_ERROR
    if isRecordingPath || g_armedPaths.Length > 0 || pathActive {
        MsgBox("Stop the active path or disarm all paths first.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    path := LoadPath(name)
    if !path {
        MsgBox("Could not load path: " name, "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    ; Build prompt listing the numbered choices.
    prompt := "Pick a search region (enter number):`n"
    for i, choice in REGION_CHOICES
        prompt .= i ". " choice[1] "`n"
    current := path.trigger.HasProp("region") && path.trigger.region != "" ? path.trigger.region : "whole"
    currentIdx := 1
    for i, choice in REGION_CHOICES {
        if (choice[2] = current) {
            currentIdx := i
            break
        }
    }
    ib := InputBox(prompt, "Set Search Region", "w320 h260", currentIdx)
    if (ib.Result != "OK")
        return
    pick := 0
    try pick := Integer(Trim(ib.Value))
    if (pick < 1 || pick > REGION_CHOICES.Length) {
        MsgBox("Invalid choice.", "Set Search Region", "Icon! Owner" mainGui.Hwnd)
        return
    }
    newRegion := REGION_CHOICES[pick][2]
    newTrigger := path.trigger.type = "image"
        ? { type: "image", imageData: path.trigger.imageData, region: newRegion }
        : { type: path.trigger.type, intervalMs: path.trigger.intervalMs, region: newRegion }
    if SavePath(name, newTrigger, path.events)
        SetShadowText(txtPathLastAction, "Region set: " REGION_CHOICES[pick][1], "c" COLOR_STATE_SUCCESS)
    else
        SetShadowText(txtPathLastAction, "Save failed", "c" COLOR_STATE_ERROR)
}

; Called when user types into the new-path interval edit. Switches the trigger
; type to "timer" when the value is a positive integer, clears it when empty/0.
OnNewPathIntervalChange(*) {
    global edtNewPathInterval, g_newPathTriggerType, g_newPathTriggerBase64
    global g_newPathTriggerIntervalMs, g_newPathTriggerDesc
    raw := edtNewPathInterval.Value
    secs := 0
    try secs := Integer(raw)
    if (secs <= 0) {
        if (g_newPathTriggerType = "timer") {
            g_newPathTriggerType       := "none"
            g_newPathTriggerIntervalMs := 0
            g_newPathTriggerDesc       := "(none)"
            UpdateNewPathTriggerStatus()
        }
        return
    }
    g_newPathTriggerType       := "timer"
    g_newPathTriggerBase64     := ""
    g_newPathTriggerIntervalMs := secs * 1000
    g_newPathTriggerDesc       := "Timer: every " secs "s"
    UpdateNewPathTriggerStatus()
}

OnPathRecordClick() {
    global edtPathName, txtPathState, txtPathActive, txtPathLastAction, isRecordingPath
    global pathActive, g_armedPaths, g_newPathTriggerType, COLOR_STATE_WARNING, ROBLOX_EXE

    if isRecordingPath {
        MsgBox("Already recording. Press F8 to stop.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if pathActive || g_armedPaths.Length > 0 {
        MsgBox("Stop the active path or disarm all paths first.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }

    name := Trim(edtPathName.Value)
    if (name = "") {
        MsgBox("Enter a name for the path.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if !RegExMatch(name, "^[A-Za-z0-9 _\-]+$") {
        MsgBox("Name can only contain letters, numbers, spaces, underscores, and hyphens.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }

    if (g_newPathTriggerType = "none") {
        MsgBox("Set a trigger first — capture/upload an image, or enter a timer interval.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }

    SetShadowText(txtPathState, "Recording", "c" COLOR_STATE_WARNING)
    SetShadowText(txtPathActive, name)
    ; Focus Roblox so initial idle + keystrokes land on the game.
    if WinExist(ROBLOX_EXE)
        WinActivate ROBLOX_EXE
    StartRecordingPath()
    SetShadowText(txtPathLastAction, "Press F8 to stop", "c" COLOR_STATE_WARNING)
    SetTimer CheckPathRecordingDone, 100
}

CheckPathRecordingDone() {
    global pathRecordingStopRequested, edtPathName, txtPathLastAction
    global g_newPathTriggerType, g_newPathTriggerBase64, g_newPathTriggerIntervalMs
    global COLOR_STATE_SUCCESS, COLOR_STATE_ERROR
    if !pathRecordingStopRequested
        return
    SetTimer CheckPathRecordingDone, 0
    events := StopRecordingPath()
    name := Trim(edtPathName.Value)
    if (events.Length = 0) {
        UpdatePathStatusIdle()
        SetShadowText(txtPathLastAction, "No keys recorded", "c" COLOR_STATE_ERROR)
        return
    }
    global g_newPathTriggerRegion
    trigger := g_newPathTriggerType = "image"
        ? { type: "image", imageData: g_newPathTriggerBase64, region: g_newPathTriggerRegion }
        : { type: "timer", intervalMs: g_newPathTriggerIntervalMs, region: g_newPathTriggerRegion }
    if SavePath(name, trigger, events) {
        UpdatePathStatusIdle()
        SetShadowText(txtPathLastAction, "Saved (" events.Length " events)", "c" COLOR_STATE_SUCCESS)
        edtPathName.Value := ""
        ClearNewPathTrigger()
        RefreshPathLists()
    } else {
        UpdatePathStatusIdle()
        SetShadowText(txtPathLastAction, "Save failed", "c" COLOR_STATE_ERROR)
    }
}

; Describes currently-armed paths for the "Path:" status row. Timer-triggered
; paths get a "(every Ns)" suffix so the user can see the cadence at a glance.
FormatArmedPathList() {
    global g_armedPaths
    if (g_armedPaths.Length = 0)
        return "-"
    names := ""
    for armed in g_armedPaths {
        label := armed.path.name
        if (armed.path.trigger.type = "timer")
            label .= " (every " Round(armed.path.trigger.intervalMs / 1000) "s)"
        names .= (names = "" ? "" : ", ") label
    }
    return names
}

; Reset the status box to the "nothing playing / not recording" view. Shows
; Armed (N) when paths are armed, Idle otherwise. Does not touch Last action.
UpdatePathStatusIdle() {
    global txtPathState, txtPathActive, txtPathStep, txtPathArmed, g_armedPaths
    global COLOR_STATE_INFO, COLOR_STATE_WARNING
    if (g_armedPaths.Length > 0)
        SetShadowText(txtPathState, "Armed (" g_armedPaths.Length ")", "c" COLOR_STATE_WARNING)
    else
        SetShadowText(txtPathState, "Idle", "c" COLOR_STATE_INFO)
    SetShadowText(txtPathActive, "-")
    SetShadowText(txtPathStep, "-")
    SetShadowText(txtPathArmed, FormatArmedPathList())
}

OnPathPlayClick() {
    global ddPaths, txtPathState, txtPathActive, pathActive, isRecordingPath
    global COLOR_STATE_SUCCESS, ROBLOX_EXE
    if isRecordingPath {
        MsgBox("Stop recording first (F8).", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if pathActive {
        MsgBox("A path is already playing.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    path := LoadPath(name)
    if !path {
        MsgBox("Could not load path: " name, "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    SetShadowText(txtPathState, "Playing", "c" COLOR_STATE_SUCCESS)
    SetShadowText(txtPathActive, name)
    ; Focus Roblox before playback so keystrokes land on the game, not our GUI.
    ; Runs in-handler (not via RefocusRoblox) because RefocusRoblox is gated on
    ; isAutomationEnabled (Story Mode only).
    if WinExist(ROBLOX_EXE)
        WinActivate ROBLOX_EXE
    ; Async playback — returns immediately; FinishPathPlayback calls
    ; UpdatePathStatusIdle when the last event fires.
    PlayPath(path)
}

; Arm is a toggle: clicking on an already-armed path disarms it.
OnPathArmClick() {
    global ddPaths, isRecordingPath
    if isRecordingPath {
        MsgBox("Stop recording first (F8).", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if IsPathArmed(name) {
        DisarmPath(name)
        UpdatePathStatusIdle()
        return
    }
    path := LoadPath(name)
    if !path {
        MsgBox("Could not load path: " name, "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if (path.trigger.type = "image" && path.trigger.imageData = "") {
        MsgBox("Path has no trigger image.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if (path.trigger.type = "timer" && path.trigger.intervalMs <= 0) {
        MsgBox("Path has no timer interval.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if (path.trigger.type != "image" && path.trigger.type != "timer") {
        MsgBox("Path has no trigger configured.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if !ArmPath(path) {
        MsgBox("Failed to arm path.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    UpdatePathStatusIdle()
}

; Single-shot trigger test — runs one FindPathTrigger against the selected
; path's trigger image and reports the result in the Last action row, so the
; user can verify detection without actually arming.
OnPathTestTriggerClick() {
    global ddPaths, txtPathLastAction, PATHS_DIR, ROBLOX_EXE, PATH_TRIGGER_VARIATION
    global COLOR_STATE_SUCCESS, COLOR_STATE_ERROR, COLOR_STATE_INFO
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path to test.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    path := LoadPath(name)
    if !path {
        MsgBox("Could not load path: " name, "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if (path.trigger.type = "timer") {
        SetShadowText(txtPathLastAction, "Test: timer paths fire on a schedule (nothing to detect)", "c" COLOR_STATE_INFO)
        return
    }
    if (path.trigger.type != "image" || path.trigger.imageData = "") {
        MsgBox("Path has no trigger image.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if !WinExist(ROBLOX_EXE) {
        SetShadowText(txtPathLastAction, "Test: Roblox not running", "c" COLOR_STATE_ERROR)
        return
    }
    tempPath := PATHS_DIR "\.tmp\test_" name ".png"
    if !WriteBase64ToFile(path.trigger.imageData, tempPath) {
        SetShadowText(txtPathLastAction, "Test: failed to write trigger", "c" COLOR_STATE_ERROR)
        return
    }
    regionHint := path.trigger.HasProp("region") ? path.trigger.region : ""
    coords := FindPathTrigger(tempPath, PATH_TRIGGER_VARIATION, regionHint)
    try FileDelete tempPath
    if coords
        SetShadowText(txtPathLastAction, "Test: match at " coords.x "," coords.y, "c" COLOR_STATE_SUCCESS)
    else
        SetShadowText(txtPathLastAction, "Test: no match", "c" COLOR_STATE_ERROR)
}

OnPathStopClick() {
    global pathActive, g_armedPaths, isRecordingPath, txtPathLastAction, COLOR_STATE_INFO
    didSomething := false
    if isRecordingPath {
        StopRecordingPath()
        SetTimer CheckPathRecordingDone, 0
        didSomething := true
    }
    if pathActive {
        StopPathPlayback()
        didSomething := true
    }
    if (g_armedPaths.Length > 0) {
        DisarmAllPaths()
        didSomething := true
    }
    UpdatePathStatusIdle()
    if didSomething
        SetShadowText(txtPathLastAction, "Stopped", "c" COLOR_STATE_INFO)
}

OnPathDeleteClick() {
    global ddPaths, txtPathLastAction, COLOR_STATE_INFO
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path to delete.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    confirm := MsgBox("Delete path '" name "'?", "Confirm Delete", "YesNo Icon? Owner" mainGui.Hwnd)
    if (confirm != "Yes")
        return
    DeletePath(name)
    RefreshPathLists()
    SetShadowText(txtPathLastAction, "Deleted: " name, "c" COLOR_STATE_INFO)
}

; Replace the selected path's trigger image — by screen capture.
OnPathRecaptureClick() {
    global ddPaths, txtPathLastAction, g_armedPaths, pathActive, isRecordingPath
    global COLOR_STATE_SUCCESS, COLOR_STATE_ERROR
    if isRecordingPath || g_armedPaths.Length > 0 || pathActive {
        MsgBox("Stop the active path or disarm all paths first.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    path := LoadPath(name)
    if !path {
        MsgBox("Could not load path: " name, "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    base64 := CaptureTriggerImageAsBase64()
    if (base64 = "")
        return
    if SavePath(name, { type: "image", imageData: base64, region: path.trigger.region }, path.events)
        SetShadowText(txtPathLastAction, "Updated trigger: " name, "c" COLOR_STATE_SUCCESS)
    else
        SetShadowText(txtPathLastAction, "Save failed", "c" COLOR_STATE_ERROR)
}

; Replace the selected path's trigger image — by uploading a file.
OnPathUploadExistingTriggerClick() {
    global ddPaths, txtPathLastAction, g_armedPaths, pathActive, isRecordingPath
    global COLOR_STATE_SUCCESS, COLOR_STATE_ERROR
    if isRecordingPath || g_armedPaths.Length > 0 || pathActive {
        MsgBox("Stop the active path or disarm all paths first.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    path := LoadPath(name)
    if !path {
        MsgBox("Could not load path: " name, "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    base64 := UploadTriggerImageAsBase64()
    if (base64 = "")
        return
    if SavePath(name, { type: "image", imageData: base64, region: path.trigger.region }, path.events)
        SetShadowText(txtPathLastAction, "Updated trigger: " name, "c" COLOR_STATE_SUCCESS)
    else
        SetShadowText(txtPathLastAction, "Save failed", "c" COLOR_STATE_ERROR)
}

OnPathRenameClick() {
    global ddPaths, txtPathLastAction, g_armedPaths, pathActive, isRecordingPath
    global COLOR_STATE_SUCCESS, COLOR_STATE_ERROR, PATHS_DIR
    if isRecordingPath || g_armedPaths.Length > 0 || pathActive {
        MsgBox("Stop the active path or disarm all paths first.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path to rename.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    ib := InputBox("Enter new name for '" name "':", "Rename Path", "w320 h130", name)
    if (ib.Result != "OK")
        return
    newName := Trim(ib.Value)
    if (newName = "" || newName = name)
        return
    if !RegExMatch(newName, "^[A-Za-z0-9 _\-]+$") {
        MsgBox("Name can only contain letters, numbers, spaces, underscores, and hyphens.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if FileExist(PATHS_DIR "\" newName ".path") {
        MsgBox("A path named '" newName "' already exists.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if RenamePath(name, newName) {
        RefreshPathLists()
        SetShadowText(txtPathLastAction, "Renamed: " name " -> " newName, "c" COLOR_STATE_SUCCESS)
    } else {
        SetShadowText(txtPathLastAction, "Rename failed", "c" COLOR_STATE_ERROR)
    }
}

; Import a .path file from anywhere into the paths folder.
OnPathImportClick() {
    global PATHS_DIR, txtPathLastAction, COLOR_STATE_SUCCESS, COLOR_STATE_ERROR
    selectedFile := FileSelect("1", , "Import path file", "Path files (*.path)")
    if !selectedFile
        return
    SplitPath selectedFile, &fileName, , , &nameNoExt
    destPath := PATHS_DIR "\" fileName
    if FileExist(destPath) {
        confirm := MsgBox("A path named '" nameNoExt "' already exists. Overwrite?", "Import Path", "YesNo Icon? Owner" mainGui.Hwnd)
        if (confirm != "Yes")
            return
    }
    try {
        FileCopy selectedFile, destPath, true
    } catch {
        SetShadowText(txtPathLastAction, "Import failed", "c" COLOR_STATE_ERROR)
        return
    }
    RefreshPathLists()
    SetShadowText(txtPathLastAction, "Imported: " nameNoExt, "c" COLOR_STATE_SUCCESS)
}

; Replace the selected path's trigger with a timer (interval in seconds).
OnPathSetTimerClick() {
    global ddPaths, txtPathLastAction, g_armedPaths, pathActive, isRecordingPath
    global COLOR_STATE_SUCCESS, COLOR_STATE_ERROR
    if isRecordingPath || g_armedPaths.Length > 0 || pathActive {
        MsgBox("Stop the active path or disarm all paths first.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    path := LoadPath(name)
    if !path {
        MsgBox("Could not load path: " name, "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    ; Pre-fill with existing interval if already a timer trigger
    defaultSecs := (path.trigger.type = "timer" && path.trigger.intervalMs > 0)
        ? Round(path.trigger.intervalMs / 1000)
        : 5
    ib := InputBox("Trigger every how many seconds?", "Set Timer Trigger", "w320 h130", defaultSecs)
    if (ib.Result != "OK")
        return
    secs := 0
    try secs := Integer(Trim(ib.Value))
    if (secs <= 0) {
        MsgBox("Interval must be a positive integer.", "Set Timer Trigger", "Icon! Owner" mainGui.Hwnd)
        return
    }
    if SavePath(name, { type: "timer", intervalMs: secs * 1000, region: path.trigger.region }, path.events)
        SetShadowText(txtPathLastAction, "Updated trigger: " name " (every " secs "s)", "c" COLOR_STATE_SUCCESS)
    else
        SetShadowText(txtPathLastAction, "Save failed", "c" COLOR_STATE_ERROR)
}

; Export the selected path to a user-chosen location.
OnPathExportClick() {
    global ddPaths, PATHS_DIR, txtPathLastAction, COLOR_STATE_SUCCESS, COLOR_STATE_ERROR
    name := ddPaths.Text
    if (name = "") {
        MsgBox("Select a path to export.", "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    sourcePath := PATHS_DIR "\" name ".path"
    if !FileExist(sourcePath) {
        MsgBox("Path file not found: " sourcePath, "Custom Pathing", "Icon! Owner" mainGui.Hwnd)
        return
    }
    destFile := FileSelect("S", name ".path", "Export path file", "Path files (*.path)")
    if !destFile
        return
    ; Ensure the destination ends with .path (5 chars)
    if (SubStr(destFile, -5) != ".path")
        destFile .= ".path"
    try {
        FileCopy sourcePath, destFile, true
    } catch {
        SetShadowText(txtPathLastAction, "Export failed", "c" COLOR_STATE_ERROR)
        return
    }
    SetShadowText(txtPathLastAction, "Exported: " name, "c" COLOR_STATE_SUCCESS)
}

; ==============================================================================
; Scan registration
; ==============================================================================
RegisterScanner(PATH_TRIGGER_INTERVAL_MS, WatchArmedPathsTick)
