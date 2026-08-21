local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

local Trinkets = {}
ns.Sections.Trinkets = Trinkets

local MAX_ICONS = 40
local MAX_TIERS = 10
local ICON_SIZE = 32
local SLOT_FRAME = math.floor(ICON_SIZE * 1.8125 + 0.5)
local ICON_STRIDE = 42
local ROW_STRIDE = 42
local TIER_LABEL_W = 22
local TIER_GAP = 6
local LIST_ROW_H = 40
local LIST_INSET_X = 8

local function viewContext(override)
    if override then return override end
    if ns.isFloating and ns.isFloating() then return "float" end
    return "dock"
end

function Trinkets.GetViewMode(context)
    context = viewContext(context)
    return (ClassCodexDB and ClassCodexDB["trinketView_" .. context]) or "table"
end

function Trinkets.SetViewMode(mode, context)
    context = viewContext(context)
    if not ClassCodexDB then ClassCodexDB = {} end
    ClassCodexDB["trinketView_" .. context] = mode
    if context == "comp" then
        if ns.UpdateCompendiumTrinkets then ns:UpdateCompendiumTrinkets() end
        if ns.LayoutCompendium then ns:LayoutCompendium() end
    else
        if ns.UpdateGearingSections then ns:UpdateGearingSections() end
        if ns.LayoutPanel then ns:LayoutPanel() end
    end
end

local function LoadCtx()
    local specKey = ns.GetSpecKey and ns.GetSpecKey()
    if
        specKey
        and ClassCodexCharDB
        and ClassCodexCharDB.perSpec
        and ClassCodexCharDB.perSpec[specKey]
        and ClassCodexCharDB.perSpec[specKey].trinketContext
    then
        return ClassCodexCharDB.perSpec[specKey].trinketContext
    end
    return "All"
end

local function SaveCtx(ctx)
    local specKey = ns.GetSpecKey and ns.GetSpecKey()
    if not specKey or not ClassCodexCharDB then return end
    if not ClassCodexCharDB.perSpec then ClassCodexCharDB.perSpec = {} end
    if not ClassCodexCharDB.perSpec[specKey] then ClassCodexCharDB.perSpec[specKey] = {} end
    ClassCodexCharDB.perSpec[specKey].trinketContext = ctx
end

local function LoadHiddenTiers()
    local specKey = ns.GetSpecKey and ns.GetSpecKey()
    if specKey and ClassCodexCharDB and ClassCodexCharDB.perSpec and ClassCodexCharDB.perSpec[specKey] then
        return ClassCodexCharDB.perSpec[specKey].trinketHiddenTiers or {}
    end
    return {}
end

local function ToggleHiddenTier(tier)
    local specKey = ns.GetSpecKey and ns.GetSpecKey()
    if not specKey or not ClassCodexCharDB then return end
    if not ClassCodexCharDB.perSpec then ClassCodexCharDB.perSpec = {} end
    if not ClassCodexCharDB.perSpec[specKey] then ClassCodexCharDB.perSpec[specKey] = {} end
    local ps = ClassCodexCharDB.perSpec[specKey]
    ps.trinketHiddenTiers = ps.trinketHiddenTiers or {}
    ps.trinketHiddenTiers[tier] = (not ps.trinketHiddenTiers[tier]) or nil
end

local function CollectContexts(trinkets)
    local contexts, seen = {}, {}
    for _, t in ipairs(trinkets) do
        if t.contexts then
            for _, ctx in ipairs(t.contexts) do
                if not seen[ctx] then
                    seen[ctx] = true
                    contexts[#contexts + 1] = ctx
                end
            end
        end
    end
    return contexts
end

local function FilterAndSort(trinkets, ctxKey)
    local TIER_ORDER = ns.TIER_ORDER
    local filtered = {}
    local key = ctxKey ~= "All" and ctxKey or nil
    for i, t in ipairs(trinkets) do
        local include = not key
        if key and t.contexts then
            for _, ctx in ipairs(t.contexts) do
                if ctx == key then
                    include = true
                    break
                end
            end
        end
        if include then filtered[#filtered + 1] = { t = t, i = i } end
    end

    table.sort(filtered, function(a, b)
        local ta, tb = TIER_ORDER[a.t.tier] or 99, TIER_ORDER[b.t.tier] or 99
        if ta ~= tb then return ta < tb end
        return a.i < b.i
    end)
    local out = {}
    for _, w in ipairs(filtered) do
        out[#out + 1] = w.t
    end
    return out
end

local function CtxLabel(ctx)
    return (ns.CONTEXT_LABELS and ns.CONTEXT_LABELS[ctx]) or ctx
end

local function SetTierColor(textWidget, tier)
    local color = ns.TIER_COLORS and ns.TIER_COLORS[tier]
    if color then
        textWidget:SetTextColor(color.r, color.g, color.b)
    else
        textWidget:SetTextColor(1, 1, 1)
    end
end

local function makeCog(inst, ctx)
    if not (inst.header and inst.header.AddHeaderWidget) then return end
    local cog = CreateFrame("Button", nil, inst.header)
    cog:SetSize(14, 14)
    cog:RegisterForClicks("LeftButtonUp")
    local icon = cog:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("QuestLog-icon-setting")
    icon:SetVertexColor(0.6, 0.6, 0.6)
    cog:SetScript("OnEnter", function(self)
        icon:SetVertexColor(1, 1, 1)
        ns.Tooltip
            .Open(self, "ANCHOR_RIGHT")
            .Title(L["tab.trinkets"] or "Trinkets")
            .Hint("Click to filter tiers and content.")
            .Show()
    end)
    cog:SetScript("OnLeave", function()
        icon:SetVertexColor(0.6, 0.6, 0.6)
        ns.Tooltip.Hide()
    end)
    cog:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            local ctxOpts = inst.contextOptions
            if ctxOpts and #ctxOpts > 1 then
                root:CreateTitle(L["context.label"] or "Content")
                root:CreateRadio("All", function()
                    return inst.currentContext == "All"
                end, function()
                    if inst.onContextPick then inst.onContextPick("All") end
                    return MenuResponse.Refresh
                end)
                for _, c in ipairs(ctxOpts) do
                    root:CreateRadio(CtxLabel(c), function()
                        return inst.currentContext == c
                    end, function()
                        if inst.onContextPick then inst.onContextPick(c) end
                        return MenuResponse.Refresh
                    end)
                end
                root:CreateDivider()
            end
            local tiers = inst.tiersPresent
            if tiers and #tiers > 0 then
                root:CreateTitle("Tiers")
                for _, tier in ipairs(tiers) do
                    root:CreateCheckbox(tier, function()
                        return not LoadHiddenTiers()[tier]
                    end, function()
                        ToggleHiddenTier(tier)
                        if inst.onRefresh then inst.onRefresh() end
                        return MenuResponse.Refresh
                    end)
                end
                root:CreateDivider()
            end
            root:CreateTitle(L["settings.value.view"] or "View")
            root:CreateRadio(L["settings.value.table"] or "Table", function()
                return Trinkets.GetViewMode(ctx) == "table"
            end, function()
                Trinkets.SetViewMode("table", ctx)
                return MenuResponse.Refresh
            end)
            root:CreateRadio(L["settings.value.list"] or "List", function()
                return Trinkets.GetViewMode(ctx) == "list"
            end, function()
                Trinkets.SetViewMode("list", ctx)
                return MenuResponse.Refresh
            end)
            root:CreateRadio(L["settings.value.icons"] or "Icons", function()
                return Trinkets.GetViewMode(ctx) == "icons"
            end, function()
                Trinkets.SetViewMode("icons", ctx)
                return MenuResponse.Refresh
            end)
        end)
    end)
    cog:Hide()
    inst.contextCog = cog
end

local function placeCog(inst, title)
    local cog = inst.contextCog
    if not cog then return end
    if title then
        cog:SetParent(title)
        cog:ClearAllPoints()
        if title.link then
            cog:SetPoint("RIGHT", title.link, "LEFT", -3, 0)
        else
            cog:SetPoint("RIGHT", title, "RIGHT", -(ns.PAGE_TITLE_HPAD or 8), 0)
        end
    elseif inst.header and inst.header.AddHeaderWidget then
        inst.header:AddHeaderWidget(cog)
    end
end

local function makeIcon(inst)
    local ic = ns.CreateSlotIcon(inst.content, { size = ICON_SIZE, slotSize = SLOT_FRAME })
    ns.SetupItemTooltip(ic)
    ic:Hide()
    return ic
end

local function makeListRow(inst)
    local row = CreateFrame("Frame", nil, inst.content)
    row:SetHeight(LIST_ROW_H)
    row.icon = ns.CreateSlotIcon(row, { size = ICON_SIZE, slotSize = SLOT_FRAME })
    row.icon:SetPoint("LEFT", row, "LEFT", LIST_INSET_X, 0)
    local tier = row.icon:CreateFontString(nil, "OVERLAY", nil, 7)
    tier:SetFont(GameFontNormalSmall:GetFont(), 14, "OUTLINE")
    tier:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -3, 5)
    tier:SetJustifyH("CENTER")
    row.tierLabel = tier
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", row.icon.slot, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.itemText = name
    ns.SetupItemTooltip(row)
    row:Hide()
    return row
end

local function buildRows(inst)
    inst.icons = {}
    for i = 1, MAX_ICONS do
        inst.icons[i] = makeIcon(inst)
    end
    inst.listRows = {}
    for i = 1, MAX_ICONS do
        inst.listRows[i] = makeListRow(inst)
    end
    inst.tableRows = {}
    for i = 1, MAX_ICONS do
        inst.tableRows[i] = ns.MakeTableRow(inst.content)
    end
    inst.tierLabels = {}
    for i = 1, MAX_TIERS do
        local t = inst.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetJustifyH("CENTER")
        t:SetWidth(TIER_LABEL_W)
        t:Hide()
        inst.tierLabels[i] = t
    end
end

local function render(inst, args)
    if not inst.icons then return 0 end
    for i = 1, MAX_ICONS do
        inst.icons[i]:Hide()
        if inst.listRows and inst.listRows[i] then inst.listRows[i]:Hide() end
        if inst.tableRows and inst.tableRows[i] then inst.tableRows[i]:Hide() end
    end
    for i = 1, MAX_TIERS do
        inst.tierLabels[i]:Hide()
    end

    if not args or not args.trinkets or #args.trinkets == 0 then
        if inst.contextCog then inst.contextCog:Hide() end
        if inst.section then inst.section:Hide() end
        return 0
    end

    local contexts = CollectContexts(args.trinkets)
    local ctxKey = LoadCtx()
    if ctxKey ~= "All" then
        local valid = false
        for _, c in ipairs(contexts) do
            if c == ctxKey then
                valid = true
                break
            end
        end
        if not valid then
            ctxKey = "All"
            SaveCtx("All")
        end
    end

    inst.contextOptions = contexts
    inst.currentContext = ctxKey
    inst.onContextPick = function(picked)
        SaveCtx(picked)
        if args.onChange then args.onChange() end
        if args.refresh then args.refresh() end
    end
    inst.onRefresh = function()
        if args.onChange then args.onChange() end
        if args.refresh then args.refresh() end
    end

    local filtered = FilterAndSort(args.trinkets, ctxKey)
    if #filtered == 0 then
        if inst.contextCog then inst.contextCog:Hide() end
        if inst.section then inst.section:Hide() end
        return 0
    end

    local tiersPresent, seenTier = {}, {}
    for _, t in ipairs(filtered) do
        -- Tierless entries (e.g. a flat "recommended" list) default to S so the
        -- seenTier table below is never indexed with nil.
        local tier = t.tier or "S"
        t.tier = tier
        if not seenTier[tier] then
            seenTier[tier] = true
            tiersPresent[#tiersPresent + 1] = tier
        end
    end
    inst.tiersPresent = tiersPresent
    if inst.contextCog then inst.contextCog:Show() end

    local hidden = LoadHiddenTiers()

    if inst.header and inst.header.label then
        local base = L["tab.trinkets"] or "Trinkets"
        local selected = {}
        for _, tier in ipairs(tiersPresent) do
            if not hidden[tier] then selected[#selected + 1] = tier end
        end
        if #selected > 0 and #selected < #tiersPresent then
            local parts = {}
            for _, tier in ipairs(selected) do
                local c = ns.TIER_COLORS and ns.TIER_COLORS[tier]
                if c then
                    parts[#parts + 1] = string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, tier)
                else
                    parts[#parts + 1] = tier
                end
            end
            inst.header.label:SetText(base .. " · " .. table.concat(parts, ", "))
        else
            inst.header.label:SetText(base)
        end
    end

    if Trinkets.GetViewMode(args._viewCtx) == "list" then
        local rowIdx = 0
        for _, t in ipairs(filtered) do
            if not hidden[t.tier] and rowIdx < MAX_ICONS then
                rowIdx = rowIdx + 1
                local row = inst.listRows[rowIdx]
                if row then
                    row.itemId = t.itemId
                    row.bonusIDs = t.bonusIDs
                    row.altItemId = nil
                    row.embItemId = nil
                    row.sourceText = (t.source and t.source ~= "" and t.source)
                        or (ns.GetTrinketSource and ns:GetTrinketSource(t.itemId))
                        or nil
                    row.popText = t.popularity and (t.popularity .. "%") or nil
                    row.tierLabel:SetText(t.tier)
                    SetTierColor(row.tierLabel, t.tier)
                    row.itemText:SetText(t.itemId and ns.FormatItem({ itemId = t.itemId }) or "")
                    row.icon:SetItem(t.itemId)
                    local owned = ns.IsItemOwned(t.itemId)
                    if inst.gateOwned then owned = owned and ns.compOwnClass end
                    row.icon:ToggleMarker("owned", owned and true or false)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", inst.content, "TOPLEFT", 0, -(rowIdx - 1) * LIST_ROW_H)
                    row:SetPoint("RIGHT", inst.content, "RIGHT", 0, 0)
                    row:Show()
                end
            end
        end
        local listH = rowIdx * LIST_ROW_H
        ns.SetContentHeight(inst.content, math.max(listH, 1))
        if inst.section then inst.section:Show() end
        return #tiersPresent
    end

    if Trinkets.GetViewMode(args._viewCtx) == "table" then
        local items = {}
        for _, t in ipairs(filtered) do
            if not hidden[t.tier] then
                local tierColor = ns.TIER_COLORS and ns.TIER_COLORS[t.tier]
                items[#items + 1] = {
                    itemId = t.itemId,
                    bonusIDs = t.bonusIDs,
                    sourceText = (t.source and t.source ~= "" and t.source)
                        or (ns.GetTrinketSource and ns:GetTrinketSource(t.itemId))
                        or nil,
                    popText = t.popularity and (t.popularity .. "%") or nil,
                    isOwned = ns.IsItemOwned(t.itemId),
                    label = t.tier,
                    labelColor = tierColor and { tierColor.r, tierColor.g, tierColor.b } or nil,
                }
            end
        end
        local h = ns.LayoutTable(inst.content, inst.tableRows, items)
        ns.SetContentHeight(inst.content, math.max(h, 1))
        if inst.section then inst.section:Show() end
        return #tiersPresent
    end

    local inset = 4
    local width = inst.content:GetWidth()
    if not width or width < 100 then width = args.width or (ns.GetPanelWidth and ns.GetPanelWidth()) or 300 end
    local availW = width - inset - TIER_LABEL_W - 6
    local perRow = math.max(1, math.floor(availW / ICON_STRIDE))

    local y = -2
    local iconIdx, tierIdx = 0, 0
    local i = 1
    while i <= #filtered and iconIdx < MAX_ICONS and tierIdx < MAX_TIERS do
        local tier = filtered[i].tier
        local group = {}
        while i <= #filtered and filtered[i].tier == tier do
            group[#group + 1] = filtered[i]
            i = i + 1
        end

        if not hidden[tier] then
            local numRows = math.ceil(#group / perRow)
            tierIdx = tierIdx + 1
            local tl = inst.tierLabels[tierIdx]
            tl:SetText(tier)
            SetTierColor(tl, tier)
            tl:ClearAllPoints()
            local labelY = y - ((numRows - 1) * ROW_STRIDE) / 2 - ICON_SIZE / 2
            tl:SetPoint("LEFT", inst.content, "TOPLEFT", inset, labelY)
            tl:Show()

            for j, t in ipairs(group) do
                iconIdx = iconIdx + 1
                if iconIdx > MAX_ICONS then break end
                local ic = inst.icons[iconIdx]
                local rowN = math.floor((j - 1) / perRow)
                local col = (j - 1) % perRow
                local x = inset + TIER_LABEL_W + col * ICON_STRIDE
                ic:ClearAllPoints()
                ic:SetPoint("TOPLEFT", inst.content, "TOPLEFT", x, y - rowN * ROW_STRIDE)
                ic:SetItem(t.itemId)
                ic.itemId = t.itemId
                ic.bonusIDs = t.bonusIDs
                ic.altItemId = nil
                ic.embItemId = nil
                ic.sourceText = (t.source and t.source ~= "" and t.source)
                    or (ns.GetTrinketSource and ns:GetTrinketSource(t.itemId))
                    or nil
                ic.popText = t.popularity and (t.popularity .. "%") or nil
                local owned = ns.IsItemOwned(t.itemId)
                if inst.gateOwned then owned = owned and ns.compOwnClass end
                ic:ToggleMarker("owned", owned and true or false)
                ic:Show()
            end

            y = y - numRows * ROW_STRIDE - TIER_GAP
        end
    end

    ns.SetContentHeight(inst.content, math.max(math.abs(y), 1))
    if inst.section then inst.section:Show() end
    return #tiersPresent
end

local panel = {}
local comp = { gateOwned = true }

function Trinkets.InitPanel(parent, cogTitle)
    panel.section, panel.header, panel.content = ns.CreateCollapsibleSection(parent, {
        label = L["tab.trinkets"],
        stateKey = "trinkets",
        refresh = function()
            if ns.LayoutPanel then ns:LayoutPanel() end
        end,
    })
    panel.title = panel.header
    makeCog(panel, nil)
    placeCog(panel, cogTitle)
    buildRows(panel)
    return panel.section
end

function Trinkets.RenderPanel(args)
    args._viewCtx = nil
    return render(panel, args)
end

function Trinkets.GetPanelFrames()
    return {
        section = panel.section,
        content = panel.content,
        collapsed = panel.section.IsCollapsed and panel.section.IsCollapsed() or false,
    }
end

function Trinkets.InitCompendium(opts)
    comp.section = CreateFrame("Frame", nil, opts.parent)
    comp.header = opts.headerFactory(comp.section, L["tab.trinkets"], false)
    comp.content = CreateFrame("Frame", nil, comp.section)
    comp.content:SetPoint("TOPLEFT", comp.header, "BOTTOMLEFT", 0, 0)
    comp.content:SetPoint("RIGHT", 0, 0)
    makeCog(comp, "comp")
    placeCog(comp, opts.cogTitle)
    buildRows(comp)
    return comp.section, comp.header, comp.content
end

function Trinkets.RenderCompendium(args)
    args._viewCtx = "comp"
    return render(comp, args)
end

function Trinkets.GetCompendiumContentHeight()
    return comp.content and (comp.content._stackHeight or comp.content:GetHeight()) or 0
end
