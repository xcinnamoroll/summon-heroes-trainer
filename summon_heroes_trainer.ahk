#Requires AutoHotkey v2.0

; ------------------------------------------------------------------------------
; AppData Setup
; ------------------------------------------------------------------------------
global APP_DATA_DIR := A_AppData "\SummonHeroesTrainer"
global APP_BUTTONS_DIR := APP_DATA_DIR "\buttons"
global APP_PVP_SHOP_DIR := APP_DATA_DIR "\pvp_shop"
DirCreate APP_DATA_DIR
DirCreate APP_BUTTONS_DIR
DirCreate APP_PVP_SHOP_DIR

FileInstall "icon.ico", APP_DATA_DIR "\icon.ico", 1
FileInstall "background.png", APP_DATA_DIR "\background.png", 1
FileInstall "pvp_shop_icons\trait_reroll.png",          APP_PVP_SHOP_DIR "\trait_reroll.png", 1
FileInstall "pvp_shop_icons\summon_ticket.png",         APP_PVP_SHOP_DIR "\summon_ticket.png", 1
FileInstall "pvp_shop_icons\fusion_crystal_orange.png", APP_PVP_SHOP_DIR "\fusion_crystal_orange.png", 1
FileInstall "pvp_shop_icons\fusion_crystal_purple.png", APP_PVP_SHOP_DIR "\fusion_crystal_purple.png", 1
FileInstall "pvp_shop_icons\fusion_crystal_blue.png",   APP_PVP_SHOP_DIR "\fusion_crystal_blue.png", 1
FileInstall "pvp_shop_icons\food.png",                  APP_PVP_SHOP_DIR "\food.png", 1

TraySetIcon APP_DATA_DIR "\icon.ico"

; ------------------------------------------------------------------------------
; Includes (order matters: config → helpers → settings → gui → features)
; ------------------------------------------------------------------------------
#Include lib/config.ahk
#Include lib/helpers.ahk
#Include lib/gui_components.ahk
#Include lib/scan_master.ahk
#Include lib/settings.ahk

LoadSettings()

#Include lib/custom_pathing.ahk
#Include lib/auto_chest.ahk
#Include lib/pvp_shop.ahk
#Include lib/gui.ahk
#Include lib/story_mode.ahk
#Include lib/image_capture.ahk
#Include lib/updater.ahk

; ------------------------------------------------------------------------------
; Startup
; ------------------------------------------------------------------------------
g_gdip := GdipInit()

mainGui.Show("w" GUI_WIDTH " h" GUI_HEIGHT)
RefreshPathLists()
UpdateChestStatusIdle()

; If we exit (user close, script reload, crash handled by AHK), release any
; path keys that might still be held down so the user isn't left with a
; stuck W/A/S/D/E/Space in the game, and clean up temp trigger files.
OnExit((*) => (ReleaseAllPathKeys(), StopRecordingPath(), ClearPathTempFiles()))

; ------------------------------------------------------------------------------
; Hotkeys
; ------------------------------------------------------------------------------
IsNumberEditFocused() {
    global edtMaxRetries, edtCurrentRetry, edtTeleport, edtIdle, edtSpamClick
    focusedHwnd := DllCall("GetFocus", "Ptr")
    for ctrl in [edtMaxRetries, edtCurrentRetry, edtTeleport, edtIdle, edtSpamClick] {
        if (focusedHwnd = ctrl.Hwnd)
            return true
    }
    return false
}

#HotIf WinActive("ahk_id " mainGui.Hwnd) && IsNumberEditFocused()
Enter:: {
    global mainGui
    DllCall("SetFocus", "Ptr", mainGui.Hwnd)
}
#HotIf

Insert:: {
    global mainGui
    if WinActive("ahk_id " mainGui.Hwnd)
        mainGui.Minimize()
    else
        mainGui.Show()
}

SetTimer CheckMouseIdle, IDLE_CHECK_INTERVAL_MS
SetTimer UpdateActiveWindow, 500
SetTimer ScanMasterTick, SCAN_MASTER_INTERVAL_MS
SetTimer CheckForUpdatesOnStartup, -1000
SetTimer WarnIfAntiCheatRunning, -500
