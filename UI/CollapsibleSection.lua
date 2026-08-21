local _, ns = ...

local HEADER_LABEL_COLOR = { 1, 0.82, 0 }
local HEADER_LABEL_COLOR_HL = { 1, 0.93, 0.35 }

function ns.CreateSectionHeader(parent, labelText, collapsible)
    if collapsible == nil then collapsible = true end
    local headerHeight = ns.SECTION_HEADER_HEIGHT or 24

    local header = CreateFrame("Button", nil, parent)
    header:SetHeight(headerHeight)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:RegisterForClicks("LeftButtonUp")

    local arrow
    if collapsible then
        arrow = header:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(13, 13)
        arrow:SetPoint("LEFT", 3, 0)
        arrow:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
        header.arrow = arrow
    end

    local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", ns.PAGE_TITLE_HPAD or 8, 2)
    text:SetText(labelText)
    text:SetTextColor(HEADER_LABEL_COLOR[1], HEADER_LABEL_COLOR[2], HEADER_LABEL_COLOR[3])
    text:SetJustifyH("LEFT")
    header.label = text
    header.text = text

    local divider = header:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.35, 0.35, 0.35, 0.40)
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", 1, 3)
    divider:SetPoint("BOTTOMRIGHT", -2, 3)
    header.divider = divider

    local topDivider = header:CreateTexture(nil, "ARTWORK")
    topDivider:SetColorTexture(0.35, 0.35, 0.35, 0.40)
    topDivider:SetHeight(1)
    topDivider:SetPoint("TOPLEFT", 1, 0)
    topDivider:SetPoint("TOPRIGHT", -2, 0)
    topDivider:Hide()
    header.topDivider = topDivider

    if collapsible then
        header:EnableMouse(true)
        header:SetScript("OnEnter", function(self)
            if self.label then
                self.label:SetTextColor(HEADER_LABEL_COLOR_HL[1], HEADER_LABEL_COLOR_HL[2], HEADER_LABEL_COLOR_HL[3])
            end
        end)
        header:SetScript("OnLeave", function(self)
            if self.label then
                self.label:SetTextColor(HEADER_LABEL_COLOR[1], HEADER_LABEL_COLOR[2], HEADER_LABEL_COLOR[3])
            end
        end)
    end

    header._widgets = {}
    local WIDGET_GAP = 3
    function header:LayoutWidgets()
        local edge
        for _, w in ipairs(self._widgets) do
            if w.frame:IsShown() then
                w.frame:ClearAllPoints()
                if edge then
                    w.frame:SetPoint("RIGHT", edge, "LEFT", -w.gap, 0)
                else
                    w.frame:SetPoint("RIGHT", self, "RIGHT", -(ns.PAGE_TITLE_HPAD or 8), 2)
                end
                edge = w.frame
            end
        end
    end
    function header:AddHeaderWidget(frame, gap)
        local existing
        for _, w in ipairs(self._widgets) do
            if w.frame == frame then
                existing = w
                break
            end
        end
        if existing then
            if gap then existing.gap = gap end
        else
            self._widgets[#self._widgets + 1] = { frame = frame, gap = gap or WIDGET_GAP }
        end
        frame:SetParent(self)
        if not frame._hdrLayoutHooked then
            frame._hdrLayoutHooked = true
            hooksecurefunc(frame, "Show", function()
                header:LayoutWidgets()
            end)
            hooksecurefunc(frame, "Hide", function()
                header:LayoutWidgets()
            end)
            hooksecurefunc(frame, "SetShown", function()
                header:LayoutWidgets()
            end)
        end
        self:LayoutWidgets()
        return frame
    end

    return header
end

function ns.SetCollapsed(content, header, collapsed)
    if collapsed then
        content:Hide()
        if header.arrow then header.arrow:SetTexture("Interface\\Buttons\\UI-PlusButton-Up") end
    else
        content:Show()
        if header.arrow then header.arrow:SetTexture("Interface\\Buttons\\UI-MinusButton-Up") end
    end
end

function ns.RenderEmptyState(content, message)
    if not content then return end
    content._stackHeight = nil
    for i = 1, select("#", content:GetChildren()) do
        local child = select(i, content:GetChildren())
        if child ~= content.emptyMsg then child:Hide() end
    end
    local msg = content.emptyMsg
    if not msg then
        msg = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        msg:SetJustifyH("LEFT")
        msg:SetWordWrap(true)
        msg:SetTextColor(0.5, 0.5, 0.5)
        content.emptyMsg = msg
    end
    msg:ClearAllPoints()
    msg:SetPoint("TOPLEFT", 4, -4)
    msg:SetPoint("RIGHT", -4, 0)
    local line = message or ""
    if ns.DISCORD_URL then
        line = line .. "\n|cff9a9a9a" .. (ns.L and ns.L["empty.report_discord"] or "Report issues on Discord") .. "|r"
    end
    msg:SetText(line)
    msg:Show()
    content:SetHeight(math.max(msg:GetStringHeight() + 8, 1))
end

function ns.MakeCollapsible(section, header, content, opts)
    opts = opts or {}

    ns.SetCollapsed(content, header, false)
    if header.arrow then header.arrow:Hide() end
    header:EnableMouse(false)
    header:SetScript("OnEnter", nil)
    header:SetScript("OnLeave", nil)
    header:SetScript("OnClick", nil)

    section.header = header
    section.content = content
    section.IsCollapsed = function()
        return false
    end

    if opts.info and ns.CreateHelpIcon then header:AddHeaderWidget(ns.CreateHelpIcon(header, opts.info)) end
    if opts.headerWidgets then
        for _, w in ipairs(opts.headerWidgets) do
            header:AddHeaderWidget(w)
        end
    end

    return section
end

function ns.CreateCollapsibleSection(parent, opts)
    opts = opts or {}
    local section = CreateFrame("Frame", nil, parent)
    section:SetHeight(ns.SECTION_HEADER_HEIGHT or 24)
    local header = ns.CreateSectionHeader(section, opts.label, opts.collapsible)
    local content = CreateFrame("Frame", nil, section)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    content:SetPoint("RIGHT", 0, 0)
    ns.MakeCollapsible(section, header, content, opts)
    return section, header, content
end
