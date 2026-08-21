local _, ns = ...

local SPELL_COLOR = "|cff69ccf0"

local HTML_ENTITIES = {
    amp = "&",
    lt = "<",
    gt = ">",
    quot = '"',
    apos = "'",
    nbsp = " ",
    mdash = "\226\128\148",
    ndash = "\226\128\147",
    hellip = "...",
    times = "x",
}

local function StripHtml(text)
    if not text or text == "" then return text end
    text = text:gsub("<%s*[bB][rR]%s*/?>", " ")
    text = text:gsub("<[^>]->", "")
    text = text:gsub("&#(%d+);", function(n)
        local code = tonumber(n)
        if code and code < 128 then return string.char(code) end
        return ""
    end)
    text = text:gsub("&(%a+);", function(name)
        return HTML_ENTITIES[name:lower()] or ""
    end)
    text = text:gsub("%s+", " ")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
ns.StripHtml = StripHtml

local function StripConditionPrefix(stepText)
    -- Item markers may carry a display-name fallback: {item:123|Name}
    stepText = stepText:gsub("^%?!?{%d+}:%s*", "")
    stepText = stepText:gsub("^%?!?{item:%d+[^}]*}:%s*", "")
    stepText = stepText:gsub("^%?%b():%s*", "")
    return stepText
end
ns.StripConditionPrefix = StripConditionPrefix

function ns.FormatRotationStep(stepText)
    stepText = StripHtml(stepText)
    -- SimpleHTML's parser is strict: a bare "&" (or stray "<"/">") makes the
    -- whole step render as literal markup, so escape before adding links
    stepText = stepText:gsub("&", "&amp;")
    stepText = stepText:gsub("<", "&lt;")
    stepText = stepText:gsub(">", "&gt;")
    local body = stepText:gsub("{item:(%d+)|([^}]*)}", function(id, fallback)
        local name, _, quality = GetItemInfo(tonumber(id))
        if name then
            local color = (quality and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex)
                or "|cffffffff"
            return '<A HREF="item:' .. id .. '">' .. color .. name .. "|r</A>"
        end
        -- Not in the live client (e.g. next-season tier items): render the
        -- source-provided name as plain text instead of "Unknown Item".
        if fallback and fallback ~= "" then return "|cffffffff" .. fallback .. "|r" end
        return '<A HREF="item:' .. id .. '">|cffffffffUnknown Item|r</A>'
    end)
    body = body:gsub("{item:(%d+)}", function(id)
        local name, _, quality = GetItemInfo(tonumber(id))
        name = name or "Unknown Item"
        local color = (quality and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex) or "|cffffffff"
        return '<A HREF="item:' .. id .. '">' .. color .. name .. "|r</A>"
    end)
    body = body:gsub("{(%d+)}", function(id)
        local spellId = tonumber(id)
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
        local name = (info and info.name) or "Unknown Spell"
        return '<A HREF="spell:' .. id .. '">' .. SPELL_COLOR .. name .. "|r</A>"
    end)
    return "<HTML><BODY><P>" .. body .. "</P></BODY></HTML>"
end

function ns.GetStepSpellIcon(stepText)
    local stripped = StripConditionPrefix(stepText)
    -- The icon belongs to the step's PRIMARY action — the first reference in
    -- the text by position, not the first item link: a "Cast Ascendance …
    -- sync with trinkets" step must show the spell, not the trinket.
    local itemPos, _, itemId = stripped:find("{item:(%d+)")
    local spellPos, _, spellId = stripped:find("{(%d+)}")
    if itemId and itemPos and (not spellPos or itemPos < spellPos) then
        local icon = select(10, GetItemInfo(tonumber(itemId)))
        if icon then return icon end
    end
    if spellId then
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(tonumber(spellId))
        if info and info.iconID then return info.iconID end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end
