; ------------------------------------------------------------------------------
; Settings Persistence
; ------------------------------------------------------------------------------
SafeInt(value, default) {
    try
        return Integer(value)
    catch
        return default
}

LoadSettings() {
    global SETTINGS_FILE
    global AUTO_RETRIES_BEFORE_ADVANCE, TELEPORT_INTERVAL_MS, IDLE_THRESHOLD_MS, SPAM_CLICK_INTERVAL_MS
    global teleportEnabled, spamClickEnabled, autoChestEnabled
    global PVP_SHOP_ITEMS, pvpShopAutoBuy, pvpShopOffsetX, pvpShopOffsetY

    if !FileExist(SETTINGS_FILE)
        return

    AUTO_RETRIES_BEFORE_ADVANCE := SafeInt(IniRead(SETTINGS_FILE, "AutoMode", "MaxRetries", AUTO_RETRIES_BEFORE_ADVANCE), AUTO_RETRIES_BEFORE_ADVANCE)
    TELEPORT_INTERVAL_MS := SafeInt(IniRead(SETTINGS_FILE, "AutoMode", "TeleportInterval", TELEPORT_INTERVAL_MS), TELEPORT_INTERVAL_MS)
    IDLE_THRESHOLD_MS := SafeInt(IniRead(SETTINGS_FILE, "AutoMode", "IdleThreshold", IDLE_THRESHOLD_MS), IDLE_THRESHOLD_MS)
    SPAM_CLICK_INTERVAL_MS := SafeInt(IniRead(SETTINGS_FILE, "AutoMode", "SpamClickInterval", SPAM_CLICK_INTERVAL_MS), SPAM_CLICK_INTERVAL_MS)
    teleportEnabled := SafeInt(IniRead(SETTINGS_FILE, "Toggles", "Teleport", teleportEnabled), teleportEnabled)
    spamClickEnabled := SafeInt(IniRead(SETTINGS_FILE, "Toggles", "SpamClick", spamClickEnabled), spamClickEnabled)
    autoChestEnabled := SafeInt(IniRead(SETTINGS_FILE, "AutoChest", "Enabled", autoChestEnabled), autoChestEnabled)

    for _, item in PVP_SHOP_ITEMS {
        pvpShopAutoBuy[item.slug] := SafeInt(IniRead(SETTINGS_FILE, "PvPShop", "AutoBuy_" item.slug, 0), 0)
        pvpShopOffsetX[item.slug] := SafeInt(IniRead(SETTINGS_FILE, "PvPShop", "OffsetX_" item.slug, 0), 0)
        pvpShopOffsetY[item.slug] := SafeInt(IniRead(SETTINGS_FILE, "PvPShop", "OffsetY_" item.slug, 0), 0)
    }
}

SaveSettings() {
    global SETTINGS_FILE
    global AUTO_RETRIES_BEFORE_ADVANCE, TELEPORT_INTERVAL_MS, IDLE_THRESHOLD_MS, SPAM_CLICK_INTERVAL_MS
    global teleportEnabled, spamClickEnabled, autoChestEnabled
    global PVP_SHOP_ITEMS, pvpShopAutoBuy, pvpShopOffsetX, pvpShopOffsetY

    IniWrite AUTO_RETRIES_BEFORE_ADVANCE, SETTINGS_FILE, "AutoMode", "MaxRetries"
    IniWrite TELEPORT_INTERVAL_MS, SETTINGS_FILE, "AutoMode", "TeleportInterval"
    IniWrite IDLE_THRESHOLD_MS, SETTINGS_FILE, "AutoMode", "IdleThreshold"
    IniWrite SPAM_CLICK_INTERVAL_MS, SETTINGS_FILE, "AutoMode", "SpamClickInterval"
    IniWrite teleportEnabled, SETTINGS_FILE, "Toggles", "Teleport"
    IniWrite spamClickEnabled, SETTINGS_FILE, "Toggles", "SpamClick"
    IniWrite autoChestEnabled, SETTINGS_FILE, "AutoChest", "Enabled"

    for _, item in PVP_SHOP_ITEMS {
        IniWrite pvpShopAutoBuy.Get(item.slug, 0), SETTINGS_FILE, "PvPShop", "AutoBuy_" item.slug
        IniWrite pvpShopOffsetX.Get(item.slug, 0), SETTINGS_FILE, "PvPShop", "OffsetX_" item.slug
        IniWrite pvpShopOffsetY.Get(item.slug, 0), SETTINGS_FILE, "PvPShop", "OffsetY_" item.slug
    }
}
