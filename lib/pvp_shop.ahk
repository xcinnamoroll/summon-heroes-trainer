; ------------------------------------------------------------------------------
; PvP Shop
; Configuration UI: a 3x2 grid of item cards, each with an icon, name, an
; identifier-image uploader, a click-point calibration button, X/Y offset
; fields, and an "Auto Buy" toggle. Runtime: when any item's Auto Buy is on,
; a scan timer searches the Roblox client for each enabled item's uploaded
; image, samples the pixel at match-center + (offsetX, offsetY), and clicks
; if that pixel looks like a green (active) Buy button.
; ------------------------------------------------------------------------------

DirCreate PVP_SHOP_ICONS_DIR
DirCreate PVP_SHOP_DETECT_DIR

global g_pvpAutoBuyBtns  := Map()   ; slug -> Auto Buy button control
global g_pvpOffsetXEdits := Map()   ; slug -> offset-X edit control
global g_pvpOffsetYEdits := Map()   ; slug -> offset-Y edit control
; Cursor position captured before the first click of a buying run, so we
; can snap the mouse back once every watched item has greyed out (or the
; scan stops). 0 when nothing is saved.
global g_pvpSavedMouse := 0

; ==============================================================================
; Paths
; ==============================================================================
PvPShopDetectPath(slug) {
    global PVP_SHOP_DETECT_DIR
    return PVP_SHOP_DETECT_DIR "\" slug ".png"
}

; ==============================================================================
; Toggle / offset handlers
; ==============================================================================
OnPvPAutoBuyToggle(slug, *) {
    global pvpShopAutoBuy, g_pvpAutoBuyBtns, COLOR_BG_ACTIVE, COLOR_BG_BTN
    newVal := !pvpShopAutoBuy.Get(slug, 0)
    pvpShopAutoBuy[slug] := newVal
    btn := g_pvpAutoBuyBtns[slug]
    btn.Opt("Background" (newVal ? COLOR_BG_ACTIVE : COLOR_BG_BTN))
    btn.Redraw()
    SaveSettings()
    if IsAnyPvPAutoBuyEnabled()
        StartPvPShopScan()
    else
        StopPvPShopScan()
}

OnPvPOffsetChange(slug, which, edit, *) {
    global pvpShopOffsetX, pvpShopOffsetY
    val := 0
    if (edit.Value != "") {
        try
            val := Integer(edit.Value)
    }
    if (which = "x")
        pvpShopOffsetX[slug] := val
    else
        pvpShopOffsetY[slug] := val
    SaveSettings()
}

; ==============================================================================
; Upload identifier image
; ==============================================================================
OnPvPUploadClick(item, *) {
    global mainGui
    srcFile := FileSelect("1", , "Select " item.name " identifier image", "Images (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")
    if !srcFile
        return
    pBitmap := 0
    status := DllCall("gdiplus\GdipCreateBitmapFromFile", "Str", srcFile, "Ptr*", &pBitmap)
    if (status != 0 || !pBitmap) {
        MsgBox("Failed to load image: " srcFile, "PvP Shop", "Icon! Owner" mainGui.Hwnd)
        return
    }
    savePath := PvPShopDetectPath(item.slug)
    pEncoder := Buffer(16)
    DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", pEncoder)
    saveStatus := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Str", savePath, "Ptr", pEncoder, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    if (saveStatus != 0)
        MsgBox("Failed to save image.", "PvP Shop", "Icon! Owner" mainGui.Hwnd)
}

; ==============================================================================
; Set click point: find the uploaded image on screen, then ask the user to
; click the Buy button; store the delta from match-center as the offset.
; ==============================================================================
OnPvPSetClickPointClick(item, *) {
    global mainGui, pvpShopOffsetX, pvpShopOffsetY
    global g_pvpOffsetXEdits, g_pvpOffsetYEdits, PVP_SHOP_IMAGE_VARIATION
    detectPath := PvPShopDetectPath(item.slug)
    if !FileExist(detectPath) {
        MsgBox("Upload an identifier image for " item.name " first.", "PvP Shop", "Icon! Owner" mainGui.Hwnd)
        return
    }
    coords := FindPathTrigger(detectPath, PVP_SHOP_IMAGE_VARIATION, "")
    if !coords {
        MsgBox("Couldn't find " item.name " on screen. Open the PvP Shop with the item visible, then try again.", "PvP Shop", "Icon! Owner" mainGui.Hwnd)
        return
    }
    mainGui.Hide()
    Sleep 200
    ToolTip "Click the BUY button for " item.name " (right-click to cancel)"
    if !WaitForClick(&bx, &by) {
        ToolTip
        mainGui.Show()
        return
    }
    ToolTip
    mainGui.Show()
    dx := bx - coords.x
    dy := by - coords.y
    pvpShopOffsetX[item.slug] := dx
    pvpShopOffsetY[item.slug] := dy
    g_pvpOffsetXEdits[item.slug].Value := dx
    g_pvpOffsetYEdits[item.slug].Value := dy
    SaveSettings()
}

; ==============================================================================
; Runtime: scan enabled items, click Buy while it's green
; ==============================================================================
IsAnyPvPAutoBuyEnabled() {
    global PVP_SHOP_ITEMS, pvpShopAutoBuy
    for _, item in PVP_SHOP_ITEMS {
        if item.HasOwnProp("disabled") && item.disabled
            continue
        if pvpShopAutoBuy.Get(item.slug, 0)
            return true
    }
    return false
}

StartPvPShopScan() {
    global PVP_SHOP_SCAN_INTERVAL_MS
    SetTimer ScanPvPShop, PVP_SHOP_SCAN_INTERVAL_MS
}

StopPvPShopScan() {
    global g_pvpSavedMouse
    SetTimer ScanPvPShop, 0
    RestoreSavedMouseIfAny()
}

RestoreSavedMouseIfAny() {
    global g_pvpSavedMouse
    if !g_pvpSavedMouse
        return
    HumanMove g_pvpSavedMouse.x, g_pvpSavedMouse.y
    g_pvpSavedMouse := 0
}

; Vivid green button: G channel dominates R and B with high saturation.
; The exact shop Buy-button hue is ~#33CC66 / #50D070; this heuristic is
; tolerant enough for small theme variations without matching the grey
; (#888-ish, all channels near equal) or the red X close button.
IsBuyButtonGreen(x, y) {
    color := PixelGetColor(x, y, "RGB")
    r := (color >> 16) & 0xFF
    g := (color >>  8) & 0xFF
    b :=  color        & 0xFF
    return (g > 120 && g > r + 30 && g > b + 30)
}

ScanPvPShop() {
    global ROBLOX_EXE, PVP_SHOP_ITEMS, pvpShopAutoBuy
    global pvpShopOffsetX, pvpShopOffsetY, PVP_SHOP_IMAGE_VARIATION
    global g_pvpSavedMouse
    if !WinActive(ROBLOX_EXE)
        return
    clickedThisTick := false
    for _, item in PVP_SHOP_ITEMS {
        if item.HasOwnProp("disabled") && item.disabled
            continue
        if !pvpShopAutoBuy.Get(item.slug, 0)
            continue
        detectPath := PvPShopDetectPath(item.slug)
        if !FileExist(detectPath)
            continue
        coords := FindPathTrigger(detectPath, PVP_SHOP_IMAGE_VARIATION, "")
        if !coords
            continue
        clickX := coords.x + pvpShopOffsetX.Get(item.slug, 0)
        clickY := coords.y + pvpShopOffsetY.Get(item.slug, 0)
        if !IsBuyButtonGreen(clickX, clickY)
            continue
        ; Snapshot the cursor once, on the transition from idle to buying,
        ; so it can be restored once every watched item has greyed out.
        if !g_pvpSavedMouse {
            MouseGetPos &mx, &my
            g_pvpSavedMouse := { x: mx, y: my }
        }
        HumanMove clickX, clickY
        Click
        clickedThisTick := true
    }
    if !clickedThisTick
        RestoreSavedMouseIfAny()
}

; ==============================================================================
; Card builder
; ==============================================================================
; Builds one 3x2-grid card. Disabled items skip the Upload / Set Click Point /
; offset controls and render "Coming soon" in place of the Auto Buy toggle.
AddPvPShopItemCard(pageNum, cardX, cardY, cardW, cardH, item) {
    global mainGui, PVP_SHOP_ICONS_DIR, pvpShopAutoBuy, pvpShopOffsetX, pvpShopOffsetY
    global g_pvpAutoBuyBtns, g_pvpOffsetXEdits, g_pvpOffsetYEdits
    global COLOR_BG_MAIN, COLOR_BG_BTN, COLOR_BG_ACTIVE, COLOR_TEXT_WHITE, COLOR_TEXT_PRIMARY

    AddToPage(pageNum, mainGui.AddText("x" cardX " y" cardY " w" cardW " h" cardH " Background" COLOR_BG_MAIN, ""))

    iconSize := 64
    iconX := cardX + 8
    iconY := cardY + 8
    iconPath := PVP_SHOP_ICONS_DIR "\" item.icon
    if FileExist(iconPath)
        AddToPage(pageNum, mainGui.AddPicture("x" iconX " y" iconY " w" iconSize " h" iconSize, iconPath))
    else
        AddToPage(pageNum, mainGui.AddText("x" iconX " y" iconY " w" iconSize " h" iconSize " Background" COLOR_BG_BTN, ""))

    rightX := iconX + iconSize + 10
    rightW := cardW - (rightX - cardX) - 8
    mainGui.SetFont("s11 Bold c" item.color, "Segoe UI")
    AddToPage(pageNum, AddShadowText(mainGui, "x" rightX " y" (cardY + 10) " w" rightW " h22", item.name, "c" item.color))

    disabled := item.HasOwnProp("disabled") && item.disabled

    if !disabled {
        ; Upload + Set Click Point buttons
        btnRowY := cardY + 40
        upW := 108
        spW := rightW - upW - 6
        AddActionButton(pageNum, "x" rightX " y" btnRowY " w" upW " h24", "Upload Image", OnPvPUploadClick.Bind(item))
        AddActionButton(pageNum, "x" (rightX + upW + 6) " y" btnRowY " w" spW " h24", "Set Click Point", OnPvPSetClickPointClick.Bind(item))

        ; Offset X / Y fields
        offY := cardY + 76
        mainGui.SetFont("Norm s9 c" COLOR_TEXT_PRIMARY, "Segoe UI")
        AddToPage(pageNum, AddShadowText(mainGui, "x" rightX         " y" (offY + 2) " w50 h20", "Offset:"))
        AddToPage(pageNum, AddShadowText(mainGui, "x" (rightX + 54)  " y" (offY + 2) " w14 h20", "X"))
        xEdit := AddEditField(pageNum, "x" (rightX + 70)  " y" offY " w54 h20", pvpShopOffsetX.Get(item.slug, 0))
        AddToPage(pageNum, AddShadowText(mainGui, "x" (rightX + 130) " y" (offY + 2) " w14 h20", "Y"))
        yEdit := AddEditField(pageNum, "x" (rightX + 146) " y" offY " w54 h20", pvpShopOffsetY.Get(item.slug, 0))
        g_pvpOffsetXEdits[item.slug] := xEdit
        g_pvpOffsetYEdits[item.slug] := yEdit
        xEdit.OnEvent("Change", OnPvPOffsetChange.Bind(item.slug, "x", xEdit))
        yEdit.OnEvent("Change", OnPvPOffsetChange.Bind(item.slug, "y", yEdit))
    }

    ; Auto Buy toggle (or "Coming soon" for disabled items), bottom-anchored
    ; so disabled cards stay the same height as the rest of the grid.
    btnH := 34
    btnY := cardY + cardH - btnH - 8
    if disabled {
        mainGui.SetFont("Norm s10 c" COLOR_TEXT_WHITE, "Segoe UI")
        AddToPage(pageNum, mainGui.AddText("x" (cardX + 8) " y" btnY " w" (cardW - 16) " h" btnH " Center +0x200 Background" COLOR_BG_BTN, "Coming soon"))
        return
    }
    isOn := pvpShopAutoBuy.Get(item.slug, 0) ? true : false
    bg := isOn ? COLOR_BG_ACTIVE : COLOR_BG_BTN
    mainGui.SetFont("Norm s10 c" COLOR_TEXT_WHITE, "Segoe UI")
    btn := AddToPage(pageNum, mainGui.AddText("x" (cardX + 8) " y" btnY " w" (cardW - 16) " h" btnH " Center +0x200 Background" bg, "Auto Buy"))
    btn.OnEvent("Click", OnPvPAutoBuyToggle.Bind(item.slug))
    g_pvpAutoBuyBtns[item.slug] := btn
}
