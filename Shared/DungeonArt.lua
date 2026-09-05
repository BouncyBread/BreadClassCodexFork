local _, ns = ...

ns.DUNGEON_BG = {
    [161] = 1041999,
    [239] = 1718213,
    [402] = 4742929,
    [556] = 608210,
    [557] = 7464937,
    [558] = 7467174,
    [559] = 7570501,
    [560] = 7478529,
}

local function hslToRgb(h, s, l)
    local function hue(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    if s == 0 then return l, l, l end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return hue(p, q, h + 1 / 3), hue(p, q, h), hue(p, q, h - 1 / 3)
end

function ns.TintFromKey(key)
    if not key or key == "" then return nil end
    local sum = 0
    for i = 1, #key do
        sum = sum + key:byte(i) * i
    end
    return hslToRgb((sum % 360) / 360, 0.55, 0.52)
end

local RAID_GROUP_HUE = { main = 120, overview = 180, other = 240 }

function ns.GetRaidGroupTint(kind)
    local h = kind and RAID_GROUP_HUE[kind]
    if not h then return nil end
    return hslToRgb(h / 360, 0.55, 0.52)
end

local currentRaidName
function ns.GetCurrentRaidName()
    if currentRaidName ~= nil then return currentRaidName or nil end
    currentRaidName = false
    if EJ_SelectTier and EJ_GetNumTiers and EJ_GetInstanceByIndex then
        pcall(function()
            EJ_SelectTier(EJ_GetNumTiers())
            local id, name = EJ_GetInstanceByIndex(1, true)
            if id and name then currentRaidName = name end
        end)
    end
    return currentRaidName or nil
end

local function norm(s)
    return s and s:lower():gsub("[^%w]", "") or nil
end

local dungeonByName
local function EnsureDungeonMap()
    if dungeonByName then return end
    if not (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then return end
    local ids = {}
    if C_ChallengeMode.GetMapTable then
        local t = C_ChallengeMode.GetMapTable()
        if type(t) == "table" then
            for _, id in ipairs(t) do
                ids[id] = true
            end
        end
    end
    for id in pairs(ns.DUNGEON_BG) do
        ids[id] = true
    end
    local map, any = {}, false
    for id in pairs(ids) do
        local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(id)
        if name and texture then
            map[norm(name)] = { bg = ns.DUNGEON_BG[id], icon = texture, id = id }
            any = true
        end
    end
    if any then dungeonByName = map end
end

function ns.GetDungeonIconByName(name)
    local key = norm(name)
    if not key then return nil end
    EnsureDungeonMap()
    local e = dungeonByName[key]
    return e and e.icon or nil
end

local bossByName
local bossMapReady = false
local bossScanStarted = false

local function BuildBossMap()
    if bossByName then return true end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
    if not (EJ_GetInstanceByIndex and EJ_SelectInstance and EJ_GetEncounterInfoByIndex and EJ_GetCreatureInfo) then
        return false
    end
    local map, any = {}, false
    local function scanTier(tier)
        EJ_SelectTier(tier)
        local i = 1
        while true do
            local instanceID = EJ_GetInstanceByIndex(i, true)
            if not instanceID then break end
            EJ_SelectInstance(instanceID)
            local instBg = select(6, EJ_GetInstanceInfo(instanceID))
            local j = 1
            while true do
                local bossName, _, encounterID = EJ_GetEncounterInfoByIndex(j, instanceID)
                if not bossName then break end
                local key = norm(bossName)
                if key and not map[key] then
                    local _, _, _, displayID = EJ_GetCreatureInfo(1, encounterID)
                    map[key] =
                        { displayID = displayID, instanceID = instanceID, encounterID = encounterID, bg = instBg }
                    any = true
                end
                j = j + 1
            end
            i = i + 1
        end
    end
    pcall(function()
        local n = (EJ_GetNumTiers and EJ_GetNumTiers()) or 1
        scanTier(n)
        -- Expansion boundaries can briefly report the current tier empty;
        -- one tier back is cheap insurance before settling on no portraits.
        if not any and n > 1 then scanTier(n - 1) end
    end)
    if any then bossByName = map end
    bossMapReady = true
    return true
end

local function EnsureBossMap()
    if bossMapReady or bossScanStarted then return end
    bossScanStarted = true
    C_Timer.After(0, function()
        local ejReady = BuildBossMap()
        if ejReady then
            -- Refresh even when the scan came up empty: cards holding a
            -- placeholder must fall back to their normal icon, not pulse
            -- forever.
            if ns.RefreshBossArt then ns.RefreshBossArt() end
        else
            bossScanStarted = false
        end
    end)
end

function ns.RefreshBossArt()
    if ns.UpdatePanelIfVisible then ns.UpdatePanelIfVisible() end
    if ns.UpdateCompendium then ns:UpdateCompendium() end
    if ns.RefreshTalentPaneDropdown then ns.RefreshTalentPaneDropdown() end
end

function ns.GetBossArtByName(name)
    local key = norm(name)
    if not key then return nil end
    EnsureBossMap()
    return bossByName and bossByName[key] or nil
end

-- Journal navigation off a gear "source" line. Sources read like "Nek'zali"
-- (current-raid boss), "Ula'tek in Venomous Abyss" (boss + M+ dungeon) or
-- "King's Rest" (dungeon; M+ pools mix old expansions, so dungeons are
-- matched by name across every EJ tier, cached per name). "Catalyst from X"
-- strips to X. Returns instanceID, encounterID (encounter nil when only the
-- dungeon resolved); nil when nothing matched.
local dungeonInstanceByName = {}

local function DungeonInstanceIDByName(key)
    local cached = dungeonInstanceByName[key]
    if cached ~= nil then return cached or nil end
    local tiers = (EJ_GetNumTiers and EJ_GetNumTiers()) or 1
    for tier = 1, tiers do
        EJ_SelectTier(tier)
        local i = 1
        while true do
            local id, name = EJ_GetInstanceByIndex(i, false)
            if not id then break end
            if norm(name) == key then
                dungeonInstanceByName[key] = id
                return id
            end
            i = i + 1
        end
    end
    dungeonInstanceByName[key] = false
    return nil
end

function ns.GetJournalTarget(sourceText)
    if type(sourceText) ~= "string" or sourceText == "" then return nil end
    if
        not (
            EJ_SelectTier
            and EJ_GetNumTiers
            and EJ_GetInstanceByIndex
            and EJ_SelectInstance
            and EJ_GetEncounterInfoByIndex
        )
    then
        return nil
    end
    local text = sourceText:gsub("^Catalyst from ", "")

    -- Current-raid boss, named alone ("Nek'zali"). BuildBossMap is normally
    -- already warm from talent cards; a cold synchronous scan is fine on a click.
    local whole = norm(text)
    if whole and not bossByName then BuildBossMap() end
    if whole and bossByName and bossByName[whole] then
        local e = bossByName[whole]
        return e.instanceID, e.encounterID
    end

    local bossPart, dungeonPart = text:match("^(.-) in (.+)$")
    bossPart = bossPart and norm(bossPart)
    dungeonPart = norm(dungeonPart or text)
    if not dungeonPart then return nil end

    local ok, instanceID = pcall(DungeonInstanceIDByName, dungeonPart)
    if not (ok and instanceID) then return nil end

    if bossPart then
        local okEnc, encounterID = pcall(function()
            EJ_SelectInstance(instanceID)
            local j = 1
            while true do
                local name, _, enc = EJ_GetEncounterInfoByIndex(j, instanceID)
                if not name then break end
                if norm(name) == bossPart then return enc end
                j = j + 1
            end
            return nil
        end)
        if okEnc and encounterID then return instanceID, encounterID end
    end
    return instanceID, nil
end

-- Current-season journal loot index: itemID -> {instanceID, encounterID},
-- built once over the current tier's raid encounters and the M+ pool
-- dungeons (challenge-map names resolved to EJ instances across tiers).
-- Answers "can the journal actually show this item?" synchronously — for
-- rows with no parsable source — and pins the exact boss for dungeon-only
-- sources. Built lazily on first query; a few thousand C-side EJ calls,
-- one-time. A failed build is remembered (no per-click rebuild loops) and
-- reported once in chat so the gap is visible instead of silent.
local journalLootByItem
local journalLootScanTried = false

local function ScanEncounterLoot(instanceID, encounterID)
    EJ_SelectEncounter(encounterID)
    for i = 1, EJ_GetNumLoot() do
        local info = C_EncounterJournal.GetLootInfoByIndex(i)
        local id = info and info.itemID
        if id and not journalLootByItem[id] then
            journalLootByItem[id] = { instanceID = instanceID, encounterID = encounterID }
        end
    end
end

local function BuildJournalLootIndex()
    if journalLootScanTried then return end
    journalLootScanTried = true
    if not (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex and EJ_SelectEncounter and EJ_GetNumLoot) then
        print("|cffff3333Bread Codex:|r " .. ns.L["dungeon.journal_unavailable"])
        return
    end
    journalLootByItem = {}
    -- BOTH journal filters shrink EJ_GetNumLoot: the slot filter, and the
    -- class/spec loot filter — an active spec filter makes the index contain
    -- only that spec's loot. Enumerate with both cleared, restore after
    -- (QUI's ej_lootspecs sweeps the same way; filter 0/0 = no filter).
    local prevFilter = C_EncounterJournal.GetSlotFilter and C_EncounterJournal.GetSlotFilter() or nil
    if C_EncounterJournal.ResetSlotFilter then C_EncounterJournal.ResetSlotFilter() end
    local prevLootClass, prevLootSpec
    if EJ_GetLootFilter then
        prevLootClass, prevLootSpec = EJ_GetLootFilter()
    end
    if EJ_SetLootFilter then pcall(EJ_SetLootFilter, 0, 0) end
    local ok, err = pcall(function()
        local instances = {}

        -- Current tier's raids.
        EJ_SelectTier((EJ_GetNumTiers and EJ_GetNumTiers()) or 1)
        local i = 1
        while true do
            local id = EJ_GetInstanceByIndex(i, true)
            if not id then break end
            instances[#instances + 1] = id
            i = i + 1
        end

        -- M+ pool dungeons, whatever expansion they come from.
        if C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo then
            for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
                local name = C_ChallengeMode.GetMapUIInfo(mapID)
                local inst = name and DungeonInstanceIDByName(norm(name))
                if inst then instances[#instances + 1] = inst end
            end
        end

        for _, inst in ipairs(instances) do
            EJ_SelectInstance(inst)
            local j = 1
            while true do
                local _, _, encounterID = EJ_GetEncounterInfoByIndex(j, inst)
                if not encounterID then break end
                ScanEncounterLoot(inst, encounterID)
                j = j + 1
            end
        end
    end)
    if prevFilter ~= nil and C_EncounterJournal.SetSlotFilter then
        pcall(C_EncounterJournal.SetSlotFilter, prevFilter)
    end
    if prevLootClass ~= nil and EJ_SetLootFilter then pcall(EJ_SetLootFilter, prevLootClass or 0, prevLootSpec or 0) end
    if not ok then
        journalLootByItem = nil
        print("|cffff3333Bread Codex:|r " .. string.format(ns.L["dungeon.journal_build_failed"], tostring(err)))
    elseif not next(journalLootByItem) then
        journalLootByItem = nil
        print("|cffff3333Bread Codex:|r " .. ns.L["dungeon.journal_empty"])
    end
end

function ns.GetJournalLootTarget(itemId)
    if not itemId then return nil end
    if not journalLootByItem then BuildJournalLootIndex() end
    local e = journalLootByItem and journalLootByItem[itemId]
    if e then return e.instanceID, e.encounterID end
end

-- "Ready" means the scan has settled — with or without portraits. An empty
-- result makes cards fall back to their normal icon instead of a placeholder.
function ns.IsBossMapReady()
    return bossMapReady
end

-- Generic per-content-type icons for cards with no specific art (raid
-- overview, unknown bosses, M+ overview, delves, PvP). Blizzard's quest-log
-- tag icons read cleanly at card-icon size; guarded so a client rename
-- degrades to the spec icon instead of a broken texture.
local CONTENT_FALLBACK_ATLAS = {
    raid = "questlog-questtypeicon-raid",
    mplus = "questlog-questtypeicon-dungeon",
    delve = "questlog-questtypeicon-delves",
    pvp = "questlog-questtypeicon-pvp",
}

function ns.GetContentFallbackAtlas(kind)
    local atlas = kind and CONTENT_FALLBACK_ATLAS[kind] or nil
    if not atlas then return nil end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas) then return nil end
    return atlas
end
