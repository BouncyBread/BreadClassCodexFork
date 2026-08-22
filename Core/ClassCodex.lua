local addonName, ns = ...

local DATA = IcyVeinsData
if not DATA then return end

local L = ns.L

ns.ccContested = false
function ns.FixSlash(s)
    if ns.ccContested and type(s) == "string" then return (s:gsub("/cc", "/classcodex")) end
    return s
end

local PANEL_WIDTH = 312
local PANEL_PADDING = 12
local CONTENT_INSET = 11
local BUTTON_SIZE = 42
local WIDGET_DEFAULT_OFFSET_X = -22
local WIDGET_DEFAULT_OFFSET_Y = -46
local FADE_DURATION = 0.15
local ROW_HEIGHT = 22
local SECTION_HEADER_HEIGHT = 28
local SECTION_CONTENT_PAD = 4
local SECTION_GAP = 5
local PAGE_TITLE_GAP = 0
local DROPDOWN_HEIGHT = 26
local SUBHEADER_HEIGHT = 30

local RANK_COLORS = {
    { r = 0.64, g = 0.21, b = 0.93 },
    { r = 0.00, g = 0.44, b = 0.87 },
    { r = 0.12, g = 1.00, b = 0.00 },
    { r = 1.00, g = 1.00, b = 1.00 },
    { r = 0.62, g = 0.62, b = 0.62 },
}

local HERO_TALENT_ATLAS = {

    ["San'layn"] = "talents-heroclass-deathknight-sanlayn",
    ["Rider of the Apocalypse"] = "talents-heroclass-deathknight-rideroftheapocalypse",
    ["Deathbringer"] = "talents-heroclass-deathknight-deathbringer",

    ["Fel-Scarred"] = "talents-heroclass-demonhunter-felscarred",
    ["Aldrachi Reaver"] = "talents-heroclass-demonhunter-aldrachireaver",
    ["Annihilator"] = "talents-heroclass-demonhunter-annihilator",
    ["Void-Scarred"] = "talents-heroclass-demonhunter-felscarred2",

    ["Druid of the Claw"] = "talents-heroclass-druid-druidoftheclaw",
    ["Wildstalker"] = "talents-heroclass-druid-wildstalker",
    ["Keeper of the Grove"] = "talents-heroclass-druid-keeperofthegrove",
    ["Elune's Chosen"] = "talents-heroclass-druid-eluneschosen",

    ["Scalecommander"] = "talents-heroclass-evoker-scalecommander",
    ["Flameshaper"] = "talents-heroclass-evoker-flameshaper",
    ["Chronowarden"] = "talents-heroclass-evoker-chronowarden",

    ["Sentinel"] = "talents-heroclass-hunter-sentinel",
    ["Pack Leader"] = "talents-heroclass-hunter-packleader",
    ["Dark Ranger"] = "talents-heroclass-hunter-darkranger",

    ["Sunfury"] = "talents-heroclass-mage-sunfury",
    ["Spellslinger"] = "talents-heroclass-mage-spellslinger",
    ["Frostfire"] = "talents-heroclass-mage-frostfire",

    ["Conduit of the Celestials"] = "talents-heroclass-monk-conduitofthecelestials",
    ["Shado-Pan"] = "talents-heroclass-monk-shadopan",
    ["Shado-pan"] = "talents-heroclass-monk-shadopan",
    ["Master of Harmony"] = "talents-heroclass-monk-masterofharmony",

    ["Templar"] = "talents-heroclass-paladin-templar",
    ["Lightsmith"] = "talents-heroclass-paladin-lightsmith",
    ["Herald of the Sun"] = "talents-heroclass-paladin-heraldofthesun",

    ["Voidweaver"] = "talents-heroclass-priest-voidweaver",
    ["Archon"] = "talents-heroclass-priest-archon",
    ["Oracle"] = "talents-heroclass-priest-oracle",

    ["Trickster"] = "talents-heroclass-rogue-trickster",
    ["Fatebound"] = "talents-heroclass-rogue-fatebound",
    ["Deathstalker"] = "talents-heroclass-rogue-deathstalker",

    ["Totemic"] = "talents-heroclass-shaman-totemic",
    ["Stormbringer"] = "talents-heroclass-shaman-stormbringer",
    ["Farseer"] = "talents-heroclass-shaman-farseer",

    ["Soul Harvester"] = "talents-heroclass-warlock-soulharvester",
    ["Hellcaller"] = "talents-heroclass-warlock-hellcaller",
    ["Diabolist"] = "talents-heroclass-warlock-diabolist",

    ["Slayer"] = "talents-heroclass-warrior-slayer",
    ["Mountain Thane"] = "talents-heroclass-warrior-mountainthane",
    ["Colossus"] = "talents-heroclass-warrior-colossus",
}

local ATLAS_TO_HERO = {}
for name, atlas in pairs(HERO_TALENT_ATLAS) do
    ATLAS_TO_HERO[atlas] = ATLAS_TO_HERO[atlas] or name
end

local isFloating = false
local isMinimized = false

local dockHosts = {}

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

local function GetClassAndSpec()
    local _, classToken = UnitClass("player")
    local specIndex = GetSpecialization()
    if not specIndex then return classToken, nil end
    local keys = SPEC_KEYS[classToken]
    if not keys or not keys[specIndex] then return classToken, nil end
    return classToken, keys[specIndex]
end

local function GetSpecData()
    local classToken, specKey = GetClassAndSpec()
    if not classToken or not specKey then return nil end
    local classData = DATA[classToken]
    if not classData then return nil end
    return classData[specKey], classToken, specKey
end

local function GetSpecKey()
    local classToken, specKey = GetClassAndSpec()
    if classToken and specKey then return classToken .. "-" .. specKey end
    return nil
end

local function GetActiveHeroTalentName()
    if not C_ClassTalents or not C_ClassTalents.GetActiveHeroTalentSpec then return nil end
    local subTreeID = C_ClassTalents.GetActiveHeroTalentSpec()
    if not subTreeID or subTreeID == 0 then return nil end

    if C_Traits and C_Traits.GetSubTreeInfo then
        local ok, info = pcall(C_Traits.GetSubTreeInfo, subTreeID)
        if not ok and C_ClassTalents.GetActiveConfigID then
            local configID = C_ClassTalents.GetActiveConfigID()
            if configID then
                ok, info = pcall(C_Traits.GetSubTreeInfo, configID, subTreeID)
            end
        end
        if ok and info then
            if info.iconAtlas and ATLAS_TO_HERO[info.iconAtlas] then return ATLAS_TO_HERO[info.iconAtlas] end
            if info.name then return info.name end
        end
    end
    return nil
end

local function GetSpecHeroTalents()
    local out = {}
    if
        not (
            C_ClassTalents
            and C_ClassTalents.GetActiveConfigID
            and C_ClassTalents.GetHeroTalentSpecsForClassSpec
            and C_Traits
            and C_Traits.GetSubTreeInfo
            and GetSpecialization
        )
    then
        return out
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    if not (configID and specID) then return out end
    local ok, subTreeIDs = pcall(C_ClassTalents.GetHeroTalentSpecsForClassSpec, configID, specID)
    if not ok or type(subTreeIDs) ~= "table" then return out end
    for _, id in ipairs(subTreeIDs) do
        local iok, info = pcall(C_Traits.GetSubTreeInfo, configID, id)
        if iok and info then
            local name = (info.iconAtlas and ATLAS_TO_HERO[info.iconAtlas]) or info.name
            if name then out[#out + 1] = name end
        end
    end
    return out
end

local function GetSpecIcon()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local _, _, _, icon = GetSpecializationInfo(specIndex)
    return icon
end

local function FadeIn(frame)
    if frame.fadeAnim then frame.fadeAnim:Stop() end
    frame:SetAlpha(0)
    frame:Show()
    if not frame.fadeAnim then
        local ag = frame:CreateAnimationGroup()
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(0)
        fade:SetToAlpha(1)
        fade:SetDuration(FADE_DURATION)
        ag:SetScript("OnFinished", function()
            frame:SetAlpha(1)
        end)
        frame.fadeAnim = ag
    end
    frame.fadeAnim:Play()
end

local PANEL_WIDTH_MIN = 260
local PANEL_WIDTH_MAX = 500

local function GetPanelWidth()
    local w = ClassCodexDB and ClassCodexDB.panelWidth
    if type(w) ~= "number" or w < PANEL_WIDTH_MIN or w > PANEL_WIDTH_MAX then return PANEL_WIDTH end
    return w
end

local FLOAT_HEIGHT_DEFAULT = 600
local FLOAT_HEIGHT_MIN = 360
local FLOAT_HEIGHT_MAX = 1200

local function GetFloatPanelHeight()
    local h = ClassCodexDB and ClassCodexDB.floatPanelHeight
    if type(h) ~= "number" or h < FLOAT_HEIGHT_MIN or h > FLOAT_HEIGHT_MAX then return FLOAT_HEIGHT_DEFAULT end
    return h
end

local GetHeroTalentOptions = ns.GetHeroTalentOptions

local GetRotationContextOptions = ns.GetRotationContextOptions

local FindRotationByContext = ns.FindRotationByContext

local function GetPerSpecState()
    local specKey = GetSpecKey()
    if not specKey or not ClassCodexCharDB then return nil end
    if not ClassCodexCharDB.perSpec then ClassCodexCharDB.perSpec = {} end
    if not ClassCodexCharDB.perSpec[specKey] then
        ClassCodexCharDB.perSpec[specKey] =
            { heroTalent = nil, statContext = nil, rotationContext = nil, trinketContext = nil, bisTab = nil }
    end
    return ClassCodexCharDB.perSpec[specKey]
end

local FormatRotationStep = ns.FormatRotationStep

local function EvalConditionExpr(expr, currentHeroTalent, viewingOwnHero)
    local pos, len = 1, #expr
    local function peek()
        if pos > len then return nil end
        return expr:sub(pos, pos)
    end
    local function eatWs()
        while pos <= len and expr:sub(pos, pos) == " " do
            pos = pos + 1
        end
    end
    local parseOr
    local function parseUnary()
        eatWs()
        local c = peek()
        if c == "!" then
            pos = pos + 1
            return not parseUnary()
        elseif c == "(" then
            pos = pos + 1
            local v = parseOr()
            eatWs()
            if peek() == ")" then pos = pos + 1 end
            return v
        elseif c == "H" and expr:sub(pos + 1, pos + 1) == '"' then
            local closing = expr:find('"', pos + 2, true)
            if not closing then return false end
            local label = expr:sub(pos + 2, closing - 1)
            pos = closing + 1
            if not currentHeroTalent then return false end
            return currentHeroTalent:lower() == label:lower()
        else
            local s, e = expr:find("^(%d+)", pos)
            if not s then return false end
            pos = e + 1
            if not viewingOwnHero then return true end
            return IsPlayerSpell(tonumber(expr:sub(s, e))) and true or false
        end
    end
    local function parseAnd()
        local v = parseUnary()
        eatWs()
        while peek() == "&" do
            pos = pos + 1
            v = parseUnary() and v
            eatWs()
        end
        return v
    end
    parseOr = function()
        local v = parseAnd()
        eatWs()
        while peek() == "|" do
            pos = pos + 1
            v = parseAnd() or v
            eatWs()
        end
        return v
    end
    return parseOr() and true or false
end

-- Rank upgrades replace a talent's spell id with a new one, so IsPlayerSpell
-- on the data's base id is false even though the player has the (upgraded)
-- talent — which silently hid whole rotation steps (e.g. Earthquake). Fall
-- back to a name match against the player's spellbook, cached per id and
-- wiped whenever talents change.
local spellKnownCache = {}
local function PlayerKnowsSpell(spellId)
    if not spellId then return true end
    local cached = spellKnownCache[spellId]
    if cached ~= nil then return cached end
    local known = (IsPlayerSpell and IsPlayerSpell(spellId)) or (IsSpellKnown and IsSpellKnown(spellId))
    if not known then
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
        if info and info.name and C_SpellBook and C_SpellBook.GetNumSpells and C_SpellBook.GetSpellInfo then
            local ok, count = pcall(C_SpellBook.GetNumSpells)
            if ok and type(count) == "number" then
                for i = 1, count do
                    local sok, sinfo = pcall(C_SpellBook.GetSpellInfo, i)
                    if sok and sinfo and sinfo.name == info.name then
                        known = true
                        break
                    end
                end
            end
        end
    end
    spellKnownCache[spellId] = known
    return known
end

local function ViewingOwnHero(currentHeroTalent)
    if not currentHeroTalent or currentHeroTalent == "All" then return true end
    local active = GetActiveHeroTalentName()
    if not active then return true end
    return active:lower() == currentHeroTalent:lower()
end

local function ShouldShowStep(stepText, currentHeroTalent)
    local ownHero = ViewingOwnHero(currentHeroTalent)
    local reqId = stepText:match("^%?{(%d+)}:")
    if reqId then return (not ownHero) or PlayerKnowsSpell(tonumber(reqId)) end
    local negId = stepText:match("^%?!{(%d+)}:")
    if negId then return (not ownHero) or (not PlayerKnowsSpell(tonumber(negId))) end

    local exprParen = stepText:match("^%?(%b()):")
    if exprParen then return EvalConditionExpr(exprParen:sub(2, -2), currentHeroTalent, ownHero) end

    local primaryId = ns.StripConditionPrefix(stepText):match("{(%d+)}")
    if primaryId and ownHero and not PlayerKnowsSpell(tonumber(primaryId)) then return false end
    return true
end

local StripConditionPrefix = ns.StripConditionPrefix

local GetStepSpellIcon = ns.GetStepSpellIcon

local panel = CreateFrame("Frame", "ClassCodexPanel", UIParent, "ButtonFrameTemplate")
panel:SetSize(PANEL_WIDTH, 1)
if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(panel) end
if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(panel) end

panel:SetFrameStrata("HIGH")
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:Hide()

panel:HookScript("OnHide", function()
    if ns.HideSaveAsLoadoutPopup then ns.HideSaveAsLoadoutPopup() end
end)

if panel.SetTitle then panel:SetTitle("Bread Codex") end

local titleFS = panel.TitleContainer and panel.TitleContainer.TitleText
if titleFS then
    titleFS:ClearAllPoints()
    titleFS:SetPoint("LEFT", panel, "TOPLEFT", CONTENT_INSET + 2, -13)
    titleFS:SetJustifyH("LEFT")
end

if panel.CloseButton then
    panel.CloseButton:HookScript("OnClick", function()
        if ClassCodexCharDB then ClassCodexCharDB.panelOpen = false end
    end)
end

panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function(self)
    if isFloating then self:StartMoving() end
end)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if ClassCodexCharDB and isFloating then
        ClassCodexCharDB.floatX = self:GetLeft()
        ClassCodexCharDB.floatY = self:GetTop()
    end
end)

local TITLE_BTN_LEVEL = panel:GetFrameLevel() + 500
local closeAnchor = panel.CloseButton or panel

local minimizeBtn = CreateFrame("Button", nil, panel)
minimizeBtn:SetSize(21, 21)
minimizeBtn:SetPoint("RIGHT", closeAnchor, "LEFT", -2, 0)
minimizeBtn:SetFrameLevel(TITLE_BTN_LEVEL)
minimizeBtn:RegisterForClicks("LeftButtonUp")
minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
minimizeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Highlight")
minimizeBtn:Hide()
minimizeBtn:SetScript("OnEnter", function(self)
    ns.Tooltip.Open(self, "ANCHOR_RIGHT").Intro(isMinimized and "Expand" or "Minimize").Show()
end)
minimizeBtn:SetScript("OnLeave", function()
    ns.Tooltip.Hide()
end)

local SIDE_TAB_W = 34
local SIDE_TAB_H = 44
local SIDE_TAB_ATLAS = "QuestLog-tab-side"
local SIDE_TAB_SELECTED_ATLAS = "QuestLog-Tab-side-Glow-Select"
local SIDE_TAB_HOVER_ATLAS = "QuestLog-Tab-side-Glow-hover"
local SIDE_TAB_ICON_SIZE = 16
local SIDE_TAB_ICON_OFFSET_X = -1
local SIDE_TAB_ICON_OFFSET_Y = 0
local SIDE_TAB_ICON_GOLD = { 1.0, 0.82, 0.0 }
local SIDE_TAB_ICON_DIM = { 0.55, 0.45, 0.1 }
local SIDE_TAB_ANCHOR_X = -3
local SIDE_TAB_GAP = -2

local GROUP_ORDER = {
    "stats",
    "talents",
    "rotation",
    "gear",
    "trinkets",
    "enhancements",
    "crafting",
    "about",
}

local TAB_META = {
    stats = {
        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-stats",
        loc = "section.stats",
        members = {
            { sec = "stats", db = "Stats", loc = "section.stats" },
        },
    },
    talents = {
        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-talents",
        loc = "section.talents",
        members = {
            { sec = "talents", db = "Talents", loc = "section.talents" },
            { sec = "omnium" },
        },
    },
    rotation = {
        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-rotation",
        loc = "section.rotation",
        members = {
            { sec = "rotation", db = "Rotation", loc = "section.rotation" },
        },
    },
    gear = {
        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-gear",
        loc = "tab.gear",
        members = {
            { sec = "bis", db = "BisGear", loc = "tab.bis_gear" },
        },
    },
    trinkets = {
        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-trinkets",
        loc = "tab.trinkets",
        members = {
            { sec = "trinkets", db = "Trinkets", loc = "tab.trinkets" },
        },
    },
    enhancements = {
        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-enhancements",
        loc = "tab.enhancements",
        members = {
            { sec = "enchants", db = "Enchants", loc = "tab.enchants" },
            { sec = "gems", db = "Gems", loc = "tab.gems" },
            { sec = "consumables", db = "Consumables", loc = "tab.consumables" },
        },
    },
    crafting = {
        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-crafting",
        loc = "tab.crafting",
        members = {
            { sec = "crafting", db = "Crafts", loc = "crafting.section_crafts" },
            { sec = "embellishments", db = "Embellishments", loc = "crafting.section_embellishments" },
        },
    },
    about = {
        icon = "Interface\\AddOns\\BreadClassCodex\\Media\\tab-about",
        loc = "tab.about",
        members = {
            { sec = "about" },
        },
    },
}

local activeTab = "stats"
local reorderMode = false

function ns.GetSectionOrder()
    local saved = ClassCodexDB and ClassCodexDB.sectionOrder
    if type(saved) ~= "table" then return GROUP_ORDER end
    local order, seen = {}, {}
    for _, key in ipairs(saved) do
        if TAB_META[key] and not seen[key] then
            order[#order + 1] = key
            seen[key] = true
        end
    end
    for _, key in ipairs(GROUP_ORDER) do
        if not seen[key] then order[#order + 1] = key end
    end
    return order
end

local function CreateSideTab(parent, icon, tooltip, tabKey)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SIDE_TAB_W, SIDE_TAB_H)
    btn:RegisterForClicks("LeftButtonUp")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas(SIDE_TAB_ATLAS)
    bg:SetAllPoints(btn)
    btn.bg = bg

    local hoverGlow = btn:CreateTexture(nil, "HIGHLIGHT")
    hoverGlow:SetAtlas(SIDE_TAB_HOVER_ATLAS)
    hoverGlow:SetAllPoints(bg)

    local selected = btn:CreateTexture(nil, "OVERLAY")
    selected:SetAtlas(SIDE_TAB_SELECTED_ATLAS)
    selected:SetAllPoints(bg)
    selected:Hide()
    btn.selectedGlow = selected

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetSize(SIDE_TAB_ICON_SIZE, SIDE_TAB_ICON_SIZE)
    tex:SetPoint("CENTER", btn, "CENTER", SIDE_TAB_ICON_OFFSET_X, SIDE_TAB_ICON_OFFSET_Y)
    if type(icon) == "number" then
        tex:SetTexture(icon)
    elseif type(icon) == "string" and icon:find("[\\/]") then
        tex:SetTexture(icon)
    else
        tex:SetAtlas(icon)
    end
    tex:SetDesaturated(true)
    tex:SetVertexColor(SIDE_TAB_ICON_DIM[1], SIDE_TAB_ICON_DIM[2], SIDE_TAB_ICON_DIM[3])
    btn.icon = tex
    btn.tabKey = tabKey

    btn:SetScript("OnEnter", function(self)
        ns.Tooltip.Open(self, "ANCHOR_RIGHT").Intro(tooltip).Show()
    end)
    btn:SetScript("OnLeave", function()
        ns.Tooltip.Hide()
    end)
    return btn
end

local sideTabs = {}
local bottomTabs = {}
local tabByKey = {}
for _, key in ipairs(GROUP_ORDER) do
    local meta = TAB_META[key]
    if meta then
        local tab = CreateSideTab(panel, meta.icon, L[meta.loc], key)
        tab._baseLevel = tab:GetFrameLevel()
        tabByKey[key] = tab
    end
end

function ns.LayoutSideTabs()
    wipe(sideTabs)
    local prev
    local settingsTab
    for _, key in ipairs(ns.GetSectionOrder()) do
        local tab = tabByKey[key]
        if tab then
            if key == "about" then
                settingsTab = tab
            else
                tab:ClearAllPoints()
                if tab._baseLevel then tab:SetFrameLevel(tab._baseLevel) end
                if prev then
                    tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -SIDE_TAB_GAP)
                else
                    tab:SetPoint("TOPLEFT", panel, "TOPRIGHT", SIDE_TAB_ANCHOR_X, -40)
                end
                sideTabs[#sideTabs + 1] = tab
                prev = tab
            end
        end
    end
    if settingsTab then
        settingsTab:ClearAllPoints()
        if settingsTab._baseLevel then settingsTab:SetFrameLevel(settingsTab._baseLevel) end
        settingsTab:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", SIDE_TAB_ANCHOR_X, 13)
        sideTabs[#sideTabs + 1] = settingsTab
    end
end
ns.LayoutSideTabs()

local allTabs = {}
for _, key in ipairs(GROUP_ORDER) do
    if tabByKey[key] then allTabs[#allTabs + 1] = tabByKey[key] end
end

local function UpdateTabAppearance()
    for _, tab in ipairs(allTabs) do
        local isActive = (activeTab == tab.tabKey) or reorderMode
        if tab.selectedGlow then tab.selectedGlow:SetShown(activeTab == tab.tabKey and not reorderMode) end
        local c = isActive and SIDE_TAB_ICON_GOLD or SIDE_TAB_ICON_DIM
        tab.icon:SetVertexColor(c[1], c[2], c[3])
    end
end
UpdateTabAppearance()

for _, tab in ipairs(allTabs) do
    tab:SetScript("OnClick", function(self)
        if SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB or SOUNDKIT.IG_MAINMENU_OPTION) end
        activeTab = self.tabKey
        if ClassCodexCharDB then ClassCodexCharDB.activeTab = activeTab end
        UpdateTabAppearance()
        ns:UpdatePanel()
        if ns.ScrollToTab then ns:ScrollToTab(self.tabKey) end
    end)
end

do
    local TAB_STRIDE = SIDE_TAB_H + SIDE_TAB_GAP
    local dragState

    local function ColumnTopY()
        local t = panel:GetTop()
        return t and (t - 40) or nil
    end

    local function CursorScreenY()
        local _, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale == 0 then return y end
        return y / scale
    end

    local function HoverIndexFromCursor(count)
        local top = ColumnTopY()
        if not top then return count end
        local idx = math.floor((top - CursorScreenY()) / TAB_STRIDE + 0.5) + 1
        if idx < 1 then idx = 1 end
        if idx > count then idx = count end
        return idx
    end

    local function ReorderableKeys()
        local out = {}
        for _, k in ipairs(ns.GetSectionOrder()) do
            if k ~= "about" then out[#out + 1] = k end
        end
        return out
    end

    local function RelayoutDuringDrag()
        if not dragState then return end
        local count = #ReorderableKeys()
        local hover = HoverIndexFromCursor(count)
        dragState.hover = hover

        local ri = 1
        for slot = 1, count do
            if slot ~= hover then
                local tab = tabByKey[dragState.rest[ri]]
                ri = ri + 1
                if tab then
                    tab:ClearAllPoints()
                    tab:SetPoint("TOPLEFT", panel, "TOPRIGHT", SIDE_TAB_ANCHOR_X, -(40 + (slot - 1) * TAB_STRIDE))
                end
            end
        end

        local dragged = tabByKey[dragState.key]
        local top = ColumnTopY()
        if dragged and top then
            local offset = top - (CursorScreenY() + SIDE_TAB_H / 2)
            local maxOffset = (count - 1) * TAB_STRIDE
            if offset < 0 then offset = 0 end
            if offset > maxOffset then offset = maxOffset end
            dragged:ClearAllPoints()
            dragged:SetPoint("TOPLEFT", panel, "TOPRIGHT", SIDE_TAB_ANCHOR_X, -(40 + offset))
        end
    end

    local function BeginTabDrag(tab)
        if not reorderMode then return end
        local rest = {}
        for _, k in ipairs(ReorderableKeys()) do
            if k ~= tab.tabKey then rest[#rest + 1] = k end
        end
        dragState = { key = tab.tabKey, rest = rest, hover = 1 }
        tab:SetFrameLevel((panel:GetFrameLevel() or 0) + 20)
        tab.icon:SetDesaturated(false)
        tab:SetScript("OnUpdate", RelayoutDuringDrag)
        RelayoutDuringDrag()
    end

    local function EndTabDrag(tab)
        tab:SetScript("OnUpdate", nil)
        if not dragState then
            ns.LayoutSideTabs()
            return
        end
        local hover = dragState.hover or 1
        local newOrder = {}
        for _, k in ipairs(dragState.rest) do
            newOrder[#newOrder + 1] = k
        end
        if hover < 1 then hover = 1 end
        if hover > #newOrder + 1 then hover = #newOrder + 1 end
        table.insert(newOrder, hover, dragState.key)
        dragState = nil
        if ClassCodexDB then ClassCodexDB.sectionOrder = newOrder end
        ns.LayoutSideTabs()
        UpdateTabAppearance()
        if panel:IsShown() then ns:UpdatePanel() end
    end

    for _, key in ipairs(GROUP_ORDER) do
        local tab = tabByKey[key]
        if tab and key ~= "about" then
            tab:RegisterForDrag("LeftButton")
            tab:SetScript("OnDragStart", function(self)
                BeginTabDrag(self)
            end)
            tab:SetScript("OnDragStop", function(self)
                EndTabDrag(self)
            end)
        end
    end

    local reorderHint = CreateFrame("Button", nil, panel, "BackdropTemplate")
    reorderHint:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -28)
    reorderHint:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -28)
    reorderHint:SetHeight(20)
    reorderHint:SetFrameStrata("HIGH")
    reorderHint:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    reorderHint:SetBackdropColor(0.12, 0.2, 0.12, 0.95)
    reorderHint:SetBackdropBorderColor(0.2, 0.9, 0.4, 1)
    local reorderHintText = reorderHint:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reorderHintText:SetPoint("CENTER")
    reorderHintText:SetText(L["reorder.hint"])
    reorderHintText:SetTextColor(0.4, 1, 0.5)
    reorderHint:Hide()

    local function SetReorderMode(on)
        reorderMode = on and true or false
        reorderHint:SetShown(reorderMode)
        UpdateTabAppearance()
    end
    reorderHint:SetScript("OnClick", function()
        SetReorderMode(false)
    end)
    ns.SetReorderMode = SetReorderMode
    ns.IsReorderMode = function()
        return reorderMode
    end
end

local TAB_VISIBILITY_RULES = {}
for _, key in ipairs(GROUP_ORDER) do
    local meta, tab = TAB_META[key], tabByKey[key]
    if meta and meta.members and tab then
        local keys = {}
        for _, member in ipairs(meta.members) do
            if member.db then keys[#keys + 1] = member.db end
        end
        if #keys > 0 then TAB_VISIBILITY_RULES[#TAB_VISIBILITY_RULES + 1] = { tab = tab, tabKey = key, keys = keys } end
    end
end

function ns:UpdateSideTabVisibility(prefix, currentActiveTab)
    local db = ClassCodexDB
    if not db then return currentActiveTab end
    for _, rule in ipairs(TAB_VISIBILITY_RULES) do
        local allDisabled = true
        for _, key in ipairs(rule.keys) do
            if db[prefix .. key] ~= false then
                allDisabled = false
                break
            end
        end
        if allDisabled then
            rule.tab:Hide()
            if currentActiveTab == rule.tabKey then
                currentActiveTab = "stats"
                UpdateTabAppearance()
            end
        else
            rule.tab:Show()
        end
    end
    return currentActiveTab
end

local FOOTER_RESERVE = 8

local subheaderFrame = CreateFrame("Frame", nil, panel)
subheaderFrame:SetHeight(SUBHEADER_HEIGHT)

subheaderFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", CONTENT_INSET, -27)
subheaderFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -7, -27)
subheaderFrame:SetFrameLevel(panel:GetFrameLevel() + 6)

local contentScroll = CreateFrame("Frame", "ClassCodexContentScroll", panel, "WowScrollBox")

contentScroll:SetPoint("TOPLEFT", subheaderFrame, "BOTTOMLEFT", 0, -5)
contentScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -7, FOOTER_RESERVE)

local contentScrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
contentScrollBar:SetPoint("TOPLEFT", contentScroll, "TOPRIGHT", 6, 0)
contentScrollBar:SetPoint("BOTTOMLEFT", contentScroll, "BOTTOMRIGHT", 6, 0)

local contentFrame = CreateFrame("Frame", nil, contentScroll)
contentFrame.scrollable = true
contentFrame:SetHeight(400)

local contentView = CreateScrollBoxLinearView()
contentView:SetPanExtent(60)
ScrollUtil.InitScrollBoxWithScrollBar(contentScroll, contentScrollBar, contentView)

if contentScroll.SetInterpolateScroll then contentScroll:SetInterpolateScroll(true) end
if contentScrollBar.SetInterpolateScroll then contentScrollBar:SetInterpolateScroll(true) end

contentScrollBar:SetAlpha(0)
contentScrollBar:EnableMouse(false)
contentScrollBar:SetWidth(1)
if contentScrollBar.SetMouseClickEnabled then contentScrollBar:SetMouseClickEnabled(false) end
for _, child in ipairs({ contentScrollBar:GetChildren() }) do
    if child.EnableMouse then child:EnableMouse(false) end
    if child.SetMouseClickEnabled then child:SetMouseClickEnabled(false) end
end

local panelEmptyFrame = CreateFrame("Frame", nil, panel)
panelEmptyFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", CONTENT_INSET, -28)
panelEmptyFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -7, FOOTER_RESERVE)
panelEmptyFrame:SetFrameLevel(panel:GetFrameLevel() + 10)
panelEmptyFrame:Hide()

local panelEmptyIcon = panelEmptyFrame:CreateTexture(nil, "ARTWORK")
panelEmptyIcon:SetSize(48, 48)
panelEmptyIcon:SetPoint("CENTER", panelEmptyFrame, "CENTER", 0, 42)
panelEmptyIcon:SetTexture("Interface\\AddOns\\BreadClassCodex\\Media\\icon")
panelEmptyIcon:SetAlpha(0.85)

local panelEmptyText = panelEmptyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
panelEmptyText:SetPoint("TOP", panelEmptyIcon, "BOTTOM", 0, -16)
panelEmptyText:SetJustifyH("CENTER")
panelEmptyText:SetJustifyV("TOP")
panelEmptyText:SetSpacing(4)
panelEmptyText:SetTextColor(0.75, 0.75, 0.75)

local panelEmptyLinks = {}
local panelEmptyLinksBuilt = false

local EMPTY_CLASS_ID = {
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

local function BuildEmptyLevelingLinks()
    if panelEmptyLinksBuilt then return end
    local _, classToken = UnitClass("player")
    local keys = classToken and SPEC_KEYS[classToken]
    if not keys then return end
    local classID = EMPTY_CLASS_ID[classToken]

    local items = {}
    for i, slug in ipairs(keys) do
        local url = ns.SourceLink and ns.SourceLink("icyveins", "leveling", classToken, slug)
        if url then
            local specName = slug:gsub("^%l", string.upper):gsub("%-(%l)", function(c)
                return " " .. c:upper()
            end)
            local specIcon
            if classID and GetSpecializationInfoForClassID then
                local _, n, _, ic = GetSpecializationInfoForClassID(classID, i)
                if n then specName = n end
                specIcon = ic
            end
            items[#items + 1] = { url = url, name = specName, icon = specIcon }
        end
    end
    if #items == 0 then return end

    local SIZE, GAP = 28, 18
    local total = #items * SIZE + (#items - 1) * GAP
    for i, item in ipairs(items) do
        local x = -total / 2 + (i - 1) * (SIZE + GAP) + SIZE / 2
        local btn = CreateFrame("Button", nil, panelEmptyFrame)
        btn:SetSize(SIZE, SIZE)
        btn:SetPoint("CENTER", panelEmptyText, "BOTTOM", x, -42)
        btn:RegisterForClicks("LeftButtonUp")
        btn.url = item.url

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        if item.icon then tex:SetTexture(item.icon) end
        btn.icon = tex

        local mask = btn:CreateMaskTexture()
        mask:SetAllPoints(tex)
        mask:SetTexture(
            "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE",
            "CLAMPTOBLACKADDITIVE"
        )
        tex:AddMaskTexture(mask)

        local ring = btn:CreateTexture(nil, "OVERLAY")
        ring:SetAtlas("Artifacts-PerkRing-Final")
        ring:SetPoint("CENTER", btn, "CENTER")
        ring:SetSize(SIZE * 1.4, SIZE * 1.4)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(tex)
        hl:SetColorTexture(1, 1, 1, 0.2)
        hl:AddMaskTexture(mask)

        local title = (ns.L["empty.spec_leveling"] or "%s Leveling Guide"):format(item.name)
        btn:SetScript("OnEnter", function(self)
            ns.Tooltip.Open(self, "ANCHOR_RIGHT").Head(title, "title").Line(ns.L["attribution.copy_url"], "body").Show()
        end)
        btn:SetScript("OnLeave", function()
            ns.Tooltip.Hide()
        end)
        btn:SetScript("OnClick", function(self)
            if self.url and ns.ShowCopyPopup then ns.ShowCopyPopup(self.url, self) end
        end)

        panelEmptyLinks[#panelEmptyLinks + 1] = btn
    end
    panelEmptyLinksBuilt = true
end

local function ShowPanelEmptyState(msg)
    panelEmptyText:SetText(msg)
    panelEmptyText:SetWidth(math.min((panel:GetWidth() or 320) - 48, 190))
    BuildEmptyLevelingLinks()
    panelEmptyFrame:Show()
end

local function HidePanelEmptyState()
    panelEmptyFrame:Hide()
end

local PAGE_WHEEL_STEP = 90
local FREE_WHEEL_STEP = 48
local SNAP_RESISTANCE = 2
local SNAP_COOLDOWN = 0.3
local pageTargetOffset = 0
local edgeTicks = 0
local edgeDir = 0
local lastSnapAt = 0

local function ApplyScrollOffset(off)
    local range = contentScroll:GetDerivedScrollRange() or 0
    pageTargetOffset = math.max(0, math.min(off or 0, range))
    contentScroll:SetScrollPercentage(range > 0 and pageTargetOffset / range or 0)
end

local function CurrentPageIndex()
    local pages = ns._pages
    if not pages or #pages == 0 then return 1 end
    local idx = 1
    for i, p in ipairs(pages) do
        if pageTargetOffset >= p.top - 4 then
            idx = i
        else
            break
        end
    end
    return idx
end

local function OnContentWheel(_, delta)
    local pages = ns._pages
    if not ns._pagedMode or not pages or #pages == 0 then
        ApplyScrollOffset(pageTargetOffset - delta * FREE_WHEEL_STEP)
        return
    end

    local now = GetTime and GetTime() or 0
    if now - lastSnapAt < SNAP_COOLDOWN then return end

    local V = ns._viewportH or contentScroll:GetHeight() or 1
    local idx = CurrentPageIndex()
    local p = pages[idx]
    local pageBottom = p.top + math.max(0, p.height - V)

    local function crossPage(dir, targetOffset)
        if edgeDir ~= dir then
            edgeDir = dir
            edgeTicks = 0
        end
        edgeTicks = edgeTicks + 1
        if edgeTicks >= SNAP_RESISTANCE then
            edgeTicks = 0
            lastSnapAt = now
            ApplyScrollOffset(targetOffset)
        end
    end

    local hardStops = true

    if delta < 0 then
        if pageTargetOffset < pageBottom - 2 then
            edgeTicks, edgeDir = 0, 0
            ApplyScrollOffset(math.min(pageBottom, pageTargetOffset + PAGE_WHEEL_STEP))
        elseif not hardStops and idx < #pages then
            crossPage(-1, pages[idx + 1].top)
        end
    else
        if pageTargetOffset > p.top + 2 then
            edgeTicks, edgeDir = 0, 0
            ApplyScrollOffset(math.max(p.top, pageTargetOffset - PAGE_WHEEL_STEP))
        elseif not hardStops and idx > 1 then
            local pp = pages[idx - 1]
            crossPage(1, pp.top + math.max(0, pp.height - V))
        end
    end
end

contentScroll:EnableMouseWheel(true)
contentScroll:SetScript("OnMouseWheel", OnContentWheel)

local GROUP_LINK_SURFACE = {
    stats = "stats",
    talents = "talents",
    rotation = "rotation",
    gear = "bis",
    trinkets = "trinkets",
    enhancements = "enhancements",
    crafting = "crafting",
}

local DATE_MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function RelativeDateShort(iso)
    if type(iso) ~= "string" then return nil end
    local y, m, d = iso:match("^(%d+)-(%d+)-(%d+)$")
    if not y then return iso end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    local t = date("*t")
    local today = time({ year = t.year, month = t.month, day = t.day, hour = 12 })
    local when = time({ year = y, month = m, day = d, hour = 12 })
    local days = math.floor((today - when) / 86400 + 0.5)
    if days <= 0 then return (L and L["footer.today"]) or "Today" end
    if days == 1 then return (L and L["footer.yesterday"]) or "Yesterday" end
    if days <= 6 then
        return (L and L["footer.days_ago"] and L["footer.days_ago"]:format(days)) or (days .. " days ago")
    end
    return string.format("%s %d, %d", DATE_MONTHS[m] or m, d, y)
end

function ns.AddonVersion()
    return (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")) or "?"
end

function ns.DataUpdatedText()
    return RelativeDateShort(ns.LastUpdated and ns.LastUpdated()) or "?"
end

function ns.DataUpdatedDays()
    local iso = ns.LastUpdated and ns.LastUpdated()
    if type(iso) ~= "string" then return nil end
    local y, m, d = iso:match("^(%d+)-(%d+)-(%d+)$")
    if not y then return nil end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    local t = date("*t")
    local today = time({ year = t.year, month = t.month, day = t.day, hour = 12 })
    local when = time({ year = y, month = m, day = d, hour = 12 })
    return math.floor((today - when) / 86400 + 0.5)
end

function ns.DataUpdatedColor()
    local days = ns.DataUpdatedDays()
    if days ~= nil and days >= 7 then
        return 0.95, 0.35, 0.3
    elseif days ~= nil and days >= 1 then
        return 0.98, 0.6, 0.25
    end
    return 1, 0.82, 0
end

local groupTitles = {}
ns.groupTitles = groupTitles
for _, gkey in ipairs(GROUP_ORDER) do
    local pt = ns.CreatePageTitle(contentFrame)
    pt.link = ns.CreateSourceLinkIcon(pt)
    pt.link:SetPoint("RIGHT", pt, "RIGHT", -(ns.PAGE_TITLE_HPAD or 8), 1)
    groupTitles[gkey] = pt
end
do
    local pt = ns.CreatePageTitle(contentFrame)
    pt.link = ns.CreateSourceLinkIcon(pt)
    pt.link:SetPoint("RIGHT", pt, "RIGHT", -(ns.PAGE_TITLE_HPAD or 8), 1)
    groupTitles.about = pt
end
do
    local pt = ns.CreatePageTitle(contentFrame)
    pt.link = ns.CreateSourceLinkIcon(pt)
    pt.link:SetPoint("RIGHT", pt, "RIGHT", -(ns.PAGE_TITLE_HPAD or 8), 1)
end

local function CreateOptionDropdown(name, parent, width)
    local dd = CreateFrame("DropdownButton", name, parent, "WowStyle1DropdownTemplate")
    dd:SetSize(width or 140, DROPDOWN_HEIGHT)

    dd._opts, dd._current, dd._onSelect = nil, nil, nil
    dd:SetupMenu(function(_, rootDescription)
        if not dd._opts then return end
        for _, opt in ipairs(dd._opts) do
            local label, value
            if type(opt) == "table" then
                label, value = opt.label or opt.value, opt.value
            else
                label, value = opt, opt
            end
            rootDescription:CreateRadio(label, function()
                return value == dd._current
            end, function()
                if dd._onSelect then dd._onSelect(value) end
            end)
        end
    end)

    function dd:SetOptions(opts, current, onSelect)
        self._opts, self._current, self._onSelect = opts, current, onSelect

        local fallbackLabel
        if opts and current then
            for _, opt in ipairs(opts) do
                local l, v
                if type(opt) == "table" then
                    l, v = opt.label or opt.value, opt.value
                else
                    l, v = opt, opt
                end
                if v == current then
                    fallbackLabel = l
                    break
                end
            end
        end
        if self.SetDefaultText then self:SetDefaultText(fallbackLabel or current or "") end
        if self.GenerateMenu then self:GenerateMenu() end
    end

    return dd
end

local SOURCE_BANNER_H = 30
local CONTEXT_ICON = {
    mplus = "Interface\\Icons\\Achievement_ChallengeMode_Gold",
    raid = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider",
}

local PVP_BANNER = {
    Horde = "Interface\\Icons\\Achievement_PVP_H_H",
    Alliance = "Interface\\Icons\\Achievement_PVP_A_A",
}

function ns.ContentTypeIcon(value)
    if value == "pvp" then return PVP_BANNER[UnitFactionGroup("player") or ""] or PVP_BANNER.Alliance end
    return CONTEXT_ICON[value]
end

local function CreateSourceButton(name, parent, badgeSize)
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetHeight(SOURCE_BANNER_H)

    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    btn:SetBackdropColor(0, 0, 0, 0)
    btn:SetBackdropBorderColor(1, 1, 1, 0.9)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 3, -3)
    bg:SetPoint("BOTTOMRIGHT", -3, 3)
    bg:SetColorTexture(1, 1, 1, 1)
    btn.bg = bg

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 3, -3)
    hl:SetPoint("BOTTOMRIGHT", -3, 3)
    hl:SetColorTexture(1, 1, 1, 0.10)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(badgeSize or 16, badgeSize or 16)
    icon:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btn.icon = icon

    local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    local BADGE = badgeSize or 16
    local function makeStateIcon(anchorTo, anchorPoint, dx)
        local f = CreateFrame("Frame", nil, btn)
        f:SetSize(BADGE, BADGE)
        f:SetPoint("RIGHT", anchorTo, anchorPoint, dx, 0)
        local mask = f:CreateMaskTexture()
        mask:SetAllPoints(f)
        mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(f)
        bg:SetColorTexture(0, 0, 0, 1)
        bg:AddMaskTexture(mask)
        local tex = f:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(f)
        tex:AddMaskTexture(mask)
        local border = f:CreateTexture(nil, "OVERLAY")
        border:SetAtlas("Artifacts-PerkRing-Final")
        border:SetPoint("CENTER", f, "CENTER")
        border:SetSize(BADGE * 1.4, BADGE * 1.4)
        f.icon = tex
        return f
    end

    local heroStateIcon = makeStateIcon(btn, "RIGHT", -10)
    btn.heroStateIcon = heroStateIcon
    local classIcon = makeStateIcon(heroStateIcon, "LEFT", -7)
    btn.classIcon = classIcon
    local ctxIcon = makeStateIcon(classIcon, "LEFT", -7)
    btn.ctxIcon = ctxIcon

    local classCrest = makeStateIcon(ctxIcon, "LEFT", -7)
    classCrest:Hide()
    btn.classCrest = classCrest

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", ctxIcon, "LEFT", -6, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(1, 1, 1)
    btn.text = text

    btn._ctx = nil

    function btn:SetContext(cfg)
        self._ctx = cfg
        local src = ns.SOURCES[cfg.sourceCurrent]
        if src then
            local c = src.color or { 0.3, 0.3, 0.3 }
            if self.bg.SetGradient and CreateColor then
                self.bg:SetGradient(
                    "HORIZONTAL",
                    CreateColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 1),
                    CreateColor(c[1], c[2], c[3], 1)
                )
            else
                self.bg:SetColorTexture(c[1], c[2], c[3], 1)
            end
            self.icon:SetTexture(ns.SourceTexturePath(cfg.sourceCurrent))
            self.icon:Show()
            self.text:SetText(cfg.labelOverride or src.name:upper())
        else
            self.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
            self.icon:Hide()
            self.text:SetText(cfg.labelOverride or "")
        end
        if cfg.hideStateIcons then
            self.ctxIcon:Hide()
            self.classIcon:Hide()
            self.heroStateIcon:Hide()
            self.classCrest:Hide()
            return
        end
        local ctex
        if cfg.contentCurrent == "pvp" then
            ctex = PVP_BANNER[UnitFactionGroup("player") or ""] or PVP_BANNER.Alliance
        elseif cfg.contentCurrent then
            ctex = CONTEXT_ICON[cfg.contentCurrent]
        end
        if ctex then
            self.ctxIcon.icon:SetTexture(ctex)
            self.ctxIcon:Show()
        else
            self.ctxIcon:Hide()
        end
        local hatlas = cfg.heroBadgeAtlas or (cfg.heroCurrent and HERO_TALENT_ATLAS[cfg.heroCurrent])
        if hatlas then
            self.heroStateIcon.icon:SetAtlas(hatlas)
            self.heroStateIcon:Show()
        else
            self.heroStateIcon:Hide()
        end
        if cfg.specIcon then
            self.classIcon.icon:SetTexture(cfg.specIcon)
            self.classIcon:Show()
        else
            self.classIcon:Hide()
        end
        if cfg.classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cfg.classToken] then
            local t = CLASS_ICON_TCOORDS[cfg.classToken]
            self.classCrest.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            self.classCrest.icon:SetTexCoord(t[1], t[2], t[3], t[4])
            self.classCrest:Show()
        else
            self.classCrest:Hide()
        end

        local prev, anchorFrom, dx = self, "RIGHT", -10
        for _, badge in ipairs({ self.heroStateIcon, self.classIcon, self.classCrest, self.ctxIcon }) do
            if badge:IsShown() then
                badge:ClearAllPoints()
                badge:SetPoint("RIGHT", prev, anchorFrom, dx, 0)
                prev, anchorFrom, dx = badge, "LEFT", -7
            end
        end
        self.text:ClearAllPoints()
        self.text:SetPoint("LEFT", self.icon, "RIGHT", 8, 0)
        if prev == self then
            self.text:SetPoint("RIGHT", self, "RIGHT", -10, 0)
        else
            self.text:SetPoint("RIGHT", prev, "LEFT", -6, 0)
        end
    end

    local function BuildMenuAnchor()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        x, y = x / scale, y / scale
        local screenTop = UIParent:GetTop() or 768
        if y > screenTop * 0.5 then
            -- plenty of room below the cursor: the menu drops down from it
            return AnchorUtil.CreateAnchor("TOPLEFT", UIParent, "BOTTOMLEFT", x, y), y
        end
        -- cursor in the lower half: grow upward from the cursor instead
        return AnchorUtil.CreateAnchor("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y), screenTop - y
    end

    local function ManagerMenuAvailable()
        return (
            Menu
            and Menu.GetManager
            and Menu.PopulateDescription
            and MenuUtil
            and MenuUtil.CreateRootMenuDescription
            and MenuVariants
            and MenuVariants.GetDefaultContextMenuMixin
            and AnchorUtil
        )
    end

    -- Rough per-row extents of the default menu template; used to predict whether the
    -- menu will overflow its anchor's space before opening it.
    local MENU_ROW_H = 20

    local function EstimateMenuHeight(cfg)
        if not cfg then return nil end
        -- Radios render flat in the root; class/spec/hero fold into submenus, so they
        -- contribute one button each.
        local rows = 0
        local function flat(options)
            if options and #options > 0 then rows = rows + #options + 1 end
        end
        local function folded(options)
            if options and #options > 0 then rows = rows + 2 end
        end
        flat(cfg.sourceOptions)
        flat(cfg.contentOptions)
        folded(cfg.classOptions)
        folded(cfg.specOptions)
        folded(cfg.heroOptions)
        return rows * MENU_ROW_H + 24
    end

    local function TryOpenMenuAnchored(generator, anchor, maxHeight, estimatedHeight)
        local menuMixin = btn.menuMixin or MenuVariants.GetDefaultContextMenuMixin()
        local description = MenuUtil.CreateRootMenuDescription(menuMixin)
        Menu.PopulateDescription(generator, btn, description)
        -- Only cap the menu to the space its anchor has when the content is expected to
        -- overflow it, so it scrolls (keeping its position stable) instead of growing
        -- past the screen edge and flipping over. Menus that fit keep their natural
        -- height and no scrollbar.
        local available = maxHeight - 16
        if description.SetScrollMode and available > 120 and estimatedHeight and estimatedHeight > available then
            description:SetScrollMode(available)
        end
        local menu = Menu.GetManager():OpenMenu(btn, description, anchor)
        if menu then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
        return menu
    end

    -- Open the menu through the manager with an explicit anchor so its position is
    -- deterministic: it opens at the cursor like a context menu, and class/spec picks
    -- (which must rebuild the option tree) reopen it at that same captured anchor
    -- instead of re-anchoring to the current cursor position.
    local function OpenMenuAnchored(generator, anchor, maxHeight, estimatedHeight)
        if not ManagerMenuAvailable() then return MenuUtil.CreateContextMenu(btn, generator) end
        local ok, result = pcall(TryOpenMenuAnchored, generator, anchor, maxHeight, estimatedHeight)
        if ok then return result end
        -- Surface the failure, then fall back to the stock cursor-anchored open.
        geterrorhandler()(result)
        return MenuUtil.CreateContextMenu(btn, generator)
    end

    function btn:Reopen()
        local owner = self
        C_Timer.After(0, function()
            if owner:IsVisible() then owner:OpenMenu(true) end
        end)
    end

    local function BuildGenericMenu(owner, cfg, root)
        -- Always read the live context: selection handlers rebuild it via SetContext,
        -- and MenuResponse.Refresh must show the fresh state without reopening the menu.
        local ctx = owner._ctx or cfg

        root:CreateTitle("Source")
        for _, key in ipairs(ctx.sourceOptions or {}) do
            root:CreateRadio(ns.SourceLabelText(key), function()
                return ctx.sourceCurrent == key
            end, function()
                -- Refresh re-evaluates isSelected against this captured table,
                -- so keep it in sync; SetContext installs a fresh table separately.
                ctx.sourceCurrent = key
                if ctx.onSource then ctx.onSource(key) end
                return MenuResponse.Refresh
            end)
        end

        if ctx.contentOptions and #ctx.contentOptions > 0 then
            root:CreateDivider()
            root:CreateTitle("Content")
            for _, o in ipairs(ctx.contentOptions) do
                local ctex = (o.value == "pvp")
                        and (PVP_BANNER[UnitFactionGroup("player") or ""] or PVP_BANNER.Alliance)
                    or CONTEXT_ICON[o.value]
                local label = ctex and ("|T" .. ctex .. ":16:16|t  " .. (o.label or o.value)) or (o.label or o.value)
                root:CreateRadio(label, function()
                    return ctx.contentCurrent == o.value
                end, function()
                    ctx.contentCurrent = o.value
                    if ctx.onContent then ctx.onContent(o.value) end
                    return MenuResponse.Refresh
                end)
            end
        end

        -- Class / Specialization / Hero Talent: flat titled sections, or — when the
        -- context opts in via useSubmenus (compendium) — folded into submenus whose
        -- button shows the current selection, with the name as a title inside.
        local function CurrentSelectionLabel(options, current, decorate)
            for _, o in ipairs(options or {}) do
                local label, value
                if type(o) == "table" then
                    label, value = o.label or o.value, o.value
                else
                    label, value = o, o
                end
                if value == current then return decorate and decorate(label, current) or label end
            end
            return nil
        end

        local function EmitOptionSection(root, owner, ctx, opts)
            -- opts: title, options, current, onPick, pickResponse, useSubmenus, decorate
            local options = opts.options
            if not options or #options == 0 then return end
            local function makeRadio(parent)
                for _, o in ipairs(options) do
                    local label, value
                    if type(o) == "table" then
                        label, value = o.label or o.value, o.value
                    else
                        label, value = o, o
                    end
                    if opts.decorate then label = opts.decorate(label, value) end
                    parent:CreateRadio(label, function()
                        return opts.current() == value
                    end, function()
                        if opts.onPick then opts.onPick(value) end
                        return opts.pickResponse(owner)
                    end)
                end
            end
            root:CreateDivider()
            root:CreateTitle(opts.title)
            if opts.useSubmenus then
                local currentLabel = CurrentSelectionLabel(options, opts.current(), opts.decorate)
                local sub = root:CreateButton(currentLabel or opts.title)
                makeRadio(sub)
            else
                makeRadio(root)
            end
        end

        local submenuLayout = ctx.useSubmenus == true
        local rebuildResponse = function(owner)
            owner:Reopen()
            return MenuResponse.Close
        end

        EmitOptionSection(root, owner, ctx, {
            title = CLASS,
            options = ctx.classOptions,
            current = function()
                return ctx.classCurrent
            end,
            onPick = ctx.onClass,
            pickResponse = rebuildResponse,
            useSubmenus = submenuLayout,
        })

        EmitOptionSection(root, owner, ctx, {
            title = SPECIALIZATION,
            options = ctx.specOptions,
            current = function()
                return ctx.specCurrent
            end,
            onPick = ctx.onSpec,
            pickResponse = rebuildResponse,
            useSubmenus = submenuLayout,
        })

        if ctx.heroOptions and #ctx.heroOptions > 1 then
            EmitOptionSection(root, owner, ctx, {
                title = "Hero Talent",
                options = ctx.heroOptions,
                current = function()
                    return ctx.heroCurrent
                end,
                onPick = function(v)
                    ctx.heroCurrent = v
                    if ctx.onHero then ctx.onHero(v) end
                end,
                pickResponse = function()
                    return MenuResponse.Refresh
                end,
                useSubmenus = submenuLayout,
                decorate = function(_, value)
                    local atlas = HERO_TALENT_ATLAS[value]
                    return atlas and ("|A:" .. atlas .. ":14:14|a  " .. value) or value
                end,
            })
        end
    end

    local function GenericMenuGenerator(owner, cfg)
        return function(_, root)
            BuildGenericMenu(owner, cfg, root)
        end
    end

    function btn:OpenMenu(reuseAnchor)
        local cfg = self._ctx
        if not cfg or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        local generator = cfg.menuBuilder or GenericMenuGenerator(self, cfg)
        local anchor, maxHeight
        if reuseAnchor and self._menuAnchor then
            anchor, maxHeight = self._menuAnchor, self._menuMaxHeight
        else
            local ok, a, h = pcall(BuildMenuAnchor)
            if ok then
                anchor, maxHeight = a, h
                self._menuAnchor, self._menuMaxHeight = a, h
            else
                geterrorhandler()(a)
            end
        end
        if anchor then
            OpenMenuAnchored(generator, anchor, maxHeight, EstimateMenuHeight(cfg))
        else
            MenuUtil.CreateContextMenu(self, generator)
        end
    end

    btn:SetScript("OnClick", function(self)
        self:OpenMenu()
    end)

    btn:SetScript("OnEnter", function(self)
        ns.Tooltip
            .Open(self, "ANCHOR_RIGHT")
            .Title("Context")
            .Hint("Source, content type, hero spec — click to change.")
            .Show()
    end)
    btn:SetScript("OnLeave", function()
        ns.Tooltip.Hide()
    end)

    return btn
end
ns.CreateSourceButton = CreateSourceButton

local heroDropdown = CreateOptionDropdown("ClassCodexHeroDropdown", subheaderFrame)

local contentTypeDropdown = CreateOptionDropdown("ClassCodexContentTypeDropdown", subheaderFrame)
contentTypeDropdown:Hide()

local sourceDropdown = CreateSourceButton("ClassCodexSourceButton", subheaderFrame)
sourceDropdown:Hide()

local function LayoutSubheader(showBanner)
    contentTypeDropdown:Hide()
    heroDropdown:Hide()
    sourceDropdown:ClearAllPoints()
    sourceDropdown:SetShown(showBanner)
    if showBanner then
        sourceDropdown:SetPoint("TOPLEFT", subheaderFrame, "TOPLEFT", 0, 0)
        sourceDropdown:SetPoint("TOPRIGHT", subheaderFrame, "TOPRIGHT", 0, 0)
        subheaderFrame:SetHeight(SOURCE_BANNER_H)
    else
        subheaderFrame:SetHeight(1)
    end
end

local CreateSectionHeader = ns.CreateSectionHeader
local SetCollapsed = ns.SetCollapsed

local tabTitle = CreateFrame("Frame", nil, contentFrame)
tabTitle:SetHeight(SECTION_HEADER_HEIGHT)
local tabTitleText = tabTitle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tabTitleText:SetPoint("LEFT", 2, 0)
tabTitleText:SetTextColor(1, 0.82, 0)
tabTitle:Hide()

local statInfoBtn = ns.CreateStatInfoButton(tabTitle)
statInfoBtn:SetPoint("RIGHT", -2, 0)

ns.SECTION_HEADER_HEIGHT = SECTION_HEADER_HEIGHT
ns.ROW_HEIGHT = ROW_HEIGHT
ns.CONTENT_INSET = CONTENT_INSET
ns.PANEL_PADDING = PANEL_PADDING
ns.contentFrame = contentFrame
ns.CreateSectionHeader = CreateSectionHeader
ns.SetCollapsed = SetCollapsed
ns.CreateOptionDropdown = CreateOptionDropdown
ns.GetPanelWidth = GetPanelWidth

local statSection, statHeader, statContent = ns.Sections.Stats.InitPanel({
    parent = contentFrame,
    header = CreateSectionHeader,
})

statInfoBtn:Show()
statHeader:AddHeaderWidget(statInfoBtn)

ns.MakeCollapsible(statSection, statHeader, statContent, {
    stateKey = "stats",
    refresh = function()
        ns:UpdatePanel()
    end,
})
local lastStatRowCount = 0

local _statTargetsSection = ns.Sections.Stats.InitStatTargets({ parent = contentFrame })
local statTargets = {
    section = _statTargetsSection,
    content = ns.Sections.Stats.GetStatTargetsContent(),
}

local talentSection, talentHeader, talentContent = ns.Sections.Talents.InitPanel({
    parent = contentFrame,
    header = CreateSectionHeader,
    source = function()
        return (ns.Context and ns.Context.source())
            or (ns.GetEffectiveTalentSource and ns.GetEffectiveTalentSource())
            or "ugg"
    end,
    refresh = function()
        ns:UpdatePanel()
    end,
})
ns.MakeCollapsible(talentSection, talentHeader, talentContent, {
    stateKey = "allTalents",
    refresh = function()
        ns:LayoutPanel()
    end,
})
local copyPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
copyPopup:SetSize(280, 28)
copyPopup:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
copyPopup:SetFrameStrata("DIALOG")
copyPopup:Hide()

local copyEdit = CreateFrame("EditBox", nil, copyPopup, "InputBoxTemplate")
copyEdit:SetSize(260, 18)
copyEdit:SetPoint("CENTER")
copyEdit:SetAutoFocus(true)
copyEdit:SetScript("OnEscapePressed", function()
    copyPopup:Hide()
end)
copyEdit:SetScript("OnEditFocusLost", function()
    copyPopup:Hide()
end)

local function ShowCopyPopup(text, anchor, yOffset)
    copyPopup:ClearAllPoints()
    if anchor then
        copyPopup:SetPoint("TOP", anchor, "BOTTOM", 0, yOffset or -4)
    else
        copyPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    copyEdit:SetText(text or "")
    copyPopup:Show()
    copyEdit:SetFocus()
    copyEdit:HighlightText()
    copyEdit:SetCursorPosition(0)
end
ns.ShowCopyPopup = ShowCopyPopup

local saveAsPopup, saveAsEdit, saveAsConfirm, saveAsError
local function EnsureSaveAsPopup()
    if saveAsPopup then return end
    saveAsPopup = CreateFrame("Frame", "ClassCodexSaveAsLoadoutPopup", UIParent, "BackdropTemplate")
    saveAsPopup:SetSize(320, 108)
    saveAsPopup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    saveAsPopup:SetFrameStrata("DIALOG")
    saveAsPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    saveAsPopup:EnableMouse(true)
    saveAsPopup:Hide()

    local label = saveAsPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", saveAsPopup, "TOP", 0, -10)
    label:SetText((ns.L and ns.L["talent_pane.save_as.prompt"]) or "Loadout name:")

    saveAsEdit = CreateFrame("EditBox", nil, saveAsPopup, "InputBoxTemplate")
    saveAsEdit:SetSize(260, 18)
    saveAsEdit:SetPoint("TOP", label, "BOTTOM", 0, -10)
    saveAsEdit:SetAutoFocus(true)
    saveAsEdit:SetMaxLetters(32)

    saveAsError = saveAsPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    saveAsError:SetPoint("TOPLEFT", saveAsEdit, "BOTTOMLEFT", 0, -6)
    saveAsError:SetPoint("TOPRIGHT", saveAsEdit, "BOTTOMRIGHT", 0, -6)
    saveAsError:SetJustifyH("LEFT")
    saveAsError:SetTextColor(1, 0.3, 0.3)
    saveAsError:SetText("")

    saveAsConfirm = CreateFrame("Button", nil, saveAsPopup, "UIPanelButtonTemplate")
    saveAsConfirm:SetSize(80, 22)
    saveAsConfirm:SetPoint("BOTTOMRIGHT", saveAsPopup, "BOTTOMRIGHT", -10, 8)
    saveAsConfirm:SetText((ns.L and ns.L["talent_pane.save_as.confirm"]) or "Save")

    local cancelBtn = CreateFrame("Button", nil, saveAsPopup, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 22)
    cancelBtn:SetPoint("RIGHT", saveAsConfirm, "LEFT", -6, 0)
    cancelBtn:SetText(CANCEL or "Cancel")
    cancelBtn:SetScript("OnClick", function()
        saveAsPopup:Hide()
    end)

    saveAsEdit:SetScript("OnEscapePressed", function()
        saveAsPopup:Hide()
    end)
    saveAsEdit:SetScript("OnEnterPressed", function()
        if saveAsConfirm.onConfirm then saveAsConfirm.onConfirm() end
    end)
end

function ns.ShowSaveAsLoadoutPopup(defaultName, onConfirm)
    EnsureSaveAsPopup()
    saveAsEdit:SetText(defaultName or "")
    saveAsEdit:HighlightText()
    saveAsError:SetText("")
    saveAsPopup:SetHeight(84)
    saveAsConfirm.onConfirm = function()
        local name = (saveAsEdit:GetText() or ""):match("^%s*(.-)%s*$")

        local err = onConfirm(name)
        if err then
            saveAsError:SetText(err)

            saveAsPopup:SetHeight(84 + math.ceil(saveAsError:GetStringHeight()) + 4)
            saveAsEdit:SetFocus()
            return
        end
        saveAsPopup:Hide()
    end
    saveAsConfirm:SetScript("OnClick", saveAsConfirm.onConfirm)
    saveAsPopup:Show()
    saveAsEdit:SetFocus()
end

function ns.HideSaveAsLoadoutPopup()
    if saveAsPopup then saveAsPopup:Hide() end
end

function ns.PromptAndSaveTalentBuild(exportString, defaultLabel)
    if not exportString or not ns.SaveTalentBuildAsNewLoadout then return end
    ns.ShowSaveAsLoadoutPopup(defaultLabel, function(name)
        local ok, err = ns.SaveTalentBuildAsNewLoadout(exportString, defaultLabel, name)

        if not ok then return err or "Failed to save loadout" end
    end)
end

function ns:UpdateAllTalents(_, classToken, specKey)
    local source = (ns.Context and ns.Context.source())
        or (ns.GetEffectiveTalentSource and ns.GetEffectiveTalentSource())
        or "ugg"
    ns.Sections.Talents.RenderPanel({
        class = classToken,
        spec = specKey,
        source = source,
        specIcon = GetSpecIcon(),
        onCopy = function(export, card)
            ShowCopyPopup(export, card)
        end,
    })
    talentContent._active = true
end

local rotationSection, rotationHeader, rotationContent = ns.Sections.Rotation.InitPanel({
    parent = contentFrame,
    header = CreateSectionHeader,
})
ns.MakeCollapsible(rotationSection, rotationHeader, rotationContent, {
    stateKey = "rotation",
    refresh = function()
        ns:LayoutPanel()
    end,
})
local pvpEmptySection, pvpEmptyHeader, pvpEmptyContent = ns.Sections.PvpEmpty.InitPanel({
    parent = contentFrame,
    header = CreateSectionHeader,
})
ns.MakeCollapsible(pvpEmptySection, pvpEmptyHeader, pvpEmptyContent, {
    stateKey = "pvpEmpty",
    refresh = function()
        ns:LayoutPanel()
    end,
})
local lastPvpEmptyHeight = 0
local currentRotationContext = nil
local lastRotationContentHeight = 0

local omniumSection, omniumHeader, omniumContent = ns.Sections.Omnium.InitPanel({
    parent = contentFrame,
    header = CreateSectionHeader,
})
ns.MakeCollapsible(omniumSection, omniumHeader, omniumContent, {
    stateKey = "omnium",
    refresh = function()
        ns:LayoutPanel()
    end,
})
local lastOmniumContentHeight = 0

ns.OnOmniumFolioChanged = function()
    if panel and panel:IsShown() then ns:UpdatePanel() end
end

function ns:ScrollToTab(tabKey)
    C_Timer.After(0, function()
        local offset = ns._tabAnchorY and ns._tabAnchorY[tabKey]
        if not offset then return end
        ApplyScrollOffset(offset)
    end)
end

local function TabAnchorOffset(tabKey)
    return ns._tabAnchorY and ns._tabAnchorY[tabKey] or nil
end

local function SyncActiveTabToScroll()
    if ns._suppressTabSync then return end
    local scroll = contentScroll:GetDerivedScrollOffset() or 0
    local scanOrder = ns.GetSectionOrder()
    local best, bestOff
    for _, k in ipairs(scanOrder) do
        local off = TabAnchorOffset(k)

        if off and off <= scroll + 8 and (not bestOff or off >= bestOff) then
            best, bestOff = k, off
        end
    end

    if not best then
        for _, k in ipairs(scanOrder) do
            if TabAnchorOffset(k) then
                best = k
                break
            end
        end
    end
    if best and best ~= activeTab then
        activeTab = best
        if ClassCodexCharDB then ClassCodexCharDB.activeTab = activeTab end
        UpdateTabAppearance()
    end
end

contentScroll:RegisterCallback("OnScroll", function()
    SyncActiveTabToScroll()
end, contentScroll)

ns.panel = panel
ns.GetClassAndSpec = GetClassAndSpec
ns.GetSpecKey = GetSpecKey
ns.GetSpecData = GetSpecData
ns.GetPerSpecState = GetPerSpecState
ns.GetActiveHeroTalentName = GetActiveHeroTalentName
ns.isFloating = function()
    return isFloating
end
ns.getActiveTab = function()
    return activeTab
end
ns.setActiveTab = function(tab)
    activeTab = tab
    UpdateTabAppearance()
end
ns.HERO_TALENT_ATLAS = HERO_TALENT_ATLAS
ns.SPEC_KEYS = SPEC_KEYS

local CONTENT_TYPE_LABELS = { mplus = "Mythic+", raid = "Raid", pvp = "PvP" }
local CONTENT_TYPE_ORDER = { mplus = 1, raid = 2, pvp = 3 }
local function GetGenericContentOptions()
    local seen = {}
    for _, ct in ipairs(ns.QueryContentTypes and ns.QueryContentTypes("gear") or {}) do
        local top = ct:sub(1, 4) == "pvp:" and "pvp" or ct
        if CONTENT_TYPE_LABELS[top] then seen[top] = true end
    end
    local out = {}
    for top in pairs(seen) do
        out[#out + 1] = { value = top, label = CONTENT_TYPE_LABELS[top], order = CONTENT_TYPE_ORDER[top] }
    end
    table.sort(out, function(a, b)
        return a.order < b.order
    end)
    return out
end
ns.GetGenericContentOptions = GetGenericContentOptions

local currentHeroTalent = nil
ns.GetActiveHero = function()
    return currentHeroTalent
end

ns.Context.OnChange(function()
    ns:UpdatePanel()
end)

local cachedRanks = nil
local cachedRanksHero = nil
local cachedRanksCtx = nil
local cachedBreakpoints = nil

function ns:UpdatePanel()
    cachedRanks = nil
    cachedBreakpoints = nil
    local specData, classToken, specKey = GetSpecData()
    if not specData then
        ns:LayoutPanel()
        return
    end

    local panelWidth = GetPanelWidth()
    panel:SetWidth(panelWidth)

    local heroOptions = GetSpecHeroTalents()
    if #heroOptions < 2 then heroOptions = GetHeroTalentOptions(specData) end
    local showHero = #heroOptions > 1

    local pinnedHero = ns.Context.heroSpec()
    if pinnedHero then
        currentHeroTalent = pinnedHero
    else
        local detected = GetActiveHeroTalentName()
        if detected then
            local matched = false
            for _, opt in ipairs(heroOptions) do
                if opt:lower() == detected:lower() then
                    currentHeroTalent = opt
                    matched = true
                    break
                end
            end
            if not matched then currentHeroTalent = heroOptions[1] or "All" end
        else
            currentHeroTalent = heroOptions[1] or "All"
        end
    end

    if panel.SetTitle then panel:SetTitle("Bread Codex") end

    local contentOpts = GetGenericContentOptions()
    local sourceKeys = ns.QuerySources("gear", classToken, specKey) or {}
    local showBanner = #sourceKeys > 0 or #contentOpts > 0 or showHero

    if #contentOpts > 0 then
        local ct, ok = ns.Context.contentType(), false
        for _, o in ipairs(contentOpts) do
            if o.value == ct then
                ok = true
                break
            end
        end
        if not ok then ns.Context.set("contentType", contentOpts[1].value, true) end
    end
    if #sourceKeys > 0 then
        local cs, ok = ns.Context.source(), false
        for _, s in ipairs(sourceKeys) do
            if s == cs then
                ok = true
                break
            end
        end
        if not ok then ns.Context.set("source", sourceKeys[1], true) end
    end
    LayoutSubheader(showBanner)
    subheaderFrame._wantShown = showBanner
    subheaderFrame:SetShown(showBanner)
    if showBanner then
        if panel.SetTitle then panel:SetTitle("Bread Codex") end
        local cc = ns.Context.contentType()
        if type(cc) == "string" and cc:sub(1, 4) == "pvp:" then cc = "pvp" end
        local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
            or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
            or "?"
        sourceDropdown:SetContext({
            sourceCurrent = ns.Context.source(),
            sourceOptions = sourceKeys,
            onSource = function(k)
                ns.Context.set("source", k)
            end,
            contentCurrent = cc,
            contentOptions = contentOpts,
            onContent = function(v)
                ns.Context.set("contentType", v)
            end,
            heroCurrent = currentHeroTalent,
            heroOptions = showHero and heroOptions or nil,
            onHero = function(h)
                ns.Context.set("heroSpec", h)
            end,
            specIcon = GetSpecIcon(),
            version = ver,
            lastUpdated = ns.LastUpdated(),
        })
    end

    local pvpNoGuide = false
    if ns.Context.contentType() == "pvp" and ns.HasPvpGuide then
        local pvpEmptySource = (ns.ActiveSource and ns.ActiveSource()) or "icyveins"
        pvpNoGuide = not ns.HasPvpGuide(pvpEmptySource, classToken, specKey)
    end
    lastPvpEmptyHeight = ns.Sections.PvpEmpty.RenderPanel({ shown = pvpNoGuide })

    local priorityHero = (currentHeroTalent and ns.HeroSlugFromDisplay and ns.HeroSlugFromDisplay(currentHeroTalent))
        or nil
    local priorityStats = ns.GetStatPriority
        and ns.GetStatPriority(classToken, specKey, ns.Context.contentType(), nil, priorityHero)
    lastStatRowCount = ns.Sections.Stats.RenderPanel({
        contextOptions = {},
        priorityStats = priorityStats,
        rankColors = RANK_COLORS,
    })

    local rotWantPvp = ns.Context.contentType() == "pvp"
    local rotCtxOptions = {}
    for _, c in ipairs(GetRotationContextOptions(specData, currentHeroTalent)) do
        local isPvp = type(c) == "string" and c:lower():find("pvp", 1, true) ~= nil
        if isPvp == rotWantPvp then rotCtxOptions[#rotCtxOptions + 1] = c end
    end
    -- Specs whose PvP guide has no rotation page: show the PvE rotation rather
    -- than an empty panel. Specs without a PvP guide at all get the PvP empty
    -- screen instead.
    if #rotCtxOptions == 0 and not pvpNoGuide then
        for _, c in ipairs(GetRotationContextOptions(specData, currentHeroTalent)) do
            local isPvp = type(c) == "string" and c:lower():find("pvp", 1, true) ~= nil
            if isPvp ~= rotWantPvp then rotCtxOptions[#rotCtxOptions + 1] = c end
        end
    end
    local perSpecRot = GetPerSpecState()
    if perSpecRot and perSpecRot.rotationContext then
        local found = false
        for _, c in ipairs(rotCtxOptions) do
            if c == perSpecRot.rotationContext then
                found = true
                break
            end
        end
        currentRotationContext = found and perSpecRot.rotationContext or (rotCtxOptions[1] or "General")
    else
        currentRotationContext = rotCtxOptions[1] or "General"
    end

    local rotation = FindRotationByContext(specData.rotation, currentHeroTalent, currentRotationContext)
    lastRotationContentHeight = ns.Sections.Rotation.RenderPanel({
        contextOptions = rotCtxOptions,
        currentContext = currentRotationContext,
        rotation = rotation,
        heroTalent = currentHeroTalent,
        hasAnyRotation = specData.rotation and #specData.rotation > 0,
        textAreaWidth = GetPanelWidth() - CONTENT_INSET * 2 - 42,
        helpers = {
            shouldShow = ShouldShowStep,
            strip = StripConditionPrefix,
            getIcon = GetStepSpellIcon,
            format = FormatRotationStep,
        },
        onCtxChange = function(picked)
            local ps = GetPerSpecState()
            if not ps then return end
            ps.rotationContext = picked
            ns:UpdatePanel()
        end,
    })

    local omniumSource = ns.ActiveSource and ns.ActiveSource() or "icyveins"
    local omniumSd = ns.SourceSpec and ns.SourceSpec(omniumSource, classToken, specKey)
    -- The PvP pages pick their own runes; fall back to the PvE set (specs
    -- without a PvP guide still have the shared folio).
    local omniumRunes = omniumSd
        and omniumSd.omniumFolio
        and ns.ResolveCategory(omniumSd.omniumFolio, "all", ns.Context.contentType())
    if not omniumRunes and omniumSd and omniumSd.omniumFolio then
        omniumRunes = ns.ResolveCategory(omniumSd.omniumFolio, "all", "all")
    end
    -- u.gg has no folio data — borrow Icy Veins' (the section badges it).
    if not omniumRunes and omniumSource ~= "icyveins" then
        local ivSd = ns.SourceSpec and ns.SourceSpec("icyveins", classToken, specKey)
        local ivRunes = ivSd
            and ivSd.omniumFolio
            and ns.ResolveCategory(ivSd.omniumFolio, "all", ns.Context.contentType())
        if not ivRunes and ivSd and ivSd.omniumFolio then
            ivRunes = ns.ResolveCategory(ivSd.omniumFolio, "all", "all")
        end
        if ivRunes then omniumRunes = ivRunes end
    end
    lastOmniumContentHeight = ns.Sections.Omnium.RenderPanel({
        runes = omniumRunes,
        source = omniumSource,
    })
    if lastOmniumContentHeight > 0 then
        omniumSection:Show()
    else
        omniumSection:Hide()
    end

    ns:UpdateAllTalents(specData, classToken, specKey)

    if ns.UpdateGearingSections then ns:UpdateGearingSections() end

    if (lastRotationContentHeight or 0) > 0 and not pvpNoGuide then
        rotationSection:Show()
    else
        rotationSection:Hide()
    end

    local statRowCount = ns.Sections.Stats.RenderStatTargets({
        classToken = classToken,
        specKey = specKey,
        heroTalent = currentHeroTalent,
        refresh = function()
            ns:UpdatePanel()
        end,
    })

    local havePriority = (lastStatRowCount or 0) > 0
    local haveTargets = statRowCount > 0
    local statCollapsed = statSection.IsCollapsed and statSection.IsCollapsed() or false
    statSection:SetShown(havePriority)
    if statContent then statContent:SetShown(havePriority and not statCollapsed) end
    statHeader.label:SetText(L["section.stat_priority"] or "Stat Priority")
    statTargets.section:SetShown(havePriority and haveTargets and not statCollapsed)

    if ClassCodexDB then
        local prefix = isFloating and "floatShow" or "dockShow"
        if not ClassCodexDB[prefix .. "Stats"] then statSection:Hide() end
        if not ClassCodexDB[prefix .. "Talents"] then
            talentSection:Hide()
            talentContent._active = false
        end
        if not ClassCodexDB[prefix .. "Rotation"] then rotationSection:Hide() end
        if not ClassCodexDB[prefix .. "Omnium"] then omniumSection:Hide() end
        if not ClassCodexDB[prefix .. "Stats"] then statTargets.section:Hide() end
        activeTab = ns:UpdateSideTabVisibility(prefix, activeTab)
    end

    ns:LayoutPanel()
end

function ns.SetContentHeight(content, h)
    if not content then return end
    h = math.max(h or 0, 0)
    content._stackHeight = h
    content:SetHeight(math.max(h, 1))
end

function ns.StackSection(section, content, collapsed, y, parent)
    if not section or not section:IsShown() then return y end

    local hideHeader = section._hideHeader == true
    if section.header then
        if section.header.SetShown then section.header:SetShown(not hideHeader) end
        if content then ns.SetCollapsed(content, section.header, collapsed) end
    end
    parent = parent or ns.contentFrame
    section:ClearAllPoints()
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    section:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    local headerH = hideHeader and 0 or SECTION_HEADER_HEIGHT
    local topPad = hideHeader and 0 or SECTION_CONTENT_PAD
    local h = headerH
    if not collapsed and content then
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -headerH - topPad)
        content:SetPoint("RIGHT", section, "RIGHT", 0, 0)
        local ch = content._stackHeight or content:GetHeight() or 0
        h = h + topPad + math.max(0, ch) + SECTION_CONTENT_PAD
    end
    section:SetHeight(math.max(h, 1))

    return y - h - (collapsed and 2 or SECTION_GAP)
end

function ns:LayoutPanel()
    local y = 0

    local prevAnchor = ns._tabAnchorY

    tabTitle:Hide()

    local enhF = ns.Sections.Enhancements.GetPanelFrames()
    local tF = ns.Sections.Trinkets.GetPanelFrames()
    local cF = ns.Sections.Crafting.GetPanelFrames()
    local gF = ns.Sections.Gear.GetPanelFrames()

    ns._tabAnchorY = {}
    ns._pages = {}

    local _, titleClassToken = GetSpecData()
    local titleSpecKey = GetSpecKey()
    for _, pt in pairs(groupTitles) do
        pt:Hide()
    end

    local function placeTitle(groupKey)
        local pt = groupTitles[groupKey]
        if not pt then return end
        pt:ClearAllPoints()
        pt:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, y)
        pt:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
        local meta = TAB_META[groupKey]
        pt:SetTitle((groupKey == "about" and L["about.header"]) or (meta and L[meta.loc]) or "")
        local surface = GROUP_LINK_SURFACE[groupKey]
        if groupKey == "about" then
            pt.link:SetLink(ns.WEBSITE_URL, L["about.website_page"])
        elseif surface and ns.ResolveAttribution then
            pt.link:SetSource(ns.ResolveAttribution(surface, titleClassToken, titleSpecKey))
        else
            pt.link:SetSource(nil)
        end
        pt:Show()
        y = y - ns.PAGE_TITLE_HEIGHT
    end

    local function placeDropdownAbove(dd)
        if dd and dd:IsShown() then
            dd:ClearAllPoints()
            dd:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", CONTENT_INSET, y)
            dd:SetPoint("RIGHT", contentFrame, "RIGHT", -CONTENT_INSET, 0)
            y = y - 30
        end
    end

    local function placePvpEmpty()
        if (lastPvpEmptyHeight or 0) <= 0 then return end
        ns.SetContentHeight(pvpEmptyContent, lastPvpEmptyHeight)
        y = ns.StackSection(pvpEmptySection, pvpEmptyContent, pvpEmptySection.IsCollapsed(), y)
    end

    local sectionPlacers = {
        omnium = function()
            ns.SetContentHeight(omniumContent, lastOmniumContentHeight)
            y = ns.StackSection(omniumSection, omniumContent, omniumSection.IsCollapsed(), y)
        end,
        stats = function()
            placePvpEmpty()
            ns.SetContentHeight(statContent, ns.Sections.Stats.GetPanelContentHeight(lastStatRowCount))
            y = ns.StackSection(statSection, statContent, statSection.IsCollapsed(), y)
            if statTargets.section:IsShown() then
                local th = ns.Sections.Stats.GetStatTargetsHeight()
                statTargets.section:ClearAllPoints()
                statTargets.section:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, y)
                statTargets.section:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
                statTargets.section:SetHeight(th)
                y = y - th - SECTION_GAP
            end
            y = ns.StackSection(talentSection, talentContent, true, y)
        end,
        talents = function()
            talentSection:SetShown(talentContent._active == true)
            y = ns.StackSection(talentSection, talentContent, talentSection.IsCollapsed(), y)
        end,
        rotation = function()
            placePvpEmpty()
            local h = lastRotationContentHeight
            ns.SetContentHeight(rotationContent, h)
            y = ns.StackSection(rotationSection, rotationContent, rotationSection.IsCollapsed(), y)
        end,
        bis = function()
            y = ns.StackSection(gF.section, gF.content, gF.collapsed, y)
        end,
        trinkets = function()
            placePvpEmpty()
            y = ns.StackSection(tF.section, tF.content, tF.collapsed, y)
        end,
        enchants = function()
            placePvpEmpty()
            placeDropdownAbove(enhF.sourceDropdown)
            y = ns.StackSection(enhF.enchSection, enhF.enchContent, enhF.enchCollapsed, y)
        end,
        gems = function()
            y = ns.StackSection(enhF.gemSection, enhF.gemContent, enhF.gemCollapsed, y)
        end,
        consumables = function()
            y = ns.StackSection(enhF.consumSection, enhF.consumContent, enhF.consumCollapsed, y)
        end,
        crafting = function()
            placePvpEmpty()
            placeDropdownAbove(cF.ctxDropdown)
            y = ns.StackSection(cF.craftsSection, cF.craftsContent, cF.craftsCollapsed, y)
        end,
        embellishments = function()
            y = ns.StackSection(cF.embsSection, cF.embsContent, cF.embsCollapsed, y)
        end,
        about = function()
            if ns.settingsSection and ns.settingsContent then
                if ns.RefreshSettingsView then ns.RefreshSettingsView() end
                y = ns.StackSection(ns.settingsSection, ns.settingsContent, false, y)
            end
        end,
    }

    local memberSection = {
        stats = statSection,
        talents = talentSection,
        omnium = omniumSection,
        rotation = rotationSection,
        bis = gF.section,
        trinkets = tF.section,
        enchants = enhF.enchSection,
        gems = enhF.gemSection,
        consumables = enhF.consumSection,
        crafting = cF.craftsSection,
        embellishments = cF.embsSection,
        about = ns.settingsSection,
    }

    local function placeGroup(groupKey)
        local meta = TAB_META[groupKey]
        if not meta or not meta.members then return end

        local visibleCount, soleSection = 0, nil
        for _, member in ipairs(meta.members) do
            local sec = memberSection[member.sec]
            if sec and sec:IsShown() then
                visibleCount = visibleCount + 1
                soleSection = sec
            end
        end
        for _, member in ipairs(meta.members) do
            local sec = memberSection[member.sec]
            if sec then
                local hasWidgets = sec.header and sec.header._widgets and #sec.header._widgets > 0
                sec._hideHeader = (not sec._keepHeader and visibleCount == 1 and sec == soleSection and not hasWidgets)
                    or nil
            end
        end

        local seenHeader = false
        for _, member in ipairs(meta.members) do
            local sec = memberSection[member.sec]
            if sec and sec:IsShown() then
                if sec.header and sec.header.topDivider then
                    sec.header.topDivider:SetShown(seenHeader and not sec._hideHeader)
                end
                if not sec._hideHeader then seenHeader = true end
            end
        end

        for _, member in ipairs(meta.members) do
            local place = sectionPlacers[member.sec]
            if place then place() end
        end
    end

    local minPanelHeight = 40 + #sideTabs * (SIDE_TAB_H + SIDE_TAB_GAP) + 10
    local charHeight = (not isFloating and CharacterFrame and CharacterFrame:IsShown()) and CharacterFrame:GetHeight()
        or nil
    local screenMax = math.floor((UIParent:GetHeight() or 900) * 0.9)
    local paged = true

    local emptyPanel = (GetSpecData() == nil)
    if emptyPanel and panel.SetTitle then panel:SetTitle("Bread Codex") end

    if isMinimized then
        HidePanelEmptyState()
        contentFrame:Hide()
        contentScroll:Hide()
        contentScrollBar:Hide()
        if panel.Inset then panel.Inset:Hide() end
        panel:SetHeight(27 + SOURCE_BANNER_H + 6)
        for _, tab in ipairs(allTabs) do
            tab:Hide()
        end
        ns._pagedMode = false
        return
    end

    if panel.Inset then panel.Inset:Show() end
    contentScroll:Show()
    subheaderFrame:SetShown(not emptyPanel and subheaderFrame._wantShown ~= false)
    for _, tab in ipairs(bottomTabs) do
        tab:Show()
    end
    for _, tab in ipairs(sideTabs) do
        tab:Show()
    end
    if ClassCodexDB then
        local prefix = isFloating and "floatShow" or "dockShow"
        activeTab = ns:UpdateSideTabVisibility(prefix, activeTab)
    end

    local prevTab = nil
    for _, tab in ipairs(sideTabs) do
        if tab:IsShown() and tab.tabKey ~= "about" then
            tab:ClearAllPoints()
            if prevTab then
                tab:SetPoint("TOPLEFT", prevTab, "BOTTOMLEFT", 0, -SIDE_TAB_GAP)
            else
                tab:SetPoint("TOPLEFT", panel, "TOPRIGHT", SIDE_TAB_ANCHOR_X, -40)
            end
            prevTab = tab
        end
    end
    if tabByKey.about and tabByKey.about:IsShown() then
        tabByKey.about:ClearAllPoints()
        tabByKey.about:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", SIDE_TAB_ANCHOR_X, 13)
    end

    if emptyPanel and activeTab ~= "about" then
        contentScroll:Hide()
        contentScrollBar:Hide()
        contentFrame:Hide()
        ShowPanelEmptyState(GetSpecKey() and L["empty.no_data"] or L["empty.no_spec"])
        panel:SetHeight(charHeight or minPanelHeight)
        ns._pagedMode = false
        ns._tabAnchorY = {}
        return
    end
    HidePanelEmptyState()

    local pageOrder = ns.GetSectionOrder()
    if emptyPanel then
        for k, sec in pairs(memberSection) do
            if k ~= "about" and sec then sec:Hide() end
        end
        pageOrder = { "about" }
    end
    local contentHeight

    if paged then
        local panelHeight
        if isFloating then
            panelHeight = math.max(minPanelHeight, math.min(GetFloatPanelHeight(), screenMax))
        else
            panelHeight = charHeight or minPanelHeight
        end
        panel:SetHeight(panelHeight)

        local subH = (subheaderFrame._wantShown ~= false) and SUBHEADER_HEIGHT or 1
        local V = math.max(40, panelHeight - (27 + subH + 5) - FOOTER_RESERVE)
        ns._viewportH = V

        local naturalH = {}
        for _, key in ipairs(pageOrder) do
            local startY = y
            placeGroup(key)
            naturalH[key] = startY - y
        end

        y = 0
        for _, key in ipairs(pageOrder) do
            local nat = naturalH[key] or 0
            if nat > 1 then
                local total = nat + ns.PAGE_TITLE_HEIGHT + PAGE_TITLE_GAP
                local pageTop = -y
                local pageHeight = math.max(V, total)
                placeTitle(key)
                y = y - PAGE_TITLE_GAP
                placeGroup(key)
                ns._tabAnchorY[key] = pageTop
                ns._pages[#ns._pages + 1] = { key = key, top = pageTop, height = pageHeight }
                y = -(pageTop + pageHeight)
            end
        end
        contentHeight = math.max(-y, 1)
        ns._pagedMode = true
    end

    local targetTab = activeTab
    ns._suppressTabSync = true
    contentFrame:Show()
    contentFrame:SetHeight(contentHeight)
    if contentScroll.FullUpdate then contentScroll:FullUpdate(ScrollBoxConstants.UpdateQueued) end

    C_Timer.After(0, function()
        local range = contentScroll:GetDerivedScrollRange() or 0
        local top = ns._tabAnchorY and ns._tabAnchorY[targetTab]
        if top then
            local within = false
            for _, p in ipairs(ns._pages or {}) do
                if p.key == targetTab then
                    within = pageTargetOffset >= p.top - 4 and pageTargetOffset <= p.top + (p.height or 0)
                    break
                end
            end
            -- Preserve the scroll position RELATIVE to the tab's top: if the reflow
            -- shifted the page, keep the same distance into the tab (so sitting at the
            -- top stays pinned to the top instead of drifting a few pixels off). Only
            -- when genuinely scrolled into the tab; otherwise snap to the new top.
            local prevTop = prevAnchor and prevAnchor[targetTab]
            local target = top
            if within and prevTop then
                local rel = pageTargetOffset - prevTop
                if rel > 1 then target = top + rel end
            end
            ApplyScrollOffset(math.min(math.max(0, target), range))
            activeTab = targetTab
        elseif pageTargetOffset > range then
            ApplyScrollOffset(range)
        end
        ns._suppressTabSync = false
    end)

    if ns.RefreshSettingsView then ns.RefreshSettingsView() end
end

local function GetActiveDockHost()
    for _, host in ipairs(dockHosts) do
        local frame = host.frame
        if frame and frame.IsShown and frame:IsShown() then return host end
    end
end

local function AnchorDockedPanel()
    if isFloating then return end
    local host = GetActiveDockHost()
    if not host then return end
    panel:ClearAllPoints()
    panel:SetPoint(host.point, host.frame, host.relativePoint, host.xOffset, host.yOffset)
end

local SLIDE_DURATION = 0.26

local function SlideInDocked()
    local host = not isFloating and GetActiveDockHost()
    if not host then
        FadeIn(panel)
        return
    end

    local ag = panel.slideAnim
    if not ag then
        ag = panel:CreateAnimationGroup()
        ag.move = ag:CreateAnimation("Translation")
        ag.move:SetSmoothing("OUT")
        ag.move:SetOrder(1)
        ag.fade = ag:CreateAnimation("Alpha")
        ag.fade:SetFromAlpha(0)
        ag.fade:SetToAlpha(1)
        ag.fade:SetOrder(1)
        ag:SetScript("OnFinished", function()
            panel:SetAlpha(1)
            panel:SetFrameStrata("DIALOG")
            AnchorDockedPanel()
        end)
        panel.slideAnim = ag
    end
    ag:Stop()

    local dx = math.max(120, panel:GetWidth() or 320)
    panel:ClearAllPoints()
    panel:SetPoint(host.point, host.frame, host.relativePoint, host.xOffset - dx, host.yOffset)
    panel:SetFrameStrata("LOW")
    panel:SetAlpha(0)
    panel:Show()

    ag.move:SetOffset(dx, 0)
    ag.move:SetDuration(SLIDE_DURATION)
    ag.fade:SetDuration(SLIDE_DURATION)
    ag:Play()
end

local function DockPanel()
    isFloating = false

    if isMinimized then
        isMinimized = false
        minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
    end
    minimizeBtn:Hide()
    panel:SetMovable(false)
    local host = GetActiveDockHost()
    panel:SetParent((host and host.parent) or CharacterFrame)
    AnchorDockedPanel()
    panel:SetFrameStrata("DIALOG")
    if ClassCodexCharDB then ClassCodexCharDB.floating = false end
end

local function FloatPanel()
    isFloating = true
    panel:SetParent(UIParent)
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    if ClassCodexCharDB and ClassCodexCharDB.floatX and ClassCodexCharDB.floatY then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ClassCodexCharDB.floatX, ClassCodexCharDB.floatY)
    else
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if ClassCodexCharDB then ClassCodexCharDB.floating = true end
    minimizeBtn:Show()

    if ClassCodexCharDB and ClassCodexCharDB.minimized then
        isMinimized = true
        minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up")
    end
end

function ns.SetFloating(on)
    if on then
        FloatPanel()
    else
        DockPanel()
    end
    if panel:IsShown() then ns:UpdatePanel() end
end

function ns.RegisterDockHost(frame, opts)
    if type(frame) ~= "table" then return end
    opts = opts or {}
    local host
    for _, h in ipairs(dockHosts) do
        if h.frame == frame then
            host = h
            break
        end
    end
    local isNew = not host
    host = host or { frame = frame }
    host.parent = opts.parent or frame
    host.point = opts.point or "TOPLEFT"
    host.relativePoint = opts.relativePoint or "TOPRIGHT"
    host.xOffset = opts.xOffset or -2
    host.yOffset = opts.yOffset or 0
    host.priority = opts.priority or 0
    if isNew then
        table.insert(dockHosts, host)
        if ns.InstallHostHooks then ns.InstallHostHooks(host) end
    end
    table.sort(dockHosts, function(a, b)
        return a.priority > b.priority
    end)
    if not isFloating and panel and panel:IsShown() then DockPanel() end
end

function ns.UnregisterDockHost(frame)
    for i, h in ipairs(dockHosts) do
        if h.frame == frame then
            table.remove(dockHosts, i)
            if not isFloating and panel and panel:IsShown() then DockPanel() end
            return
        end
    end
end

function ns.RefreshDock()
    if not isFloating and panel and panel:IsShown() then
        AnchorDockedPanel()
        ns:LayoutPanel()
    end
end

ns.RegisterDockHost(PaperDollFrame, { priority = 10, parent = CharacterFrame, xOffset = -5, yOffset = 0 })
ns.RegisterDockHost(CharacterFrame, { priority = 0, parent = CharacterFrame, xOffset = -5, yOffset = -1 })

_G.ClassCodex = _G.ClassCodex or {}
_G.ClassCodex.RegisterDockHost = ns.RegisterDockHost
_G.ClassCodex.UnregisterDockHost = ns.UnregisterDockHost
_G.ClassCodex.RefreshDock = ns.RefreshDock

local function SectionVisibilityOptions()
    local prefix = isFloating and "float" or "dock"

    local options = {}
    for _, key in ipairs(ns.GetSectionOrder()) do
        local meta = TAB_META[key]
        if meta and meta.members then
            for _, member in ipairs(meta.members) do
                if member.db and member.loc then
                    options[#options + 1] = { key = prefix .. "Show" .. member.db, label = L[member.loc] }
                end
            end
        end
    end
    return options
end

local function TabVisibilityOptions()
    local prefix = isFloating and "float" or "dock"
    local options = {}
    for _, key in ipairs(ns.GetSectionOrder()) do
        if key ~= "about" then
            local meta = TAB_META[key]
            if meta and meta.members and meta.loc then
                local keys = {}
                for _, member in ipairs(meta.members) do
                    if member.db then keys[#keys + 1] = prefix .. "Show" .. member.db end
                end
                if #keys > 0 then options[#options + 1] = { keys = keys, label = L[meta.loc] } end
                if key == "talents" then
                    options[#options + 1] = { keys = { prefix .. "ShowOmnium" }, label = L["section.omnium"] }
                end
            end
        end
    end
    return options
end
ns.TabVisibilityOptions = TabVisibilityOptions

function ns.IsTabShown(keys)
    if not ClassCodexDB then return true end
    for _, k in ipairs(keys) do
        if ClassCodexDB[k] ~= false then return true end
    end
    return false
end

function ns.SetTabShown(keys, shown)
    if not ClassCodexDB then return end
    for _, k in ipairs(keys) do
        ClassCodexDB[k] = shown and nil or false
    end
end

local WIDTH_PRESETS = {
    { key = "narrow", value = 280 },
    { key = "default", value = PANEL_WIDTH },
    { key = "wide", value = 380 },
    { key = "extra_wide", value = 460 },
}

minimizeBtn:SetScript("OnClick", function()
    isMinimized = not isMinimized
    if ClassCodexCharDB then ClassCodexCharDB.minimized = isMinimized end
    minimizeBtn:SetNormalTexture(
        isMinimized and "Interface\\Buttons\\UI-Panel-ExpandButton-Up"
            or "Interface\\Buttons\\UI-Panel-CollapseButton-Up"
    )
    ns:LayoutPanel()
end)

ns.ToggleFloat = function()
    if isFloating then
        DockPanel()
    else
        FloatPanel()
    end
end
ns.WIDTH_PRESETS = WIDTH_PRESETS
ns.SectionVisibilityOptions = SectionVisibilityOptions
if ns.BuildSettingsPage then ns.BuildSettingsPage() end

local widgetContainer, widgetBtn, widgetIcon

local function ApplyWidgetPosition()
    if not widgetContainer or not ClassCodexDB then return end
    local host = GetActiveDockHost()
    local anchor = (host and host.frame) or PaperDollFrame
    local x = ClassCodexDB.widgetOffsetX or WIDGET_DEFAULT_OFFSET_X
    local y = ClassCodexDB.widgetOffsetY or WIDGET_DEFAULT_OFFSET_Y
    if widgetContainer:GetParent() ~= anchor then widgetContainer:SetParent(anchor) end
    widgetContainer:ClearAllPoints()
    widgetContainer:SetPoint("CENTER", anchor, "TOPRIGHT", x, y)
    if not isFloating and panel and panel:IsShown() then AnchorDockedPanel() end
end
ns.ApplyWidgetPosition = ApplyWidgetPosition

local function RefreshWidgetTooltip()
    if not widgetBtn or not GameTooltip:IsOwned(widgetBtn) then return end
    widgetBtn:GetScript("OnEnter")(widgetBtn)
end
ns.RefreshWidgetTooltip = RefreshWidgetTooltip

local function SetupWidgetButton()
    if widgetContainer then return end

    widgetContainer = CreateFrame("Frame", nil, PaperDollFrame)
    widgetContainer:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    widgetContainer:SetFrameStrata("TOOLTIP")
    widgetContainer:SetMovable(true)
    widgetContainer:SetClampedToScreen(true)

    widgetBtn = CreateFrame("Button", "ClassCodexWidgetButton", widgetContainer)
    widgetBtn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    widgetBtn:SetPoint("CENTER")
    widgetBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    widgetBtn:RegisterForDrag("LeftButton")

    widgetIcon = widgetBtn:CreateTexture(nil, "ARTWORK")
    widgetIcon:SetSize(BUTTON_SIZE - 6, BUTTON_SIZE - 6)
    widgetIcon:SetPoint("CENTER")
    widgetIcon:SetTexture("Interface\\AddOns\\BreadClassCodex\\Media\\icon")
    widgetIcon:SetVertexColor(0.82, 0.82, 0.82)

    local widgetHighlight = widgetBtn:CreateTexture(nil, "HIGHLIGHT")
    widgetHighlight:SetAllPoints(widgetIcon)
    widgetHighlight:SetTexture("Interface\\AddOns\\BreadClassCodex\\Media\\icon")
    widgetHighlight:SetAlpha(0.3)
    widgetHighlight:SetBlendMode("ADD")

    local widgetIconBright = widgetBtn:CreateTexture(nil, "OVERLAY")
    widgetIconBright:SetAllPoints(widgetIcon)
    widgetIconBright:SetTexture("Interface\\AddOns\\BreadClassCodex\\Media\\icon")
    widgetIconBright:SetVertexColor(1, 1, 1)
    widgetIconBright:SetAlpha(0)

    local brightTarget = 0
    local function AnimateBright(toAlpha)
        brightTarget = toAlpha
    end
    widgetBtn:SetScript("OnUpdate", function(_, elapsed)
        local cur = widgetIconBright:GetAlpha()
        if math.abs(cur - brightTarget) < 0.01 then
            if cur ~= brightTarget then widgetIconBright:SetAlpha(brightTarget) end
            return
        end
        local step = elapsed / 0.22
        if cur < brightTarget then
            cur = math.min(brightTarget, cur + step)
        else
            cur = math.max(brightTarget, cur - step)
        end
        widgetIconBright:SetAlpha(cur)
    end)

    local fx = CreateFrame("Frame", nil, widgetContainer)
    fx:SetAllPoints(widgetBtn)
    fx:SetFrameLevel(math.max(0, widgetBtn:GetFrameLevel() - 1))
    local fxGlow = fx:CreateTexture(nil, "BACKGROUND")
    fxGlow:SetSize(BUTTON_SIZE + 12, BUTTON_SIZE + 12)
    fxGlow:SetPoint("CENTER")
    fxGlow:SetAtlas("bags-glow-flash")
    fxGlow:SetVertexColor(1.0, 0.85, 0.3)
    fxGlow:SetBlendMode("ADD")

    local starFrame = CreateFrame("Frame", nil, fx)
    starFrame:SetAllPoints()
    local fxStar = starFrame:CreateTexture(nil, "BACKGROUND")
    fxStar:SetSize(BUTTON_SIZE + 18, BUTTON_SIZE + 18)
    fxStar:SetPoint("CENTER")
    fxStar:SetTexture("Interface\\Cooldown\\star4")
    fxStar:SetVertexColor(1.0, 0.9, 0.45, 0.5)
    fxStar:SetBlendMode("ADD")

    local pulse = fx:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local pulseAlpha = pulse:CreateAnimation("Alpha")
    pulseAlpha:SetFromAlpha(0.25)
    pulseAlpha:SetToAlpha(0.7)
    pulseAlpha:SetDuration(1.1)
    pulseAlpha:SetSmoothing("IN_OUT")

    local spin = starFrame:CreateAnimationGroup()
    spin:SetLooping("REPEAT")
    local spinRot = spin:CreateAnimation("Rotation")
    spinRot:SetDegrees(360)
    spinRot:SetDuration(9)

    local trailFx = CreateFrame("Frame", nil, UIParent)
    trailFx:SetFrameStrata("TOOLTIP")
    trailFx:SetSize(24, 24)
    trailFx:Hide()
    local trailTex = trailFx:CreateTexture(nil, "OVERLAY")
    trailTex:SetAllPoints()
    trailTex:SetTexture("Interface\\Cooldown\\star4")
    trailTex:SetVertexColor(1.0, 0.9, 0.5)
    trailTex:SetBlendMode("ADD")
    local trailT = 0
    trailFx:SetScript("OnUpdate", function(self, elapsed)
        trailT = trailT - elapsed
        if trailT <= 0 then
            self:Hide()
            return
        end
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale == 0 then return end
        local cx, cy = GetCursorPosition()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
        self:SetAlpha(math.min(1, trailT * 1.6))
        trailTex:SetRotation((1 - trailT) * 5)
    end)
    local function StartTrail()
        trailT = 1.0
        trailFx:Show()
    end

    local widgetActive = false
    local function SetWidgetActive(active)
        widgetActive = active
        if active then
            pulse:Stop()
            spin:Stop()
            fx:Hide()
            AnimateBright(1)
        else
            fx:Show()
            pulse:Play()
            spin:Play()
            AnimateBright(0)
        end
    end

    local function IsLocked()
        return ClassCodexDB and ClassCodexDB.widgetLocked
    end

    widgetBtn:SetScript("OnEnter", function(self)
        AnimateBright(1)
        StartTrail()
        ns.Tooltip.Open(self, "ANCHOR_RIGHT").Title("Bread Codex").Body(L["character_pane.click_to_toggle"])
        if IsLocked() then
            ns.Tooltip.Body(L["character_pane.position_locked"])
        else
            ns.Tooltip.Hint(L["character_pane.shift_drag_hint"])
        end
        ns.Tooltip.Show()
    end)
    widgetBtn:SetScript("OnLeave", function()
        AnimateBright(widgetActive and 1 or 0)
        ns.Tooltip.Hide()
    end)

    SetWidgetActive(false)

    widgetBtn:SetScript("OnDragStart", function()
        if IsLocked() or not IsShiftKeyDown() then return end
        widgetContainer:StartMoving()
        widgetContainer.isMoving = true
    end)

    widgetBtn:SetScript("OnDragStop", function()
        if not widgetContainer.isMoving then return end
        widgetContainer:StopMovingOrSizing()
        widgetContainer.isMoving = false
        local cx, cy = widgetContainer:GetCenter()
        local anchor = widgetContainer:GetParent() or PaperDollFrame
        local right, top = anchor:GetRight(), anchor:GetTop()
        if cx and cy and right and top then
            ClassCodexDB.widgetOffsetX = math.floor(cx - right + 0.5)
            ClassCodexDB.widgetOffsetY = math.floor(cy - top + 0.5)
        end
        ApplyWidgetPosition()
        RefreshWidgetTooltip()
    end)

    widgetBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if IsLocked() or not IsShiftKeyDown() then return end
            ClassCodexDB.widgetOffsetX = WIDGET_DEFAULT_OFFSET_X
            ClassCodexDB.widgetOffsetY = WIDGET_DEFAULT_OFFSET_Y
            ApplyWidgetPosition()
            return
        end
        if IsShiftKeyDown() and not IsLocked() then return end
        if panel:IsShown() and not isFloating then
            panel:Hide()
            ClassCodexCharDB.panelOpen = false
            SetWidgetActive(false)
            if SOUNDKIT then PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE or SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end
        else
            if not isFloating then DockPanel() end
            ns:UpdatePanel()
            SlideInDocked()
            ClassCodexCharDB.panelOpen = true
            SetWidgetActive(true)
            if SOUNDKIT then PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN or SOUNDKIT.IG_CHARACTER_INFO_OPEN) end
        end
    end)

    local function OnAnyHostShow()
        local ok, err = pcall(function()
            ApplyWidgetPosition()
            if not isFloating then
                DockPanel()
                if ClassCodexCharDB and ClassCodexCharDB.panelOpen then
                    ns:UpdatePanel()
                    FadeIn(panel)
                    SetWidgetActive(true)
                else
                    SetWidgetActive(false)
                end

                C_Timer.After(0, function()
                    if not isFloating and panel:IsShown() then
                        AnchorDockedPanel()
                        ns:LayoutPanel()
                    end
                end)
            end
        end)
        if not ok then print("|cffff0000Bread Codex:|r Panel error: " .. tostring(err)) end
    end

    local function OnAnyHostHide()
        if not isFloating then
            panel:Hide()
            copyPopup:Hide()
        end
        SetWidgetActive(false)
    end

    -- Both hosts need the hook: opening the character frame on a non-PaperDoll
    -- tab (Reputation/PvP/Pet) shows CharacterFrame without PaperDollFrame, so
    -- a PaperDoll-only hook leaves the docked panel hidden until the tab
    -- switch. A one-frame throttle collapses the double-fire when both show.
    local hostShowQueued = false
    local function OnSomeHostShow()
        if hostShowQueued then return end
        hostShowQueued = true
        C_Timer.After(0, function()
            hostShowQueued = false
            -- On a non-PaperDoll tab the dock waits for the tab switch (the
            -- PaperDollFrame OnShow hook fires then) instead of overlaying.
            if not PaperDollFrame:IsShown() then return end
            OnAnyHostShow()
        end)
    end

    PaperDollFrame:HookScript("OnShow", OnSomeHostShow)
    PaperDollFrame:HookScript("OnHide", OnAnyHostHide)
    CharacterFrame:HookScript("OnShow", OnSomeHostShow)

    CharacterFrame:HookScript("OnSizeChanged", function()
        if not isFloating and panel:IsShown() then
            AnchorDockedPanel()
            ns:LayoutPanel()
        end
    end)

    function ns.InstallHostHooks(host)
        if host._hooked then return end
        if host.frame == PaperDollFrame or host.frame == CharacterFrame then return end
        host._hooked = true
        host.frame:HookScript("OnShow", OnAnyHostShow)
        host.frame:HookScript("OnHide", OnAnyHostHide)
    end

    for _, host in ipairs(dockHosts) do
        ns.InstallHostHooks(host)
    end
end

function ClassCodex_OnAddonCompartmentClick()
    if ns.OpenCompendium then ns:OpenCompendium() end
end

function ClassCodex_OnAddonCompartmentEnter(_, menuButtonFrame)
    local ver = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
    ns.Tooltip
        .Open(menuButtonFrame, "ANCHOR_RIGHT")
        .Intro("Bread Codex v" .. ver)
        .Body("Click to open Compendium")
        .Show()
end

function ClassCodex_OnAddonCompartmentLeave()
    ns.Tooltip.Hide()
end

local STAT_LOOKUP = {}
do
    local stats = {
        { key = "Critical Strike", globals = { "STAT_CRITICAL_STRIKE", "ITEM_MOD_CRIT_RATING_SHORT" } },
        { key = "Haste", globals = { "STAT_HASTE", "ITEM_MOD_HASTE_RATING_SHORT" } },
        { key = "Mastery", globals = { "STAT_MASTERY", "ITEM_MOD_MASTERY_RATING_SHORT" } },
        { key = "Versatility", globals = { "STAT_VERSATILITY", "ITEM_MOD_VERSATILITY" } },
    }
    for _, s in ipairs(stats) do
        for _, g in ipairs(s.globals) do
            local localized = _G[g]
            if localized and localized ~= "" and not STAT_LOOKUP[localized] then STAT_LOOKUP[localized] = s.key end
        end

        if not STAT_LOOKUP[s.key] then STAT_LOOKUP[s.key] = s.key end
    end
end

local BIS_TIER_HEX = {
    S = "|cffff8000",
    A = "|cffa336ee",
    B = "|cff0070dd",
    C = "|cff1eff00",
    D = "|cff9e9e9e",
}
local BIS_TIER_ORDER = { S = 1, A = 2, B = 3, C = 4, D = 5 }
local BIS_CLASS_ID_MAP = {
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

local iconCache = {}
local colorCache = {}

local function GetClassColorHex(classToken)
    local cached = colorCache[classToken]
    if cached then return cached end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if color then
        cached = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    else
        cached = "|cffffffff"
    end
    colorCache[classToken] = cached
    return cached
end

local function GetClassIcon(classToken)
    local key = classToken
    local cached = iconCache[key]
    if cached then return cached end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    if coords then
        local l, r, t, b = coords[1], coords[2], coords[3], coords[4]
        cached = string.format(
            "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes:14:14:0:0:256:256:%d:%d:%d:%d|t",
            l * 256 + 6,
            r * 256 - 6,
            t * 256 + 6,
            b * 256 - 6
        )
    else
        cached = ""
    end
    iconCache[key] = cached
    return cached
end

local function GetSpecIconFor(classToken, specKey)
    local key = classToken .. "|" .. specKey
    local cached = iconCache[key]
    if cached then return cached end
    local classID = BIS_CLASS_ID_MAP[classToken]
    if classID and GetSpecializationInfoForClassID then
        local keys = SPEC_KEYS[classToken]
        if keys then
            for i, k in ipairs(keys) do
                if k == specKey then
                    local _, _, _, icon = GetSpecializationInfoForClassID(classID, i)
                    if icon then
                        cached = string.format("|T%s:14:14:0:0|t", tostring(icon))
                        iconCache[key] = cached
                        return cached
                    end
                    break
                end
            end
        end
    end
    cached = GetClassIcon(classToken)
    iconCache[key] = cached
    return cached
end

local function GetEntryIcon(entry)
    if entry.consolidated then
        return GetClassIcon(entry.class)
    else
        return GetSpecIconFor(entry.class, entry.spec)
    end
end

local tooltipCache = {}
local tooltipCacheScopeKey = nil
local playerClassToken = nil

local function ResolveBisScope()
    local scope = ClassCodexDB.tooltipBisScope or "all"
    if scope == "all" then return nil, "all" end
    if scope == "off" then return {}, "off" end
    local set = {}
    if playerClassToken then set[playerClassToken] = true end
    if scope == "group" then
        local n = GetNumGroupMembers() or 0
        if n > 0 then
            local unitPrefix = IsInRaid() and "raid" or "party"
            for i = 1, n do
                local _, class = UnitClass(unitPrefix .. i)
                if class then set[class] = true end
            end
        end
    end

    local tokens = {}
    for c in pairs(set) do
        tokens[#tokens + 1] = c
    end
    table.sort(tokens)
    return set, scope .. ":" .. table.concat(tokens, ",")
end

local function SourceBadge(which, style)
    local showIcon = style == 1 or style == 3
    local showLabel = style == 2 or style == 3
    local s = ""
    if which == "ugg" then
        if showIcon then s = s .. "|TInterface\\AddOns\\BreadClassCodex\\Media\\ugg:12:12:0:0|t" end
        if showLabel then s = s .. (showIcon and " " or "") .. "|cffff8000WH|r" end
    else
        if showIcon then s = s .. "|TInterface\\AddOns\\BreadClassCodex\\Media\\icyveins:12:12:0:0|t" end
        if showLabel then s = s .. (showIcon and " " or "") .. "|cff00ccffIV|r" end
    end
    return s
end

local function FormatTrinketTiers(entry, style)
    local uggTier, ivTier = entry.tier, entry.ivTier
    local function letter(tier)
        return (BIS_TIER_HEX[tier] or "|cffffffff") .. tier .. "|r"
    end
    if uggTier and ivTier then
        if uggTier == ivTier then
            return letter(uggTier) .. " " .. SourceBadge("ugg", style) .. " " .. SourceBadge("iv", style)
        end
        return letter(uggTier)
            .. " "
            .. SourceBadge("ugg", style)
            .. "  "
            .. letter(ivTier)
            .. " "
            .. SourceBadge("iv", style)
    elseif uggTier then
        return letter(uggTier) .. " " .. SourceBadge("ugg", style)
    elseif ivTier then
        return letter(ivTier) .. " " .. SourceBadge("iv", style)
    end
    return nil
end

local function BuildTooltipEntries(itemId)
    local filterSet, scopeKey = ResolveBisScope()

    if tooltipCacheScopeKey ~= scopeKey then
        wipe(tooltipCache)
        tooltipCacheScopeKey = scopeKey
    end

    local cached = tooltipCache[itemId]
    if cached then return cached.entries, cached.source, cached.hasTrinketEntries end

    local entries = {}
    local seen = {}
    local hasTrinketEntries = false
    local source = nil

    if ClassCodexDB.showTrinketTooltip and ns.GetTrinketSpecs then
        local trinketSpecs = ns:GetTrinketSpecs(itemId)
        if trinketSpecs then
            if ns.GetTrinketSource then source = ns:GetTrinketSource(itemId) end
            for _, entry in ipairs(trinketSpecs) do
                if not filterSet or filterSet[entry.class] then
                    local right = FormatTrinketTiers(entry, ClassCodexDB.tooltipSourceStyle or 1)
                    if right then
                        entries[#entries + 1] = {
                            left = GetEntryIcon(entry) .. " " .. GetClassColorHex(entry.class) .. entry.label .. "|r",
                            right = right,
                            classToken = entry.class,
                            sortKey = math.min(BIS_TIER_ORDER[entry.tier] or 6, BIS_TIER_ORDER[entry.ivTier] or 6),
                            isTrinketEntry = true,
                        }
                        seen[entry.label] = true
                        hasTrinketEntries = true
                    end
                end
            end
        end
    end

    local showUgg = ClassCodexDB.showUggBisTooltip
    local showIV = ClassCodexDB.showIcyVeinsBisTooltip

    local bisBySpec = {}
    local bisOrder = {}

    if showUgg and ns.GetUggBisSpecs then
        local bisSpecs = ns:GetUggBisSpecs(itemId)
        if bisSpecs then
            for _, entry in ipairs(bisSpecs) do
                if not seen[entry.label] and (not filterSet or filterSet[entry.class]) then
                    bisBySpec[entry.label] = {
                        class = entry.class,
                        spec = entry.spec,
                        consolidated = entry.consolidated,
                        hasWH = true,
                        hasIV = false,
                        ivTabs = {},
                    }
                    bisOrder[#bisOrder + 1] = entry.label
                end
            end
        end
    end

    if showIV and not hasTrinketEntries and ns.GetIcyVeinsBisSpecs then
        local ivSpecs = ns:GetIcyVeinsBisSpecs(itemId)
        if ivSpecs then
            for _, entry in ipairs(ivSpecs) do
                if not filterSet or filterSet[entry.class] then
                    local existing = bisBySpec[entry.label]
                    if existing then
                        existing.hasIV = true
                        if entry.tabs then
                            for _, t in ipairs(entry.tabs) do
                                existing.ivTabs[#existing.ivTabs + 1] = t
                            end
                        end
                    else
                        bisBySpec[entry.label] = {
                            class = entry.class,
                            spec = entry.spec,
                            consolidated = entry.consolidated,
                            hasWH = false,
                            hasIV = true,
                            ivTabs = entry.tabs or {},
                        }
                        bisOrder[#bisOrder + 1] = entry.label
                    end
                end
            end
        end
    end

    for _, label in ipairs(bisOrder) do
        if not seen[label] then
            local info = bisBySpec[label]
            local rightLabel = nil

            if info.hasWH or info.hasIV then
                local style = ClassCodexDB.tooltipSourceStyle or 1
                local showIcon = style == 1 or style == 3
                local showLabel = style == 2 or style == 3
                local parts = {}
                if info.hasWH then
                    local s = ""
                    if showIcon then s = s .. "|TInterface\\AddOns\\BreadClassCodex\\Media\\ugg:12:12:0:0|t" end
                    if showLabel then s = s .. (showIcon and " " or "") .. "|cffff8000WH|r" end
                    parts[#parts + 1] = s
                end
                if info.hasIV then
                    local uniqueTabs = {}
                    local tabSeen = {}
                    for _, t in ipairs(info.ivTabs) do
                        if not tabSeen[t] then
                            tabSeen[t] = true
                            uniqueTabs[#uniqueTabs + 1] = t
                        end
                    end
                    local s = ""
                    if showIcon then s = s .. "|TInterface\\AddOns\\BreadClassCodex\\Media\\icyveins:12:12:0:0|t" end

                    if #uniqueTabs > 0 and #uniqueTabs < 3 then
                        local shortTabs = {}
                        for _, t in ipairs(uniqueTabs) do
                            local short
                            if t == "Mythic+" then
                                short = "M+"
                            elseif t == "Raid" then
                                short = L["context.raid"]
                            elseif t == "Overall" or t:sub(1, 8) == "Overall " then
                                short = L["context.overall"]
                            else
                                short = t
                            end
                            shortTabs[#shortTabs + 1] = short
                        end
                        s = s .. " \194\183 " .. "|cff00ccff" .. table.concat(shortTabs, ", ") .. "|r"
                    elseif showLabel then
                        s = s .. (showIcon and " " or "") .. "|cff00ccffIV|r"
                    end
                    parts[#parts + 1] = s
                end
                rightLabel = table.concat(parts, "  ")
            end

            entries[#entries + 1] = {
                left = GetEntryIcon(info) .. " " .. GetClassColorHex(info.class) .. label .. "|r",
                right = rightLabel,
                classToken = info.class,
                sortKey = 0,
            }
            seen[label] = true
        end
    end

    if #entries > 0 then table.sort(entries, function(a, b)
        return a.sortKey < b.sortKey
    end) end

    tooltipCache[itemId] = { entries = entries, source = source, hasTrinketEntries = hasTrinketEntries }
    return entries, source, hasTrinketEntries
end

local function GetCachedRanks()
    local specData = GetSpecData()
    if not specData then return nil end

    if not currentHeroTalent then
        local perSpec = GetPerSpecState()
        if perSpec and perSpec.heroTalent then
            currentHeroTalent = perSpec.heroTalent
        else
            local detected = GetActiveHeroTalentName()
            if detected then
                local heroOptions = GetHeroTalentOptions(specData)
                for _, opt in ipairs(heroOptions) do
                    if opt:lower() == detected:lower() then
                        currentHeroTalent = opt
                        break
                    end
                end
            end
        end
    end
    local hero = currentHeroTalent or "All"
    local ctx = (ns.Context and ns.Context.contentType()) or "mplus"
    if cachedRanks and cachedRanksHero == hero and cachedRanksCtx == ctx then return cachedRanks end
    local classToken, specKey = GetClassAndSpec()
    local tiers = ns.GetStatPriority and ns.GetStatPriority(classToken, specKey, ctx)
    cachedRanksHero = hero
    cachedRanksCtx = ctx
    cachedBreakpoints = nil
    if not tiers then
        cachedRanks = nil
        return nil
    end
    cachedRanks = {}
    for i, tier in ipairs(tiers) do
        for _, stat in ipairs(tier) do
            cachedRanks[stat] = i
        end
    end
    if ns.GetStatBreakpoints then cachedBreakpoints = ns.GetStatBreakpoints(classToken, specKey, ctx) end
    return cachedRanks
end

local function OnTooltipItem(tooltip, tooltipData)
    if not ClassCodexDB then return end

    local itemId = tooltipData and tooltipData.id

    if ClassCodexDB.showTrinketTooltip and itemId and ns.GetTrinketTier then
        local tier, tierColor = ns:GetTrinketTier(itemId)
        if tier and tierColor then
            local titleRight = _G[tooltip:GetName() .. "TextRight1"]
            if titleRight and titleRight:GetFont() then
                local hex = string.format("|cff%02x%02x%02x", tierColor.r * 255, tierColor.g * 255, tierColor.b * 255)
                titleRight:SetText(hex .. tier .. "|r")
                titleRight:Show()
            end
        end
    end

    local bisScope = ClassCodexDB.tooltipBisScope or "all"
    if
        itemId
        and bisScope ~= "off"
        and (ClassCodexDB.showUggBisTooltip or ClassCodexDB.showIcyVeinsBisTooltip or ClassCodexDB.showTrinketTooltip)
    then
        local entries = BuildTooltipEntries(itemId)

        if #entries > 0 then
            tooltip:AddLine(" ")
            local style = ClassCodexDB.tooltipSourceStyle or 1
            local showIcon = style == 1 or style == 3
            local showLabel = style == 2 or style == 3
            local headerSources = {}
            if ClassCodexDB.showUggBisTooltip then
                local s = ""
                if showIcon then s = s .. "|TInterface\\AddOns\\BreadClassCodex\\Media\\ugg:12:12:0:0|t" end
                if showLabel then s = s .. (showIcon and " " or "") .. "|cffff8000WH|r" end
                headerSources[#headerSources + 1] = s
            end
            if ClassCodexDB.showIcyVeinsBisTooltip then
                local s = ""
                if showIcon then s = s .. "|TInterface\\AddOns\\BreadClassCodex\\Media\\icyveins:12:12:0:0|t" end
                if showLabel then s = s .. (showIcon and " " or "") .. "|cff00ccffIV|r" end
                headerSources[#headerSources + 1] = s
            end
            if #headerSources > 0 then
                tooltip:AddDoubleLine(
                    L["tooltip.bis_header"],
                    table.concat(headerSources, "  "),
                    1,
                    0.82,
                    0,
                    1,
                    0.82,
                    0
                )
            else
                tooltip:AddLine(L["tooltip.bis_header"], 1, 0.82, 0)
            end

            for _, e in ipairs(entries) do
                local cclr = RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.classToken]
                local cr, cg, cb = 1, 1, 1
                if cclr then
                    cr, cg, cb = cclr.r, cclr.g, cclr.b
                end
                if e.right then
                    tooltip:AddDoubleLine(e.left, e.right, cr, cg, cb, cr, cg, cb)
                else
                    tooltip:AddLine(e.left, cr, cg, cb)
                end
            end
        end
    end

    if not ClassCodexDB.showTooltipBadges then return end
    local ranks = GetCachedRanks()
    if not ranks then return end

    local annotated = false
    for i = 2, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                local ok, _ = pcall(string.len, text)
                if ok and line:GetFont() then
                    for localizedStat, englishStat in pairs(STAT_LOOKUP) do
                        if text:find(localizedStat, 1, true) and not text:find("#%d") then
                            local rank = ranks[englishStat]
                            -- Breakpoint stats ("Haste to 22%", "Haste (until
                            -- 1800 rating)") rank at the qualified tier until
                            -- the player actually reaches the threshold, then
                            -- fall back to their bare tier (if any).
                            local bp = cachedBreakpoints and cachedBreakpoints[englishStat]
                            if bp then
                                local current
                                if bp.kind == "rating" then
                                    current = ns.GetPlayerStatRating and ns.GetPlayerStatRating(bp.statKey)
                                else
                                    current = ns.GetPlayerStatPercent and ns.GetPlayerStatPercent(bp.statKey)
                                end
                                if current and current < bp.value then rank = bp.tier end
                            end
                            if rank then
                                local color = RANK_COLORS[rank]
                                if color then
                                    local hex =
                                        string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
                                    line:SetText(text .. "  " .. hex .. "#" .. rank .. "|r")
                                    annotated = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if annotated then
        -- Default "only when different": the line appears when the ranks on
        -- this tooltip reflect a DIFFERENT priority than the current content
        -- context + hero talent resolve to — not merely a different hero
        -- label (two heroes can share one priority, and then it's not
        -- different in any way that matters).
        local mode = ClassCodexDB.tooltipFooterMode
        if mode == nil then mode = 2 end
        if mode > 0 then
            local function PriorityKey(heroDisplay, ctx)
                local classToken, specKey = GetClassAndSpec()
                if not classToken then return nil end
                local heroSlug = (heroDisplay and heroDisplay ~= "All" and ns.HeroSlugFromDisplay)
                        and ns.HeroSlugFromDisplay(heroDisplay)
                    or "all"
                local tiers = ns.GetStatPriority and ns.GetStatPriority(classToken, specKey, ctx, nil, heroSlug)
                if not tiers then return nil end
                local parts = {}
                for _, tier in ipairs(tiers) do
                    parts[#parts + 1] = table.concat(tier, "=")
                end
                return table.concat(parts, ">")
            end

            local suppress = false
            if mode == 2 then
                local shown = PriorityKey(cachedRanksHero, cachedRanksCtx)
                local current = PriorityKey(
                    GetActiveHeroTalentName() or "All",
                    (ns.Context and ns.Context.contentType()) or "mplus"
                )
                suppress = shown ~= nil and current ~= nil and shown == current
            end
            if not suppress then
                local ctxLabel = cachedRanksCtx
                        and (CONTENT_TYPE_LABELS[cachedRanksCtx] or (cachedRanksCtx:sub(1, 4) == "pvp:" and "PvP") or cachedRanksCtx)
                    or "General"
                -- Own line (blank line above), yellow label left, white value
                -- right. The hero renders icon-or-label per the existing
                -- tooltip source-style preference (icons / labels / both).
                local heroName = cachedRanksHero or "All"
                local style = ClassCodexDB.tooltipPriorityStyle or 3
                local showIcon = style == 1 or style == 3
                local showLabel = style == 2 or style == 3
                local heroPart = ""
                if showIcon and heroName ~= "All" then
                    local atlas = ns.HERO_TALENT_ATLAS and ns.HERO_TALENT_ATLAS[heroName]
                    if atlas then heroPart = "|A:" .. atlas .. ":14:14|a" .. (showLabel and " " or "") end
                end
                if showLabel or heroPart == "" then heroPart = heroPart .. heroName end
                -- Content gets its icon (the same ones the context bar uses).
                local ctex
                if cachedRanksCtx == "pvp" or (cachedRanksCtx or ""):sub(1, 4) == "pvp:" then
                    ctex = PVP_BANNER[UnitFactionGroup("player") or ""] or PVP_BANNER.Alliance
                else
                    ctex = CONTEXT_ICON[cachedRanksCtx]
                end
                -- The icons/labels preference applies to the content too:
                -- icons-only shows just the icon (label falls back in when no
                -- icon exists for the context), labels-only just the label.
                local ctxPart = ""
                if showIcon and ctex then ctxPart = "|T" .. ctex .. ":14:14|t" end
                if showLabel or ctxPart == "" then ctxPart = ctxPart .. (ctxPart ~= "" and " " or "") .. ctxLabel end
                tooltip:AddLine(" ")
                tooltip:AddDoubleLine(L["tooltip.stat_priority_footer"], heroPart .. " " .. ctxPart, 1, 0.8, 0, 1, 1, 1)
            end
        end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipItem)
end

function ns.UpdatePanelIfVisible(mode)
    if not panel:IsShown() then return end
    if mode == "docked" and isFloating then return end
    if mode == "floating" and not isFloating then return end
    ns:UpdatePanel()
end

function ns.InvalidateTooltipCache()
    wipe(tooltipCache)
    tooltipCacheScopeKey = nil
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")

eventFrame:RegisterEvent("COMBAT_RATING_UPDATE")
eventFrame:RegisterEvent("UNIT_STATS")

eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")

eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        local dbDefaults = {
            showLoginMessage = false,
            showTooltipBadges = true,
            tooltipFooterMode = 2,
            showUggBisTooltip = true,
            showIcyVeinsBisTooltip = true,
            showTrinketTooltip = true,
            tooltipBisScope = "all",
            pinTalentSource = false,
            panelWidth = PANEL_WIDTH,
            floatPanelHeight = FLOAT_HEIGHT_DEFAULT,
            floatAutoHeight = false,
            pageHardStops = false,
            highlightOwnedGear = true,
            tooltipSourceStyle = 1,
            minimap = { hide = false },
            showMinimapButton = true,
            floatShowStats = true,
            floatShowTalents = true,
            floatShowRotation = true,
            floatShowOmnium = true,
            floatShowEnchants = true,
            floatShowGems = true,
            floatShowConsumables = true,
            floatShowTrinkets = true,
            floatShowCrafts = true,
            floatShowEmbellishments = true,
            floatShowBisGear = true,
            dockShowStats = true,
            dockShowTalents = true,
            dockShowRotation = true,
            dockShowOmnium = true,
            dockShowEnchants = true,
            dockShowGems = true,
            dockShowConsumables = true,
            dockShowTrinkets = true,
            dockShowCrafts = true,
            dockShowEmbellishments = true,
            dockShowBisGear = true,
            widgetOffsetX = WIDGET_DEFAULT_OFFSET_X,
            widgetOffsetY = WIDGET_DEFAULT_OFFSET_Y,
            widgetLocked = false,
            dockLoadoutEnabled = false,
            dockLoadoutHideInCombat = true,
            dockLoadoutLocked = false,
            dockLoadoutShowSpecIcon = true,
            dockLoadoutShowHeroIcon = true,
            dockLoadoutShowSaved = true,
            dockLoadoutShowIcyVeins = true,
            dockLoadoutShowUgg = true,
            dockLoadoutBackground = "class",
            dockLoadoutTheme = "codex",
            dockLoadoutBuildFilter = "hero",
            dockLoadoutHeroFilter = "auto",
            dockLoadoutShowPvp = true,
            dockLoadoutWidth = 200,
            dockLoadoutMaxWidth = 400,
            dockLoadoutAutoWidth = false,
            dockLoadoutScale = 100,
            dockLoadoutAlignment = "LEFT",
            raidDifficulty = "both",
        }
        local charDefaults = {
            panelOpen = true,
            floating = false,
            minimized = false,
            perSpec = {},
            collapsed = {
                stats = false,
                statTargets = false,
                talents = false,
                rotation = false,
                enchants = false,
                gems = false,
            },
        }

        if not ClassCodexDB then ClassCodexDB = {} end

        if ClassCodexDB.showBisTooltip ~= nil then
            ClassCodexDB.showUggBisTooltip = ClassCodexDB.showBisTooltip
            ClassCodexDB.showBisTooltip = nil
        end

        local TAB_MIGRATION = {
            enchants = "enhancements",
            consumables = "enhancements",
            gear = "bis",
            trinkets = "trinkets",
            crafts = "crafting",
        }
        if ClassCodexDB.compendiumTab then
            ClassCodexDB.compendiumTab = TAB_MIGRATION[ClassCodexDB.compendiumTab] or ClassCodexDB.compendiumTab
        end

        if ClassCodexCharDB and ClassCodexCharDB.loadoutDock then
            local old = ClassCodexCharDB.loadoutDock
            if old.point and old.x and old.y and not ClassCodexDB.dockLoadoutPosition then
                ClassCodexDB.dockLoadoutPosition = {
                    point = old.point,
                    relativePoint = old.relativePoint,
                    x = old.x,
                    y = old.y,
                }
            end
            ClassCodexCharDB.loadoutDock = nil
        end

        if ClassCodexDB.showTooltipPriorityFooter ~= nil and ClassCodexDB.tooltipFooterMode == nil then
            if ClassCodexDB.showTooltipPriorityFooter then
                ClassCodexDB.tooltipFooterMode = ClassCodexDB.tooltipFooterOnlyWhenDifferent and 2 or 1
            else
                ClassCodexDB.tooltipFooterMode = 0
            end
        end
        ClassCodexDB.showTooltipPriorityFooter = nil
        ClassCodexDB.tooltipFooterOnlyWhenDifferent = nil

        if ClassCodexDB.dockShowCrafts == false and ClassCodexDB.dockShowEmbellishments == nil then
            ClassCodexDB.dockShowEmbellishments = false
        end
        if ClassCodexDB.floatShowCrafts == false and ClassCodexDB.floatShowEmbellishments == nil then
            ClassCodexDB.floatShowEmbellishments = false
        end

        if ClassCodexDB.bisCurrentClassOnly ~= nil and ClassCodexDB.tooltipBisScope == nil then
            ClassCodexDB.tooltipBisScope = ClassCodexDB.bisCurrentClassOnly and "self" or "all"
            ClassCodexDB.bisCurrentClassOnly = nil
        end
        for k, v in pairs(dbDefaults) do
            if ClassCodexDB[k] == nil then ClassCodexDB[k] = v end
        end

        local function EnsureAtLeastOneVisibleTab(modePrefix)
            local hasGuide = ClassCodexDB[modePrefix .. "Stats"] ~= false
                or ClassCodexDB[modePrefix .. "Talents"] ~= false
                or ClassCodexDB[modePrefix .. "Rotation"] ~= false
                or ClassCodexDB[modePrefix .. "Omnium"] ~= false
            local hasGearing = ClassCodexDB[modePrefix .. "Enchants"] ~= false
                or ClassCodexDB[modePrefix .. "Gems"] ~= false
                or ClassCodexDB[modePrefix .. "Consumables"] ~= false
                or ClassCodexDB[modePrefix .. "Trinkets"] ~= false
                or ClassCodexDB[modePrefix .. "Crafts"] ~= false
                or ClassCodexDB[modePrefix .. "Embellishments"] ~= false
                or ClassCodexDB[modePrefix .. "BisGear"] ~= false
            if not hasGuide and not hasGearing then
                ClassCodexDB[modePrefix .. "Stats"] = true
                ClassCodexDB[modePrefix .. "Talents"] = true
                ClassCodexDB[modePrefix .. "Rotation"] = true
            end
        end
        EnsureAtLeastOneVisibleTab("dockShow")
        EnsureAtLeastOneVisibleTab("floatShow")
        if type(ClassCodexDB.minimap) ~= "table" then ClassCodexDB.minimap = { hide = false } end

        ClassCodexDB.minimap.hide = not ClassCodexDB.showMinimapButton
        if not ClassCodexCharDB then ClassCodexCharDB = {} end
        for k, v in pairs(charDefaults) do
            if ClassCodexCharDB[k] == nil then ClassCodexCharDB[k] = v end
        end

        if ClassCodexCharDB.activeTab then
            local remap = {
                guide = "stats",
                omnium = "talents",
                bis = "gear",
                trinkets = "gear",
                enchants = "enhancements",
                gems = "enhancements",
                consumables = "enhancements",
                enhancements = "enhancements",
                crafts = "crafting",
                embellishments = "crafting",
                settings = "about",
            }
            local t = remap[ClassCodexCharDB.activeTab] or ClassCodexCharDB.activeTab
            if not TAB_META[t] then t = "stats" end
            ClassCodexCharDB.activeTab = t
            activeTab = t
        end

        playerClassToken = select(2, UnitClass("player"))
        ns.RegisterSettings()

        local LDB = LibStub("LibDataBroker-1.1", true)
        local LDBIcon = LibStub("LibDBIcon-1.0", true)
        if LDB and LDBIcon then
            local dataObj = LDB:NewDataObject("ClassCodex", {
                type = "launcher",

                icon = "Interface\\AddOns\\BreadClassCodex\\Media\\minimap",
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        if ns.OpenCompendium then ns:OpenCompendium() end
                    elseif button == "RightButton" then
                        if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
                    end
                end,
                OnTooltipShow = function(tip)
                    local ver = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
                    tip:AddLine("Bread Codex v" .. ver, 1, 1, 1)
                    tip:AddLine("Left-click to open Compendium", 1, 0.82, 0)
                    tip:AddLine("Right-click to open Settings", 1, 0.82, 0)
                end,
            })
            LDBIcon:Register("ClassCodex", dataObj, ClassCodexDB.minimap)
            ns.LDBIcon = LDBIcon
        end

        if ClassCodexCharDB.floating then FloatPanel() end

        isMinimized = ClassCodexCharDB.minimized or false
        if isMinimized then minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up") end

        if ClassCodexCharDB.activeTab then ns.setActiveTab(ClassCodexCharDB.activeTab) end

        if ns.LayoutSideTabs then ns.LayoutSideTabs() end

        if PaperDollFrame then SetupWidgetButton() end
    elseif event == "ADDON_LOADED" and PaperDollFrame and not widgetContainer then
        SetupWidgetButton()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if PaperDollFrame and not widgetContainer then SetupWidgetButton() end

        if _G.GwCharacterWindow then ns.RegisterDockHost(_G.GwCharacterWindow, { priority = 50 }) end

        ns.ccContested = false
        for name in pairs(SlashCmdList) do
            if name ~= "CLASSCODEX" then
                local i = 1
                local s = _G["SLASH_" .. name .. i]
                while s do
                    if type(s) == "string" and s:upper() == "/CC" then
                        ns.ccContested = true
                        break
                    end
                    i = i + 1
                    s = _G["SLASH_" .. name .. i]
                end
            end
            if ns.ccContested then break end
        end
        if ClassCodexDB and ClassCodexDB.showLoginMessage then
            local ver = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
            print("|cff00ccffBread Codex|r v" .. ver .. " " .. ns.FixSlash(L["chat.loaded"]))
        end
        if ns.ccContested then print("|cff00ccffBread Codex:|r " .. L["chat.slash_conflict"]) end

        if isFloating and ClassCodexCharDB and ClassCodexCharDB.panelOpen then
            ns:UpdatePanel()
            panel:Show()
        end

        if ns.RegisterUggContextCallback then
            ns.RegisterUggContextCallback(function()
                if panel:IsShown() and not isMinimized then ns:UpdatePanel() end
            end)
        end
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if widgetContainer then eventFrame:UnregisterEvent("ADDON_LOADED") end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player" then
        local perSpec = GetPerSpecState()
        if perSpec then
            local oldHero = perSpec.heroTalent
            perSpec.heroTalent = nil
            local newHero = GetActiveHeroTalentName()
            if oldHero and oldHero ~= newHero then
                print("|cff00ccffBread Codex:|r " .. L["chat.switched_to"]:format(newHero or "auto-detect"))
            end
        end
        currentHeroTalent = nil
        cachedRanks = nil
        cachedBreakpoints = nil
        if panel:IsShown() then ns:UpdatePanel() end
    elseif event == "TRAIT_CONFIG_UPDATED" then
        if ns._talentApplyInProgress then return end
        local perSpec = GetPerSpecState()
        if perSpec then perSpec.heroTalent = nil end
        currentHeroTalent = nil
        cachedRanks = nil
        cachedBreakpoints = nil
        wipe(spellKnownCache)
        if panel:IsShown() then ns:UpdatePanel() end
    elseif event == "COMBAT_RATING_UPDATE" or event == "UNIT_STATS" then
        if panel:IsShown() and not isMinimized then ns:UpdatePanel() end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        if panel:IsShown() and not isMinimized then ns:UpdatePanel() end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED" then
        if panel:IsShown() and not isMinimized then ns:UpdatePanel() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if ClassCodexDB and ClassCodexDB.tooltipBisScope == "group" then ns.InvalidateTooltipCache() end
    end
end)

SLASH_CLASSCODEX1 = "/cc"
SLASH_CLASSCODEX2 = "/classcodex"
SlashCmdList["CLASSCODEX"] = function(msg)
    msg = msg:lower():trim()
    if msg == "toggle" or msg == "" then
        if isFloating then
            if panel:IsShown() then
                panel:Hide()
                ClassCodexCharDB.panelOpen = false
            else
                ns:UpdatePanel()
                FadeIn(panel)
                ClassCodexCharDB.panelOpen = true
            end
        elseif CharacterFrame:IsShown() then
            if panel:IsShown() then
                panel:Hide()
                ClassCodexCharDB.panelOpen = false
            else
                ns:UpdatePanel()
                SlideInDocked()
                ClassCodexCharDB.panelOpen = true
            end
        else
            ToggleCharacter("PaperDollFrame")
            ClassCodexCharDB.panelOpen = true
        end
    elseif msg == "compendium" then
        if ns.OpenCompendium then
            ns:OpenCompendium()
        else
            print("|cff00ccffBread Codex:|r " .. L["chat.compendium_not_available"])
        end
    elseif msg == "reset" then
        ClassCodexCharDB.floating = false
        ClassCodexCharDB.floatX = nil
        ClassCodexCharDB.floatY = nil
        ClassCodexCharDB.minimized = false
        isFloating = false
        isMinimized = false
        DockPanel()
        minimizeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-CollapseButton-Up")
        print("|cff00ccffBread Codex:|r " .. L["chat.mode_reset"])
        if panel:IsShown() then ns:UpdatePanel() end
    elseif msg == "help" then
        local sc = ns.FixSlash("/cc")
        print("|cff00ccffBread Codex|r commands:")
        print("  " .. sc)
        print("  " .. sc .. " compendium")
        print("  " .. sc .. " reset")
    else
        print("|cff00ccffBread Codex:|r " .. ns.FixSlash(L["chat.unknown_command"]))
    end
end
