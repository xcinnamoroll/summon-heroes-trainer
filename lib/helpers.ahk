; ------------------------------------------------------------------------------
; Search region helpers
; ------------------------------------------------------------------------------
; Turns a region name (or already-resolved object, or "") into either an
; object { xFrac, yFrac, wFrac, hFrac } bounding a fraction of the client
; area, or "" meaning "no constraint / whole haystack".
ResolveRegion(region) {
    if (region = "" || region = "whole")
        return ""
    if IsObject(region)
        return region
    switch region {
        case "top-half":     return { xFrac: 0,    yFrac: 0,    wFrac: 1,    hFrac: 0.5 }
        case "bottom-half":  return { xFrac: 0,    yFrac: 0.5,  wFrac: 1,    hFrac: 0.5 }
        case "left-half":    return { xFrac: 0,    yFrac: 0,    wFrac: 0.5,  hFrac: 1   }
        case "right-half":   return { xFrac: 0.5,  yFrac: 0,    wFrac: 0.5,  hFrac: 1   }
        case "top-left":     return { xFrac: 0,    yFrac: 0,    wFrac: 0.5,  hFrac: 0.5 }
        case "top-right":    return { xFrac: 0.5,  yFrac: 0,    wFrac: 0.5,  hFrac: 0.5 }
        case "bottom-left":  return { xFrac: 0,    yFrac: 0.5,  wFrac: 0.5,  hFrac: 0.5 }
        case "bottom-right": return { xFrac: 0.5,  yFrac: 0.5,  wFrac: 0.5,  hFrac: 0.5 }
    }
    return ""
}

; ------------------------------------------------------------------------------
; Window Helpers
; ------------------------------------------------------------------------------
DwmSetWindowColor(hwnd, captionColor, textColor) {
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 35, "UInt*", captionColor, "Int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 36, "UInt*", textColor, "Int", 4)
}

; Force a full repaint of mainGui and every child control. Called after
; scrolling so BackgroundTrans (shadow text) controls don't leave ghost
; pixels in the area they used to occupy — Windows only invalidates a
; moved transparent control's new rect, not its old one.
; Flags: RDW_INVALIDATE (0x1) | RDW_ERASE (0x4) | RDW_ALLCHILDREN (0x80).
RedrawMainGui() {
    global mainGui
    DllCall("RedrawWindow", "Ptr", mainGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x85)
}

IsRobloxActive() {
    global ROBLOX_EXE
    return WinActive(ROBLOX_EXE)
}

EnsureRobloxFocused() {
    global ROBLOX_EXE

    if !WinActive(ROBLOX_EXE) {
        WinActivate ROBLOX_EXE
        WinWaitActive ROBLOX_EXE, , 2
    }
}

RefocusRoblox() {
    global isAutomationEnabled, ROBLOX_EXE

    if !isAutomationEnabled
        return

    if WinExist(ROBLOX_EXE) {
        WinActivate ROBLOX_EXE
    }
}

UpdateActiveWindow() {
    global txtActiveWindow, ROBLOX_EXE, isAutomationEnabled
    global COLOR_STATE_WARNING, COLOR_STATE_SUCCESS
    if !isAutomationEnabled {
        SetShadowText(txtActiveWindow, "No mode selected", "c" COLOR_STATE_WARNING)
    } else if WinActive(ROBLOX_EXE) {
        SetShadowText(txtActiveWindow, "Roblox is active", "c" COLOR_STATE_SUCCESS)
    } else {
        SetShadowText(txtActiveWindow, "Roblox is running in background", "c" COLOR_STATE_SUCCESS)
    }
}

; ------------------------------------------------------------------------------
; Mouse Helpers
; ------------------------------------------------------------------------------
HumanMove(targetX, targetY) {
    global BEZIER_MIN_STEPS, BEZIER_MAX_STEPS, BEZIER_PX_PER_STEP
    global BEZIER_STEP_DELAY_MS, BEZIER_CURVE_STRENGTH

    MouseGetPos &startX, &startY

    dx := targetX - startX
    dy := targetY - startY
    distance := Sqrt(dx * dx + dy * dy)

    if (distance < 2) {
        MouseMove targetX, targetY, 0
        return
    }

    steps := Round(distance / BEZIER_PX_PER_STEP)
    if (steps < BEZIER_MIN_STEPS)
        steps := BEZIER_MIN_STEPS
    if (steps > BEZIER_MAX_STEPS)
        steps := BEZIER_MAX_STEPS

    ; Perpendicular unit vector, used to push control points off the straight line
    perpX := -dy / distance
    perpY := dx / distance

    offset1 := (Random(-100, 100) / 100) * distance * BEZIER_CURVE_STRENGTH
    offset2 := (Random(-100, 100) / 100) * distance * BEZIER_CURVE_STRENGTH

    ; Control points at ~1/3 and ~2/3 along the line, pushed sideways
    c1x := startX + dx * 0.33 + perpX * offset1
    c1y := startY + dy * 0.33 + perpY * offset1
    c2x := startX + dx * 0.66 + perpX * offset2
    c2y := startY + dy * 0.66 + perpY * offset2

    Loop steps {
        t := A_Index / steps
        ; Ease-in-out so the cursor accelerates and decelerates
        t := t * t * (3 - 2 * t)

        u := 1 - t
        uu := u * u
        uuu := uu * u
        tt := t * t
        ttt := tt * t

        px := uuu * startX + 3 * uu * t * c1x + 3 * u * tt * c2x + ttt * targetX
        py := uuu * startY + 3 * uu * t * c1y + 3 * u * tt * c2y + ttt * targetY

        MouseMove Round(px), Round(py), 0
        Sleep BEZIER_STEP_DELAY_MS
    }

    MouseMove targetX, targetY, 0
}

; ------------------------------------------------------------------------------
; GUI Helpers
; ------------------------------------------------------------------------------
AddToPage(pageNum, ctrl) {
    global g_pageControls
    g_pageControls[pageNum].Push(ctrl)
    return ctrl
}

SetTabActive(btn, active) {
    global COLOR_BG_ACTIVE, COLOR_BG_PANEL, COLOR_TAB_TEXT, COLOR_TEXT_WHITE
    btn.Opt("Background" (active ? COLOR_BG_ACTIVE : COLOR_BG_PANEL))
    btn.SetFont("Norm c" (active ? COLOR_TEXT_WHITE : COLOR_TAB_TEXT))
    btn.Redraw()
}

SetModeBtn(btn, active) {
    global COLOR_BG_ACTIVE, COLOR_BG_BTN
    btn.Opt("Background" (active ? COLOR_BG_ACTIVE : COLOR_BG_BTN))
    btn.Redraw()
}

SwitchPage(pageNum, *) {
    global g_pageControls, g_pageBtns, g_activePage
    SetTabActive(g_pageBtns[g_activePage], false)
    SetTabActive(g_pageBtns[pageNum], true)
    for i, ctrls in g_pageControls {
        visible := (i = pageNum)
        for ctrl in ctrls
            ctrl.Visible := visible
    }
    ; Reset scroll AFTER the blanket visibility loop — the loop sets every
    ; page-n control Visible=true, which would otherwise overwrite the
    ; bottom-edge clipping that Reset*Scroll applies.
    if (pageNum = 7)
        ResetCaptureScroll()
    else if (pageNum = 2)
        ResetChestScroll()
    g_activePage := pageNum
}

AddShadowText(guiObj, options, text, color := "") {
    global g_lastColor, COLOR_TEXT_PRIMARY
    if (color = "")
        color := "c" COLOR_TEXT_PRIMARY
    guiObj.SetFont(color)
    ctrl := guiObj.AddText(options " BackgroundTrans", text)
    g_lastColor[ctrl.Hwnd] := color
    return ctrl
}

SetShadowText(ctrl, text, color := "") {
    global g_lastColor
    ctrl.Value := text
    if (color != "" && g_lastColor.Get(ctrl.Hwnd, "") != color) {
        ctrl.SetFont(color)
        g_lastColor[ctrl.Hwnd] := color
    }
}

UpdateStatusTip() {
    global isAutomationEnabled, automationMode
    global autoRetryCount, AUTO_RETRIES_BEFORE_ADVANCE
    global txtStatus, txtRetries, txtPhase, txtLastAction, lastAction, edtCurrentRetry, missingImageWarned
    global COLOR_STATE_ERROR, COLOR_STATE_SUCCESS, COLOR_STATE_INFO

    ; Sync current retry control without triggering ApplySettings
    currentVal := edtCurrentRetry.Value
    if (currentVal = "" || Integer(currentVal) != autoRetryCount) {
        edtCurrentRetry.OnEvent("Change", ApplySettings, 0)
        edtCurrentRetry.Value := autoRetryCount
        edtCurrentRetry.OnEvent("Change", ApplySettings)
    }

    if !isAutomationEnabled {
        SetShadowText(txtStatus, "OFF", "c" COLOR_STATE_ERROR)
        SetShadowText(txtRetries, "0/" AUTO_RETRIES_BEFORE_ADVANCE, "c" COLOR_STATE_INFO)
        SetShadowText(txtPhase, "-", "c" COLOR_STATE_INFO)
        SetShadowText(txtLastAction, lastAction, "c" COLOR_STATE_INFO)
        return
    }

    ; Show missing image warning if any
    if (missingImageWarned.Count > 0) {
        for path, _ in missingImageWarned {
            SplitPath path, &fileName
            SetShadowText(txtStatus, "Missing: " fileName, "c" COLOR_STATE_ERROR)
            break
        }
    } else {
        SetShadowText(txtStatus, StrUpper(automationMode), "c" COLOR_STATE_SUCCESS)
    }

    SetShadowText(txtRetries, autoRetryCount "/" AUTO_RETRIES_BEFORE_ADVANCE, "c" COLOR_STATE_INFO)
    global g_autoSawEndRound
    if !g_autoSawEndRound
        SetShadowText(txtPhase, "Waiting for round to end", "c" COLOR_STATE_INFO)
    else if (automationMode = "auto" && autoRetryCount >= AUTO_RETRIES_BEFORE_ADVANCE)
        SetShadowText(txtPhase, "Looking for next stage", "c" COLOR_STATE_INFO)
    else
        SetShadowText(txtPhase, "Retrying stage", "c" COLOR_STATE_INFO)
    SetShadowText(txtLastAction, lastAction, "c" COLOR_STATE_INFO)
}

; ------------------------------------------------------------------------------
; GDI+ Helpers
; ------------------------------------------------------------------------------
GdipInit() {
    hLib := DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
    si := Buffer(24, 0)
    NumPut("UInt", 1, si)
    token := 0
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)
    return { token: token, hLib: hLib }
}

GdipShutdown(gdip) {
    DllCall("gdiplus\GdiplusShutdown", "Ptr", gdip.token)
    DllCall("FreeLibrary", "Ptr", gdip.hLib)
}

GetImageCenter(imagePath) {
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", imagePath, "Ptr*", &pBitmap)

    w := 0, h := 0
    DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &w)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &h)

    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)

    return { x: w // 2, y: h // 2 }
}

; ------------------------------------------------------------------------------
; Anti-Cheat Detection
; Kernel-level anti-cheats (Vanguard in particular) can block PrintWindow
; silently, making image detection return black bitmaps. Warn the user on
; startup so they aren't left wondering why automation does nothing.
; ------------------------------------------------------------------------------
DetectAntiCheatProcesses() {
    antiCheats := Map(
        "vgc.exe",               "Riot Vanguard",
        "vgtray.exe",            "Riot Vanguard",
        "EasyAntiCheat.exe",     "Easy Anti-Cheat",
        "EasyAntiCheat_EOS.exe", "Easy Anti-Cheat (EOS)",
        "BEService.exe",         "BattlEye",
        "FaceitService.exe",     "Faceit Anti-Cheat",
        "FACEITService.exe",     "Faceit Anti-Cheat"
    )
    detected := Map()
    for exe, name in antiCheats {
        if ProcessExist(exe)
            detected[name] := true
    }
    return detected
}

WarnIfAntiCheatRunning() {
    global mainGui
    detected := DetectAntiCheatProcesses()
    if detected.Count = 0
        return
    running := ""
    for name in detected
        running .= "  - " name "`n"
    msg := "The following kernel-level anti-cheat is running:`n`n" running
         . "`nKernel anti-cheats can block PrintWindow (the API this "
         . "trainer uses to read Roblox's pixels), so image detection will "
         . "silently capture black frames and no button clicks will fire.`n`n"
         . "Known kernel anti-cheats that can block us:`n"
         . "  - Riot Vanguard (Valorant)`n"
         . "  - Easy Anti-Cheat (Fortnite, Apex, etc.)`n"
         . "  - BattlEye (PUBG, Rust, etc.)`n"
         . "  - Faceit Anti-Cheat`n`n"
         . "Close the anti-cheat (or reboot if it's Vanguard) before "
         . "starting automation."
    MsgBox(msg, "Anti-Cheat Detected", "Icon! Owner" mainGui.Hwnd)
}

; ------------------------------------------------------------------------------
; Version Helpers
; ------------------------------------------------------------------------------
CompareVersions(v1, v2) {
    parts1 := StrSplit(v1, ".")
    parts2 := StrSplit(v2, ".")
    maxLen := Max(parts1.Length, parts2.Length)
    Loop maxLen {
        p1 := A_Index <= parts1.Length ? Integer(parts1[A_Index]) : 0
        p2 := A_Index <= parts2.Length ? Integer(parts2[A_Index]) : 0
        if (p1 > p2)
            return 1
        if (p1 < p2)
            return -1
    }
    return 0
}
