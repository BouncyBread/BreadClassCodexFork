local addonName, ns = ...
local L = ns.L

function ns.CreateSettingsAboutCanvas()
    local canvas = CreateFrame("Frame", "ClassCodexSettingsAbout")
    canvas.OnCommit = function() end
    canvas.OnDefault = function() end
    canvas.OnRefresh = function() end

    local scroll = CreateFrame("ScrollFrame", "ClassCodexSettingsAboutScroll", canvas, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"

    local ICON_SIZE = 38

    local titleIcon = content:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(ICON_SIZE, ICON_SIZE)
    titleIcon:SetTexture("Interface\\AddOns\\BreadClassCodex\\Media\\icon")

    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetText("Bread Codex  · v" .. version)
    title:SetTextColor(1, 0.82, 0)

    local dataLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dataLabel:SetText(L["about.data_update"])
    dataLabel:SetTextColor(1, 0.82, 0)

    local dataVal = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")

    local placeCards = ns.BuildSettingsCards(content)

    local separator = content:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetColorTexture(0.3, 0.3, 0.3, 0.6)

    local placeTiers = ns.BuildSupporterTiers(content)

    local function Layout()
        local width = scroll:GetWidth()
        if not width or width < 40 then return end
        content:SetWidth(width)

        local titleX = 2 + ICON_SIZE + 8
        local iconTop = -2
        local gap = 2
        local titleH = title:GetStringHeight() or 18
        local dataH = dataLabel:GetStringHeight() or 12
        local blockTop = iconTop - (ICON_SIZE - (titleH + gap + dataH)) / 2

        titleIcon:ClearAllPoints()
        titleIcon:SetPoint("TOPLEFT", content, "TOPLEFT", 2, iconTop)
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", content, "TOPLEFT", titleX, blockTop)

        dataLabel:ClearAllPoints()
        dataLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -gap)
        dataVal:SetText(ns.DataUpdatedText and ns.DataUpdatedText() or "")
        if ns.DataUpdatedColor then dataVal:SetTextColor(ns.DataUpdatedColor()) end
        dataVal:ClearAllPoints()
        dataVal:SetPoint("LEFT", dataLabel, "RIGHT", 4, 0)

        local y = iconTop - ICON_SIZE - 10

        y = placeCards(width, y)

        y = y - 4
        separator:ClearAllPoints()
        separator:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
        separator:SetPoint("RIGHT", content, "RIGHT", -2, 0)
        y = y - 10

        y = placeTiers(width, y)

        content:SetHeight(math.abs(y) + 10)
    end

    scroll:SetScript("OnSizeChanged", Layout)
    canvas:SetScript("OnShow", Layout)
    canvas.Layout = Layout
    return canvas
end
