; ------------------------------------------------------------------------------
; Auto Chest
; Per-map configuration: a loading-screen image used to detect which map is
; active, plus a saved custom path selected to run on that map.
; ------------------------------------------------------------------------------

DirCreate AUTO_CHEST_DIR

; Scroll state for page 2 (set once when gui.ahk builds the page).
global g_chestScrollable        := []
global g_chestScrollOffset      := 0
global g_chestContentAreaTop    := 0
global g_chestContentAreaBottom := 0

; Per-map GUI control maps, populated as sections are built.
global g_chestPathDropdowns := Map()
global g_chestImageStatus   := Map()

; Dropdown label used when no path is selected for a map.
global CHEST_PATH_NONE := "(none)"

; Set while RefreshChestPathDropdowns is rebuilding the lists, so the
; Change events fired by Delete/Add/Choose don't spuriously overwrite the
; saved path for every map.
global g_chestRefreshing := false

; ==============================================================================
; Persistence
; ==============================================================================
ChestMapSlug(mapName) {
    return StrReplace(mapName, " ", "_")
}

ChestMapImagePath(mapName) {
    global AUTO_CHEST_DIR
    return AUTO_CHEST_DIR "\" ChestMapSlug(mapName) ".png"
}

GetChestMapPath(mapName) {
    global SETTINGS_FILE
    val := IniRead(SETTINGS_FILE, "AutoChest", "Path_" ChestMapSlug(mapName), "")
    return val
}

SetChestMapPath(mapName, pathName) {
    global SETTINGS_FILE
    key := "Path_" ChestMapSlug(mapName)
    if (pathName = "" || pathName = CHEST_PATH_NONE) {
        try IniDelete SETTINGS_FILE, "AutoChest", key
    } else {
        IniWrite pathName, SETTINGS_FILE, "AutoChest", key
    }
}

FormatChestImageStatus(mapName) {
    imgPath := ChestMapImagePath(mapName)
    if !FileExist(imgPath)
        return "Image: (none)"
    dims := GetImageDimensionsFromFile(imgPath)
    return "Image: " dims.w "x" dims.h
}

; ==============================================================================
; Scroll helpers (mirrors image_capture.ahk's pattern)
; ==============================================================================
AddChestScrollable(ctrl, baseY) {
    global g_chestScrollable
    ctrl.GetPos(, , , &h)
    g_chestScrollable.Push({ ctrl: ctrl, baseY: baseY, height: h })
    return ctrl
}

; Shows an item only when it fits entirely between content top and bottom,
; so partial items at either edge don't spill past the background panel.
ChestItemVisibleAt(item, newY) {
    global g_chestContentAreaTop, g_chestContentAreaBottom
    return (newY >= g_chestContentAreaTop - 5) && (newY + item.height <= g_chestContentAreaBottom)
}

ScrollChest(delta) {
    global g_chestScrollable, g_chestScrollOffset, g_chestContentAreaTop
    maxBaseY := 0
    for item in g_chestScrollable
        if (item.baseY > maxBaseY)
            maxBaseY := item.baseY
    maxOffset := Max(0, maxBaseY - g_chestContentAreaTop)
    newOffset := Max(0, Min(maxOffset, g_chestScrollOffset + delta))
    if (newOffset = g_chestScrollOffset)
        return
    g_chestScrollOffset := newOffset
    for item in g_chestScrollable {
        newY := item.baseY - g_chestScrollOffset
        item.ctrl.Move(, newY)
        item.ctrl.Visible := ChestItemVisibleAt(item, newY)
    }
    RedrawMainGui()
}

; Always re-applies positions and visibility — SwitchPage blanket-sets all
; page controls Visible=true, so we need to re-hide any that sit beyond the
; content area even when the offset was already 0.
ResetChestScroll() {
    global g_chestScrollable, g_chestScrollOffset
    g_chestScrollOffset := 0
    for item in g_chestScrollable {
        item.ctrl.Move(, item.baseY)
        item.ctrl.Visible := ChestItemVisibleAt(item, item.baseY)
    }
    RedrawMainGui()
}

; ==============================================================================
; Image capture / upload
; ==============================================================================
CaptureChestMapImage(mapName) {
    global mainGui
    savePath := ChestMapImagePath(mapName)
    mainGui.Hide()
    Sleep 200
    ToolTip "Click TOP-LEFT corner of " mapName " loading image (right-click to cancel)"
    if !WaitForClick(&x1, &y1) {
        ToolTip
        mainGui.Show()
        return false
    }
    ToolTip "Click BOTTOM-RIGHT corner (right-click to cancel)"
    if !WaitForClick(&x2, &y2) {
        ToolTip
        mainGui.Show()
        return false
    }
    ToolTip
    if (x2 <= x1 || y2 <= y1) {
        mainGui.Show()
        MsgBox("Invalid selection — bottom-right must be below and right of top-left.", "Auto Chest", "Icon! Owner" mainGui.Hwnd)
        return false
    }
    saved := CaptureScreenRegion(x1, y1, x2 - x1, y2 - y1, savePath)
    mainGui.Show()
    if !saved {
        MsgBox("Failed to save image to:`n" savePath, "Auto Chest", "Icon! Owner" mainGui.Hwnd)
        return false
    }
    return true
}

UploadChestMapImage(mapName) {
    global mainGui
    srcFile := FileSelect("1", , "Select " mapName " loading image", "Images (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")
    if !srcFile
        return false
    pBitmap := 0
    status := DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", srcFile, "Ptr*", &pBitmap)
    if (status != 0 || !pBitmap) {
        MsgBox("Failed to load image: " srcFile, "Auto Chest", "Icon! Owner" mainGui.Hwnd)
        return false
    }
    savePath := ChestMapImagePath(mapName)
    pEncoder := Buffer(16)
    DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", pEncoder)
    saveStatus := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Str", savePath, "Ptr", pEncoder, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    if (saveStatus != 0) {
        MsgBox("Failed to convert image to PNG.", "Auto Chest", "Icon! Owner" mainGui.Hwnd)
        return false
    }
    return true
}

; ==============================================================================
; Event handlers
; ==============================================================================
OnChestCaptureClick(mapName, *) {
    global g_chestImageStatus
    if CaptureChestMapImage(mapName)
        SetShadowText(g_chestImageStatus[mapName], FormatChestImageStatus(mapName))
}

OnChestUploadClick(mapName, *) {
    global g_chestImageStatus
    if UploadChestMapImage(mapName)
        SetShadowText(g_chestImageStatus[mapName], FormatChestImageStatus(mapName))
}

OnChestPathChange(mapName, ddCtrl, *) {
    global g_chestRefreshing
    if g_chestRefreshing
        return
    name := ddCtrl.Text
    SetChestMapPath(mapName, name = CHEST_PATH_NONE ? "" : name)
}

OnToggleAutoChest(*) {
    global chkChestEnabled, autoChestEnabled, isAutomationEnabled
    autoChestEnabled := chkChestEnabled.Value
    SaveSettings()
    if (autoChestEnabled && isAutomationEnabled)
        StartAutoChestScan()
    else
        StopAutoChestScan()
}

; ==============================================================================
; Runtime: scan for map loading images while Story Mode auto/retry is active
; ==============================================================================
StartAutoChestScan() {
    global autoChestEnabled, CHEST_SCAN_INTERVAL_MS
    global g_chestFoundState, g_chestActiveMap, g_chestArmedPath
    global txtChestState, COLOR_STATE_INFO
    if !autoChestEnabled
        return
    g_chestFoundState := Map()
    g_chestActiveMap := ""
    g_chestArmedPath := ""
    SetTimer ScanChestMaps, CHEST_SCAN_INTERVAL_MS
    if IsSet(txtChestState)
        SetShadowText(txtChestState, "Scanning", "c" COLOR_STATE_INFO)
}

StopAutoChestScan() {
    global g_chestFoundState, g_chestActiveMap, g_chestArmedPath
    SetTimer ScanChestMaps, 0
    ; Disarm anything Auto Chest armed so it doesn't keep firing after stop.
    if (g_chestArmedPath != "" && IsPathArmed(g_chestArmedPath))
        DisarmPath(g_chestArmedPath)
    g_chestFoundState := Map()
    g_chestActiveMap := ""
    g_chestArmedPath := ""
    UpdateChestStatusIdle()
}

; Applies on startup, on toggle-off, and on Story Mode stop. Reflects whether
; auto chest is enabled (Idle) or disabled (off) while nothing is running.
UpdateChestStatusIdle() {
    global autoChestEnabled
    global txtChestState, txtChestMap, txtChestPath
    global COLOR_STATE_ERROR, COLOR_STATE_INFO, COLOR_STATE_WARNING
    if !IsSet(txtChestState)
        return
    if autoChestEnabled
        SetShadowText(txtChestState, "Idle", "c" COLOR_STATE_WARNING)
    else
        SetShadowText(txtChestState, "Disabled", "c" COLOR_STATE_ERROR)
    SetShadowText(txtChestMap, "-", "c" COLOR_STATE_INFO)
    SetShadowText(txtChestPath, "-", "c" COLOR_STATE_INFO)
}

; Timer callback. The loading image selects which path Auto Chest arms —
; the path's own trigger is what actually starts playback. Uses per-map
; edge detection so we only act on the transition from not-visible to
; visible (one arm action per map entry). When the detected map changes,
; the previously armed path is disarmed first. Gated on WinActive so we
; don't touch arm state while Roblox is backgrounded; not gated on
; pathActive because armed-but-idle state is fine during playback.
ScanChestMaps() {
    global ROBLOX_EXE, autoChestEnabled, isAutomationEnabled
    global AUTO_CHEST_MAPS, g_chestFoundState, g_chestActiveMap, g_chestArmedPath
    global PATH_TRIGGER_VARIATION
    global txtChestState, txtChestMap, txtChestPath, txtChestLastAction
    global COLOR_STATE_INFO, COLOR_STATE_SUCCESS, COLOR_STATE_ERROR, COLOR_STATE_WARNING

    if !autoChestEnabled || !isAutomationEnabled
        return
    if !WinActive(ROBLOX_EXE) {
        if IsSet(txtChestState)
            SetShadowText(txtChestState, "Paused (Roblox not active)", "c" COLOR_STATE_WARNING)
        return
    }

    if IsSet(txtChestState) {
        if (g_chestArmedPath != "")
            SetShadowText(txtChestState, "Armed", "c" COLOR_STATE_SUCCESS)
        else
            SetShadowText(txtChestState, "Scanning", "c" COLOR_STATE_INFO)
    }

    for _, mapName in AUTO_CHEST_MAPS {
        imgPath := ChestMapImagePath(mapName)
        if !FileExist(imgPath)
            continue
        pathName := GetChestMapPath(mapName)
        if (pathName = "")
            continue

        coords := FindPathTrigger(imgPath, PATH_TRIGGER_VARIATION, "")
        wasFound := g_chestFoundState.Get(mapName, false)

        if coords {
            if wasFound
                continue
            g_chestFoundState[mapName] := true

            ; Re-entry of the same map with the same path still armed: nothing to do.
            stillArmed := (g_chestArmedPath != "" && IsPathArmed(g_chestArmedPath))
            if (g_chestActiveMap = mapName && stillArmed && g_chestArmedPath = pathName)
                continue

            ; Switching maps (or our arm was cleared externally) — swap arms.
            if stillArmed
                DisarmPath(g_chestArmedPath)

            path := LoadPath(pathName)
            if !path {
                g_chestArmedPath := ""
                SetShadowText(txtChestLastAction, "Failed to load path: " pathName, "c" COLOR_STATE_ERROR)
                continue
            }
            if !ArmPath(path) {
                g_chestArmedPath := ""
                SetShadowText(txtChestLastAction, "Failed to arm: " pathName, "c" COLOR_STATE_ERROR)
                continue
            }

            g_chestActiveMap := mapName
            g_chestArmedPath := path.name
            SetShadowText(txtChestMap,        mapName,  "c" COLOR_STATE_SUCCESS)
            SetShadowText(txtChestPath,       pathName, "c" COLOR_STATE_SUCCESS)
            SetShadowText(txtChestState,      "Armed",  "c" COLOR_STATE_SUCCESS)
            SetShadowText(txtChestLastAction, "Armed " pathName " for " mapName, "c" COLOR_STATE_SUCCESS)
            return
        } else if wasFound {
            g_chestFoundState[mapName] := false
        }
    }
}

; Populate every per-map dropdown with the current saved-paths list plus a
; "(none)" entry, then restore the previously selected path for each map.
RefreshChestPathDropdowns() {
    global g_chestPathDropdowns, CHEST_PATH_NONE, g_chestRefreshing
    g_chestRefreshing := true
    try {
        paths := ListPaths()
        for mapName, dd in g_chestPathDropdowns {
            saved := GetChestMapPath(mapName)
            dd.Delete()
            dd.Add([CHEST_PATH_NONE])
            for p in paths
                dd.Add([p])
            chosen := 1
            if (saved != "") {
                for i, p in paths {
                    if (p = saved) {
                        chosen := i + 1  ; +1 for the leading "(none)" entry
                        break
                    }
                }
            }
            dd.Choose(chosen)
        }
    } finally {
        g_chestRefreshing := false
    }
}

; ==============================================================================
; GUI section builder
; ==============================================================================
; Builds one map section inside the scrollable content area, registering each
; control with AddChestScrollable so it moves with the wheel. Returns the
; y-coordinate at which the next section should start.
AddChestMapSection(pageNum, y, mapName) {
    global mainGui, contentX, wideContentW
    global g_chestPathDropdowns, g_chestImageStatus
    global COLOR_TEXT_PRIMARY, COLOR_BG_INPUT, COLOR_TEXT_WHITE, COLOR_DIVIDER

    ; Section header
    hdr := AddSectionHeader(pageNum, mapName, "y" y, contentX, wideContentW)
    AddChestScrollable(hdr, y)

    ; Image status line
    statusY := y + 24
    mainGui.SetFont("Norm s9 c" COLOR_TEXT_PRIMARY, "Segoe UI")
    statusCtrl := AddToPage(pageNum, AddShadowText(mainGui, "x" contentX " y" statusY " w" wideContentW " h18", FormatChestImageStatus(mapName)))
    AddChestScrollable(statusCtrl, statusY)
    g_chestImageStatus[mapName] := statusCtrl

    ; Capture / Upload buttons
    btnY := statusY + 22
    btnW := (wideContentW - 5) // 2
    capBtn := AddActionButton(pageNum, "x" contentX " y" btnY " w" btnW " h28", "Capture Loading Image", OnChestCaptureClick.Bind(mapName))
    upBtn  := AddActionButton(pageNum, "x" (contentX + btnW + 5) " y" btnY " w" btnW " h28", "Upload Loading Image", OnChestUploadClick.Bind(mapName))
    AddChestScrollable(capBtn, btnY)
    AddChestScrollable(upBtn, btnY)

    ; Path dropdown
    pathY := btnY + 34
    labelW := 50
    mainGui.SetFont("Norm s9 c" COLOR_TEXT_PRIMARY, "Segoe UI")
    lbl := AddToPage(pageNum, AddShadowText(mainGui, "x" contentX " y" (pathY + 3) " w" labelW " h20", "Path:"))
    AddChestScrollable(lbl, pathY + 3)
    ddX := contentX + labelW
    ddW := wideContentW - labelW
    dd := mainGui.AddDropDownList("x" ddX " y" pathY " w" ddW " Background" COLOR_BG_INPUT)
    dd.SetFont("c" COLOR_TEXT_WHITE)
    AddToPage(pageNum, dd)
    AddChestScrollable(dd, pathY)
    g_chestPathDropdowns[mapName] := dd
    dd.OnEvent("Change", OnChestPathChange.Bind(mapName))

    ; Trailing divider
    divY := pathY + 32
    div := AddToPage(pageNum, mainGui.AddText("x" contentX " y" divY " w" wideContentW " h1 Background" COLOR_DIVIDER, ""))
    AddChestScrollable(div, divY)

    return divY + 10
}
