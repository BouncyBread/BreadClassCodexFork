local _, ns = ...

-- Where each Best in Slot row drops, for the Gear list's "Group by Source"
-- view: a raid boss, a dungeon, Crafted, or Other. Resolve and Group are
-- pure (lookups are passed in); Lookups builds them from the loaded data.
local RS = {}
ns.RollSource = RS

-- Tier slots that drop as a token from one raid boss each.
local TOKEN_SLOTS = { Head = true, Shoulders = true, Chest = true, Hands = true, Legs = true }
RS.TOKEN_SLOTS = TOKEN_SLOTS

local CRAFTED = { key = "crafted", kind = "crafted" }
local OTHER = { key = "other", kind = "other" }
RS.CRAFTED, RS.OTHER = CRAFTED, OTHER

local function fromIds(encounterID, instanceID)
    if encounterID then
        return { key = "e:" .. encounterID, kind = "encounter", encounterID = encounterID, instanceID = instanceID }
    end
    if instanceID then return { key = "i:" .. instanceID, kind = "instance", instanceID = instanceID } end
end

-- A raid hit groups by boss, a dungeon hit by dungeon. The list's content
-- picks between hits when one item drops in both.
local function fromHits(hits, content)
    if not hits or #hits == 0 then return nil end
    local pick
    for _, h in ipairs(hits) do
        if (content == "raid" and h.isRaid) or (content == "mplus" and not h.isRaid) then
            pick = h
            break
        end
    end
    pick = pick or hits[1]
    if pick.isRaid then return fromIds(pick.encounterID, pick.instanceID) end
    return fromIds(nil, pick.instanceID)
end

local function fromFields(f)
    if not f then return nil end
    if f.crafted then return CRAFTED end
    return fromIds(f.sourceEncounter, f.sourceInstance)
end

--- entry: a Gear row ({ slot, item = { itemId, catalyst }, crafted,
--- sourceEncounter, sourceInstance }). content: "raid" | "mplus" | "all".
--- L (lookups): journalHits(itemId), isCrafted(itemId), isTier(itemId),
--- ivItem(itemId), ivTier(itemId), tokenBoss(slot).
function RS.Resolve(entry, content, L)
    local item = entry.item or {}
    local id = item.itemId
    if entry.crafted or (id and L.isCrafted(id)) then return CRAFTED end

    local catId = item.catalyst and item.catalyst.itemId
    local r = (catId and fromHits(L.journalHits(catId), content)) or (id and fromHits(L.journalHits(id), content))
    if r then return r end

    r = fromFields(entry)
    if r then return r end

    if id and L.isTier(id) then
        -- A tier piece's source is the catalyzed item, which a row without
        -- one does not name. In M+ only the guide's own row for this spec
        -- can say it; raid lists use the boss that drops the slot's token.
        if content == "mplus" then return fromFields(L.ivTier(id)) or OTHER end
        local enc, inst = L.tokenBoss(entry.slot)
        return fromIds(enc, inst) or OTHER
    end

    return (id and fromFields(L.ivItem(id))) or OTHER
end

local KIND_RANK = { encounter = 0, instance = 0, crafted = 1, other = 2 }

--- Groups entries by source. Returns an ordered list of
--- { key, kind, label, entries = {...}, count, done }: count and done are
--- distinct items (done only with isDone). Sources sort by count, highest
--- first, then by label; Crafted, then Other last. Progress never moves a
--- source.
function RS.Group(entries, content, L, labelFor, isDone)
    local byKey, groups = {}, {}
    for _, entry in ipairs(entries) do
        local src = RS.Resolve(entry, content, L)
        local g = byKey[src.key]
        if not g then
            g = { key = src.key, kind = src.kind, source = src, entries = {}, count = 0, done = 0, seen = {} }
            g.label = labelFor(src)
            byKey[src.key] = g
            groups[#groups + 1] = g
        end
        g.entries[#g.entries + 1] = entry
        local id = entry.item and entry.item.itemId
        if id == nil or not g.seen[id] then
            g.count = g.count + 1
            if isDone and isDone(entry) then g.done = g.done + 1 end
            if id then g.seen[id] = true end
        end
    end
    table.sort(groups, function(a, b)
        local ra, rb = KIND_RANK[a.kind] or 0, KIND_RANK[b.kind] or 0
        if ra ~= rb then return ra < rb end
        if a.count ~= b.count then return a.count > b.count end
        return (a.label or "") < (b.label or "")
    end)
    for _, g in ipairs(groups) do
        g.seen = nil
    end
    return groups
end

--- Token boss per tier slot, by majority over guide rows that name a raid
--- boss for a tier piece dropped directly (no catalyzed item).
function RS.TokenBosses(rows, isTier)
    local counts = {}
    for _, row in ipairs(rows) do
        local id = row.itemId
        if row.sourceEncounter and not row.catalyst and TOKEN_SLOTS[row.slot] and id and isTier(id) then
            local bySlot = counts[row.slot] or {}
            counts[row.slot] = bySlot
            local c = bySlot[row.sourceEncounter] or { n = 0, instanceID = row.sourceInstance }
            c.n = c.n + 1
            bySlot[row.sourceEncounter] = c
        end
    end
    local out = {}
    for slot, bySlot in pairs(counts) do
        local bestEnc, best
        for enc, c in pairs(bySlot) do
            if not best or c.n > best.n or (c.n == best.n and enc < bestEnc) then
                bestEnc, best = enc, c
            end
        end
        out[slot] = { encounterID = bestEnc, instanceID = best.instanceID }
    end
    return out
end

-- Runtime lookups over the loaded source data. Built once per class/spec/
-- content; the shared indexes once per session.
local shared

local function eachGearRow(source, fn)
    local root = ClassCodexSource and ClassCodexSource[source] and ClassCodexSource[source].data
    if not root then return end
    for classToken, specs in pairs(root) do
        for specKey in pairs(specs) do
            local sd = ns.SourceSpec and ns.SourceSpec(source, classToken, specKey)
            local gear = sd and sd.gear
            if gear then
                for _, byCtx in pairs(gear) do
                    for ctx, rows in pairs(byCtx) do
                        if type(rows) == "table" and ctx:sub(1, 4) ~= "pvp" then
                            for _, row in ipairs(rows) do
                                fn(row, classToken, specKey, ctx)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function collectItemIds(t, out, depth)
    if type(t) ~= "table" or depth > 6 then return end
    if type(t.itemId) == "number" then out[t.itemId] = true end
    for _, v in pairs(t) do
        if type(v) == "table" then collectItemIds(v, out, depth + 1) end
    end
end

local function buildShared()
    local s = { crafted = {}, tier = {}, ivItem = {}, ivTier = {}, rows = {} }
    eachGearRow("icyveins", function(row, classToken, specKey, ctx)
        local id = row.itemId
        if not id then return end
        if row.crafted then s.crafted[id] = true end
        if row.catalyst then s.tier[id] = true end
        s.rows[#s.rows + 1] = row
        s.ivTier[classToken .. "/" .. specKey .. "/" .. ctx .. "/" .. id] = row
    end)
    for _, row in ipairs(s.rows) do
        local id = row.itemId
        if not s.tier[id] and not s.ivItem[id] and (row.crafted or row.sourceEncounter or row.sourceInstance) then
            s.ivItem[id] = row
        end
    end
    local ugg = ClassCodexSource and ClassCodexSource.ugg and ClassCodexSource.ugg.data
    if ugg then
        for classToken, specs in pairs(ugg) do
            for specKey in pairs(specs) do
                local sd = ns.SourceSpec and ns.SourceSpec("ugg", classToken, specKey)
                if sd and sd.crafting then collectItemIds(sd.crafting, s.crafted, 0) end
            end
        end
    end
    s.isTierData = function(id)
        return s.tier[id] == true
    end
    s.tokenBoss = RS.TokenBosses(s.rows, s.isTierData)
    return s
end

local function inItemSet(id)
    if not (C_Item and C_Item.GetItemInfo) then return false end
    local setID = select(16, C_Item.GetItemInfo(id))
    return setID ~= nil and setID ~= 0
end

--- Lookups for one list: the spec and content being shown.
function RS.Lookups(classToken, specKey, content)
    shared = shared or buildShared()
    local s = shared
    local prefix = (classToken or "") .. "/" .. (specKey or "") .. "/" .. (content or "") .. "/"
    return {
        journalHits = function(id)
            return ns.GetJournalLootTargets and ns.GetJournalLootTargets(id)
        end,
        isCrafted = function(id)
            return s.crafted[id] == true
        end,
        isTier = function(id)
            return s.tier[id] == true or inItemSet(id)
        end,
        ivItem = function(id)
            return s.ivItem[id]
        end,
        ivTier = function(id)
            return s.ivTier[prefix .. id]
        end,
        tokenBoss = function(slot)
            local t = slot and s.tokenBoss[slot]
            if t then return t.encounterID, t.instanceID end
        end,
    }
end

--- Header text for a group's source: the journal's (localized) name.
function RS.Label(src)
    if src.kind == "crafted" then return ns.L["gear.group.crafted"] end
    if src.kind == "other" then return ns.L["gear.group.other"] end
    local name
    if src.encounterID and EJ_GetEncounterInfo then name = EJ_GetEncounterInfo(src.encounterID) end
    if not name and src.instanceID and EJ_GetInstanceInfo then name = EJ_GetInstanceInfo(src.instanceID) end
    return name or ns.L["gear.group.other"]
end
