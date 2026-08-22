local _, ns = ...
local L = ns.L

local CHAMPIONS = {
    "Tantify",
    "Bull Horn",
    "Insecurity",
    "Lisa",
    "HelloImDrew",
    "Keith C Davis",
    "willis_1128",
    "Jakob Hartley",
    "Rookie H",
}
local SUPPORTER_LIST = {
    "Bxnane",
    "Rod",
    "Furkan Yünkül",
    "Mudrc",
    "Fabian Goertz",
    "Volkan Yamanlar",
    "Joe Zollo",
    "Zalyniela",
    "Kim",
    "xmousseline",
    "Chris Bobek",
    "Юрий Минкин",
    "Sabuha",
    "André Milde",
    "Alida Bell",
    "Gilen Martinez",
    "Tristin Alexander",
    "cumdunt",
}

local CHAMPION_COLOR = { 0.98, 0.78, 0.18 }
local SUPPORTER_COLOR = { 0.98, 0.65, 0.50 }
local TIER_ICON_ATLAS = "PetJournal-FavoritesIcon"
local TIER_ICON_W = 14
local TIER_DOT_W = 5
local TIER_NAME_INDENT = TIER_ICON_W + 4

local NAME_STRIDE = 18
local HEADER_STRIDE = 22
local TIER_GAP = 12

local ROW_H = 34
local ROW_GAP = 5
local HPAD = ns.PAGE_TITLE_HPAD or 8
local CHECK = "Interface\\AddOns\\BreadClassCodex\\Media\\action-apply"

local ARROW_RIGHT = "Interface\\AddOns\\BreadClassCodex\\Media\\arrow-right"
local LINK_EXTERNAL = "Interface\\AddOns\\BreadClassCodex\\Media\\link-external"
local GOLD = { 1, 0.82, 0 }
local GOLD_HL = { 1, 0.93, 0.4 }
local GREY = { 0.6, 0.6, 0.66 }
local TOGGLE = { 0.42, 0.72, 0.5 }
local DISCORD = { 0.34, 0.40, 0.95 }

local function ClassSpec()
    local classToken = select(2, UnitClass("player"))
    local specKey = ns.GetSpecKey and ns.GetSpecKey() or nil
    local spec = specKey and (specKey:match("-(.+)") or specKey)
    return classToken, spec
end

local function buildCards(parent)
    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetTextColor(1, 1, 1)
    desc:SetText(L["settings.description"])

    local rows = {
        ns.AboutLinkRow(parent, {
            icon = ns.SourceTexturePath("icyveins"),
            label = ns.SOURCES.icyveins.name,
            tip = L["settings.source_role.icyveins"],
            color = ns.SOURCES.icyveins.color,
            alpha = 0.75,
            round = true,
            onClick = function(self)
                local class, spec = ClassSpec()
                local url = ns.SourceLink("icyveins", "bis", class, spec)
                if url and ns.ShowCopyPopup then ns.ShowCopyPopup(url, self) end
            end,
        }),
        ns.AboutLinkRow(parent, {
            icon = ns.SourceTexturePath("ugg"),
            label = ns.SOURCES.ugg.name,
            tip = L["settings.source_role.ugg"],
            color = ns.SOURCES.ugg.color,
            alpha = 0.75,
            round = true,
            onClick = function(self)
                local class, spec = ClassSpec()
                local url = ns.SourceLink("ugg", "talents", class, spec) or ns.SOURCES.ugg.homepage
                if url and ns.ShowCopyPopup then ns.ShowCopyPopup(url, self) end
            end,
        }),
        ns.AboutLinkRow(parent, {
            icon = "Interface\\AddOns\\BreadClassCodex\\Media\\discord",
            label = "Bread Codex Discord",
            tip = L["settings.role.discord"],
            color = DISCORD,
            alpha = 0.75,
            round = true,
            onClick = function(self)
                if ns.ShowCopyPopup then ns.ShowCopyPopup(ns.DISCORD_URL, self) end
            end,
        }),
        ns.AboutLinkRow(parent, {
            icon = ns.SourceTexturePath("icyveins"),
            label = L["about.support_iv"],
            tip = L["about.support_iv_tip"],
            color = ns.SOURCES.icyveins.color,
            alpha = 0.75,
            round = true,
            onClick = function(self)
                local url = ns.ICYVEINS_PREMIUM_URL
                if ns.WithReferral then url = ns.WithReferral(url) end
                if url and ns.ShowCopyPopup then ns.ShowCopyPopup(url, self) end
            end,
        }),
    }

    return function(width, y)
        local textW = width - 4

        desc:ClearAllPoints()
        desc:SetWidth(textW)
        desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, y)
        y = y - (desc:GetStringHeight() or 12) - 12

        local colGap = 8
        local cellW = math.floor((textW - colGap) / 2)
        for i = 1, #rows, 2 do
            local left, right = rows[i], rows[i + 1]
            left:ClearAllPoints()
            left:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, y)
            left:SetWidth(cellW)
            left:Show()
            if right then
                right:ClearAllPoints()
                right:SetPoint("TOPLEFT", parent, "TOPLEFT", 2 + cellW + colGap, y)
                right:SetWidth(cellW)
                right:Show()
            end
            y = y - ROW_H - ROW_GAP
        end

        return y
    end
end

ns.BuildSettingsCards = buildCards

local function subheaderValue(header, text)
    local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("RIGHT", header, "RIGHT", -HPAD, 1)
    fs:SetJustifyH("RIGHT")
    fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    fs:SetText(text or "")
    return fs
end

local function AboutRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp")
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    row:SetBackdropColor(0.08, 0.08, 0.09, 0.94)
    row:SetBackdropBorderColor(0.32, 0.32, 0.38, 0.7)

    local colorBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    colorBg:SetPoint("TOPLEFT", 3, -3)
    colorBg:SetPoint("BOTTOMRIGHT", -3, 3)
    colorBg:Hide()
    row.colorBg = colorBg

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 11, 0)
    row.icon = icon

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    local marker = row:CreateTexture(nil, "OVERLAY")
    marker:SetSize(13, 13)
    marker:SetPoint("RIGHT", -11, 0)
    marker:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    row.marker = marker

    label:SetPoint("RIGHT", marker, "LEFT", -6, 0)

    function row:SetBackgroundColor(r, g, b, a)
        if r and colorBg.SetGradient and CreateColor then
            a = a or 0.32
            colorBg:SetColorTexture(1, 1, 1, 1)
            colorBg:SetGradient("HORIZONTAL", CreateColor(r, g, b, a * 0.35), CreateColor(r, g, b, a))
            colorBg:Show()
        else
            colorBg:Hide()
        end
    end

    row:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0, 0.9)
        self.label:SetTextColor(GOLD_HL[1], GOLD_HL[2], GOLD_HL[3])
        if self._markerHL then marker:SetVertexColor(GOLD_HL[1], GOLD_HL[2], GOLD_HL[3]) end
        if self.tipText then
            ns.Tooltip.Open(self, "ANCHOR_RIGHT").Head(self.label:GetText(), "title").Line(self.tipText, "body").Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.32, 0.32, 0.38, 0.7)
        self.label:SetTextColor(1, 1, 1)
        if self._markerHL then marker:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end
        if self._refreshMarker then self:_refreshMarker() end
        ns.Tooltip.Hide()
    end)
    return row
end

local ROUND_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local function roundIcon(r)
    if r._iconMask then return end
    local mask = r:CreateMaskTexture()
    mask:SetAllPoints(r.icon)
    mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    r.icon:AddMaskTexture(mask)
    r._iconMask = mask
end

local function styleRow(r, tint, color, alpha)
    if tint then
        r.icon:SetVertexColor(tint[1], tint[2], tint[3])
    else
        r.icon:SetVertexColor(1, 1, 1)
    end
    if color then r:SetBackgroundColor(color[1], color[2], color[3], alpha) end
end

local function makeLinkRow(parent, opts)
    local r = AboutRow(parent)
    r.icon:SetTexture(opts.icon)
    styleRow(r, opts.tint, opts.color, opts.alpha)
    if opts.round then roundIcon(r) end
    r.label:SetText(opts.label)
    r.tipText = opts.tip
    r.marker:SetTexture(opts.marker or LINK_EXTERNAL)
    r._markerHL = true
    if opts.onClick then r:SetScript("OnClick", opts.onClick) end
    return r
end
ns.AboutLinkRow = makeLinkRow

local function buildSettings(parent, context)
    local isComp = context == "compendium"
    local section, secHeader, content = ns.CreateCollapsibleSection(parent, {
        label = L["tab.about"],
        stateKey = "settings",
    })
    section.header = section.header or secHeader

    local frame = content

    local hVersion = ns.CreateSectionHeader(frame, L["about.version"], false)
    subheaderValue(hVersion, "v" .. (ns.AddonVersion and ns.AddonVersion() or "?"))

    local hData = ns.CreateSectionHeader(frame, L["about.data_update"], false)
    local dataVal = subheaderValue(hData, "")

    local hMore = ns.CreateSectionHeader(frame, L["about.more"], false)

    local rows = {}
    local function addLinkRow(icon, label, tip, arrow, onClick, tint, color, alpha)
        local r = AboutRow(frame)
        r.icon:SetTexture(icon)
        styleRow(r, tint, color, alpha)
        r.label:SetText(label)
        r.tipText = tip
        r.marker:SetTexture(arrow)
        r._markerHL = true
        r:SetScript("OnClick", onClick)
        rows[#rows + 1] = r
        return r
    end
    local function addToggleRow(icon, label, tip, getState, setState, tint, color, alpha)
        local r = AboutRow(frame)
        r.icon:SetTexture(icon)
        styleRow(r, tint, color, alpha)
        r.label:SetText(label)
        r.tipText = tip
        r.marker:SetTexture(CHECK)
        r._refreshMarker = function(self)
            if getState() then
                self.marker:SetAlpha(1)
                self.marker:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
            else
                self.marker:SetAlpha(0.3)
                self.marker:SetVertexColor(0.5, 0.5, 0.5)
            end
        end
        r:SetScript("OnClick", function(self)
            local newState = not getState()
            setState(newState)
            self:_refreshMarker()
            PlaySound(newState and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        end)
        r:_refreshMarker()
        rows[#rows + 1] = r
        return r
    end
    local settingsRow = addLinkRow(
        "Interface\\AddOns\\BreadClassCodex\\Media\\gear",
        L["about.all_settings"],
        L["about.settings_tip"],
        ARROW_RIGHT,
        function()
            if ns.OpenSettings then ns.OpenSettings() end
        end,
        GREY,
        GREY,
        0.28
    )
    settingsRow.icon:SetSize(16, 16)
    if not isComp then
        addLinkRow(
            "Interface\\AddOns\\BreadClassCodex\\Media\\icon",
            L["about.compendium"],
            L["about.compendium_tip"],
            ARROW_RIGHT,
            function()
                if ns.OpenCompendium then ns:OpenCompendium() end
            end,
            nil,
            GOLD,
            0.4
        )
    end
    addToggleRow(
        "Interface\\AddOns\\BreadClassCodex\\Media\\dock",
        L["about.loadout_dock"],
        L["about.loadout_dock_tip"],
        function()
            return ClassCodexDB and ClassCodexDB.dockLoadoutEnabled
        end,
        function(v)
            if ClassCodexDB then ClassCodexDB.dockLoadoutEnabled = v end
            if ns.UpdateLoadoutDockVisibility then ns.UpdateLoadoutDockVisibility() end
        end,
        GOLD,
        TOGGLE,
        0.3
    )
    addToggleRow(
        "Interface\\AddOns\\BreadClassCodex\\Media\\talent-highlight",
        L["about.talent_highlight"],
        L["about.talent_highlight_tip"],
        function()
            return not (ClassCodexDB and ClassCodexDB.talentPaneEnabled == false)
        end,
        function(v)
            if ClassCodexDB then ClassCodexDB.talentPaneEnabled = v end
            if ns.SetTalentPaneEnabled then ns.SetTalentPaneEnabled(v) end
        end,
        GOLD,
        TOGGLE,
        0.3
    )
    roundIcon(
        addLinkRow(
            "Interface\\AddOns\\BreadClassCodex\\Media\\discord",
            L["about.discord"],
            L["about.discord_tip"],
            LINK_EXTERNAL,
            function(self)
                if ns.ShowCopyPopup then ns.ShowCopyPopup(ns.DISCORD_URL, self) end
            end,
            nil,
            DISCORD,
            0.75
        )
    )
    roundIcon(
        addLinkRow(
            (ns.SourceTexturePath and ns.SourceTexturePath("icyveins"))
                or "Interface\\AddOns\\BreadClassCodex\\Media\\icyveins",
            L["about.support_iv"],
            L["about.support_iv_tip"],
            LINK_EXTERNAL,
            function(self)
                local url = ns.ICYVEINS_PREMIUM_URL
                if ns.WithReferral then url = ns.WithReferral(url) end
                if ns.ShowCopyPopup then ns.ShowCopyPopup(url, self) end
            end,
            nil,
            ns.SOURCES and ns.SOURCES.icyveins and ns.SOURCES.icyveins.color,
            0.75
        )
    )

    local function Layout()
        local p = frame:GetParent()
        local width = (p and p:GetWidth() and p:GetWidth() > 0 and p:GetWidth())
            or (ns.contentFrame and ns.contentFrame:GetWidth())
            or 0
        if width < 40 then return end

        local headerH = ns.SECTION_HEADER_HEIGHT or 24
        local function placeHeader(h, y)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
            h:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, y)
            if h.topDivider then h.topDivider:SetShown(false) end
            h:Show()
            return y - headerH + 4
        end
        local function placeRow(row, y)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", HPAD, y)
            row:SetPoint("RIGHT", frame, "RIGHT", -HPAD, 0)
            row:Show()
            return y - ROW_H - ROW_GAP
        end

        dataVal:SetText(ns.DataUpdatedText and ns.DataUpdatedText() or "")
        if ns.DataUpdatedColor then dataVal:SetTextColor(ns.DataUpdatedColor()) end

        local y = 0
        y = placeHeader(hVersion, y)
        y = placeHeader(hData, y)
        y = placeHeader(hMore, y)
        y = y - 6
        for _, r in ipairs(rows) do
            if r._refreshMarker then r:_refreshMarker() end
            y = placeRow(r, y)
        end

        frame:SetHeight(math.abs(y) + 8)
    end

    Layout()
    return section, content, Layout
end

function ns.BuildSupporterTiers(parent)
    local tiers = {}
    local function addTier(labelText, color, names)
        if #names == 0 then return end
        local icon = parent:CreateTexture(nil, "OVERLAY")
        icon:SetSize(TIER_ICON_W, TIER_ICON_W)
        icon:SetAtlas(TIER_ICON_ATLAS)
        icon:SetDesaturated(true)
        icon:SetVertexColor(color[1], color[2], color[3])

        local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetText(labelText .. "  |cff808080·|r  " .. #names)
        header:SetTextColor(color[1], color[2], color[3])
        header:SetJustifyH("LEFT")

        local rows = {}
        for _, name in ipairs(names) do
            local dot = parent:CreateTexture(nil, "OVERLAY")
            dot:SetSize(TIER_DOT_W, TIER_DOT_W)
            dot:SetColorTexture(color[1], color[2], color[3], 1)
            local mask = parent:CreateMaskTexture()
            mask:SetAllPoints(dot)
            mask:SetTexture(
                "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
                "CLAMPTOBLACKADDITIVE",
                "CLAMPTOBLACKADDITIVE"
            )
            dot:AddMaskTexture(mask)
            local nameFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameFs:SetText(name)
            nameFs:SetTextColor(0.85, 0.85, 0.85)
            nameFs:SetJustifyH("LEFT")
            nameFs:SetWordWrap(false)
            rows[#rows + 1] = { dot = dot, name = nameFs }
        end
        tiers[#tiers + 1] = { icon = icon, header = header, rows = rows }
    end
    addTier(L["settings.champions"], CHAMPION_COLOR, CHAMPIONS)
    addTier(L["settings.supporters"], SUPPORTER_COLOR, SUPPORTER_LIST)

    return function(width, y)
        local textW = width - 4
        local colCount = (width >= 520) and 3 or 2
        local colGap = 8
        local colWidth = math.floor((textW - colGap * (colCount - 1)) / colCount)

        for _, tier in ipairs(tiers) do
            tier.icon:ClearAllPoints()
            tier.icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, y - 1)
            tier.header:ClearAllPoints()
            tier.header:SetPoint("TOPLEFT", parent, "TOPLEFT", 2 + TIER_NAME_INDENT, y)
            y = y - HEADER_STRIDE
            for i, row in ipairs(tier.rows) do
                local col = (i - 1) % colCount
                local rowIdx = math.floor((i - 1) / colCount)
                local cellX = 2 + col * (colWidth + colGap)
                local rowY = y - rowIdx * NAME_STRIDE
                row.dot:ClearAllPoints()
                row.dot:SetPoint("TOPLEFT", parent, "TOPLEFT", cellX + (TIER_ICON_W - TIER_DOT_W) / 2, rowY - 4)
                row.name:ClearAllPoints()
                row.name:SetPoint("TOPLEFT", parent, "TOPLEFT", cellX + TIER_NAME_INDENT, rowY)
                row.name:SetWidth(colWidth - TIER_NAME_INDENT)
            end
            y = y - math.ceil(#tier.rows / colCount) * NAME_STRIDE - TIER_GAP
        end

        return y
    end
end

function ns.BuildSettingsPage()
    if not ns.contentFrame then return end
    ns.settingsSection, ns.settingsContent, ns.RefreshSettingsView = buildSettings(ns.contentFrame)
end

function ns.BuildCompendiumSettings(parent)
    ns.compSettingsSection, ns.compSettingsContent, ns.compRefreshSettingsView = buildSettings(parent, "compendium")
end
