local _, ns = ...

local L = ns.L

local TIER_COLORS = {
    S = { r = 1.00, g = 0.50, b = 0.00 },
    A = { r = 0.64, g = 0.21, b = 0.93 },
    B = { r = 0.00, g = 0.44, b = 0.87 },
    C = { r = 0.12, g = 1.00, b = 0.00 },
    D = { r = 0.62, g = 0.62, b = 0.62 },
}

local TIER_ORDER = { S = 1, A = 2, B = 3, C = 4, D = 5 }

local CONTEXT_LABELS = {
    raid = L["context.raid"],
    dungeon = L["context.dungeon"],
    delves = L["context.delves"],
    crafting = L["context.crafting"],
}

local CONSUMABLE_ORDER = { "flask", "combatPotion", "food", "weaponBuff", "augmentRune" }
local CONSUMABLE_LABELS = {
    flask = L["consumable.flask"],
    combatPotion = L["consumable.combat_potion"],
    food = L["consumable.food"],
    weaponBuff = L["consumable.weapon_buff"],
    augmentRune = L["consumable.augment_rune"],
}

local MAX_ENCHANT_ROWS = 12
local MAX_GEM_ROWS = 4
local MAX_CONSUMABLE_ROWS = 6

local RequestItemData = ns.RequestItemData
local gearingDirty = false

local function GetItemName(itemRef)
    if not itemRef then return "" end

    if itemRef.spellId then
        if C_Spell and C_Spell.GetSpellName then
            local name = C_Spell.GetSpellName(itemRef.spellId)
            if name then return name end
        elseif GetSpellInfo then
            local name = GetSpellInfo(itemRef.spellId)
            if name then return name end
        end
    end
    local cached = ns.GetCachedItem(itemRef.itemId)
    if cached and cached.name then return cached.name end
    if itemRef.name and itemRef.name ~= "" then return itemRef.name end
    if itemRef.spellId then return "Spell " .. itemRef.spellId end
    return "Item " .. itemRef.itemId
end

local function GetItemQuality(itemId)
    local cached = ns.GetCachedItem(itemId)
    return cached and cached.quality or nil
end

-- Quality must reflect the row's bonus ids: M+ and upgrade-track loot renders
-- purple from its bonuses while the base item is blue. Ask the client for the
-- exact combo via a bare item string (same layout BuildItemLink emits); base
-- quality stays the fallback for combos the client hasn't cached yet — rows
-- re-render once the item data lands.
local function GetItemQualityWithBonuses(itemRef)
    local itemId = itemRef and itemRef.itemId
    local bonusIDs = itemRef and itemRef.bonusIDs
    if itemId and bonusIDs and #bonusIDs > 0 then
        local s = "item:" .. itemId .. "::::::::::::" .. #bonusIDs .. ":" .. table.concat(bonusIDs, ":")
        return select(3, GetItemInfo(s)) or GetItemQuality(itemId)
    end
    return GetItemQuality(itemId)
end

local function FormatItem(itemRef, nameOverride)
    if not itemRef then return "" end
    local name = nameOverride or GetItemName(itemRef)
    return ns.FormatItemLabel(name, GetItemQualityWithBonuses(itemRef))
end

ns.OnItemLoaded(function()
    if gearingDirty then return end
    gearingDirty = true
    C_Timer.After(0.1, function()
        gearingDirty = false
        if ns.panel and ns.panel:IsShown() then
            ns:UpdateGearingSections()
            ns:LayoutPanel()
        end
    end)
end)

local function RequestAllItems(gearData)
    if not gearData then return end
    if gearData.enchants then
        for _, e in ipairs(gearData.enchants) do
            if e.best and e.best.itemId then RequestItemData(e.best.itemId) end
            if e.alternate and e.alternate.itemId then RequestItemData(e.alternate.itemId) end
        end
    end
    if gearData.gems then
        if gearData.gems.primary then RequestItemData(gearData.gems.primary.itemId) end
        if gearData.gems.secondary then
            for _, g in ipairs(gearData.gems.secondary) do
                RequestItemData(g.itemId)
            end
        end
    end
    if gearData.consumables then
        for _, key in ipairs(CONSUMABLE_ORDER) do
            if gearData.consumables[key] then RequestItemData(gearData.consumables[key].itemId) end
        end
    end
    if gearData.trinkets then
        for _, t in ipairs(gearData.trinkets) do
            RequestItemData(t.itemId)
        end
    end

    local craftClassToken, craftSpec = ns.GetPlayerClassSpec()
    ns.Sections.Crafting.RequestItems(craftClassToken, craftSpec, RequestItemData)
    if gearData.bisGear then
        for _, tab in ipairs(gearData.bisGear) do
            for _, g in ipairs(tab.slots) do
                RequestItemData(g.item.itemId)
                if g.item.catalyst then RequestItemData(g.item.catalyst.itemId) end
            end
        end
    end
end

-- PvP items carry bonus ids that set their PvP item level. Icy Veins' pages
-- only mark some items with them, but u.gg's PvP gear lists carry them for
-- every slot — borrow by item id when the active source's entry lacks them.
-- (No structural fallback: the per-track bonus lists share no common core, so
-- an unlisted item's bonuses are genuinely unknown.)
local pvpBonusByItem
local function PvpItemBonusIds(itemId)
    if not itemId then return nil end
    if pvpBonusByItem == nil then
        pvpBonusByItem = {}
        local data = ClassCodexSource and ClassCodexSource.ugg
        data = data and data.data
        if type(data) == "table" then
            for _, specs in pairs(data) do
                for _, sd in pairs(specs) do
                    local items = sd.gear and sd.gear.all and sd.gear.all.pvp
                    if type(items) == "table" then
                        for _, g in ipairs(items) do
                            if g.itemId and g.bonusIDs and #g.bonusIDs > 0 and pvpBonusByItem[g.itemId] == nil then
                                pvpBonusByItem[g.itemId] = g.bonusIDs
                            end
                        end
                    end
                end
            end
        end
    end
    return pvpBonusByItem[itemId]
end
ns.PvpItemBonusIds = PvpItemBonusIds

local function GetSpecGearData(classToken, specKey, trinketSourceOverride, contentOverride)
    if not (classToken and specKey) then
        classToken, specKey = ns.GetClassAndSpec()
    end
    if not classToken or not specKey then return nil end
    local out = {}

    local content = contentOverride or (ns.Context and ns.Context.contentType())
    local ctxKey = (content == "pvp") and "pvp" or "all"
    local source = trinketSourceOverride or (ns.ActiveSource and ns.ActiveSource()) or "icyveins"
    local sd = ns.SourceSpec and ns.SourceSpec(source, classToken, specKey)
    -- A spec with no PvP guide on the active source shows the dedicated empty
    -- screen — no borrowed or PvE data under PvP content.
    if ctxKey == "pvp" and sd and ns.HasPvpGuide and not ns.HasPvpGuide(source, classToken, specKey) then sd = nil end

    if sd then
        local tr = sd.trinkets and ns.ResolveCategory(sd.trinkets, "all", ctxKey)
        if tr then
            local list = {}
            for _, t in ipairs(tr) do
                local bonuses = t.bonusIDs or (ctxKey == "pvp" and PvpItemBonusIds(t.itemId)) or nil
                list[#list + 1] = { itemId = t.itemId, tier = t.tier or "S", popularity = t.pop, bonusIDs = bonuses }
            end
            out.trinkets = list
        end

        local gm = sd.gems and ns.ResolveCategory(sd.gems, "all", ctxKey)
        if not gm and ctxKey ~= "all" and sd.gems then gm = ns.ResolveCategory(sd.gems, "all", "all") end
        if gm and gm[1] then
            local secondary = {}
            for _, id in ipairs(gm[1].secondary or {}) do
                secondary[#secondary + 1] = { itemId = id }
            end
            out.gems = { primary = gm[1].primary and { itemId = gm[1].primary } or nil, secondary = secondary }
        end

        -- Consumables: PvP content falls back to the source's PvE set, then to
        -- Icy Veins (u.gg publishes no consumables at all).
        local c = sd.consumables and ns.ResolveCategory(sd.consumables, "all", ctxKey)
        if not c and ctxKey ~= "all" and sd.consumables then c = ns.ResolveCategory(sd.consumables, "all", "all") end
        if not c and source ~= "icyveins" then
            local ivSd = ns.SourceSpec and ns.SourceSpec("icyveins", classToken, specKey)
            if ivSd and ivSd.consumables then
                c = ns.ResolveCategory(ivSd.consumables, "all", ctxKey)
                    or ns.ResolveCategory(ivSd.consumables, "all", "all")
            end
        end
        if c then
            local function top(l)
                return l and l[1] and { itemId = l[1] } or nil
            end
            out.consumables = {
                flask = top(c.flask),
                combatPotion = top(c.potions),
                food = top(c.food),
                augmentRune = top(c.augmentRune),
            }
        end

        -- Resolve enchants for the active content first, then the aggregate set.
        local ench = sd.enchants and ns.ResolveCategory(sd.enchants, "all", ctxKey)
        if not ench and ctxKey ~= "all" and sd.enchants then ench = ns.ResolveCategory(sd.enchants, "all", "all") end
        if ench then
            local list = {}
            local function mk(e)
                if not e then return nil end
                if e.spellId then
                    local mapped = ClassCodexGameData
                        and ClassCodexGameData.enchants
                        and ClassCodexGameData.enchants[e.spellId]
                    return { enchantId = e.id, itemId = mapped, spellId = e.spellId, pop = e.pop }
                end
                return { itemId = e.id, pop = e.pop }
            end
            for slot, entries in pairs(ench) do
                if entries[1] then
                    list[#list + 1] = { slot = slot, best = mk(entries[1]), alternate = mk(entries[2]) }
                end
            end
            if #list > 0 then out.enchants = list end
        end
    end

    local bis = ns.GetBisGearData and ns.GetBisGearData(source, classToken, specKey)
    if bis then out.bisGear = bis.bisGear end
    if not next(out) then return nil end
    return out
end

local function GetPlayerClassSpec()
    local classToken = select(2, UnitClass("player"))
    local specKey = ns.GetSpecKey()
    if not classToken or not specKey then return nil, nil end
    local spec = specKey:match("-(.+)") or specKey
    return classToken, spec
end

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

local SPEC_KEYS_BY_CLASS = {
    DEATHKNIGHT = { "blood", "frost", "unholy" },
    DEMONHUNTER = { "havoc", "vengeance", "devourer" },
    DRUID = { "balance", "feral", "guardian", "restoration" },
    EVOKER = { "devastation", "preservation", "augmentation" },
    HUNTER = { "beast-mastery", "marksmanship", "survival" },
    MAGE = { "arcane", "fire", "frost" },
    MONK = { "brewmaster", "mistweaver", "windwalker" },
    PALADIN = { "holy", "protection", "retribution" },
    PRIEST = { "discipline", "holy", "shadow" },
    ROGUE = { "assassination", "outlaw", "subtlety" },
    SHAMAN = { "elemental", "enhancement", "restoration" },
    WARLOCK = { "affliction", "demonology", "destruction" },
    WARRIOR = { "arms", "fury", "protection" },
}

local CLASS_ID_BY_TOKEN = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    MONK = 10,
    DRUID = 11,
    DEMONHUNTER = 12,
    EVOKER = 13,
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
            if k == specKey then
                specIndex = i
                break
            end
        end
    end
    if classID and specIndex and GetSpecializationInfoForClassID then
        local _, name = GetSpecializationInfoForClassID(classID, specIndex)
        if name and name ~= "" then result = name end
    end
    if not result then result = specKey:sub(1, 1):upper() .. specKey:sub(2) end
    localizedSpecNameCache[cacheKey] = result
    return result
end

local CLASS_SPEC_COUNT = {}

-- Numeric (classID, specID) for the EJ loot filter, off the addon's
-- classToken + specKey. Positional lookup assumes the game's spec order
-- matches our key order — not always true (DH's third spec) — so match by
-- localized name first (order-independent, like QUI's ej_lootspecs), with
-- position as fallback. specID nil when nothing resolves; callers then
-- leave the journal's filter alone.
function ns.GetSpecIDForKeys(classToken, specKey)
    local classID = CLASS_ID_BY_TOKEN[classToken]
    if not classID then return nil, nil end
    if not (specKey and GetSpecializationInfoForClassID) then return classID, nil end

    local keys = SPEC_KEYS_BY_CLASS[classToken]
    local wantIndex
    if keys then
        for i, k in ipairs(keys) do
            if k == specKey then
                wantIndex = i
                break
            end
        end
    end
    local wantName = GetLocalizedSpecName(classToken, specKey)

    local numSpecs = (
        C_SpecializationInfo
        and C_SpecializationInfo.GetNumSpecializationsForClassID
        and C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
    ) or 0
    if numSpecs > 0 then
        for i = 1, numSpecs do
            local id, name = GetSpecializationInfoForClassID(classID, i)
            if id and name and name == wantName then return classID, id end
            if id and wantIndex == i then return classID, id end
        end
    elseif wantIndex then
        local id = GetSpecializationInfoForClassID(classID, wantIndex)
        if id then return classID, id end
    end
    return classID, nil
end

local uggBisLookup = {}
local icyVeinsBisLookup = {}
local trinketLookup = {}
local trinketSourceLookup = {}

local bonusIdLookup = {}

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

local function eachSourceSpec(fn)
    local src = ClassCodexSource
    if not src then return end
    local seen = {}
    for _, source in ipairs({ "icyveins", "ugg" }) do
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

        local usd = ns.SourceSpec and ns.SourceSpec("ugg", classToken, specKey)
        local ivd = ns.SourceSpec and ns.SourceSpec("icyveins", classToken, specKey)
        local tr = usd and usd.trinkets and usd.trinkets["all"] and usd.trinkets["all"]["all"]
        local ivTr = ivd and ivd.trinkets and ivd.trinkets["all"] and ivd.trinkets["all"]["all"]

        if tr or ivTr then
            -- itemId -> { ugg = tier, iv = tier }, first-listed tier per source wins
            local tiers = {}
            for _, t in ipairs(tr or {}) do
                tiers[t.itemId] = tiers[t.itemId] or {}
                if not tiers[t.itemId].ugg then tiers[t.itemId].ugg = t.tier end
            end
            for _, t in ipairs(ivTr or {}) do
                tiers[t.itemId] = tiers[t.itemId] or {}
                if not tiers[t.itemId].iv then tiers[t.itemId].iv = t.tier end
            end
            for id, pair in pairs(tiers) do
                trinketLookup[id] = trinketLookup[id] or {}
                local list = trinketLookup[id]
                local existing
                for _, e in ipairs(list) do
                    if e.label == label then
                        existing = e
                        break
                    end
                end
                if existing then
                    existing.tier = existing.tier or pair.ugg
                    existing.ivTier = existing.ivTier or pair.iv
                else
                    list[#list + 1] =
                        { label = label, class = classToken, spec = specKey, tier = pair.ugg, ivTier = pair.iv }
                end
            end
        end

        local trinketIds = {}
        for _, t in ipairs(tr or {}) do
            trinketIds[t.itemId] = true
        end
        for _, t in ipairs(ivTr or {}) do
            trinketIds[t.itemId] = true
        end

        local uggGear = ns.GetBisGearData and ns.GetBisGearData("ugg", classToken, specKey)
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

        local ivGear = ns.GetBisGearData and ns.GetBisGearData("icyveins", classToken, specKey)
        if ivGear and ivGear.bisGear then
            for _, tab in ipairs(ivGear.bisGear) do
                for _, entry in ipairs(tab.slots) do
                    local id = entry.item.itemId
                    if entry.item.bonusIDs and not bonusIdLookup[id] then bonusIdLookup[id] = entry.item.bonusIDs end
                    if
                        id
                        and entry.source
                        and entry.source ~= ""
                        and not trinketSourceLookup[id]
                        and entry.slot
                        and entry.slot:lower():find("trinket")
                    then
                        trinketSourceLookup[id] = entry.source
                    end
                    icyVeinsBisLookup[id] = icyVeinsBisLookup[id] or {}
                    local found = false
                    for _, existing in ipairs(icyVeinsBisLookup[id]) do
                        if existing.label == label then
                            existing.tabs[#existing.tabs + 1] = tab.label
                            found = true
                            break
                        end
                    end
                    if not found then
                        icyVeinsBisLookup[id][#icyVeinsBisLookup[id] + 1] =
                            { label = label, class = classToken, spec = specKey, tabs = { tab.label } }
                    end
                end
            end
        end
    end)
end

local function TiersEqual(a, b)
    return (a.tier or false) == (b.tier or false) and (a.ivTier or false) == (b.ivTier or false)
end

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
                if not TiersEqual(classEntries[i], classEntries[1]) then
                    sameTier = false
                    break
                end
            end
        end
        if #classEntries >= totalSpecs and totalSpecs > 0 and sameTier then
            result[#result + 1] = {
                label = className,
                class = classToken,
                tier = classEntries[1].tier,
                ivTier = classEntries[1].ivTier,
                consolidated = true,
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

local SLOT_ORDER = {
    ["Head"] = 1,
    ["Neck"] = 2,
    ["Shoulders"] = 3,
    ["Back"] = 4,
    ["Chest"] = 5,
    ["Wrist"] = 6,
    ["Hands"] = 7,
    ["Waist"] = 8,
    ["Legs"] = 9,
    ["Feet"] = 10,
    ["Finger 1"] = 11,
    ["Finger 2"] = 12,
    ["Trinket 1"] = 13,
    ["Trinket 2"] = 14,
    ["Main Hand"] = 15,
    ["Off Hand"] = 16,
}

function ns.SortSlotsCanonical(slots)
    if not slots then return slots end
    table.sort(slots, function(a, b)
        return (SLOT_ORDER[a.slot] or 99) < (SLOT_ORDER[b.slot] or 99)
    end)
    return slots
end

local BIS_GEAR_TAB = { all = "Overall", mplus = "Mythic+", raid = "Raid", pvp = "PvP" }
local BIS_CTX_ORDER = { "all", "mplus", "raid", "pvp" }

function ns.GetBisGearData(source, classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec(source, classToken, specKey)
    if not sd or not sd.gear then return nil end
    local bisGear = {}
    for _, ctx in ipairs(BIS_CTX_ORDER) do
        local slots = ns.ResolveCategory(sd.gear, "all", ctx)
        if slots then
            local out = {}
            for _, g in ipairs(slots) do
                local item = { itemId = g.itemId }
                if g.bonusIDs then
                    item.bonusIDs = g.bonusIDs
                elseif ctx == "pvp" then
                    item.bonusIDs = PvpItemBonusIds(g.itemId)
                end
                if g.catalyst then item.catalyst = g.catalyst end
                local row = { slot = g.slot, item = item }
                if g.source then row.source = g.source end
                if g.pop then row.pop = g.pop end
                out[#out + 1] = row
            end
            bisGear[#bisGear + 1] = { label = BIS_GEAR_TAB[ctx] or ctx, slots = ns.SortSlotsCanonical(out) }
        end
    end
    if #bisGear == 0 then return nil end
    return { bisGear = bisGear }
end

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

local IV_TALENT_CTX =
    { raid = "Raid", mplus = "Mythic+", delve = "Delves", leveling = "Leveling", pvp = "PvP", all = "General" }
function ns:GetIcyVeinsTalentSpecData(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("icyveins", classToken, specKey)
    local byHero = sd and sd.talents
    if not byHero then return nil end

    local heroNames = ClassCodexSource
        and ClassCodexSource.icyveins
        and ClassCodexSource.icyveins.reference
        and ClassCodexSource.icyveins.reference.heroNames
    local talents = {}
    -- The same build fans out to several contexts in the source data (a
    -- "Raid-Cleave" tree is both raid and mplus); flat lists (dock, pane) show
    -- one entry per distinct loadout, so skip re-listing an identical export.
    local seenExports = {}
    for heroKey, byContext in pairs(byHero) do
        local heroDisplay = (heroKey ~= "all") and ((heroNames and heroNames[heroKey]) or heroKey) or nil
        for _, ctx in ipairs({ "raid", "mplus", "delve", "all", "leveling", "pvp" }) do
            local builds = byContext[ctx]
            if builds then
                for _, b in ipairs(builds) do
                    if b.export and not seenExports[b.export] then
                        seenExports[b.export] = true
                        talents[#talents + 1] = {
                            buildLabel = b.label,
                            exportString = b.export,
                            context = IV_TALENT_CTX[ctx] or ctx,
                            leveling = (ctx == "leveling") or nil,
                            heroTalent = heroDisplay,
                            recommended = b.recommended,
                            tags = b.tags,
                            honor = b.honor,
                        }
                    end
                end
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

local ICON_SIZE = 16

local function GetItemIcon(itemId)
    local cached = ns.GetCachedItem(itemId)
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

local function IsItemOwned(itemId)
    if not itemId then return false end
    if ClassCodexDB and ClassCodexDB.highlightOwnedGear == false then return false end
    if IsEquippedItem and IsEquippedItem(itemId) then return true end
    return (GetItemCount(itemId, true, false, true, true) or 0) > 0
end

local function GetItemLink(itemId)
    local _, link = C_Item.GetItemInfo(itemId)
    return link
end

--- The full hyperlink for an item with its bonus-list ids. GetItemInfo's cached
--- link is always the BASE version — without the bonuses a BiS pick renders at
--- its base item level (e.g. 219 instead of the bonus-encoded 344), so chat
--- links and dressing-room previews must be built from the ids directly.
---
--- Field layout mirrors a REAL in-game link: linkLevel (player level) in field
--- 9, trailing colon. sourceItemId (catalyst rows) appends the item modifier
--- the engine itself writes for catalyzed items — "1 modifier, type 64, value
--- = source item id" (captured from a live conversion:
--- item:271540:…:5:1558:…:1:64:272239:) — which is what makes the tooltip
--- apply the conversion's retained source stats.
function ns.BuildItemLink(itemId, bonusIDs, sourceItemId)
    if not itemId then return nil end
    if bonusIDs and #bonusIDs > 0 then
        -- 7 empty fields (enchant, 4 gems, suffix, unique), linkLevel, 3 more
        -- (spec, modifiers mask, itemContext), then the bonus count.
        local bare
        if sourceItemId then
            bare = format(
                "item:%d::::::::%d::::%d:%s:1:64:%d:",
                itemId,
                UnitLevel("player") or MAX_PLAYER_LEVEL,
                #bonusIDs,
                table.concat(bonusIDs, ":"),
                sourceItemId
            )
        else
            bare = format(
                "item:%d::::::::%d::::%d:%s:",
                itemId,
                UnitLevel("player") or MAX_PLAYER_LEVEL,
                #bonusIDs,
                table.concat(bonusIDs, ":")
            )
        end
        -- Prefer the CLIENT's own link for this exact bonus combo: GetItemInfo
        -- on an item string returns the engine-sanctioned hyperlink (correct
        -- color placement, whatever field layout this client build validates
        -- on send). Hand-built links risk "Invalid escape code in chat
        -- message" rejections inside C_ChatInfo.SendChatMessage, which does
        -- no Lua-side validation we could satisfy ourselves.
        local _, link = GetItemInfo(bare)
        if not link then
            C_Item.RequestLoadItemDataByID(itemId)
            _, link = GetItemInfo(bare)
        end
        if link then return link end
        -- Uncached: hand-build as a fallback (color outside the |H…|h pair,
        -- matching real client links) until the item data arrives.
        local name, _, quality = GetItemInfo(itemId)
        if not name then return GetItemLink(itemId) end
        local color = "|cffffffff"
        local ok, r, g, b = pcall(GetItemQualityColor, quality or 1)
        if ok and r then
            color = format(
                "|cff%02x%02x%02x",
                math.floor(r * 255 + 0.5),
                math.floor(g * 255 + 0.5),
                math.floor(b * 255 + 0.5)
            )
        end
        return format("%s|H%s|h[%s]|h|r", color, bare, name:gsub("[%[%]]", ""))
    end
    return GetItemLink(itemId)
end

local function HandleItemClick(self)
    if not self.itemId then return end
    local link = (ns.BuildItemLink and ns.BuildItemLink(self.itemId, self.bonusIDs, self.catalystItemId))
        or GetItemLink(self.itemId)
    if not link then return end -- uncached item; BuildItemLink already requested the load, next click works
    if IsModifiedClick("CHATLINK") then
        -- Bag behaviour: insert into the open chat box only; never open chat
        -- on the user's behalf.
        ChatEdit_InsertLink(link)
    elseif IsModifiedClick("DRESSUP") then
        DressUpItemLink(link)
    end
end

-- Row text can carry markup (atlas icons, color codes) — strip it before it
-- reaches the AH search box, where it would break the query.
local function CleanItemText(text)
    if not text then return nil end
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- Quality labels render as [Name] — the brackets break AH search queries.
    text = text:gsub("%[", ""):gsub("%]", "")
    text = text:gsub("^%s*", ""):gsub("%s*$", "")
    return text ~= "" and text or nil
end

local AUCTIONATOR_LIST_NAME = "Bread Codex"

-- Append `item:ID` (Auctionator's exact-item search term) to our shopping
-- list in Auctionator's SavedVariables. No public API exists for list edits,
-- so this writes the lists table directly. Retail keys lists by name
-- (AUC_SHOPPING_LISTS) while classic-era builds keep an array
-- (AUCTIONATOR_SHOPPING_LISTS) — handle both, never mark the list temporary,
-- and pcall everything so an internals change degrades to a message instead
-- of an error. Works anywhere; the list runs when the AH is opened.
local function AddToAuctionatorList(itemId, name)
    local ok, added = pcall(function()
        local lists, keyed = _G.AUC_SHOPPING_LISTS, true
        if type(lists) ~= "table" then
            lists, keyed = _G.AUCTIONATOR_SHOPPING_LISTS, false
        end
        if type(lists) ~= "table" then
            -- Retail keeps its lists inside the addon's own namespace rather
            -- than a bare global — last resort: search Auctionator's exports.
            if type(Auctionator) == "table" then
                for _, key in ipairs({ "SHOPPING_LISTS", "ShoppingLists" }) do
                    if type(Auctionator[key]) == "table" then
                        lists, keyed = Auctionator[key], true
                        break
                    end
                end
            end
        end
        if type(lists) ~= "table" then
            -- No list has ever been created, so Auctionator never initialized
            -- its SavedVariable. Create the retail-shaped table ourselves —
            -- it is the declared SavedVariable name, so it persists.
            lists, keyed = {}, true
            _G.AUC_SHOPPING_LISTS = lists
        end

        local list
        if keyed then
            list = lists[AUCTIONATOR_LIST_NAME]
        else
            for _, entry in ipairs(lists) do
                if type(entry) == "table" and entry.name == AUCTIONATOR_LIST_NAME then
                    list = entry
                    break
                end
            end
        end
        if type(list) ~= "table" or type(list.items) ~= "table" then
            list = { name = AUCTIONATOR_LIST_NAME, items = {} }
            if keyed then
                lists[AUCTIONATOR_LIST_NAME] = list
            else
                table.insert(lists, list)
            end
        end
        -- Must read as a permanent, saved list — not a throwaway temp one.
        list.isTemporary = nil

        -- List entries are display strings in Auctionator's list view, so a
        -- raw `item:ID` term renders unresolved. Store the (cleaned) name —
        -- it searches correctly and stays readable; fall back to the id term
        -- only when no name is known.
        local term = (name and name ~= "" and name) or ("item:" .. itemId)
        for _, existing in ipairs(list.items) do
            if existing == term then return true end
        end
        list.items[#list.items + 1] = term
        return true
    end)
    if ok and added then
        print(
            "|cff00ccffBread Codex:|r "
                .. (
                    (L and L["item.menu.ah_listed"])
                    or ('Added to your Auctionator "%s" shopping list.'):format(AUCTIONATOR_LIST_NAME)
                )
        )
    else
        print(
            "|cff00ccffBread Codex:|r "
                .. ((L and L["item.menu.ah_list_fail"]) or "Could not update the Auctionator shopping list.")
        )
    end
end

-- Right-click menu shared by every row/icon wired through SetupItemTooltip:
-- shop via Auctionator (when installed, on Enhancements rows), or copy the name.
local function OpenItemContextMenu(row)
    local itemId = row.itemId
    if not itemId then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end

    -- Crafted-enchant item names embed a profession-quality atlas in the name
    -- itself (straight from GetItemInfo), and row text adds brackets/colors —
    -- both break Auctionator queries, so always clean whatever we use.
    local name = CleanItemText(select(1, GetItemInfo(itemId)))
        or CleanItemText(row.itemText and row.itemText.GetText and row.itemText:GetText())
        or nil
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(name or (L and L["tab.enhancements"]) or "Item")
        -- Auctionator integration: only makes sense on the Enhancements tab
        -- (rows are flagged allowAhSearch) and only with Auctionator installed.
        -- Presence of the addon is enough to show the entry; the action itself
        -- resolves whichever SavedVariables shape this build uses.
        if row.allowAhSearch and Auctionator ~= nil then
            root:CreateButton((L and L["item.menu.search_ah"]) or "Add to Auctionator List", function()
                AddToAuctionatorList(itemId, name)
            end)
        end
        -- "View in Dungeon Journal": only where the journal can actually show
        -- the item. Precedence: a boss NAMED by the source text wins (tier
        -- pieces drop from several bosses — the index would pick an arbitrary
        -- one); otherwise the season loot index pins the exact boss by the
        -- droppable item id (catalyst rows carry the SOURCE item precisely
        -- for that); a dungeon-only source text is the last resort. Crafted/
        -- vendor/world-drop rows resolve to nothing and never see the entry.
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
        else
            pcall(LoadAddOn, "Blizzard_EncounterJournal")
        end
        local journalItemId = row.catalystItemId or itemId
        local journalInst, journalEnc
        if EncounterJournal and ToggleEncounterJournal then
            local textInst, textEnc
            if ns.GetJournalTarget then
                textInst, textEnc = ns.GetJournalTarget(row.sourceText)
            end
            if textEnc then
                journalInst, journalEnc = textInst, textEnc
            elseif ns.GetJournalLootTarget then
                journalInst, journalEnc = ns.GetJournalLootTarget(journalItemId)
            end
            if not journalInst and textInst then journalInst = textInst end
        end
        if journalInst and EncounterJournal_OpenJournal then
            root:CreateButton(L["item.menu.view_journal"], function()
                if InCombatLockdown() then return end
                -- Loot filter goes on BEFORE navigating so the encounter's
                -- first loot paint already uses it; it is re-asserted after,
                -- because the journal refreshes loot asynchronously
                -- (EJ_LOOT_DATA_RECIEVED) and the difficulty switch
                -- re-renders too — either can race a one-shot filter set.
                -- The set goes through Blizzard's own global wrapper — the
                -- exact path a dropdown pick takes — and is verified by
                -- reading EJ_GetLootFilter back: the C function silently
                -- ignores invalid (classID, specID) pairs, so a mismatch
                -- prints instead of failing invisibly.
                local filterReported
                local function SetEJLootFilter()
                    if not (row.ejSpecID and row.ejClassID) then return end
                    if EncounterJournal and EncounterJournal_SetClassAndSpecFilter then
                        pcall(EncounterJournal_SetClassAndSpecFilter, EncounterJournal, row.ejClassID, row.ejSpecID)
                    elseif EJ_SetLootFilter then
                        pcall(EJ_SetLootFilter, row.ejClassID, row.ejSpecID)
                        if EncounterJournal_LootUpdate then pcall(EncounterJournal_LootUpdate) end
                    else
                        return
                    end
                    if not filterReported and EJ_GetLootFilter then
                        local c, s = EJ_GetLootFilter()
                        if c ~= row.ejClassID or s ~= row.ejSpecID then
                            filterReported = true
                            print(
                                ("|cffff3333Bread Codex:|r journal loot filter not applied (got %s/%s, wanted %s/%s)"):format(
                                    tostring(c),
                                    tostring(s),
                                    tostring(row.ejClassID),
                                    tostring(row.ejSpecID)
                                )
                            )
                        end
                    end
                end
                SetEJLootFilter()
                if not EncounterJournal:IsShown() then ShowUIPanel(EncounterJournal) end
                -- OpenJournal lands on the right content tab and the
                -- encounter, and its itemID argument selects the Loot side
                -- tab — but only with an encounter displayed (without one the
                -- click would hit a stale loot tab), so the item id rides
                -- along only when the boss is pinned.
                local okNav = pcall(
                    EncounterJournal_OpenJournal,
                    nil,
                    journalInst,
                    journalEnc,
                    nil,
                    nil,
                    journalEnc and journalItemId or nil
                )
                local function AssertEJState()
                    SetEJLootFilter()
                    -- Mythic loot view, matching what the guides cover;
                    -- validity-checked against the displayed instance —
                    -- legacy-pool dungeons don't all offer every difficulty.
                    if
                        not (DifficultyUtil and DifficultyUtil.ID and EJ_SetDifficulty and EJ_IsValidInstanceDifficulty)
                    then
                        return
                    end
                    local mythic = DifficultyUtil.ID.DungeonMythic
                    if not EJ_IsValidInstanceDifficulty(mythic) then mythic = DifficultyUtil.ID.PrimaryRaidMythic end
                    if EJ_IsValidInstanceDifficulty(mythic) then EJ_SetDifficulty(mythic) end
                end
                AssertEJState()
                C_Timer.After(0.25, AssertEJState)
                if not okNav and row.ejSpecID and EJ_SetLootFilter then
                    -- Navigation failed (pcall'd): at least leave the filter on
                    -- the browsed spec so the journal is in the right context.
                    pcall(EJ_SetLootFilter, row.ejClassID, row.ejSpecID)
                end
            end)
        end
        root:CreateButton((L and L["item.menu.link_chat"]) or "Link in chat", function()
            local link = (ns.BuildItemLink and ns.BuildItemLink(itemId, row.bonusIDs, row.catalystItemId))
                or GetItemLink(itemId)
            if link then
                if not ChatEdit_InsertLink(link) then ChatFrame_OpenChat(link) end
            end
        end)
        root:CreateButton((L and L["item.menu.copy_name"]) or "Copy name", function()
            local text = name or tostring(itemId)
            if ns.ShowCopyPopup then ns.ShowCopyPopup(text, row) end
        end)
    end)
end

local function SetupItemTooltip(row)
    row:EnableMouse(true)
    -- Menus open on mouse-DOWN: a tooltip sitting under the cursor (edge of the
    -- panel, overlapping neighbours) can swallow the mouse-up and make
    -- right-clicks feel flaky. The tooltip itself is made non-interactive so
    -- it never eats clicks meant for the row beneath it.
    row:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then OpenItemContextMenu(self) end
    end)
    row:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" then HandleItemClick(self) end
    end)
    row:SetScript("OnEnter", function(self)
        ns.Tooltip.MakeClickThrough()
        if self.spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellId)
            if self.sourceText then ns.Tooltip.Blank().Double(SOURCE or "Source", self.sourceText, "muted", "title") end
            if self.popText then
                ns.Tooltip.Blank().Double(L["tooltip.popularity"] or "Popularity", self.popText, "muted", "title")
            end
            GameTooltip:Show()
        elseif self.itemId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.bonusIDs and #self.bonusIDs > 0 then
                -- BuildItemLink returns nil while the item is uncached
                -- (GetItemLink has nothing yet); SetHyperlink(nil) then errors
                -- later inside the engine's async tooltip handler, beyond the
                -- pcall. Fall back to SetItemByID, which waits for data cleanly.
                local link = ns.BuildItemLink(self.itemId, self.bonusIDs, self.catalystItemId)
                local ok = link and pcall(GameTooltip.SetHyperlink, GameTooltip, link)
                if not (link and ok) then GameTooltip:SetItemByID(self.itemId) end
            else
                GameTooltip:SetItemByID(self.itemId)
            end
            if self.altItemId then
                ns.Tooltip.Blank().Muted((L and L["gear.tooltip.alternative"]) or "Alternative:")
                local altRef = { itemId = self.altItemId, name = self.altName or "" }
                ns.Tooltip.Intro("  " .. FormatItem(altRef))
            end
            if self.embItemId then
                ns.Tooltip.Blank().Muted((L and L["gear.tooltip.embellishment"]) or "Embellished:")
                local embRef = { itemId = self.embItemId, name = self.embName or "" }
                ns.Tooltip.Intro("  " .. FormatItem(embRef))
            end
            if self.sourceText then ns.Tooltip.Blank().Double(SOURCE or "Source", self.sourceText, "muted", "title") end
            if self.catalystItemId then
                ns.Tooltip.Double(
                    L["gear.tooltip.catalyst"],
                    FormatItem({ itemId = self.catalystItemId, bonusIDs = self.bonusIDs }),
                    "muted",
                    "title"
                )
            end
            if self.popText then
                ns.Tooltip.Blank().Double(L["tooltip.popularity"] or "Popularity", self.popText, "muted", "title")
            end
            ns.Tooltip.Blank().Body(L["item.tooltip.menu_hint"])
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

ns.FormatItem = FormatItem
ns.CleanItemText = CleanItemText
ns.IsItemOwned = IsItemOwned
ns.CreateRowIcon = CreateRowIcon
ns.SetRowIcon = SetRowIcon
ns.GetSpellIcon = GetSpellIcon
ns.SetupItemTooltip = SetupItemTooltip
ns.OpenItemContextMenu = OpenItemContextMenu
ns.GetItemIcon = GetItemIcon
ns.GetItemName = GetItemName
ns.HandleItemClick = HandleItemClick
ns.RequestAllItems = RequestAllItems
ns.GetSpecGearData = GetSpecGearData
ns.GetPlayerClassSpec = GetPlayerClassSpec
ns.TIER_COLORS = TIER_COLORS
ns.TIER_ORDER = TIER_ORDER
ns.CONTEXT_LABELS = CONTEXT_LABELS
ns.CONSUMABLE_ORDER = CONSUMABLE_ORDER
ns.CONSUMABLE_LABELS = CONSUMABLE_LABELS
ns.ICON_SIZE_GEAR = ICON_SIZE

function ns.SizeSourceColumn(fs, rowWidth, leftCols, nameMin, cap)
    local content = math.ceil(fs:GetStringWidth()) + 2
    local maxByName = (rowWidth and rowWidth > 0) and math.max(20, rowWidth - leftCols - nameMin) or content
    fs:SetWidth(math.max(1, math.min(content, maxByName, cap or 300)))
end
ns.MAX_ENCHANT_ROWS = MAX_ENCHANT_ROWS
ns.MAX_GEM_ROWS = MAX_GEM_ROWS
ns.MAX_CONSUMABLE_ROWS = MAX_CONSUMABLE_ROWS

local SLOT_TO_INV = {
    Head = 1,
    Neck = 2,
    Shoulders = 3,
    Back = 15,
    Chest = 5,
    Wrist = 9,
    Hands = 10,
    Waist = 6,
    Legs = 7,
    Feet = 8,
    ["Finger 1"] = 11,
    ["Finger 2"] = 12,
    ["Trinket 1"] = 13,
    ["Trinket 2"] = 14,
    ["Main Hand"] = 16,
    ["Off Hand"] = 17,
}

local function parseLinkFields(link)
    if not link then return nil end
    local payload = link:match("item:([^|]+)")
    if not payload then return nil end
    local fields = {}
    for f in (payload .. ":"):gmatch("([^:]*):") do
        fields[#fields + 1] = f
    end
    return fields
end

function ns.EquippedEnchantIdForSlot(slot)
    local invSlot = SLOT_TO_INV[slot]
    if not invSlot then return nil end
    local link = GetInventoryItemLink("player", invSlot)
    local fields = parseLinkFields(link)
    if not fields then return nil end
    local id = tonumber(fields[2])
    return (id and id > 0) and id or nil
end

function ns.IsGemSocketed(itemId)
    if not itemId then return false end
    for _, invSlot in ipairs({ 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16, 17 }) do
        local link = GetInventoryItemLink("player", invSlot)
        local fields = parseLinkFields(link)
        if fields then
            for gi = 3, 6 do
                if tonumber(fields[gi]) == itemId then return true end
            end
        end
    end
    return false
end

local enchantSpellToId

function ns.RebuildEnchantSpellLookup()
    enchantSpellToId = {}
    for _, source in ipairs({ "ugg" }) do
        local classToken, specKey = ns.GetClassAndSpec()
        if classToken and specKey then
            local sd = ns.SourceSpec and ns.SourceSpec(source, classToken, specKey)
            local byHero = sd and sd.enchants and sd.enchants["all"]
            local byCtx = byHero and byHero["all"]
            if byCtx then
                for _, list in pairs(byCtx) do
                    for _, e in ipairs(list) do
                        if e.spellId and e.id then enchantSpellToId[e.spellId] = e.id end
                    end
                end
            end
        end
    end
end

function ns.ResolveEnchantId(entry)
    if not entry then return nil end
    if entry.enchantId then return entry.enchantId end
    if entry.itemId then
        local spellId
        if GetItemSpell then
            local _, s = GetItemSpell(entry.itemId)
            spellId = s
        end
        if spellId and enchantSpellToId and enchantSpellToId[spellId] then return enchantSpellToId[spellId] end
    end
    return nil
end

function ns.IsEnchantApplied(entry, slot)
    local id = ns.ResolveEnchantId(entry)
    if not id then return false end
    return ns.EquippedEnchantIdForSlot(slot) == id
end

BuildBisLookup()
