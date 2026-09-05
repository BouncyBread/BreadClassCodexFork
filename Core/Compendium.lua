local _, ns = ...

local DATA = IcyVeinsData
if not DATA then
    function ns:OpenCompendium()
        print("|cff00ccffBread Codex:|r " .. ns.L["chat.compendium_data_not_loaded"])
    end
    return
end

local L = ns.L

local FRAME_WIDTH = 540
local FRAME_HEIGHT = 480
local INSET_PAD = -2
local ROW_HEIGHT = 22
local SECTION_HEADER_HEIGHT = ns.SECTION_HEADER_HEIGHT or 24
local SECTION_CONTENT_PAD = 4

local CONSUMABLE_ORDER = { "flask", "combatPotion", "food", "weaponBuff", "augmentRune" }

local SPEC_KEYS = {
    DEATHKNIGHT = { "blood", "frost", "unholy" },
    DEMONHUNTER = { "havoc", "vengeance", "devourer" },
    DRUID = { "balance", "feral", "guardian", "restoration" },
    EVOKER = { "devastation", "preservation", "augmentation" },
    HUNTER = { "beast-mastery", "marksmanship", "survival" },
    MAGE = { "arcane", "fire", "frost" },
    MONK = { "brewmaster", "mistweaver", "windwalker" },
    PALADIN = { "holy", "protection", "retribution" },
    PRIEST = { "discipline", "holy", "shadow" },
    ROGUE = { "assassination", "outlaw", "subtlety" },
    SHAMAN = { "elemental", "enhancement", "restoration" },
    WARLOCK = { "affliction", "demonology", "destruction" },
    WARRIOR = { "arms", "fury", "protection" },
}

local CLASS_ORDER = {
    "DEATHKNIGHT",
    "DEMONHUNTER",
    "DRUID",
    "EVOKER",
    "HUNTER",
    "MAGE",
    "MONK",
    "PALADIN",
    "PRIEST",
    "ROGUE",
    "SHAMAN",
    "WARLOCK",
    "WARRIOR",
}

local CLASS_ID_MAP = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    MONK = 10,
    DRUID = 11,
    DEMONHUNTER = 12,
    EVOKER = 13,
}

local GROUP_ORDER = { "stats", "talents", "rotation", "gear", "trinkets", "enhancements", "crafting", "about" }
local GROUP_TAB_ICON = {
    stats = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-stats",
    talents = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-talents",
    rotation = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-rotation",
    gear = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-gear",
    trinkets = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-trinkets",
    enhancements = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-enhancements",
    crafting = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-crafting",
    about = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-about",
}
local GROUP_LABEL = {
    stats = "section.stats",
    talents = "section.talents",
    rotation = "section.rotation",
    gear = "tab.gear",
    trinkets = "tab.trinkets",
    enhancements = "tab.enhancements",
    crafting = "tab.crafting",
    about = "tab.about",
}
local GROUP_SURFACE = {
    stats = "stats",
    talents = "talents",
    rotation = "rotation",
    gear = "bis",
    trinkets = "trinkets",
    enhancements = "enhancements",
    crafting = "crafting",
    about = "about",
}
local TAB_MIGRATE = { guide = "stats", bis = "gear", settings = "about" }

local function ClassIconMarkup(classToken)
    local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    if not c then return "" end
    return string.format(
        "|TInterface\\TargetingFrame\\UI-Classes-Circles:16:16:0:0:256:256:%d:%d:%d:%d|t ",
        c[1] * 256,
        c[2] * 256,
        c[3] * 256,
        c[4] * 256
    )
end

local selectedClass = nil
local selectedSpec = nil
local selectedHero = nil
local compSource = nil
local compContent = nil
local activeTab = "stats"

local currentRotContext = nil
local initialized = false
local SaveCompendiumState

local UI = {}

local function CompContentWidth()
    local w = UI.scrollChild and UI.scrollChild:GetWidth() or 0
    if not w or w < 100 then w = FRAME_WIDTH - 40 end
    return w
end

local function GetClassDisplayName(classToken)
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo(CLASS_ID_MAP[classToken])
    return info and info.className or classToken:sub(1, 1) .. classToken:sub(2):lower()
end

local function GetSpecDisplayName(classToken, specKey)
    local classID = CLASS_ID_MAP[classToken]
    if not classID or not GetSpecializationInfoForClassID then return specKey end
    local keys = SPEC_KEYS[classToken]
    if keys then
        for i, key in ipairs(keys) do
            if key == specKey then
                local _, name = GetSpecializationInfoForClassID(classID, i)
                if name then return name end
                break
            end
        end
    end
    return specKey:gsub("^%l", string.upper):gsub("%-(%l)", function(c)
        return " " .. c:upper()
    end)
end

local function GetSpecIconTexture(classToken, specKey)
    local classID = CLASS_ID_MAP[classToken]
    if not classID or not GetSpecializationInfoForClassID then return nil end
    local keys = SPEC_KEYS[classToken]
    if keys then
        for i, key in ipairs(keys) do
            if key == specKey then
                local _, _, _, icon = GetSpecializationInfoForClassID(classID, i)
                return icon
            end
        end
    end
    return nil
end

local function SpecIconMarkup(classToken, specKey)
    local tex = GetSpecIconTexture(classToken, specKey)
    if not tex then return "" end
    return "|T" .. tex .. ":16:16:0:0:64:64:5:59:5:59|t "
end

local GetHeroTalentOptions = ns.GetHeroTalentOptions

local FindRotationByContext = ns.FindRotationByContext

local GetRotationContextOptions = ns.GetRotationContextOptions

local FormatRotationStep = ns.FormatRotationStep

local StripConditionPrefix = ns.StripConditionPrefix

local GetStepSpellIcon = ns.GetStepSpellIcon

local CreateSectionHeader = ns.CreateSectionHeader
local function MakeStaticHeader(header)
    if not header then return end
    if header.arrow then header.arrow:Hide() end
    header:EnableMouse(false)
    header:SetScript("OnClick", nil)
    header:SetScript("OnEnter", nil)
    header:SetScript("OnLeave", nil)
    if header.label then header.label:SetTextColor(1, 0.82, 0) end
end

local compendiumDirty = false
local RequestItemData = ns.RequestItemData

local function RequestAllGearItems(gearData)
    if not gearData then return end
    if gearData.enchants then
        for _, e in ipairs(gearData.enchants) do
            if e.best and e.best.itemId then RequestItemData(e.best.itemId) end
            if e.alternate and e.alternate.itemId then RequestItemData(e.alternate.itemId) end
        end
    end
    if gearData.gems then
        if gearData.gems.primary then RequestItemData(gearData.gems.primary.itemId) end
        if gearData.gems.secondary then
            for _, g in ipairs(gearData.gems.secondary) do
                RequestItemData(g.itemId)
            end
        end
    end
    if gearData.consumables then
        for _, key in ipairs(CONSUMABLE_ORDER) do
            if gearData.consumables[key] then RequestItemData(gearData.consumables[key].itemId) end
        end
    end
    if gearData.trinkets then
        for _, t in ipairs(gearData.trinkets) do
            RequestItemData(t.itemId)
        end
    end
    ns.Sections.Crafting.RequestItems(selectedClass, selectedSpec, RequestItemData)
    if gearData.bisGear then
        for _, tab in ipairs(gearData.bisGear) do
            for _, g in ipairs(tab.slots) do
                RequestItemData(g.item.itemId)
            end
        end
    end

    if selectedClass and selectedSpec and ns.GetBisGearData then
        local bisData = ns.GetBisGearData(compSource, selectedClass, selectedSpec)
        if bisData and bisData.bisGear then
            for _, tab in ipairs(bisData.bisGear) do
                for _, g in ipairs(tab.slots) do
                    RequestItemData(g.item.itemId)
                end
            end
        end
    end
end

ns.OnItemLoaded(function()
    if compendiumDirty or not (UI.frame and UI.frame:IsShown()) then return end
    compendiumDirty = true
    C_Timer.After(0.1, function()
        compendiumDirty = false
        if UI.frame and UI.frame:IsShown() then ns:UpdateCompendium() end
    end)
end)

local function GetItemDisplayName(itemRef)
    if not itemRef then return "" end
    if itemRef.spellId then
        if C_Spell and C_Spell.GetSpellName then
            local name = C_Spell.GetSpellName(itemRef.spellId)
            if name then return name end
        end
    end
    if itemRef.itemId then
        local cached = ns.GetCachedItem(itemRef.itemId)
        if cached and cached.name then return cached.name end
        local name = GetItemInfo(itemRef.itemId)
        if name then return name end
    end
    return itemRef.name or ("Item " .. (itemRef.itemId or "?"))
end

local ICON_SIZE = 16

local RefreshContextBanner

local function InitFrame()
    if initialized then return end
    initialized = true

    UI.frame = CreateFrame("Frame", "ClassCodexCompendium", UIParent, "ButtonFrameTemplate")
    UI.frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)

    UI.frame:SetFrameStrata("HIGH")

    if ClassCodexDB and ClassCodexDB.compendiumX and ClassCodexDB.compendiumY then
        UI.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ClassCodexDB.compendiumX, ClassCodexDB.compendiumY)
    else
        UI.frame:SetPoint("CENTER")
    end
    UI.frame:SetTitle("Bread Codex Compendium")
    UI.frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_09")
    ButtonFrameTemplate_HideButtonBar(UI.frame)

    do
        local titleFS = UI.frame.TitleContainer and UI.frame.TitleContainer.TitleText
        if titleFS then
            titleFS:ClearAllPoints()
            titleFS:SetPoint("LEFT", UI.frame, "TOPLEFT", 66, -13)
            titleFS:SetJustifyH("LEFT")
        end
    end

    local function pinCornerToBottomEdge(corner)
        if not corner then return end
        local point, relTo, relPoint, x = corner:GetPoint(1)
        if not point then return end
        corner:ClearAllPoints()
        corner:SetPoint(point, relTo, relPoint, x, -4)
    end
    if UI.frame.NineSlice then
        pinCornerToBottomEdge(UI.frame.NineSlice.BottomLeftCorner)
        pinCornerToBottomEdge(UI.frame.NineSlice.BottomRightCorner)
    end
    UI.frame:EnableMouse(true)
    UI.frame:SetMovable(true)
    UI.frame:SetClampedToScreen(true)
    UI.frame:Hide()
    UI.frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)
    tinsert(UISpecialFrames, "ClassCodexCompendium")

    UI.frame.TitleContainer:EnableMouse(true)
    UI.frame.TitleContainer:RegisterForDrag("LeftButton")
    UI.frame.TitleContainer:SetScript("OnDragStart", function()
        UI.frame:StartMoving()
    end)
    UI.frame.TitleContainer:SetScript("OnDragStop", function()
        UI.frame:StopMovingOrSizing()
        if ClassCodexDB then
            ClassCodexDB.compendiumX = UI.frame:GetLeft()
            ClassCodexDB.compendiumY = UI.frame:GetTop()
        end
    end)

    UI.subheaderFrame = CreateFrame("Frame", nil, UI.frame)
    UI.subheaderFrame:SetHeight(30)
    UI.subheaderFrame:SetPoint("TOPLEFT", UI.frame, "TOPLEFT", 62, -26)
    UI.subheaderFrame:SetPoint("TOPRIGHT", UI.frame, "TOPRIGHT", -8, -26)
    UI.subheaderFrame:SetFrameLevel(UI.frame:GetFrameLevel() + 10)

    local paneTabs = {}
    local paneBottomTabs = {}
    for _, key in ipairs(GROUP_ORDER) do
        local entry = { key = key, icon = GROUP_TAB_ICON[key], tooltip = L[GROUP_LABEL[key]] }
        if key == "about" then
            paneBottomTabs[#paneBottomTabs + 1] = entry
        else
            paneTabs[#paneTabs + 1] = entry
        end
    end
    UI.pane = ns.CreateAnchorPane({
        parent = UI.frame,
        insetFrame = UI.frame.Inset,
        scrollTopAnchor = UI.subheaderFrame,
        scrollInsets = { top = 8, left = 4, right = 4, bottom = 4 },
        scrollName = "ClassCodexCompendiumScroll",
        hideScrollBar = true,
        tabsTopY = -40,
        tabs = paneTabs,
        bottomTabs = paneBottomTabs,
        onTabChange = function(key)
            activeTab = key
            SaveCompendiumState()
        end,
        onSync = function(key)
            activeTab = key
            SaveCompendiumState()
        end,
        onLayout = function(content, viewportH)
            return ns:BuildCompendiumLayout(content, viewportH)
        end,
    })
    UI.scrollChild = UI.pane.contentFrame
    UI.scrollBox = UI.pane.scroll

    UI.groupTitles = {}
    if ns.CreatePageTitle then
        for _, key in ipairs(GROUP_ORDER) do
            local pt = ns.CreatePageTitle(UI.scrollChild)
            if ns.CreateSourceLinkIcon then
                pt.link = ns.CreateSourceLinkIcon(pt)
                pt.link:SetPoint("RIGHT", pt, "RIGHT", -(ns.PAGE_TITLE_HPAD or 8), 1)
            end
            pt:Hide()
            UI.groupTitles[key] = pt
        end
    end

    UI.sourceButton = ns.CreateSourceButton and ns.CreateSourceButton("ClassCodexCompSourceBtn", UI.subheaderFrame)
    if UI.sourceButton then
        UI.sourceButton:SetPoint("TOPLEFT", UI.subheaderFrame, "TOPLEFT", 0, 0)
        UI.sourceButton:SetPoint("TOPRIGHT", UI.subheaderFrame, "TOPRIGHT", 0, 0)
        UI.sourceButton:Hide()
    end

    local function MakeItemRow(parent)
        local row = CreateFrame("Button", nil, parent)
        row:SetHeight(ROW_HEIGHT)

        local ownedBg = row:CreateTexture(nil, "BACKGROUND")
        ownedBg:SetAllPoints(row)
        ownedBg:SetColorTexture(0.2, 0.9, 0.2, 0.10)
        ownedBg:Hide()
        row.ownedBg = ownedBg
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnEnter", function(self)
            if self.itemId then
                ns.Tooltip.MakeClickThrough()
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.bonusIDs and #self.bonusIDs > 0 and ns.BuildItemLink then
                    local ok =
                        pcall(GameTooltip.SetHyperlink, GameTooltip, ns.BuildItemLink(self.itemId, self.bonusIDs))
                    if not ok then GameTooltip:SetItemByID(self.itemId) end
                else
                    GameTooltip:SetItemByID(self.itemId)
                end

                if self.embItemId then
                    ns.Tooltip.Blank().Muted((L and L["gear.tooltip.embellishment"]) or "Embellishment:")
                    local embName = self.embName
                    if not embName or embName == "" then
                        embName = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(self.embItemId))
                            or GetItemInfo(self.embItemId)
                            or ("Item " .. self.embItemId)
                    end
                    local _, _, embQuality = GetItemInfo(self.embItemId)
                    ns.Tooltip.Intro(
                        "  " .. (ns.FormatItemLabel and ns.FormatItemLabel(embName, embQuality) or embName)
                    )
                end
                if self.sourceText then
                    ns.Tooltip.Blank().Double(SOURCE or "Source", self.sourceText, "muted", "title")
                end
                GameTooltip:Show()
            elseif self.spellId then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellId)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(self)
            if not self.itemId then return end
            local link = (ns.BuildItemLink and ns.BuildItemLink(self.itemId, self.bonusIDs))
                or C_Item.GetItemInfo(self.itemId)
            if not link then return end
            if IsModifiedClick("CHATLINK") then
                ChatEdit_InsertLink(link)
            elseif IsModifiedClick("DRESSUP") then
                DressUpItemLink(link)
            end
        end)
        return row
    end

    UI.statSection, UI.statHeader, UI.statContent = ns.Sections.Stats.InitCompendium({
        parent = UI.scrollChild,
        headerFactory = CreateSectionHeader,
        refresh = function()
            ns:UpdateCompendium()
        end,
    })

    UI.talentSection, UI.talentHeader, UI.talentContent = ns.Sections.Talents.InitCompendium({
        parent = UI.scrollChild,
        headerFactory = CreateSectionHeader,
        source = function()
            return compSource
        end,
        contentType = function()
            return compContent
        end,
        refresh = function()
            ns:UpdateCompendiumAllTalents(nil, selectedClass, selectedSpec)
            if UI.omniumSection then
                local specData = DATA[selectedClass] and DATA[selectedClass][selectedSpec]
                ns:UpdateCompendiumOmnium(specData)
            end
            ns:LayoutCompendium()
        end,
    })

    UI.rotationSection, UI.rotationHeader, UI.rotationContent = ns.Sections.Rotation.InitCompendium({
        parent = UI.scrollChild,
        headerFactory = CreateSectionHeader,
        cogTitle = UI.groupTitles and UI.groupTitles.rotation,
        refresh = function()
            ns:LayoutCompendium()
        end,
    })
    UI.rotationCollapsed = false

    local _enhFrames = ns.Sections.Enhancements.InitCompendium({
        parent = UI.scrollChild,
        headerFactory = CreateSectionHeader,
        rowFactory = MakeItemRow,
        refresh = function()
            ns:LayoutCompendium()
        end,
        iconSize = ICON_SIZE,
    })
    UI.enchantSection, UI.enchantHeader, UI.enchantContent =
        _enhFrames.enchSection, _enhFrames.enchHeader, _enhFrames.enchContent
    UI.gemSection, UI.gemHeader, UI.gemContent = _enhFrames.gemSection, _enhFrames.gemHeader, _enhFrames.gemContent
    UI.consumSection, UI.consumHeader, UI.consumContent =
        _enhFrames.consumSection, _enhFrames.consumHeader, _enhFrames.consumContent
    UI.enhancementsSourceDropdown = _enhFrames.sourceDropdown

    UI.trinketSection, UI.trinketHeader, UI.trinketContent = ns.Sections.Trinkets.InitCompendium({
        parent = UI.scrollChild,
        headerFactory = CreateSectionHeader,
        rowFactory = MakeItemRow,
    })
    UI.trinketSection._keepHeader = true
    UI.trinketCollapsed = false

    UI.craftCraftsSection, UI.craftEmbsSection = ns.Sections.Crafting.InitCompendium({
        parent = UI.scrollChild,
        headerFactory = CreateSectionHeader,
        refresh = function()
            ns:LayoutCompendium()
        end,
    })

    UI.bisSection, UI.bisHeader, UI.bisContent = ns.Sections.Gear.InitCompendium({
        parent = UI.scrollChild,
        headerFactory = CreateSectionHeader,
        rowFactory = MakeItemRow,
    })
    UI.bisSection._keepHeader = true
    UI.bisCollapsed = false

    UI.statTargetsSection, UI.statTargetsContent =
        ns.Sections.Stats.InitCompendiumStatTargets({ parent = UI.scrollChild })
    UI.statTargetsSection:Hide()

    UI.omniumSection, UI.omniumHeader, UI.omniumContent = ns.Sections.Omnium.InitCompendium({
        parent = UI.scrollChild,
        headerFactory = CreateSectionHeader,
        refresh = function()
            ns:LayoutCompendium()
        end,
    })
    UI.omniumCollapsed = false
    UI.omniumSection:Hide()

    if ns.BuildCompendiumSettings then ns.BuildCompendiumSettings(UI.scrollChild) end

    for _, header in ipairs({
        UI.statHeader,
        UI.talentHeader,
        UI.rotationHeader,
        UI.enchantHeader,
        UI.gemHeader,
        UI.consumHeader,
        UI.trinketHeader,
        UI.bisHeader,
        UI.omniumHeader,
    }) do
        MakeStaticHeader(header)
    end

    for _, pair in ipairs({
        { UI.statContent, UI.statHeader },
        { UI.talentContent, UI.talentHeader },
        { UI.rotationContent, UI.rotationHeader },
        { UI.omniumContent, UI.omniumHeader },
        { UI.bisContent, UI.bisHeader },
        { UI.trinketContent, UI.trinketHeader },
        { UI.enchantContent, UI.enchantHeader },
        { UI.gemContent, UI.gemHeader },
        { UI.consumContent, UI.consumHeader },
    }) do
        if pair[1] and pair[2] then pair[1]:SetPoint("TOPLEFT", pair[2], "BOTTOMLEFT", 0, -SECTION_CONTENT_PAD) end
    end

    UI.emptyText = UI.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    UI.emptyText:SetPoint("CENTER", UI.scrollChild, "TOP", 0, -60)
    UI.emptyText:SetText(L["empty.select_class_spec"])
    UI.emptyText:SetTextColor(0.5, 0.5, 0.5)
end

SaveCompendiumState = function()
    if not ClassCodexDB then return end
    ClassCodexDB.compendiumClass = selectedClass
    ClassCodexDB.compendiumSpec = selectedSpec
    ClassCodexDB.compendiumHero = selectedHero
    ClassCodexDB.compendiumSource = compSource
    ClassCodexDB.compendiumContent = compContent
    ClassCodexDB.compendiumTab = activeTab
end

local COMP_CONTENT_LABELS = { mplus = "Mythic+", raid = "Raid", pvp = "PvP" }
local COMP_CONTENT_ORDER = { mplus = 1, raid = 2, pvp = 3 }
local function CompContentOptions(class, spec)
    local seen = {}
    for _, ct in ipairs(ns.QueryContentTypes and ns.QueryContentTypes("gear", class, spec) or {}) do
        local top = ct:sub(1, 4) == "pvp:" and "pvp" or ct
        if COMP_CONTENT_LABELS[top] then seen[top] = true end
    end
    local out = {}
    for top in pairs(seen) do
        out[#out + 1] = { value = top, label = COMP_CONTENT_LABELS[top], order = COMP_CONTENT_ORDER[top] }
    end
    table.sort(out, function(a, b)
        return a.order < b.order
    end)
    return out
end

local function BuildSpecOptions(class)
    local out = {}
    local keys = SPEC_KEYS[class]
    if keys then
        for _, specKey in ipairs(keys) do
            out[#out + 1] = {
                value = specKey,
                label = SpecIconMarkup(class, specKey) .. GetSpecDisplayName(class, specKey),
            }
        end
    end
    return out
end

local function DefaultHero(class, spec)
    local sd = spec and DATA[class] and DATA[class][spec]
    local opts = sd and GetHeroTalentOptions(sd)
    return (opts and opts[1]) or "All"
end

-- Icy Veins sometimes covers only one hero tree for a spec (e.g. warrior arms/fury);
-- top the selector's options up from u.gg so every hero tree stays selectable.
local function HeroOptionsForSelector(class, spec, specData)
    local opts = GetHeroTalentOptions(specData)
    local ugg = ClassCodexSource and ClassCodexSource.ugg
    local usd = ugg and ugg.data and ugg.data[class] and ugg.data[class][spec]
    local names = ugg and ugg.reference and ugg.reference.heroNames
    if usd and usd.talents and names then
        local seen = {}
        for _, h in ipairs(opts) do
            seen[h] = true
        end
        for slug in pairs(usd.talents) do
            local display = names[slug]
            if display and not seen[display] then
                seen[display] = true
                opts[#opts + 1] = display
            end
        end
    end
    return opts
end

RefreshContextBanner = function()
    if not UI.sourceButton then return end
    local specData = selectedClass and selectedSpec and DATA[selectedClass] and DATA[selectedClass][selectedSpec]
    if not specData then
        UI.sourceButton:Hide()
        return
    end

    local heroOptions = HeroOptionsForSelector(selectedClass, selectedSpec, specData)
    if not selectedHero or selectedHero == "" then selectedHero = heroOptions[1] or "All" end

    local sourceKeys = ns.QuerySources and ns.QuerySources("gear", selectedClass, selectedSpec) or {}
    if #sourceKeys == 0 then sourceKeys = { "icyveins", "ugg" } end
    local sourceOk = false
    for _, s in ipairs(sourceKeys) do
        if s == compSource then
            sourceOk = true
            break
        end
    end
    if not sourceOk then compSource = sourceKeys[1] end

    local contentOpts = CompContentOptions(selectedClass, selectedSpec)
    local ctOk = false
    for _, o in ipairs(contentOpts) do
        if o.value == compContent then
            ctOk = true
            break
        end
    end
    if not ctOk then compContent = contentOpts[1] and contentOpts[1].value or "mplus" end

    local classOptions = {}
    for _, token in ipairs(CLASS_ORDER) do
        classOptions[#classOptions + 1] = {
            value = token,
            label = ClassIconMarkup(token) .. GetClassDisplayName(token),
        }
    end

    local specOptions = BuildSpecOptions(selectedClass)

    local cfg = {
        useSubmenus = true,
        sourceCurrent = compSource,
        sourceOptions = sourceKeys,
        onSource = function(k)
            compSource = k
            SaveCompendiumState()
            ns:UpdateCompendium()
        end,
        contentCurrent = compContent,
        contentOptions = contentOpts,
        onContent = function(v)
            compContent = v
            SaveCompendiumState()
            ns:UpdateCompendium()
        end,
        heroCurrent = selectedHero,
        heroOptions = #heroOptions > 1 and heroOptions or nil,
        onHero = function(h)
            selectedHero = h
            SaveCompendiumState()
            ns:UpdateCompendium()
        end,
        classCurrent = selectedClass,
        classOptions = classOptions,
        onClass = function(token)
            selectedClass = token
            selectedSpec = SPEC_KEYS[token] and SPEC_KEYS[token][1] or nil
            selectedHero = DefaultHero(token, selectedSpec)
            SaveCompendiumState()
            ns:UpdateCompendium()
        end,
        specCurrent = selectedSpec,
        specOptions = specOptions,
        onSpec = function(key)
            selectedSpec = key
            selectedHero = DefaultHero(selectedClass, key)
            SaveCompendiumState()
            ns:UpdateCompendium()
        end,
        specIcon = GetSpecIconTexture(selectedClass, selectedSpec),
        classToken = selectedClass,
        class = selectedClass,
        spec = selectedSpec,
    }
    UI.sourceButton:SetContext(cfg)
    UI.sourceButton:Show()
end

local COMP_TAB_FLAGS = {
    stats = { "compShowStats" },
    talents = { "compShowTalents", "compShowOmnium" },
    rotation = { "compShowRotation" },
    gear = { "compShowBisGear" },
    trinkets = { "compShowTrinkets" },
    enhancements = { "compShowEnchants" },
    crafting = { "compShowCrafts" },
}

local function CompTabHidden(key)
    local flags = COMP_TAB_FLAGS[key]
    if not flags or not ClassCodexDB then return false end
    for _, flag in ipairs(flags) do
        if ClassCodexDB[flag] ~= false then return false end
    end
    return true
end

function ns:UpdateCompendium()
    if not UI.statSection then return end

    ns.compOwnClass = selectedClass == select(2, UnitClass("player"))

    local tabRedirected = false
    if UI.pane and UI.pane.ApplyTabVisibility then
        local resolved = UI.pane:ApplyTabVisibility(CompTabHidden) or activeTab
        tabRedirected = resolved ~= activeTab
        activeTab = resolved
        if tabRedirected then SaveCompendiumState() end
    end

    UI.statSection:Hide()
    UI.talentSection:Hide()
    UI.rotationSection:Hide()
    UI.enchantSection:Hide()
    UI.gemSection:Hide()
    UI.consumSection:Hide()
    UI.trinketSection:Hide()
    if UI.craftCraftsSection then UI.craftCraftsSection:Hide() end
    if UI.craftEmbsSection then UI.craftEmbsSection:Hide() end
    UI.bisSection:Hide()
    if UI.statTargetsSection then UI.statTargetsSection:Hide() end
    if UI.omniumSection then UI.omniumSection:Hide() end
    UI.emptyText:Hide()

    if UI.enhancementsSourceDropdown then UI.enhancementsSourceDropdown:Hide() end

    if not selectedClass or not selectedSpec then
        UI.emptyText:Show()
        ns:LayoutCompendium()
        return
    end

    local specData = DATA[selectedClass] and DATA[selectedClass][selectedSpec]
    if not specData then
        UI.emptyText:SetText(L["empty.no_data"])
        UI.emptyText:Show()
        ns:LayoutCompendium()
        return
    end

    local heroOptions = GetHeroTalentOptions(specData)
    if not selectedHero or selectedHero == "" then selectedHero = heroOptions[1] or "All" end

    local icon = GetSpecIconTexture(selectedClass, selectedSpec)
    if icon then
        UI.frame:SetPortraitToAsset(icon)
    else
        UI.frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_09")
    end

    local contentLabel = COMP_CONTENT_LABELS[compContent]
    local heroLabel = (selectedHero and selectedHero ~= "All" and selectedHero ~= "") and selectedHero or nil
    local titleParts = {}
    if contentLabel then titleParts[#titleParts + 1] = contentLabel end
    if heroLabel then titleParts[#titleParts + 1] = heroLabel end
    titleParts[#titleParts + 1] = GetSpecDisplayName(selectedClass, selectedSpec)
    titleParts[#titleParts + 1] = GetClassDisplayName(selectedClass)
    UI.frame:SetTitle("Compendium " .. ns.DOT_SEPARATOR .. " " .. table.concat(titleParts, " "))

    local gearData = ns.GetSpecGearData(selectedClass, selectedSpec, compSource)
    RequestAllGearItems(gearData)

    RefreshContextBanner()

    local heroTalent = selectedHero or "All"
    self:RenderAllCompendiumSections(specData, heroTalent)

    ns:LayoutCompendium()

    if tabRedirected and UI.pane then UI.pane:ScrollToTab(activeTab) end
end

local function RenderStatPrioritySection(specData, heroTalent)
    ns.Sections.Stats.RenderCompendium({
        contextOptions = {},
        classToken = selectedClass,
        specKey = selectedSpec, -- raw data key
        prefKey = (selectedClass or "") .. "-" .. (selectedSpec or ""), -- per-spec pref key
        source = compSource,
        heroSlug = ns.HeroSlugFromDisplay and ns.HeroSlugFromDisplay(heroTalent) or nil,
        contentType = compContent,
    })
end

function ns:UpdateCompendiumRotation(specData, heroTalent)
    local rotWantPvp = compContent == "pvp"
    local rotCtxOptions = {}
    for _, c in ipairs(GetRotationContextOptions(specData, heroTalent)) do
        local isPvp = type(c) == "string" and c:lower():find("pvp", 1, true) ~= nil
        if isPvp == rotWantPvp then rotCtxOptions[#rotCtxOptions + 1] = c end
    end
    local rotContext = rotCtxOptions[1] or "General"
    if currentRotContext then
        for _, c in ipairs(rotCtxOptions) do
            if c == currentRotContext then
                rotContext = currentRotContext
                break
            end
        end
    end
    if #rotCtxOptions > 1 then currentRotContext = rotContext end
    local rotation = FindRotationByContext(specData.rotation, heroTalent, rotContext)
    ns.Sections.Rotation.RenderCompendium({
        contextOptions = rotCtxOptions,
        currentContext = currentRotContext or rotContext,
        rotation = rotation,
        heroTalent = heroTalent,
        source = compSource,
        hasAnyRotation = specData.rotation and #specData.rotation > 0 or false,
        textAreaWidth = CompContentWidth() - 42,
        labelForContext = function(ctx)
            return L[ctx]
        end,
        helpers = {
            shouldShow = function()
                return true
            end,
            strip = StripConditionPrefix,
            getIcon = GetStepSpellIcon,
            format = FormatRotationStep,
        },
        onCtxChange = function(picked)
            currentRotContext = picked
            ns:UpdateCompendium()
        end,
    })
end

function ns:UpdateCompendiumStatTargets()
    if not UI.statTargetsSection then return end
    local pClass, pSpec = nil, nil
    if ns.GetClassAndSpec then
        pClass, pSpec = ns.GetClassAndSpec()
    end
    local ownSpec = selectedClass == pClass and selectedSpec == pSpec
    local n = ns.Sections.Stats.RenderCompendiumStatTargets({
        classToken = selectedClass,
        specKey = selectedSpec,
        heroTalent = selectedHero,
        contentType = compContent,
        source = compSource,
        showCurrent = ownSpec,
    })
    UI.statTargetsSection:SetShown(n and n > 0 or false)
end

function ns:UpdateCompendiumOmnium(specData)
    if not UI.omniumSection then return end
    local runes = specData
        and specData.omniumFolio
        and specData.omniumFolio["all"]
        and specData.omniumFolio["all"]["all"]
    -- The folio is Icy Veins data regardless of the selected source — the
    -- badge in the subheader marks it as borrowed on the u.gg source.
    local n = ns.Sections.Omnium.RenderCompendium({
        runes = runes,
        source = compSource,
    })
    local allowed = not ClassCodexDB or ClassCodexDB.compShowOmnium ~= false
    UI.omniumSection:SetShown(allowed and n and n > 0 or false)
end

function ns:RenderAllCompendiumSections(specData, heroTalent)
    RenderStatPrioritySection(specData, heroTalent)
    self:UpdateCompendiumStatTargets()
    self:UpdateCompendiumAllTalents(specData, selectedClass, selectedSpec)
    self:UpdateCompendiumOmnium(specData)
    self:UpdateCompendiumRotation(specData, heroTalent)
    self:UpdateCompendiumBis()
    self:UpdateCompendiumTrinkets()
    self:UpdateCompendiumEnchants()
    self:UpdateCompendiumConsumables()
    self:UpdateCompendiumCrafts()
end

function ns:UpdateCompendiumAllTalents(_, classFile, specKey)
    local curClass, curSpec
    if ns.GetClassAndSpec then
        curClass, curSpec = ns.GetClassAndSpec()
    end
    local isCurrentSpec = ns.compOwnClass and curClass == classFile and curSpec == specKey
    ns.Sections.Talents.RenderCompendium({
        class = classFile,
        spec = specKey,
        source = compSource,
        contentType = compContent,
        activeHero = selectedHero,
        specIcon = GetSpecIconTexture(classFile, specKey),
        showActions = isCurrentSpec,
        matchActive = isCurrentSpec and ns.BuildMatchesActive or function()
            return false
        end,
        onCopy = function(export, card)
            if ns.ShowCopyPopup then ns.ShowCopyPopup(export, card) end
        end,
        fallbackNoneText = (compSource == "icyveins")
                and (L["loadout_dock.no_icyveins_builds"] or "No Icy Veins talent builds available.")
            or (L["loadout_dock.no_ugg_builds"] or "No U.GG builds available."),
    })
end

function ns:UpdateCompendiumEnchants()
    local gearData = ns.GetSpecGearData(selectedClass, selectedSpec, compSource, compContent)
    local enchants = gearData and gearData.enchants
    local gems = (compContent ~= "pvp") and gearData and gearData.gems or nil
    ns.Sections.Enhancements.RenderCompendiumEnchantsGems({
        enchants = enchants,
        gems = gems,
        specKey = (selectedClass or "") .. "-" .. (selectedSpec or ""),
        getDisplayName = GetItemDisplayName,
        refresh = function()
            ns:UpdateCompendiumEnchants()
            ns:LayoutCompendium()
        end,
    })
end

function ns:UpdateCompendiumConsumables()
    local gearData = ns.GetSpecGearData(selectedClass, selectedSpec, compSource, compContent)
    ns.Sections.Enhancements.RenderCompendiumConsumables({
        consumables = gearData and gearData.consumables,
        source = compSource,
    })
end

function ns:UpdateCompendiumTrinkets()
    local src = compSource
    local gearData = ns.GetSpecGearData(selectedClass, selectedSpec, src, compContent)
    ns.Sections.Trinkets.RenderCompendium({
        trinkets = gearData and gearData.trinkets,
        class = selectedClass,
        specKey = selectedSpec,
        width = CompContentWidth(),
        refresh = function()
            ns:UpdateCompendium()
        end,
    })
end

function ns:UpdateCompendiumCrafts()
    ns.Sections.Crafting.RenderCompendium({
        class = selectedClass,
        spec = selectedSpec,
        refresh = function()
            ns:UpdateCompendium()
        end,
    })
end

function ns:UpdateCompendiumBis()
    local bisData = ns.GetBisGearData and ns.GetBisGearData(compSource, selectedClass, selectedSpec)
    ns.Sections.Gear.RenderCompendium({
        bisGear = bisData and bisData.bisGear,
        class = selectedClass,
        spec = selectedSpec,
        source = compSource,
        contentType = compContent,
        specKey = (selectedClass or "") .. "-" .. (selectedSpec or ""),
        refresh = function()
            ns:UpdateCompendium()
            ns:LayoutCompendium()
        end,
    })
end

function ns:LayoutCompendium()
    if UI.pane then UI.pane:Relayout() end
end

function ns:BuildCompendiumLayout(content, viewportH)
    local anchors, pages = {}, {}
    for _, pt in pairs(UI.groupTitles or {}) do
        pt:Hide()
    end

    if UI.emptyText:IsShown() then return anchors, pages, 120 end

    local function compHidden(flag)
        return ClassCodexDB and ClassCodexDB[flag] == false
    end
    if compHidden("compShowStats") then
        UI.statSection:Hide()
        if UI.statTargetsSection then UI.statTargetsSection:Hide() end
    end
    if compHidden("compShowTalents") then UI.talentSection:Hide() end
    if compHidden("compShowRotation") then UI.rotationSection:Hide() end
    if compHidden("compShowBisGear") then UI.bisSection:Hide() end
    if compHidden("compShowTrinkets") then UI.trinketSection:Hide() end
    if compHidden("compShowEnchants") then
        UI.enchantSection:Hide()
        UI.gemSection:Hide()
        UI.consumSection:Hide()
    end
    if compHidden("compShowCrafts") then
        if UI.craftCraftsSection then UI.craftCraftsSection:Hide() end
        if UI.craftEmbsSection then UI.craftEmbsSection:Hide() end
    end

    local function placeGroupSection(section, header, body, contentHeight, y, hideHeader)
        if not section or not section:IsShown() then return y end
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", content, "TOPLEFT", INSET_PAD, y)
        section:SetPoint("RIGHT", content, "RIGHT", -INSET_PAD, 0)
        body:ClearAllPoints()
        body:SetPoint("RIGHT", section, "RIGHT", 0, 0)
        local h
        if hideHeader then
            if header then header:Hide() end
            body:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
            h = (contentHeight or 0) + 4
        else
            if header then header:Show() end
            body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -SECTION_CONTENT_PAD)
            h = SECTION_HEADER_HEIGHT + SECTION_CONTENT_PAD + (contentHeight or 0)
        end
        section:SetHeight(h)
        return y - h - 4
    end

    local function divider(header, show)
        if header and header.topDivider then header.topDivider:SetShown(show and true or false) end
    end

    local function headerHasWidgets(header)
        return (header and header._widgets and #header._widgets > 0) and true or false
    end

    local function layoutMembers(y, members)
        local visibleCount = 0
        for _, m in ipairs(members) do
            if m.section and m.section:IsShown() then visibleCount = visibleCount + 1 end
        end
        local sole = visibleCount == 1
        local seen = false
        for _, m in ipairs(members) do
            if m.section and m.section:IsShown() then
                local hide = sole and not headerHasWidgets(m.header) and not (m.section and m.section._keepHeader)
                divider(m.header, seen and not hide)
                if not hide then seen = true end
                y = placeGroupSection(m.section, m.header, m.body, m.height or 0, y, hide)
            end
        end
        return y
    end

    local placers = {
        stats = function(y)
            y = layoutMembers(y, {
                {
                    section = UI.statSection,
                    header = UI.statHeader,
                    body = UI.statContent,
                    height = ns.Sections.Stats.GetCompendiumContentHeight(),
                },
            })
            if UI.statTargetsSection and UI.statTargetsSection:IsShown() then
                UI.statTargetsSection:ClearAllPoints()
                UI.statTargetsSection:SetPoint("TOPLEFT", content, "TOPLEFT", INSET_PAD, y)
                UI.statTargetsSection:SetPoint("RIGHT", content, "RIGHT", -INSET_PAD, 0)
                local sth = ns.Sections.Stats.GetCompendiumStatTargetsHeight()
                UI.statTargetsSection:SetHeight(sth)
                y = y - sth - 4
            end
            return y
        end,
        talents = function(y)
            return layoutMembers(y, {
                {
                    section = UI.talentSection,
                    header = UI.talentHeader,
                    body = UI.talentContent,
                    height = ns.Sections.Talents.GetCompendiumContentHeight(),
                },
                {
                    section = UI.omniumSection,
                    header = UI.omniumHeader,
                    body = UI.omniumContent,
                    height = ns.Sections.Omnium.GetCompendiumContentHeight(),
                },
            })
        end,
        rotation = function(y)
            return layoutMembers(y, {
                {
                    section = UI.rotationSection,
                    header = UI.rotationHeader,
                    body = UI.rotationContent,
                    height = ns.Sections.Rotation.GetCompendiumContentHeight(),
                },
            })
        end,
        gear = function(y)
            return layoutMembers(y, {
                {
                    section = UI.bisSection,
                    header = UI.bisHeader,
                    body = UI.bisContent,
                    height = ns.Sections.Gear.GetCompendiumContentHeight(),
                },
            })
        end,
        trinkets = function(y)
            return layoutMembers(y, {
                {
                    section = UI.trinketSection,
                    header = UI.trinketHeader,
                    body = UI.trinketContent,
                    height = ns.Sections.Trinkets.GetCompendiumContentHeight(),
                },
            })
        end,
        enhancements = function(y)
            local enh = ns.Sections.Enhancements.GetCompendiumFrames()
            if enh.sourceDropdown and enh.sourceDropdown:IsShown() then
                enh.sourceDropdown:ClearAllPoints()
                enh.sourceDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", INSET_PAD, y)
                enh.sourceDropdown:SetPoint("RIGHT", content, "RIGHT", -INSET_PAD, 0)
                y = y - 30
            end
            return layoutMembers(y, {
                {
                    section = UI.enchantSection,
                    header = UI.enchantHeader,
                    body = UI.enchantContent,
                    height = ns.Sections.Enhancements.GetCompendiumEnchantHeight(),
                },
                {
                    section = UI.gemSection,
                    header = UI.gemHeader,
                    body = UI.gemContent,
                    height = ns.Sections.Enhancements.GetCompendiumGemHeight(),
                },
                {
                    section = UI.consumSection,
                    header = UI.consumHeader,
                    body = UI.consumContent,
                    height = ns.Sections.Enhancements.GetCompendiumConsumHeight(),
                },
            })
        end,
        crafting = function(y)
            return layoutMembers(y, {
                {
                    section = UI.craftCraftsSection,
                    header = UI.craftCraftsSection and UI.craftCraftsSection.header,
                    body = UI.craftCraftsSection and UI.craftCraftsSection.content,
                    height = ns.Sections.Crafting.GetCompendiumCraftsHeight(),
                },
                {
                    section = UI.craftEmbsSection,
                    header = UI.craftEmbsSection and UI.craftEmbsSection.header,
                    body = UI.craftEmbsSection and UI.craftEmbsSection.content,
                    height = ns.Sections.Crafting.GetCompendiumEmbsHeight(),
                },
            })
        end,
        about = function(y)
            if ns.compSettingsSection and ns.compSettingsContent then
                if ns.compRefreshSettingsView then ns.compRefreshSettingsView() end
                y = layoutMembers(y, {
                    {
                        section = ns.compSettingsSection,
                        header = ns.compSettingsSection.header,
                        body = ns.compSettingsContent,
                        height = ns.compSettingsContent:GetHeight() or 0,
                    },
                })
            end
            return y
        end,
    }

    local function placeTitle(key, y)
        local pt = UI.groupTitles and UI.groupTitles[key]
        if not pt then return y end
        pt:ClearAllPoints()
        pt:SetPoint("TOPLEFT", content, "TOPLEFT", INSET_PAD, y)
        pt:SetPoint("RIGHT", content, "RIGHT", -INSET_PAD, 0)
        pt:SetTitle((key == "about" and L["about.header"]) or L[GROUP_LABEL[key]] or "")
        if pt.link then
            local surface = GROUP_SURFACE[key]
            if key == "about" then
                pt.link:SetLink(ns.WEBSITE_URL, L["about.website_page"])
            elseif surface and ns.ResolveAttribution and selectedClass and selectedSpec then
                pt.link:SetSource(
                    ns.ResolveAttribution(
                        surface,
                        selectedClass,
                        selectedSpec,
                        compSource,
                        compContent == "pvp" and "pvp" or "pve"
                    )
                )
            else
                pt.link:SetSource(nil)
            end
        end
        pt:Show()
        return y - ns.PAGE_TITLE_HEIGHT
    end

    local y = 0
    local naturalH = {}
    for _, key in ipairs(GROUP_ORDER) do
        local startY = y
        y = placers[key](y)
        naturalH[key] = startY - y
    end

    y = 0
    for _, key in ipairs(GROUP_ORDER) do
        local nat = naturalH[key] or 0
        if nat > 1 then
            local total = nat + ns.PAGE_TITLE_HEIGHT
            local pageTop = -y
            local pageHeight = math.max(viewportH, total)
            y = placeTitle(key, y)
            placers[key](y)
            anchors[key] = pageTop
            pages[#pages + 1] = { key = key, top = pageTop, height = pageHeight }
            y = -(pageTop + pageHeight)
        elseif UI.groupTitles and UI.groupTitles[key] then
            UI.groupTitles[key]:Hide()
        end
    end

    return anchors, pages, math.max(-y, 1)
end

function ns:OpenCompendium(class, spec)
    InitFrame()

    if class then
        selectedClass = class
        selectedSpec = spec or (SPEC_KEYS[class] and SPEC_KEYS[class][1]) or nil
        selectedHero = nil
        compSource, compContent = nil, nil
        SaveCompendiumState()
        if UI.frame:IsShown() then
            ns:UpdateCompendium()
            return
        end
    elseif UI.frame:IsShown() then
        UI.frame:Hide()
        return
    end

    if not selectedClass then
        if ClassCodexDB and ClassCodexDB.compendiumClass and ClassCodexDB.compendiumSpec then
            selectedClass = ClassCodexDB.compendiumClass
            selectedSpec = ClassCodexDB.compendiumSpec
            selectedHero = ClassCodexDB.compendiumHero
            compSource = ClassCodexDB.compendiumSource
            compContent = ClassCodexDB.compendiumContent
        else
            local _, classToken = UnitClass("player")
            selectedClass = classToken
            local specIndex = GetSpecialization()
            if specIndex and SPEC_KEYS[classToken] then
                selectedSpec = SPEC_KEYS[classToken][specIndex]
            else
                selectedSpec = SPEC_KEYS[classToken] and SPEC_KEYS[classToken][1]
            end
        end

        if not selectedHero and selectedSpec then
            local specData = DATA[selectedClass] and DATA[selectedClass][selectedSpec]
            if specData then
                local opts = GetHeroTalentOptions(specData)
                selectedHero = opts[1] or "All"
            end
        end
    end

    if ClassCodexDB and ClassCodexDB.compendiumTab then
        activeTab = TAB_MIGRATE[ClassCodexDB.compendiumTab] or ClassCodexDB.compendiumTab
    end
    if not GROUP_SURFACE[activeTab] then activeTab = "stats" end
    if UI.pane then UI.pane:SetActiveTab(activeTab) end

    RefreshContextBanner()

    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    UI.frame:Show()
    ns:UpdateCompendium()
    if UI.pane then UI.pane:ScrollToTab(activeTab) end
end
