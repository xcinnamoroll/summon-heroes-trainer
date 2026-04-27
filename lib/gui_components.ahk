; ------------------------------------------------------------------------------
; GUI Components
; Reusable builders for consistent page styling. Callers never set fonts or
; colors directly — they pick a component and pass position options + text.
; Adding a new page should look like:
;
;     AddPageTitle(n, "My Page")
;     AddPageSubtitle(n, "What this page does")
;     AddSectionDivider(n)
;     AddSectionHeader(n, "Some Section")
;     ...
;
; The helpers manage SetFont cumulative state so Bold never leaks between
; titles/headers and body content.
; ------------------------------------------------------------------------------

; ==============================================================================
; Page structure
; ==============================================================================
AddPageTitle(pageNum, text, boxX := "", boxW := "") {
    global mainGui, contentX, contentY, contentW
    if (boxX = "")
        boxX := contentX
    if (boxW = "")
        boxW := contentW
    mainGui.SetFont("s12 Bold", "Segoe UI")
    return AddToPage(pageNum, AddShadowText(mainGui, "x" boxX " y" contentY " w" boxW " h28", text))
}

AddPageSubtitle(pageNum, text, boxX := "", boxW := "") {
    global mainGui, contentX, contentW
    if (boxX = "")
        boxX := contentX
    if (boxW = "")
        boxW := contentW
    mainGui.SetFont("Norm s8", "Segoe UI")
    return AddToPage(pageNum, AddShadowText(mainGui, "x" boxX " y+3 w" boxW " h16", text))
}

AddSectionDivider(pageNum, yOpt := "y+8", boxX := "", boxW := "") {
    global mainGui, contentX, contentW, COLOR_DIVIDER
    if (boxX = "")
        boxX := contentX
    if (boxW = "")
        boxW := contentW
    return AddToPage(pageNum, mainGui.AddText("x" boxX " " yOpt " w" boxW " h1 Background" COLOR_DIVIDER, ""))
}

AddSectionHeader(pageNum, text, yOpt := "y+12", boxX := "", boxW := "") {
    global mainGui, contentX, contentW, COLOR_TEXT_PRIMARY
    if (boxX = "")
        boxX := contentX
    if (boxW = "")
        boxW := contentW
    mainGui.SetFont("s10 c" COLOR_TEXT_PRIMARY " Bold", "Segoe UI")
    ctrl := AddToPage(pageNum, AddShadowText(mainGui, "x" boxX " " yOpt " w" boxW " h20", text))
    ; Restore non-bold default for whatever content follows this header
    mainGui.SetFont("Norm s10 c" COLOR_TEXT_PRIMARY, "Segoe UI")
    return ctrl
}

; ==============================================================================
; Input fields
; ==============================================================================
AddEditField(pageNum, positionOptions, initialValue := "") {
    global mainGui, COLOR_BG_INPUT, COLOR_TEXT_WHITE
    edt := AddToPage(pageNum, mainGui.AddEdit(positionOptions " Background" COLOR_BG_INPUT, initialValue))
    edt.SetFont("c" COLOR_TEXT_WHITE)
    return edt
}

AddNumberEditField(pageNum, positionOptions, initialValue) {
    global mainGui, COLOR_BG_INPUT, COLOR_TEXT_WHITE
    edt := AddToPage(pageNum, mainGui.AddEdit(positionOptions " Number Background" COLOR_BG_INPUT, initialValue))
    edt.SetFont("c" COLOR_TEXT_WHITE)
    return edt
}

AddDropDownField(pageNum, positionOptions) {
    global mainGui, COLOR_BG_INPUT, COLOR_TEXT_WHITE
    dd := AddToPage(pageNum, mainGui.AddDropDownList(positionOptions " Background" COLOR_BG_INPUT))
    dd.SetFont("c" COLOR_TEXT_WHITE)
    return dd
}

; ==============================================================================
; Buttons
; ==============================================================================
; variant: "default" — purple action (Auto, Retry, Play, etc.)
;          "stop"    — red STOP button
AddActionButton(pageNum, positionOptions, text, onClick := "", variant := "default") {
    global mainGui, COLOR_BG_BTN, COLOR_BTN_STOP, COLOR_TEXT_WHITE
    bg := (variant = "stop") ? COLOR_BTN_STOP : COLOR_BG_BTN
    mainGui.SetFont("Norm s9 c" COLOR_TEXT_WHITE, "Segoe UI")
    btn := AddToPage(pageNum, mainGui.AddText(positionOptions " Center +0x200 Background" bg, text))
    if onClick
        btn.OnEvent("Click", onClick)
    return btn
}

; Checkbox + a clickable text label that mirrors its value.
; onClick is called after either control is clicked (the label handler flips
; the checkbox value first). Returns the checkbox so the caller can read Value
; later; the label control is managed entirely by this helper.
AddCheckboxRow(pageNum, chkOptions, labelText, labelOptions, isChecked, onClick) {
    global mainGui
    chk := AddToPage(pageNum, mainGui.AddCheckbox(chkOptions (isChecked ? " Checked" : ""), ""))
    lbl := AddToPage(pageNum, AddShadowText(mainGui, labelOptions, labelText))
    chk.OnEvent("Click", (*) => onClick())
    lbl.OnEvent("Click", (*) => (chk.Value := !chk.Value, onClick()))
    return chk
}

; ==============================================================================
; Field labels and status rows
; ==============================================================================
; A small text label used before an edit/dropdown/etc. Consistent size and color
; across every page.
AddFieldLabel(pageNum, text, yOpt := "y+8") {
    global mainGui, contentX, COLOR_TEXT_PRIMARY
    mainGui.SetFont("Norm s9 c" COLOR_TEXT_PRIMARY, "Segoe UI")
    return AddToPage(pageNum, AddShadowText(mainGui, "x" contentX " " yOpt " w180", text))
}

; One row of the Story Mode status box: a fixed-width label on the left plus a
; value that fills the remaining width. The status box's inner x-offset is
; computed from contentX/contentW so callers only pass labelWidth + content.
; Returns the value control so callers can update it later.
AddStatusRow(pageNum, rowY, labelText, labelWidth, valueText, valueColor := "", boxX := "", boxW := "") {
    global mainGui, contentX, contentW
    if (boxX = "")
        boxX := contentX
    if (boxW = "")
        boxW := contentW
    lx := boxX + 8
    AddToPage(pageNum, AddShadowText(mainGui, "x" lx " y" rowY " w" labelWidth " h20", labelText))
    valueX := lx + labelWidth + 4
    valueW := boxW - 20 - labelWidth
    return AddToPage(pageNum, AddShadowText(mainGui, "x" valueX " y" rowY " w" valueW " h20", valueText, valueColor))
}

; ==============================================================================
; Image Capture helpers (category header + subtitle + paired capture buttons)
; ==============================================================================
; Scrollable category on the Image Capture page: a bold title + non-bold
; subtitle, both registered with AddCaptureScrollable so the scroll wheel
; moves them. Returns the y-coordinate after the subtitle for chaining.
AddCaptureCategory(pageNum, capY, titleText, subtitleText, boxX := "", boxW := "") {
    global mainGui, contentX, contentW, COLOR_TEXT_PRIMARY
    if (boxX = "")
        boxX := contentX
    if (boxW = "")
        boxW := contentW
    mainGui.SetFont("s9 c" COLOR_TEXT_PRIMARY " Bold", "Segoe UI")
    AddCaptureScrollable(AddToPage(pageNum, AddShadowText(mainGui, "x" boxX " y" capY " w" boxW " h18", titleText)), capY)
    subtitleY := capY + 20
    mainGui.SetFont("Norm s9 c" COLOR_TEXT_PRIMARY, "Segoe UI")
    AddCaptureScrollable(AddToPage(pageNum, AddShadowText(mainGui, "x" boxX " y" subtitleY " w" boxW " h16", subtitleText)), subtitleY)
    return subtitleY + 20
}

; Pair of capture buttons side-by-side at the given capY, each half the
; box width minus a 5px gap. Returns the y-coordinate for the next row.
AddCaptureButtonRow(pageNum, capY, leftText, leftClick, rightText, rightClick, boxX := "", boxW := "") {
    global contentX, contentW
    if (boxX = "")
        boxX := contentX
    if (boxW = "")
        boxW := contentW
    btnW := (boxW - 5) // 2
    AddCaptureScrollable(AddActionButton(pageNum, "x" boxX               " y" capY " w" btnW " h30", leftText,  leftClick),  capY)
    AddCaptureScrollable(AddActionButton(pageNum, "x" (boxX + btnW + 5)  " y" capY " w" btnW " h30", rightText, rightClick), capY)
    return capY + 34
}

; Pair of region dropdowns (one per capture image) aligned with the button
; row above. Each dropdown is pre-populated from REGION_CHOICES and
; pre-selected to the current saved region for its imagePath. Returns the
; y-coordinate for the next row.
AddCaptureRegionRow(pageNum, capY, leftImagePath, rightImagePath, boxX := "", boxW := "") {
    global mainGui, contentX, contentW, COLOR_BG_INPUT, COLOR_TEXT_WHITE, REGION_CHOICES
    if (boxX = "")
        boxX := contentX
    if (boxW = "")
        boxW := contentW
    ddW := (boxW - 5) // 2
    for idx, imagePath in [leftImagePath, rightImagePath] {
        ddX := boxX + (idx = 1 ? 0 : ddW + 5)
        dd := mainGui.AddDropDownList("x" ddX " y" capY " w" ddW " Background" COLOR_BG_INPUT)
        dd.SetFont("c" COLOR_TEXT_WHITE)
        for _, choice in REGION_CHOICES
            dd.Add([choice[1]])
        currentName := GetSavedImageRegion(imagePath)
        chosen := 1
        for i, choice in REGION_CHOICES {
            if (choice[2] = currentName) {
                chosen := i
                break
            }
        }
        dd.Choose(chosen)
        dd.OnEvent("Change", OnCaptureRegionChange.Bind(imagePath))
        AddCaptureScrollable(AddToPage(pageNum, dd), capY)
    }
    return capY + 26
}
