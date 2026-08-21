local _, ns = ...

ns.OmniumFolio = {}
local OF = ns.OmniumFolio

local SYSTEM_ID = 48

local SELECTION_TYPE = (Enum and Enum.TraitNodeType and Enum.TraitNodeType.Selection) or 2

local stateCache

local function entrySpellId(configID, entryID)
    local ei = entryID and C_Traits.GetEntryInfo(configID, entryID)
    local defID = ei and ei.definitionID
    local def = defID and C_Traits.GetDefinitionInfo(defID)
    return def and def.spellID or nil
end

local function entryTypeInfo(configID, entryID)
    local ei = entryID and C_Traits.GetEntryInfo(configID, entryID)
    return ei and ei.type or nil
end

local function currencyMap(configID, treeID)
    local out = {}
    if not C_Traits.GetTreeCurrencyInfo then return out end
    local ok, list = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
    if ok and list then
        for _, c in ipairs(list) do
            if c.traitCurrencyID then out[c.traitCurrencyID] = c.quantity or 0 end
        end
    end
    return out
end

local function canAfford(configID, nodeID, have)
    if not C_Traits.GetNodeCost then return true end
    local ok, costs = pcall(C_Traits.GetNodeCost, configID, nodeID)
    if not ok or not costs then return true end
    for _, cost in ipairs(costs) do
        local id, amount = cost.ID, cost.amount or 0
        if id and (have[id] or 0) < amount then return false end
    end
    return true
end

local function buildState()
    if not (C_Traits and C_Traits.GetConfigIDBySystemID) then return { available = false } end
    local configID = C_Traits.GetConfigIDBySystemID(SYSTEM_ID)
    if not configID then return { available = false } end
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return { available = false } end
    local nodeIDs = C_Traits.GetTreeNodes(treeID)
    if not nodeIDs or #nodeIDs == 0 then return { available = false } end

    local have = currencyMap(configID, treeID)
    local nodes, bySpell = {}, {}
    for _, nodeID in ipairs(nodeIDs) do
        local ni = C_Traits.GetNodeInfo(configID, nodeID)
        if ni and ni.entryIDs and #ni.entryIDs > 0 then
            local committedEntryID = ni.entryIDsWithCommittedRanks and ni.entryIDsWithCommittedRanks[1]

            if ni.entryIDToRanksIncreased then
                for entryID, n in pairs(ni.entryIDToRanksIncreased) do
                    if n and n > 0 then
                        committedEntryID = entryID
                        break
                    end
                end
            end
            local entries = {}
            for _, entryID in ipairs(ni.entryIDs) do
                local spellId = entrySpellId(configID, entryID)
                if spellId then
                    entries[#entries + 1] = {
                        entryID = entryID,
                        spellId = spellId,
                        entryType = entryTypeInfo(configID, entryID),
                    }
                    bySpell[spellId] = { nodeID = nodeID, entryID = entryID, nodeType = ni.type }
                end
            end
            if #entries > 0 then
                local isSelection = ni.type == SELECTION_TYPE
                local rank = ni.currentRank or ni.ranksPurchased or 0
                local active = (ni.ranksPurchased or 0) > 0 or rank > 0

                local shape
                if isSelection then
                    shape = "choice"
                else
                    local et = entries[1].entryType
                    shape = (et == 1) and "square" or "circle"
                end

                local canBuy = (ni.canPurchaseRank and canAfford(configID, nodeID, have)) or false

                if isSelection and committedEntryID then canBuy = true end
                nodes[#nodes + 1] = {
                    nodeID = nodeID,
                    nodeType = ni.type,
                    isSelection = isSelection,
                    shape = shape,
                    posX = ni.posX or 0,
                    posY = ni.posY or 0,
                    entries = entries,
                    committedEntryID = committedEntryID,
                    committedSpellId = entrySpellId(configID, committedEntryID),
                    rank = rank,
                    active = active,
                    canBuy = canBuy,
                }
            end
        end
    end

    table.sort(nodes, function(a, b)
        if a.posY ~= b.posY then return a.posY < b.posY end
        return a.posX < b.posX
    end)

    return { available = true, configID = configID, treeID = treeID, nodes = nodes, bySpell = bySpell }
end

function OF.GetState()
    if stateCache == nil then
        local ok, res = pcall(buildState)
        stateCache = ok and res or { available = false }
    end
    return stateCache
end

function OF.Invalidate()
    stateCache = nil
end

function OF.IsAvailable()
    local s = OF.GetState()
    return s and s.available or false
end

function OF.GetNodes()
    local s = OF.GetState()
    return (s and s.available and s.nodes) or {}
end

function OF.Lookup(spellId)
    local s = OF.GetState()
    if not (s and s.available) or not spellId then return nil end
    return s.bySpell[spellId]
end

function OF.ApplyEntry(nodeID, entryID)
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    local s = OF.GetState()
    if not (s and s.available) then return false, "unavailable" end

    local node
    for _, n in ipairs(s.nodes) do
        if n.nodeID == nodeID then
            node = n
            break
        end
    end
    if not node then return false, "unavailable" end
    if node.committedEntryID == entryID then return false, "already" end

    local ok
    if node.isSelection then
        ok = C_Traits.SetSelection and C_Traits.SetSelection(s.configID, nodeID, entryID)
    else
        ok = C_Traits.PurchaseRank and C_Traits.PurchaseRank(s.configID, nodeID)
    end
    if ok then
        if C_Traits.CommitConfig then C_Traits.CommitConfig(s.configID) end
        OF.Invalidate()
        return true
    end
    return false, "failed"
end

function OF.ApplySpell(spellId)
    local e = OF.Lookup(spellId)
    if not e then return false, "notfound" end
    return OF.ApplyEntry(e.nodeID, e.entryID)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("TRAIT_CONFIG_UPDATED")
ev:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
ev:RegisterEvent("CONFIG_COMMIT_FAILED")
-- PurchaseRank fires TRAIT_CONFIG_UPDATED synchronously, so a talent apply
-- re-enters the panel rebuild once per staged purchase and freezes the main
-- thread (ERROR #109, 60s unresponsive thread). While an apply is staging,
-- only invalidate the cache and coalesce a single deferred refresh.
local refreshQueued = false
ev:SetScript("OnEvent", function()
    OF.Invalidate()
    if ns._talentApplyInProgress then
        if refreshQueued then return end
        refreshQueued = true
        C_Timer.After(0.1, function()
            refreshQueued = false
            if not ns._talentApplyInProgress and ns.OnOmniumFolioChanged then ns.OnOmniumFolioChanged() end
        end)
        return
    end
    if ns.OnOmniumFolioChanged then ns.OnOmniumFolioChanged() end
end)
