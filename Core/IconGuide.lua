local _, ns = ...
local L = ns.L

-- Icon guide for the settings About page: one row per marker that the panels
-- and item tooltips show, drawn with the same helpers and colors the addon
-- uses, so the guide matches what players see.

local KEY_W = 62
local KEY_GAP = 8
local ROW_GAP = 4
local GROUP_GAP = 6
local HEADER_STRIDE = 22
local SUBHEADER_STRIDE = 16
local CHECK_ATLAS = "common-icon-checkmark"
local CHECK_SIZE = 14
local HEADER_ICON = "Interface\\AddOns\\BreadClassCodex\\Media\\icon"
local COG_ATLAS = "QuestLog-icon-setting"
local COL_GAP = 16
local TWO_COL_MIN = 520
local HEADER_ICON_W = 14
local HEADER_COLOR = { 1, 0.82, 0 }
local SUBHEADER_COLOR = { 0.6, 0.6, 0.66 }

local function hex(c)
    local r, g, b = c.r or c[1], c.g or c[2], c.b or c[3]
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function tierLetters()
    local parts = {}
    for _, t in ipairs({ "S", "A", "B", "C", "D" }) do
        local c = ns.TIER_COLORS and ns.TIER_COLORS[t]
        parts[#parts + 1] = c and (hex(c) .. t .. "|r") or t
    end
    return table.concat(parts, " ")
end

local function statRanks()
    local parts = {}
    for i = 1, 3 do
        local c = ns.STAT_RANK_COLORS and ns.STAT_RANK_COLORS[i]
        parts[#parts + 1] = c and (hex(c) .. "#" .. i .. "|r") or ("#" .. i)
    end
    return table.concat(parts, " ")
end

-- The player's own spec and class icons, as in the Best in Slot tooltip list.
local function specClassIcons()
    local classToken = select(2, UnitClass("player"))
    local specKey = ns.GetSpecKey and ns.GetSpecKey() or nil
    local spec = specKey and (specKey:match("-(.+)") or specKey)
    local specIcon = (classToken and spec and ns.SpecIconMarkup) and ns.SpecIconMarkup(classToken, spec) or ""
    local classIcon = (classToken and ns.ClassIconMarkup) and ns.ClassIconMarkup(classToken) or ""
    return specIcon .. "  " .. classIcon
end

-- Rows: key = markup string, keyFn = markup built at layout, or check = tick color.
local function guideGroups()
    local ticks = ns.TICK_COLORS or {}
    return {
        {
            title = L["about.icon_guide.tooltips"],
            rows = {
                { key = tierLetters(), text = L["about.icon_guide.tier"] },
                { key = ns.SourceIcon("icyveins", 14), text = L["about.icon_guide.icyveins"] },
                { key = ns.SourceIcon("ugg", 14), text = L["about.icon_guide.ugg"] },
                { keyFn = specClassIcons, text = L["about.icon_guide.spec_class"] },
                { key = statRanks(), text = L["about.icon_guide.stat_rank"] },
            },
        },
        {
            title = L["about.icon_guide.panels"],
            rows = {
                { key = "|A:" .. COG_ATLAS .. ":14:14:0:0:153:153:153|a", text = L["about.icon_guide.cog"] },
                { check = ticks.perfect or { 0.4, 1.0, 0.4 }, text = L["about.icon_guide.tick_green"] },
                { check = ticks.below or { 1.0, 0.93, 0.0 }, text = L["about.icon_guide.tick_yellow"] },
            },
        },
    }
end

function ns.BuildIconGuide(parent)
    local separator = parent:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetColorTexture(0.3, 0.3, 0.3, 0.6)

    local headerIcon = parent:CreateTexture(nil, "OVERLAY")
    headerIcon:SetSize(HEADER_ICON_W, HEADER_ICON_W)
    headerIcon:SetTexture(HEADER_ICON)

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetText(L["about.icon_guide"])
    header:SetTextColor(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3])
    header:SetJustifyH("LEFT")

    local groups = {}
    for _, g in ipairs(guideGroups()) do
        local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetText(g.title)
        title:SetTextColor(SUBHEADER_COLOR[1], SUBHEADER_COLOR[2], SUBHEADER_COLOR[3])
        title:SetJustifyH("LEFT")
        local rows = {}
        for _, r in ipairs(g.rows) do
            local row = {}
            if r.check then
                row.check = parent:CreateTexture(nil, "OVERLAY")
                row.check:SetSize(CHECK_SIZE, CHECK_SIZE)
                row.check:SetAtlas(CHECK_ATLAS)
                -- The checkmark atlas is green: tint other colors on a
                -- desaturated copy, the same way the panel ticks do.
                local c = r.check
                row.check:SetDesaturated(not (c[2] > 0.9 and c[1] < 0.5))
                row.check:SetVertexColor(c[1], c[2], c[3])
            else
                row.key = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.key:SetJustifyH("LEFT")
                row.key:SetWordWrap(false)
                row.key:SetText(r.key or "")
                row.keyFn = r.keyFn
            end
            row.text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetJustifyH("LEFT")
            row.text:SetText(r.text)
            row.text:SetTextColor(0.85, 0.85, 0.85)
            rows[#rows + 1] = row
        end
        groups[#groups + 1] = { title = title, rows = rows }
    end

    local function placeRows(g, x, y, colW)
        g.title:ClearAllPoints()
        g.title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        y = y - SUBHEADER_STRIDE
        local textX = x + KEY_W + KEY_GAP
        local textW = math.max(60, colW - KEY_W - KEY_GAP)
        for _, row in ipairs(g.rows) do
            row.text:SetWidth(textW)
            row.text:ClearAllPoints()
            row.text:SetPoint("TOPLEFT", parent, "TOPLEFT", textX, y)
            local textH = math.max(row.text:GetStringHeight() or 12, 12)
            local keyH = CHECK_SIZE
            if row.check then
                row.check:ClearAllPoints()
                row.check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y + 1)
            else
                -- Spec and class icons resolve once the player's spec is known.
                if row.keyFn then row.key:SetText(row.keyFn()) end
                row.key:SetWidth(KEY_W)
                row.key:ClearAllPoints()
                row.key:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y + 2)
                keyH = row.key:GetStringHeight() or 14
            end
            y = y - math.max(textH, keyH) - ROW_GAP
        end
        return y
    end

    -- Places the guide at y (going down) and returns the y below it. Wide
    -- canvases put the groups side by side (tooltips left, panels right).
    return function(width, y)
        y = y - 4
        separator:ClearAllPoints()
        separator:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, y)
        separator:SetPoint("RIGHT", parent, "RIGHT", -2, 0)
        y = y - 10

        headerIcon:ClearAllPoints()
        headerIcon:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, y - 1)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", 2 + HEADER_ICON_W + 4, y)
        y = y - HEADER_STRIDE

        local inner = width - 6
        if width >= TWO_COL_MIN and #groups == 2 then
            local colW = math.floor((inner - COL_GAP) / 2)
            local yl = placeRows(groups[1], 2, y, colW)
            local yr = placeRows(groups[2], 2 + colW + COL_GAP, y, colW)
            return math.min(yl, yr)
        end
        for gi, g in ipairs(groups) do
            if gi > 1 then y = y - GROUP_GAP end
            y = placeRows(g, 2, y, inner)
        end
        return y
    end
end
