local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

local Gear = {}
ns.Sections.Gear = Gear

local MAX_ROWS = 20
local ICON_SIZE = 32
local SLOT_FRAME = math.floor(ICON_SIZE * 1.8125 + 0.5)
local CARD_HEIGHT = 40

local ICON_STRIDE = 42
local ROW_STRIDE = 42
local TOP_PAD = 4
local GRID_INSET = 4

local function LoadBisPrefs(specKey)
    specKey = specKey or (ns.GetSpecKey and ns.GetSpecKey())
    local source, tabLabel = "Icy Veins", nil
    if specKey and ClassCodexCharDB and ClassCodexCharDB.perSpec and ClassCodexCharDB.perSpec[specKey] then
        local s = ClassCodexCharDB.perSpec[specKey]
        if s.bisSource then source = s.bisSource end
        if s.bisTab then tabLabel = s.bisTab end
    end
    return source, tabLabel
end

local function SaveBisPrefs(specKey, source, tabLabel)
    specKey = specKey or (ns.GetSpecKey and ns.GetSpecKey())
    if not specKey or not ClassCodexCharDB then return end
    if not ClassCodexCharDB.perSpec then ClassCodexCharDB.perSpec = {} end
    if not ClassCodexCharDB.perSpec[specKey] then ClassCodexCharDB.perSpec[specKey] = {} end
    if source ~= nil then ClassCodexCharDB.perSpec[specKey].bisSource = source end
    if tabLabel ~= nil then ClassCodexCharDB.perSpec[specKey].bisTab = tabLabel end
end

local function viewContext(override)
    if override then return override end
    if ns.isFloating and ns.isFloating() then return "float" end
    return "dock"
end

local function refreshView(context)
    context = viewContext(context)
    if context == "comp" then
        if ns.UpdateCompendiumBis then ns:UpdateCompendiumBis() end
        if ns.LayoutCompendium then ns:LayoutCompendium() end
    else
        if ns.UpdateGearingSections then ns:UpdateGearingSections() end
        if ns.LayoutPanel then ns:LayoutPanel() end
    end
end

function Gear.GetViewMode(context)
    context = viewContext(context)
    return (ClassCodexDB and ClassCodexDB["gearView_" .. context]) or "table"
end

function Gear.SetViewMode(mode, context)
    context = viewContext(context)
    if not ClassCodexDB then ClassCodexDB = {} end
    ClassCodexDB["gearView_" .. context] = mode
    refreshView(context)
end

-- The docked panel and the Compendium remember the source setting separately
-- (same convention as the per-context view mode above).
function Gear.IsSourceShown(context)
    context = viewContext(context)
    local shown = ClassCodexDB and ClassCodexDB["gearSource_" .. context]
    return shown == true
end

function Gear.SetSourceShown(shown, context)
    context = viewContext(context)
    if not ClassCodexDB then ClassCodexDB = {} end
    ClassCodexDB["gearSource_" .. context] = shown and true or false
    refreshView(context)
end

function Gear.ToggleSource(context)
    context = viewContext(context)
    Gear.SetSourceShown(not Gear.IsSourceShown(context), context)
end

local function FindTabByLabel(tabs, label)
    if not label then return nil end
    for _, tab in ipairs(tabs) do
        if tab.label == label then return tab end
    end
    return nil
end

local function ResolveRow(entry, whLookup, context)
    local itemId = entry.item and entry.item.itemId
    local source = entry.source
    if not source or source == "" then
        source = (whLookup and whLookup[itemId]) or (itemId and ns:GetTrinketSource(itemId))
        if (not source or source == "") and entry.bis then source = "BiS" end
    end

    local bonusIDs = entry.item and entry.item.bonusIDs
    if not bonusIDs and itemId then
        bonusIDs = ns:GetItemBonusIDs(itemId) or (context and ns:GetContextBonusDefault(context))
    end
    return source or "", bonusIDs
end

local CONTENT_LABEL = { mplus = "Mythic+", raid = "Raid", pvp = "PvP" }

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
            .Title(L["tab.best_in_slot"] or "Best in Slot")
            .Hint("Click to change build or view.")
            .Show()
    end)
    cog:SetScript("OnLeave", function()
        icon:SetVertexColor(0.6, 0.6, 0.6)
        ns.Tooltip.Hide()
    end)
    cog:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            local opts = inst.variantOptions
            if opts and #opts > 1 then
                root:CreateTitle(L["tab.best_in_slot"] or "Best in Slot")
                for _, label in ipairs(opts) do
                    root:CreateRadio(label, function()
                        return inst.currentVariant == label
                    end, function()
                        if inst.onVariantPick then inst.onVariantPick(label) end
                        return MenuResponse.Refresh
                    end)
                end
                root:CreateDivider()
            end
            root:CreateTitle(L["settings.value.view"] or "View")
            root:CreateRadio(L["settings.value.table"] or "Table", function()
                return Gear.GetViewMode(ctx) == "table"
            end, function()
                Gear.SetViewMode("table", ctx)
                return MenuResponse.Refresh
            end)
            root:CreateRadio(L["settings.value.list"] or "List", function()
                return Gear.GetViewMode(ctx) == "list"
            end, function()
                Gear.SetViewMode("list", ctx)
                return MenuResponse.Refresh
            end)
            root:CreateRadio(L["settings.value.icons"] or "Icons", function()
                return Gear.GetViewMode(ctx) == "icons"
            end, function()
                Gear.SetViewMode("icons", ctx)
                return MenuResponse.Refresh
            end)
            root:CreateDivider()
            local srcCheck = root:CreateCheckbox(L["settings.label.gear_source"] or "Show Item Source", function()
                return Gear.IsSourceShown(ctx)
            end, function()
                Gear.ToggleSource(ctx)
                return MenuResponse.Refresh
            end)
            if srcCheck and srcCheck.SetTooltip then
                srcCheck:SetTooltip(function(tip)
                    GameTooltip_AddNormalLine(
                        tip,
                        L["settings.hint.gear_source_no_icons"] or "Appears in the table and list views."
                    )
                end)
            end
        end)
    end)
    cog:Hide()
    inst.variantCog = cog
    if ns.MakeCogGlow then
        ns.MakeCogGlow(cog, icon)
        ns.MakeLabelMenuHotspot(inst.header, cog)
    end
end

local function placeCog(inst, title)
    local cog = inst.variantCog
    if not cog then return end
    if title then
        cog:SetParent(title)
        if ns.LinkCogHover then
            ns.LinkCogHover(title, cog)
            ns.LinkCogMenu(title, cog, "LeftButton")
        end
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

local CARD_INSET_X = 8

local function hideIcons(icons)
    for i = 1, #icons do
        if icons[i] then icons[i]:Hide() end
    end
end

local function layoutGrid(content, icons, items)
    hideIcons(icons)
    local count = math.min(#items, #icons)
    if count == 0 then return 0 end

    local width = content:GetWidth()
    if not width or width < 100 then width = 300 end
    local maxPerRow = math.max(1, math.floor((width - GRID_INSET * 2) / ICON_STRIDE))
    local numRows = math.ceil(count / maxPerRow)
    local perRow = math.ceil(count / numRows)

    local y = -TOP_PAD
    for i = 1, count do
        local item = items[i]
        local ic = icons[i]
        local rowN = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow
        local iconsInRow = math.min(perRow, count - rowN * perRow)
        local totalRowW = (iconsInRow - 1) * ICON_STRIDE + ICON_SIZE
        local rowStartX = (width - totalRowW) / 2
        local x = rowStartX + col * ICON_STRIDE

        ic:ClearAllPoints()
        ic:SetPoint("TOPLEFT", content, "TOPLEFT", x, y - rowN * ROW_STRIDE)

        ic:SetItem(item.itemId)
        ic.itemId = item.itemId
        ic.bonusIDs = item.bonusIDs
        ic.altItemId = nil
        ic.embItemId = nil
        ic.sourceText = item.sourceText
        ic.popText = item.popText
        ic:ToggleMarker("owned", item.isOwned and true or false)
        ic:Show()
    end

    return numRows * ROW_STRIDE + TOP_PAD
end

local function buildRows(inst)
    inst.rows = {}
    local inset = CARD_INSET_X
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, inst.content)
        row:SetHeight(CARD_HEIGHT)

        row.icon = ns.CreateSlotIcon(row, { size = ICON_SIZE, slotSize = SLOT_FRAME })
        row.icon:SetPoint("LEFT", row, "LEFT", inset, 0)

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", row.icon.slot, "RIGHT", 2, 0)
        name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        row.itemText = name

        local src = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        src:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, 0)
        src:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        src:SetJustifyH("LEFT")
        src:SetWordWrap(false)
        src:SetTextColor(0.5, 0.5, 0.52)
        src:Hide()
        row.sourceLine = src

        ns.SetupItemTooltip(row)
        row:Hide()
        inst.rows[i] = row
    end

    inst.icons = {}
    for i = 1, MAX_ROWS do
        local ic = ns.CreateSlotIcon(inst.content, { size = ICON_SIZE, slotSize = SLOT_FRAME })
        ns.SetupItemTooltip(ic)
        ic:Hide()
        inst.icons[i] = ic
    end

    inst.tableRows = {}
    for i = 1, MAX_ROWS do
        inst.tableRows[i] = ns.MakeTableRow(inst.content)
    end

    inst.fallback = inst.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inst.fallback:SetTextColor(0.5, 0.5, 0.5)
    inst.fallback:Hide()
end

local function render(inst, args)
    if not inst.rows then return 0 end
    for i = 1, MAX_ROWS do
        inst.rows[i]:Hide()
    end
    hideIcons(inst.icons)
    inst.fallback:Hide()
    inst.lastContentHeight = 0

    local bisGear = args.bisGear
    local hasGear = bisGear and #bisGear > 0
    local hasPvP = bisGear and FindTabByLabel(bisGear, "PvP") ~= nil

    if not hasGear then
        if inst.variantCog then inst.variantCog:Hide() end
        if inst.section then inst.section:Hide() end
        return 0
    end

    local class, spec = args.class, args.spec
    if not class and ns.GetClassAndSpec then
        class, spec = ns.GetClassAndSpec()
    end
    local curSource = args.source or (ns.ActiveSource and ns.ActiveSource()) or "icyveins"
    local specKey = args.specKey or (ns.GetSpecKey and ns.GetSpecKey())

    local contentOpts = {
        { label = CONTENT_LABEL.mplus, value = "mplus" },
        { label = CONTENT_LABEL.raid, value = "raid" },
    }
    if hasPvP then contentOpts[#contentOpts + 1] = { label = CONTENT_LABEL.pvp, value = "pvp" } end
    local curCT = args.contentType or (ns.Context and ns.Context.contentType())
    local function ctOk(ct)
        for _, o in ipairs(contentOpts) do
            if o.value == ct then return true end
        end
    end
    if not ctOk(curCT) then curCT = contentOpts[1] and contentOpts[1].value or "mplus" end

    local variants = ns.GearVariants(class, spec, curSource, curCT)
    local variantLabels = {}
    for _, v in ipairs(variants) do
        variantLabels[#variantLabels + 1] = v.label
    end
    local _, savedVariant = LoadBisPrefs(specKey)
    local curVariant = savedVariant
    local ok = false
    for _, l in ipairs(variantLabels) do
        if l == curVariant then
            ok = true
            break
        end
    end
    if not ok then curVariant = variantLabels[1] end
    local tab = curVariant and FindTabByLabel(bisGear, curVariant)
    local selectedSlots = tab and tab.slots

    inst.variantOptions = variantLabels
    inst.currentVariant = curVariant
    if inst.header and inst.header.label then
        local base = L["tab.best_in_slot"] or "Best in Slot"
        if curVariant and curVariant ~= "" then
            inst.header.label:SetText(base .. " · " .. curVariant)
        else
            inst.header.label:SetText(base)
        end
    end
    inst.onVariantPick = function(picked)
        SaveBisPrefs(specKey, nil, picked)
        if args.onChange then args.onChange() end
        if args.refresh then args.refresh() end
    end
    if inst.variantCog then inst.variantCog:SetShown(true) end

    if not selectedSlots or #selectedSlots == 0 then
        inst.fallback:SetText(L["pvp.no_gear_data"] or "No gear data for this context yet.")
        inst.fallback:ClearAllPoints()
        inst.fallback:SetPoint("TOPLEFT", 4, -4)
        inst.fallback:Show()
        inst.lastContentHeight = 24
        ns.SetContentHeight(inst.content, 24)
        if inst.section then inst.section:Show() end
        return 0
    end

    local ctxBonus = (curCT == "raid") and "raid" or "dungeon"
    local count = math.min(#selectedSlots, MAX_ROWS)
    local viewMode = Gear.GetViewMode(args._viewCtx)
    local showSource = Gear.IsSourceShown(args._viewCtx)

    if viewMode == "icons" then
        local items = {}
        for i = 1, count do
            local entry = selectedSlots[i]
            local source, bonusIDs = ResolveRow(entry, nil, ctxBonus)
            local owned = ns.IsItemOwned(entry.item.itemId)
            if inst.gateOwned then owned = owned and ns.compOwnClass end
            items[#items + 1] = {
                itemId = entry.item.itemId,
                bonusIDs = bonusIDs,
                sourceText = (source ~= "" and source) or nil,
                popText = entry.pop and (entry.pop .. "%") or nil,
                isOwned = owned,
            }
        end
        for i = 1, MAX_ROWS do
            if inst.tableRows and inst.tableRows[i] then inst.tableRows[i]:Hide() end
        end
        inst.lastContentHeight = layoutGrid(inst.content, inst.icons, items)
    elseif viewMode == "table" then
        local items = {}
        for i = 1, count do
            local entry = selectedSlots[i]
            local source, bonusIDs = ResolveRow(entry, nil, ctxBonus)
            local owned = ns.IsItemOwned(entry.item.itemId)
            if inst.gateOwned then owned = owned and ns.compOwnClass end
            items[#items + 1] = {
                itemId = entry.item.itemId,
                bonusIDs = bonusIDs,
                sourceText = (source ~= "" and source) or nil,
                popText = entry.pop and (entry.pop .. "%") or nil,
                isOwned = owned,
                label = entry.slot,
            }
        end
        hideIcons(inst.icons)
        -- The column is never hidden by panel width — the toggle is an explicit
        -- choice; it scales down instead so the item name keeps room.
        local tableOpts = nil
        if showSource then
            tableOpts = { showSource = true }
            local w = inst.content:GetWidth() or 0
            if w > 0 then tableOpts.sourceWidth = math.min(160, math.floor(w * 0.34)) end
        end
        inst.lastContentHeight = ns.LayoutTable(inst.content, inst.tableRows, items, tableOpts)
    else
        for i = 1, MAX_ROWS do
            if inst.tableRows and inst.tableRows[i] then inst.tableRows[i]:Hide() end
        end
        for i = 1, count do
            local entry = selectedSlots[i]
            local row = inst.rows[i]
            local source, bonusIDs = ResolveRow(entry, nil, ctxBonus)
            local itemLabel = ns.FormatItem(entry.item)
            row.itemText:SetText(itemLabel)
            local hasSource = showSource and source and source ~= ""
            local yOff = hasSource and 5 or 0
            row.itemText:ClearAllPoints()
            row.itemText:SetPoint("LEFT", row.icon.slot, "RIGHT", 2, yOff)
            row.itemText:SetPoint("RIGHT", row, "RIGHT", -4, yOff)
            if hasSource then
                row.sourceLine:SetText(source)
                row.sourceLine:Show()
            else
                row.sourceLine:Hide()
            end
            row.itemId = entry.item.itemId
            row.bonusIDs = bonusIDs
            row.altItemId = nil
            row.embItemId = nil
            row.sourceText = (source ~= "" and source) or nil
            row.popText = entry.pop and (entry.pop .. "%") or nil
            row.icon:SetItem(entry.item.itemId)
            local owned = ns.IsItemOwned(entry.item.itemId)
            if inst.gateOwned then owned = owned and ns.compOwnClass end
            row.icon:ToggleMarker("owned", owned and true or false)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(i - 1) * CARD_HEIGHT)
            row:SetPoint("RIGHT", 0, 0)
            row:Show()
        end
        inst.lastContentHeight = count * CARD_HEIGHT
    end

    ns.SetContentHeight(inst.content, inst.lastContentHeight)
    if inst.section then inst.section:Show() end
    return count
end

local panel = {}
local comp = { gateOwned = true }

function Gear.InitPanel(parent, cogTitle)
    panel.section, panel.header, panel.content = ns.CreateCollapsibleSection(parent, {
        label = L["tab.best_in_slot"],
        stateKey = "bisGear",
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

function Gear.RenderPanel(args)
    args._viewCtx = nil
    return render(panel, args)
end

function Gear.GetPanelFrames()
    return {
        section = panel.section,
        content = panel.content,
        collapsed = panel.section.IsCollapsed and panel.section.IsCollapsed() or false,
    }
end

function Gear.InitCompendium(opts)
    comp.section = CreateFrame("Frame", nil, opts.parent)
    comp.header = opts.headerFactory(comp.section, L["tab.best_in_slot"], false)
    comp.content = CreateFrame("Frame", nil, comp.section)
    comp.content:SetPoint("TOPLEFT", comp.header, "BOTTOMLEFT", 0, 0)
    comp.content:SetPoint("RIGHT", 0, 0)
    makeCog(comp, "comp")
    placeCog(comp, opts.cogTitle)
    buildRows(comp)
    return comp.section, comp.header, comp.content
end

function Gear.RenderCompendium(args)
    args._viewCtx = "comp"
    return render(comp, args)
end

function Gear.GetCompendiumContentHeight()
    if not comp.rows then return 0 end
    if comp.fallback:IsShown() then return 24 end
    return comp.lastContentHeight or 0
end
