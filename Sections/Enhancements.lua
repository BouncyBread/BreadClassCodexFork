local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

local Enhancements = {}
ns.Sections.Enhancements = Enhancements

local panel = {}
local comp = {}

local ICON_SIZE = 32
local SLOT_FRAME = math.floor(ICON_SIZE * 1.8125 + 0.5)
local ICON_STRIDE = 42
local ROW_STRIDE = 42
local TOP_PAD = 4
local GRID_INSET = 4
local LIST_ROW_H = 40
local LIST_INSET_X = 8
local LABEL_W = 60

local MAX_ENCHANT_ICONS = 24
local MAX_GEM_ICONS = 8
local MAX_CONSUM_ICONS = 8

local ENCH_SLOT_ORDER = {
    Head = 1,
    Neck = 2,
    Shoulders = 3,
    Back = 4,
    Chest = 5,
    Wrist = 6,
    Hands = 7,
    Waist = 8,
    Legs = 9,
    Feet = 10,
    ["Finger 1"] = 11,
    ["Finger 2"] = 12,
    ["Main Hand"] = 15,
    ["Off Hand"] = 16,
}

local function viewContext(override)
    if override then return override end
    if ns.isFloating and ns.isFloating() then return "float" end
    return "dock"
end

function Enhancements.GetViewMode(section, context)
    context = viewContext(context)
    return (ClassCodexDB and ClassCodexDB["enhView_" .. section .. "_" .. context]) or "table"
end

function Enhancements.SetViewMode(section, mode, context)
    context = viewContext(context)
    if not ClassCodexDB then ClassCodexDB = {} end
    ClassCodexDB["enhView_" .. section .. "_" .. context] = mode
    if context == "comp" then
        if comp.enchIcons then
            if ns.UpdateCompendiumEnchants then ns:UpdateCompendiumEnchants() end
            if ns.UpdateCompendiumConsumables then ns:UpdateCompendiumConsumables() end
            if ns.LayoutCompendium then ns:LayoutCompendium() end
        end
    else
        if ns.UpdateGearingSections then ns:UpdateGearingSections() end
        if ns.LayoutPanel then ns:LayoutPanel() end
    end
end

local function makeViewCog(header, section, ctx)
    if not (header and header.AddHeaderWidget) then return end
    local cog = CreateFrame("Button", nil, header)
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
            .Title(L["settings.value.view"] or "View")
            .Hint("Click to switch view.")
            .Show()
    end)
    cog:SetScript("OnLeave", function()
        icon:SetVertexColor(0.6, 0.6, 0.6)
        ns.Tooltip.Hide()
    end)
    cog:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle(L["settings.value.view"] or "View")
            root:CreateRadio(L["settings.value.table"] or "Table", function()
                return Enhancements.GetViewMode(section, ctx) == "table"
            end, function()
                Enhancements.SetViewMode(section, "table", ctx)
                return MenuResponse.Refresh
            end)
            root:CreateRadio(L["settings.value.list"] or "List", function()
                return Enhancements.GetViewMode(section, ctx) == "list"
            end, function()
                Enhancements.SetViewMode(section, "list", ctx)
                return MenuResponse.Refresh
            end)
            root:CreateRadio(L["settings.value.icons"] or "Icons", function()
                return Enhancements.GetViewMode(section, ctx) == "icons"
            end, function()
                Enhancements.SetViewMode(section, "icons", ctx)
                return MenuResponse.Refresh
            end)
        end)
    end)
    header:AddHeaderWidget(cog)
end

local function makeGridIcon(content)
    local ic = ns.CreateSlotIcon(content, { size = ICON_SIZE, slotSize = SLOT_FRAME })
    ns.SetupItemTooltip(ic)
    local countText = ic:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
    countText:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 1, -1)
    countText:SetJustifyH("RIGHT")
    countText:Hide()
    ic.countText = countText
    ic:Hide()
    return ic
end

local function makeListRow(content)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(LIST_ROW_H)

    row.icon = ns.CreateSlotIcon(row, { size = ICON_SIZE, slotSize = SLOT_FRAME })
    row.icon:SetPoint("LEFT", row, "LEFT", LIST_INSET_X, 0)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", row.icon.slot, "RIGHT", 4, 0)
    label:SetWidth(LABEL_W)
    label:SetJustifyH("LEFT")
    label:SetTextColor(0.6, 0.6, 0.6)
    row.labelText = label

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", label, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.itemText = name

    ns.SetupItemTooltip(row)
    row:Hide()
    return row
end

local function buildPool(content, max, factory)
    local pool = {}
    for i = 1, max do
        pool[i] = factory(content)
        -- This tab's items (enchants, gems, consumables) are what you'd shop
        -- for on the AH; gear/trinket rows elsewhere don't get the search.
        pool[i].allowAhSearch = true
    end
    return pool
end

local function hideAll(pool)
    for i = 1, #pool do
        pool[i]:Hide()
    end
end

local function layoutGrid(content, icons, items)
    hideAll(icons)
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

        if item.spellId then
            ic:SetSpell(item.spellId)
        elseif item.itemId then
            ic:SetItem(item.itemId)
        end
        ic.itemId = item.itemId
        ic.spellId = item.spellId
        ic.bonusIDs = nil
        ic.altItemId = nil
        ic.embItemId = nil
        ic.sourceText = item.sourceText
        ic.popText = item.popText

        ic:ToggleMarker("owned", item.isOwned and true or false)

        if item.count and item.count > 1 then
            ic.countText:SetText(tostring(item.count))
            ic.countText:Show()
        else
            ic.countText:Hide()
        end

        ic:Show()
    end

    return numRows * ROW_STRIDE + TOP_PAD
end

local function layoutList(content, rows, items)
    hideAll(rows)
    local count = math.min(#items, #rows)
    if count == 0 then return 0 end

    for i = 1, count do
        local item = items[i]
        local row = rows[i]

        row.labelText:SetText("")
        row.labelText:SetWidth(0)
        row.itemText:ClearAllPoints()
        row.itemText:SetPoint("LEFT", row.icon.slot, "RIGHT", 2, 0)
        local name = (item.itemId or item.spellId)
                and ns.FormatItem({ itemId = item.itemId, spellId = item.spellId, name = item.name })
            or ""
        if item.count and item.count > 1 then name = name .. "  |cff808080×" .. item.count .. "|r" end
        row.itemText:SetText(name)

        if item.spellId then
            row.icon:SetSpell(item.spellId)
        elseif item.itemId then
            row.icon:SetItem(item.itemId)
        end
        row.itemId = item.itemId
        row.spellId = item.spellId
        row.bonusIDs = nil
        row.altItemId = nil
        row.embItemId = nil
        row.sourceText = item.sourceText
        row.popText = item.popText
        row.icon:ToggleMarker("owned", item.isOwned and true or false)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * LIST_ROW_H)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        row:Show()
    end

    return count * LIST_ROW_H
end

local function renderSection(section, content, icons, rows, tableRows, items, context)
    local mode = Enhancements.GetViewMode(section, context)
    if mode == "table" then
        hideAll(icons)
        hideAll(rows)
        return ns.LayoutTable(content, tableRows, items)
    elseif mode == "list" then
        hideAll(icons)
        hideAll(tableRows)
        return layoutList(content, rows, items)
    else
        hideAll(rows)
        hideAll(tableRows)
        return layoutGrid(content, icons, items)
    end
end

local function buildEnchantItems(activeEnchants)
    local items = {}
    if not activeEnchants then return items end

    local sorted = {}
    for _, e in ipairs(activeEnchants) do
        sorted[#sorted + 1] = e
    end
    table.sort(sorted, function(a, b)
        return (ENCH_SLOT_ORDER[a.slot] or 99) < (ENCH_SLOT_ORDER[b.slot] or 99)
    end)

    for _, e in ipairs(sorted) do
        if e.best then
            -- Prefer the buyable enchant item (AH tooltip/link). Entries carrying
            -- only a spellId — DK Runeforge runes, which have no scroll item —
            -- render as the spell, so the raw enchant id must not leak into
            -- itemId (it would show as "Item 326805").
            local itemId = e.best.itemId or (e.best.spellId and nil) or e.best.enchantId
            items[#items + 1] = {
                itemId = itemId,
                spellId = e.best.spellId,
                isOwned = ns.IsEnchantApplied and ns.IsEnchantApplied(e.best, e.slot) or false,
                popText = e.best.pop and (e.best.pop .. "%") or nil,
                label = e.slot,
            }
        end
    end
    return items
end

local function buildGemItems(activeGems)
    local items = {}
    if not activeGems then return items end

    if activeGems.primary then
        local id = activeGems.primary.itemId
        items[#items + 1] = {
            itemId = id,
            isOwned = (ns.IsItemOwned(id) or (ns.IsGemSocketed and ns.IsGemSocketed(id))) and true or false,
            label = L["gem.primary"],
        }
    end
    if activeGems.secondary then
        for _, gem in ipairs(activeGems.secondary) do
            local id = gem.itemId
            items[#items + 1] = {
                itemId = id,
                isOwned = (ns.IsItemOwned(id) or (ns.IsGemSocketed and ns.IsGemSocketed(id))) and true or false,
                label = L["gem.secondary"],
            }
        end
    end
    return items
end

local function buildConsumableItems(activeConsumables)
    local items = {}
    if not activeConsumables then return items end

    for _, key in ipairs(ns.CONSUMABLE_ORDER) do
        local c = activeConsumables[key]
        if c then
            local id = c.itemId
            local count = (GetItemCount and GetItemCount(id)) or 0
            items[#items + 1] = {
                itemId = id,
                isOwned = count > 0,
                count = count,
                label = ns.CONSUMABLE_LABELS[key] or key,
            }
        end
    end
    return items
end

function Enhancements.InitPanel(opts)
    local parent = opts.parent

    panel.enchSection = CreateFrame("Frame", nil, parent)
    panel.enchSection:SetHeight(ns.SECTION_HEADER_HEIGHT)
    panel.enchHeader = ns.CreateSectionHeader(panel.enchSection, L["tab.enchants"])
    panel.enchContent = CreateFrame("Frame", nil, panel.enchSection)
    panel.enchContent:SetPoint("TOPLEFT", panel.enchHeader, "BOTTOMLEFT", 0, 0)
    panel.enchContent:SetPoint("RIGHT", 0, 0)
    ns.MakeCollapsible(
        panel.enchSection,
        panel.enchHeader,
        panel.enchContent,
        { stateKey = "enchants", refresh = opts.refresh }
    )
    panel.enchIcons = buildPool(panel.enchContent, MAX_ENCHANT_ICONS, makeGridIcon)
    panel.enchRows = buildPool(panel.enchContent, MAX_ENCHANT_ICONS, makeListRow)
    panel.enchTableRows = buildPool(panel.enchContent, MAX_ENCHANT_ICONS, ns.MakeTableRow)
    makeViewCog(panel.enchHeader, "enchants", nil)

    panel.sourceDropdown = ns.CreateOptionDropdown("ClassCodexDockEnhancementsSourceDropdown", parent)
    panel.sourceDropdown:Hide()

    panel.pvpFallback = panel.enchContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.pvpFallback:SetTextColor(0.5, 0.5, 0.5)
    panel.pvpFallback:Hide()

    panel.gemSection = CreateFrame("Frame", nil, parent)
    panel.gemSection:SetHeight(ns.SECTION_HEADER_HEIGHT)
    panel.gemHeader = ns.CreateSectionHeader(panel.gemSection, L["tab.gems"])
    panel.gemContent = CreateFrame("Frame", nil, panel.gemSection)
    panel.gemContent:SetPoint("TOPLEFT", panel.gemHeader, "BOTTOMLEFT", 0, 0)
    panel.gemContent:SetPoint("RIGHT", 0, 0)
    ns.MakeCollapsible(
        panel.gemSection,
        panel.gemHeader,
        panel.gemContent,
        { stateKey = "gems", refresh = opts.refresh }
    )
    panel.gemIcons = buildPool(panel.gemContent, MAX_GEM_ICONS, makeGridIcon)
    panel.gemRows = buildPool(panel.gemContent, MAX_GEM_ICONS, makeListRow)
    panel.gemTableRows = buildPool(panel.gemContent, MAX_GEM_ICONS, ns.MakeTableRow)
    makeViewCog(panel.gemHeader, "gems", nil)

    panel.consumSection = CreateFrame("Frame", nil, parent)
    panel.consumSection:SetHeight(ns.SECTION_HEADER_HEIGHT)
    panel.consumHeader = ns.CreateSectionHeader(panel.consumSection, L["tab.consumables"])
    panel.consumContent = CreateFrame("Frame", nil, panel.consumSection)
    panel.consumContent:SetPoint("TOPLEFT", panel.consumHeader, "BOTTOMLEFT", 0, 0)
    panel.consumContent:SetPoint("RIGHT", 0, 0)
    panel.consumContent:Show()
    ns.MakeCollapsible(
        panel.consumSection,
        panel.consumHeader,
        panel.consumContent,
        { stateKey = "consumables", refresh = opts.refresh }
    )
    panel.consumIcons = buildPool(panel.consumContent, MAX_CONSUM_ICONS, makeGridIcon)
    panel.consumRows = buildPool(panel.consumContent, MAX_CONSUM_ICONS, makeListRow)
    panel.consumTableRows = buildPool(panel.consumContent, MAX_CONSUM_ICONS, ns.MakeTableRow)
    makeViewCog(panel.consumHeader, "consumables", nil)

    panel.consumIvIcon = ns.CreateSourceAttributionIcon(
        panel.consumHeader,
        "icyveins",
        "Consumables",
        "Data from Icy Veins",
        function()
            if ns.ResolveAttribution and ns.GetClassAndSpec then
                local class, spec = ns.GetClassAndSpec()
                local _, url = ns.ResolveAttribution("crafting", class, spec)
                return url
            end
        end
    )
    if panel.consumHeader.AddHeaderWidget then panel.consumHeader:AddHeaderWidget(panel.consumIvIcon) end

    return {
        enchSection = panel.enchSection,
        gemSection = panel.gemSection,
        consumSection = panel.consumSection,
        sourceDropdown = panel.sourceDropdown,
    }
end

function Enhancements.GetPanelFrames()
    return {
        enchSection = panel.enchSection,
        enchContent = panel.enchContent,
        enchCollapsed = panel.enchSection.IsCollapsed and panel.enchSection.IsCollapsed() or false,
        gemSection = panel.gemSection,
        gemContent = panel.gemContent,
        gemCollapsed = panel.gemSection.IsCollapsed and panel.gemSection.IsCollapsed() or false,
        consumSection = panel.consumSection,
        consumContent = panel.consumContent,
        consumCollapsed = panel.consumSection.IsCollapsed and panel.consumSection.IsCollapsed() or false,
        sourceDropdown = panel.sourceDropdown,
    }
end

function Enhancements.HidePanelSourceDropdown()
    panel.sourceDropdown:Hide()
end

function Enhancements.RenderPanel(args)
    panel.sourceDropdown:Hide()

    local content = ns.Context and ns.Context.contentType()
    local isPvp = content == "pvp"
    local activeEnchants = (not isPvp) and args.enchants or nil
    local activeGems = (not isPvp) and args.gems or nil
    local activeConsumables = (not isPvp) and args.consumables or nil

    local pvpEnchantsMissing = isPvp

    panel.pvpFallback:Hide()
    local enchHeight = 0
    if activeEnchants and #activeEnchants > 0 then
        local items = buildEnchantItems(activeEnchants)
        enchHeight = renderSection(
            "enchants",
            panel.enchContent,
            panel.enchIcons,
            panel.enchRows,
            panel.enchTableRows,
            items,
            nil
        )
        panel.enchSection:Show()
    elseif pvpEnchantsMissing and args.showSourceDropdown then
        local msg = activeGems and (L["pvp.no_enchants"] or "No PvP enchants for this spec yet.")
            or (L["pvp.no_enchant_gem_data"] or "No PvP enchant/gem data for this spec yet.")
        panel.pvpFallback:SetText(msg)
        panel.pvpFallback:ClearAllPoints()
        panel.pvpFallback:SetPoint("TOPLEFT", 4, -4)
        panel.pvpFallback:Show()
        hideAll(panel.enchIcons)
        hideAll(panel.enchRows)
        enchHeight = 20
        panel.enchSection:Show()
    else
        hideAll(panel.enchIcons)
        hideAll(panel.enchRows)
        panel.enchSection:Hide()
    end

    local gemHeight = 0
    if activeGems then
        local items = buildGemItems(activeGems)
        if #items > 0 then
            gemHeight =
                renderSection("gems", panel.gemContent, panel.gemIcons, panel.gemRows, panel.gemTableRows, items, nil)
            panel.gemSection:Show()
        else
            hideAll(panel.gemIcons)
            hideAll(panel.gemRows)
            panel.gemSection:Hide()
        end
    else
        hideAll(panel.gemIcons)
        hideAll(panel.gemRows)
        panel.gemSection:Hide()
    end

    local consumHeight = 0
    if activeConsumables then
        local items = buildConsumableItems(activeConsumables)
        if #items > 0 then
            consumHeight = renderSection(
                "consumables",
                panel.consumContent,
                panel.consumIcons,
                panel.consumRows,
                panel.consumTableRows,
                items,
                nil
            )
            panel.consumSection:Show()
            if panel.consumIvIcon then
                local curSource = (ns.ActiveSource and ns.ActiveSource()) or "icyveins"
                panel.consumIvIcon:SetShown(curSource ~= "icyveins")
            end
        else
            hideAll(panel.consumIcons)
            hideAll(panel.consumRows)
            panel.consumSection:Hide()
        end
    else
        hideAll(panel.consumIcons)
        hideAll(panel.consumRows)
        panel.consumSection:Hide()
    end

    ns.SetContentHeight(panel.enchContent, enchHeight)
    ns.SetContentHeight(panel.gemContent, gemHeight)
    ns.SetContentHeight(panel.consumContent, consumHeight)

    return enchHeight, gemHeight, consumHeight
end

function Enhancements.InitCompendium(opts)
    comp.enchSection = CreateFrame("Frame", nil, opts.parent)
    comp.enchHeader = opts.headerFactory(comp.enchSection, L["tab.enchants"], true)
    comp.enchContent = CreateFrame("Frame", nil, comp.enchSection)
    comp.enchContent:SetPoint("TOPLEFT", comp.enchHeader, "BOTTOMLEFT", 0, 0)
    comp.enchContent:SetPoint("RIGHT", 0, 0)

    comp.sourceDropdown =
        CreateFrame("DropdownButton", "ClassCodexCompEnhancementsSourceDD", opts.parent, "WowStyle1DropdownTemplate")
    comp.sourceDropdown:SetHeight(24)
    comp.sourceDropdown:Hide()

    comp.enchIcons = buildPool(comp.enchContent, MAX_ENCHANT_ICONS, makeGridIcon)
    comp.enchRows = buildPool(comp.enchContent, MAX_ENCHANT_ICONS, makeListRow)
    comp.enchTableRows = buildPool(comp.enchContent, MAX_ENCHANT_ICONS, ns.MakeTableRow)
    comp.enchCollapsed = false
    comp.pvpFallback = comp.enchContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    comp.pvpFallback:SetTextColor(0.5, 0.5, 0.5)
    comp.pvpFallback:Hide()
    makeViewCog(comp.enchHeader, "enchants", "comp")
    comp.enchHeader:SetScript("OnClick", function()
        comp.enchCollapsed = not comp.enchCollapsed
        ns.SetCollapsed(comp.enchContent, comp.enchHeader, comp.enchCollapsed)
        if opts.refresh then opts.refresh() end
    end)

    comp.gemSection = CreateFrame("Frame", nil, opts.parent)
    comp.gemHeader = opts.headerFactory(comp.gemSection, L["tab.gems"], true)
    comp.gemContent = CreateFrame("Frame", nil, comp.gemSection)
    comp.gemContent:SetPoint("TOPLEFT", comp.gemHeader, "BOTTOMLEFT", 0, 0)
    comp.gemContent:SetPoint("RIGHT", 0, 0)
    comp.gemIcons = buildPool(comp.gemContent, MAX_GEM_ICONS, makeGridIcon)
    comp.gemRows = buildPool(comp.gemContent, MAX_GEM_ICONS, makeListRow)
    comp.gemTableRows = buildPool(comp.gemContent, MAX_GEM_ICONS, ns.MakeTableRow)
    comp.gemCollapsed = false
    makeViewCog(comp.gemHeader, "gems", "comp")
    comp.gemHeader:SetScript("OnClick", function()
        comp.gemCollapsed = not comp.gemCollapsed
        ns.SetCollapsed(comp.gemContent, comp.gemHeader, comp.gemCollapsed)
        if opts.refresh then opts.refresh() end
    end)

    comp.consumSection = CreateFrame("Frame", nil, opts.parent)
    comp.consumHeader = opts.headerFactory(comp.consumSection, L["tab.consumables"], false)
    comp.consumContent = CreateFrame("Frame", nil, comp.consumSection)
    comp.consumContent:SetPoint("TOPLEFT", comp.consumHeader, "BOTTOMLEFT", 0, 0)
    comp.consumContent:SetPoint("RIGHT", 0, 0)
    comp.consumIcons = buildPool(comp.consumContent, MAX_CONSUM_ICONS, makeGridIcon)
    comp.consumRows = buildPool(comp.consumContent, MAX_CONSUM_ICONS, makeListRow)
    comp.consumTableRows = buildPool(comp.consumContent, MAX_CONSUM_ICONS, ns.MakeTableRow)
    comp.consumCollapsed = false
    makeViewCog(comp.consumHeader, "consumables", "comp")

    comp.consumIvIcon = ns.CreateSourceAttributionIcon(
        comp.consumHeader,
        "icyveins",
        "Consumables",
        "Data from Icy Veins",
        function()
            if ns.ResolveAttribution then
                local _, url = ns.ResolveAttribution("crafting", selectedClass, selectedSpec)
                return url
            end
        end
    )
    if comp.consumHeader.AddHeaderWidget then comp.consumHeader:AddHeaderWidget(comp.consumIvIcon) end

    return {
        enchSection = comp.enchSection,
        enchHeader = comp.enchHeader,
        enchContent = comp.enchContent,
        gemSection = comp.gemSection,
        gemHeader = comp.gemHeader,
        gemContent = comp.gemContent,
        consumSection = comp.consumSection,
        consumHeader = comp.consumHeader,
        consumContent = comp.consumContent,
        sourceDropdown = comp.sourceDropdown,
    }
end

function Enhancements.GetCompendiumFrames()
    return {
        enchSection = comp.enchSection,
        enchContent = comp.enchContent,
        enchCollapsed = comp.enchCollapsed,
        gemSection = comp.gemSection,
        gemContent = comp.gemContent,
        gemCollapsed = comp.gemCollapsed,
        consumSection = comp.consumSection,
        consumContent = comp.consumContent,
        consumCollapsed = comp.consumCollapsed,
        sourceDropdown = comp.sourceDropdown,
    }
end

function Enhancements.RenderCompendiumEnchantsGems(args)
    if not comp.enchIcons then return end
    comp.pvpFallback:Hide()
    comp.sourceDropdown:Hide()

    comp.enchHeight = 0
    if args.enchants then
        local items = buildEnchantItems(args.enchants)
        if #items > 0 then
            comp.enchHeight = renderSection(
                "enchants",
                comp.enchContent,
                comp.enchIcons,
                comp.enchRows,
                comp.enchTableRows,
                items,
                "comp"
            )
            comp.enchSection:Show()
        else
            hideAll(comp.enchIcons)
            hideAll(comp.enchRows)
        end
    else
        hideAll(comp.enchIcons)
        hideAll(comp.enchRows)
    end

    comp.gemHeight = 0
    if args.gems then
        local items = buildGemItems(args.gems)
        if #items > 0 then
            comp.gemHeight =
                renderSection("gems", comp.gemContent, comp.gemIcons, comp.gemRows, comp.gemTableRows, items, "comp")
            comp.gemSection:Show()
        else
            hideAll(comp.gemIcons)
            hideAll(comp.gemRows)
        end
    else
        hideAll(comp.gemIcons)
        hideAll(comp.gemRows)
    end
end

function Enhancements.RenderCompendiumConsumables(args)
    comp.consumHeight = 0
    if not comp.consumIcons then return end
    if not args.consumables then
        hideAll(comp.consumIcons)
        hideAll(comp.consumRows)
        return
    end
    local items = buildConsumableItems(args.consumables)
    if comp.consumIvIcon then
        local curSource = args.source or "icyveins"
        comp.consumIvIcon:SetShown(#items > 0 and curSource ~= "icyveins")
    end
    if #items > 0 then
        comp.consumHeight = renderSection(
            "consumables",
            comp.consumContent,
            comp.consumIcons,
            comp.consumRows,
            comp.consumTableRows,
            items,
            "comp"
        )
        comp.consumSection:Show()
    else
        hideAll(comp.consumIcons)
        hideAll(comp.consumRows)
    end
end

function Enhancements.GetCompendiumEnchantHeight()
    return comp.enchHeight or 0
end

function Enhancements.GetCompendiumGemHeight()
    return comp.gemHeight or 0
end

function Enhancements.GetCompendiumConsumHeight()
    return comp.consumHeight or 0
end
