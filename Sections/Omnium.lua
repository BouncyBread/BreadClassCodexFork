local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

local Omnium = {}
ns.Sections.Omnium = Omnium

local MAX_WEEKS = 12
local LIST_ICON = 32
local SLOT_RATIO = 1.8125
local SLOT_FRAME = math.floor(LIST_ICON * SLOT_RATIO + 0.5)
local SLOT_OVERHANG = math.floor((SLOT_FRAME - LIST_ICON) / 2)
local ROW_HEIGHT = 40
local INSET_X = 10
local TEXT_X = INSET_X + LIST_ICON + SLOT_OVERHANG + 4

local MAX_NODES = 40
local ICON_SIZE = 30
local BLIZ_ICON = 36
local CELL = 36
local ROW_GAP = 3
local FLYOUT_GAP = -1
local FLYOUT_SCALE = 1.1
local QUESTION_ICON = 134400

local SELECT_SOUND = (
    SOUNDKIT
    and (
        SOUNDKIT.UI_CLASS_TALENT_LEARN_TALENT
        or SOUNDKIT.UI_CLASS_TALENT_APPLY_COMPLETE
        or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
    )
) or nil
local PURCHASE_FX_IDS = { 150, 142, 143 }
local CHECK_ATLAS = "common-icon-checkmark"
local REC_STAR = "Interface\\Common\\FavoritesIcon"

local flyout
local fxScene

local function SpellName(spellId, fallback)
    local n = spellId and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId)
    return n or fallback or ""
end
local function SpellTexture(spellId)
    return spellId and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId) or nil
end
local function WeekLabel(i)
    local fmt = L and L["omnium.week"]
    return fmt and fmt:format(i) or ("Week " .. i)
end
local function HasAtlas(name)
    return name and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end
local function maskAtlasFor(shape)
    if shape == "circle" then return "talents-node-circle-mask" end
    if shape == "choice" then return "talents-node-choice-mask" end
    return "UI-Frame-IconMask"
end

local function AttachPulse(tex, lo, hi, dur)
    local ag = tex:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(lo)
    a:SetToAlpha(hi)
    a:SetDuration(dur)
    a:SetOrder(1)
    a:SetSmoothing("OUT")
    local b = ag:CreateAnimation("Alpha")
    b:SetFromAlpha(hi)
    b:SetToAlpha(lo)
    b:SetDuration(dur)
    b:SetOrder(2)
    b:SetSmoothing("IN")
    return ag
end

local function SizeToAtlas(tex, atlas, sc)
    tex:SetAtlas(atlas, true)
    local w, h = tex:GetSize()
    tex:SetSize((w or CELL) * sc, (h or CELL) * sc)
    tex:Show()
end

local function BuildNode(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(CELL, CELL)
    b:RegisterForClicks("LeftButtonUp")

    b.shadow = b:CreateTexture(nil, "BACKGROUND")
    b.shadow:SetPoint("CENTER")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")
    b.icon:SetSize(ICON_SIZE, ICON_SIZE)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.iconMask = b:CreateMaskTexture(nil, "ARTWORK")
    b.iconMask:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(b.iconMask)

    b.borderFlat = b:CreateTexture(nil, "BORDER")
    b.borderFlat:SetAllPoints(b)
    b.borderFlat:Hide()

    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetPoint("CENTER")

    b.glow = b:CreateTexture(nil, "OVERLAY", nil, -2)
    b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("CENTER")
    b.glow:Hide()
    b.glowAnim = AttachPulse(b.glow, 0.10, 0.45, 0.8)

    b.check = b:CreateTexture(nil, "OVERLAY", nil, 5)
    b.check:SetSize(15, 15)
    b.check:SetPoint("TOPRIGHT", b.icon, "TOPRIGHT", 3, 3)
    if HasAtlas(CHECK_ATLAS) then
        b.check:SetAtlas(CHECK_ATLAS)
    else
        b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    end
    b.check:Hide()

    b.srcIcon = b:CreateTexture(nil, "OVERLAY", nil, 7)
    b.srcIcon:SetSize(18, 18)
    b.srcIcon:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -4, 4)
    b.srcIcon:SetTexture(REC_STAR)
    b.srcIcon:Hide()

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(1, 1, 1, 0.12)
    hl:AddMaskTexture(b.iconMask)
    hl:SetAllPoints(b.icon)
    b:SetScript("OnMouseDown", function(self)
        self.icon:SetPoint("CENTER", 0, -1)
    end)
    b:SetScript("OnMouseUp", function(self)
        self.icon:SetPoint("CENTER", 0, 0)
    end)
    return b
end

local function StyleNode(b, shape, state, spellId)
    b.shape, b._state = shape, state
    b.icon:SetTexture(SpellTexture(spellId) or QUESTION_ICON)
    b.icon:SetDesaturated(state == "gray")
    b.icon:SetSize(ICON_SIZE, ICON_SIZE)

    local mask = maskAtlasFor(shape)
    if HasAtlas(mask) then
        b.iconMask:SetAtlas(mask)
    else
        b.iconMask:SetColorTexture(1, 1, 1, 1)
    end

    local sc = ICON_SIZE / BLIZ_ICON
    local border = "talents-node-" .. shape .. "-" .. state
    if HasAtlas(border) then
        SizeToAtlas(b.border, border, sc)
        b.borderFlat:Hide()
    else
        b.border:Hide()
        local c = (state == "yellow") and { 0.95, 0.80, 0.20 }
            or (state == "green") and { 0.25, 0.75, 0.35 }
            or { 0.35, 0.35, 0.35 }
        b.borderFlat:SetColorTexture(c[1], c[2], c[3], 1)
        b.borderFlat:Show()
    end

    local shadow = "talents-node-" .. shape .. "-shadow"
    if HasAtlas(shadow) then
        SizeToAtlas(b.shadow, shadow, sc)
    else
        b.shadow:Hide()
    end

    if state == "green" then
        local ga = "talents-node-" .. shape .. "-greenglow"
        if HasAtlas(ga) then
            SizeToAtlas(b.glow, ga, sc)
            b.glow:SetVertexColor(1, 1, 1)
        else
            b.glow:SetAtlas("bags-glow-orange")
            b.glow:SetSize(CELL * 1.3, CELL * 1.3)
            b.glow:SetVertexColor(0.3, 1, 0.4)
            b.glow:Show()
        end
        if not b.glowAnim:IsPlaying() then b.glowAnim:Play() end
    else
        b.glowAnim:Stop()
        b.glow:Hide()
    end
end

local function SetCheck(b, show)
    b.check:SetShown(show and true or false)
end

local function SetSrcIcon(b, show)
    b.srcIcon:SetShown(show and true or false)
end

local function PlaySelectFeedback(b)
    local scene = fxScene
    if scene and scene.AddEffect then
        local sm = 1
        local ss = scene:GetEffectiveScale()
        if ss and ss > 0 then sm = b:GetEffectiveScale() / ss end
        for _, id in ipairs(PURCHASE_FX_IDS) do
            pcall(scene.AddEffect, scene, id, b, b, nil, nil, sm)
        end
    end
    if SELECT_SOUND then PlaySound(SELECT_SOUND) end
end

local function EnsureFlyout()
    if flyout then return flyout end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:Hide()
    f.btns = {}
    for i = 1, MAX_NODES do
        local b = BuildNode(f)
        b:SetScript("OnEnter", function(self)
            if self.spellId then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellId)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", function(self)
            if self._state == "gray" then return end
            if InCombatLockdown and InCombatLockdown() then return end
            if self.nodeID and self.entryID then ns.OmniumFolio.ApplyEntry(self.nodeID, self.entryID) end
            f:Hide()
        end)
        b:Hide()
        f.btns[i] = b
    end
    f:SetScript("OnUpdate", function(self, e)
        self._t = (self._t or 0) + e
        if self._t < 0.16 then
            local p = self._t / 0.16
            self:SetScale(1.0 + (FLYOUT_SCALE - 1.0) * p)
            self:SetAlpha(math.min(1, self._t * 9))
            return
        end
        self:SetScale(FLYOUT_SCALE)
        self:SetAlpha(1)
        self._ct = (self._ct or 0) + e
        if self._ct < 0.15 then return end
        self._ct = 0
        if self:IsMouseOver() or (self._anchor and self._anchor:IsMouseOver()) then return end
        self:Hide()
    end)
    flyout = f
    return f
end

local function OpenFlyout(nodeBtn)
    local node = nodeBtn.node
    if not node or not node.isSelection then return end
    local f = EnsureFlyout()

    local n = math.min(#node.entries, MAX_NODES)
    for i = 1, MAX_NODES do
        f.btns[i]:Hide()
    end
    local x = 0
    for i = 1, n do
        local e = node.entries[i]
        local b = f.btns[i]
        b.nodeID, b.entryID, b.spellId, b.node = node.nodeID, e.entryID, e.spellId, nil
        local shape = (e.entryType == 1) and "square" or "circle"
        local state = (node.committedEntryID == e.entryID) and "yellow" or (node.canBuy and "green" or "gray")
        StyleNode(b, shape, state, e.spellId)
        SetCheck(b, false)
        SetSrcIcon(b, nodeBtn.recEntryID == e.entryID)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 4)
        b:Show()
        x = x + CELL + FLYOUT_GAP
    end
    f:SetSize(math.max(CELL, x - FLYOUT_GAP), CELL + 4)
    f._anchor = nodeBtn
    f:ClearAllPoints()

    f:SetPoint("BOTTOM", nodeBtn, "TOP", 0, -16)
    f._t = 0
    f._ct = 0
    f:SetScale(1.0)
    f:SetAlpha(0)
    f:Show()
end

local function MakeRowNode(parent)
    local b = BuildNode(parent)
    b:SetScript("OnEnter", function(self)
        if not self.node then return end
        if self.node.isSelection then
            if not (flyout and flyout:IsShown() and flyout._anchor == self) then OpenFlyout(self) end
            return
        end
        ns.Tooltip.Open(self, "ANCHOR_RIGHT")
        if self.node.committedSpellId then
            GameTooltip:SetSpellByID(self.node.committedSpellId)
        else
            ns.Tooltip.Title(L["section.omnium"] or "Omnium Folio")
            ns.Tooltip.Intro(L["omnium.unset"] or "No rune selected")
        end
        ns.Tooltip.Show()
    end)
    b:SetScript("OnLeave", function()
        ns.Tooltip.Hide()
    end)

    b:SetScript("OnClick", function(self)
        local node = self.node
        if not node or node.isSelection or not node.canBuy then return end
        if node.entries[1] then
            if InCombatLockdown and InCombatLockdown() then return end
            ns.OmniumFolio.ApplyEntry(node.nodeID, node.entries[1].entryID)
        end
    end)
    return b
end

local function build(inst, opts, collapsible)
    inst.section = CreateFrame("Frame", nil, opts.parent)
    inst.header = (opts.header or opts.headerFactory)(inst.section, L["section.omnium"], collapsible)
    inst.content = CreateFrame("Frame", nil, inst.section)
    inst.content:SetPoint("TOPLEFT", inst.header, "BOTTOMLEFT", 0, 0)
    inst.content:SetPoint("RIGHT", 0, 0)

    if not fxScene then
        local ok, scene = pcall(CreateFrame, "ModelScene", nil, UIParent, "ScriptAnimatedModelSceneTemplate")
        if ok and scene then
            scene:SetAllPoints(opts.parent)
            scene:SetFrameStrata("DIALOG")
            scene:SetFrameLevel(1000)
            fxScene = scene
        end
    end

    inst.listRows = {}
    for i = 1, MAX_WEEKS do
        local row = CreateFrame("Frame", nil, inst.content)
        row:SetHeight(ROW_HEIGHT)
        row:EnableMouse(true)
        local icon = ns.CreateSlotIcon(row, { size = LIST_ICON, slotSize = SLOT_FRAME })
        icon:SetPoint("LEFT", row, "LEFT", INSET_X, 0)
        row.icon = icon
        local week = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        week:SetPoint("BOTTOMLEFT", row, "LEFT", TEXT_X, 2)
        week:SetTextColor(0.6, 0.6, 0.6)
        row.week = week
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("TOPLEFT", row, "LEFT", TEXT_X, -2)
        name:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row.name = name
        row:SetScript("OnEnter", function(self)
            if self.spellId then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellId)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:Hide()
        inst.listRows[i] = row
    end

    inst.nodeBtns = {}
    for i = 1, MAX_NODES do
        local b = MakeRowNode(inst.content)
        b:Hide()
        inst.nodeBtns[i] = b
    end

    -- Source badge: the folio is Icy Veins-only data, so when the u.gg source
    -- is active it's borrowed — badge it like the other borrowed sections.
    if ns.CreateSourceAttributionIcon and inst.header.AddHeaderWidget then
        inst.ivIcon = ns.CreateSourceAttributionIcon(
            inst.header,
            "icyveins",
            "Omnium Folio",
            "Data from Icy Veins",
            function()
                if ns.ResolveAttribution and ns.GetClassAndSpec then
                    local class, spec = ns.GetClassAndSpec()
                    local _, url = ns.ResolveAttribution("guide", class, spec, "icyveins")
                    return url
                end
            end
        )
        inst.header:AddHeaderWidget(inst.ivIcon)
    end
end

local function RenderList(inst, runes)
    for i = 1, MAX_WEEKS do
        inst.listRows[i]:Hide()
    end
    if not runes or #runes == 0 then return 0 end
    local count = math.min(#runes, MAX_WEEKS)
    for i = 1, count do
        local r = runes[i]
        local row = inst.listRows[i]
        row.icon:SetSpell(r.spellId)
        row.spellId = r.spellId
        row.week:SetText(WeekLabel(i))
        row.name:SetText(SpellName(r.spellId, r.label))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", inst.content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", inst.content, "RIGHT", 0, 0)
        row:Show()
    end
    return count * ROW_HEIGHT
end

local function RenderGrid(inst, recSet)
    for i = 1, MAX_NODES do
        inst.nodeBtns[i]:Hide()
    end
    local nodes = ns.OmniumFolio.GetNodes()
    if #nodes == 0 then return 0 end

    local width = (
        (inst.content:GetWidth() and inst.content:GetWidth() > 40 and inst.content:GetWidth())
        or (ns.GetPanelWidth and ns.GetPanelWidth())
        or 312
    ) - 14
    local stride = CELL + ROW_GAP
    local cols = math.max(1, math.floor((width + ROW_GAP) / stride))
    local n = math.min(#nodes, MAX_NODES)
    local totalRows = math.ceil(n / cols)

    for i = 1, n do
        local node = nodes[i]
        local b = inst.nodeBtns[i]
        local prevCommitted = b._lastCommitted
        b.node = node

        local recEntryID, recSpellId
        for _, e in ipairs(node.entries) do
            if recSet[e.spellId] then
                recEntryID, recSpellId = e.entryID, e.spellId
                break
            end
        end
        b.recEntryID, b.recSpellId = recEntryID, recSpellId

        if inst.readOnly then
            local showSpell = recSpellId or (node.entries[1] and node.entries[1].spellId)
            b.readOnlySpell = showSpell
            StyleNode(b, node.shape or "circle", "yellow", showSpell)
            SetCheck(b, false)
            SetSrcIcon(b, false)
        else
            local state = node.active and "yellow" or (node.canBuy and "green" or "gray")
            local showSpell = node.committedSpellId or recSpellId or (node.entries[1] and node.entries[1].spellId)
            StyleNode(b, node.shape or "circle", state, showSpell)

            SetCheck(b, #node.entries > 1 and recEntryID ~= nil and node.committedEntryID == recEntryID)
            SetSrcIcon(b, false)

            if prevCommitted ~= nil and prevCommitted ~= node.committedEntryID then PlaySelectFeedback(b) end
            b._lastCommitted = node.committedEntryID
        end

        local rowIdx = math.floor((i - 1) / cols)
        local inThisRow = math.min(cols, n - rowIdx * cols)
        local col = (i - 1) % cols
        local xoff = (col - (inThisRow - 1) / 2) * stride
        local yoff = -(rowIdx * stride + CELL / 2)
        b:ClearAllPoints()
        b:SetPoint("CENTER", inst.content, "TOP", xoff, yoff)
        b:Show()
    end

    return totalRows * stride - ROW_GAP
end

local function render(inst, args)
    if flyout then flyout:Hide() end
    args = args or {}
    if inst.ivIcon then inst.ivIcon:SetShown(args.source == "ugg") end
    local runes = args.runes or {}
    if ns.OmniumFolio and ns.OmniumFolio.IsAvailable() then
        for i = 1, MAX_WEEKS do
            inst.listRows[i]:Hide()
        end
        local recSet = {}
        for _, r in ipairs(runes) do
            if r.spellId then recSet[r.spellId] = true end
        end
        return RenderGrid(inst, recSet)
    end
    for i = 1, MAX_NODES do
        inst.nodeBtns[i]:Hide()
    end
    return RenderList(inst, runes)
end

local panel = {}
local comp = {}

function Omnium.InitPanel(opts)
    build(panel, opts, false)
    return panel.section, panel.header, panel.content
end

function Omnium.RenderPanel(args)
    return render(panel, args)
end

function Omnium.InitCompendium(opts)
    build(comp, opts, true)
    comp.readOnly = true
    for _, b in ipairs(comp.nodeBtns) do
        b:SetScript("OnEnter", function(self)
            if not self.readOnlySpell then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.readOnlySpell)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", nil)
    end
    comp.header:SetScript("OnClick", function()
        comp.collapsed = not comp.collapsed
        ns.SetCollapsed(comp.content, comp.header, comp.collapsed)
        if opts.refresh then opts.refresh() end
    end)
    return comp.section, comp.header, comp.content
end

function Omnium.RenderCompendium(args)
    comp.lastHeight = render(comp, args)
    return comp.lastHeight
end

function Omnium.GetCompendiumContentHeight()
    return comp.lastHeight or 0
end
