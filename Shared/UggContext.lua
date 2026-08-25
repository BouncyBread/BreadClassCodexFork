local _, ns = ...

local UGG_DATA = _G.UGGData

local function GetUggGlobal()
    return UGG_DATA or _G.UGGData
end

local DUNGEON_NAME_OVERRIDE = {
    ["maisara-caverns"] = "Mai'sara Caverns",
}
local BOSS_NAME_OVERRIDE = {}

local DUNGEON_ID_OVERRIDE = {}
local BOSS_ID_OVERRIDE = {}

local DUNGEON_BY_ID, DUNGEON_BY_NAME
local BOSS_BY_ID, BOSS_BY_NAME

local DUNGEON_DISPLAY, BOSS_DISPLAY

local function DungeonName(slug, label)
    return DUNGEON_NAME_OVERRIDE[slug] or label
end
local function BossName(slug, label)
    return BOSS_NAME_OVERRIDE[slug] or label
end

local lookupsBuilt = false

local function BuildLookups()
    DUNGEON_BY_ID, DUNGEON_BY_NAME = {}, {}
    BOSS_BY_ID, BOSS_BY_NAME = {}, {}
    DUNGEON_DISPLAY, BOSS_DISPLAY = {}, {}

    local data = GetUggGlobal()
    lookupsBuilt = data ~= nil
    if data then
        for _, classData in pairs(data) do
            for _, specData in pairs(classData) do
                local contexts = type(specData) == "table" and specData.contexts
                if contexts then
                    for _, ctx in pairs(contexts) do
                        local slug = ctx.encounter
                        if slug and slug ~= "all-dungeons" and slug ~= "all-bosses" then
                            local label = ctx.encounterLabel
                            if ctx.zoneType == "mplus" then
                                local name = DungeonName(slug, label)
                                if name and name ~= "" then
                                    DUNGEON_BY_NAME[name:lower()] = slug
                                    DUNGEON_DISPLAY[slug] = name
                                end
                            elseif ctx.zoneType == "raid" then
                                local name = BossName(slug, label)
                                if name and name ~= "" then
                                    BOSS_BY_NAME[name:lower()] = slug
                                    BOSS_DISPLAY[slug] = name
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for id, slug in pairs(DUNGEON_ID_OVERRIDE) do
        DUNGEON_BY_ID[id] = slug
    end
    for id, slug in pairs(BOSS_ID_OVERRIDE) do
        BOSS_BY_ID[id] = slug
    end
end
BuildLookups()

function ns.RebuildUggLookups()
    BuildLookups()
end

function ns.GetUggEncounterLabel(ctx)
    if not ctx then return "" end
    if ctx.encounterLabel and ctx.encounterLabel ~= "" then return ctx.encounterLabel end
    local slug = ctx.encounter
    if slug and DUNGEON_DISPLAY[slug] then return DUNGEON_DISPLAY[slug] end
    if slug and BOSS_DISPLAY[slug] then return BOSS_DISPLAY[slug] end
    return ""
end

function ns.GetUggSpecData(class, spec)
    local data = GetUggGlobal()
    if not data then return nil end
    local cls = data[class]
    if not cls then return nil end
    return cls[spec]
end

function ns.FindUggBuildByExportString(class, spec, exportString)
    if not exportString then return nil end
    local sd = ns.GetUggSpecData(class, spec)
    if not sd or not sd.contexts then return nil end
    for ctxKey, ctx in pairs(sd.contexts) do
        if ctx.builds then
            for _, b in ipairs(ctx.builds) do
                if b.exportString == exportString then return b, ctx, ctxKey end
            end
        end
    end
    return nil
end

-- Current-season display order for u.gg encounters, keyed by the numeric u.gg
-- encounter id (context keys look like "raid:mythic:ugg-3470"). Encounters not
-- listed sort after the listed ones, alphabetically by label. RAID_BREAK ids
-- start a new section: consumers draw a separator in front of them (e.g.
-- Nymrissa belongs to a different raid than the season's main one).
local SEASON_DUNGEON_ORDER = {
    12923, -- Voidscar Arena
    12859, -- The Blinding Vale
    61877, -- Temple of Sethraliss
    112521, -- Ruby Life Pools
    12813, -- Murder Row
    61762, -- King's Rest
    12825, -- Den of Nalorakk
    12993, -- Altar of Fangs
}
local SEASON_RAID_ORDER = {
    3470, -- Nek'zali the Soulcoiler
    3445, -- Entombed Sentinels
    3497, -- The Lost Explorers
    3455, -- Vashnik the Malignant
    3420, -- Sszorak
    3421, -- The Twin Fangs
    3429, -- The Coiled Altar
    3492, -- Ula'tek
    3379, -- Nymrissa Wavecaller
}
local SEASON_RAID_BREAK = { [3379] = true }

function ns.GroupUggContexts(specData)
    local out = {
        mplusDungeons = {},
        raidHeroicBosses = {},
        raidMythicBosses = {},
        pvpArena = {},
        pvpBattleground = {},
    }
    if not specData or not specData.contexts then return out end

    local order = specData.contextOrder
    local seen = {}
    local function process(ctxKey)
        if seen[ctxKey] then return end
        seen[ctxKey] = true
        local ctx = specData.contexts[ctxKey]
        if not ctx then return end
        if ctx.zoneType == "mplus" then
            if ctx.encounter == "all-dungeons" then
                out.mplusOverview = { contextKey = ctxKey, ctx = ctx }
            else
                out.mplusDungeons[#out.mplusDungeons + 1] = { contextKey = ctxKey, ctx = ctx }
            end
        elseif ctx.zoneType == "raid" then
            if ctx.encounter == "all-bosses" then
                if ctx.difficulty == "mythic" then
                    out.raidOverviewMythic = { contextKey = ctxKey, ctx = ctx }
                else
                    out.raidOverviewHeroic = { contextKey = ctxKey, ctx = ctx }
                end
            else
                local bucket = (ctx.difficulty == "mythic") and out.raidMythicBosses or out.raidHeroicBosses
                bucket[#bucket + 1] = { contextKey = ctxKey, ctx = ctx }
            end
        elseif ctx.zoneType == "pvp" then
            local bucket = (ctx.encounter == "rbg") and out.pvpBattleground or out.pvpArena
            bucket[#bucket + 1] = { contextKey = ctxKey, ctx = ctx }
        end
    end

    if type(order) == "table" then
        for _, ctxKey in ipairs(order) do
            process(ctxKey)
        end
    end

    for ctxKey in pairs(specData.contexts) do
        process(ctxKey)
    end

    -- Sort each encounter bucket by the explicit season order above. The
    -- contextOrder emitted by SourceReader reflects pairs() discovery order —
    -- Lua hash order, which shuffles between sessions.
    local dungeonRank, raidRank = {}, {}
    for i, id in ipairs(SEASON_DUNGEON_ORDER) do
        dungeonRank[id] = i
    end
    for i, id in ipairs(SEASON_RAID_ORDER) do
        raidRank[id] = i
    end
    local function encounterId(ctx)
        local e = ctx and ctx.encounter
        if type(e) ~= "string" then return nil end
        return tonumber(e:match("ugg%-(%d+)$"))
    end
    local function sortBySeason(list, rank, isRaid)
        for _, e in ipairs(list) do
            local id = encounterId(e.ctx)
            e.rank = (id and rank[id]) or math.huge
            e.separatorBefore = (isRaid and id and SEASON_RAID_BREAK[id]) or false
        end
        table.sort(list, function(a, b)
            if a.rank ~= b.rank then return a.rank < b.rank end
            return (ns.GetUggEncounterLabel(a.ctx) or "") < (ns.GetUggEncounterLabel(b.ctx) or "")
        end)
    end
    sortBySeason(out.mplusDungeons, dungeonRank, false)
    sortBySeason(out.raidHeroicBosses, raidRank, true)
    sortBySeason(out.raidMythicBosses, raidRank, true)

    for _, k in ipairs({ "mplusOverview", "raidOverviewHeroic", "raidOverviewMythic" }) do
        if out[k] then out[k].isOverview = true end
    end

    return out
end

function ns.GetUggRaidGroupKind(ctx)
    if not ctx then return nil end
    if ctx.encounter == "all-bosses" then return "overview" end
    if type(ctx.encounter) == "string" then
        local id = tonumber(ctx.encounter:match("ugg%-(%d+)$"))
        if id and SEASON_RAID_BREAK[id] then return "other" end
    end
    return "main"
end

local activeContextKey
local lastEncounterID
local lastEncounterName
local callbacks = {}

local function EnsureLookups()
    if not lookupsBuilt and GetUggGlobal() then BuildLookups() end
end

local DIFFICULTY_TO_UGG = {
    [14] = "heroic",
    [15] = "heroic",
    [16] = "mythic",
    [17] = "heroic",
}

local function ResolveDungeonSlug(instanceMapID, instanceName)
    EnsureLookups()
    if instanceMapID and DUNGEON_BY_ID[instanceMapID] then return DUNGEON_BY_ID[instanceMapID] end
    if instanceName and DUNGEON_BY_NAME[instanceName:lower()] then return DUNGEON_BY_NAME[instanceName:lower()] end
    return nil
end

local function ResolveBossSlug(encounterID, encounterName)
    EnsureLookups()
    if encounterID and BOSS_BY_ID[encounterID] then return BOSS_BY_ID[encounterID] end
    if encounterName and BOSS_BY_NAME[encounterName:lower()] then return BOSS_BY_NAME[encounterName:lower()] end
    return nil
end

local function ComputeActiveContext()
    local _, instanceType = IsInInstance()
    local instanceName, _, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()

    if instanceType == "party" then
        local slug = ResolveDungeonSlug(instanceMapID, instanceName)
        if slug then return "mythic-plus:high-keys:" .. slug end
        return "mythic-plus:high-keys:all-dungeons"
    end

    if instanceType == "raid" then
        local uggDiff = DIFFICULTY_TO_UGG[difficultyID] or "heroic"

        if lastEncounterID or lastEncounterName then
            local slug = ResolveBossSlug(lastEncounterID, lastEncounterName)
            if slug then return "raid:" .. uggDiff .. ":" .. slug end
        end

        return "raid:" .. uggDiff .. ":all-bosses"
    end

    if ns.IsInPvPInstance and ns.IsInPvPInstance() then
        local bracket = (ns.GetActivePvPBracket and ns.GetActivePvPBracket()) or "any"
        return "pvp:" .. bracket
    end

    return nil
end

local function FireCallbacks()
    for i = 1, #callbacks do
        local ok, err = pcall(callbacks[i], activeContextKey)
        if not ok then geterrorhandler()(err) end
    end
end

local function RefreshContext()
    local newKey = ComputeActiveContext()
    if newKey == activeContextKey then return end
    activeContextKey = newKey
    FireCallbacks()
end

function ns.GetActiveUggContext()
    if activeContextKey == nil then RefreshContext() end
    return activeContextKey
end

function ns.RegisterUggContextCallback(fn)
    callbacks[#callbacks + 1] = fn
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("PLAYER_LEVEL_UP")

f:RegisterEvent("GROUP_ROSTER_UPDATE")

f:SetScript("OnEvent", function(_, event, encounterID, encounterName, difficultyID)
    if event == "ENCOUNTER_START" then
        lastEncounterID = encounterID
        lastEncounterName = encounterName
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        lastEncounterID = nil
        lastEncounterName = nil
    elseif event == "PLAYER_LEVEL_UP" then
        C_Timer.After(0, function()
            if activeContextKey == nil then activeContextKey = ComputeActiveContext() end
            FireCallbacks()
        end)
        return
    end

    RefreshContext()
end)

local function CurrentSpecID()
    if not GetSpecialization then return nil end
    local idx = GetSpecialization()
    if not idx then return nil end
    local id = GetSpecializationInfo and GetSpecializationInfo(idx)
    return id
end

function ns.GetPersistedTalentSource()
    if not ClassCodexCharDB then return nil end
    local specID = CurrentSpecID()
    if not specID or not ClassCodexCharDB.uggSource then return nil end
    return ClassCodexCharDB.uggSource[specID]
end

function ns.SetPersistedTalentSource(source)
    if not ClassCodexCharDB then return end
    local specID = CurrentSpecID()
    if not specID then return end
    ClassCodexCharDB.uggSource = ClassCodexCharDB.uggSource or {}
    ClassCodexCharDB.uggSource[specID] = source
end

function ns.SetPersistedUggContext(contextKey)
    if not ClassCodexCharDB then return end
    local specID = CurrentSpecID()
    if not specID then return end
    ClassCodexCharDB.uggContext = ClassCodexCharDB.uggContext or {}
    ClassCodexCharDB.uggContext[specID] = contextKey
end

function ns.GetPersistedUggHero()
    if not ClassCodexCharDB or not ClassCodexCharDB.uggHero then return nil end
    local specID = CurrentSpecID()
    return specID and ClassCodexCharDB.uggHero[specID] or nil
end

function ns.SetPersistedUggHero(hero)
    if not ClassCodexCharDB then return end
    local specID = CurrentSpecID()
    if not specID then return end
    ClassCodexCharDB.uggHero = ClassCodexCharDB.uggHero or {}
    ClassCodexCharDB.uggHero[specID] = hero
end

function ns.IsAtMaxLevel()
    local max = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
        or (GetMaxPlayerLevel and GetMaxPlayerLevel())
    if not max then return true end
    return (UnitLevel("player") or max) >= max
end

function ns.GetEffectiveTalentSource()
    if ClassCodexDB and ClassCodexDB.pinTalentSource then
        local persisted = ns.GetPersistedTalentSource()
        if persisted then return persisted end
    end

    if not ns.IsAtMaxLevel() then return "icyveins" end
    local activeKey = ns.GetActiveUggContext()
    if activeKey then
        if activeKey:find("^pvp:") then
            if ns.HasPvPData and ns.GetClassAndSpec then
                local class, spec = ns.GetClassAndSpec()
                if class and spec and ns.HasPvPData(class, spec) then return "ugg" end
            end
            return "icyveins"
        end
        return "ugg"
    end
    return "icyveins"
end

local UGG_CONTENT_KEY = {
    mplus = "mythic-plus:high-keys:all-dungeons",
    raid = "raid:mythic:all-bosses",
}
local UGG_CONTENT_LABEL = { mplus = "Mythic+", raid = "Raid", pvp = "PvP" }

function ns.GetUggTalentBuildsForContent(classToken, specKey, contentType, heroDisplay)
    local sd = ns.GetUggSpecData and ns.GetUggSpecData(classToken, specKey)
    if not sd or not sd.contexts then return {} end

    local ct = contentType or "mplus"
    if ct:sub(1, 4) == "pvp:" then ct = "pvp" end

    local ctxKey
    if ct == "mplus" or ct == "raid" then
        ctxKey = UGG_CONTENT_KEY[ct]
    elseif ct == "pvp" then
        if sd.contexts["pvp:3v3"] then
            ctxKey = "pvp:3v3"
        else
            for _, k in ipairs(sd.contextOrder or {}) do
                if k:sub(1, 4) == "pvp:" then
                    ctxKey = k
                    break
                end
            end
        end
    end
    local ctx = ctxKey and sd.contexts[ctxKey]
    if not ctx or not ctx.builds then return {} end

    local contentLabel = UGG_CONTENT_LABEL[ct] or ct
    local out = {}
    for _, b in ipairs(ctx.builds) do
        local heroOk = (not heroDisplay) or heroDisplay == "All" or b.heroTalent == heroDisplay
        if heroOk and b.exportString and b.exportString ~= "" then
            local parts = {}
            if b.heroTalent and b.heroTalent ~= "All" then parts[#parts + 1] = b.heroTalent end
            if b.pickrate and b.pickrate > 0 then parts[#parts + 1] = string.format("%g%%", b.pickrate) end
            local entry = {
                exportString = b.exportString,
                context = contentLabel,
                buildLabel = #parts > 0 and table.concat(parts, " ") or nil,
            }
            if b.topDps then entry.topDps = true end
            if b.pickrate then entry.pickrate = b.pickrate end
            out[#out + 1] = entry
        end
    end
    return out
end
