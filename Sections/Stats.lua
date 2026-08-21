local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

local Stats = {}
ns.Sections.Stats = Stats

local HPAD = ns.PAGE_TITLE_HPAD or 8

local MAX_ROWS = 10
local DEFAULT_RANK_COLORS = {
    [1] = { r = 0.64, g = 0.21, b = 0.93 },
    [2] = { r = 0.00, g = 0.44, b = 0.87 },
    [3] = { r = 0.12, g = 1.00, b = 0.00 },
    [4] = { r = 1.00, g = 1.00, b = 1.00 },
    [5] = { r = 0.62, g = 0.62, b = 0.62 },
}

local function PickRankColor(i, override)
    return (override and override[i]) or DEFAULT_RANK_COLORS[i] or DEFAULT_RANK_COLORS[5]
end

function ns.CreateStatInfoButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(14, 14)
    btn:RegisterForClicks("LeftButtonUp")
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("QuestLog-icon-setting")
    icon:SetVertexColor(0.6, 0.6, 0.6)
    btn:SetScript("OnEnter", function(self)
        ns.Tooltip
            .Open(self, "ANCHOR_RIGHT")
            .Title(L["settings.label.stat_priority_on_tooltips"])
            .Intro("Item tooltips show each stat's priority rank (#1, #2, …) for your hero talent.")
            .Hint("Click to change tooltip settings.")
            .Show()
        icon:SetVertexColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function()
        ns.Tooltip.Hide()
        icon:SetVertexColor(0.6, 0.6, 0.6)
    end)
    btn:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateCheckbox(L["settings.label.stat_priority_ranks"], function()
                return ClassCodexDB and ClassCodexDB.showTooltipBadges ~= false
            end, function()
                if ClassCodexDB then ClassCodexDB.showTooltipBadges = ClassCodexDB.showTooltipBadges == false end
                if ns.InvalidateTooltipCache then ns.InvalidateTooltipCache() end
                return MenuResponse.Refresh
            end)
        end)
    end)
    return btn
end

-- ============================================================
-- Stat Priority subsection
-- ============================================================

local function buildPriority(inst, opts, collapsible)
    inst.section = CreateFrame("Frame", nil, opts.parent)
    inst.header = (opts.header or opts.headerFactory)(inst.section, L["section.stat_priority"], collapsible)
    inst.content = CreateFrame("Frame", nil, inst.section)
    inst.content:SetPoint("TOPLEFT", inst.header, "BOTTOMLEFT", 0, 0)
    inst.content:SetPoint("RIGHT", 0, 0)
    inst.content:SetHeight(200)

    inst.ctxDropdown = ns.CreateOptionDropdown(inst.ddName, inst.content)
    inst.ctxDropdown:SetPoint("TOPLEFT", 0, 0)
    inst.ctxDropdown:SetPoint("TOPRIGHT", 0, 0)
    inst.ctxDropdown:Hide()

    inst.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, inst.content)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ns.ROW_HEIGHT)
        row:SetPoint("RIGHT", 0, 0)
        local rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rank:SetPoint("LEFT", HPAD, 0)
        rank:SetWidth(16)
        rank:SetJustifyH("LEFT")
        row.rank = rank
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", rank, "RIGHT", 4, 0)
        name:SetPoint("RIGHT", -HPAD, 0)
        name:SetJustifyH("LEFT")
        row.statName = name
        inst.rows[i] = row
    end

    inst.pvpFallback = inst.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inst.pvpFallback:SetTextColor(0.5, 0.5, 0.5)
    inst.pvpFallback:Hide()
end

local function renderPriority(inst, args)
    local options = args.contextOptions or {}
    local showCtx = #options > 0

    if showCtx then
        inst.ctxDropdown:Show()
        inst.ctxDropdown:SetOptions(options, args.currentContext, function(picked)
            if args.onCtxChange then args.onCtxChange(picked) end
        end)
    else
        inst.ctxDropdown:Hide()
    end

    inst.pvpFallback:Hide()
    for i = 1, MAX_ROWS do
        inst.rows[i]:Hide()
    end

    local priority = args.priorityStats
    if priority then
        local yOffset = showCtx and -30 or 0
        local count = math.min(#priority, MAX_ROWS)
        for i = 1, count do
            local row = inst.rows[i]
            local color = PickRankColor(i, args.rankColors)
            row.rank:SetTextColor(color.r or 0.6, color.g or 0.6, color.b or 0.6)
            row.rank:SetText(i .. ".")
            row.statName:SetTextColor(
                #priority[i] > 1 and 0.8 or 1,
                #priority[i] > 1 and 0.8 or 1,
                #priority[i] > 1 and 0.6 or 1
            )
            row.statName:SetText(table.concat(priority[i], " / "))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, yOffset - (i - 1) * ns.ROW_HEIGHT)
            row:SetPoint("RIGHT", 0, 0)
            row:Show()
        end
        inst.section:Show()
        return count
    elseif args.showPvpFallback then
        local yOffset = showCtx and -30 or 0
        inst.pvpFallback:SetText(L["pvp.no_stat_priority"] or "No PvP stat priority for this spec yet.")
        inst.pvpFallback:ClearAllPoints()
        inst.pvpFallback:SetPoint("TOPLEFT", inst.content, "TOPLEFT", 4, yOffset - 4)
        inst.pvpFallback:Show()
        inst.section:Show()
        return 0
    else
        inst.section:Hide()
        return 0
    end
end

local function priorityHeight(inst)
    local h = 0
    if inst.ctxDropdown:IsShown() then h = h + 30 end
    for i = 1, MAX_ROWS do
        if inst.rows[i]:IsShown() then h = h + ns.ROW_HEIGHT end
    end
    if inst.pvpFallback:IsShown() then h = h + 20 end
    return h
end

-- ============================================================
-- Stat Targets subsection
-- ============================================================

local TGT_MAX_ROWS = 4
local TGT_ROW_HEIGHT = 40
local TGT_ROW_GAP = 5
local BAR_HEIGHT = 16
local BAR_MAX_RATIO = 1.3

local DISPLAY_ORDER = { "mastery", "haste", "crit", "versatility" }

local STATUS_ICONS = {
    above = {
        texture = "Interface\\BUTTONS\\Arrow-Up-Up",
        r = 0.40,
        g = 0.70,
        b = 1.00,
        texCoord = { 0, 1, 0, 1 },
    },
    at = { texture = "Interface\\BUTTONS\\UI-CheckBox-Check", r = 0.40, g = 1.00, b = 0.45, texCoord = { 0, 1, 0, 1 } },
    below = {
        texture = "Interface\\BUTTONS\\Arrow-Up-Up",
        r = 1.00,
        g = 0.40,
        b = 0.40,
        texCoord = { 0, 1, 1, 0 },
    },
}
local BAR_COLORS = {
    above = { 0.35, 0.65, 1.00 },
    at = { 0.40, 1.00, 0.45 },
    below = { 0.95, 0.40, 0.40 },
}

local function MakeBar(row)
    local barFrame = CreateFrame("Frame", nil, row)
    barFrame:SetPoint("BOTTOMLEFT", HPAD, 3)
    barFrame:SetPoint("BOTTOMRIGHT", -HPAD, 3)
    barFrame:SetHeight(BAR_HEIGHT)

    local function colorEdge(layer, r, g, b, a)
        local t = barFrame:CreateTexture(nil, layer)
        t:SetColorTexture(r, g, b, a or 1)
        return t
    end

    local oTop = colorEdge("BORDER", 0, 0, 0)
    oTop:SetPoint("TOPLEFT")
    oTop:SetPoint("TOPRIGHT")
    oTop:SetHeight(1)
    local oBot = colorEdge("BORDER", 0, 0, 0)
    oBot:SetPoint("BOTTOMLEFT")
    oBot:SetPoint("BOTTOMRIGHT")
    oBot:SetHeight(1)
    local oL = colorEdge("BORDER", 0, 0, 0)
    oL:SetPoint("TOPLEFT")
    oL:SetPoint("BOTTOMLEFT")
    oL:SetWidth(1)
    local oR = colorEdge("BORDER", 0, 0, 0)
    oR:SetPoint("TOPRIGHT")
    oR:SetPoint("BOTTOMRIGHT")
    oR:SetWidth(1)

    local iTop = colorEdge("BORDER", 0.62, 0.51, 0.27)
    iTop:SetPoint("TOPLEFT", 1, -1)
    iTop:SetPoint("TOPRIGHT", -1, -1)
    iTop:SetHeight(1)
    local iBot = colorEdge("BORDER", 0.62, 0.51, 0.27)
    iBot:SetPoint("BOTTOMLEFT", 1, 1)
    iBot:SetPoint("BOTTOMRIGHT", -1, 1)
    iBot:SetHeight(1)
    local iL = colorEdge("BORDER", 0.62, 0.51, 0.27)
    iL:SetPoint("TOPLEFT", 1, -1)
    iL:SetPoint("BOTTOMLEFT", 1, 1)
    iL:SetWidth(1)
    local iR = colorEdge("BORDER", 0.62, 0.51, 0.27)
    iR:SetPoint("TOPRIGHT", -1, -1)
    iR:SetPoint("BOTTOMRIGHT", -1, 1)
    iR:SetWidth(1)

    local barBg = barFrame:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", 2, -2)
    barBg:SetPoint("BOTTOMRIGHT", -2, 2)
    barBg:SetColorTexture(0.05, 0.05, 0.05, 1)

    local innerShadow = barFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    innerShadow:SetColorTexture(0, 0, 0, 0.55)
    innerShadow:SetPoint("TOPLEFT", 2, -2)
    innerShadow:SetPoint("TOPRIGHT", -2, -2)
    innerShadow:SetHeight(1)

    local fill = barFrame:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMLEFT", 2, 2)
    fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    fill:SetVertexColor(0.85, 0.45, 0.45, 1)
    fill:SetWidth(0)

    local glossHeight = math.max(2, math.floor((BAR_HEIGHT - 4) * 0.4))
    local gloss = barFrame:CreateTexture(nil, "OVERLAY")
    gloss:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    gloss:SetVertexColor(1, 1, 1, 0.16)
    gloss:SetBlendMode("ADD")
    gloss:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    gloss:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
    gloss:SetHeight(glossHeight)

    local tick = barFrame:CreateTexture(nil, "OVERLAY")
    tick:SetColorTexture(0.95, 0.86, 0.55, 0.95)
    tick:SetWidth(2)
    barFrame.tick = tick

    barFrame:SetScript("OnSizeChanged", function(self, w)
        local p = self.progress or 0
        local inner = math.max(0, w - 4)
        self.fill:SetWidth(math.max(p > 0 and 2 or 0, math.min(p * inner, inner)))
        if self.tick then
            local tickX = 2 + math.floor((1 / BAR_MAX_RATIO) * inner + 0.5)
            self.tick:ClearAllPoints()
            self.tick:SetPoint("TOP", self, "TOPLEFT", tickX, -2)
            self.tick:SetPoint("BOTTOM", self, "BOTTOMLEFT", tickX, 2)
        end
    end)
    barFrame.fill = fill
    return barFrame
end

local function tgtSubHeaderHeight(inst)
    return (inst.subHeader and inst.subHeader:GetHeight()) or ns.SECTION_HEADER_HEIGHT or 28
end

local function buildTargets(inst, opts)
    inst.section = CreateFrame("Frame", nil, opts.parent)
    inst.content = CreateFrame("Frame", nil, inst.section)
    inst.content:SetPoint("TOPLEFT", 0, 0)
    inst.content:SetPoint("RIGHT", 0, 0)
    inst.content:SetHeight(140)

    inst.subHeader = ns.CreateSectionHeader(inst.content, L["section.stat_targets"] or "Stat Targets", false)
    inst.subHeader:ClearAllPoints()
    inst.subHeader:SetPoint("TOPLEFT", 0, 0)
    inst.subHeader:SetPoint("TOPRIGHT", 0, 0)
    if inst.subHeader.topDivider then inst.subHeader.topDivider:Show() end

    inst.uggIcon = ns.CreateSourceAttributionIcon(inst.subHeader, "ugg", "Stat targets", "Data from U.GG", function()
        if ns.ResolveAttribution and ns.GetClassAndSpec then
            local class, spec = ns.GetClassAndSpec()
            local _, url = ns.ResolveAttribution("stats", class, spec)
            return url
        end
    end)
    if inst.subHeader.AddHeaderWidget then inst.subHeader:AddHeaderWidget(inst.uggIcon) end

    inst.ctxDropdown = ns.CreateOptionDropdown(inst.ddName, inst.content)
    inst.ctxDropdown:SetPoint("TOPLEFT", 0, 0)
    inst.ctxDropdown:SetPoint("TOPRIGHT", 0, 0)

    inst.rows = {}
    for i = 1, TGT_MAX_ROWS do
        local row = CreateFrame("Frame", nil, inst.content)
        row:SetHeight(TGT_ROW_HEIGHT)
        row:SetPoint("LEFT", 0, 0)
        row:SetPoint("RIGHT", 0, 0)

        local statusIcon = row:CreateTexture(nil, "ARTWORK")
        statusIcon:SetSize(14, 14)
        statusIcon:SetPoint("TOPRIGHT", -HPAD, -2)
        row.statusIcon = statusIcon

        local rating = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        -- Fixed width so a long "24.5% 1234 / 1456" can never encroach on the
        -- stat name at narrow panel widths (an auto-width right-anchored string
        -- grows leftward and squeezes the name to a negative width, which
        -- renders as the two texts colliding).
        rating:SetWidth(112)
        rating:SetPoint("TOPRIGHT", statusIcon, "TOPLEFT", -4, 0)
        rating:SetJustifyH("RIGHT")
        row.rating = rating

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("TOPLEFT", HPAD, -2)
        name:SetPoint("RIGHT", rating, "LEFT", -4, 0)
        name:SetJustifyH("LEFT")
        row.statName = name

        row.bar = MakeBar(row)
        inst.rows[i] = row
    end

    inst.emptyFallback = inst.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inst.emptyFallback:SetTextColor(0.5, 0.5, 0.5)
    inst.emptyFallback:SetJustifyH("CENTER")
    inst.emptyFallback:SetWordWrap(true)
    inst.emptyFallback:Hide()
end

local function renderTargets(inst, args)
    inst.emptyFallback:Hide()
    local classToken = args.classToken
    local specKey = args.specKey
    local src = args.source
    if not classToken or not specKey then
        for i = 1, TGT_MAX_ROWS do
            inst.rows[i]:Hide()
        end
        if inst.uggIcon then inst.uggIcon:Hide() end
        return 0
    end

    -- The pane/compendium hero selection drives the targets; only fall back
    -- to the active-hero logic when no selection was passed.
    local heroSlug = (args.heroTalent and ns.HeroSlugFromDisplay and ns.HeroSlugFromDisplay(args.heroTalent)) or nil

    -- Contexts offered depend on the view: PvP shows its own targets, PvE
    -- views offer Mythic+/Raid.
    local viewCt = args.contentType or (ns.Context and ns.Context.contentType())
    local isPvpView = type(viewCt) == "string" and viewCt:sub(1, 3) == "pvp"
    local CONTEXT_OPTIONS = isPvpView and { "PvP" } or { "Mythic+", "Raid" }
    local availableContexts = {}
    for _, ctx in ipairs(CONTEXT_OPTIONS) do
        if ns.GetStatTargets(classToken, specKey, ctx, src, heroSlug) then
            availableContexts[#availableContexts + 1] = ctx
        end
    end

    if #availableContexts == 0 then
        inst.ctxDropdown:Hide()
        for i = 1, TGT_MAX_ROWS do
            inst.rows[i]:Hide()
        end
        if inst.uggIcon then inst.uggIcon:Hide() end
        -- A spec with no targets at all (e.g. a young season with too few
        -- parses) still gets the section, with a note instead of rows —
        -- callers treat any positive return as "section shown".
        local yOffset = -(tgtSubHeaderHeight(inst) + 12)
        inst.emptyFallback:SetText(L["empty.no_stat_targets"] or "Stat targets coming soon.")
        inst.emptyFallback:ClearAllPoints()
        inst.emptyFallback:SetPoint("TOPLEFT", inst.content, "TOPLEFT", HPAD, yOffset)
        inst.emptyFallback:SetPoint("TOPRIGHT", inst.content, "TOPRIGHT", -HPAD, yOffset)
        inst.emptyFallback:Show()
        return 1
    end

    local CT_MAP = { mplus = "Mythic+", raid = "Raid", pvp = "PvP" }
    local wantCtx = args.contentType and CT_MAP[args.contentType]
    if not wantCtx then wantCtx = ns.Context and CT_MAP[ns.Context.contentType()] end
    if wantCtx and ns.GetStatTargets(classToken, specKey, wantCtx, src, heroSlug) then
        inst.currentCtx = wantCtx
    elseif not inst.currentCtx or not ns.GetStatTargets(classToken, specKey, inst.currentCtx, src, heroSlug) then
        inst.currentCtx = availableContexts[1]
    end
    inst.ctxDropdown:Hide()

    local snapshot = ns.GetStatTargets(classToken, specKey, inst.currentCtx, src, heroSlug)
    if not snapshot or not snapshot.targets then
        for i = 1, TGT_MAX_ROWS do
            inst.rows[i]:Hide()
        end
        return 0
    end

    local yOffset = -(tgtSubHeaderHeight(inst) + 4)
    local visibleCount = 0

    for _, statKey in ipairs(DISPLAY_ORDER) do
        local target = snapshot.targets[statKey] or 0
        local hasTarget = target > 0
        visibleCount = visibleCount + 1
        local row = inst.rows[visibleCount]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", inst.content, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", inst.content, "TOPRIGHT", 0, yOffset)
        row:Show()
        yOffset = yOffset - TGT_ROW_HEIGHT - TGT_ROW_GAP

        row.statName:SetText(ns.STAT_LABELS[statKey] or statKey)
        local showCurrent = args.showCurrent ~= false

        local kind, progress
        if showCurrent then
            local current = ns.GetPlayerStatRating(statKey)
            local livePct = ns.GetPlayerStatPercent(statKey)
            kind = hasTarget and (ns.ClassifyStatDelta(current, target) or "below") or "at"
            local status = STATUS_ICONS[kind]
            row.statusIcon:SetTexture(status.texture)
            row.statusIcon:SetTexCoord(status.texCoord[1], status.texCoord[2], status.texCoord[3], status.texCoord[4])
            row.statusIcon:SetVertexColor(status.r, status.g, status.b)
            row.statusIcon:Show()
            row.rating:SetText(string.format("%.1f%%  |cff9a9a9a%d / %d|r", livePct, current, target))
            local marginal = ns.GetMarginalDR and ns.GetMarginalDR(livePct) or 1
            if marginal >= 1 then
                row.rating:SetTextColor(0.85, 0.85, 0.85)
            elseif marginal >= 0.8 then
                row.rating:SetTextColor(1, 0.85, 0.4)
            elseif marginal >= 0.6 then
                row.rating:SetTextColor(1, 0.65, 0.1)
            else
                row.rating:SetTextColor(1, 0.4, 0.2)
            end
            row:EnableMouse(true)
            row.statKey = statKey
            row.snapshot = snapshot
            if not row._statTooltipBound then
                row:SetScript("OnEnter", function(self)
                    if not self.statKey then return end
                    ns.Tooltip.Open(self, "ANCHOR_RIGHT")
                    if ns.AppendStatExtrasToTooltip then
                        ns.AppendStatExtrasToTooltip(GameTooltip, self.statKey, self.snapshot, { includeTitle = true })
                    end
                    ns.Tooltip.Show()
                end)
                row:SetScript("OnLeave", function()
                    ns.Tooltip.Hide()
                end)
                row._statTooltipBound = true
            end
            local ratio = hasTarget and (current / target) or 1
            progress = math.min(ratio, BAR_MAX_RATIO) / BAR_MAX_RATIO
        else
            kind = "at"
            row.statusIcon:Hide()
            row.rating:SetText(hasTarget and string.format("|cff9a9a9a%d|r", target) or "")
            row.rating:SetTextColor(0.85, 0.85, 0.85)
            row:EnableMouse(false)
            progress = hasTarget and (1 / BAR_MAX_RATIO) or 0
        end
        row.bar.progress = progress
        local barW = row.bar:GetWidth()
        local inner = math.max(0, barW - 4)
        row.bar.fill:SetWidth(math.max(progress > 0 and 2 or 0, math.min(progress * inner, inner)))

        if row.bar.tick then
            local tickX = 2 + math.floor((1 / BAR_MAX_RATIO) * inner + 0.5)
            row.bar.tick:ClearAllPoints()
            row.bar.tick:SetPoint("TOP", row.bar, "TOPLEFT", tickX, -2)
            row.bar.tick:SetPoint("BOTTOM", row.bar, "BOTTOMLEFT", tickX, 2)
            row.bar.tick:Show()
        end

        local barColor = BAR_COLORS[kind]
        row.bar.fill:SetVertexColor(barColor[1], barColor[2], barColor[3], 1)
    end

    for i = visibleCount + 1, TGT_MAX_ROWS do
        inst.rows[i]:Hide()
    end

    if inst.uggIcon then
        local curSource = args.source or (ns.ActiveSource and ns.ActiveSource()) or "icyveins"
        inst.uggIcon:SetShown(visibleCount > 0 and curSource == "icyveins")
    end

    return visibleCount
end

local function targetsHeight(inst)
    local h = tgtSubHeaderHeight(inst) + 4
    if inst.ctxDropdown:IsShown() then h = h + 28 end
    local n = 0
    for i = 1, TGT_MAX_ROWS do
        if inst.rows[i]:IsShown() then n = n + 1 end
    end
    if n > 0 then
        h = h + n * TGT_ROW_HEIGHT + (n - 1) * TGT_ROW_GAP + 4
    elseif inst.emptyFallback:IsShown() then
        h = h + 44
    end
    return h
end

-- ============================================================
-- Instances + public API
-- ============================================================

local priPanel = { ddName = "ClassCodexStatCtxDropdown" }
local priComp = { ddName = "ClassCodexCompStatCtxDropdown" }
local tgtPanel = { ddName = "ClassCodexStatTargetCtxDropdown" }
local tgtComp = { ddName = "ClassCodexCompStatTargetCtxDropdown" }

-- Stat Priority

function Stats.InitPanel(opts)
    buildPriority(priPanel, opts, false)
    return priPanel.section, priPanel.header, priPanel.content
end

function Stats.RenderPanel(args)
    return renderPriority(priPanel, args)
end

function Stats.GetPanelContentHeight(visibleRowCount)
    if visibleRowCount then
        local h = visibleRowCount * ns.ROW_HEIGHT
        if priPanel.ctxDropdown and priPanel.ctxDropdown:IsShown() then h = h + 30 end
        return h
    end
    return priorityHeight(priPanel)
end

function Stats.InitCompendium(opts)
    buildPriority(priComp, opts, true)
    return priComp.section, priComp.header, priComp.content
end

function Stats.RenderCompendium(args)
    return renderPriority(priComp, args)
end

function Stats.GetCompendiumContentHeight()
    return priorityHeight(priComp)
end

-- Stat Targets

function Stats.InitStatTargets(opts)
    buildTargets(tgtPanel, opts)
    return tgtPanel.section
end

function Stats.GetStatTargetsContent()
    return tgtPanel.content
end

function Stats.GetStatTargetsHeight()
    return targetsHeight(tgtPanel)
end

function Stats.RenderStatTargets(args)
    return renderTargets(tgtPanel, args)
end

function Stats.InitCompendiumStatTargets(opts)
    buildTargets(tgtComp, opts)
    return tgtComp.section, tgtComp.content
end

function Stats.RenderCompendiumStatTargets(args)
    return renderTargets(tgtComp, args)
end

function Stats.GetCompendiumStatTargetsHeight()
    return targetsHeight(tgtComp)
end
