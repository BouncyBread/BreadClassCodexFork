local _, ns = ...

-------------------------------------------------------------------------------
-- ArchonContext: Archon per-encounter talent accessors + zone auto-detection.
--
-- The Archon scraper emits the normalized ClassCodexSource["archongg"] table,
-- where each spec's talents carry aggregate context keys (mplus, raid,
-- raid:heroic) plus per-encounter keys (mplus:<dungeon>, raid:heroic:<boss>,
-- raid:mythic:<boss>) and an `archonContexts` metadata record with the
-- encounter order, display labels and Blizzard map/encounter ids. This module reads that
-- seam directly — there is no ClassCodexArchonData global anymore. It provides:
--
--   - ns.GetArchonContextSpecData(class, spec) — the per-spec record, or nil.
--   - ns.GroupArchonContexts(class, spec) — bucketed view: { mplusOverview,
--     mplusDungeons[], raidOverviewHeroic, raidOverviewMythic,
--     raidHeroicBosses[], raidMythicBosses[] }, each { contextKey, label,
--     builds } in metadata order (no hand-maintained season roster).
--   - ns.GetArchonTalentBuildsForContext(class, spec, contextKey) — canonical
--     build records (Shared/TalentBuildList.lua shape) for one context.
--   - ns.GetActiveArchonContext() — heuristic match from the player's current
--     zone / current pull to a context key, or nil if unknown.
--   - ns.GetArchonEncounterLabel(contextKey) — the display label for a context.
--   - ns.RegisterArchonContextCallback(fn) — fires whenever the active context
--     changes so the talent pane / Compendium can refresh their auto-pick.
--
-- Context-key vocabulary (mirrors the scraper's):
--   mplus                      M+ all-dungeons aggregate
--   mplus:<dungeon>            one dungeon
--   raid                       Mythic all-bosses aggregate (historical key;
--                              preserved so aggregate consumers never moved)
--   raid:heroic                Heroic all-bosses aggregate
--   raid:heroic:<boss> / raid:mythic:<boss>
--
-- Name matching below works on enUS clients. The scraper stamps the full
-- Archon dropdown label into archonContexts.labels and Blizzard's numeric id into
-- archonContexts.ids (dungeon mapId / raid encounterId); the id path is tried
-- first, name match second, and the few labels that differ from Blizzard's
-- in-game name are corrected in NAME_OVERRIDE below. A non-enUS client with no
-- matching numeric id falls back to the aggregate — it does not claim
-- locale-independent matching it doesn't have.
-------------------------------------------------------------------------------

local ARCHON_SOURCE = "archongg"

-- Aggregate context display names, same vocabulary the flat talent list uses.
local AGGREGATE_DISPLAY = {
    mplus = "Mythic+",
    raid = "Raid",
    ["raid:heroic"] = "Raid (Heroic)",
}

-------------------------------------------------------------------------------
-- Slug → in-game lookups (auto-derived from the scraped metadata)
-------------------------------------------------------------------------------

-- Archon's dropdown labels that differ from Blizzard's in-game name (which is
-- what the name-match path compares against). Everything else flows straight
-- from archonContexts.labels. Not a seasonal roster — add an entry only when
-- the two disagree.
local DUNGEON_NAME_OVERRIDE = {
    ["magisters"]       = "Magisters' Terrace",        -- archon renders "Magisters'"
    ["maisara-caverns"] = "Mai'sara Caverns",          -- archon renders "Maisara Caverns"
    ["seat"]            = "Seat of the Triumvirate",   -- archon renders "Seat"
}
local BOSS_NAME_OVERRIDE = {}

-- Optional numeric-ID pins for non-enUS clients where name-match can't work.
-- Normally the scraped ids in archonContexts.ids cover this.
local DUNGEON_ID_OVERRIDE = {}
local BOSS_ID_OVERRIDE = {}

local DUNGEON_BY_ID, DUNGEON_BY_NAME
local BOSS_BY_ID, BOSS_BY_NAME
-- slug -> display label, from the metadata (any spec).
local DUNGEON_DISPLAY, BOSS_DISPLAY
-- True once built against a populated data global; the lazy rebuild fires
-- exactly once when the data appears (toc order: this file loads before the
-- db_ files assign ClassCodexSource).
local lookupsBuilt = false

local function BuildLookups()
    DUNGEON_BY_ID, DUNGEON_BY_NAME = {}, {}
    BOSS_BY_ID, BOSS_BY_NAME = {}, {}
    DUNGEON_DISPLAY, BOSS_DISPLAY = {}, {}
    local data = ClassCodexSource and ClassCodexSource[ARCHON_SOURCE]
    lookupsBuilt = data ~= nil
    if data and data.data then
        for _, classData in pairs(data.data) do
            for _, specData in pairs(classData) do
                local meta = type(specData) == "table" and specData.archonContexts
                if meta and meta.labels then
                    local dungeonSlugs, bossSlugs = {}, {}
                    local function add(nameMap, displayMap, slug, label)
                        local name = label and label ~= "" and label or nil
                        if slug and name then
                            nameMap[name:lower()] = slug
                            displayMap[slug] = name
                        end
                    end
                    for _, slug in ipairs(meta.mplus or {}) do
                        dungeonSlugs[slug] = true
                        local label = DUNGEON_NAME_OVERRIDE[slug] or meta.labels[slug]
                        add(DUNGEON_BY_NAME, DUNGEON_DISPLAY, slug, label)
                    end
                    for _, slug in ipairs(meta.raidHeroic or {}) do
                        bossSlugs[slug] = true
                        local label = BOSS_NAME_OVERRIDE[slug] or meta.labels[slug]
                        add(BOSS_BY_NAME, BOSS_DISPLAY, slug, label)
                    end
                    for _, slug in ipairs(meta.raidMythic or {}) do
                        bossSlugs[slug] = true
                        local label = BOSS_NAME_OVERRIDE[slug] or meta.labels[slug]
                        add(BOSS_BY_NAME, BOSS_DISPLAY, slug, label)
                    end
                    for slug, id in pairs(meta.ids or {}) do
                        if id and id ~= 0 then
                            if dungeonSlugs[slug] and not DUNGEON_BY_ID[id] then
                                DUNGEON_BY_ID[id] = slug
                            elseif bossSlugs[slug] and not BOSS_BY_ID[id] then
                                BOSS_BY_ID[id] = slug
                            end
                        end
                    end
                end
            end
        end
    end
    -- Layer on any hand-pinned numeric IDs.
    for id, slug in pairs(DUNGEON_ID_OVERRIDE) do DUNGEON_BY_ID[id] = slug end
    for id, slug in pairs(BOSS_ID_OVERRIDE) do BOSS_BY_ID[id] = slug end
end
BuildLookups()

-- Rebuild the slug lookups on demand — the data may load after this file (toc
-- order) and a later scrape refresh can change the roster.
function ns.RebuildArchonLookups()
    BuildLookups()
end

-- The data global might not be populated when this file loads; rebuild lazily
-- the first time a lookup is needed after the data appears.
local function EnsureLookups()
    if not lookupsBuilt and ClassCodexSource and ClassCodexSource[ARCHON_SOURCE] then
        BuildLookups()
    end
end

-- Public helper: display label for a context key (or a bare slug). The
-- scraper stamps the full Archon dropdown label into archonContexts.labels, so
-- the metadata is the primary source; the overrides and derived *_DISPLAY
-- tables are the fallbacks for name-matching.
function ns.GetArchonEncounterLabel(contextKey)
    if not contextKey or contextKey == "" then return "" end
    EnsureLookups()
    -- Per-encounter keys are "<zone>:<difficulty>:<encounter>" for raids and
    -- "<zone>:<encounter>" for dungeons; the label lookup is keyed on the
    -- encounter slug, i.e. the last colon-separated segment.
    local slug = contextKey:match(":([^:]+)$") or contextKey
    if DUNGEON_NAME_OVERRIDE[slug] then return DUNGEON_NAME_OVERRIDE[slug] end
    if BOSS_NAME_OVERRIDE[slug] then return BOSS_NAME_OVERRIDE[slug] end
    if DUNGEON_DISPLAY[slug] then return DUNGEON_DISPLAY[slug] end
    if BOSS_DISPLAY[slug] then return BOSS_DISPLAY[slug] end
    return AGGREGATE_DISPLAY[contextKey] or ""
end

-------------------------------------------------------------------------------
-- Data accessors
-------------------------------------------------------------------------------

function ns.GetArchonContextSpecData(class, spec)
    if not class or not spec then return nil end
    return ns.SourceSpec and ns.SourceSpec(ARCHON_SOURCE, class, spec) or nil
end

-- True only when the spec has at least one dungeon- or boss-specific talent
-- context. Aggregate-only Season 1 data deliberately returns false so the UI
-- can show its temporary Season 2 availability notice. This is derived from
-- the actual talent keys instead of metadata, which prevents a partially
-- written scrape from hiding the notice before encounter builds are usable.
function ns.HasArchonEncounterData(class, spec)
    local sd = ns.GetArchonContextSpecData(class, spec)
    if not sd or not sd.talents then return false end
    for _, byContext in pairs(sd.talents) do
        for contextKey in pairs(byContext or {}) do
            if contextKey:match("^mplus:[^:]+$")
                or contextKey:match("^raid:heroic:[^:]+$")
                or contextKey:match("^raid:mythic:[^:]+$") then
                return true
            end
        end
    end
    return false
end

-- Canonical build records (Shared/TalentBuildList.lua shape) for ONE context,
-- across every hero that has builds there. The flat GetArchonTalentBuilds
-- accessor stays aggregate-only; this is the per-encounter surface.
function ns.GetArchonTalentBuildsForContext(class, spec, contextKey)
    local sd = ns.GetArchonContextSpecData(class, spec)
    if not sd or not sd.talents or not contextKey then return nil end
    local out = {}
    for hero, byContext in pairs(sd.talents) do
        local builds = byContext and byContext[contextKey]
        if builds then
            for i, b in ipairs(builds) do
                if b.export and b.export ~= "" then
                    out[#out + 1] = {
                        heroTalent   = ns.HeroDisplayName and ns.HeroDisplayName(hero) or hero,
                        context      = ns.GetArchonEncounterLabel(contextKey),
                        buildLabel   = b.label or ns.GetArchonEncounterLabel(contextKey),
                        exportString = b.export,
                        _heroSlug    = hero,
                        _contextKey  = contextKey,
                        _popularity  = b.popularity,
                        _order       = i,
                    }
                end
            end
        end
    end
    if #out == 0 then return nil end
    -- Preserve the scraper's recommendation order (default first, then by
    -- popularity) rather than reshuffling by label.
    table.sort(out, function(a, b)
        if a._heroSlug ~= b._heroSlug then return a._heroSlug < b._heroSlug end
        return a._order < b._order
    end)
    return out
end

-- Bucket contexts by zone type + difficulty for menu rendering. Each entry is
-- { contextKey, label, builds }. Order comes from the scraper-provided
-- archonContexts metadata (M+ dropdown order / raid pull order), so a season
-- rotation needs no code change here. Entries with no builds are omitted.
function ns.GroupArchonContexts(class, spec)
    local out = {
        mplusDungeons = {},
        raidHeroicBosses = {},
        raidMythicBosses = {},
    }
    local sd = ns.GetArchonContextSpecData(class, spec)
    if not sd or not sd.talents then return out end
    local meta = sd.archonContexts or {}

    local function entry(contextKey)
        local builds = ns.GetArchonTalentBuildsForContext(class, spec, contextKey)
        if not builds then return nil end
        return {
            contextKey = contextKey,
            label = ns.GetArchonEncounterLabel(contextKey),
            builds = builds,
        }
    end

    out.mplusOverview = entry("mplus")
    out.raidOverviewHeroic = entry("raid:heroic")
    out.raidOverviewMythic = entry("raid")

    local seen = { ["mplus"] = true, ["raid"] = true, ["raid:heroic"] = true }
    local function append(bucket, contextKey)
        if seen[contextKey] then return end
        seen[contextKey] = true
        local e = entry(contextKey)
        if e then bucket[#bucket + 1] = e end
    end
    for _, slug in ipairs(meta.mplus or {}) do append(out.mplusDungeons, "mplus:" .. slug) end
    for _, slug in ipairs(meta.raidHeroic or {}) do append(out.raidHeroicBosses, "raid:heroic:" .. slug) end
    for _, slug in ipairs(meta.raidMythic or {}) do append(out.raidMythicBosses, "raid:mythic:" .. slug) end

    -- Any per-encounter context the metadata missed (e.g. a fresh scrape whose
    -- metadata didn't load yet): sweep the data so nothing is unreachable.
    -- Per-encounter keys are mplus:<slug> or raid:<difficulty>:<slug>;
    -- the aggregates (mplus, raid, raid:heroic) are already covered.
    local leftovers = {}
    for hero, byContext in pairs(sd.talents) do
        for contextKey in pairs(byContext) do
            if not seen[contextKey] then
                if contextKey:match("^mplus:[^:]+$")
                    or contextKey:match("^raid:heroic:[^:]+$")
                    or contextKey:match("^raid:mythic:[^:]+$") then
                    leftovers[#leftovers + 1] = contextKey
                end
            end
        end
    end
    if #leftovers > 0 then
        table.sort(leftovers)
        for _, contextKey in ipairs(leftovers) do
            if contextKey:find("^raid:heroic:") then
                append(out.raidHeroicBosses, contextKey)
            elseif contextKey:find("^raid:mythic:") then
                append(out.raidMythicBosses, contextKey)
            else
                append(out.mplusDungeons, contextKey)
            end
        end
    end
    return out
end

-------------------------------------------------------------------------------
-- Zone / encounter detection
-------------------------------------------------------------------------------

local activeContextKey  -- cached "where is the player right now" key
local lastEncounterID   -- remembered between ENCOUNTER_START and ENCOUNTER_END
local lastEncounterName -- boss name from ENCOUNTER_START, for name-match
local callbacks = {}

-- "Heroic Raid" / "Mythic Raid" difficulty IDs.
-- 14 = Normal, 15 = Heroic, 16 = Mythic, 17 = LFR. Only mythic has its own
-- Archon dataset; the rest fall back to the heroic aggregate.
local DIFFICULTY_TO_ARCHON = {
    [14] = "heroic",
    [15] = "heroic",
    [16] = "mythic",
    [17] = "heroic",
}

local function ResolveDungeonSlug(instanceMapID, instanceName)
    EnsureLookups()
    if instanceMapID and DUNGEON_BY_ID[instanceMapID] then
        return DUNGEON_BY_ID[instanceMapID]
    end
    if instanceName and DUNGEON_BY_NAME[instanceName:lower()] then
        return DUNGEON_BY_NAME[instanceName:lower()]
    end
    return nil
end

local function ResolveBossSlug(encounterID, encounterName)
    EnsureLookups()
    if encounterID and BOSS_BY_ID[encounterID] then
        return BOSS_BY_ID[encounterID]
    end
    if encounterName and BOSS_BY_NAME[encounterName:lower()] then
        return BOSS_BY_NAME[encounterName:lower()]
    end
    return nil
end

local function ComputeActiveContext()
    local _, instanceType = IsInInstance()
    local instanceName, _, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()

    if instanceType == "party" then
        local slug = ResolveDungeonSlug(instanceMapID, instanceName)
        if slug then
            return "mplus:" .. slug
        end
        return "mplus"
    end

    if instanceType == "raid" then
        local archonDiff = DIFFICULTY_TO_ARCHON[difficultyID] or "heroic"

        -- Mid-pull: prefer the boss the player just engaged. Match on the
        -- encounter name (enUS), with the numeric Blizzard encounterID as the
        -- locale-independent primary path.
        if lastEncounterID or lastEncounterName then
            local slug = ResolveBossSlug(lastEncounterID, lastEncounterName)
            if slug then
                return "raid:" .. archonDiff .. ":" .. slug
            end
        end
        -- Between pulls: fall back to the difficulty-appropriate aggregate.
        -- Mythic's aggregate key is the historical "raid"; heroic's is
        -- "raid:heroic" (see the vocabulary note at the top).
        return archonDiff == "mythic" and "raid" or "raid:heroic"
    end

    return nil
end

local function FireCallbacks()
    for i = 1, #callbacks do
        local ok, err = pcall(callbacks[i], activeContextKey)
        if not ok then
            -- Surface the error but don't break the chain — one bad
            -- listener shouldn't take the others down with it.
            geterrorhandler()(err)
        end
    end
end

local function RefreshContext()
    local newKey = ComputeActiveContext()
    if newKey == activeContextKey then return end
    activeContextKey = newKey
    FireCallbacks()
end

function ns.GetActiveArchonContext()
    if activeContextKey == nil then RefreshContext() end
    return activeContextKey
end

function ns.RegisterArchonContextCallback(fn)
    callbacks[#callbacks + 1] = fn
end

-------------------------------------------------------------------------------
-- Event wiring
-------------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")
-- ENCOUNTER_START args: encounterID, encounterName, difficultyID, groupSize.
f:SetScript("OnEvent", function(_, event, encounterID, encounterName)
    if event == "ENCOUNTER_START" then
        lastEncounterID = encounterID
        lastEncounterName = encounterName
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        -- Honour the "reset on the next zone change" contract: forget the
        -- remembered boss so re-entering a raid shows the all-bosses overview
        -- until the next pull, instead of resolving a stale boss whose name
        -- still matches this raid's dataset.
        lastEncounterID = nil
        lastEncounterName = nil
    end
    -- ENCOUNTER_END keeps lastEncounter* so the picker still shows the boss
    -- until you move (zone change) or re-enter.
    RefreshContext()
end)
