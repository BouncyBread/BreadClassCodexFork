local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

local Crafting = {}
ns.Sections.Crafting = Crafting

local ICON_SIZE = 32
local SLOT_FRAME = math.floor(ICON_SIZE * 1.8125 + 0.5)
local CARD_HEIGHT = 40
local CONTENT_INSET = 2

local CARD_INSET_X = CONTENT_INSET + 2
local TEXT_GAP_X = 5

local MAX_CRAFT_CARDS = 8
local MAX_EMB_CARDS = 7

local ICON_STRIDE = 42
local ROW_STRIDE = 42
local GRID_INSET = 4
local GRID_TOP_PAD = 6

local function viewContext(override)
    if override then return override end
    if ns.isFloating and ns.isFloating() then return "float" end
    return "dock"
end

function Crafting.GetViewMode(section, context)
    context = viewContext(context)
    return (ClassCodexDB and ClassCodexDB["craftView_" .. section .. "_" .. context]) or "table"
end

function Crafting.GetSortPopular(section)
    return (ClassCodexDB and ClassCodexDB["craftingPopular_" .. section]) and true or false
end

function Crafting.SetSortPopular(section, on)
    if not ClassCodexDB then ClassCodexDB = {} end
    ClassCodexDB["craftingPopular_" .. section] = on and true or false
    -- While the dropdown menu is open it owns input/layout for the frame;
    -- same-frame re-renders get suppressed. Defer one frame so the filter is
    -- visible the moment the menu closes.
    C_Timer.After(0, function()
        -- Pane first — it's where the toggle lives. Each update is isolated:
        -- the compendium's crafting renderer dereferences its UI unconditionally
        -- and errors before it has been opened once, which would abort the
        -- whole chain and leave the pane stale.
        pcall(function()
            if ns.UpdateGearingSections then ns:UpdateGearingSections() end
            if ns.UpdatePanel then ns:UpdatePanel() end
            if ns.LayoutPanel then ns:LayoutPanel() end
        end)
        pcall(function()
            if ns.UpdateCompendiumCrafts then ns:UpdateCompendiumCrafts() end
            if ns.LayoutCompendium then ns:LayoutCompendium() end
        end)
    end)
end

function Crafting.SetViewMode(section, mode, context)
    context = viewContext(context)
    if not ClassCodexDB then ClassCodexDB = {} end
    ClassCodexDB["craftView_" .. section .. "_" .. context] = mode
    if context == "comp" then
        if ns.UpdateCompendiumCrafts then ns:UpdateCompendiumCrafts() end
        if ns.LayoutCompendium then ns:LayoutCompendium() end
    else
        if ns.UpdateGearingSections then ns:UpdateGearingSections() end
        if ns.LayoutPanel then ns:LayoutPanel() end
    end
end

local CONTEXTS = {
    {
        key = "raid",
        label = function()
            return L["context.raid"]
        end,
    },
    {
        key = "mythicPlus",
        label = function()
            return L["context.mythic_plus"]
        end,
    },
    {
        key = "pvp",
        label = function()
            return L["pvp.label"]
        end,
    },
}

local CONTEXT_FROM_GENERIC = { mplus = "mythicPlus", raid = "raid", pvp = "pvp" }
local function GetPerSpecCtx()
    if ns.GetPerSpecState then
        local ps = ns.GetPerSpecState()
        if ps and ps.craftingContext then return ps.craftingContext end
    end
    return "raid"
end

function Crafting.GetContextKey()
    return GetPerSpecCtx()
end

local panel = {}
local EMBELLISHMENT_LIMIT = 2
local embBadges = {}

local equippedBonusIds
local equippedSpellIds
local UpdateEmbBadge

local function InvalidateEquippedState()
    equippedBonusIds = nil
    equippedSpellIds = nil
    if UpdateEmbBadge then UpdateEmbBadge() end
end

local stateFrame = CreateFrame("Frame")
stateFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
stateFrame:RegisterEvent("BAG_UPDATE_DELAYED")
stateFrame:SetScript("OnEvent", InvalidateEquippedState)

local BORING_BONUS_IDS = {
    [8960] = true,
    [12066] = true,
    [12214] = true,
    [8790] = true,
    [8791] = true,
    [8792] = true,
    [8793] = true,
    [8794] = true,
    [8795] = true,
}

local function ExtractBonusIdsFromLink(link, into, keepBoring)
    if not link then return end
    local payload = link:match("item:([^|]+)")
    if not payload then return end
    local fields = {}
    for field in (payload .. ":"):gmatch("([^:]*):") do
        fields[#fields + 1] = field
    end
    local numBonus = tonumber(fields[13]) or 0
    if numBonus <= 0 then return end
    for i = 1, numBonus do
        local id = tonumber(fields[13 + i])
        if id and id > 0 and (keepBoring or not BORING_BONUS_IDS[id]) then into[id] = true end
    end
end

local function GetEquippedBonusIds()
    if equippedBonusIds then return equippedBonusIds end
    local ids = {}
    for slot = 1, 18 do
        if slot ~= 4 then
            local link = GetInventoryItemLink("player", slot)
            ExtractBonusIdsFromLink(link, ids)
        end
    end
    equippedBonusIds = ids
    return ids
end

local function GetEquippedEffectSpellIds()
    if equippedSpellIds then return equippedSpellIds end
    local ids = {}
    for slot = 1, 18 do
        if slot ~= 4 then
            local link = GetInventoryItemLink("player", slot)
            if link then
                local _, spellId = GetItemSpell(link)
                if spellId then ids[spellId] = true end
            end
        end
    end
    equippedSpellIds = ids
    return ids
end

local function IsEmbellishmentApplied(entry)
    if not entry or not entry.itemId then return false end
    local emb = ClassCodexGameData and ClassCodexGameData.embellishments
    local effectEntry = emb and emb.effects and emb.effects[entry.itemId]
    if not effectEntry then return false end

    if effectEntry.bonusId and GetEquippedBonusIds()[effectEntry.bonusId] then return true end
    if effectEntry.spellIds then
        local equippedSpells = GetEquippedEffectSpellIds()
        for _, spellId in ipairs(effectEntry.spellIds) do
            if equippedSpells[spellId] then return true end
        end
    end
    return false
end

local function IsItemOwned(entry, isEmbellishment)
    local itemId = entry.itemId
    if not itemId or itemId == 0 then return false end
    local count = GetItemCount(itemId, true, false, true, true) or 0
    if count > 0 then return true end
    if IsEquippedItem and IsEquippedItem(itemId) then return true end
    if isEmbellishment and IsEmbellishmentApplied(entry) then return true end
    return false
end

local function CountEquippedEmbellishments()
    local emb = ClassCodexGameData and ClassCodexGameData.embellishments
    local byBonus = emb and emb.bonusIds
    if not byBonus then return 0, {} end
    local markerSet = {}
    if emb.markers then
        for _, bl in ipairs(emb.markers) do
            markerSet[bl] = true
        end
    end
    local count, items = 0, {}
    for slot = 1, 18 do
        if slot ~= 4 then
            local link = GetInventoryItemLink("player", slot)
            if link then
                local ids = {}
                ExtractBonusIdsFromLink(link, ids, true)
                local matchedItem, embellished
                for bl in pairs(ids) do
                    if byBonus[bl] then
                        matchedItem = byBonus[bl]
                        embellished = true
                        break
                    end
                end
                if not embellished then
                    for bl in pairs(ids) do
                        if markerSet[bl] then
                            embellished = true
                            break
                        end
                    end
                end
                if embellished then
                    count = count + 1
                    if matchedItem then items[#items + 1] = matchedItem end
                end
            end
        end
    end
    return count, items
end

function UpdateEmbBadge()
    if #embBadges == 0 then return end
    local haveData = ClassCodexGameData and ClassCodexGameData.embellishments
    local count = haveData and CountEquippedEmbellishments() or 0
    for _, badge in ipairs(embBadges) do
        if not haveData or (badge.ownClassOnly and not ns.compOwnClass) then
            badge:Hide()
        else
            badge.text:SetText(count .. "/" .. EMBELLISHMENT_LIMIT)
            if count >= EMBELLISHMENT_LIMIT then
                badge.text:SetTextColor(1, 0.82, 0)
            elseif count > 0 then
                badge.text:SetTextColor(0.4, 1, 0.5)
            else
                badge.text:SetTextColor(0.6, 0.6, 0.6)
            end
            badge:Show()
        end
    end
end

local function AttachEmbBadge(header)
    if not (header and header.AddHeaderWidget) then return nil end
    local badge = CreateFrame("Frame", nil, header)
    badge:SetSize(28, 16)
    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge.text:SetPoint("RIGHT", 0, 0)
    badge:SetScript("OnEnter", function(self)
        ns.Tooltip.Open(self, "ANCHOR_LEFT")
        ns.Tooltip.Title(L["crafting.section_embellishments"])
        local count, items = CountEquippedEmbellishments()
        ns.Tooltip.Intro(count .. " / " .. EMBELLISHMENT_LIMIT)
        for _, itemId in ipairs(items) do
            local name = C_Item.GetItemInfo(itemId)
            if name then ns.Tooltip.Body("  " .. name) end
        end
        ns.Tooltip.Show()
    end)
    badge:SetScript("OnLeave", function()
        ns.Tooltip.Hide()
    end)
    header:AddHeaderWidget(badge)
    embBadges[#embBadges + 1] = badge
    return badge
end

local function PaintCardIcon(icon, entry, isEmbellishment, ctx)
    icon:SetItem(entry.itemId)
    icon:ToggleMarker("source_icyveins", false)
    icon:ToggleMarker("owned", IsItemOwned(entry, isEmbellishment) and true or false)
    icon:Show()
end

local function MakeIcon(parent)
    return ns.CreateSlotIcon(parent, { size = ICON_SIZE, slotSize = SLOT_FRAME })
end

local ICYVEINS_INLINE_ICON = "|TInterface\\AddOns\\BreadClassCodex\\Media\\icyveins:12:12|t"

local function RecipeForItem(itemId)
    local recipes = ClassCodexGameData and ClassCodexGameData.recipes
    return itemId and recipes and recipes[itemId] or nil
end

local function OpenCraftMenu(card)
    local itemId = card.itemId
    if not itemId then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end

    local recipeId = card.recipeId or RecipeForItem(itemId)

    MenuUtil.CreateContextMenu(card, function(_, root)
        -- Row text carries quality color and [brackets]; menu titles are plain
        -- yellow, so strip the markup (same treatment the gear menu gives).
        local title = ns.CleanItemText
            and ns.CleanItemText(card.itemText and card.itemText.GetText and card.itemText:GetText())
        root:CreateTitle(title or L["tab.crafting"])
        if recipeId then
            root:CreateButton(L["crafting.menu.track_materials"], function()
                if C_TradeSkillUI and C_TradeSkillUI.SetRecipeTracked then
                    C_TradeSkillUI.SetRecipeTracked(recipeId, true, false)
                end
            end)
        else
            root:CreateTitle(L["crafting.menu.no_recipe"])
        end
        root:CreateButton((L and L["item.menu.link_chat"]) or "Link in chat", function()
            local link = (ns.BuildItemLink and ns.BuildItemLink(itemId, card.bonusIDs)) or GetItemLink(itemId)
            if link then
                if not ChatEdit_InsertLink(link) then ChatFrame_OpenChat(link) end
            end
        end)
        root:CreateButton((L and L["item.menu.copy_name"]) or "Copy name", function()
            local name = select(1, GetItemInfo(itemId)) or tostring(itemId)
            if ns.ShowCopyPopup then ns.ShowCopyPopup(name, card) end
        end)
    end)
end

local function MakeCard(parent)
    local card = CreateFrame("Button", nil, parent)
    card:SetHeight(CARD_HEIGHT)

    card:RegisterForClicks("LeftButtonUp", "RightButtonDown")
    card.icon = MakeIcon(card)

    card.icon:SetPoint("LEFT", card, "LEFT", CARD_INSET_X, 0)
    local name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(true)
    name:SetMaxLines(2)
    card.itemText = name
    card:SetScript("OnEnter", function(self)
        if not self.itemId then return end
        ns.Tooltip.MakeClickThrough()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        C_Item.RequestLoadItemDataByID(self.itemId)

        local rendered = false
        if self.bonusIDs and #self.bonusIDs > 0 and ns.BuildItemLink then
            rendered = pcall(GameTooltip.SetHyperlink, GameTooltip, ns.BuildItemLink(self.itemId, self.bonusIDs))
        end
        if not rendered then GameTooltip:SetItemByID(self.itemId) end
        if self.isEmbellishment then
            ns.Tooltip.Blank().Body(ICYVEINS_INLINE_ICON .. "  " .. L["crafting.tooltip.embellishment_icyveins"])
        end
        if self.popText then
            ns.Tooltip.Blank().Double(L["tooltip.popularity"] or "Popularity", self.popText, "muted", "title")
        end
        if self.embItemId then
            ns.Tooltip.Blank().Muted((L and L["gear.tooltip.embellishment"]) or "Embellishment:")
            local embName = self.embName or ("Item " .. self.embItemId)
            local _, _, embQuality = GetItemInfo(self.embItemId)
            ns.Tooltip.Intro("  " .. (ns.FormatItemLabel and ns.FormatItemLabel(embName, embQuality) or embName))
        end
        ns.Tooltip.Blank().Body(L["crafting.tooltip.menu_hint"])
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    card:SetScript("OnClick", function(self, button)
        if not self.itemId then return end
        if button == "RightButton" then
            OpenCraftMenu(self)
            return
        end

        -- GetItemInfo's link is always the base item; crafted/embellished picks
        -- carry bonus ids that must reach chat links and the dressing room.
        local link = (ns.BuildItemLink and ns.BuildItemLink(self.itemId, self.bonusIDs))
        if not link then link = C_Item.GetItemInfo(self.itemId) end
        if not link then
            C_Item.RequestLoadItemDataByID(self.itemId)
            link = format("item:%d", self.itemId)
        end
        if IsModifiedClick("CHATLINK") then
            ChatEdit_InsertLink(link)
        elseif IsModifiedClick("DRESSUP") then
            DressUpItemLink(link)
        end
    end)
    card:Hide()
    return card
end

local function AttachHelpIcon(titleFrame, insetOverride)
    return ns.CreateHelpIcon(titleFrame, {
        title = L["tab.crafting"],
        intro = L["crafting.help.intro"],
        highlight = L["crafting.help.menu"],

        warning = L["crafting.help.embellishment_limit"],
        lines = {
            ICYVEINS_INLINE_ICON .. "  " .. L["crafting.help.embellishment_icyveins"],
        },
        inset = insetOverride,
    })
end

function Crafting.AttachInfoButton(parent)
    return AttachHelpIcon(parent, 18)
end

local function ApplyCard(card, entry, isEmbellishment, ctx)
    card.itemId = entry.itemId
    card.embItemId = nil
    card.embName = nil
    card.bonusIDs = entry.bonusIDs
    card.recipeId = entry.recipeId or RecipeForItem(entry.itemId)
    card.altItemId = nil
    card.popText = entry.pop and string.format("%.1f%%", entry.pop) or nil
    card.isEmbellishment = isEmbellishment == true
    PaintCardIcon(card.icon, entry, isEmbellishment, ctx)

    local label = ns.FormatItem({ itemId = entry.itemId }, entry.name)
    if not label or label == "" then label = entry.name or ("Item " .. (entry.itemId or 0)) end
    card.itemText:SetText(label)
    card.itemText:ClearAllPoints()

    card.itemText:SetPoint("LEFT", card.icon.slot, "RIGHT", TEXT_GAP_X, 0)
    card.itemText:SetPoint("RIGHT", card, "RIGHT", -4, 0)
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
            .Hint(L["hint.switch_view"])
            .Show()
    end)
    cog:SetScript("OnLeave", function()
        icon:SetVertexColor(0.6, 0.6, 0.6)
        ns.Tooltip.Hide()
    end)
    cog:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            -- Same structure as the gear cogwheel: titled sections, options
            -- before the view switcher. Popularity filtering is u.gg data —
            -- the section hides on other sources.
            local source = (ns.ActiveSource and ns.ActiveSource()) or "icyveins"
            if source == "ugg" then
                root:CreateTitle((L and L["crafting.menu.popularity_title"]) or "Popularity")
                root:CreateCheckbox((L and L["crafting.menu.sort_popular"]) or "Show most popular only", function()
                    return Crafting.GetSortPopular(section)
                end, function()
                    Crafting.SetSortPopular(section, not Crafting.GetSortPopular(section))
                    return MenuResponse.Refresh
                end)
                root:CreateDivider()
            end
            root:CreateTitle(L["settings.value.view"] or "View")
            root:CreateRadio(L["settings.value.table"] or "Table", function()
                return Crafting.GetViewMode(section, ctx) == "table"
            end, function()
                Crafting.SetViewMode(section, "table", ctx)
                return MenuResponse.Refresh
            end)
            root:CreateRadio(L["settings.value.list"] or "List", function()
                return Crafting.GetViewMode(section, ctx) == "list"
            end, function()
                Crafting.SetViewMode(section, "list", ctx)
                return MenuResponse.Refresh
            end)
            root:CreateRadio(L["settings.value.icons"] or "Icons", function()
                return Crafting.GetViewMode(section, ctx) == "icons"
            end, function()
                Crafting.SetViewMode(section, "icons", ctx)
                return MenuResponse.Refresh
            end)
        end)
    end)
    header:AddHeaderWidget(cog)
    return cog
end

-- The craft menu shouldn't be list-view only — icons and table rows get the
-- same right-click (track materials) as the cards. The right-click replaces the
-- generic item menu (SetupItemTooltip) rather than stacking on it; left clicks
-- (and modified clicks) still fall through to the original handler.
local function BindCraftMenu(row)
    -- Menus open on mouse-down (a tooltip under the cursor can swallow the
    -- mouse-up); everything else falls through to the original handlers.
    local prevUp = row:GetScript("OnMouseUp")
    local prevDown = row:GetScript("OnMouseDown")
    row:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            OpenCraftMenu(self)
        elseif prevDown then
            prevDown(self, button)
        end
    end)
    row:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" and prevUp then prevUp(self, button) end
    end)
end

local function makeGridIcon(content)
    local ic = ns.CreateSlotIcon(content, { size = ICON_SIZE, slotSize = SLOT_FRAME })
    ns.SetupItemTooltip(ic)
    BindCraftMenu(ic)
    ic:Hide()
    return ic
end

local function makeTableRow(content)
    local row = ns.MakeTableRow(content)
    BindCraftMenu(row)
    return row
end

local function buildPool(content, max, factory)
    local pool = {}
    for i = 1, max do
        pool[i] = factory(content)
    end
    return pool
end

local function hidePool(pool)
    if not pool then return end
    for i = 1, #pool do
        pool[i]:Hide()
    end
end

local function buildCraftItems(entries, isEmbellishment, gateOwned)
    local items = {}
    for _, e in ipairs(entries) do
        local owned = IsItemOwned(e, isEmbellishment)
        if gateOwned then owned = owned and ns.compOwnClass end
        items[#items + 1] = {
            itemId = e.itemId,
            bonusIDs = e.bonusIDs,
            pop = e.pop,
            popText = e.pop and string.format("%.1f%%", e.pop) or nil,
            isOwned = owned and true or false,
        }
    end
    return items
end

local function layoutGrid(content, icons, items)
    hidePool(icons)
    local count = math.min(#items, #icons)
    if count == 0 then return 0 end

    local width = content:GetWidth()
    if not width or width < 100 then width = 300 end
    local maxPerRow = math.max(1, math.floor((width - GRID_INSET * 2) / ICON_STRIDE))
    local numRows = math.ceil(count / maxPerRow)
    local perRow = math.ceil(count / numRows)

    local y = -GRID_TOP_PAD
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
        ic.popText = item.pop and string.format("%.1f%%", item.pop) or nil
        ic.altItemId = nil
        ic.embItemId = nil
        ic:ToggleMarker("owned", item.isOwned)
        ic:Show()
    end

    return numRows * ROW_STRIDE + GRID_TOP_PAD
end

local function layoutCards(content, cards, entries, isEmbellishment, ctx, gateOwned)
    hidePool(cards)
    local count = math.min(#entries, #cards)
    for i = 1, count do
        local card = cards[i]
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", content, "TOPLEFT", CARD_INSET_X, -(i - 1) * CARD_HEIGHT)
        card:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        ApplyCard(card, entries[i], isEmbellishment, ctx)
        if gateOwned and not ns.compOwnClass and card.icon then card.icon:ToggleMarker("owned", false) end
        card:Show()
    end
    return count * CARD_HEIGHT
end

local function renderSubsection(inst, section, entries, isEmbellishment, ctx, viewCtx, gateOwned)
    local content = inst[section .. "Content"]
    local cards = inst[section .. "Cards"]
    local icons = inst[section .. "Icons"]
    local tableRows = inst[section .. "TableRows"]
    local mode = Crafting.GetViewMode(section, viewCtx)
    if mode == "icons" then
        hidePool(cards)
        hidePool(tableRows)
        return layoutGrid(content, icons, buildCraftItems(entries, isEmbellishment, gateOwned))
    elseif mode == "list" then
        hidePool(icons)
        hidePool(tableRows)
        return layoutCards(content, cards, entries, isEmbellishment, ctx, gateOwned)
    else
        hidePool(cards)
        hidePool(icons)
        return ns.LayoutTable(content, tableRows, buildCraftItems(entries, isEmbellishment, gateOwned))
    end
end

local function LookupData(class, spec, ctxKey)
    local source = ns.ActiveSource and ns.ActiveSource() or "icyveins"
    local sd = ns.SourceSpec and ns.SourceSpec(source, class, spec)
    if not sd or not sd.crafting then return nil end

    local dataCtx
    if ctxKey == "raid" then
        dataCtx = "raid"
    elseif ctxKey == "mythicPlus" then
        dataCtx = "mplus"
    elseif ctxKey == "pvp" then
        local byHero = sd.crafting["all"]
        if byHero then
            if byHero["pvp"] then
                dataCtx = "pvp"
            elseif byHero["pvp:3v3"] then
                dataCtx = "pvp:3v3"
            else
                for k in pairs(byHero) do
                    if type(k) == "string" and k:sub(1, 4) == "pvp:" and (not dataCtx or k < dataCtx) then
                        dataCtx = k
                    end
                end
            end
        end
        if not dataCtx then return nil end
    end
    local c = ns.ResolveCategory(sd.crafting, "all", dataCtx or "all")
    if not c then return nil end

    -- Entries are item ids or detail tables {itemId, pop, bonusIDs} (u.gg's
    -- crafting data carries pick-rates and the bonus ids that reconstruct
    -- embellished items).
    local function entry(e)
        if type(e) == "table" then return e.itemId, e.pop, e.bonusIDs end
        return e
    end
    local crafts, embellishments = {}, {}
    if c.crafts then
        for _, ce in ipairs(c.crafts) do
            local id, pop, bonusIDs = entry(ce)
            crafts[#crafts + 1] = { itemId = id, pop = pop, bonusIDs = bonusIDs }
        end
    end
    if c.embellishments then
        for _, ce in ipairs(c.embellishments) do
            local id, pop = entry(ce)
            embellishments[#embellishments + 1] = { itemId = id, pop = pop }
        end
    end
    if #embellishments == 0 and not (dataCtx and dataCtx:sub(1, 3) == "pvp") then
        for _, fctx in ipairs({ "mplus", "raid", "all" }) do
            if fctx ~= dataCtx then
                local fc = ns.ResolveCategory(sd.crafting, "all", fctx)
                if fc and fc.embellishments and #fc.embellishments > 0 then
                    for _, ce in ipairs(fc.embellishments) do
                        local id, pop = entry(ce)
                        embellishments[#embellishments + 1] = { itemId = id, pop = pop }
                    end
                    break
                end
            end
        end
    end
    if #crafts == 0 and #embellishments == 0 then return nil end
    if source == "ugg" and (Crafting.GetSortPopular("crafts") or Crafting.GetSortPopular("embs")) then
        -- "Show most popular only" (per sub-section): entries above 50% pick
        -- rate; when fewer than two clear the bar, the top two by popularity
        -- stay so the list is never uselessly empty.
        local function keepPopular(list)
            local ranked = {}
            for i, e in ipairs(list) do
                ranked[#ranked + 1] = { e = e, pop = e.pop or 0, i = i }
            end
            table.sort(ranked, function(a, b)
                if a.pop ~= b.pop then return a.pop > b.pop end
                return a.i < b.i
            end)
            local cutoff = #ranked
            while cutoff > 0 and (ranked[cutoff].pop or 0) <= 50 do
                cutoff = cutoff - 1
            end
            if cutoff < 2 then cutoff = math.min(2, #ranked) end
            local kept = {}
            for i = 1, cutoff do
                kept[#kept + 1] = ranked[i].e
            end
            for i, e in ipairs(kept) do
                list[i] = e
            end
            for i = #list, #kept + 1, -1 do
                table.remove(list, i)
            end
        end
        if Crafting.GetSortPopular("crafts") then keepPopular(crafts) end
        if Crafting.GetSortPopular("embs") then keepPopular(embellishments) end
    end
    return { crafts = crafts, embellishments = embellishments }
end

local function CtxHasData(class, spec, ctxKey)
    local d = LookupData(class, spec, ctxKey)
    return d ~= nil and ((d.crafts and #d.crafts > 0) or (d.embellishments and #d.embellishments > 0))
end

local function ResolveActiveCtx(class, spec)
    local ctx = GetPerSpecCtx()
    if CtxHasData(class, spec, ctx) then return ctx end
    for _, c in ipairs(CONTEXTS) do
        if CtxHasData(class, spec, c.key) then return c.key end
    end
    return ctx
end

function Crafting.RequestItems(class, spec, requestItem)
    if not class or not spec or not requestItem then return end
    for _, ctxName in ipairs({ "raid", "mythicPlus", "pvp" }) do
        local section = LookupData(class, spec, ctxName)
        if section then
            if section.crafts then
                for _, c in ipairs(section.crafts) do
                    requestItem(c.itemId)
                end
            end
            if section.embellishments then
                for _, e in ipairs(section.embellishments) do
                    if e.itemId then requestItem(e.itemId) end
                end
            end
        end
    end
end

function Crafting.InitPanel(opts)
    opts = opts or {}
    local parent = opts.parent or ns.contentFrame
    local refresh = opts.refresh

    panel.ctxDropdown = ns.CreateOptionDropdown("ClassCodexPanelCraftingCtxDD", parent)
    panel.ctxDropdown:Hide()

    panel.craftsSection, panel.craftsHeader, panel.craftsContent = ns.CreateCollapsibleSection(parent, {
        label = L["crafting.section_crafts"],
        stateKey = "crafting.crafts",
        refresh = refresh,
    })
    panel.craftsSection:Hide()

    panel.embsSection, panel.embsHeader, panel.embsContent = ns.CreateCollapsibleSection(parent, {
        label = L["crafting.section_embellishments"],
        stateKey = "crafting.embellishments",
        refresh = refresh,
    })
    panel.embsSection:Hide()

    panel.craftsCards = buildPool(panel.craftsContent, MAX_CRAFT_CARDS, MakeCard)
    panel.craftsIcons = buildPool(panel.craftsContent, MAX_CRAFT_CARDS, makeGridIcon)
    panel.craftsTableRows = buildPool(panel.craftsContent, MAX_CRAFT_CARDS, makeTableRow)
    panel.embsCards = buildPool(panel.embsContent, MAX_EMB_CARDS, MakeCard)
    panel.embsIcons = buildPool(panel.embsContent, MAX_EMB_CARDS, makeGridIcon)
    panel.embsTableRows = buildPool(panel.embsContent, MAX_EMB_CARDS, makeTableRow)

    panel.craftsViewCog = makeViewCog(panel.craftsHeader, "crafts", nil)
    panel.embsViewCog = makeViewCog(panel.embsHeader, "embs", nil)
    panel.embSlotsBadge = AttachEmbBadge(panel.embsHeader)

    return {
        ctxDropdown = panel.ctxDropdown,
        craftsSection = panel.craftsSection,
        embsSection = panel.embsSection,
    }
end

function Crafting.RenderPanel(args)
    hidePool(panel.craftsCards)
    hidePool(panel.craftsIcons)
    hidePool(panel.craftsTableRows)
    hidePool(panel.embsCards)
    hidePool(panel.embsIcons)
    hidePool(panel.embsTableRows)

    local generic = ns.Context and ns.Context.contentType()
    local activeCtx = (generic and CONTEXT_FROM_GENERIC[generic]) or GetPerSpecCtx()
    if not CtxHasData(args.class, args.spec, activeCtx) then
        for _, c in ipairs(CONTEXTS) do
            if CtxHasData(args.class, args.spec, c.key) then
                activeCtx = c.key
                break
            end
        end
    end
    local ctxData = LookupData(args.class, args.spec, activeCtx)
    local crafts = (ctxData and ctxData.crafts) or {}
    local embellishments = (ctxData and ctxData.embellishments) or {}

    if #crafts == 0 and #embellishments == 0 then
        panel.ctxDropdown:Hide()
        panel.craftsSection:Hide()
        panel.embsSection:Hide()
        return { crafts = 0, embs = 0 }
    end

    panel.ctxDropdown:Hide()

    if #crafts > 0 then
        panel.craftsSection:Show()
        local h = renderSubsection(panel, "crafts", crafts, false, activeCtx, nil, false)
        ns.SetContentHeight(panel.craftsContent, h)
    else
        panel.craftsSection:Hide()
    end

    if #embellishments > 0 then
        panel.embsSection:Show()
        local h = renderSubsection(panel, "embs", embellishments, true, activeCtx, nil, false)
        ns.SetContentHeight(panel.embsContent, h)
        UpdateEmbBadge()
    else
        panel.embsSection:Hide()
    end

    return { crafts = #crafts, embs = #embellishments }
end

function Crafting.GetPanelFrames()
    return {
        ctxDropdown = panel.ctxDropdown,
        craftsSection = panel.craftsSection,
        craftsHeader = panel.craftsHeader,
        craftsContent = panel.craftsContent,
        craftsCollapsed = panel.craftsSection.IsCollapsed and panel.craftsSection.IsCollapsed() or false,
        embsSection = panel.embsSection,
        embsContent = panel.embsContent,
        embsCollapsed = panel.embsSection.IsCollapsed and panel.embsSection.IsCollapsed() or false,
    }
end

function Crafting.GetPanelCardHeight()
    return CARD_HEIGHT
end

local comp = {}

local function CompSection(parent, headerFactory, label)
    local section = CreateFrame("Frame", nil, parent)
    local header = headerFactory(section, label, false)
    local content = CreateFrame("Frame", nil, section)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    content:SetPoint("RIGHT", 0, 0)
    section._collapsed = false
    section.header = header
    section.content = content
    return section, header, content
end

function Crafting.InitCompendium(opts)
    comp.craftsSection, comp.craftsHeader, comp.craftsContent =
        CompSection(opts.parent, opts.headerFactory, L["crafting.section_crafts"])

    comp.embsSection, comp.embsHeader, comp.embsContent =
        CompSection(opts.parent, opts.headerFactory, L["crafting.section_embellishments"])

    comp.craftsCards = buildPool(comp.craftsContent, MAX_CRAFT_CARDS, MakeCard)
    comp.craftsIcons = buildPool(comp.craftsContent, MAX_CRAFT_CARDS, makeGridIcon)
    comp.craftsTableRows = buildPool(comp.craftsContent, MAX_CRAFT_CARDS, makeTableRow)
    comp.embsCards = buildPool(comp.embsContent, MAX_EMB_CARDS, MakeCard)
    comp.embsIcons = buildPool(comp.embsContent, MAX_EMB_CARDS, makeGridIcon)
    comp.embsTableRows = buildPool(comp.embsContent, MAX_EMB_CARDS, makeTableRow)

    comp.craftsViewCog = makeViewCog(comp.craftsHeader, "crafts", "comp")
    comp.embsViewCog = makeViewCog(comp.embsHeader, "embs", "comp")
    comp.embSlotsBadge = AttachEmbBadge(comp.embsHeader)
    if comp.embSlotsBadge then comp.embSlotsBadge.ownClassOnly = true end

    comp.craftsSection:Hide()
    comp.embsSection:Hide()

    return comp.craftsSection, comp.embsSection
end

function Crafting.RenderCompendium(args)
    hidePool(comp.craftsCards)
    hidePool(comp.craftsIcons)
    hidePool(comp.craftsTableRows)
    hidePool(comp.embsCards)
    hidePool(comp.embsIcons)
    hidePool(comp.embsTableRows)

    local ctxKey = ResolveActiveCtx(args.class, args.spec)
    local ctxData = LookupData(args.class, args.spec, ctxKey)
    local crafts = (ctxData and ctxData.crafts) or {}
    local embellishments = (ctxData and ctxData.embellishments) or {}

    if #crafts > 0 then
        comp.craftsHeight = renderSubsection(comp, "crafts", crafts, false, ctxKey, "comp", true)
        ns.SetContentHeight(comp.craftsContent, comp.craftsHeight)
        comp.craftsSection:Show()
    else
        comp.craftsHeight = 0
        comp.craftsSection:Hide()
    end

    if #embellishments > 0 then
        comp.embsHeight = renderSubsection(comp, "embs", embellishments, true, ctxKey, "comp", true)
        ns.SetContentHeight(comp.embsContent, comp.embsHeight)
        comp.embsSection:Show()
    else
        comp.embsHeight = 0
        comp.embsSection:Hide()
    end

    UpdateEmbBadge()
end

function Crafting.GetCompendiumCraftsHeight()
    return comp.craftsHeight or 0
end

function Crafting.GetCompendiumEmbsHeight()
    return comp.embsHeight or 0
end
