; ------------------------------------------------------------------------------
; Auto-Update
; Checks GitHub releases API on startup and on demand. Downloads and replaces
; the exe in-place via a temporary batch file, then relaunches.
; ------------------------------------------------------------------------------
CheckForUpdatesOnStartup() {
    global REPO_URL, APP_VERSION, btnUpdate, COLOR_BG_ACTIVE, COLOR_TEXT_WHITE

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://api.github.com/repos/" StrReplace(REPO_URL, "https://github.com/") "/releases/latest", false)
        whr.SetRequestHeader("User-Agent", "SummonHeroesTrainer")
        whr.Send()

        if (whr.Status != 200)
            return

        response := whr.ResponseText

        if !RegExMatch(response, '"tag_name"\s*:\s*"v?([^"]+)"', &mTag)
            return

        latestVersion := mTag[1]

        if (CompareVersions(latestVersion, APP_VERSION) <= 0)
            return

        btnUpdate.Value := "  🔄  Update available!"
        btnUpdate.Opt("Background" COLOR_BG_ACTIVE)
        btnUpdate.SetFont("Norm c" COLOR_TEXT_WHITE)
        btnUpdate.Redraw()
    } catch {
    }
}

CheckForUpdates() {
    global btnUpdate, REPO_URL, APP_VERSION

    btnUpdate.Value := "  🔄  Checking..."
    btnUpdate.Opt("Background" COLOR_BG_PANEL)

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://api.github.com/repos/" StrReplace(REPO_URL, "https://github.com/") "/releases/latest", false)
        whr.SetRequestHeader("User-Agent", "SummonHeroesTrainer")
        whr.Send()

        if (whr.Status != 200) {
            btnUpdate.Value := BTN_UPDATE_TEXT
            btnUpdate.Opt("Background" COLOR_BG_PANEL)
            MsgBox "Could not check for updates (HTTP " whr.Status ")"
            return
        }

        response := whr.ResponseText

        ; Parse version tag
        if !RegExMatch(response, '"tag_name"\s*:\s*"v?([^"]+)"', &mTag) {
            btnUpdate.Value := BTN_UPDATE_TEXT
            btnUpdate.Opt("Background" COLOR_BG_PANEL)
            MsgBox "Could not parse release info."
            return
        }
        latestVersion := mTag[1]

        if (CompareVersions(latestVersion, APP_VERSION) <= 0) {
            btnUpdate.Value := "  🔄  Up to date! (v" APP_VERSION ")"
            btnUpdate.Opt("Background" COLOR_BG_PANEL)
            SetTimer () => (btnUpdate.Value := BTN_UPDATE_TEXT, btnUpdate.Opt("Background" COLOR_BG_PANEL), btnUpdate.Redraw()), -2000
            return
        }

        ; Find exe download URL
        if !RegExMatch(response, '"browser_download_url"\s*:\s*"([^"]*\.exe)"', &mUrl) {
            btnUpdate.Value := BTN_UPDATE_TEXT
            btnUpdate.Opt("Background" COLOR_BG_PANEL)
            MsgBox "New version v" latestVersion " available but no exe found in release assets.`nVisit: " REPO_URL "/releases"
            return
        }
        downloadUrl := mUrl[1]

        ; Download new exe
        btnUpdate.Value := "  🔄  Downloading v" latestVersion "..."
        newExePath := A_Temp "\" A_ScriptName ".new"
        Download downloadUrl, newExePath

        ; Replace current exe and relaunch via batch file
        currentExe := A_ScriptFullPath
        batPath := A_Temp "\update_trainer.bat"
        batchNewExe := StrReplace(newExePath, "%", "%%")
        batchCurrentExe := StrReplace(currentExe, "%", "%%")
        batContent := '@echo off`r`ntimeout /t 1 /nobreak >nul`r`n'
        batContent .= 'set n=0`r`n'
        batContent .= ':retry`r`n'
        batContent .= 'move /y "' batchNewExe '" "' batchCurrentExe '" >nul 2>&1`r`n'
        batContent .= 'if %errorlevel%==0 goto done`r`n'
        batContent .= 'set /a n+=1`r`n'
        batContent .= 'if %n% geq 5 goto fail`r`n'
        batContent .= 'timeout /t 1 /nobreak >nul`r`n'
        batContent .= 'goto retry`r`n'
        batContent .= ':done`r`n'
        batContent .= 'start "" "' batchCurrentExe '"`r`n'
        batContent .= 'del "%~f0"`r`n'
        batContent .= 'exit /b 0`r`n'
        batContent .= ':fail`r`n'
        batContent .= 'msg * "Summon Heroes Trainer: update failed - the new version is at ' batchNewExe '. Please close the trainer and move it manually."`r`n'
        batContent .= 'start "" "' batchCurrentExe '"`r`n'
        batContent .= 'del "%~f0"`r`n'
        FileOpen(batPath, "w").Write(batContent)

        btnUpdate.Value := "  🔄  Restarting..."
        Run batPath, , "Hide"
        ExitApp
    } catch as e {
        btnUpdate.Value := BTN_UPDATE_TEXT
        btnUpdate.Opt("Background" COLOR_BG_PANEL)
        MsgBox "Update error: " e.Message
    }
}
