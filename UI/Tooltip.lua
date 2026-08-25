local _, ns = ...

-- Palette follows the Blizzard tooltip convention: white titles
-- (HIGHLIGHT_FONT_COLOR) and yellow descriptive text (NORMAL_FONT_COLOR).
-- Color escapes embedded in a line (e.g. item links, which carry their
-- quality color) always win, so links keep rendering correctly.
local C = {
    title = { 1, 1, 1 },
    intro = { 1, 0.82, 0 },
    body = { 1, 0.82, 0 },
    muted = { 0.6, 0.6, 0.6 },
    hint = { 1, 0.82, 0 },
    warning = { 1, 0.65, 0.15 },
    valueLeft = { 0.85, 0.85, 0.85 },
    valueRight = { 1, 1, 1 },
}

local T = {}
ns.Tooltip = T
T.COLORS = C

local function line(text, c)
    if text == nil then return T end
    GameTooltip:AddLine(text, c[1], c[2], c[3], true)
    return T
end

function T.Open(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    return T
end

function T.Title(text)
    GameTooltip:SetText(text or "", C.title[1], C.title[2], C.title[3])
    return T
end

function T.Head(text, kind)
    local c = C[kind] or C.title
    GameTooltip:SetText(text or "", c[1], c[2], c[3])
    return T
end

function T.Intro(text)
    return line(text, C.intro)
end

function T.Body(text)
    return line(text, C.body)
end

function T.Muted(text)
    return line(text, C.muted)
end

function T.Hint(text)
    return line(text, C.hint)
end

function T.Warning(text)
    return line(text, C.warning)
end

function T.Line(text, kind)
    return line(text, C[kind] or C.body)
end

function T.Blank()
    GameTooltip:AddLine(" ")
    return T
end

function T.Double(left, right, leftKind, rightKind)
    local lc = C[leftKind or "valueLeft"] or C.valueLeft
    local rc = C[rightKind or "valueRight"] or C.valueRight
    GameTooltip:AddDoubleLine(left, right, lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
    return T
end

function T.Show()
    GameTooltip:Show()
    return T
end

--- Style a Menu element tooltip (the `tip` a SetTooltip callback receives)
--- with this component's palette — menu tips are separate frames, so the
--- colors are applied explicitly rather than through the GameTooltip
--- wrappers above. One look for every tooltip in the addon.
function T.MenuTip(tip, title, body)
    if not tip then return end
    if title and GameTooltip_SetTitle then GameTooltip_SetTitle(tip, title) end
    if body then tip:AddLine(body, C.body[1], C.body[2], C.body[3], true) end
end

function T.Hide()
    GameTooltip:Hide()
    return T
end

local HELP_TEX = "Interface\\Common\\help-i"
local HELP_IDLE = { 0.7, 0.7, 0.7, 0.9 }
local HELP_HOVER = { 1, 1, 1, 1 }

function ns.CreateHelpIcon(parent, opts)
    opts = opts or {}
    local anchor = opts.tooltipAnchor or "ANCHOR_LEFT"

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(opts.size or 16, opts.size or 16)
    btn:SetPoint("RIGHT", parent, "RIGHT", -(opts.inset or 4), 0)

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(HELP_TEX)
    tex:SetVertexColor(HELP_IDLE[1], HELP_IDLE[2], HELP_IDLE[3], HELP_IDLE[4])

    btn:SetScript("OnEnter", function(self)
        tex:SetVertexColor(HELP_HOVER[1], HELP_HOVER[2], HELP_HOVER[3], HELP_HOVER[4])
        T.Open(self, anchor)
        if opts.title then T.Title(opts.title) end
        if opts.intro then T.Intro(opts.intro) end
        if opts.highlight then T.Blank().Intro(opts.highlight) end
        if opts.warning then T.Blank().Warning(opts.warning) end
        if opts.lines and #opts.lines > 0 then
            T.Blank()
            for _, l in ipairs(opts.lines) do
                T.Body(l)
            end
        end
        T.Show()
    end)
    btn:SetScript("OnLeave", function()
        tex:SetVertexColor(HELP_IDLE[1], HELP_IDLE[2], HELP_IDLE[3], HELP_IDLE[4])
        T.Hide()
    end)
    return btn
end

function ns.CreateSourceAttributionIcon(parent, sourceKey, title, subtitle, urlFn)
    local icon = CreateFrame("Button", nil, parent)
    icon:SetSize(14, 14)
    local tex = icon:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(ns.SourceTexturePath and ns.SourceTexturePath(sourceKey) or "")
    tex:SetVertexColor(0.6, 0.6, 0.6)
    icon:Hide()
    icon:SetScript("OnEnter", function(self)
        tex:SetVertexColor(1, 1, 1)
        T.Open(self, "ANCHOR_RIGHT").Title(title).Intro(subtitle).Show()
    end)
    icon:SetScript("OnLeave", function()
        tex:SetVertexColor(0.6, 0.6, 0.6)
        T.Hide()
    end)
    icon:SetScript("OnClick", function(self)
        local url = urlFn and urlFn()
        if url and ns.ShowCopyPopup then ns.ShowCopyPopup(url, self) end
    end)
    return icon
end
