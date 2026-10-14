local _, ns = ...

-- Icy Veins leveling builds below max level: the guide's talents for the
-- player's level, bought in the guide's order. No frames or events; at max
-- level every lookup returns nil and callers keep their full-build paths.

local LevelingTalents = {}
ns.LevelingTalents = LevelingTalents

-- Pure: the guide points owned at `level` from flat (nodeID, entryID, level)
-- triples sorted by level. Returns the ordered points plus per-node rank
-- counts and the last entry picked per node.
function LevelingTalents.Prefix(order, level)
    local points, ranks, entries = {}, {}, {}
    for i = 1, #order - 2, 3 do
        local nodeID, entryID, pointLevel = order[i], order[i + 1], order[i + 2]
        if pointLevel > level then break end
        points[#points + 1] = { nodeID = nodeID, entryID = entryID }
        ranks[nodeID] = (ranks[nodeID] or 0) + 1
        entries[nodeID] = entryID
    end
    return points, ranks, entries
end

-- class .. "\0" .. spec -> { [export] = { order = {...}, plans = { [level] = plan } } }
local indexBySpec = {}

local function SpecIndex(classToken, specKey)
    local key = classToken .. "\0" .. specKey
    local index = indexBySpec[key]
    if index then return index end
    index = {}
    local sd = ns.SourceSpec and ns.SourceSpec("icyveins", classToken, specKey)
    for _, byContext in pairs(sd and sd.talents or {}) do
        for _, b in ipairs(byContext.leveling or {}) do
            if b.export and type(b.order) == "table" and #b.order >= 3 then
                index[b.export] = { order = b.order, plans = {} }
            end
        end
    end
    indexBySpec[key] = index
    return index
end

--- The guide plan for this export at the player's level, or nil when the
--- export is not the current spec's Icy Veins leveling build, the player is
--- at max level, or the talent pane is inspecting someone else.
function ns.GetLevelingTarget(exportString)
    if not exportString or ns._talentPaneInspect then return nil end
    if not ns.IsAtMaxLevel or ns.IsAtMaxLevel() then return nil end
    if not ns.GetClassAndSpec then return nil end
    local classToken, specKey = ns.GetClassAndSpec()
    if not classToken or not specKey then return nil end
    local entry = SpecIndex(classToken, specKey)[exportString]
    if not entry then return nil end
    local level = UnitLevel("player") or 0
    local plan = entry.plans[level]
    if not plan then
        local points, ranks, entries = LevelingTalents.Prefix(entry.order, level)
        plan = { export = exportString, level = level, points = points, ranks = ranks, entries = entries }
        entry.plans[level] = plan
    end
    return plan
end

local function IsChoiceType(nodeType)
    return nodeType == Enum.TraitNodeType.Selection or nodeType == Enum.TraitNodeType.SubTreeSelection
end

-- The hero sub-tree selection from the full export (the order lists only
-- the hero talents, not the choice of hero tree). False when none resolves.
local function HeroSelection(plan, configID)
    if plan.heroSelection == nil then
        plan.heroSelection = false
        local entries = ns.ParseLoadoutNodes and ns.ParseLoadoutNodes(plan.export)
        for nodeID, e in pairs(entries or {}) do
            local info = C_Traits.GetNodeInfo(configID, nodeID)
            if info and info.type == Enum.TraitNodeType.SubTreeSelection and e.selectionEntryID then
                plan.heroSelection = { nodeID = nodeID, entryID = e.selectionEntryID }
                break
            end
        end
    end
    return plan.heroSelection or nil
end

local function HasHeroPoint(plan, configID)
    for nodeID in pairs(plan.ranks) do
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.subTreeID and info.subTreeID > 0 then return true end
    end
    return false
end

--- Node map of the plan in the shape of ns.ParseLoadoutNodes:
--- nodeID -> { nodeID, ranksPurchased, selectionEntryID, isChoiceNode }.
--- Non-choice nodes take the live active entry, as ParseLoadoutNodes does.
function ns.LevelingTargetMap(plan, configID)
    configID = configID or C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    local map = {}
    for nodeID, ranks in pairs(plan.ranks) do
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.ID ~= 0 then
            local isChoice = IsChoiceType(info.type)
            local entryID = isChoice and plan.entries[nodeID] or (info.activeEntry and info.activeEntry.entryID)
            map[nodeID] = {
                nodeID = nodeID,
                ranksPurchased = ranks,
                selectionEntryID = entryID,
                isChoiceNode = isChoice,
            }
        end
    end
    local hero = HasHeroPoint(plan, configID) and HeroSelection(plan, configID)
    if hero then
        map[hero.nodeID] =
            { nodeID = hero.nodeID, ranksPurchased = 1, selectionEntryID = hero.entryID, isChoiceNode = true }
    end
    return map
end

--- A node's owned ranks and picked entry. A chosen hero tree counts as one
--- rank even when the client reports no purchased ranks for the selection.
function ns.OwnedNodeState(configID, nodeID)
    local n = C_Traits.GetNodeInfo(configID, nodeID)
    if not n then return 0, nil, false end
    local entryID = n.activeEntry and n.activeEntry.entryID
    local ranks = n.ranksPurchased or 0
    if ranks == 0 and entryID and n.type == Enum.TraitNodeType.SubTreeSelection then ranks = 1 end
    return ranks, entryID, IsChoiceType(n.type)
end

-- Every owned node of the config: nodeID -> { ranks, entryID, isChoice }.
local function ActiveNodes(configID)
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return nil end
    local out = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local ranks, entryID, isChoice = ns.OwnedNodeState(configID, nodeID)
        if ranks > 0 then out[nodeID] = { ranks = ranks, entryID = entryID, isChoice = isChoice } end
    end
    return out
end

local function Compare(map, active)
    local subset = true
    for nodeID, a in pairs(active) do
        local t = map[nodeID]
        if not t or a.ranks > t.ranksPurchased or (a.isChoice and a.entryID ~= t.selectionEntryID) then
            subset = false
            break
        end
    end
    local complete = subset
    if complete then
        for nodeID, t in pairs(map) do
            local a = active[nodeID]
            if not a or a.ranks < t.ranksPurchased then
                complete = false
                break
            end
        end
    end
    return subset, complete
end

--- subset: the config holds only guide talents for this level (nothing to
--- reset). complete: the config holds exactly those talents.
function ns.LevelingCompare(plan, configID)
    configID = configID or C_ClassTalents.GetActiveConfigID()
    if not configID then return false, false end
    local map = ns.LevelingTargetMap(plan, configID)
    local active = ActiveNodes(configID)
    if not map or not active then return false, false end
    return Compare(map, active)
end

--- The purchase steps: the hero tree choice first when the plan reaches the
--- hero tree (changing the hero with purchases staged hard-crashes the
--- client), then one step per point in guide order (rank = the node's rank
--- after this point).
function ns.LevelingSteps(plan, configID)
    local steps, seen = {}, {}
    local hero = HasHeroPoint(plan, configID) and HeroSelection(plan, configID)
    if hero then
        steps[1] = { nodeID = hero.nodeID, entryID = hero.entryID, isChoice = true, isHero = true, rank = 1 }
    end
    for _, p in ipairs(plan.points) do
        local info = C_Traits.GetNodeInfo(configID, p.nodeID)
        seen[p.nodeID] = (seen[p.nodeID] or 0) + 1
        steps[#steps + 1] = {
            nodeID = p.nodeID,
            entryID = p.entryID,
            isChoice = info and IsChoiceType(info.type) or false,
            rank = seen[p.nodeID],
        }
    end
    return steps
end
