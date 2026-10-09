local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

-- The empty state shown on each PvP-relevant tab when the active source
-- publishes no PvP guide for the spec (e.g. the tank specs on Icy Veins):
-- a centered line plus, when another source has PvP data for the spec, an
-- About-style link row that switches to it. No data is borrowed or substituted. One state
-- per tab, so every tab page keeps its own anchor. The docked panel and the
-- Compendium each own an instance. Costs nothing until PvP has no guide.
local PvpEmpty = {}
ns.Sections.PvpEmpty = PvpEmpty

local TOP_PAD = 24
local LINE_H = 20
local ROW_GAP = 4
-- Row chrome around the label: icon inset + icon + gap, marker gap + marker + inset.
local ROW_CHROME = 11 + 18 + 10 + 6 + 13 + 11
local ROW_H = 38
local BOTTOM_PAD = 24
local SWITCH_MARKER = "Interface\\AddOns\\BreadClassCodex\\Media\\arrow-right"

-- "<icon> <Source> PvP guide not available." for the given source key.
function PvpEmpty.Text(source)
    local fmt = L["empty.no_pvp_guide"] or "%s PvP guide not available."
    local label = ns.SourceLabelText and ns.SourceLabelText(source) or ""
    return fmt:format(label)
end

-- First other source with PvP data for the spec, or nil.
function PvpEmpty.AlternateSource(source, class, spec)
    if not (ns.Sources and ns.HasPvpGuide) then return nil end
    for _, s in ipairs(ns.Sources()) do
        if s ~= source and ns.HasPvpGuide(s, class, spec) then return s end
    end
    return nil
end

-- opts.parent: frame the states live in.
-- opts.onSwitch(sourceKey): called when the button is clicked.
-- opts.topPad / opts.rowGap: optional spacing overrides per surface.
function PvpEmpty.New(opts)
    local inst = { cards = {}, shown = false, text = "", alt = nil }
    local topPad = opts.topPad or TOP_PAD
    local rowGap = opts.rowGap or ROW_GAP

    local function build()
        local card = {}
        card.section = CreateFrame("Frame", nil, opts.parent)
        card.section._hideHeader = true
        card.content = CreateFrame("Frame", nil, card.section)
        card.content:SetPoint("TOPLEFT", card.section, "TOPLEFT", 0, 0)
        card.content:SetPoint("RIGHT", card.section, "RIGHT", 0, 0)

        -- Centered, like the panel's own empty state.
        card.text = card.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        card.text:SetPoint("TOP", card.content, "TOP", 0, -topPad)
        card.text:SetHeight(LINE_H)
        card.text:SetJustifyH("CENTER")
        card.text:SetWordWrap(false)
        card.text:SetTextColor(1, 1, 1)

        card.row = nil
        card.section:Hide()
        return card
    end

    -- About-tab link row (ns.AboutLinkRow), built on first need.
    local function ensureRow(card)
        if card.row or not ns.AboutLinkRow then return card.row end
        card.row = ns.AboutLinkRow(card.content, {
            icon = ns.SourceTexturePath and ns.SourceTexturePath(inst.alt),
            label = "",
            alpha = 0.75,
            round = true,
            marker = SWITCH_MARKER,
            onClick = function()
                if inst.alt and opts.onSwitch then opts.onSwitch(inst.alt) end
            end,
        })
        card.row:SetHeight(ROW_H)
        card.row:SetPoint("TOP", card.text, "BOTTOM", 0, -rowGap)
        return card.row
    end

    local function height()
        if not inst.shown then return 0 end
        local h = topPad + LINE_H + BOTTOM_PAD
        if inst.alt then h = h + rowGap + ROW_H end
        return h
    end

    local function apply(card)
        card.text:SetText(inst.text)
        if inst.alt and ensureRow(card) then
            local src = ns.SOURCES and ns.SOURCES[inst.alt]
            local fmt = L["empty.pvp_switch_source"] or "View %s PvP"
            card.row.label:SetText(fmt:format(src and src.name or ""))
            card.row.icon:SetTexture(ns.SourceTexturePath and ns.SourceTexturePath(inst.alt))
            if src and src.color then card.row:SetBackgroundColor(src.color[1], src.color[2], src.color[3], 0.75) end
            -- Same width as the line above it, never narrower than its own label.
            local textW = card.text:GetStringWidth() or 0
            local labelW = (card.row.label:GetStringWidth() or 0) + ROW_CHROME
            card.row:SetWidth(math.max(textW, labelW) + 16)
            card.row:Show()
        elseif card.row then
            card.row:Hide()
        end
        local h = height()
        card.content:SetHeight(math.max(h, 1))
        card.section:SetHeight(math.max(h, 1))
        card.section:SetShown(inst.shown)
    end

    -- The state for one tab, created on first use: section, content, height.
    function inst:Get(key)
        local card = self.cards[key]
        if not card then
            card = build()
            self.cards[key] = card
        end
        apply(card)
        return card.section, card.content, height()
    end

    -- args.shown, args.source (active source), args.class, args.spec.
    -- Returns the per-tab height (0 when hidden).
    function inst:Render(args)
        self.shown = (args and args.shown) and true or false
        self.text = self.shown and PvpEmpty.Text(args.source) or ""
        self.alt = self.shown and PvpEmpty.AlternateSource(args.source, args.class, args.spec) or nil
        for _, card in pairs(self.cards) do
            apply(card)
        end
        return height()
    end

    return inst
end
