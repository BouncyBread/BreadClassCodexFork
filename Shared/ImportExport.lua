local _, ns = ...

if not ExportUtil or not C_Traits or not C_ClassTalents then
    function ns.ApplyTalentExportString()
        return nil, "Required talent APIs not available"
    end
    return
end

local BIT_WIDTH_HEADER_VERSION = 8
local BIT_WIDTH_SPEC_ID = 16
local BIT_WIDTH_RANKS_PURCHASED = 6

local function Msg(text)
    print("|cff00ccffBread Codex:|r " .. text)
end

local function GetSpecID()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    return (GetSpecializationInfo(specIndex))
end

local function GetTreeID()
    local configInfo = C_Traits.GetConfigInfo(C_ClassTalents.GetActiveConfigID())
    return configInfo and configInfo.treeIDs and configInfo.treeIDs[1]
end

local function ReadLoadoutHeader(importStream)
    local headerBitWidth = BIT_WIDTH_HEADER_VERSION + BIT_WIDTH_SPEC_ID + 128
    if importStream:GetNumberOfBits() < headerBitWidth then return false, 0, 0 end
    local serializationVersion = importStream:ExtractValue(BIT_WIDTH_HEADER_VERSION)
    local specID = importStream:ExtractValue(BIT_WIDTH_SPEC_ID)

    local treeHash = {}
    for i = 1, 16 do
        treeHash[i] = importStream:ExtractValue(8)
    end
    return true, serializationVersion, specID, treeHash
end

local function ReadLoadoutContent(importStream, treeID)
    local results = {}
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    for i, nodeID in ipairs(treeNodes) do
        local isNodeSelected = importStream:ExtractValue(1) == 1
        local isNodePurchased = false
        local isPartiallyRanked = false
        local partialRanksPurchased = 0
        local isChoiceNode = false
        local choiceNodeSelection = 0

        if isNodeSelected then
            isNodePurchased = importStream:ExtractValue(1) == 1
            if isNodePurchased then
                isPartiallyRanked = importStream:ExtractValue(1) == 1
                if isPartiallyRanked then
                    partialRanksPurchased = importStream:ExtractValue(BIT_WIDTH_RANKS_PURCHASED)
                end
                isChoiceNode = importStream:ExtractValue(1) == 1
                if isChoiceNode then choiceNodeSelection = importStream:ExtractValue(2) end
            end
        end

        results[i] = {
            nodeID = nodeID,
            isNodeSelected = isNodeSelected,
            isNodeGranted = isNodeSelected and not isNodePurchased,
            isNodePurchased = isNodePurchased,
            isPartiallyRanked = isPartiallyRanked,
            partialRanksPurchased = partialRanksPurchased,
            isChoiceNode = isChoiceNode,
            choiceNodeSelection = choiceNodeSelection + 1,
        }
    end
    return results
end

local function ConvertToEntryInfo(configID, treeID, loadoutContent)
    local results = {}
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    for i, treeNodeID in ipairs(treeNodes) do
        local indexInfo = loadoutContent[i]
        if indexInfo and indexInfo.isNodePurchased then
            local nodeInfo = C_Traits.GetNodeInfo(configID, treeNodeID)
            if nodeInfo and nodeInfo.ID ~= 0 then
                local isChoice = nodeInfo.type == Enum.TraitNodeType.Selection
                    or nodeInfo.type == Enum.TraitNodeType.SubTreeSelection
                local choiceIdx = indexInfo.isChoiceNode and indexInfo.choiceNodeSelection or nil
                if isChoice ~= indexInfo.isChoiceNode then choiceIdx = 1 end
                local selectionEntryID
                if isChoice and choiceIdx and nodeInfo.entryIDs then
                    -- The import's 2-bit choice field allows 1..3; a 2-entry
                    -- node with a "3" resolves to nil, and SetSelection with a
                    -- nil entry ID hard-crashes the client. Clamp and skip the
                    -- node entirely when nothing valid resolves.
                    choiceIdx = math.min(choiceIdx, #nodeInfo.entryIDs)
                    selectionEntryID = nodeInfo.entryIDs[choiceIdx]
                elseif nodeInfo.activeEntry then
                    selectionEntryID = nodeInfo.activeEntry.entryID
                end
                local ranks = nodeInfo.maxRanks or 1
                if indexInfo.isPartiallyRanked then ranks = indexInfo.partialRanksPurchased end
                ranks = math.max(1, math.min(ranks, nodeInfo.maxRanks or ranks))

                -- A choice node with no resolvable entry must be skipped
                -- entirely: staging it leaves an unfulfillable entry a later
                -- pass could act on with a nil entry ID. (Lua 5.1: no goto.)
                if not (isChoice and not selectionEntryID) then
                    results[treeNodeID] = {
                        nodeID = treeNodeID,
                        ranksPurchased = ranks,
                        selectionEntryID = selectionEntryID,
                        isChoiceNode = isChoice,
                    }
                end
            end
        end
    end
    return results
end

local function ParseExportString(exportString, treeID, expectedSpecID, configID)
    local ok, importStream = pcall(ExportUtil.MakeImportDataStream, exportString)
    if not ok or not importStream then return nil, "Failed to decode export string" end

    local headerValid, version, specID = ReadLoadoutHeader(importStream)
    if not headerValid then return nil, "Invalid export string" end
    if version ~= C_Traits.GetLoadoutSerializationVersion() then return nil, "Serialization version mismatch" end

    local checkAgainst = expectedSpecID or GetSpecID()
    if specID ~= checkAgainst then return nil, format("Export is for specID %d, active is %d", specID, checkAgainst) end

    local loadoutContent = ReadLoadoutContent(importStream, treeID)
    local effectiveConfigID = configID or C_ClassTalents.GetActiveConfigID()
    local entryInfo = ConvertToEntryInfo(effectiveConfigID, treeID, loadoutContent)

    return entryInfo
end

function ns.ParseLoadoutNodes(exportString)
    if not exportString or exportString == "" then return nil, "Empty export string" end
    local treeID, configID, expectedSpecID

    if ns._talentPaneInspect then
        local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
        if tf and tf.GetConfigID then
            local ok, id = pcall(tf.GetConfigID, tf)
            if ok then configID = id end
        end
        if not configID then
            configID = (Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID) or -1
        end
        local info = C_Traits.GetConfigInfo(configID)
        treeID = info and info.treeIDs and info.treeIDs[1]
        expectedSpecID = ns._talentPaneInspect.specID
    else
        treeID = GetTreeID()
    end
    if not treeID then return nil, "Cannot determine talent tree" end
    return ParseExportString(exportString, treeID, expectedSpecID, configID)
end

local BATCH_SIZE = 100
local applyToken = 0

-- Purchase order groups: main tree (class + spec) first so row/point gates
-- unlock top-down, hero subtree after (its nodes' posY is subtree-relative and
-- the subtree only unlocks once class points are spent), apex last (level-gated,
-- not points-gated), unknown-node info last so a nil GetNodeInfo can't throw
-- inside the sort and silently kill the deferred apply.
local function PurchaseOrderKey(configID, nodeID)
    local info = C_Traits.GetNodeInfo(configID, nodeID)
    local group
    if not info then
        group = 3
    elseif info.type == Enum.TraitNodeType.SubTreeSelection then
        -- Hero talent pick goes before ANY purchase: swapping the selected
        -- hero on a config that already has staged purchases hard-crashes the
        -- client (deterministic on hero-swapping builds, e.g. Prot Paladin
        -- Lightsmith applied from a Templar character). Blizzard's own flow
        -- also picks the hero first, then spends points.
        group = -1
    elseif info.isApexNode or (Enum.TraitNodeType.Apex and info.type == Enum.TraitNodeType.Apex) then
        group = 2
    elseif info.subTreeID and info.subTreeID > 0 then
        group = 1
    else
        group = 0
    end
    return group, info and (info.posY or 0) or 0, info and (info.posX or 0) or 0
end

local function ResetAndPurchaseDeferred(configID, treeID, entryInfo, onComplete)
    applyToken = applyToken + 1
    local myToken = applyToken

    -- ResetTree on a config that is still mid-load hard-crashes the client;
    -- a failed reset leaves the state machine grinding against stale state.
    local resetOK = select(1, pcall(C_Traits.ResetTree, configID, treeID))
    if not resetOK then
        Msg("|cffff0000Could not reset talent tree — apply aborted, try again in a moment.|r")
        if onComplete then onComplete() end
        return
    end

    local orderedNodes = C_Traits.GetTreeNodes(treeID)
    local keys = {}
    for _, nodeID in ipairs(orderedNodes) do
        keys[nodeID] = { PurchaseOrderKey(configID, nodeID) }
    end
    table.sort(orderedNodes, function(a, b)
        local ka, kb = keys[a], keys[b]
        if ka[1] ~= kb[1] then return ka[1] < kb[1] end
        if ka[2] ~= kb[2] then return ka[2] < kb[2] end
        return ka[3] < kb[3]
    end)

    local i = 1
    local passProgress = 0

    local zeroPasses = 0
    local MAX_ZERO_PASSES = 20

    -- Progress passes were previously unbounded: any pass with a single
    -- successful purchase restarted a full pass forever, hammering the trait
    -- system if a node never reached its target. Give up after this many
    -- total passes and let onComplete report the leftover nodes.
    local totalPasses = 0
    local MAX_TOTAL_PASSES = 50

    local function step()
        if myToken ~= applyToken then return end
        local processed = 0
        while i <= #orderedNodes and processed < BATCH_SIZE do
            local nodeID = orderedNodes[i]
            local entry = entryInfo[nodeID]
            if entry then
                local madeProgress = false
                local complete = false
                if entry.isChoiceNode then
                    local ok, result
                    if entry.selectionEntryID then
                        ok, result = pcall(C_Traits.SetSelection, configID, entry.nodeID, entry.selectionEntryID)
                    end
                    if ok and result then
                        madeProgress = true
                        complete = true
                    end
                elseif entry.ranksPurchased then
                    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                    local have = nodeInfo and nodeInfo.ranksPurchased or 0
                    if have >= entry.ranksPurchased then
                        -- Ranks already satisfied (e.g. auto-granted baseline
                        -- nodes): complete without a doomed PurchaseRank call.
                        complete = true
                    else
                        for _ = have + 1, entry.ranksPurchased do
                            local ok, result = pcall(C_Traits.PurchaseRank, configID, entry.nodeID)
                            if ok and result then
                                madeProgress = true
                            else
                                break
                            end
                        end
                        local afterInfo = C_Traits.GetNodeInfo(configID, nodeID)
                        complete = (afterInfo and afterInfo.ranksPurchased or have) >= entry.ranksPurchased
                    end
                end
                if madeProgress then passProgress = passProgress + 1 end
                if complete then entryInfo[nodeID] = nil end
            end
            i = i + 1
            processed = processed + 1
        end

        local moreNodes = i <= #orderedNodes
        if moreNodes then
            C_Timer.After(0, step)
        elseif totalPasses < MAX_TOTAL_PASSES and passProgress > 0 then
            totalPasses = totalPasses + 1
            i = 1
            passProgress = 0
            zeroPasses = 0
            C_Timer.After(0, step)
        elseif next(entryInfo) ~= nil and totalPasses < MAX_TOTAL_PASSES and zeroPasses < MAX_ZERO_PASSES then
            zeroPasses = zeroPasses + 1
            totalPasses = totalPasses + 1
            i = 1
            passProgress = 0
            C_Timer.After(0, step)
        else
            if onComplete then onComplete() end
        end
    end

    step()
end

local CC_NAME = "Bread Codex"
-- Loadouts created before the rename (and any created by upstream Class Codex)
-- are still ours to reuse. Without this they read as user loadouts, so the
-- addon never reclaims its own slot and keeps creating new ones until the
-- player runs out — "No free loadout slots".
local LEGACY_CC_NAMES = { "Class Codex", "Bread Class Codex" }
local pendingApply = nil
local pendingApplySeq = 0

local PENDING_APPLY_WATCHDOG_SECS = 10
local function SetPendingApply(pa)
    pendingApplySeq = pendingApplySeq + 1
    local mySeq = pendingApplySeq
    pendingApply = pa
    C_Timer.After(PENDING_APPLY_WATCHDOG_SECS, function()
        if pendingApplySeq ~= mySeq then return end

        pendingApply = nil
        ns._talentApplyInProgress = false
        if ns._refreshTalentDiff then ns._refreshTalentDiff() end
    end)
end

local function ClearPendingApply()
    pendingApplySeq = pendingApplySeq + 1
    pendingApply = nil
end

local function ClearStoredConfigID(specID)
    if not ClassCodexCharDB or not ClassCodexCharDB.ccLoadout then return end
    if specID then ClassCodexCharDB.ccLoadout[specID] = nil end
end

local function IsCCSlotName(name)
    if type(name) ~= "string" then return false end
    if name == CC_NAME then return true end
    if name:sub(1, #CC_NAME + 2) == CC_NAME .. ": " then return true end
    for _, legacy in ipairs(LEGACY_CC_NAMES) do
        if name == legacy then return true end
        if name:sub(1, #legacy + 2) == legacy .. ": " then return true end
    end
    return false
end

ns.IsCCSlotName = IsCCSlotName

ns.CC_LOADOUT_COLOR = CreateColor(0, 0.8, 1)
function ns.WrapCCName(name)
    return ns.CC_LOADOUT_COLOR:WrapTextInColorCode(name)
end

local function GetStoredConfigID()
    local specID = GetSpecID()
    if not specID or not ClassCodexCharDB then return nil end
    local stored = ClassCodexCharDB.ccLoadout and ClassCodexCharDB.ccLoadout[specID]
    if not stored then return nil end

    local liveIDs
    if C_ClassTalents.GetConfigIDsBySpecID then liveIDs = C_ClassTalents.GetConfigIDsBySpecID(specID) end
    if liveIDs then
        local found = false
        for _, id in ipairs(liveIDs) do
            if id == stored then
                found = true
                break
            end
        end
        if not found then
            ClearStoredConfigID(specID)
            return nil
        end
    end

    local ok, info = pcall(C_Traits.GetConfigInfo, stored)
    if not ok or not info then
        ClearStoredConfigID(specID)
        return nil
    end
    if not IsCCSlotName(info.name) then
        ClearStoredConfigID(specID)
        return nil
    end
    return stored
end

local function StoreConfigID(configID)
    local specID = GetSpecID()
    if not specID or not ClassCodexCharDB then return end
    if not ClassCodexCharDB.ccLoadout then ClassCodexCharDB.ccLoadout = {} end
    ClassCodexCharDB.ccLoadout[specID] = configID
end

local function FindExistingCCSlot()
    local specID = GetSpecID()
    if not specID or not C_ClassTalents.GetConfigIDsBySpecID then return nil end
    local liveIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if not liveIDs then return nil end
    for _, id in ipairs(liveIDs) do
        local ok, info = pcall(C_Traits.GetConfigInfo, id)
        if ok and info and IsCCSlotName(info.name) then return id end
    end
    return nil
end

-- Blizzard rejects loadout names containing markup (the dock menu prefixes
-- hero-talent atlas icons to labels). Strip texture/color escapes before renaming.
local function SanitizeLoadoutName(name)
    if type(name) ~= "string" then return name end
    name = name:gsub("|A.-|a", ""):gsub("|T.-|t", "")
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    -- drop the " - " separator source labels use (e.g. "Icy Veins - Build")
    name = name:gsub(" %- ", " ")
    if name == "" then return nil end
    return name
end

-- RenameConfig returns a success boolean that Blizzard can deny (e.g. when the
-- name contains escape markup, or while the config system is still settling
-- after a commit). Sanitize the name, check the result, retry a few times, and
-- say so loudly if the name never lands.
local function RenameCCConfig(configID, name, where)
    name = SanitizeLoadoutName(name)
    if not (configID and name and C_ClassTalents.RenameConfig) then return end
    local function Try(n)
        local ok, result = pcall(C_ClassTalents.RenameConfig, configID, name)
        if ok and result ~= false then
            if ns.NoteCCApplyComplete then
                ns.NoteCCApplyComplete(configID)
            elseif ns.RefreshLoadoutDock then
                ns.RefreshLoadoutDock()
            end
            return
        end
        if n >= 5 then
            Msg(
                string.format(
                    "|cffff0000Loadout rename rejected (%s): %s.|r",
                    where or "unknown site",
                    ok and "RenameConfig returned false" or tostring(result)
                )
            )
            return
        end
        C_Timer.After(0.25, function()
            Try(n + 1)
        end)
    end
    Try(1)
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "TRAIT_CONFIG_CREATED" then
        if type(arg1) ~= "table" then return end
        if not pendingApply then return end
        if arg1.type ~= Enum.TraitConfigType.Combat then return end

        if arg1.name ~= CC_NAME then return end
        self:UnregisterEvent("TRAIT_CONFIG_CREATED")
        StoreConfigID(arg1.ID)

        local pa = pendingApply
        RunNextFrame(function()
            ns.ApplyTalentExportString(pa.exportString, pa.buildLabel, true)
        end)
    elseif event == "TRAIT_CONFIG_UPDATED" then
        if arg1 ~= C_ClassTalents.GetActiveConfigID() then return end
        if not pendingApply then return end
        self:UnregisterEvent("TRAIT_CONFIG_UPDATED")
        local pa = pendingApply
        if pa.renameOnly then
            -- Rename must fire immediately, synchronously inside the commit's
            -- own event — deferring even one frame gets it rejected by
            -- Blizzard (verified in-game: "Blizzard rejected the loadout
            -- rename"). This matches the long-working pre-existing behavior;
            -- RenameCCConfig adds only success checking and retries on top.
            RenameCCConfig(pa.target, pa.finalName, "commit-event")
            if ns.NoteCCApplyComplete then
                ns.NoteCCApplyComplete(pa.target)
            elseif ns.RefreshLoadoutDock then
                ns.RefreshLoadoutDock()
            end
            Msg("Talents applied: " .. (pa.buildLabel or "build"))
            ClearPendingApply()

            RunNextFrame(function()
                ns._talentApplyInProgress = false
                if ns._refreshTalentDiff then ns._refreshTalentDiff() end
            end)
        else
            RunNextFrame(function()
                ns.ApplyTalentExportString(pa.exportString, pa.buildLabel, true)
            end)
        end
    end
end)

local function StageAndCommit(targetConfigID, activeConfigID, entryInfo, treeID, buildLabel, finalName)
    local originalNodeCount = 0
    for _ in pairs(entryInfo) do
        originalNodeCount = originalNodeCount + 1
    end

    ns._talentApplyInProgress = true
    ResetAndPurchaseDeferred(activeConfigID, treeID, entryInfo, function()
        if not C_Traits.ConfigHasStagedChanges(activeConfigID) then
            ns._talentApplyInProgress = false

            if finalName and C_ClassTalents.RenameConfig and targetConfigID then
                RenameCCConfig(targetConfigID, finalName, "no-staged-changes")
                Msg("Renamed loadout to " .. (buildLabel or "Build"))
            else
                Msg("Already using this build.")
            end
            ClearPendingApply()
            return
        end

        local remainingNodes = 0
        for _ in pairs(entryInfo) do
            remainingNodes = remainingNodes + 1
        end
        if remainingNodes > 0 then
            local applied = originalNodeCount - remainingNodes
            local names = {}
            for nodeID in pairs(entryInfo) do
                local info = C_Traits.GetNodeInfo(activeConfigID, nodeID)
                if info and info.name then names[#names + 1] = info.name end
            end
            table.sort(names)
            local shown = #names > 5 and 5 or #names
            local nameList = table.concat(names, ", ", 1, shown)
            if #names > shown then nameList = nameList .. string.format(" (+%d more)", #names - shown) end
            Msg(
                string.format(
                    "Applying %d of %d nodes — your current level can't fit the rest (%s). Level up and re-apply to fill in the remaining %d.",
                    applied,
                    originalNodeCount,
                    nameList,
                    remainingNodes
                )
            )
        end

        if not C_ClassTalents.CommitConfig(targetConfigID) then
            ns._talentApplyInProgress = false
            Msg("|cffff0000Commit failed.|r Open talent frame and click Apply Changes.")
            ClearPendingApply()
            return
        end

        SetPendingApply({
            buildLabel = buildLabel,
            renameOnly = true,
            target = targetConfigID,
            finalName = finalName,
        })
        eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")

        if C_ClassTalents.UpdateLastSelectedSavedConfigID then
            local specID = GetSpecID()
            if specID then C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, targetConfigID) end
        end
    end)

    return true
end

local function Fail(msg)
    ClearPendingApply()
    return nil, msg
end

-- Event-driven continuations (TRAIT_CONFIG_CREATED / TRAIT_CONFIG_UPDATED ->
-- re-invoke ApplyTalentExportString) previously had no cap: a config that kept
-- reporting LoadInProgress re-loaded and reset itself forever, and resetting a
-- config mid-load hard-crashes the client. Cap how many times one apply may be
-- re-entered before giving up.
local applyContinuations = 0
local MAX_APPLY_CONTINUATIONS = 8

function ns.ApplyTalentExportString(exportString, buildLabel, isContinuation)
    if not exportString or exportString == "" then return Fail("Empty export string") end

    if pendingApply and not isContinuation then return nil, "Apply already in progress — wait for it to finish." end

    if isContinuation then
        applyContinuations = applyContinuations + 1
        if applyContinuations > MAX_APPLY_CONTINUATIONS then
            return Fail(
                "Talent apply did not settle after "
                    .. MAX_APPLY_CONTINUATIONS
                    .. " attempts — the config system is busy. Try again in a moment."
            )
        end
    else
        applyContinuations = 0
    end

    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    if not activeConfigID then return Fail("No active talent configuration") end

    if InCombatLockdown and InCombatLockdown() then return Fail("Cannot change talents in combat.") end

    -- The talent pane blocks applying during an inspect; the character panel
    -- and dock did not, and trait API calls against the inspect config can
    -- hard-crash the client. Guard centrally.
    if PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting() then
        return Fail("Cannot apply a build while inspecting another player — close the inspect first.")
    end

    if not isContinuation and C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(activeConfigID) then
        return Fail(
            "You have unsaved talent changes. Open the talents pane and click Apply Changes (or right-click the loadout name to discard) before applying a Bread Codex build."
        )
    end

    -- Compare talent signatures before anything else: GetLastSelectedSavedConfigID
    -- can lag behind a just-finished apply, and without this check the stale
    -- path re-loads the already-active loadout and resets a config mid-load,
    -- which hard-crashes the client. Only short-circuit when nothing is staged:
    -- after a LoadConfig continuation the target build may be staged but not
    -- committed yet, and those staged changes still need StageAndCommit.
    if ns.ExtractTalentBits and ns.GetActiveTalentSignature then
        local hasStagedChanges = C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(activeConfigID)
        if not hasStagedChanges then
            -- Always compare against the PLAYER's config: reading through a
            -- stale inspect override generates against the inspect sentinel
            -- config, which hard-crashes the client.
            local activeBits = ns.GetActiveTalentSignature(true)
            local newBits = ns.ExtractTalentBits(exportString)
            if activeBits and newBits and activeBits == newBits then
                local ccConfigID = GetStoredConfigID()
                if ccConfigID and C_ClassTalents.RenameConfig then
                    RenameCCConfig(ccConfigID, CC_NAME .. ": " .. (buildLabel or "Build"), "already-applied")
                    Msg("Renamed loadout to " .. (buildLabel or "Build"))
                else
                    Msg("Already using this build.")
                end
                ClearPendingApply()
                return true
            end
        end
    end

    local treeID = GetTreeID()
    if not treeID then return Fail("Cannot determine talent tree") end

    local entryInfo, parseErr = ParseExportString(exportString, treeID)
    if not entryInfo then return Fail(parseErr) end

    local ccConfigID = GetStoredConfigID()
    if not ccConfigID then
        ccConfigID = FindExistingCCSlot()
        if ccConfigID then StoreConfigID(ccConfigID) end
    end
    if not ccConfigID then
        if C_ClassTalents.CanCreateNewConfig and not C_ClassTalents.CanCreateNewConfig() then
            return Fail("No free loadout slots — delete one to use Bread Codex builds")
        end
        C_ClassTalents.RequestNewConfig(CC_NAME)
        SetPendingApply({ exportString = exportString, buildLabel = buildLabel })
        eventFrame:RegisterEvent("TRAIT_CONFIG_CREATED")
        Msg("Creating loadout slot...")
        return true
    end

    local specID = GetSpecID()
    local currentLoadoutID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    if currentLoadoutID ~= ccConfigID then
        local result = C_ClassTalents.LoadConfig(ccConfigID, true)
        if result == Enum.LoadConfigResult.LoadInProgress then
            SetPendingApply({ exportString = exportString, buildLabel = buildLabel })
            eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
            return true
        elseif result == Enum.LoadConfigResult.Error then
            ClearStoredConfigID(specID)
            return Fail(
                "Could not load Bread Codex loadout. Open the talents pane and click Apply Changes, then try again."
            )
        end
    end

    -- LoadConfig may have swapped the active config: re-resolve the config and
    -- tree together. ResetTree/PurchaseRank with a configID/treeID pair that no
    -- longer matches hard-crashes the client, and treeID is derived from the
    -- active config, so a stale treeID from before the load is exactly that.
    activeConfigID = C_ClassTalents.GetActiveConfigID()
    if not activeConfigID then return Fail("Talent configuration is still loading — try again in a moment.") end
    local loadedTreeID = GetTreeID()
    if loadedTreeID and loadedTreeID ~= treeID then
        -- Config changed under us mid-apply (e.g. a load raced a spec/hero
        -- swap): the parsed entryInfo targets the old tree, so bail out.
        return Fail("Talent tree changed while applying — try again.")
    end

    return StageAndCommit(
        ccConfigID,
        activeConfigID,
        entryInfo,
        treeID,
        buildLabel,
        CC_NAME .. ": " .. (buildLabel or "Build")
    )
end

local function ReadImportHeader(stream)
    local headerBits = BIT_WIDTH_HEADER_VERSION + BIT_WIDTH_SPEC_ID + 128
    if stream:GetNumberOfBits() < headerBits then return false end
    local version = stream:ExtractValue(BIT_WIDTH_HEADER_VERSION)
    local specID = stream:ExtractValue(BIT_WIDTH_SPEC_ID)
    for _ = 1, 16 do
        stream:ExtractValue(8)
    end
    return true, version, specID
end

local function ReadImportContent(stream, treeID)
    local results = {}
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    for i = 1, #treeNodes do
        local r = {
            isNodeSelected = false,
            isNodeGranted = false,
            isPartiallyRanked = false,
            partialRanksPurchased = 0,
            isChoiceNode = false,
            choiceNodeSelection = 1,
        }
        if stream:ExtractValue(1) == 1 then
            r.isNodeSelected = true
            local isPurchased = stream:ExtractValue(1) == 1
            r.isNodeGranted = not isPurchased
            if isPurchased then
                r.isPartiallyRanked = stream:ExtractValue(1) == 1
                if r.isPartiallyRanked then r.partialRanksPurchased = stream:ExtractValue(BIT_WIDTH_RANKS_PURCHASED) end
                r.isChoiceNode = stream:ExtractValue(1) == 1
                if r.isChoiceNode then r.choiceNodeSelection = stream:ExtractValue(2) + 1 end
            end
        end
        results[i] = r
    end
    return results
end

local function ImportEntryFromSingleNode(results, nodeInfo, idx)
    if not nodeInfo or not idx or not idx.isNodeSelected then return end
    local r = { nodeID = nodeInfo.ID, ranksGranted = idx.isNodeGranted and 1 or 0 }
    if idx.isNodeSelected and not idx.isNodeGranted then
        r.ranksPurchased = idx.isPartiallyRanked and idx.partialRanksPurchased or nodeInfo.maxRanks
    else
        r.ranksPurchased = 0
    end
    if idx.isChoiceNode and idx.choiceNodeSelection and nodeInfo.entryIDs then
        r.selectionEntryID = nodeInfo.entryIDs[idx.choiceNodeSelection]
    elseif nodeInfo.activeEntry then
        r.selectionEntryID = nodeInfo.activeEntry.entryID
    end
    if not r.selectionEntryID and nodeInfo.entryIDs then r.selectionEntryID = nodeInfo.entryIDs[1] end
    if r.selectionEntryID ~= nil then results[#results + 1] = r end
end

local function ImportEntryFromTieredNode(results, configID, nodeInfo, idx)
    if not nodeInfo or not idx or not idx.isNodeSelected then return end
    local total = 0
    if not idx.isNodeGranted then total = idx.isPartiallyRanked and idx.partialRanksPurchased or nodeInfo.maxRanks end
    local remaining = total
    for index, entryID in ipairs(nodeInfo.entryIDs or {}) do
        local ei = C_Traits.GetEntryInfo(configID, entryID)
        if ei then
            local ranks = math.min(remaining, ei.maxRanks or 0)
            local isGranted = idx.isNodeGranted and index == 1
            if ranks > 0 or isGranted then
                results[#results + 1] = {
                    nodeID = nodeInfo.ID,
                    ranksGranted = isGranted and 1 or 0,
                    ranksPurchased = ranks,
                    selectionEntryID = entryID,
                }
            end
            remaining = remaining - ranks
        end
    end
end

local function ParseImportEntries(exportString, configID, treeID)
    if not ExportUtil or not ExportUtil.MakeImportDataStream then return nil, "Import not supported by this client." end
    local ok, stream = pcall(ExportUtil.MakeImportDataStream, exportString)
    if not ok or not stream then return nil, "Failed to decode export string" end
    local hok, version = ReadImportHeader(stream)
    if not hok then return nil, "Bad export string" end
    if C_Traits.GetLoadoutSerializationVersion and version ~= C_Traits.GetLoadoutSerializationVersion() then
        return nil, "Build string is from a different game version — re-copy it."
    end
    local content = ReadImportContent(stream, treeID)
    local results = {}
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    for index = 1, #treeNodes do
        local nodeInfo = C_Traits.GetNodeInfo(configID, treeNodes[index])
        if nodeInfo then
            if nodeInfo.type == Enum.TraitNodeType.Tiered then
                ImportEntryFromTieredNode(results, configID, nodeInfo, content[index])
            else
                ImportEntryFromSingleNode(results, nodeInfo, content[index])
            end
        end
    end
    return results
end

function ns.SaveTalentBuildAsNewLoadout(exportString, buildLabel, userName)
    if not exportString or exportString == "" then return nil, "Empty export string" end
    if not userName or userName == "" then return nil, "Loadout name is required" end

    if IsCCSlotName(userName) then
        return nil, '"' .. CC_NAME .. '" is reserved for Bread Codex — pick a different name.'
    end
    if InCombatLockdown and InCombatLockdown() then return nil, "Cannot change talents in combat." end
    if not C_ClassTalents.ImportLoadout then return nil, "This game version doesn't support saving loadouts." end
    if C_ClassTalents.CanCreateNewConfig and not C_ClassTalents.CanCreateNewConfig() then
        return nil, "No free loadout slots — delete one to save a new build."
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil, "No active talent configuration" end

    local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if tf and tf.ImportLoadout and tf.IsShown and tf:IsShown() then
        local ok, res = pcall(tf.ImportLoadout, tf, exportString, userName)
        if ok and res ~= false then
            if ns.RefreshLoadoutDock then ns.RefreshLoadoutDock() end
            return true
        end
        if ok and res == false then return nil, "Couldn't save the loadout — check the build string." end
    end

    local treeID = GetTreeID()
    if not treeID then return nil, "Cannot determine talent tree" end
    local entries, parseErr = ParseImportEntries(exportString, configID, treeID)
    if not entries then return nil, parseErr end
    local ok, importErr = C_ClassTalents.ImportLoadout(configID, entries, userName, exportString)
    if not ok then return nil, importErr or "Import failed" end
    Msg("Saved loadout '" .. userName .. "'.")
    if ns.RefreshLoadoutDock then ns.RefreshLoadoutDock() end
    return true
end
