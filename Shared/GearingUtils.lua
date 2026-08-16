local _, ns = ...

-- Shared gearing helpers — item cache, format/quality lookups, BiS reverse
-- lookups (used by tooltip integration), row icon + tooltip factories, and
-- the PvP shape-conversion wrappers. Consumed by every Sections/* module
-- that renders gear data and by GearingSections.lua's dispatcher.
--
-- Pure utility layer: this file creates no widgets and registers no event
-- handlers other than ITEM_DATA_LOAD_RESULT for cache invalidation.

local L = ns.L

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Tier letters, best first. Icy Veins and u.gg only ever publish S-D, but
-- Wowhead's trinket tier lists also use E/F/G and "+" variants — measured across
-- all 40 specs: F on 8 specs (43 rows), plus one S+ (resto druid), two A+
-- (arcane mage) and two G (pres evoker). Those must be ranked and coloured, not
-- just tolerated: an unknown label falls to `or 99` in the sort, which would
-- have put resto druid's single BEST trinket at the BOTTOM of its list.
local TIER_LETTERS = { "S", "A", "B", "C", "D", "E", "F", "G" }
local TIER_BASE_COLOR = {
    S = { r = 1.00, g = 0.50, b = 0.00 },
    A = { r = 0.64, g = 0.21, b = 0.93 },
    B = { r = 0.00, g = 0.44, b = 0.87 },
    C = { r = 0.12, g = 1.00, b = 0.00 },
    D = { r = 0.62, g = 0.62, b = 0.62 },
    E = { r = 0.62, g = 0.62, b = 0.62 },
    F = { r = 0.55, g = 0.55, b = 0.55 },
    G = { r = 0.50, g = 0.50, b = 0.50 },
}

-- Built rather than written out so the two stay in step and a new letter is one
-- edit. "X+" ranks immediately above "X"; a plus variant shares its base colour,
-- since the letter already carries the meaning.
local TIER_COLORS, TIER_ORDER = {}, {}
do
    local rank = 0
    for _, letter in ipairs(TIER_LETTERS) do
        rank = rank + 1
        TIER_ORDER[letter .. "+"] = rank
        TIER_COLORS[letter .. "+"] = TIER_BASE_COLOR[letter]
        rank = rank + 1
        TIER_ORDER[letter] = rank
        TIER_COLORS[letter] = TIER_BASE_COLOR[letter]
    end
end

local CONTEXT_LABELS = {
    raid = L["context.raid"],
    dungeon = L["context.dungeon"],
    mplus = L["context.mplus"],
    delves = L["context.delves"],
    crafting = L["context.crafting"],
}

local CONSUMABLE_ORDER = { "flask", "combatPotion", "healthPotion", "food", "weaponBuff", "augmentRune" }
local CONSUMABLE_LABELS = {
    flask = L["consumable.flask"],
    combatPotion = L["consumable.combat_potion"],
    healthPotion = L["consumable.health_potion"],
    food = L["consumable.food"],
    weaponBuff = L["consumable.weapon_buff"],
    augmentRune = L["consumable.augment_rune"],
}

-- Enhance Shaman has 10 enchant slots (MH + OH weapon enchants, Helm,
-- Shoulders, Bracers, Chest, Belt, Legs, Boots, Ring). Cap at 12 to
-- match Compendium.lua's MAX_ENCHANT_ROWS so neither surface drops rows.
local MAX_ENCHANT_ROWS = 12
local MAX_GEM_ROWS = 8
local MAX_CONSUMABLE_ROWS = 6

-------------------------------------------------------------------------------
-- Item Cache
-------------------------------------------------------------------------------

local itemCache = {}
local pendingItems = {}
local gearingDirty = false

local function RequestItemData(itemId)
    if not itemId or itemId == 0 then return end
    if itemCache[itemId] or pendingItems[itemId] then return end
    pendingItems[itemId] = true
    C_Item.RequestLoadItemDataByID(itemId)
end

local function GetItemName(itemRef)
    if not itemRef then return "" end
    -- Spell-based entries (e.g. DK runeforges): resolve via C_Spell
    if itemRef.spellId then
        if C_Spell and C_Spell.GetSpellName then
            local name = C_Spell.GetSpellName(itemRef.spellId)
            if name then return name end
        elseif GetSpellInfo then
            local name = GetSpellInfo(itemRef.spellId)
            if name then return name end
        end
    end
    local cached = itemCache[itemRef.itemId]
    if cached and cached.name then return cached.name end
    if itemRef.name and itemRef.name ~= "" then return itemRef.name end
    if itemRef.spellId then return "Spell " .. itemRef.spellId end
    return "Item " .. itemRef.itemId
end

local function GetItemQuality(itemId)
    local cached = itemCache[itemId]
    return cached and cached.quality or nil
end

-- FormatItem(itemRef [, name]) -> string
-- Convenience wrapper around ns.FormatItemLabel that pulls the
-- quality from the cache for callers that don't already have it.
-- Pass an explicit name override (e.g. after StripEnchantPrefix)
-- when the displayed text differs from the resolved item name.
local function FormatItem(itemRef, nameOverride)
    if not itemRef then return "" end
    local name = nameOverride or GetItemName(itemRef)
    return ns.FormatItemLabel(name, GetItemQuality(itemRef.itemId))
end

local itemEventFrame = CreateFrame("Frame")
itemEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
itemEventFrame:SetScript("OnEvent", function(_, _, itemId, success)
    if success then
        pendingItems[itemId] = nil
        local name, _, quality, _, _, _, _, _, _, icon = GetItemInfo(itemId)
        if name then
            itemCache[itemId] = { name = name, quality = quality, icon = icon }
            if not gearingDirty then
                gearingDirty = true
                C_Timer.After(0.1, function()
                    gearingDirty = false
                    if ns.panel and ns.panel:IsShown() then
                        ns:UpdateGearingSections()
                        ns:LayoutPanel()
                    end
                end)
            end
        end
    end
end)

-- Prefetch every item id in an enchants/gems/consumables record.
--
-- Wowhead and Archon publish these as item ids, and both are rendered from their
-- own accessor result rather than from the gearData the panel prefetches — so
-- without this their rows showed the literal "Item 243952" placeholder. The few
-- that did resolve were the ones whose ids happen to coincide with the u.gg /
-- Icy Veins picks already in the cache, which is why the section looked half
-- broken rather than plainly broken.
--
-- `request` is passed in because the Compendium owns a separate item cache from
-- the docked panel and each must warm its own.
local function RequestEnhancementItems(enh, request)
    if not enh then return end
    request = request or RequestItemData
    if enh.enchants then
        for _, e in ipairs(enh.enchants) do
            if e.best then request(e.best.itemId) end
            if e.alternate then request(e.alternate.itemId) end
        end
    end
    if enh.gems then
        if enh.gems.primary then request(enh.gems.primary.itemId) end
        if enh.gems.secondary then
            for _, g in ipairs(enh.gems.secondary) do request(g.itemId) end
        end
    end
    if enh.consumables then
        for _, key in ipairs(CONSUMABLE_ORDER) do
            local c = enh.consumables[key]
            if c then request(c.itemId) end
        end
    end
end

local function RequestAllItems(gearData)
    if not gearData then return end
    RequestEnhancementItems(gearData, RequestItemData)
    if gearData.trinkets then
        for _, t in ipairs(gearData.trinkets) do
            RequestItemData(t.itemId)
            -- Archon rows name the paired trinket, which is otherwise never
            -- requested and would render as the "Item 12345" placeholder.
            if t.partnerItemId then RequestItemData(t.partnerItemId) end
        end
    end
    -- Crafting item prefetch — defer to the Section module so this stays
    -- in sync with whatever shape Sections/Crafting.lua expects.
    local craftClassToken, craftSpec = ns.GetPlayerClassSpec()
    ns.Sections.Crafting.RequestItems(craftClassToken, craftSpec, RequestItemData)
    if gearData.bisGear then
        for _, tab in ipairs(gearData.bisGear) do
            for _, g in ipairs(tab.slots) do RequestItemData(g.item.itemId) end
        end
    end
end

-------------------------------------------------------------------------------
-- Gear Data Lookup
-------------------------------------------------------------------------------

-- Every source that can supply trinkets, in the order the dropdowns offer them
-- and the order the fallback walks. Single source of truth: Sections/Trinkets.lua
-- builds both its dropdowns from this rather than keeping its own copies, which
-- is how the panel came to offer Archon while the Compendium did not.
ns.TRINKET_SOURCE_ORDER = { "icyveins", "ugg", "wowhead", "archongg" }
local TRINKET_SOURCE_ORDER = ns.TRINKET_SOURCE_ORDER

-- The trinket source is a per-spec preference (default Icy Veins, whose tier
-- rankings are editorial rather than u.gg's popularity). Keyed by the current
-- spec so the panel, Compendium and tooltip tier lookup all agree — mirrors how
-- trinketContext is stored (Sections/Trinkets.lua).
local function GetTrinketSource()
    local specKey = ns.GetSpecKey and ns.GetSpecKey()
    if specKey and ClassCodexCharDB and ClassCodexCharDB.perSpec
        and ClassCodexCharDB.perSpec[specKey]
        and ClassCodexCharDB.perSpec[specKey].trinketSource then
        return ClassCodexCharDB.perSpec[specKey].trinketSource
    end
    return "icyveins"
end

-- trinketSourceOverride: when set (the Compendium passes its session-scoped
-- source), it wins over the per-spec saved pref. The panel and tooltip omit it
-- and use the saved pref.
local function GetSpecGearData(classToken, specKey, trinketSourceOverride)
    if not (classToken and specKey) then classToken, specKey = ns.GetClassAndSpec() end
    if not classToken or not specKey then return nil end
    local out = {}
    -- trinkets from the selected source (default Icy Veins), falling back to the
    -- other source if the chosen one carries none for this spec.
    -- Icy Veins and u.gg publish one undivided trinket list on the hero/context
    -- wildcards. Archon splits its by zone type instead, so its rows are merged
    -- into a single list tagged with the contexts each item appeared in — that's
    -- what feeds the section's existing context dropdown, no new UI needed.
    local function readTrinkets(src)
        local sd = ns.SourceSpec and ns.SourceSpec(src, classToken, specKey)
        if not (sd and sd.trinkets) then return nil end
        local flat = sd.trinkets["all"] and sd.trinkets["all"]["all"]
        if flat then return flat end

        local merged, byId = {}, {}
        for _, ctx in ipairs({ "mplus", "raid" }) do
            for _, t in ipairs(ns.ResolveCategory(sd.trinkets, "all", ctx) or {}) do
                local row = byId[t.itemId]
                if not row then
                    row = {
                        itemId = t.itemId, tier = t.tier,
                        popularity = t.popularity, pct = tonumber((t.popularity or ""):match("^([%d%.]+)")) or 0,
                        partnerItemId = t.partnerItemId, contexts = {}, ctxSeen = {},
                    }
                    byId[t.itemId] = row
                    merged[#merged + 1] = row
                else
                    -- Same trinket in both contexts: keep the stronger showing.
                    local pct = tonumber((t.popularity or ""):match("^([%d%.]+)")) or 0
                    if pct > row.pct then
                        row.pct, row.popularity, row.partnerItemId = pct, t.popularity, t.partnerItemId
                    end
                end
                -- One trinket appears in several combos per context, so guard
                -- against stacking the same context up once per pairing.
                if not row.ctxSeen[ctx] then
                    row.ctxSeen[ctx] = true
                    row.contexts[#row.contexts + 1] = ctx
                end
            end
        end
        if #merged == 0 then return nil end
        -- The source ships each context already ranked; after merging, order by
        -- the strongest share so the combined list still reads best-first.
        table.sort(merged, function(a, b) return a.pct > b.pct end)
        return merged
    end
    local tsrc = trinketSourceOverride or GetTrinketSource()
    local tr = readTrinkets(tsrc)
    if not tr then
        -- Ordered fallback rather than the old two-way icyveins<->ugg toggle: a
        -- Wowhead or Archon pick that yields nothing for this spec used to land
        -- on Icy Veins silently whichever way it fell.
        for _, alt in ipairs(TRINKET_SOURCE_ORDER) do
            if alt ~= tsrc then
                tr = readTrinkets(alt)
                if tr then break end
            end
        end
    end
    if tr then
        local list = {}
        for _, t in ipairs(tr) do
            list[#list + 1] = {
                itemId = t.itemId, tier = t.tier, popularity = t.popularity or t.pop,
                partnerItemId = t.partnerItemId, contexts = t.contexts,
                -- Wowhead publishes no tier and no adoption share; the drop
                -- location is its only per-row signal, so it must survive the
                -- projection or its rows render with an empty right column.
                source = t.source,
                -- Both Trinkets surfaces set row.bonusIDs from this and nothing
                -- ever supplied it: NO source publishes bonus ids on a trinket
                -- row (only Icy Veins' GEAR rows carry them). So every trinket
                -- link was built at base item level. Borrow from the harvested
                -- itemId -> bonusIDs map, exactly as Sections/Gear.lua's
                -- ResolveRow does for u.gg gear rows.
                bonusIDs = t.bonusIDs or (ns.GetItemBonusIDs and ns:GetItemBonusIDs(t.itemId)),
            }
        end
        out.trinkets = list
    end
    -- gems from u.gg
    local usd = ns.SourceSpec and ns.SourceSpec("ugg", classToken, specKey)
    if usd then
        local gm = usd.gems and usd.gems["all"] and usd.gems["all"]["all"]
        if gm and gm[1] then
            local secondary = {}
            for _, id in ipairs(gm[1].secondary or {}) do secondary[#secondary + 1] = { itemId = id } end
            out.gems = { primary = gm[1].primary and { itemId = gm[1].primary } or nil, secondary = secondary }
        end
    end
    -- consumables from Icy Veins; BiS gear reuses the (already-converted) IV accessor
    local ivsd = ns.SourceSpec and ns.SourceSpec("icyveins", classToken, specKey)
    if ivsd then
        local c = ivsd.consumables and ivsd.consumables["all"] and ivsd.consumables["all"]["all"]
        if c then
            local function top(l) return l and l[1] and { itemId = l[1] } or nil end
            out.consumables = { flask = top(c.flask), combatPotion = top(c.potions), food = top(c.food), augmentRune = top(c.augmentRune) }
        end
    end
    local iv = ns.GetIcyVeinsSpecData and ns:GetIcyVeinsSpecData(classToken, specKey)
    if iv then out.bisGear = iv.bisGear end
    if not next(out) then return nil end
    return out
end

-- Resolve the (classToken, spec-without-class-prefix) pair the docked
-- panel uses for PvP data lookups via PvPData.lua. The docked surface
-- always reflects the player's current spec.
local function GetPlayerClassSpec()
    local classToken = select(2, UnitClass("player"))
    local specKey = ns.GetSpecKey()
    if not classToken or not specKey then return nil, nil end
    local spec = specKey:match("-(.+)") or specKey
    return classToken, spec
end

-- PvP shape conversion lives in Shared/PvPData.lua so the Compendium and
-- the docked panel consume the same builders. Bundled into one table to
-- minimise upvalue pressure on UpdateGearingSections (Lua's 60-upvalue
-- limit was tripping after these helpers were added).
local PvP = {
    bis = function()
        if not ns.BuildPvPBisTabs then return nil end
        local classToken, spec = GetPlayerClassSpec()
        return ns.BuildPvPBisTabs(classToken, spec)
    end,
    enchants = function()
        if not ns.BuildPvPEnchantsRows then return nil end
        local classToken, spec = GetPlayerClassSpec()
        return ns.BuildPvPEnchantsRows(classToken, spec)
    end,
    gems = function()
        if not ns.BuildPvPGemsRecord then return nil end
        local classToken, spec = GetPlayerClassSpec()
        return ns.BuildPvPGemsRecord(classToken, spec)
    end,
}

-- Expose trinket tier lookup for tooltip integration
function ns:GetTrinketTier(itemId)
    local gearData = GetSpecGearData()
    if not gearData or not gearData.trinkets then return nil, nil, nil end
    for _, t in ipairs(gearData.trinkets) do
        if t.itemId == itemId then
            local color = TIER_COLORS[t.tier]
            return t.tier, color, t.source
        end
    end
    return nil, nil, nil
end

-- Locale-aware class/spec name resolution for tooltip BiS labels.
-- Class names come from Blizzard's LOCALIZED_CLASS_NAMES_MALE. Spec names are
-- resolved via GetSpecializationInfoForClassID using a local (classToken,
-- specKey) → (classID, specIndex) mapping that mirrors the data file keys.
-- Final fallback is a capitalized data key.
local SPEC_KEYS_BY_CLASS = {
    DEATHKNIGHT  = { "blood", "frost", "unholy" },
    DEMONHUNTER  = { "havoc", "vengeance", "devourer" },
    DRUID        = { "balance", "feral", "guardian", "restoration" },
    EVOKER       = { "devastation", "preservation", "augmentation" },
    HUNTER       = { "beast-mastery", "marksmanship", "survival" },
    MAGE         = { "arcane", "fire", "frost" },
    MONK         = { "brewmaster", "mistweaver", "windwalker" },
    PALADIN      = { "holy", "protection", "retribution" },
    PRIEST       = { "discipline", "holy", "shadow" },
    ROGUE        = { "assassination", "outlaw", "subtlety" },
    SHAMAN       = { "elemental", "enhancement", "restoration" },
    WARLOCK      = { "affliction", "demonology", "destruction" },
    WARRIOR      = { "arms", "fury", "protection" },
}

local CLASS_ID_BY_TOKEN = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, MONK = 10,
    DRUID = 11, DEMONHUNTER = 12, EVOKER = 13,
}

local localizedClassNameCache = {}
local localizedSpecNameCache = {}

local function GetLocalizedClassName(classToken)
    local cached = localizedClassNameCache[classToken]
    if cached ~= nil then return cached end
    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or classToken
    localizedClassNameCache[classToken] = name
    return name
end

local function GetLocalizedSpecName(classToken, specKey)
    local cacheKey = classToken .. "|" .. specKey
    local cached = localizedSpecNameCache[cacheKey]
    if cached ~= nil then return cached end

    local result
    local classID = CLASS_ID_BY_TOKEN[classToken]
    local keys = SPEC_KEYS_BY_CLASS[classToken]
    local specIndex
    if keys then
        for i, k in ipairs(keys) do
            if k == specKey then specIndex = i; break end
        end
    end
    if classID and specIndex and GetSpecializationInfoForClassID then
        local _, name = GetSpecializationInfoForClassID(classID, specIndex)
        if name and name ~= "" then result = name end
    end
    if not result then
        result = specKey:sub(1, 1):upper() .. specKey:sub(2)
    end
    localizedSpecNameCache[cacheKey] = result
    return result
end

local CLASS_SPEC_COUNT = {}
local uggBisLookup = {}
local icyVeinsBisLookup = {}
local wowheadBisLookup = {}
local archonBisLookup = {}
local trinketLookup = {}
local trinketSourceLookup = {}
-- itemId -> bonusIDs, harvested from every source that carries them (u.gg /
-- Icy Veins BiS slots + trinkets). u.gg's gear pages don't publish bonus IDs,
-- so the u.gg source borrows them here to render the correct item level.
local bonusIdLookup = {}
-- context ("raid" / "dungeon") -> the upgrade-track bonusIDs typical of that
-- content, taken from the first trinket we see in that context. Used as the
-- fallback for u.gg items we can't resolve exactly, so a raid pick still
-- shows a mythic-raid item level rather than its base.
local contextBonusDefault = {}

function ns:GetTrinketSource(itemId)
    return trinketSourceLookup[itemId]
end

function ns:GetItemBonusIDs(itemId)
    return bonusIdLookup[itemId]
end

function ns:GetContextBonusDefault(context)
    return context and contextBonusDefault[context]
end

-- Iterate every spec that has data in any source (union), once.
local function eachSourceSpec(fn)
    local src = ClassCodexSource
    if not src then return end
    local seen = {}
    -- Union across every source that can feed a reverse lookup. Icy Veins and
    -- u.gg already cover all 40 specs, so adding the newer two changes nothing
    -- today — but it keeps CLASS_SPEC_COUNT (which drives the consolidate-to-
    -- class-name rule) correct if a source ever covers a spec the others miss.
    for _, source in ipairs({ "icyveins", "ugg", "wowhead", "archongg" }) do
        local data = src[source] and src[source].data
        if data then
            for classToken, specs in pairs(data) do
                for specKey in pairs(specs) do
                    local key = classToken .. "/" .. specKey
                    if not seen[key] then
                        seen[key] = true
                        fn(classToken, specKey)
                    end
                end
            end
        end
    end
end

local function BuildBisLookup()
    eachSourceSpec(function(classToken, specKey)
        CLASS_SPEC_COUNT[classToken] = (CLASS_SPEC_COUNT[classToken] or 0) + 1
        local label = GetLocalizedSpecName(classToken, specKey) .. " " .. GetLocalizedClassName(classToken)

        -- Trinket reverse lookup: itemId + tier, per spec.
        --
        -- Read u.gg alone, which missed almost everything once Wowhead began
        -- publishing a full S-D tier list (907 rows across all 40 specs) and
        -- Icy Veins its own. Walk TRINKET_SOURCE_ORDER and take the FIRST
        -- source that rates this trinket for this spec, so a spec is never
        -- listed twice with two sources' disagreeing letters. The winning
        -- source is recorded on the entry so the tooltip can show whose tier
        -- it is rather than mixing provenance silently.
        local ratedHere = {}
        for _, srcKey in ipairs(ns.TRINKET_SOURCE_ORDER or {}) do
            local ssd = ns.SourceSpec and ns.SourceSpec(srcKey, classToken, specKey)
            local st = ssd and ssd.trinkets
            local rows = st and st["all"] and st["all"]["all"]
            if not rows and st then
                -- Archon splits by zone type instead of the wildcard.
                rows = {}
                for _, ctx in ipairs({ "mplus", "raid" }) do
                    for _, t in ipairs(ns.ResolveCategory(st, "all", ctx) or {}) do
                        rows[#rows + 1] = t
                    end
                end
            end
            for _, t in ipairs(rows or {}) do
                local id = t.itemId
                if id and t.tier and not ratedHere[id] then
                    ratedHere[id] = true
                    trinketLookup[id] = trinketLookup[id] or {}
                    trinketLookup[id][#trinketLookup[id] + 1] =
                        { label = label, class = classToken, spec = specKey, tier = t.tier, src = srcKey }
                end
            end
        end

        -- u.gg BiS reverse lookup: non-trinket gear slots across both content tabs
        -- (deduped per spec). Trinkets are excluded — they have their own lookup.
        local trinketIds = {}
        if tr then for _, t in ipairs(tr) do trinketIds[t.itemId] = true end end
        local uggGear = ns.GetUggGearSpecData and ns:GetUggGearSpecData(classToken, specKey)
        if uggGear and uggGear.bisGear then
            local addedForSpec = {}
            for _, tab in ipairs(uggGear.bisGear) do
                for _, entry in ipairs(tab.slots) do
                    local id = entry.item.itemId
                    local slotLower = entry.slot and entry.slot:lower() or ""
                    if id and not slotLower:find("trinket") and not trinketIds[id] and not addedForSpec[id] then
                        addedForSpec[id] = true
                        uggBisLookup[id] = uggBisLookup[id] or {}
                        uggBisLookup[id][#uggBisLookup[id] + 1] = { label = label, class = classToken, spec = specKey }
                    end
                end
            end
        end

        -- Icy Veins BiS reverse lookup (all tabs) + bonus IDs for item-level rendering.
        local ivGear = ns.GetIcyVeinsSpecData and ns:GetIcyVeinsSpecData(classToken, specKey)
        if ivGear and ivGear.bisGear then
            for _, tab in ipairs(ivGear.bisGear) do
                for _, entry in ipairs(tab.slots) do
                    local id = entry.item.itemId
                    if entry.item.bonusIDs and not bonusIdLookup[id] then bonusIdLookup[id] = entry.item.bonusIDs end
                    icyVeinsBisLookup[id] = icyVeinsBisLookup[id] or {}
                    local found = false
                    for _, existing in ipairs(icyVeinsBisLookup[id]) do
                        if existing.label == label then existing.tabs[#existing.tabs + 1] = tab.label; found = true; break end
                    end
                    if not found then
                        icyVeinsBisLookup[id][#icyVeinsBisLookup[id] + 1] = { label = label, class = classToken, spec = specKey, tabs = { tab.label } }
                    end
                end
            end
        end

        -- Wowhead BiS reverse lookup. Wowhead publishes one undivided table per
        -- spec, so there is no tab dimension to accumulate — one entry per spec.
        local whGear = ns.GetWowheadGearSpecData and ns:GetWowheadGearSpecData(classToken, specKey)
        if whGear and whGear.bisGear then
            local addedForSpec = {}
            for _, tab in ipairs(whGear.bisGear) do
                for _, entry in ipairs(tab.slots) do
                    local id = entry.item.itemId
                    if id and not addedForSpec[id] then
                        addedForSpec[id] = true
                        wowheadBisLookup[id] = wowheadBisLookup[id] or {}
                        wowheadBisLookup[id][#wowheadBisLookup[id] + 1] =
                            { label = label, class = classToken, spec = specKey }
                    end
                end
            end
        end

        -- Archon BiS reverse lookup. Archon splits by zone type, so it carries
        -- tabs the way Icy Veins does, plus a popularity share no other source
        -- publishes. Keep the highest popularity seen for the item in this spec
        -- — an item that is 84% in one context and 3% in another is best
        -- described by the number that made it interesting.
        local archonGear = ns.GetArchonGearSpecData and ns:GetArchonGearSpecData(classToken, specKey)
        if archonGear and archonGear.bisGear then
            for _, tab in ipairs(archonGear.bisGear) do
                for _, entry in ipairs(tab.slots) do
                    local id = entry.item.itemId
                    if id then
                        archonBisLookup[id] = archonBisLookup[id] or {}
                        local pct = tonumber((entry.popularity or ""):match("^([%d%.]+)")) or 0
                        local found = false
                        for _, existing in ipairs(archonBisLookup[id]) do
                            if existing.label == label then
                                existing.tabs[#existing.tabs + 1] = tab.label
                                if pct > (existing.pct or 0) then
                                    existing.pct, existing.popularity = pct, entry.popularity
                                end
                                found = true
                                break
                            end
                        end
                        if not found then
                            archonBisLookup[id][#archonBisLookup[id] + 1] = {
                                label = label, class = classToken, spec = specKey,
                                tabs = { tab.label }, pct = pct, popularity = entry.popularity,
                            }
                        end
                    end
                end
            end
        end

    end)
    -- trinketSourceLookup / contextBonusDefault stay empty: u.gg trinkets carry no
    -- source or bonusIDs (they were nil on the legacy path too).
end
-- Called at end of file, once the accessors it uses (GetUggGearSpecData /
-- GetIcyVeinsSpecData) are defined.

-- Consolidate entries: if all specs of a class share the same entry, show
-- just the class name.
local function ConsolidateByClass(entries)
    local byClass = {}
    local classOrder = {}
    for _, entry in ipairs(entries) do
        if not byClass[entry.class] then
            byClass[entry.class] = {}
            classOrder[#classOrder + 1] = entry.class
        end
        byClass[entry.class][#byClass[entry.class] + 1] = entry
    end

    local result = {}
    for _, classToken in ipairs(classOrder) do
        local classEntries = byClass[classToken]
        local totalSpecs = CLASS_SPEC_COUNT[classToken] or 0
        local className = GetLocalizedClassName(classToken)
        local sameTier = true
        if #classEntries > 1 then
            for i = 2, #classEntries do
                if classEntries[i].tier ~= classEntries[1].tier then sameTier = false; break end
            end
        end
        if #classEntries >= totalSpecs and totalSpecs > 0 and sameTier then
            -- Carry the highest popularity share across the class's specs onto the
            -- consolidated row. Without this the share vanishes for exactly the
            -- items that matter most: anything every spec of a class wants
            -- consolidates, which is the common case for armour. Deliberately
            -- only `popularity` is propagated, not `tabs` — the tooltip's
            -- existing tab rendering for consolidated Icy Veins rows depends on
            -- tabs staying absent here.
            local best
            for _, e in ipairs(classEntries) do
                if e.pct and (not best or e.pct > best.pct) then best = e end
            end
            -- Same for `src`, which names whose tier letter this is: carry it
            -- only when every spec of the class was rated by the SAME source.
            -- Mixed provenance leaves it nil, so the tooltip shows the letter
            -- without claiming a source rather than crediting one arbitrarily.
            local src, mixed = classEntries[1].src, false
            for _, e in ipairs(classEntries) do
                if e.src ~= src then mixed = true; break end
            end
            result[#result + 1] = {
                label = className, class = classToken, tier = classEntries[1].tier,
                consolidated = true,
                popularity = best and best.popularity or nil,
                pct = best and best.pct or nil,
                src = (not mixed) and src or nil,
            }
        else
            for _, e in ipairs(classEntries) do
                e.consolidated = false
                result[#result + 1] = e
            end
        end
    end
    return result
end

function ns:GetUggBisSpecs(itemId)
    local raw = uggBisLookup[itemId]
    if not raw then return nil end
    return ConsolidateByClass(raw)
end

function ns:GetIcyVeinsBisSpecs(itemId)
    local raw = icyVeinsBisLookup[itemId]
    if not raw then return nil end
    return ConsolidateByClass(raw)
end

function ns:GetWowheadBisSpecs(itemId)
    local raw = wowheadBisLookup[itemId]
    if not raw then return nil end
    return ConsolidateByClass(raw)
end

function ns:GetArchonBisSpecs(itemId)
    local raw = archonBisLookup[itemId]
    if not raw then return nil end
    return ConsolidateByClass(raw)
end


local IV_GEAR_TAB = { all = "Overall", raid = "Raid", mplus = "Mythic+" }
-- Wowhead's BiS guide is a single undivided list; it reuses the "Overall" tab
-- label so switching sources keeps the saved tab selection valid.
local WH_GEAR_TAB = "Overall"
function ns:GetIcyVeinsSpecData(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("icyveins", classToken, specKey)
    local gearByHero = sd and sd.gear and sd.gear["all"] -- IV is hero-agnostic
    if not gearByHero then return nil end
    -- Direct per-context access (not the fallback resolver) so a missing Raid/M+
    -- tab doesn't inherit the Overall gear.
    local bisGear = {}
    for _, ctx in ipairs({ "all", "raid", "mplus" }) do
        local slots = gearByHero[ctx]
        if slots then
            local out = {}
            for _, g in ipairs(slots) do
                out[#out + 1] = { slot = g.slot, item = { itemId = g.itemId, bonusIDs = g.bonusIDs }, source = g.source }
            end
            bisGear[#bisGear + 1] = { label = IV_GEAR_TAB[ctx], slots = out }
        end
    end
    if #bisGear == 0 then return nil end
    return { bisGear = bisGear }
end

function ns:GetUggGearSpecData(classToken, specKey)
    if not classToken or not specKey then return nil end
    -- Read the normalized structure via the seam and shape it into the
    -- { bisGear = { {label, slots={{slot, item={itemId}}}} }, enchants = { {slot, best} } }
    -- the UI expects.
    local sd = ns.SourceSpec and ns.SourceSpec("ugg", classToken, specKey)
    if not sd then return nil end
    local bisGear = {}
    for _, ctx in ipairs({ "mplus", "raid" }) do
        local slots = ns.ResolveCategory(sd.gear, "all", ctx)
        if slots then
            local out = {}
            for _, g in ipairs(slots) do out[#out + 1] = { slot = g.slot, item = { itemId = g.itemId } } end
            bisGear[#bisGear + 1] = { label = (ctx == "mplus") and "Mythic+" or "Raid", slots = out }
        end
    end
    local enchants = {}
    local ench = ns.ResolveCategory(sd.enchants, "all", "all")
    if ench then
        for slot, list in pairs(ench) do
            local e = list[1]
            if e then
                local name = e.spellId and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(e.spellId) or nil
                enchants[#enchants + 1] = { slot = slot, best = { enchantId = e.id, spellId = e.spellId, name = name } }
            end
        end
    end
    if #bisGear == 0 and #enchants == 0 then return nil end
    return { bisGear = bisGear, enchants = enchants }
end

-- Wowhead publishes a single BiS table per spec (no Raid / Mythic+ split), so
-- the scraped rows sit under the hero/context wildcards and yield one tab. Rows
-- carry the drop location Wowhead prints in its Source column.
function ns:GetWowheadGearSpecData(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("wowhead", classToken, specKey)
    local slots = sd and sd.gear and sd.gear["all"] and sd.gear["all"]["all"]
    if not slots then return nil end
    local out = {}
    for _, g in ipairs(slots) do
        out[#out + 1] = { slot = g.slot, item = { itemId = g.itemId, bonusIDs = g.bonusIDs }, source = g.source }
    end
    if #out == 0 then return nil end
    return { bisGear = { { label = WH_GEAR_TAB, slots = out } } }
end

-- True when Wowhead published talent builds for this spec. Wowhead covers only
-- some specs, so the talent-source dropdowns offer it per-spec rather than
-- unconditionally — otherwise picking it would render an empty pane.
function ns:HasWowheadTalents(classToken, specKey)
    if not classToken or not specKey then return false end
    local sd = ns.SourceSpec and ns.SourceSpec("wowhead", classToken, specKey)
    return (sd and sd.talents) ~= nil
end

-- Archon splits its data by zone type, so it yields the same two tabs u.gg does
-- (Mythic+ / Raid) rather than Wowhead's single table. Rows additionally carry
-- popularity / maxKey / dps, which no other source publishes; they ride along on
-- the row and the renderer shows them where there's room.
--
-- Raid rows are thin early in a tier (archon had ~200 raid parses per spec versus
-- ~20k for M+ on 2026-08-15), so a context can legitimately be missing. Skip an
-- empty context rather than emitting an empty tab.
local ARCHON_CONTEXT_TAB = { mplus = "Mythic+", raid = "Raid" }

-- How many of a slot a character can wear. Archon publishes ~12 popularity-ranked
-- alternatives per slot (168 rows for one Holy Paladin tab), laid out as the
-- equipped set first and then the alternatives grouped by slot. The BiS section
-- shows one row per slot for every other source, and Sections/Gear.lua caps at
-- 20 rows — so the raw list rendered the 16 correct picks followed by an
-- arbitrary four alternatives for whichever slot came next, then stopped. Taking
-- the first occurrence of each slot (they arrive best-first) gives the equipped
-- set: 15-16 rows on all 80 archon tabs, which is what "Best in Slot" means.
--
-- The alternatives are still in the data if a future surface wants to rank them.
local function ArchonSlotAllowance(slot)
    local s = slot:lower()
    if s:find("ring") or s:find("finger") or s:find("trinket") then return 2 end
    return 1
end

function ns:GetArchonGearSpecData(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("archongg", classToken, specKey)
    if not sd then return nil end
    local bisGear = {}
    for _, ctx in ipairs({ "mplus", "raid" }) do
        local slots = ns.ResolveCategory(sd.gear, "all", ctx)
        if slots and #slots > 0 then
            local out, taken = {}, {}
            for _, g in ipairs(slots) do
                local n = taken[g.slot] or 0
                if n < ArchonSlotAllowance(g.slot) then
                    taken[g.slot] = n + 1
                    out[#out + 1] = {
                        slot = g.slot,
                        item = { itemId = g.itemId },
                        source = g.source,
                        popularity = g.popularity,
                        maxKey = g.maxKey,
                        dps = g.dps,
                    }
                end
            end
            bisGear[#bisGear + 1] = { label = ARCHON_CONTEXT_TAB[ctx], slots = out, context = ctx }
        end
    end
    if #bisGear == 0 then return nil end
    return { bisGear = bisGear }
end

-- True when Archon published talent builds for this spec.
function ns:HasArchonTalents(classToken, specKey)
    if not classToken or not specKey then return false end
    local sd = ns.SourceSpec and ns.SourceSpec("archongg", classToken, specKey)
    return (sd and sd.talents) ~= nil
end


-- Wowhead stores hero talents as URL slugs ("sanlayn", "rider-of-the-apocalypse")
-- but every renderer keys on the display name ("San'layn", "Rider of the
-- Apocalypse") — that's what HERO_TALENT_ATLAS is keyed by, so a slug renders
-- without its icon. Rather than hand-maintain a second table that would drift
-- every time a hero talent is added, derive the mapping from the atlas table:
-- strip both sides down to bare letters and match. "San'layn" -> "sanlayn"
-- matches the slug exactly; "Rider of the Apocalypse" -> "rideroftheapocalypse"
-- matches "rider-of-the-apocalypse" once its hyphens are stripped.
local heroDisplayBySlug = nil
local function HeroDisplayName(slug)
    -- A page with no hero markers falls back to the hero key "all". Normalise it
    -- to "All" here: nothing in the atlas strips to "all", so it would otherwise
    -- pass through verbatim and FormatHeroHeaderText — which maps only the exact
    -- string "All" to "General" — would print a group header reading "all".
    if not slug or slug == "" or slug == "all" then return "All" end
    if not heroDisplayBySlug then
        heroDisplayBySlug = {}
        local atlas = ns.HERO_TALENT_ATLAS
        if atlas then
            for display in pairs(atlas) do
                heroDisplayBySlug[display:lower():gsub("[^%a]", "")] = display
            end
        end
    end
    return heroDisplayBySlug[slug:lower():gsub("[^%a]", "")] or slug
end

local WH_CONTEXT_DISPLAY = { raid = "Raid", mplus = "Mythic+", delves = "Delves" }

-- Wowhead talent builds for a spec, in the canonical shape every talent renderer
-- consumes (see Shared/TalentBuildList.lua):
--   { { heroTalent = "Deathbringer", context = "Raid", buildLabel = "Raid",
--       exportString = "C..." }, ... }
-- Wowhead groups builds by hero talent, which is exactly the hero dimension the
-- data seam nests on, so nothing has to be reshaped beyond naming.
function ns:GetWowheadTalentBuilds(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("wowhead", classToken, specKey)
    local talents = sd and sd.talents
    if not talents then return nil end
    local out = {}
    for hero, byContext in pairs(talents) do
        for context, builds in pairs(byContext) do
            for _, b in ipairs(builds) do
                if b.export and b.export ~= "" then
                    -- Builds whose Wowhead label didn't map to a known context are
                    -- stored under a slugified key ("rider-m-delves"). Showing that
                    -- slug next to the label would read "rider-m-delves — Rider
                    -- M+/Delves", so fall the display context back to the label
                    -- itself: FormatBuildLabel drops the context when the label
                    -- already conveys it, leaving just "Rider M+/Delves".
                    out[#out + 1] = {
                        heroTalent   = HeroDisplayName(hero),
                        context      = WH_CONTEXT_DISPLAY[context] or b.label or context,
                        buildLabel   = b.label or WH_CONTEXT_DISPLAY[context] or context,
                        exportString = b.export,
                        -- Wowhead's "Current Recommendations" marker, carried as
                        -- the page's own tag text ("Best", "Best ST", "Best
                        -- Cleave"). FormatBuildLabel prints it verbatim.
                        recommended  = b.recommended,
                        _heroSlug    = hero,
                        _contextKey  = context,
                    }
                end
            end
        end
    end
    if #out == 0 then return nil end
    -- pairs() order is undefined; sort so the pane doesn't reshuffle per render.
    table.sort(out, function(a, b)
        if a._heroSlug ~= b._heroSlug then return a._heroSlug < b._heroSlug end
        return a._contextKey < b._contextKey
    end)
    return out
end

-- Archon talent builds, same canonical shape as the Wowhead ones above.
--
-- Archon ships a real Blizzard loadout string per build (its own
-- `exportCodeParams.exportCode`, stored here as `export`), so these need no
-- encoding — they flow through ParseExportString like every other source.
--
-- Archon labels its builds "Recommended Class Tree" / "Alternative Class Tree #N".
-- Those are kept verbatim, per the standing rule on unmapped labels, and the
-- context supplies the Mythic+ / Raid split. Each build also carries a
-- popularity share, which no other source publishes.
local ARCHON_CONTEXT_DISPLAY = { raid = "Raid", mplus = "Mythic+" }

function ns:GetArchonTalentBuilds(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("archongg", classToken, specKey)
    local talents = sd and sd.talents
    if not talents then return nil end
    local out = {}
    for hero, byContext in pairs(talents) do
        for context, builds in pairs(byContext) do
            for i, b in ipairs(builds) do
                if b.export and b.export ~= "" then
                    out[#out + 1] = {
                        heroTalent   = HeroDisplayName(hero),
                        context      = ARCHON_CONTEXT_DISPLAY[context] or context,
                        buildLabel   = b.label or ARCHON_CONTEXT_DISPLAY[context] or context,
                        exportString = b.export,
                        _heroSlug    = hero,
                        _contextKey  = context,
                        _popularity  = b.popularity,
                        _order       = i,
                    }
                end
            end
        end
    end
    if #out == 0 then return nil end
    -- pairs() order is undefined; sort so the pane doesn't reshuffle per render.
    -- Within a hero+context the scraper already emitted the recommended build
    -- first, so preserve that order rather than sorting by label.
    table.sort(out, function(a, b)
        if a._heroSlug ~= b._heroSlug then return a._heroSlug < b._heroSlug end
        if a._contextKey ~= b._contextKey then return a._contextKey < b._contextKey end
        return a._order < b._order
    end)
    return out
end

-- Wowhead enchants / gems / consumables for a spec, in the shapes the
-- Enhancements section already consumes.
--
-- Wowhead publishes the enchanting *scroll item* rather than u.gg's
-- enchantId+spellId pair. That's the more useful identifier here: an itemId
-- resolves through the existing item cache to a real name and icon, so these
-- rows render as "Enchant Weapon - Acuity of the Ren'dorei" with artwork rather
-- than a bare id or a name-only string. Every value is therefore { itemId = N }
-- and the renderers need no special-casing.
function ns:GetWowheadEnhancements(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("wowhead", classToken, specKey)
    if not sd then return nil end
    local out = {}

    local e = sd.enchants and sd.enchants["all"] and sd.enchants["all"]["all"]
    if e then
        local rows = {}
        for slot, list in pairs(e) do
            local first = list and list[1]
            if first and first.itemId then
                rows[#rows + 1] = { slot = slot, best = { itemId = first.itemId } }
            end
        end
        -- pairs() order is undefined; sort by slot so the list is stable between
        -- renders rather than reshuffling every repaint.
        table.sort(rows, function(a, b) return a.slot < b.slot end)
        if #rows > 0 then out.enchants = rows end
    end

    local gm = sd.gems and sd.gems["all"] and sd.gems["all"]["all"]
    local g = gm and gm[1]
    if g and g.primary then
        local secondary = nil
        if g.secondary then
            secondary = {}
            for _, id in ipairs(g.secondary) do secondary[#secondary + 1] = { itemId = id } end
            if #secondary == 0 then secondary = nil end
        end
        out.gems = { primary = { itemId = g.primary }, secondary = secondary }
    end

    local c = sd.consumables and sd.consumables["all"] and sd.consumables["all"]["all"]
    if c then
        local function top(l) return l and l[1] and { itemId = l[1] } or nil end
        -- The UI's key names differ from the data's: it renders combatPotion and
        -- weaponBuff, the scrape stores potions and weaponBuff.
        out.consumables = {
            flask        = top(c.flask),
            combatPotion = top(c.potions),
            healthPotion = top(c.healthPotion),
            food         = top(c.food),
            weaponBuff   = top(c.weaponBuff),
            augmentRune  = top(c.augmentRune),
        }
    end

    if not next(out) then return nil end
    return out
end


-- Archon enchants / gems / consumables, in the same shapes the Enhancements
-- section consumes. The one structural difference from Wowhead is that Archon
-- splits these by zone type, so they resolve against a context rather than the
-- "all" wildcard: prefer Mythic+ (the context with real sample sizes) and fall
-- back to Raid. Archon publishes enchanting *scroll item ids*, the same
-- representation Wowhead uses, so no translation is needed.
function ns:GetArchonEnhancements(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("archongg", classToken, specKey)
    if not sd then return nil end
    local out = {}

    local function resolve(cat)
        if not cat then return nil end
        return ns.ResolveCategory(cat, "all", "mplus") or ns.ResolveCategory(cat, "all", "raid")
    end

    local e = resolve(sd.enchants)
    if e then
        local rows = {}
        for slot, list in pairs(e) do
            local first = list and list[1]
            if first and first.itemId then
                rows[#rows + 1] = { slot = slot, best = { itemId = first.itemId } }
            end
        end
        table.sort(rows, function(a, b) return a.slot < b.slot end)
        if #rows > 0 then out.enchants = rows end
    end

    local gm = resolve(sd.gems)
    local g = gm and gm[1]
    if g and g.primary then
        local secondary = nil
        if g.secondary then
            secondary = {}
            for _, id in ipairs(g.secondary) do secondary[#secondary + 1] = { itemId = id } end
            if #secondary == 0 then secondary = nil end
        end
        out.gems = { primary = { itemId = g.primary }, secondary = secondary }
    end

    local c = resolve(sd.consumables)
    if c then
        local function top(l) return l and l[1] and { itemId = l[1] } or nil end
        out.consumables = {
            flask        = top(c.flask),
            combatPotion = top(c.potions),
            healthPotion = top(c.healthPotion),
            food         = top(c.food),
            weaponBuff   = top(c.weaponBuff),
            augmentRune  = top(c.augmentRune),
        }
    end

    if not next(out) then return nil end
    return out
end

-- Wowhead's rotation for a spec, as the Rotation section's { steps = {...} }.
-- Wowhead publishes one undivided priority list per spec (no hero/context split),
-- so it lands on the wildcards and yields a single context.
function ns:GetWowheadRotation(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("wowhead", classToken, specKey)
    local r = sd and sd.rotation and sd.rotation["all"] and sd.rotation["all"]["all"]
    if not r or not r.steps or #r.steps == 0 then return nil end
    return { steps = r.steps }
end

-- itemId -> acquisition source ("Ula'tek", "The Coiled Altar", ...), harvested
-- once from every Wowhead spec list. This is what the BiS Source column falls
-- back to when the active source publishes no drop location of its own — u.gg
-- ranks by popularity, not acquisition, so its rows arrive without one.
-- Built lazily and memoised; nil-safe when db_wowhead.lua isn't installed.
local wowheadSourceIndex = nil
function ns:GetWowheadSourceIndex()
    if wowheadSourceIndex then return wowheadSourceIndex end
    local idx = {}
    local src = ClassCodexSource and ClassCodexSource["wowhead"]
    local data = src and src.data
    if data then
        for _, byClass in pairs(data) do
            for _, spec in pairs(byClass) do
                local slots = spec.gear and spec.gear["all"] and spec.gear["all"]["all"]
                if slots then
                    for _, g in ipairs(slots) do
                        local id, source = g.itemId, g.source
                        if id and source and source ~= "" and not idx[id] then
                            idx[id] = source
                        end
                    end
                end
            end
        end
    end
    wowheadSourceIndex = idx
    return idx
end

-- u.gg's Gear Overview lists items in slot order but never names the slot,
-- so we recover a display label from each item's equip location. English
-- labels keep it consistent with the u.gg / Icy Veins sources, whose slot
-- strings are also raw English from their guides.
local EQUIPLOC_SLOT = {
    INVTYPE_HEAD = "Head",
    INVTYPE_NECK = "Neck",
    INVTYPE_SHOULDER = "Shoulders",
    INVTYPE_CLOAK = "Cloak",
    INVTYPE_CHEST = "Chest",
    INVTYPE_ROBE = "Chest",
    INVTYPE_WRIST = "Wrist",
    INVTYPE_HAND = "Gloves",
    INVTYPE_WAIST = "Belt",
    INVTYPE_LEGS = "Legs",
    INVTYPE_FEET = "Feet",
    INVTYPE_FINGER = "Ring",
    INVTYPE_TRINKET = "Trinket",
    INVTYPE_WEAPON = "Weapon",
    INVTYPE_2HWEAPON = "Weapon",
    INVTYPE_WEAPONMAINHAND = "Main Hand",
    INVTYPE_WEAPONOFFHAND = "Off Hand",
    INVTYPE_HOLDABLE = "Off Hand",
    INVTYPE_SHIELD = "Off Hand",
    INVTYPE_RANGED = "Weapon",
    INVTYPE_RANGEDRIGHT = "Weapon",
}

function ns.GearSlotName(itemId)
    if not itemId then return "" end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemId)
    return (equipLoc and EQUIPLOC_SLOT[equipLoc]) or ""
end

local IV_TALENT_CTX = { raid = "Raid", mplus = "Mythic+", delve = "Delves", leveling = "Leveling", all = "General" }
function ns:GetIcyVeinsTalentSpecData(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("icyveins", classToken, specKey)
    local byContext = sd and sd.talents and sd.talents["all"] -- IV is hero-agnostic
    if not byContext then return nil end
    -- Fixed context order so talents[1] is a sensible default (single-target first).
    local talents = {}
    for _, ctx in ipairs({ "raid", "mplus", "delve", "all", "leveling" }) do
        local builds = byContext[ctx]
        if builds then
            for _, b in ipairs(builds) do
                talents[#talents + 1] = {
                    buildLabel = b.label,
                    exportString = b.export,
                    context = IV_TALENT_CTX[ctx] or ctx,
                    leveling = (ctx == "leveling") or nil,
                }
            end
        end
    end
    if #talents == 0 then return nil end
    return { talents = talents }
end

function ns:GetTrinketSpecs(itemId)
    local raw = trinketLookup[itemId]
    if not raw then return nil end
    return ConsolidateByClass(raw)
end

-------------------------------------------------------------------------------
-- Item Icon Helper
-------------------------------------------------------------------------------

local ICON_SIZE = 16

local function GetItemIcon(itemId)
    local cached = itemCache[itemId]
    if cached and cached.icon then return cached.icon end
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
    return icon
end

local function CreateRowIcon(row)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", 2, 0)
    icon:Hide()
    row.icon = icon
    return icon
end

local function GetSpellIcon(spellId)
    if not spellId then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellId)
        if info and info.iconID then return info.iconID end
    end
    return nil
end

local function SetRowIcon(row, itemId, spellId)
    if not row.icon then return end
    local tex = GetSpellIcon(spellId) or GetItemIcon(itemId)
    if tex then
        row.icon:SetTexture(tex)
        row.icon:Show()
    else
        row.icon:Hide()
    end
end

-- GetItemCount sees bags + bank + reagent bank + warbank (with the 5th
-- arg) but NOT equipment slots, so we need the IsEquippedItem
-- short-circuit. Returns false when the user has opted out via the
-- "Highlight Owned Gear" setting.
local function IsItemOwned(itemId)
    if not itemId then return false end
    if ClassCodexDB and ClassCodexDB.highlightOwnedGear == false then return false end
    if IsEquippedItem and IsEquippedItem(itemId) then return true end
    return (GetItemCount(itemId, true, false, true, true) or 0) > 0
end

-------------------------------------------------------------------------------
-- Item Tooltip Helper
-------------------------------------------------------------------------------

local function GetItemLink(itemId)
    local _, link = C_Item.GetItemInfo(itemId)
    return link
end

local function HandleItemClick(self)
    if not self.itemId then return end
    local link = GetItemLink(self.itemId)
    if not link then return end
    if IsModifiedClick("CHATLINK") then
        ChatEdit_InsertLink(link)
    elseif IsModifiedClick("DRESSUP") then
        DressUpItemLink(link)
    end
end

local function SetupItemTooltip(row)
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", HandleItemClick)
    row:SetScript("OnEnter", function(self)
        if self.spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellId)
            GameTooltip:Show()
        elseif self.itemId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.bonusIDs and #self.bonusIDs > 0 then
                local bonusStr = #self.bonusIDs .. ":" .. table.concat(self.bonusIDs, ":")
                local link = format("item:%d::::::::::::%s", self.itemId, bonusStr)
                local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
                if not ok then GameTooltip:SetItemByID(self.itemId) end
            else
                GameTooltip:SetItemByID(self.itemId)
            end
            if self.altItemId then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine((L and L["gear.tooltip.alternative"]) or "Alternative:", 0.6, 0.6, 0.6)
                local altRef = { itemId = self.altItemId, name = self.altName or "" }
                GameTooltip:AddLine("  " .. FormatItem(altRef))
            end
            if self.embItemId then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine((L and L["gear.tooltip.embellishment"]) or "Embellishment:", 0.6, 0.6, 0.6)
                local embRef = { itemId = self.embItemId, name = self.embName or "" }
                GameTooltip:AddLine("  " .. FormatItem(embRef))
            end
            if self.sourceText then
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(SOURCE or "Source", self.sourceText, 0.5, 0.5, 0.5, 1, 0.82, 0)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-------------------------------------------------------------------------------
-- Export everything Sections/* and the panel dispatcher need on `ns`.
-------------------------------------------------------------------------------
ns.FormatItem = FormatItem
ns.IsItemOwned = IsItemOwned
ns.CreateRowIcon = CreateRowIcon
ns.SetRowIcon = SetRowIcon
ns.GetSpellIcon = GetSpellIcon
ns.SetupItemTooltip = SetupItemTooltip
ns.GetItemIcon = GetItemIcon
ns.GetItemName = GetItemName
ns.HandleItemClick = HandleItemClick
ns.RequestItemData = RequestItemData
ns.RequestAllItems = RequestAllItems
ns.RequestEnhancementItems = RequestEnhancementItems
ns.GetSpecGearData = GetSpecGearData
ns.GetPlayerClassSpec = GetPlayerClassSpec
ns.GearingPvP = PvP
ns.TIER_COLORS = TIER_COLORS
ns.TIER_ORDER = TIER_ORDER
ns.CONTEXT_LABELS = CONTEXT_LABELS
ns.CONSUMABLE_ORDER = CONSUMABLE_ORDER
ns.CONSUMABLE_LABELS = CONSUMABLE_LABELS
ns.ICON_SIZE_GEAR = ICON_SIZE

-- Right-aligned source/drop column: grow to fit its text (up to `cap`) but never
-- so wide that the name column to its left drops below `nameMin`. On a wide pane
-- the full source shows; on a narrow one it caps and ellipsizes as before.
-- `leftCols` = width consumed left of the name (slot/tier + icon + gaps + pad).
function ns.SizeSourceColumn(fs, rowWidth, leftCols, nameMin, cap)
    local content = math.ceil(fs:GetStringWidth()) + 2
    local maxByName = (rowWidth and rowWidth > 0)
        and math.max(20, rowWidth - leftCols - nameMin)
        or content
    fs:SetWidth(math.max(1, math.min(content, maxByName, cap or 300)))
end
ns.MAX_ENCHANT_ROWS = MAX_ENCHANT_ROWS
ns.MAX_GEM_ROWS = MAX_GEM_ROWS
ns.MAX_CONSUMABLE_ROWS = MAX_CONSUMABLE_ROWS

-- Build the item -> specs reverse lookups now that the source accessors above exist.
BuildBisLookup()
