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

-- Upgrade-track ticks default on; the key only exists once turned off.
function Gear.IsTrackTicksShown(context)
    context = viewContext(context)
    local shown = ClassCodexDB and ClassCodexDB["gearTicks_" .. context]
    return shown ~= false
end

function Gear.SetTrackTicksShown(shown, context)
    context = viewContext(context)
    if not ClassCodexDB then ClassCodexDB = {} end
    ClassCodexDB["gearTicks_" .. context] = shown and true or false
    refreshView(context)
end

-- Group by Source defaults off; per context like the settings above.
function Gear.IsGrouped(context)
    context = viewContext(context)
    return (ClassCodexDB and ClassCodexDB["gearGroup_" .. context]) == true
end

function Gear.SetGrouped(grouped, context)
    context = viewContext(context)
    if not ClassCodexDB then ClassCodexDB = {} end
    ClassCodexDB["gearGroup_" .. context] = grouped and true or false
    refreshView(context)
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

-- Catalyst entries: the bonuses ride the DISPLAYED tier piece and the source
-- id rides the link as item modifier 64 (the engine's original-item pointer,
-- which applies the conversion's retained source stats). The source id also
-- feeds the "Catalyzed from" tooltip line.
local function ResolveStatIds(entry, bonusIDs)
    local cat = entry.item and entry.item.catalyst
    if cat then return cat.bonusIDs, cat.itemId end
    return bonusIDs, nil
end

local function resolveTick(inst, ticksOn, entry, rowBonus, catalystItemId)
    if not ticksOn then return nil end
    if inst.gateOwned and not ns.compOwnClass then return nil end
    return ns.GearTickForEntry(entry.slot, entry.item.itemId, rowBonus, catalystItemId)
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
            .Hint(L["gear.cog_hint"])
            .Show()
    end)
    cog:SetScript("OnLeave", function()
        icon:SetVertexColor(0.6, 0.6, 0.6)
        ns.Tooltip.Hide()
    end)
    cog:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        if ns.PinScroll then ns.PinScroll(self) end
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
            local groupCheck = root:CreateCheckbox(L["settings.label.gear_group"], function()
                return Gear.IsGrouped(ctx)
            end, function()
                Gear.SetGrouped(not Gear.IsGrouped(ctx), ctx)
                return MenuResponse.Refresh
            end)
            if groupCheck and groupCheck.SetTooltip then
                groupCheck:SetTooltip(function(tip)
                    ns.Tooltip.MenuTip(tip, L["settings.label.gear_group"], L["settings.hint.gear_group"])
                end)
            end
            local srcCheck = root:CreateCheckbox(L["settings.label.gear_source"] or "Show Item Source", function()
                return Gear.IsSourceShown(ctx)
            end, function()
                Gear.ToggleSource(ctx)
                return MenuResponse.Refresh
            end)
            if srcCheck and srcCheck.SetTooltip then
                srcCheck:SetTooltip(function(tip)
                    ns.Tooltip.MenuTip(
                        tip,
                        L["settings.label.gear_source"] or "Show Item Source",
                        L["settings.hint.gear_source_grouped"]
                    )
                end)
            end
            local tickCheck = root:CreateCheckbox(
                L["settings.label.gear_ticks"] or "Show Upgrade Track Ticks",
                function()
                    return Gear.IsTrackTicksShown(ctx)
                end,
                function()
                    Gear.SetTrackTicksShown(not Gear.IsTrackTicksShown(ctx), ctx)
                    return MenuResponse.Refresh
                end
            )
            if tickCheck and tickCheck.SetTooltip then
                tickCheck:SetTooltip(function(tip)
                    ns.Tooltip.MenuTip(
                        tip,
                        L["settings.label.gear_ticks"] or "Show Upgrade Track Ticks",
                        L["settings.hint.gear_ticks"]
                            or "Ticks compare your equipped item with each Best in Slot or Trinkets row. Green means it has reached the row's item level. Yellow means it is below."
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
        ic.catalystItemId = item.catalystItemId
        ic.ejClassID = item.ejClassID
        ic.ejSpecID = item.ejSpecID
        ic.altItemId = nil
        ic.embItemId = nil
        ic.sourceText = item.sourceText
        ic.popText = item.popText
        ic:ToggleMarker("owned", item.isOwned and true or false)
        ic:SetMarkerColor("owned", item.tickColor)
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

local function buildItem(inst, entry, ctxBonus, ticksOn, viewMode, ejClassID, ejSpecID)
    local source, bonusIDs = ResolveRow(entry, nil, ctxBonus)
    local rowBonus, catalystItemId = ResolveStatIds(entry, bonusIDs)
    local owned = ns.IsItemOwned(entry.item.itemId)
    if inst.gateOwned then owned = owned and ns.compOwnClass end
    local tick = resolveTick(inst, ticksOn, entry, rowBonus, catalystItemId)
    -- The table draws the tick as its checkmark; the slot views mark the icon.
    if tick and viewMode ~= "table" then owned = true end
    return {
        entry = entry,
        itemId = entry.item.itemId,
        bonusIDs = rowBonus,
        catalystItemId = catalystItemId,
        ejClassID = ejClassID,
        ejSpecID = ejSpecID,
        source = source,
        sourceText = (source ~= "" and source) or nil,
        popText = entry.pop and (entry.pop .. "%") or nil,
        isOwned = owned,
        tickColor = tick,
        label = entry.slot,
    }
end

local function layoutList(content, rows, items, showSource)
    local count = math.min(#items, #rows)
    for i = 1, count do
        local item = items[i]
        local row = rows[i]
        local source = item.source
        row.itemText:SetText(ns.FormatItem(item.entry.item))
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
        row.itemId = item.itemId
        row.bonusIDs = item.bonusIDs
        row.catalystItemId = item.catalystItemId
        row.ejClassID = item.ejClassID
        row.ejSpecID = item.ejSpecID
        row.altItemId = nil
        row.embItemId = nil
        row.sourceText = item.sourceText
        row.popText = item.popText
        row.icon:SetItem(item.itemId)
        row.icon:ToggleMarker("owned", item.isOwned and true or false)
        row.icon:SetMarkerColor("owned", item.tickColor)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * CARD_HEIGHT)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        row:Show()
    end
    return count * CARD_HEIGHT
end

-- Group by Source: one collapsible header per boss, dungeon, Crafted and
-- Other, with that source's rows under it in the current view.
local GROUP_HEADER_H = 28
local GROUP_GAP = 2
-- Every later group header starts right under the line above it. The
-- first one must start right under the section divider, which sits above
-- our content's top by the panel's content pad (both panels: 4) plus the
-- 3 px the section header draws its divider above its own bottom edge.
local SECTION_DIVIDER_LIFT = 3
local function groupTopPad()
    return -((ns.SECTION_CONTENT_PAD or 4) + SECTION_DIVIDER_LIFT)
end
local GROUP_ICON = 18
local GROUP_CHEVRON = "common-dropdown-icon-next"
local GROUP_ROTATE_S = 0.15
local GROUP_OPEN_S = 0.18
local GROUP_CLOSE_S = 0.12
-- Headers look the same in every view: the icon centered on the table's
-- item-icon column, the title on its slot-name column.
local GROUP_ICON_CENTER = 16
local GROUP_LABEL_X = 35
local GROUP_CRAFTED_ICON = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-crafting"
local GROUP_OTHER_ICON = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-gear"
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local GROUP_LABEL = { 0.92, 0.92, 0.92 }
local GROUP_LABEL_HL = { 1, 0.82, 0 }
local GROUP_CHEVRON_TINT = 0.6

local function groupOpenState()
    if not ClassCodexDB then ClassCodexDB = {} end
    ClassCodexDB.gearGroupOpen = ClassCodexDB.gearGroupOpen or {}
    return ClassCodexDB.gearGroupOpen
end

local function acquireGroupFrames(inst, i)
    inst.groupHeaders = inst.groupHeaders or {}
    inst.groupBodies = inst.groupBodies or {}
    local h = inst.groupHeaders[i]
    if not h then
        -- Flat like the section headers: the source's ringed portrait or
        -- dungeon icon (as on the talent cards), label, count, and the
        -- open/closed arrow on the right; hairline below.
        h = CreateFrame("Button", nil, inst.content)
        h:SetHeight(GROUP_HEADER_H)
        h:RegisterForClicks("LeftButtonUp")
        h.icon = h:CreateTexture(nil, "ARTWORK")
        h.icon:SetSize(GROUP_ICON, GROUP_ICON)
        h.icon:SetPoint("CENTER", h, "LEFT", GROUP_ICON_CENTER, 0)
        local mask = h:CreateMaskTexture()
        mask:SetAllPoints(h.icon)
        mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        h.icon:AddMaskTexture(mask)
        h.ring = h:CreateTexture(nil, "OVERLAY")
        h.ring:SetAtlas("Artifacts-PerkRing-Final")
        h.ring:SetPoint("CENTER", h.icon, "CENTER")
        h.ring:SetSize(GROUP_ICON * 1.42, GROUP_ICON * 1.42)
        h.chevron = h:CreateTexture(nil, "OVERLAY")
        h.chevron:SetAtlas(GROUP_CHEVRON)
        h.chevron:SetSize(12, 12)
        -- Centered under the section's cog (14 px, PAGE_TITLE_HPAD from the
        -- right edge) and the page's link arrow above it.
        local cogCenter = (ns.PAGE_TITLE_HPAD or 8) + 7
        h.chevron:SetPoint("CENTER", h, "RIGHT", -cogCenter, 0)
        h.chevron:SetVertexColor(GROUP_CHEVRON_TINT, GROUP_CHEVRON_TINT, GROUP_CHEVRON_TINT)
        local spin = h.chevron:CreateAnimationGroup()
        h.spinRot = spin:CreateAnimation("Rotation")
        h.spinRot:SetOrigin("CENTER", 0, 0)
        h.spinRot:SetDuration(GROUP_ROTATE_S)
        h.spinRot:SetSmoothing("OUT")
        spin:SetScript("OnFinished", function()
            h.chevron:SetRotation(h.angle or 0)
        end)
        h.spin = spin
        h.label = h:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        h.label:SetPoint("LEFT", h, "LEFT", GROUP_LABEL_X, 0)
        h.label:SetPoint("RIGHT", h.chevron, "LEFT", -6, 0)
        h.label:SetJustifyH("LEFT")
        h.label:SetWordWrap(false)
        h.label:SetTextColor(GROUP_LABEL[1], GROUP_LABEL[2], GROUP_LABEL[3])
        local line = h:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.35, 0.35, 0.35, 0.40)
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", 1, 0)
        line:SetPoint("BOTTOMRIGHT", -2, 0)
        -- Closes off an open drawer above this header.
        local top = h:CreateTexture(nil, "ARTWORK")
        top:SetColorTexture(0.35, 0.35, 0.35, 0.40)
        top:SetHeight(1)
        top:SetPoint("TOPLEFT", 1, 0)
        top:SetPoint("TOPRIGHT", -2, 0)
        top:Hide()
        h.topLine = top
        h:SetScript("OnEnter", function(self)
            self.label:SetTextColor(GROUP_LABEL_HL[1], GROUP_LABEL_HL[2], GROUP_LABEL_HL[3])
            if self.tipBody then
                ns.Tooltip
                    .Open(self, "ANCHOR_RIGHT")
                    .Title(self.tipTitle)
                    .Body(self.tipBody)
                    .Blank()
                    .Hint(self.tipHint)
                    .Show()
            end
            self.chevron:SetVertexColor(1, 1, 1)
        end)
        h:SetScript("OnLeave", function(self)
            ns.Tooltip.Hide()
            self.label:SetTextColor(GROUP_LABEL[1], GROUP_LABEL[2], GROUP_LABEL[3])
            self.chevron:SetVertexColor(GROUP_CHEVRON_TINT, GROUP_CHEVRON_TINT, GROUP_CHEVRON_TINT)
        end)
        inst.groupHeaders[i] = h
    end
    local b = inst.groupBodies[i]
    if not b then
        -- The body parents its rows while grouped and clips them, so a
        -- drawer opens and closes by growing or shrinking its height. The
        -- headers below anchor to it and follow.
        b = CreateFrame("Frame", nil, inst.content)
        b:SetClipsChildren(true)
        local drawer = b:CreateAnimationGroup()
        local step = drawer:CreateAnimation("Animation")
        step:SetSmoothing("IN_OUT")
        drawer:SetScript("OnUpdate", function()
            local p = step:GetSmoothProgress() or 0
            b:SetHeight(math.max(1, b.fromH + (b.toH - b.fromH) * p))
        end)
        drawer:SetScript("OnFinished", function()
            b:SetHeight(math.max(1, b.toH))
            local done = b.onDone
            b.onDone = nil
            if done then done() end
        end)
        b.drawer, b.drawerStep = drawer, step
        inst.groupBodies[i] = b
    end
    return h, b
end

local function runDrawer(body, fromH, toH, duration, onDone)
    body.drawer:Stop()
    body.fromH, body.toH, body.onDone = fromH, toH, onDone
    body:SetHeight(math.max(1, fromH))
    body.drawerStep:SetDuration(duration)
    body.drawer:Play()
end

local function turnChevron(h, angle, animate)
    if h.angle == angle then return end
    h.spin:Stop()
    if animate and h.angle ~= nil then
        h.chevron:SetRotation(h.angle)
        h.spinRot:SetRadians(angle - h.angle)
        h.angle = angle
        h.spin:Play()
    else
        h.angle = angle
        h.chevron:SetRotation(angle)
    end
end

-- Boss portrait for a raid or world boss, the dungeon's icon for a dungeon,
-- the Crafting tab icon for Crafted, the Gear tab icon for Other, and a
-- content-type icon when the journal has no art.
local function setGroupIcon(h, src)
    local tex = h.icon
    tex:SetVertexColor(1, 1, 1)
    tex:SetTexCoord(0, 1, 0, 1)
    if src.kind == "encounter" and EJ_GetCreatureInfo and SetPortraitTextureFromCreatureDisplayID then
        local displayID = select(4, EJ_GetCreatureInfo(1, src.encounterID))
        if displayID then
            SetPortraitTextureFromCreatureDisplayID(tex, displayID)
            return
        end
    end
    if src.kind == "instance" then
        local name = src.instanceID and EJ_GetInstanceInfo and EJ_GetInstanceInfo(src.instanceID)
        local icon = name and ns.GetDungeonIconByName and ns.GetDungeonIconByName(name)
        if icon then
            tex:SetTexture(icon)
            return
        end
    end
    if src.kind == "crafted" then
        tex:SetTexture(GROUP_CRAFTED_ICON)
        tex:SetVertexColor(1, 0.82, 0)
        return
    end
    local kind = (src.kind == "encounter" and "raid") or (src.kind == "instance" and "mplus") or nil
    local atlas = ns.GetContentFallbackAtlas and ns.GetContentFallbackAtlas(kind or "mplus")
    if atlas and kind then
        tex:SetAtlas(atlas)
    else
        tex:SetTexture(GROUP_OTHER_ICON)
        tex:SetVertexColor(0.6, 0.6, 0.62)
    end
end

-- A drawer that is still opening or closing stays shown unless `all`:
-- hiding it would stop its animation when a render pass runs mid-move.
local function hideGroups(inst, all)
    for _, f in ipairs(inst.groupHeaders or {}) do
        f:Hide()
    end
    for _, f in ipairs(inst.groupBodies or {}) do
        if all or not f.drawer:IsPlaying() then
            f.drawer:Stop()
            f.onDone = nil
            f:Hide()
        end
    end
end

-- done(entry) is nil when ownership does not apply (another class in the
-- Compendium); the headers then show only the item count.
local function layoutGroups(inst, entries, content, class, spec, pool, itemsFor, layout, viewCtx, done, ticksOn)
    local RS = ns.RollSource
    local groups = RS.Group(entries, content, RS.Lookups(class, spec, content), RS.Label, done)
    local open = groupOpenState()
    local y, used = groupTopPad(), 0
    local prev -- frame the next header hangs under
    for gi, g in ipairs(groups) do
        local h, body = acquireGroupFrames(inst, gi)
        local isOpen = open[g.key]
        if isOpen == nil then isOpen = gi == 1 end
        h:ClearAllPoints()
        if prev then
            h:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, prev == inst.groupBodies[gi - 1] and -GROUP_GAP or 0)
        else
            h:SetPoint("TOPLEFT", inst.content, "TOPLEFT", 0, -y)
        end
        h:SetPoint("RIGHT", inst.content, "RIGHT", 0, 0)
        h.topLine:SetShown(prev ~= nil and prev == inst.groupBodies[gi - 1])
        -- The chevron points right when closed and down when open; a click
        -- on the same header turns it instead of snapping.
        if h.groupKey ~= g.key then h.angle = nil end
        turnChevron(h, isOpen and -math.pi / 2 or 0, true)
        h.groupKey = g.key
        setGroupIcon(h, g.source)
        local countText = string.format(L[g.count == 1 and "gear.group.item_one" or "gear.group.items"], g.count)
        local shown = countText
        h.tipTitle, h.tipBody, h.tipHint = g.label, nil, nil
        if done then
            shown = g.done .. "/" .. g.count
            if g.done >= g.count then shown = "|cff66ff66" .. shown .. "|r" end
            h.tipBody = string.format(L["gear.group.tip_done"], g.done, g.count)
            h.tipHint = L[ticksOn and "gear.group.tip_rule_ticks" or "gear.group.tip_rule_owned"]
        end
        h.label:SetText((g.label or "") .. "  |cff9a9a9a" .. ns.DOT_SEPARATOR .. "  " .. shown .. "|r")
        local key = g.key
        h:SetScript("OnClick", function()
            if body.onDone then return end
            if isOpen and body:IsShown() then
                -- Close: shrink the drawer, then lay the list out again.
                turnChevron(h, 0, true)
                runDrawer(body, body:GetHeight(), 1, GROUP_CLOSE_S, function()
                    groupOpenState()[key] = false
                    refreshView(viewCtx)
                end)
            else
                groupOpenState()[key] = true
                inst.groupOpening = key
                refreshView(viewCtx)
            end
        end)
        h:Show()
        y = y + GROUP_HEADER_H
        prev = h
        if isOpen then
            local slots = {}
            for i = 1, #g.entries do
                local f = pool[used + i]
                if f then f:SetParent(body) end
                slots[i] = f
            end
            used = used + #g.entries
            body:ClearAllPoints()
            body:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -GROUP_GAP)
            body:SetPoint("RIGHT", inst.content, "RIGHT", 0, 0)
            local hgt = layout(body, slots, itemsFor(g.entries))
            body:Show()
            if inst.groupOpening == key then
                inst.groupOpening = nil
                runDrawer(body, 1, hgt, GROUP_OPEN_S)
            elseif not body.drawer:IsPlaying() then
                body:SetHeight(math.max(hgt, 1))
            elseif not body.onDone then
                -- A render pass during the opening keeps the drawer running.
                body.toH = hgt
            end
            y = y + GROUP_GAP + hgt + GROUP_GAP
            prev = body
        elseif not body.onDone then
            body.drawer:Stop()
            body:Hide()
        end
    end
    for i = #groups + 1, #(inst.groupBodies or {}) do
        inst.groupBodies[i].drawer:Stop()
        inst.groupBodies[i]:Hide()
    end
    return y
end

local function render(inst, args)
    if not inst.rows then return 0 end
    for i = 1, MAX_ROWS do
        inst.rows[i]:Hide()
    end
    hideIcons(inst.icons)
    hideGroups(inst)
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
    -- Journal loot-filter target: the spec being browsed — the player's own
    -- in the panel, the compendium's subject in the compendium. args.spec
    -- must win: specKey falls back to the PLAYER's spec key when the caller
    -- (compendium) doesn't pass one, which would shadow the browsed spec.
    local ejClassID, ejSpecID
    if ns.GetSpecIDForKeys then
        ejClassID, ejSpecID = ns.GetSpecIDForKeys(class, spec or specKey)
    end
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
            inst.header.label:SetText(base .. " " .. ns.DOT_SEPARATOR .. " " .. curVariant)
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
    local grouped = Gear.IsGrouped(args._viewCtx) and ns.RollSource ~= nil
    local showSource = Gear.IsSourceShown(args._viewCtx) and not grouped
    local ticksOn = Gear.IsTrackTicksShown(args._viewCtx)

    local entries = {}
    for i = 1, count do
        entries[i] = selectedSlots[i]
    end
    local function itemsFor(list)
        local items = {}
        for i, entry in ipairs(list) do
            items[i] = buildItem(inst, entry, ctxBonus, ticksOn, viewMode, ejClassID, ejSpecID)
        end
        return items
    end
    local tableOpts = nil
    if viewMode == "table" and showSource then
        -- The column is never hidden by panel width — the toggle is an explicit
        -- choice; it scales down instead so the item name keeps room.
        tableOpts = { showSource = true }
        local w = inst.content:GetWidth() or 0
        if w > 0 then tableOpts.sourceWidth = math.min(160, math.floor(w * 0.34)) end
    end
    local pool = viewMode == "icons" and inst.icons or (viewMode == "table" and inst.tableRows or inst.rows)
    local function layout(content, slots, items)
        if viewMode == "icons" then return layoutGrid(content, slots, items) end
        if viewMode == "table" then return ns.LayoutTable(content, slots, items, tableOpts) end
        return layoutList(content, slots, items, showSource)
    end

    hideIcons(inst.icons)
    for i = 1, MAX_ROWS do
        if inst.tableRows and inst.tableRows[i] then inst.tableRows[i]:Hide() end
    end

    if grouped then
        local content
        for _, v in ipairs(variants) do
            if v.label == curVariant then content = v.context end
        end
        local done
        if not (inst.gateOwned and not ns.compOwnClass) then
            -- With ticks on, done means a copy at the listed item level;
            -- with them off, owning the item is enough.
            done = function(entry)
                if not ticksOn then return ns.IsItemOwned(entry.item.itemId) and true or false end
                local bonusIDs = select(2, ResolveRow(entry, nil, ctxBonus))
                local rowBonus, catalystItemId = ResolveStatIds(entry, bonusIDs)
                local tick = ns.GearTickForEntry(entry.slot, entry.item.itemId, rowBonus, catalystItemId)
                return tick ~= nil and tick == (ns.TICK_COLORS and ns.TICK_COLORS.perfect)
            end
        end
        inst.lastContentHeight =
            layoutGroups(inst, entries, content, class, spec, pool, itemsFor, layout, args._viewCtx, done, ticksOn)
    else
        hideGroups(inst, true)
        for _, f in ipairs(pool) do
            f:SetParent(inst.content)
        end
        inst.lastContentHeight = layout(inst.content, pool, itemsFor(entries))
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
