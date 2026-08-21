local _, ns = ...

local DEFAULT_ICON_SIZE = 32
local DEFAULT_SLOT_RATIO = 1.8125
local DEFAULT_ICON_TRIM = 0.08
local DEFAULT_MARKER_SIZE = 20
local DEFAULT_MARKER_INSET = 7
local EMPTY_ATLAS = "auctionhouse-itemicon-empty"
local SLOT_TEXTURE = "Interface\\Buttons\\UI-Quickslot2"

local function AtlasExists(name)
    if not name then return false end
    if not C_Texture or not C_Texture.GetAtlasInfo then return false end
    return C_Texture.GetAtlasInfo(name) ~= nil
end

local CORNER_LAYOUT = {
    topleft = { point = "TOPLEFT", dx = -1, dy = 1 },
    topright = { point = "TOPRIGHT", dx = 1, dy = 1 },
    bottomleft = { point = "BOTTOMLEFT", dx = -1, dy = -1 },
    bottomright = { point = "BOTTOMRIGHT", dx = 1, dy = -1 },
}

ns.SlotIconMarkers = {
    source_icyveins = {

        corner = "topleft",
        spec = {
            texture = "Interface\\AddOns\\BreadClassCodex\\Media\\icyveins",
            size = 13,
        },
    },
    owned = {
        corner = "topright",
        spec = {

            atlas = "common-icon-checkmark",
            texture = "Interface\\Buttons\\UI-CheckBox-Check",
            size = 16,
        },
    },
}

local function CreateMarkerTexture(icon, corner, offsetX, offsetY)
    local layout = CORNER_LAYOUT[corner]
    if not layout then return nil end
    local tex = icon:CreateTexture(nil, "OVERLAY", nil, 1)
    tex:SetSize(icon._opts.markerSize, icon._opts.markerSize)
    tex:SetPoint(
        layout.point,
        icon,
        layout.point,
        layout.dx * icon._opts.markerInset + (offsetX or 0),
        layout.dy * icon._opts.markerInset + (offsetY or 0)
    )
    tex:Hide()
    return tex
end

local function RepositionMarker(icon, tex, corner, offsetX, offsetY)
    local layout = CORNER_LAYOUT[corner]
    if not layout then return end
    tex:ClearAllPoints()
    tex:SetPoint(
        layout.point,
        icon,
        layout.point,
        layout.dx * icon._opts.markerInset + (offsetX or 0),
        layout.dy * icon._opts.markerInset + (offsetY or 0)
    )
end

local function ApplySpec(tex, spec)
    if not spec then
        tex:Hide()
        return
    end
    local applied = false
    if AtlasExists(spec.atlas) then
        tex:SetAtlas(spec.atlas)
        applied = true
    elseif spec.texture then
        tex:SetTexture(spec.texture)
        applied = true
    end
    if not applied then
        tex:Hide()
        return
    end
    if spec.size then tex:SetSize(spec.size, spec.size) end
    tex:SetAlpha(spec.alpha or 1)
    if spec.vertexColor then
        tex:SetVertexColor(spec.vertexColor[1], spec.vertexColor[2], spec.vertexColor[3], spec.vertexColor[4] or 1)
    else
        tex:SetVertexColor(1, 1, 1, 1)
    end
    tex:Show()
end

local SlotIconAPI = {}

local function ResolveIconTexture(itemId)
    if not itemId or itemId == 0 then return nil end
    if C_Item and C_Item.GetItemIconByID then
        local i = C_Item.GetItemIconByID(itemId)
        if i then return i end
    end
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
    return icon
end

function SlotIconAPI:SetItem(itemId)
    self._itemId = itemId
    local tex = ResolveIconTexture(itemId)
    if tex then
        self.tex:SetTexture(tex)
        self.tex:Show()
        self.empty:Hide()
    else
        self.tex:Hide()
        self.empty:Show()
        if itemId and itemId ~= 0 and C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemId)
        end
    end
end

function SlotIconAPI:SetSpell(spellId)
    self._spellId = spellId
    local info = spellId and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
    local tex = info and info.iconID
    if tex then
        self.tex:SetTexture(tex)
        self.tex:Show()
        self.empty:Hide()
    else
        self.tex:Hide()
        self.empty:Show()
    end
end

local function ResolveMarker(icon, name)
    local preset = ns.SlotIconMarkers[name]
    if not preset then return nil end
    local offset = icon._markerOffsets[name]
    return preset, offset
end

function SlotIconAPI:SetMarkerOffset(name, offsetX, offsetY)
    self._markerOffsets[name] = { x = offsetX or 0, y = offsetY or 0 }
    local tex = self.markers[name]
    local preset = ns.SlotIconMarkers[name]
    if tex and preset then RepositionMarker(self, tex, preset.corner, offsetX, offsetY) end
end

function SlotIconAPI:SetMarkerByName(name)
    local preset, offset = ResolveMarker(self, name)
    if not preset then return end
    local tex = self.markers[name]
    if not tex then
        tex = CreateMarkerTexture(self, preset.corner, offset and offset.x or 0, offset and offset.y or 0)
        self.markers[name] = tex
    end
    ApplySpec(tex, preset.spec)
end

function SlotIconAPI:ClearMarkerByName(name)
    local tex = self.markers[name]
    if tex then tex:Hide() end
end

function SlotIconAPI:ClearAllMarkers()
    for _, tex in pairs(self.markers) do
        tex:Hide()
    end
end

function SlotIconAPI:ToggleMarker(name, shown)
    if shown then
        self:SetMarkerByName(name)
    else
        self:ClearMarkerByName(name)
    end
end

function SlotIconAPI:SetDesaturated(flag)
    self.tex:SetDesaturated(flag and true or false)
end

function ns.CreateSlotIcon(parent, opts)
    opts = opts or {}
    local size = opts.size or DEFAULT_ICON_SIZE
    local slotSize = opts.slotSize or math.floor(size * (opts.slotRatio or DEFAULT_SLOT_RATIO) + 0.5)
    local iconTrim = opts.iconTrim or DEFAULT_ICON_TRIM
    local markerSize = opts.markerSize or DEFAULT_MARKER_SIZE
    local markerInset = opts.markerInset or DEFAULT_MARKER_INSET

    local btn = CreateFrame("Frame", nil, parent)
    btn:SetSize(size, size)
    btn._opts = {
        size = size,
        slotSize = slotSize,
        markerSize = markerSize,
        markerInset = markerInset,
    }
    btn.markers = {}
    btn._markerOffsets = {}

    local empty = btn:CreateTexture(nil, "ARTWORK", nil, -1)
    empty:SetAtlas(EMPTY_ATLAS)
    empty:SetAllPoints()
    empty:SetAlpha(0.7)
    btn.empty = empty

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(iconTrim, 1 - iconTrim, iconTrim, 1 - iconTrim)
    btn.tex = tex

    local slot = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    slot:SetTexture(SLOT_TEXTURE)
    slot:SetSize(slotSize, slotSize)
    slot:SetPoint("CENTER", btn, "CENTER")
    btn.slot = slot

    for k, v in pairs(SlotIconAPI) do
        btn[k] = v
    end

    return btn
end

local TABLE_ICON_SIZE = 16
local TABLE_SLOT_FRAME = math.floor(TABLE_ICON_SIZE * 1.8125 + 0.5)
ns.TABLE_ROW_HEIGHT = 20

function ns.MakeTableRow(content)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(ns.TABLE_ROW_HEIGHT)

    row.icon = ns.CreateSlotIcon(row, { size = TABLE_ICON_SIZE, slotSize = TABLE_SLOT_FRAME })
    row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", row.icon.slot, "RIGHT", 4, 0)
    label:SetWidth(55)
    label:SetJustifyH("LEFT")
    label:SetTextColor(0.6, 0.6, 0.6)
    row.labelText = label

    local check = row:CreateTexture(nil, "OVERLAY")
    check:SetSize(14, 14)
    check:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    check:SetAtlas("common-icon-checkmark")
    check:SetVertexColor(0.4, 1.0, 0.4)
    check:Hide()
    row.checkmark = check

    local source = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    source:SetPoint("RIGHT", check, "LEFT", -4, 0)
    source:SetJustifyH("RIGHT")
    source:SetWordWrap(false)
    source:SetTextColor(0.5, 0.5, 0.52)
    source:Hide()
    row.sourceCol = source

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", label, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.itemText = name

    ns.SetupItemTooltip(row)
    row:Hide()
    return row
end

function ns.LayoutTable(content, rows, items, opts)
    for i = 1, #rows do
        rows[i]:Hide()
    end
    local count = math.min(#items, #rows)
    if count == 0 then return 0 end

    local showSource = opts and opts.showSource
    local sourceWidth = (opts and opts.sourceWidth) or 120
    if showSource then
        -- The source column stays strictly narrower than the item-name column:
        -- the icon, label (up to 55px), gaps and checkmark take ~126px, and the
        -- two columns split the remainder — capping below half of it (with a
        -- 2px margin) always leaves the name the wider one.
        local cap = math.floor(((content:GetWidth() or 0) - 128) / 2)
        if cap > 0 and sourceWidth > cap then sourceWidth = cap end
    end

    for i = 1, count do
        local item = items[i]
        local row = rows[i]

        row.labelText:SetText(item.label or "")
        local labelLen = #(item.label or "")
        row.labelText:SetWidth(labelLen <= 2 and 18 or 55)
        if item.labelColor then
            row.labelText:SetTextColor(item.labelColor[1], item.labelColor[2], item.labelColor[3])
        else
            row.labelText:SetTextColor(0.6, 0.6, 0.6)
        end
        local name = (item.itemId or item.spellId)
                and ns.FormatItem({ itemId = item.itemId, spellId = item.spellId, name = item.name })
            or ""
        if item.count and item.count > 1 then name = name .. "  |cff808080×" .. item.count .. "|r" end
        row.itemText:SetText(name)

        row.itemText:ClearAllPoints()
        row.itemText:SetPoint("LEFT", row.labelText, "RIGHT", 4, 0)
        if showSource and item.sourceText and item.sourceText ~= "" then
            row.sourceCol:SetWidth(sourceWidth)
            row.sourceCol:SetText(item.sourceText)
            row.sourceCol:Show()
            row.itemText:SetPoint("RIGHT", row.sourceCol, "LEFT", -4, 0)
        else
            row.sourceCol:Hide()
            row.itemText:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        end

        if item.spellId then
            row.icon:SetSpell(item.spellId)
        elseif item.itemId then
            row.icon:SetItem(item.itemId)
        end
        row.itemId = item.itemId
        row.spellId = item.spellId
        row.bonusIDs = item.bonusIDs
        row.altItemId = nil
        row.embItemId = nil
        row.sourceText = item.sourceText
        row.popText = item.popText

        row.icon:ToggleMarker("owned", false)
        row.checkmark:SetShown(item.isOwned and true or false)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ns.TABLE_ROW_HEIGHT)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        row:Show()
    end

    return count * ns.TABLE_ROW_HEIGHT
end
