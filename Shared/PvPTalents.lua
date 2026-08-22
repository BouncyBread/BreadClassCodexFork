local _, ns = ...

local UGG_BRACKET = {
    ["pvp:2v2"] = "pvp-2v2",
    ["pvp:3v3"] = "pvp-3v3",
    ["pvp:shuffle"] = "pvp-shuffle",
    ["pvp:blitz"] = "pvp-blitz",
    ["pvp:rbg"] = "pvp-rbg",
}

local function GetBracketSpec(classToken, specKey)
    if not classToken or not specKey then return nil end
    local sd = ns.SourceSpec and ns.SourceSpec("ugg", classToken, specKey)
    if not sd or not sd.talents then return nil end
    local heroNames = (
        ClassCodexSource
        and ClassCodexSource.ugg
        and ClassCodexSource.ugg.reference
        and ClassCodexSource.ugg.reference.heroNames
    ) or {}
    local brackets = {}
    for heroSlug, byContext in pairs(sd.talents) do
        local heroDisplay = heroSlug ~= "all" and (heroNames[heroSlug] or heroSlug) or nil
        for context, builds in pairs(byContext) do
            local bracket = UGG_BRACKET[context]
            if bracket then
                local b = brackets[bracket] or { builds = {}, pvpTalentSets = {} }
                brackets[bracket] = b
                for _, build in ipairs(builds) do
                    b.builds[#b.builds + 1] = { exportString = build.export, heroTalent = heroDisplay }
                    if build.honor then b.pvpTalentSets[#b.pvpTalentSets + 1] = { talents = build.honor } end
                end
            end
        end
    end
    if not next(brackets) then return nil end
    return { brackets = brackets }
end

function ns.HasPvPData(classToken, specKey)
    return GetBracketSpec(classToken, specKey) ~= nil
end

function ns.IsInPvPInstance()
    if not IsInInstance then return false end
    local _, instanceType = IsInInstance()
    return instanceType == "arena" or instanceType == "pvp"
end

function ns.GetActivePvPBracket()
    if not IsInInstance then return nil end
    local _, instanceType = IsInInstance()
    if instanceType == "arena" then
        if C_PvP and C_PvP.IsSoloShuffle and C_PvP.IsSoloShuffle() then return "pvp-shuffle" end
        local size = GetNumGroupMembers and GetNumGroupMembers() or 0
        if size == 2 then return "pvp-2v2" end
        if size == 3 then return "pvp-3v3" end
        return nil
    elseif instanceType == "pvp" then
        if C_PvP and C_PvP.IsSoloRBG and C_PvP.IsSoloRBG() then return "pvp-blitz" end
        if C_PvP and C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground() then return "pvp-rbg" end
        return nil
    end
    return nil
end

local function ResolveLearnFn()
    if C_SpecializationInfo then
        if C_SpecializationInfo.LearnPvpTalent then return C_SpecializationInfo.LearnPvpTalent end
        if C_SpecializationInfo.SetPvpTalent then return C_SpecializationInfo.SetPvpTalent end
    end
    return nil
end

local function CanApplyPvpTalents()
    if not C_PvP then return false end
    if C_PvP.IsWarModeActive and C_PvP.IsWarModeActive() then return true end
    if IsInInstance then
        local _, instanceType = IsInInstance()
        if instanceType == "pvp" or instanceType == "arena" then return true end
    end
    return false
end

local recommendedHonor = {} -- recommended honor SPELL ids (from the previewed build)
local hasRecommendations = false
local marks = setmetatable({}, { __mode = "k" }) -- frame -> glow texture

local RED = { 1.0, 0.15, 0.15 }
local GREEN = { 0.2, 1.0, 0.3 }

-- A pvp talentID -> its spell id(s). The C_ getter doesn't exist on live; the
-- global one does but its return signature is fuzzy, so collect every numeric
-- return (and any table's spellID) as a candidate — only the real spell id can
-- match the recommended set.
local function TalentMatchesRecommended(pvpTalentID)
    if recommendedHonor[pvpTalentID] then return true end
    local getter = _G.GetPvpTalentInfoByID or (C_SpecializationInfo and C_SpecializationInfo.GetPvpTalentInfoByID)
    if not getter then return false end
    local res = { pcall(getter, pvpTalentID) }
    if not res[1] then return false end
    for i = 2, #res do
        local v = res[i]
        if type(v) == "number" and recommendedHonor[v] then
            return true
        elseif type(v) == "table" and type(v.spellID) == "number" and recommendedHonor[v.spellID] then
            return true
        end
    end
    return false
end

-- The set of currently-equipped pvp talentIDs. GetAllSelectedPvpTalentIDs is the
-- reliable source (GetPvpTalentSlotInfo.selectedTalentID comes back nil on live),
-- and equipped talents must be excluded from the "green" so the tray never lights.
local function SelectedPvpSet()
    local set = {}
    local getAll = C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs
    if getAll then
        local ok, ids = pcall(getAll)
        if ok and type(ids) == "table" then
            for _, id in ipairs(ids) do
                if type(id) == "number" then set[id] = true end
            end
        end
    end
    return set
end

-- The live picture from the pvp talent slots. availableTalentIDs is the SAME full
-- honor pool for every slot (talents aren't slot-locked), so "recommended" is a
-- SET of pool talents whose spell is in the honor set — not a per-slot pick.
--   recSet    : every pool talentID whose spell matches a recommended honor spell
--   selBySlot : the equipped talentID per slot (for the red check)
--   selSet    : all equipped talentIDs (excluded from the green)
local function SlotState()
    local getSlot = C_SpecializationInfo and C_SpecializationInfo.GetPvpTalentSlotInfo
    if not getSlot then return nil end
    local recSet, selBySlot = {}, {}
    local selSet = SelectedPvpSet()
    for i = 1, 3 do
        local ok, info = pcall(getSlot, i)
        if ok and type(info) == "table" then
            local sel = info.selectedTalentID
            selBySlot[i] = sel
            if sel then selSet[sel] = true end
            if type(info.availableTalentIDs) == "table" then
                for _, tid in ipairs(info.availableTalentIDs) do
                    if recSet[tid] == nil then recSet[tid] = TalentMatchesRecommended(tid) end
                end
            end
        end
    end
    return recSet, selBySlot, selSet
end

local function EnsureGlow(frame)
    if frame._ccPvpGlow then return frame._ccPvpGlow end
    local m = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    m:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    m:SetBlendMode("ADD")
    m:SetPoint("CENTER", frame, "CENTER", 0, 0)
    local w, h = frame:GetSize()
    if not w or w == 0 then
        w, h = 34, 34
    end
    m:SetSize(w * 1.55, h * 1.55)
    frame._ccPvpGlow = m
    marks[frame] = m
    return m
end

local function ShowGlow(frame, color)
    local m = EnsureGlow(frame)
    m:SetVertexColor(color[1], color[2], color[3])
    m:Show()
end

local function ClearMarks()
    for _, m in pairs(marks) do
        m:Hide()
    end
end

-- Flyout: green the rows that are recommended but not currently selected. Slot
-- (tray) buttons always show a selected talent, so they're excluded here — the
-- red on the tray is handled separately.
local function WalkGreen(frame, depth, recSet, selSet)
    if type(frame) ~= "table" or (depth or 0) > 8 then return end
    if frame.GetObjectType then
        local tid = frame.talentID
        if
            type(tid) == "number"
            and recSet[tid]
            and not selSet[tid]
            and not (frame.GetNodeID or frame.nodeInfo or frame.nodeID or frame.GetNodeInfo)
        then
            pcall(ShowGlow, frame, GREEN)
        end
    end
    if frame.GetChildren then
        for i = 1, select("#", frame:GetChildren()) do
            WalkGreen(select(i, frame:GetChildren()), (depth or 0) + 1, recSet, selSet)
        end
    end
end

local function PvpSlotFrames()
    local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not tf then return nil end
    local tray = tf.PvPTalentSlotTray or tf.PvpTalentSlotTray
    if not tray then return nil end
    if type(tray.Slots) == "table" and tray.Slots[1] then return tray.Slots end
    local out = {}
    for i = 1, 3 do
        out[i] = tray["Slot" .. i] or tray["slot" .. i]
    end
    return (out[1] or out[2] or out[3]) and out or nil
end

local function RefreshHonorMarks()
    ClearMarks()
    if not hasRecommendations then return end
    if not (PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame) then return end
    local recSet, selBySlot, selSet = SlotState()
    if not recSet then return end
    -- Tray slots: red only when the equipped talent is NOT one of the recommended
    -- talents (correct = untinted). Fall back to the slot frame's own talent id.
    local slots = PvpSlotFrames()
    if slots then
        for i = 1, 3 do
            local frame = slots[i]
            local equipped = selBySlot[i]
            if equipped == nil and frame and type(frame.talentID) == "number" then equipped = frame.talentID end
            if frame and equipped and not recSet[equipped] then pcall(ShowGlow, frame, RED) end
        end
    end
    -- Flyout: green the recommended talents that aren't equipped yet.
    pcall(WalkGreen, PlayerSpellsFrame.TalentsFrame, 0, recSet, selSet)
end

function ns.SetRecommendedHonorTalents(ids)
    wipe(recommendedHonor)
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            recommendedHonor[id] = true
        end
    end
    hasRecommendations = next(recommendedHonor) ~= nil
    RefreshHonorMarks()
end

local highlightInstalled = false
function ns.InstallPvpTalentHighlight()
    if highlightInstalled then return end
    if not (PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame) then return end
    highlightInstalled = true
    local function schedule(delay)
        if C_Timer and C_Timer.After then
            C_Timer.After(delay or 0, RefreshHonorMarks)
        else
            RefreshHonorMarks()
        end
    end
    local tf = PlayerSpellsFrame.TalentsFrame
    if tf.HookScript then
        tf:HookScript("OnShow", function()
            schedule(0)
        end)
        tf:HookScript("OnMouseUp", function()
            schedule(0.05)
        end)
    end
    local list = tf.PvPTalentList
    if list and list.HookScript then
        list:HookScript("OnShow", function()
            schedule(0)
        end)
        list:HookScript("OnMouseUp", function()
            schedule(0.05)
        end)
    end
    schedule(0)
end

function ns.ApplyPvpHonorTalents(talentIds)
    if not talentIds or type(talentIds) ~= "table" or #talentIds == 0 then return false end
    local fn = ResolveLearnFn()
    if not fn then return false end
    if not CanApplyPvpTalents() then
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage("Honor talents will apply once you enter War Mode or a PvP instance.", 1, 0.82, 0)
        end
        return false
    end
    local applied = 0
    for slot, talentId in ipairs(talentIds) do
        if slot > 3 then break end
        local ok = pcall(fn, talentId, slot)
        if ok then applied = applied + 1 end
    end
    if applied > 0 then
        print(string.format("|cff00ccffBread Codex:|r Applied %d PvP talent%s.", applied, applied == 1 and "" or "s"))
    end
    return applied > 0
end
