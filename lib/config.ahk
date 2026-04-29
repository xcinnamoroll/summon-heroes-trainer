; ------------------------------------------------------------------------------
; Screen / Mouse Settings
; ------------------------------------------------------------------------------
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

; ------------------------------------------------------------------------------
; Configuration
; ------------------------------------------------------------------------------
global ROBLOX_EXE := "ahk_exe RobloxPlayerBeta.exe"
global REPO_URL := "https://github.com/xcinnamoroll/summon-heroes-trainer"
global APP_VERSION := "1.0.100"
global BTN_UPDATE_TEXT := "  🔄  Check for updates"

global SETTINGS_FILE := APP_DATA_DIR "\settings.ini"

global IDLE_THRESHOLD_MS := 1000
global IDLE_CHECK_INTERVAL_MS := 100
global SPAM_CLICK_INTERVAL_MS := 200

global RETRY_IMAGE := APP_BUTTONS_DIR "\retry_stage.png"
global RETRY_SEARCH_INTERVAL_MS := 500
global RETRY_CLICK_COOLDOWN_MS := 1500
global RETRY_IMAGE_VARIATION := 40

; ------------------------------------------------------------------------------
; Next Stage Button
; ------------------------------------------------------------------------------
global NEXT_STAGE_IMAGE := APP_BUTTONS_DIR "\next_stage.png"
global NEXT_STAGE_IMAGE_VARIATION := 40

global NEXT_MAP_IMAGE := APP_BUTTONS_DIR "\next_map.png"
global NEXT_MAP_IMAGE_VARIATION := 40

; Auto-cycle settings
global AUTO_RETRIES_BEFORE_ADVANCE := 9
global AUTO_ADVANCE_GRACE_MS := 3000

; Human-like bezier slide settings
global BEZIER_MIN_STEPS := 10
global BEZIER_PX_PER_STEP := 20
global BEZIER_MAX_STEPS := 40
global BEZIER_STEP_DELAY_MS := 2
global BEZIER_CURVE_STRENGTH := 0.04

; ------------------------------------------------------------------------------
; Teleport Button (Periodic Click)
; ------------------------------------------------------------------------------
global TELEPORT_IMAGE := APP_BUTTONS_DIR "\teleport_button.png"
global TELEPORT_INTERVAL_MS := 5000
global TELEPORT_IMAGE_VARIATION := 40
global TELEPORT_HOLD_MS := 150

; ------------------------------------------------------------------------------
; UI Colors
; ------------------------------------------------------------------------------
global COLOR_BG_MAIN   := "21193F"   ; Main window / status box background
global COLOR_BG_PANEL  := "2C1F4F"   ; Sidebar + content panel background
global COLOR_BG_ACTIVE := "5D2298"   ; Active tab / mode button
global COLOR_BG_BTN    := "3D2560"   ; Inactive action button (Auto, Retry, capture)
global COLOR_BG_INPUT  := "333333"   ; Edit field / dropdown background
global COLOR_DIVIDER   := "4A3880"   ; Horizontal rule
global COLOR_TAB_TEXT  := "C0B0E8"   ; Inactive sidebar tab text
global COLOR_BTN_STOP  := "AA2233"   ; Stop button background

; Text colors
global COLOR_TEXT_PRIMARY := "CCB8FF" ; Subtitle / body / section headers / default shadow-text color
global COLOR_TEXT_WHITE   := "FFFFFF" ; Plain white (version label, mode button text)

; Status-line colors (used by txtStatus / txtLastAction / txtActiveWindow etc.)
global COLOR_STATE_WARNING := "FFAA00" ; Orange — recording / armed / idle
global COLOR_STATE_SUCCESS := "66FF66" ; Green — running / saved / Roblox active
global COLOR_STATE_ERROR   := "FF6B6B" ; Red — OFF / missing image / save failed
global COLOR_STATE_INFO    := "66DDFF" ; Blue — neutral info (retries, phase, last action)

; Title bar (DwmSetWindowAttribute expects COLORREF = 0x00BBGGRR)
global COLOR_TITLEBAR_BG   := 0x672631
global COLOR_TITLEBAR_TEXT := 0xFFB8CC

; ------------------------------------------------------------------------------
; Auto Chest
; ------------------------------------------------------------------------------
global AUTO_CHEST_DIR := APP_DATA_DIR "\auto_chest"
global AUTO_CHEST_MAPS := [
    "Rookie Island",
    "Volcano Fortress",
    "Frozen Glacier",
    "Calamity Canyon",
    "Sakura Village",
    "Everest Academy",
    "Leviathan's Eye",
    "Sunset City",
    "Aetherwell Citadel"
]
global CHEST_SCAN_INTERVAL_MS := 500

; Auto Chest state
global autoChestEnabled   := false
global g_chestFoundState  := Map()   ; per-map edge state for loading-image detection
global g_chestActiveMap   := ""      ; last map whose loading image was detected
global g_chestArmedPath   := ""      ; name of the custom path Auto Chest armed

; ------------------------------------------------------------------------------
; Custom Pathing
; ------------------------------------------------------------------------------
global PATHS_DIR := APP_DATA_DIR "\paths"
global PATH_KEYS := ["w", "a", "s", "d", "e", "space", "Up", "Down", "Left", "Right"]
global PATH_TRIGGER_INTERVAL_MS := 500
global PATH_TRIGGER_VARIATION := 60

; Default search region per image path (used by SearchCapture / FindPathTrigger
; when neither the caller nor a per-image sidecar overrides it). Story mode
; buttons all live in the lower portion of the Roblox window.
global NEEDLE_REGIONS := Map(
    RETRY_IMAGE,      "bottom-half",
    NEXT_STAGE_IMAGE, "bottom-half",
    NEXT_MAP_IMAGE,   "bottom-half",
    TELEPORT_IMAGE,   "bottom-half"
)

; ------------------------------------------------------------------------------
; State
; ------------------------------------------------------------------------------
global idleTimeMs := 0
global lastMouseX := 0
global lastMouseY := 0
global isSpamClicking := false
global isClickingButton := false
global isAutomationEnabled := false
global automationMode := ""
global autoRetryCount := 0
global autoPhase := "retry"
global autoAdvanceStartTick := 0
global STATUS_UPDATE_MS := 500
global teleportEnabled := true
global spamClickEnabled := true
global lastAction := "Waiting"
global missingImageWarned := Map()
global g_gdip := 0
global g_needleCache := Map()
; Last known x/y where each needle was found (keyed by imagePath). Used to
; shrink the search window on the next scan — we do a tiered expanding
; search around the cached location before falling back to full-haystack.
global g_needleLastFound := Map()
; Tier 1 — half-width of the "tight" box around last-known position.
; Small fixed value: stationary UI elements are found here in microseconds.
global SEARCH_CACHE_TIGHT_PX := 20
; Tier 2 — multiplier applied to max(needleW, needleH) for the "relaxed"
; box. Scales with needle size so larger needles get proportionally larger
; search windows. Minimum floor below.
global SEARCH_CACHE_RELAXED_MULT := 1.0
global SEARCH_CACHE_RELAXED_MIN_PX := 100

; Named options shown in region dropdowns (user-facing labels -> region name).
; Keep these in display order.
global REGION_CHOICES := [
    ["Whole window",      "whole"],
    ["Top half",          "top-half"],
    ["Bottom half",       "bottom-half"],
    ["Left half",         "left-half"],
    ["Right half",        "right-half"],
    ["Top-left quad",     "top-left"],
    ["Top-right quad",    "top-right"],
    ["Bottom-left quad",  "bottom-left"],
    ["Bottom-right quad", "bottom-right"]
]
global g_lastColor := Map()

; ------------------------------------------------------------------------------
; PvP Shop
; Each item is { name, slug, color, icon } — icon is the filename under
; PVP_SHOP_ICONS_DIR. Order defines the 3-row x 2-col card grid: entries
; 1/2 fill row 1, 3/4 fill row 2, 5/6 fill row 3.
; ------------------------------------------------------------------------------
global PVP_SHOP_ICONS_DIR := APP_DATA_DIR "\pvp_shop"
global PVP_SHOP_DETECT_DIR := APP_DATA_DIR "\pvp_shop_detect"
global PVP_SHOP_SCAN_INTERVAL_MS := 400
global PVP_SHOP_IMAGE_VARIATION := 40
global PVP_SHOP_ITEMS := [
    { name: "Trait Reroll",    slug: "trait_reroll",          color: "FF66CC", icon: "trait_reroll.png" },
    { name: "Summon Ticket",   slug: "summon_ticket",         color: "FFCC33", icon: "summon_ticket.png" },
    { name: "Fusion Crystal",  slug: "fusion_crystal_orange", color: "FFAA33", icon: "fusion_crystal_orange.png" },
    { name: "Fusion Crystal",  slug: "fusion_crystal_purple", color: "CC66FF", icon: "fusion_crystal_purple.png" },
    { name: "Fusion Crystal",  slug: "fusion_crystal_blue",   color: "66DDFF", icon: "fusion_crystal_blue.png" },
    { name: "Food",            slug: "food",                  color: "66DDFF", icon: "food.png", disabled: true }
]

; Per-item auto-buy toggles (slug -> bool). Populated from settings.ini on load.
global pvpShopAutoBuy := Map()
; Per-item click-point offset from the detected image's match center
; (slug -> int). Populated from settings.ini on load.
global pvpShopOffsetX := Map()
global pvpShopOffsetY := Map()

; Custom Pathing state
global pathActive := false
global isRecordingPath := false
global pathRecordStartTick := 0
global pathRecordEvents := []
global pathRecordingStopRequested := false
global g_pathHeldKeys := Map()
; Tracks which PATH_KEYS are currently held during recording, so OS
; auto-repeat presses don't spam duplicate "down" events into the path.
global g_pathRecordingHeld := Map()
; Each entry: { path: <path obj>, tempPath: "<.tmp\armed_X.png>", lastFound: <bool> }
; Multiple paths can be armed at once; only one plays at a time.
global g_armedPaths := []
global g_armedScanCount := 0
; State for async playback (set by PlayPath, advanced by FirePathEvent).
global g_pathPlayback := { stopped: true, idx: 0, total: 0, startTick: 0, path: 0 }
; Trigger prepared for the next new-path recording — either an image
; (imageData base64 populated) or a timer (intervalMs > 0), but not both.
; g_newPathTriggerType: "none" | "image" | "timer"
global g_newPathTriggerType       := "none"
global g_newPathTriggerBase64     := ""
global g_newPathTriggerIntervalMs := 0
global g_newPathTriggerDesc       := "(none)"
global g_newPathTriggerRegion     := "whole"
