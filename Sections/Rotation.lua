local _, ns = ...
ns.Sections = ns.Sections or {}

local L = ns.L

local Rotation = {}
ns.Sections.Rotation = Rotation

-- Longest list in the data is 33 steps (Marksmanship AoE); 40 leaves headroom.
local MAX_STEPS = 40
local STEP_GAP = 7
local TOP_PAD = 2
local ICON_SIZE = 18
local RIGHT_PAD = 10
local NOTE_GAP = 2
-- A noted row carries the note's own leading, so it takes a slightly
-- smaller gap to the next step than plain rows do.
local NOTE_STEP_GAP = 3
-- Left edge of the step text (icon block: 24px inset + ICON_SIZE + 8px gap).
local STEP_TEXT_X = 24 + ICON_SIZE + 8

local function makeStepHelpers(opts)
    return {
        shouldShow = opts.shouldShow or function()
            return true
        end,
        strip = opts.strip or function(s)
            return s
        end,
        getIcon = opts.getIcon or function()
            return "Interface\\Icons\\INV_Misc_QuestionMark"
        end,
        format = opts.format or function(s)
            return s
        end,
    }
end

local function rowTotalHeight(row)
    local base = row.stepH or ns.ROW_HEIGHT
    -- Noted rows stack top-down (text, NOTE_GAP, note, 2px edges), so the
    -- note hugs its step instead of riding on the padded single-line height.
    if row.hasNote and row.noteFullH and row.noteFullH > 0 then
        return math.max(ns.ROW_HEIGHT, (row.textH or base) + NOTE_GAP + row.noteFullH + 4)
    end
    return base
end

local function layoutRows(inst)
    local y = -TOP_PAD
    for _, row in ipairs(inst.shownRows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", inst.content, "TOPLEFT", 0, y)
        row:SetPoint("RIGHT", inst.content, "RIGHT", -RIGHT_PAD, 0)
        row:SetHeight(rowTotalHeight(row))
        y = y - rowTotalHeight(row) - (row.hasNote and NOTE_STEP_GAP or STEP_GAP)
    end
    local total = math.abs(y)
    inst.content:SetHeight(math.max(total, 1))
    return total
end

local function makeCtxCog(inst)
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
            .Title(L["section.rotation"] or "Rotation")
            .Hint("Click to switch rotation.")
            .Show()
    end)
    cog:SetScript("OnLeave", function()
        icon:SetVertexColor(0.6, 0.6, 0.6)
        ns.Tooltip.Hide()
    end)
    cog:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        local opts = inst.contextOptions
        if not opts or #opts < 2 then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle(L["section.rotation"] or "Rotation")
            for _, label in ipairs(opts) do
                root:CreateRadio(label, function()
                    return inst.currentContext == label
                end, function()
                    if inst.onCtxPick then inst.onCtxPick(label) end
                    return MenuResponse.Refresh
                end)
            end
        end)
    end)
    cog:Hide()
    inst.ctxCog = cog
    if ns.MakeCogGlow then
        ns.MakeCogGlow(cog, icon)
        ns.MakeLabelMenuHotspot(inst.header, cog)
    end
    inst.header:AddHeaderWidget(cog)
end

local function makeStepRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ns.ROW_HEIGHT)

    local iconFrame = CreateFrame("Frame", nil, row)
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetPoint("TOPLEFT", 24, -2)
    local border = iconFrame:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 0.85)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(iconFrame)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon
    row.iconFrame = iconFrame

    local rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rank:SetPoint("RIGHT", iconFrame, "LEFT", -5, 0)
    rank:SetJustifyH("RIGHT")
    rank:SetTextColor(0.55, 0.55, 0.55)
    row.rank = rank

    -- SimpleHTML (not a plain FontString) so spell-name links fire OnHyperlinkEnter
    local stepText = CreateFrame("SimpleHTML", nil, row)
    stepText:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 8, 2)
    -- FontInstance setters on SimpleHTML take a textType first arg ("p", "h1", ...)
    stepText:SetFontObject("p", "GameFontHighlight")
    stepText:SetJustifyH("p", "LEFT")
    stepText:SetTextColor("p", 0.86, 0.86, 0.86)
    row.stepText = stepText

    iconFrame:EnableMouse(true)
    iconFrame:SetScript("OnEnter", function(self)
        local row = self:GetParent()
        if row.itemId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(row.itemId)
            GameTooltip:Show()
        elseif row.spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(row.spellId)
            GameTooltip:Show()
        end
    end)
    iconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    stepText:EnableMouse(true)
    stepText:SetScript("OnHyperlinkEnter", function(self, link)
        local itemId = tonumber(link and link:match("^item:(%d+)"))
        local spellId = tonumber(link and link:match("^spell:(%d+)"))
        if itemId or spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if itemId then
                GameTooltip:SetItemByID(itemId)
            else
                GameTooltip:SetSpellByID(spellId)
            end
            GameTooltip:Show()
        end
    end)
    stepText:SetScript("OnHyperlinkLeave", function()
        GameTooltip:Hide()
    end)

    local note = CreateFrame("SimpleHTML", nil, row)
    note:SetFontObject("p", "GameFontHighlightSmall")
    note:SetJustifyH("p", "LEFT")
    note:SetTextColor("p", 0.62, 0.66, 0.72)
    note:EnableMouse(true)
    note:SetScript("OnHyperlinkEnter", function(self, link)
        local itemId = tonumber(link and link:match("^item:(%d+)"))
        local spellId = tonumber(link and link:match("^spell:(%d+)"))
        if itemId or spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if itemId then
                GameTooltip:SetItemByID(itemId)
            else
                GameTooltip:SetSpellByID(spellId)
            end
            GameTooltip:Show()
        end
    end)
    note:SetScript("OnHyperlinkLeave", function()
        GameTooltip:Hide()
    end)
    note:Hide()
    row.note = note
    return row
end

local function build(inst, opts, collapsible)
    inst.section = CreateFrame("Frame", nil, opts.parent)
    inst.baseTitle = L["section.rotation"] or "Rotation"
    inst.header = (opts.header or opts.headerFactory)(inst.section, inst.baseTitle, collapsible)
    inst.content = CreateFrame("Frame", nil, inst.section)
    inst.content:SetPoint("TOPLEFT", inst.header, "BOTTOMLEFT", 0, 0)
    inst.content:SetPoint("RIGHT", 0, 0)
    inst.content:SetHeight(400)

    makeCtxCog(inst)

    inst.ivIcon = ns.CreateSourceAttributionIcon(inst.header, "icyveins", "Rotation", "Data from Icy Veins", function()
        if ns.ResolveAttribution and ns.GetClassAndSpec then
            local class, spec = ns.GetClassAndSpec()
            local _, url = ns.ResolveAttribution("rotation", class, spec)
            return url
        end
    end)
    if inst.header.AddHeaderWidget then inst.header:AddHeaderWidget(inst.ivIcon) end

    inst.rows = {}
    inst.shownRows = {}
    for i = 1, MAX_STEPS do
        inst.rows[i] = makeStepRow(inst.content)
    end

    inst.fallback = CreateFrame("Frame", nil, inst.content)
    inst.fallback:SetHeight(20)
    inst.fallbackText = inst.fallback:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    inst.fallbackText:SetPoint("LEFT", 0, 0)
    inst.fallbackText:SetPoint("RIGHT", 0, 0)
    inst.fallbackText:SetJustifyH("LEFT")
    inst.fallbackText:SetTextColor(0.5, 0.5, 0.5)
    inst.fallback:Hide()
end

local function render(inst, args)
    local options = args.contextOptions or {}
    local showCtx = #options > 1
    inst.contextOptions = options
    inst.currentContext = args.currentContext
    inst.onCtxPick = args.onCtxChange
    if inst.ctxCog then inst.ctxCog:SetShown(showCtx) end

    if inst.header and inst.header.label then
        local base = inst.baseTitle or L["section.rotation"] or "Rotation"
        if showCtx and inst.currentContext and inst.currentContext ~= "" then
            inst.header.label:SetText(base .. " · " .. inst.currentContext)
        else
            inst.header.label:SetText(base)
        end
    end

    if inst.ivIcon then
        local curSource = args.source or (ns.ActiveSource and ns.ActiveSource()) or "icyveins"
        inst.ivIcon:SetShown(curSource ~= "icyveins")
    end

    for i = 1, MAX_STEPS do
        local r = inst.rows[i]
        if r.note then r.note:Hide() end
        r:Hide()
    end
    wipe(inst.shownRows)
    inst.fallback:Hide()
    if inst.content.emptyMsg then inst.content.emptyMsg:Hide() end

    local h = makeStepHelpers(args.helpers or {})
    local rotation = args.rotation
    local hero = args.heroTalent
    local textW = (args.textAreaWidth or 200) - RIGHT_PAD

    if rotation then
        local visibleStep = 0
        for _, step in ipairs(rotation.steps) do
            -- Steps may carry structured hero conditions (source per-hero
            -- rotation presets): unpack the text and apply the hero filter
            -- before the text-based heuristics.
            local stepText = step
            local note = nil
            local heroOk = true
            local heroTagged = false
            if type(step) == "table" then
                stepText = step.text
                note = step.note
                if step.heroRequired and #step.heroRequired > 0 then
                    -- Hero-specific step: shown only for a matching hero
                    -- selection (none selected = shared skeleton only).
                    heroTagged = true
                    heroOk = false
                    for _, allowed in ipairs(step.heroRequired) do
                        if hero and allowed == hero then
                            heroOk = true
                            break
                        end
                    end
                end
                if heroOk and hero and step.heroExcluded then
                    for _, banned in ipairs(step.heroExcluded) do
                        if banned == hero then
                            heroOk = false
                            break
                        end
                    end
                end
            end
            if heroOk and h.shouldShow(stepText, hero, heroTagged) then
                visibleStep = visibleStep + 1
                if visibleStep > MAX_STEPS then break end
                local row = inst.rows[visibleStep]
                row:Show()
                row.rank:SetText(visibleStep .. ".")
                row.icon:SetTexture(h.getIcon(stepText))
                local cleanStep = h.strip(stepText)
                -- Tooltip follows the same rule as the icon: the step's PRIMARY
                -- reference (first by position), not whichever item link happens
                -- to appear later in the sentence.
                local itemPos, _, itemId = cleanStep:find("{item:(%d+)")
                local spellPos, _, spellId = cleanStep:find("{(%d+)}")
                if itemId and itemPos and (not spellPos or itemPos < spellPos) then
                    row.itemId = tonumber(itemId)
                    row.spellId = nil
                else
                    row.itemId = nil
                    row.spellId = spellId and tonumber(spellId) or nil
                end
                local hasNote = note ~= nil and note ~= ""
                row.hasNote = hasNote
                row.stepText:SetWidth(textW)
                row.stepText:SetText(h.format(cleanStep))
                local textHeight = row.stepText:GetContentHeight() or 12
                -- A wrapped line block reads as taller than the same text at an
                -- unbounded width; single-line steps center in the row, wrapped
                -- ones align to the top so icon, text and note share a top edge.
                row.stepText:SetWidth(4096)
                local oneLineH = row.stepText:GetContentHeight() or textHeight
                row.stepText:SetWidth(textW)
                row.stepText:SetHeight(textHeight)
                row.textH = textHeight
                row.stepH = math.max(ns.ROW_HEIGHT, textHeight + 8)
                row.stepText:ClearAllPoints()
                if hasNote or textHeight > oneLineH + 1 then
                    -- A noted step stacks top-down (text, gap, note), so it
                    -- always aligns to the top, wrapped or not.
                    row.stepText:SetPoint("TOPLEFT", row, "TOPLEFT", STEP_TEXT_X, -2)
                else
                    row.stepText:SetPoint("TOPLEFT", row, "TOPLEFT", STEP_TEXT_X, -((row.stepH - textHeight) / 2))
                end
                if hasNote then
                    row.note:SetPoint("TOPLEFT", row.stepText, "BOTTOMLEFT", 0, -NOTE_GAP)
                    row.note:SetWidth(textW)
                    row.note:SetText(h.format(note))
                    row.noteFullH = row.note:GetContentHeight() or 0
                    row.note:SetHeight(row.noteFullH)
                    row.note:Show()
                else
                    row.noteFullH = 0
                end
                inst.shownRows[#inst.shownRows + 1] = row
            end
        end
        local total = layoutRows(inst)
        inst.section:Show()
        return total
    elseif args.hasAnyRotation then
        inst.fallback:SetHeight(ns.ROW_HEIGHT)
        inst.fallbackText:SetJustifyH("LEFT")
        inst.fallbackText:SetText(L["empty.no_rotation_for_details"]:format(hero or ""))
        inst.fallback:ClearAllPoints()
        inst.fallback:SetPoint("TOPLEFT", inst.content, "TOPLEFT", 0, 0)
        inst.fallback:SetPoint("RIGHT", inst.content, "RIGHT", 0, 0)
        inst.fallback:Show()
        inst.section:Show()
        return ns.ROW_HEIGHT
    else
        local BLOCK_H = ns.ROW_HEIGHT * 2
        inst.fallback:SetHeight(BLOCK_H)
        inst.fallbackText:SetJustifyH("CENTER")
        inst.fallbackText:SetText(L["empty.no_rotation_available"])
        inst.fallback:ClearAllPoints()
        inst.fallback:SetPoint("TOPLEFT", inst.content, "TOPLEFT", 0, -8)
        inst.fallback:SetPoint("RIGHT", inst.content, "RIGHT", 0, 0)
        inst.fallback:Show()
        inst.section:Show()
        return BLOCK_H + 16
    end
end

local function contentHeight(inst)
    local h = 0
    local anyRow = false
    for i = 1, MAX_STEPS do
        if inst.rows[i]:IsShown() then
            h = h + inst.rows[i]:GetHeight() + STEP_GAP
            anyRow = true
        end
    end
    if anyRow then h = h + TOP_PAD end
    if inst.fallback:IsShown() then h = h + inst.fallback:GetHeight() end
    return h
end

local function placeCtxCog(inst, title)
    local cog = inst.ctxCog
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

local panel = {}
local comp = {}

function Rotation.InitPanel(opts)
    build(panel, opts, false)
    placeCtxCog(panel, opts.cogTitle)
    return panel.section, panel.header, panel.content
end

function Rotation.RenderPanel(args)
    return render(panel, args)
end

function Rotation.InitCompendium(opts)
    build(comp, opts, true)
    placeCtxCog(comp, opts.cogTitle)
    comp.header:SetScript("OnClick", function()
        comp.collapsed = not comp.collapsed
        ns.SetCollapsed(comp.content, comp.header, comp.collapsed)
        if opts.refresh then opts.refresh() end
    end)
    return comp.section, comp.header, comp.content
end

function Rotation.RenderCompendium(args)
    return render(comp, args)
end

function Rotation.GetCompendiumContentHeight()
    return contentHeight(comp)
end
