local _, ns = ...

-- U+00B7 has no glyph in the RU client's Cyrillic fonts (renders as a tofu
-- box), so every user-visible middle dot ships as a texture instead of text.
ns.DOT_SEPARATOR = "|TInterface\\AddOns\\BreadClassCodex\\Media\\dot:8:8:0:0|t"

ns.L = setmetatable({}, {
    __index = function(_, k)
        return k
    end,
    __newindex = function(t, k, v)
        if type(v) == "string" and v:find("\194\183", 1, true) then v = (v:gsub("\194\183", ns.DOT_SEPARATOR)) end
        rawset(t, k, v)
    end,
})
