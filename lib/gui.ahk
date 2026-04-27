; ------------------------------------------------------------------------------
; GUI
; ------------------------------------------------------------------------------
global mainGui := Gui("+AlwaysOnTop -MaximizeBox", "Summon Heroes Trainer")
mainGui.SetFont("s9", "Segoe UI")
mainGui.MarginX := 10
mainGui.MarginY := 8
mainGui.BackColor := COLOR_BG_MAIN

; --- Title Bar Color ---
DwmSetWindowColor(mainGui.Hwnd, COLOR_TITLEBAR_BG, COLOR_TITLEBAR_TEXT)

; --- Title Banner ---
global BACKGROUND_IMAGE := APP_DATA_DIR "\background.png"
bannerBottom := 175
if FileExist(BACKGROUND_IMAGE) {
    bannerPic := mainGui.AddPicture("x0 y0 w838 h-1", BACKGROUND_IMAGE)
    bannerPic.GetPos(,, , &bh)
    bannerBottom := bh + 5
}

; --- Banner Divider ---
mainGui.AddText("x0 y" (bannerBottom - 8) " w838 h2 Background" COLOR_BG_MAIN, "")

; --- Version Label ---
mainGui.SetFont("Norm s8 c" COLOR_TEXT_WHITE, "Segoe UI")
mainGui.AddText("x4 y4 BackgroundTrans", "v" APP_VERSION)

; --- Active Window ---
mainGui.SetFont("Norm s8 c" COLOR_TEXT_WHITE, "Segoe UI")
global txtActiveWindow := mainGui.AddText("x10 y4 w816 Right BackgroundTrans", "")

; --- Sidebar Tab Buttons ---
global g_activePage := 1
global g_pageBtns := []
global g_pageControls := Map(1, [], 2, [], 3, [], 4, [], 5, [], 6, [], 7, [])
global g_sideTabLabels := ["📖  Story Mode", "📦  Auto Chest", "🗺  Custom Pathing", "🔮  Summon Shop", "🛒  Item Shop", "⚔  PvP Shop", "📷  Image Capture"]

mainGui.SetFont("s9 c" COLOR_TAB_TEXT, "Segoe UI")
for i, lbl in g_sideTabLabels {
    b := mainGui.AddText("x8 " (i=1 ? "y" (bannerBottom + 8) : "y+3") " w136 h46 +0x200 Background" COLOR_BG_PANEL, "  " lbl)
    b.OnEvent("Click", SwitchPage.Bind(i))
    g_pageBtns.Push(b)
}
global btnUpdate := mainGui.AddText("x8 y+3 w136 h46 +0x200 Background" COLOR_BG_PANEL, BTN_UPDATE_TEXT)
btnUpdate.SetFont("c" COLOR_TAB_TEXT)
btnUpdate.OnEvent("Click", (*) => CheckForUpdates())

global contentX := 170
global contentW := 290
global contentY := bannerBottom + 22

; Right-side content panel (status / overview).
; Width is sized so the widest Status value ("Spam stopped: Roblox inactive",
; 29 chars at s10 Segoe UI) plus its "Last action:" label fits on one line.
global rightContentX := 495
global rightContentW := 320

; Full-width content for pages whose bg panel spans the whole area (no right panel)
global wideContentW := 645

; --- Content Background Boxes ---
; Pages with a right-side status panel get a narrow main panel + right panel.
; Other pages get a single wide main panel that spans the full content area.
; Heights are trimmed to fit content at the end of this file (except page 7).
global PAGES_WITH_RIGHT_PANEL := [1, 3]
global g_pageBgPanels := Map()
for _, p in PAGES_WITH_RIGHT_PANEL {
    g_pageBgPanels[p] := [
        AddToPage(p, mainGui.AddText("x155 y" (bannerBottom + 8) " w317 h520 Background" COLOR_BG_PANEL, "")),
        AddToPage(p, mainGui.AddText("x480 y" (bannerBottom + 8) " w350 h520 Background" COLOR_BG_PANEL, ""))
    ]
}
for _, p in [2, 4, 5, 6, 7] {
    g_pageBgPanels[p] := [
        AddToPage(p, mainGui.AddText("x155 y" (bannerBottom + 8) " w675 h520 Background" COLOR_BG_PANEL, ""))
    ]
}

; ==============================================================================
; Story Mode Page
; ==============================================================================
AddPageTitle(1, "Story Mode")
AddPageSubtitle(1, "Automation settings and controls")
AddSectionDivider(1)

; --- Toggles ---
global chkTeleport     := AddCheckboxRow(1, "x" contentX " y+14 w15 h15 Section",  "Teleport to Units", "x+4 ys w120 h20", teleportEnabled,  (*) => (OnToggleTeleport(),  RefocusRoblox()))
global chkSpamClick    := AddCheckboxRow(1, "x+10 ys w15 h15",                     "Spam Click",        "x+4 ys w80 h20",  spamClickEnabled, (*) => (OnToggleSpamClick(), RefocusRoblox()))
global chkChestEnabled := AddCheckboxRow(1, "x" contentX " y+8 w15 h15 Section",   "Auto Chest",        "x+4 ys w120 h20", autoChestEnabled, (*) => OnToggleAutoChest())

; --- Mode Controls ---
global btnAuto  := AddActionButton(1, "x" contentX " y+12 w90 h30 Section", "Auto",  (*) => (ToggleAutomation("auto"),  RefocusRoblox()))
global btnRetry := AddActionButton(1, "x+5 w90 h30",                         "Retry", (*) => (ToggleAutomation("retry"), RefocusRoblox()))
global btnStop  := AddActionButton(1, "x+5 w90 h30",                         "STOP",  (*) => (StopAllAutomation(),       RefocusRoblox()), "stop")
AddSectionDivider(1, "y+10")

; --- Auto Mode Settings ---
AddSectionHeader(1, "Auto Mode Settings")

AddFieldLabel(1, "Max retries:", "y+4")
global edtMaxRetries := AddNumberEditField(1, "x+5 w55", AUTO_RETRIES_BEFORE_ADVANCE)
global udMaxRetries  := AddToPage(1, mainGui.AddUpDown("Range0-999", AUTO_RETRIES_BEFORE_ADVANCE))

AddFieldLabel(1, "Current retry:")
global edtCurrentRetry := AddNumberEditField(1, "x+5 w55", autoRetryCount)
global udCurrentRetry  := AddToPage(1, mainGui.AddUpDown("Range0-999", autoRetryCount))

AddFieldLabel(1, "Teleport interval (ms):")
global edtTeleport := AddNumberEditField(1, "x+5 w55", TELEPORT_INTERVAL_MS)

AddFieldLabel(1, "Idle threshold (ms):")
global edtIdle := AddNumberEditField(1, "x+5 w55", IDLE_THRESHOLD_MS)

AddFieldLabel(1, "Spam click (ms):")
global edtSpamClick := AddNumberEditField(1, "x+5 w55", SPAM_CLICK_INTERVAL_MS)

edtMaxRetries.OnEvent("Change", ApplySettings)
edtCurrentRetry.OnEvent("Change", ApplySettings)
edtTeleport.OnEvent("Change", ApplySettings)
edtIdle.OnEvent("Change", ApplySettings)
edtSpamClick.OnEvent("Change", ApplySettings)

; --- Status (Right Panel) ---
statusLabel := AddSectionHeader(1, "Status", "y" contentY, rightContentX, rightContentW)
AddSectionDivider(1, "y+4", rightContentX, rightContentW)
statusLabel.GetPos(, &sby, , &sbh)
statusBoxY := sby + sbh + 12
AddToPage(1, mainGui.AddText("x" rightContentX " y" statusBoxY " w" rightContentW " h112 Background" COLOR_BG_MAIN, ""))
global txtStatus     := AddStatusRow(1, statusBoxY +  8, "Mode:",        38, "OFF",                            "c" COLOR_STATE_ERROR, rightContentX, rightContentW)
global txtRetries    := AddStatusRow(1, statusBoxY + 32, "Retries:",     48, "0/" AUTO_RETRIES_BEFORE_ADVANCE, "c" COLOR_STATE_INFO,  rightContentX, rightContentW)
global txtPhase      := AddStatusRow(1, statusBoxY + 56, "Phase:",       40, "-",                              "c" COLOR_STATE_INFO,  rightContentX, rightContentW)
global txtLastAction := AddStatusRow(1, statusBoxY + 80, "Last action:", 72, "Waiting",                        "c" COLOR_STATE_INFO,  rightContentX, rightContentW)

; --- Auto Chest Status (below Story Mode Status) ---
chestHdr := AddSectionHeader(1, "Auto Chest", "y" (statusBoxY + 112 + 12), rightContentX, rightContentW)
AddSectionDivider(1, "y+4", rightContentX, rightContentW)
chestHdr.GetPos(, &chy, , &chh)
chestStatusBoxY := chy + chh + 12
AddToPage(1, mainGui.AddText("x" rightContentX " y" chestStatusBoxY " w" rightContentW " h112 Background" COLOR_BG_MAIN, ""))
global txtChestState      := AddStatusRow(1, chestStatusBoxY +  8, "State:",       40, "Disabled", "c" COLOR_STATE_ERROR, rightContentX, rightContentW)
global txtChestMap        := AddStatusRow(1, chestStatusBoxY + 32, "Map:",         32, "-",        "c" COLOR_STATE_INFO,  rightContentX, rightContentW)
global txtChestPath       := AddStatusRow(1, chestStatusBoxY + 56, "Path:",        32, "-",        "c" COLOR_STATE_INFO,  rightContentX, rightContentW)
global txtChestLastAction := AddStatusRow(1, chestStatusBoxY + 80, "Last action:", 72, "Waiting",  "c" COLOR_STATE_INFO,  rightContentX, rightContentW)

; ==============================================================================
; Auto Chest Page
; ==============================================================================
; Single wide panel — status lives under Story Mode's status on page 1 now,
; since Auto Chest only scans while Story Mode auto/retry is active.
AddPageTitle(2, "Auto Chest", , wideContentW)
AddPageSubtitle(2, "Per-map image and path selection", , wideContentW)
AddSectionDivider(2, , , wideContentW)

g_chestContentAreaTop := contentY + 60
chestY := g_chestContentAreaTop
for _, chestMapName in AUTO_CHEST_MAPS
    chestY := AddChestMapSection(2, chestY, chestMapName)

; ==============================================================================
; Custom Pathing Page
; ==============================================================================
AddPageTitle(3, "Custom Pathing")
AddPageSubtitle(3, "Record key macros triggered by images")
AddSectionDivider(3)

; --- Record section ---
AddSectionHeader(3, "Record New Path", "y+10")

AddFieldLabel(3, "Name:", "y+4")
global edtPathName := AddEditField(3, "x" contentX " y+2 w" contentW)

; Trigger row: "Trigger:" label on the left, "Or every __ s" timer shortcut on the right
mainGui.SetFont("Norm s9 c" COLOR_TEXT_PRIMARY, "Segoe UI")
AddToPage(3, AddShadowText(mainGui, "x" contentX " y+6 w60 h18 Section", "Trigger:"))
AddToPage(3, AddShadowText(mainGui, "x+10 ys w85 h18", "Or every (s):"))
global edtNewPathInterval := AddNumberEditField(3, "x+5 ys w50", 0)
edtNewPathInterval.OnEvent("Change", OnNewPathIntervalChange)

global txtPathTriggerStatus := AddToPage(3, AddShadowText(mainGui, "x" contentX " y+2 w" contentW " h18", "(none)", "c" COLOR_TEXT_PRIMARY))
global btnPathCaptureTrigger := AddActionButton(3, "x" contentX " y+4 w" ((contentW - 5) // 2) " h24 Section", "Capture", (*) => OnPathCaptureNewTriggerClick())
global btnPathUploadTrigger  := AddActionButton(3, "x+5 w" ((contentW - 5) // 2) " h24",                        "Upload",  (*) => OnPathUploadNewTriggerClick())

mainGui.SetFont("Norm s9 c" COLOR_TEXT_PRIMARY, "Segoe UI")
AddToPage(3, AddShadowText(mainGui, "x" contentX " y+6 w90 h20 Section", "Search region:"))
global ddNewPathRegion := AddDropDownField(3, "x+5 ys w" (contentW - 95))
for _, choice in REGION_CHOICES
    ddNewPathRegion.Add([choice[1]])
ddNewPathRegion.Choose(1)
ddNewPathRegion.OnEvent("Change", OnNewPathRegionChange)

global btnPathRecord := AddActionButton(3, "x" contentX " y+8 w" contentW " h30", "Record (F8 to stop)", (*) => (OnPathRecordClick(), RefocusRoblox()))

AddSectionDivider(3, "y+10")

; --- Play / Arm section ---
AddSectionHeader(3, "Saved Paths", "y+10")

global ddPaths := AddDropDownField(3, "x" contentX " y+4 w" contentW)

global btnPathPlay := AddActionButton(3, "x" contentX " y+8 w93 h30 Section", "Play",  (*) => (OnPathPlayClick(), RefocusRoblox()))
global btnPathArm  := AddActionButton(3, "x+5 w93 h30",                        "Arm",   (*) => (OnPathArmClick(),  RefocusRoblox()))
global btnPathStop := AddActionButton(3, "x+5 w94 h30",                        "STOP",  (*) => OnPathStopClick(), "stop")

global btnPathTestTrigger := AddActionButton(3, "x" contentX " y+6 w" contentW " h24", "Test Trigger", (*) => OnPathTestTriggerClick())
global btnPathSetRegion   := AddActionButton(3, "x" contentX " y+6 w" contentW " h24", "Set Region",   (*) => OnPathSetRegionClick())

global btnPathRecapture       := AddActionButton(3, "x" contentX " y+6 w93 h24 Section", "Recapture", (*) => OnPathRecaptureClick())
global btnPathUploadForSaved  := AddActionButton(3, "x+5 w93 h24",                        "Upload",    (*) => OnPathUploadExistingTriggerClick())
global btnPathSetTimer        := AddActionButton(3, "x+5 w94 h24",                        "Set Timer", (*) => OnPathSetTimerClick())

global btnPathRename := AddActionButton(3, "x" contentX " y+6 w93 h24 Section", "Rename",       (*) => OnPathRenameClick())
global btnPathImport := AddActionButton(3, "x+5 w93 h24",                        "Import",       (*) => OnPathImportClick())
global btnPathExport := AddActionButton(3, "x+5 w94 h24",                        "Export",       (*) => OnPathExportClick())

global btnPathDelete  := AddActionButton(3, "x" contentX         " y+6 w142 h24 Section", "Delete",       (*) => OnPathDeleteClick())
global btnPathRefresh := AddActionButton(3, "x" (contentX + 147) " yp  w143 h24",          "Refresh list", (*) => RefreshPathLists())
btnPathDelete.Move(contentX,       , 142, 24)
btnPathRefresh.Move(contentX + 147, , 143, 24)

; --- Status (Right Panel) ---
pathStatusLabel := AddSectionHeader(3, "Status", "y" contentY, rightContentX, rightContentW)
AddSectionDivider(3, "y+4", rightContentX, rightContentW)
pathStatusLabel.GetPos(, &psy, , &psh)
pathStatusBoxY := psy + psh + 12
AddToPage(3, mainGui.AddText("x" rightContentX " y" pathStatusBoxY " w" rightContentW " h136 Background" COLOR_BG_MAIN, ""))
global txtPathState      := AddStatusRow(3, pathStatusBoxY +   8, "State:",       40, "Idle",    "c" COLOR_STATE_INFO, rightContentX, rightContentW)
global txtPathActive     := AddStatusRow(3, pathStatusBoxY +  32, "Active:",      42, "-",       "c" COLOR_STATE_INFO, rightContentX, rightContentW)
global txtPathStep       := AddStatusRow(3, pathStatusBoxY +  56, "Step:",        32, "-",       "c" COLOR_STATE_INFO, rightContentX, rightContentW)
global txtPathArmed      := AddStatusRow(3, pathStatusBoxY +  80, "Armed:",       42, "-",       "c" COLOR_STATE_INFO, rightContentX, rightContentW)
global txtPathLastAction := AddStatusRow(3, pathStatusBoxY + 104, "Last action:", 72, "Waiting", "c" COLOR_STATE_INFO, rightContentX, rightContentW)

; ==============================================================================
; Summon Shop Page
; ==============================================================================
AddPageTitle(4, "Summon Shop")
AddPageSubtitle(4, "Coming soon")

; ==============================================================================
; Item Shop Page
; ==============================================================================
AddPageTitle(5, "Item Shop")
AddPageSubtitle(5, "Coming soon")

; ==============================================================================
; PvP Shop Page
; ==============================================================================
AddPageTitle(6, "PvP Shop", , wideContentW)
AddPageSubtitle(6, "Toggle which items to auto-buy when they appear", , wideContentW)
AddSectionDivider(6, , , wideContentW)

; 3 rows x 2 columns of item cards
pvpGridTop  := contentY + 60
pvpColGap   := 12
pvpRowGap   := 12
pvpCardW    := (wideContentW - pvpColGap) // 2
pvpCardH    := 160
for idx, pvpItem in PVP_SHOP_ITEMS {
    col := Mod(idx - 1, 2)
    row := (idx - 1) // 2
    pvpCardX := contentX + col * (pvpCardW + pvpColGap)
    pvpCardY := pvpGridTop + row * (pvpCardH + pvpRowGap)
    AddPvPShopItemCard(6, pvpCardX, pvpCardY, pvpCardW, pvpCardH, pvpItem)
}

; ==============================================================================
; Image Capture Page
; ==============================================================================
; "Open Buttons Folder" button sits to the right of the title/subtitle. The
; divider is added before the button so its y+8 positions relative to the
; subtitle (h=16) instead of the taller button (h=30).
capOpenBtnW := 150
capTitleW   := wideContentW - capOpenBtnW - 10
AddPageTitle(7, "Image Capture", , capTitleW)
AddPageSubtitle(7, "Capture button images for detection", , capTitleW)
AddSectionDivider(7, , , wideContentW)
global btnOpenButtonsFolder := AddActionButton(7, "x" (contentX + capTitleW + 10) " y" contentY " w" capOpenBtnW " h30", "Open Buttons Folder", (*) => OpenButtonsFolder())

global g_captureScrollable    := []
global g_capScrollOffset      := 0
global g_capContentAreaTop    := contentY + 60
global g_capContentAreaBottom := 0   ; set after panel sizing below

capY := AddCaptureCategory(7, g_capContentAreaTop, "Story Mode", "mouse will click center of image", , wideContentW)
capY := AddCaptureButtonRow(7, capY, "Retry Stage",   (*) => CaptureButtonImage(RETRY_IMAGE, "Retry Stage"),
                                     "Next Stage",    (*) => CaptureButtonImage(NEXT_STAGE_IMAGE, "Next Stage"), , wideContentW)
capY := AddCaptureRegionRow(7, capY, RETRY_IMAGE, NEXT_STAGE_IMAGE, , wideContentW)
capY := AddCaptureButtonRow(7, capY, "Play Next Map", (*) => CaptureButtonImage(NEXT_MAP_IMAGE, "Play Next Map"),
                                     "Teleport",      (*) => CaptureButtonImage(TELEPORT_IMAGE, "Teleport"), , wideContentW)
capY := AddCaptureRegionRow(7, capY, NEXT_MAP_IMAGE, TELEPORT_IMAGE, , wideContentW)

OnMessage(0x020A, WM_MOUSEWHEEL_Capture)

; ==============================================================================
; Finalize
; ==============================================================================

; Shrink each page's background panel(s) to fit the tallest control within
; that panel's own x-range. Main and right panels size independently.
; Pages 2 (Auto Chest) and 7 (Image Capture) are sized to match the tallest
; of the other pages rather than fit-to-content, since their content scrolls.
panelTop := bannerBottom + 8
tallestFittedH := 0
for pageNum, bgPanels in g_pageBgPanels {
    if (pageNum = 2 || pageNum = 7)
        continue
    bgHwnds := Map()
    for bg in bgPanels
        bgHwnds[bg.Hwnd] := true
    for bg in bgPanels {
        bg.GetPos(&bx, , &bw)
        bgRight := bx + bw
        maxBottom := panelTop
        for ctrl in g_pageControls[pageNum] {
            if bgHwnds.Has(ctrl.Hwnd)
                continue
            ctrl.GetPos(&cx, &cy, , &ch)
            if (cx >= bx && cx < bgRight && cy + ch > maxBottom)
                maxBottom := cy + ch
        }
        fittedH := (maxBottom - panelTop) + 12
        bg.Move(, , , fittedH)
        if (fittedH > tallestFittedH)
            tallestFittedH := fittedH
    }
}
for _, p in [2, 7]
    for bg in g_pageBgPanels[p]
        bg.Move(, , , tallestFittedH)

; Scrollable content areas extend to the bg panel's bottom edge. Items whose
; newY + height exceed this are hidden so they don't spill past the panel.
panelBottom := panelTop + tallestFittedH
g_capContentAreaBottom   := panelBottom
g_chestContentAreaBottom := panelBottom

global GUI_WIDTH := 838
global GUI_HEIGHT := panelTop + tallestFittedH + 24

SwitchPage(1)
mainGui.MarginY := 24
mainGui.OnEvent("Close", (*) => (GdipShutdown(g_gdip), ExitApp()))
