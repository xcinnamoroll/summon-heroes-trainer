; ------------------------------------------------------------------------------
; Image Capture
; Lets the user click to define a region on screen, saves it as a PNG for
; use as a detection needle in story mode automation.
; ------------------------------------------------------------------------------

OpenButtonsFolder() {
    global APP_BUTTONS_DIR
    Run APP_BUTTONS_DIR
}

; Reads the saved region name from "<imagePath>.region" or returns the
; NEEDLE_REGIONS default, so the dropdown can be populated correctly on
; GUI startup.
GetSavedImageRegion(imagePath) {
    global NEEDLE_REGIONS
    sidecar := imagePath ".region"
    if FileExist(sidecar) {
        try {
            name := Trim(FileRead(sidecar))
            if (name != "")
                return name
        }
    }
    if NEEDLE_REGIONS.Has(imagePath)
        return NEEDLE_REGIONS[imagePath]
    return "whole"
}

; Writes the region name to "<imagePath>.region" so SearchCapture's
; ResolveEffectiveRegion picks it up on the next scan. Deletes the sidecar
; if the user selects "whole" (matches "no constraint").
SaveImageRegion(imagePath, regionName) {
    sidecar := imagePath ".region"
    if (regionName = "" || regionName = "whole") {
        if FileExist(sidecar)
            try FileDelete sidecar
        return
    }
    f := FileOpen(sidecar, "w")
    if !f
        return
    f.Write(regionName)
    f.Close()
}

; Dropdown Change handler — looks up which imagePath this dropdown controls
; and saves the chosen region name.
OnCaptureRegionChange(imagePath, ddCtrl, *) {
    global REGION_CHOICES
    idx := ddCtrl.Value
    if (idx < 1 || idx > REGION_CHOICES.Length)
        return
    SaveImageRegion(imagePath, REGION_CHOICES[idx][2])
}

AddCaptureScrollable(ctrl, baseY) {
    global g_captureScrollable
    ctrl.GetPos(, , , &h)
    g_captureScrollable.Push({ctrl: ctrl, baseY: baseY, height: h})
    return ctrl
}

; Shows an item only when it fits entirely between content top and bottom,
; so partial items at either edge don't spill past the background panel.
CaptureItemVisibleAt(item, newY) {
    global g_capContentAreaTop, g_capContentAreaBottom
    return (newY >= g_capContentAreaTop - 5) && (newY + item.height <= g_capContentAreaBottom)
}

ScrollCapture(delta) {
    global g_captureScrollable, g_capScrollOffset, g_capContentAreaTop
    maxBaseY := 0
    for item in g_captureScrollable
        if (item.baseY > maxBaseY)
            maxBaseY := item.baseY
    maxOffset := Max(0, maxBaseY - g_capContentAreaTop)
    newOffset := Max(0, Min(maxOffset, g_capScrollOffset + delta))
    if (newOffset = g_capScrollOffset)
        return
    g_capScrollOffset := newOffset
    for item in g_captureScrollable {
        newY := item.baseY - g_capScrollOffset
        item.ctrl.Move(, newY)
        item.ctrl.Visible := CaptureItemVisibleAt(item, newY)
    }
    RedrawMainGui()
}

ResetCaptureScroll() {
    global g_captureScrollable, g_capScrollOffset
    g_capScrollOffset := 0
    for item in g_captureScrollable {
        item.ctrl.Move(, item.baseY)
        item.ctrl.Visible := CaptureItemVisibleAt(item, item.baseY)
    }
    RedrawMainGui()
}

; Return 0 after handling so the default control behavior is suppressed —
; otherwise hovering the wheel over a ComboBox would change its selection
; instead of scrolling the page.
WM_MOUSEWHEEL_Capture(wParam, *) {
    global g_activePage
    rawDelta := (wParam >> 16) & 0xFFFF
    if (rawDelta > 32767)
        rawDelta -= 65536
    delta := rawDelta > 0 ? -30 : 30
    if (g_activePage = 7) {
        ScrollCapture(delta)
        return 0
    } else if (g_activePage = 2) {
        ScrollChest(delta)
        return 0
    }
}

CaptureButtonImage(savePath, label) {
    mainGui.Hide()
    Sleep 200

    ToolTip "Click TOP-LEFT corner of " label " (right-click to cancel)"
    if !WaitForClick(&x1, &y1) {
        ToolTip
        mainGui.Show()
        return
    }

    ToolTip "Click BOTTOM-RIGHT corner of " label " (right-click to cancel)"
    if !WaitForClick(&x2, &y2) {
        ToolTip
        mainGui.Show()
        return
    }

    ToolTip

    if (x2 <= x1 || y2 <= y1) {
        mainGui.Show()
        MsgBox "Invalid selection — bottom-right must be below and right of top-left."
        return
    }

    saved := CaptureScreenRegion(x1, y1, x2 - x1, y2 - y1, savePath)
    if g_needleCache.Has(savePath)
        g_needleCache.Delete(savePath)
    if g_needleLastFound.Has(savePath)
        g_needleLastFound.Delete(savePath)

    mainGui.Show()
    if saved {
        ToolTip "Saved: " label
        SetTimer () => ToolTip(), -1500
    } else {
        MsgBox("Failed to save " label " image to:`n" savePath "`n`nCheck disk space and folder permissions.", "Save Failed", "Icon! Owner" mainGui.Hwnd)
    }
}

WaitForClick(&outX, &outY) {
    Loop {
        if GetKeyState("RButton", "P") {
            KeyWait "RButton"
            return false
        }
        if GetKeyState("LButton", "P") {
            MouseGetPos &outX, &outY
            KeyWait "LButton"
            return true
        }
        Sleep 10
    }
}

CaptureScreenRegion(x, y, w, h, filePath) {
    ; Create bitmap and graphics
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)
    pGraphics := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics)

    ; GetDC(0) on Windows 10/11 returns a DC spanning the virtual screen,
    ; so BitBlt works regardless of which monitor Roblox is on.
    hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    hMemDC := 0
    DllCall("gdiplus\GdipGetDC", "Ptr", pGraphics, "Ptr*", &hMemDC)
    blitOk := false
    try {
        blitOk := DllCall("BitBlt", "Ptr", hMemDC, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hDC, "Int", x, "Int", y, "UInt", 0x00CC0020)
    } finally {
        DllCall("gdiplus\GdipReleaseDC", "Ptr", pGraphics, "Ptr", hMemDC)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
    }

    saveStatus := 1
    if blitOk {
        ; Save as PNG
        pEncoder := Buffer(16)
        DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", pEncoder)
        saveStatus := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Str", filePath, "Ptr", pEncoder, "Ptr", 0)
    }

    ; Cleanup
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)

    return blitOk && saveStatus = 0
}
