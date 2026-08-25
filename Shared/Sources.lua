local _, ns = ...

local TEX = "Interface\\AddOns\\BreadClassCodex\\Media\\"

ns.DISCORD_URL = "https://discord.gg/WY7HQaVkRw"
ns.WEBSITE_URL = "https://www.icy-veins.com/download"
ns.PATREON_URL = "https://www.patreon.com/classcodex"
ns.ICYVEINS_PREMIUM_URL = "https://www.icy-veins.com/forums/premium"

ns.SOURCES = {
    icyveins = {
        key = "icyveins",
        name = "Icy Veins",
        homepage = "https://www.icy-veins.com",
        iconTex = "icyveins",
        color = { 0.30, 0.62, 0.90 },
    },
    ugg = {
        key = "ugg",
        name = "U.GG",
        homepage = "https://u.gg/wow",
        iconTex = "ugg",
        color = { 0.36, 0.09, 0.77 },
    },
    wowhead = {
        key = "wowhead",
        name = "Wowhead",
        homepage = "https://www.wowhead.com",
        iconTex = "wowhead",
        color = { 0.92, 0.62, 0.20 },
    },
    -- Keyed `archongg`, not `archon`: the Priest hero talent is already called
    -- Archon throughout the talent data, and a bare `archon` key sitting beside
    -- it at a different nesting level reads as the same thing. No runtime
    -- collision, but a genuine trap for the next reader.
    archongg = {
        key = "archongg",
        name = "Archon",
        homepage = "https://www.archon.gg/wow",
        iconTex = "archon",
        color = { 0.85, 0.31, 0.31 },
    },
}

function ns.SourceIcon(key, size, yoff)
    local src = ns.SOURCES[key]
    if not src then return "" end
    size = size or 12
    return "|T" .. TEX .. src.iconTex .. ":" .. size .. ":" .. size .. ":0:" .. (yoff or 0) .. "|t"
end

function ns.SourceLabelText(key)
    local src = ns.SOURCES[key]
    if not src then return "" end
    return ns.SourceIcon(key) .. "  " .. src.name
end

function ns.SourceTexturePath(key)
    local src = ns.SOURCES[key]
    return src and (TEX .. src.iconTex) or nil
end

local REFERRAL = "utm_source=classcodex&utm_medium=addon"
function ns.WithReferral(url)
    if not url or url == "" then return url end
    if url:find("utm_source=", 1, true) then return url end
    return url .. (url:find("?", 1, true) and "&" or "?") .. REFERRAL
end

local function linkTitle(srcName, pageLabel)
    if pageLabel and pageLabel ~= "" then return ns.L["attribution.page_title"]:format(srcName, pageLabel) end
    return ns.L["attribution.visit_source"]:format(srcName)
end

function ns.CreateSourceTag(parent, opts)
    opts = opts or {}
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(18)
    btn:RegisterForClicks("LeftButtonUp")

    local ICON = 11
    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:SetSize(ICON, ICON)
    icon:SetPoint("RIGHT", btn, "RIGHT", 0, 1)
    btn.icon = icon

    local rc = opts.textColor or { 0.5, 0.5, 0.5 }
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("RIGHT", btn, "RIGHT", -(ICON + 3), 0)
    fs:SetJustifyH("RIGHT")
    fs:SetTextColor(rc[1], rc[2], rc[3])
    btn.text = fs
    btn:Hide()

    function btn:SetSource(key, url, label)
        local src = key and ns.SOURCES[key]
        if not src then
            self.url, self.srcName, self.pageLabel = nil, nil, nil
            self:Hide()
            return
        end
        self.url = url
        self.srcName = src.name
        self.pageLabel = label

        self.icon:SetTexture(ns.SourceTexturePath(key))
        local cta = opts.noPrefix and "" or (ns.L["attribution.visit_cta"] .. " ")
        fs:SetText(cta .. src.name)
        self:SetWidth(fs:GetStringWidth() + 3 + self.icon:GetWidth() + 1)
        self:Show()
    end

    btn:SetScript("OnEnter", function(self)
        if not self.srcName then return end
        self.text:SetTextColor(0.9, 0.9, 0.9)

        if opts.tooltipAbove then
            ns.Tooltip.Open(self, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 4)
        else
            ns.Tooltip.Open(self, "ANCHOR_LEFT")
        end

        ns.Tooltip
            .Head(linkTitle(self.srcName, self.pageLabel), "title")
            .Line(ns.L["attribution.copy_url"], "body")
            .Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self.text:SetTextColor(rc[1], rc[2], rc[3])
        ns.Tooltip.Hide()
    end)
    btn:SetScript("OnClick", function(self)
        if self.url and ns.ShowCopyPopup then ns.ShowCopyPopup(self.url, self) end
    end)

    return btn
end

function ns.CreateSourceLinkIcon(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(14, 14)
    btn:RegisterForClicks("LeftButtonUp")
    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\BreadClassCodex\\Media\\link-external")
    icon:SetVertexColor(1, 0.82, 0)
    btn.icon = icon
    btn:Hide()
    btn:SetScript("OnEnter", function(self)
        local head = self.linkHead or (self.srcName and linkTitle(self.srcName, self.pageLabel))
        if not (self.url and head) then return end
        icon:SetVertexColor(1, 0.93, 0.4)
        ns.Tooltip.Open(self, "ANCHOR_RIGHT").Head(head, "title").Line(ns.L["attribution.copy_url"], "body").Show()
    end)
    btn:SetScript("OnLeave", function(self)
        icon:SetVertexColor(1, 0.82, 0)
        ns.Tooltip.Hide()
    end)
    btn:SetScript("OnClick", function(self)
        if self.url and ns.ShowCopyPopup then ns.ShowCopyPopup(self.url, self) end
    end)
    function btn:SetSource(key, url, label)
        local src = key and ns.SOURCES[key]
        self.linkHead = nil
        if not src then
            self.url, self.srcName, self.pageLabel = nil, nil, nil
            self:Hide()
            return
        end
        self.url = url
        self.srcName = src.name
        self.pageLabel = label
        self:Show()
    end
    function btn:SetLink(url, title)
        if not url then
            self.url, self.srcName, self.pageLabel, self.linkHead = nil, nil, nil, nil
            self:Hide()
            return
        end
        self.url = url
        self.srcName, self.pageLabel = nil, nil
        self.linkHead = title
        self:Show()
    end
    return btn
end

local PVP_SOURCE_ICON = ns.SourceIcon("ugg")

ns.ENH_SOURCE_LABELS = {
    ["u.gg"] = ns.SourceLabelText("ugg"),
    ["PvP"] = PVP_SOURCE_ICON .. "  U.GG (PvP)",
}

local function perSpec(specKey)
    if specKey and ClassCodexCharDB and ClassCodexCharDB.perSpec then return ClassCodexCharDB.perSpec[specKey] end
    return nil
end

-- Spec keys come in two shapes: the panel's class-prefixed form
-- ("HUNTER-beast-mastery") and the compendium's bare form ("beast-mastery").
-- Strip only a leading class prefix — a bare match("-(.+)") mangles dashed
-- spec slugs ("beast-mastery" -> "mastery") and every link built from it.
local function specFromKey(classToken, specKey)
    if type(specKey) ~= "string" then return nil end
    local prefix = (type(classToken) == "string" and classToken or ""):lower() .. "-"
    if specKey:sub(1, #prefix):lower() == prefix then return specKey:sub(#prefix + 1) end
    return specKey
end

local function playerClassSpec()
    local classToken = select(2, UnitClass("player"))
    local specKey = ns.GetSpecKey and ns.GetSpecKey()
    return classToken, specFromKey(classToken, specKey)
end

local function srcUrl(class, spec, source, page)
    if not (class and spec) then
        class, spec = playerClassSpec()
    end

    local sd = class and spec and ns.SourceSpec and ns.SourceSpec(source, class, spec)
    local links = sd and sd.links
    return links and links[page] or nil
end

local UGG_CLASS_SLUG = { DEATHKNIGHT = "death_knight", DEMONHUNTER = "demon_hunter" }
-- u.gg scopes PvE pages by content segment (…/<page>/raid?difficulty=<mythic|heroic>).
-- The site's default raid difficulty is mythic, matching the addon default.
local function uggPageUrl(class, spec, page, mode)
    if not class or not spec then return ns.WithReferral(ns.SOURCES.ugg.homepage) end
    local classSlug = UGG_CLASS_SLUG[class] or class:lower()
    local specSlug = spec:gsub("-", "_")
    local base = string.format("https://u.gg/wow/%s/%s", specSlug, classSlug)
    if page and page ~= "pvp" and mode ~= "pvp" then
        local ct = mode == "pve" and "pve"
            or (ns.Context and ns.Context.contentType and ns.Context.contentType() or nil)
        if ct == "raid" then
            local diff = (ClassCodexDB and ClassCodexDB.raidDifficulty == "heroic") and "heroic" or "mythic"
            return ns.WithReferral(base .. "/" .. page .. "/raid?difficulty=" .. diff)
        end
    end
    return ns.WithReferral(page and (base .. "/" .. page) or base)
end

local IV_CLASS_SLUG = { DEATHKNIGHT = "death-knight", DEMONHUNTER = "demon-hunter" }
local ROLE_BY_SPEC = {
    blood = "tank",
    vengeance = "tank",
    guardian = "tank",
    brewmaster = "tank",
    protection = "tank",
    restoration = "heal",
    preservation = "heal",
    mistweaver = "heal",
    holy = "heal",
    discipline = "heal",
}
local ROLE_SEG = { dps = "dps", tank = "tank", heal = "healing" }

local function ivPageUrl(class, spec, suffix)
    if not (class and spec) then return ns.WithReferral(ns.SOURCES.icyveins.homepage) end
    local classSlug = IV_CLASS_SLUG[class] or class:lower()
    local specSlug = spec:gsub("_", "-")
    local role = ROLE_SEG[ROLE_BY_SPEC[specSlug] or "dps"]
    return ns.WithReferral(
        ("https://www.icy-veins.com/wow/%s-%s-%s"):format(specSlug, classSlug, (suffix:gsub("{role}", role)))
    )
end

-- iv.data prefers the scraper's recorded canonical URL for the page the data
-- came from; iv.suffix/pvpSuffix build the canonical URL scheme otherwise.
-- uggPvp is u.gg's spec PvP page (its PvP pages are one per spec).
local SURFACES = {
    guide = { label = "Guide", iv = { data = "talents" }, ugg = "talents" },
    talents = {
        label = "Talents",
        iv = { data = "talents", pvpSuffix = "pvp-talents-and-builds" },
        ugg = "talents",
        uggPvp = "pvp",
    },
    rotation = {
        label = "Rotation",
        iv = { suffix = "pve-{role}-rotation-cooldowns-abilities", pvpSuffix = "pvp-rotation-and-playstyle" },
        ugg = "builds",
        uggPvp = "pvp",
    },
    bis = {
        label = "Gear",
        iv = { data = "bis", pvpSuffix = "pvp-stat-priority-gear-and-trinkets" },
        ugg = "gear",
        uggPvp = "pvp",
    },
    trinkets = {
        label = "Trinkets",
        iv = { data = "bis", pvpSuffix = "pvp-stat-priority-gear-and-trinkets" },
        ugg = "trinkets",
        uggPvp = "pvp",
    },
    enhancements = {
        label = "Enchants",
        iv = { suffix = "pve-{role}-gems-enchants-consumables" },
        ugg = "gems-and-enchants",
        uggPvp = "pvp",
    },
    crafting = { label = "Crafting", iv = { data = "bis" }, ugg = "gear" },
    stats = {
        label = "Stats",
        iv = { suffix = "pve-{role}-stat-priority", pvpSuffix = "pvp-stat-priority-gear-and-trinkets" },
        ugg = "gear",
        uggPvp = "pvp",
    },
    leveling = { label = "Leveling", iv = { data = "leveling", suffix = "leveling-guide" } },
}

-- Which recorded page backs each surface for the fill sources. Trinkets,
-- crafted gear, stat priority and enchants/gems all live inside the gear
-- guide, so they point at `bis`; `rotation` and `leveling` have no recorded
-- page and deliberately have no entry, so they fall back to the homepage
-- rather than silently linking somewhere wrong.
local FILL_LINK_KEYS = {
    bis          = { "bis" },
    trinkets     = { "bis" },
    crafting     = { "bis" },
    stats        = { "bis" },
    enhancements = { "bis" },
    talents      = { "talents" },
    guide        = { "talents", "bis" },
}

function ns.SourceLink(source, surface, class, spec, mode)
    local def = SURFACES[surface]
    if not def then return nil, nil end
    local isPvp = mode == "pvp"
    if source == "ugg" and def.ugg then
        local page = (isPvp and def.uggPvp) and def.uggPvp or def.ugg
        return uggPageUrl(class, spec, page, isPvp and "pvp" or nil), def.label
    end
    -- Locally scraped sources publish their own page URLs in sd.links; without
    -- this they fell into the Icy Veins branch below, which hardcodes
    -- srcUrl(..., "icyveins", ...) and so returned an icy-veins.com link for
    -- Wowhead and Archon content.
    --
    -- The key is named EXPLICITLY per surface. It used to be borrowed from
    -- upstream's own `def.iv.data`, which quietly made this lookup depend on a
    -- table the fork does not control: when 1.0.8 dropped `data` from
    -- SURFACES.stats the expression fell through to the surface name and
    -- started asking for a `links.stats` that has never existed. The scrapers
    -- record exactly two pages per spec -- `bis` (the gear guide) and
    -- `talents` -- so anything not listed here has no page and correctly
    -- falls back to the source's homepage.
    if source == "wowhead" or source == "archongg" then
        local keys = FILL_LINK_KEYS[surface]
        if keys then
            for _, key in ipairs(keys) do
                local own = srcUrl(class, spec, source, key)
                if own then return ns.WithReferral(own), def.label end
            end
        end
        local home = ns.SOURCES[source] and ns.SOURCES[source].homepage
        if home then return ns.WithReferral(home), def.label end
    end
    local iv = def.iv
    if isPvp and iv and iv.pvpSuffix then return ivPageUrl(class, spec, iv.pvpSuffix), def.label end
    if iv and iv.data then
        local dataUrl = srcUrl(class, spec, "icyveins", iv.data)
        if dataUrl then return ns.WithReferral(dataUrl), def.label end
    end
    if iv and iv.suffix then return ivPageUrl(class, spec, iv.suffix), def.label end
    return ns.WithReferral(ns.SOURCES.icyveins.homepage), def.label
end

local SOURCE_PAGE_LIST = {
    icyveins = {
        pve = {
            { label = "Overview", suffix = "pve-{role}-guide" },
            { label = "Leveling", suffix = "leveling-guide" },
            { label = "Easy Mode", suffix = "pve-{role}-easy-mode" },
            { label = "Talents", suffix = "pve-{role}-spec-builds-talents" },
            { label = "Rotation", suffix = "pve-{role}-rotation-cooldowns-abilities" },
            { label = "Gear", suffix = "pve-{role}-gear-best-in-slot" },
            { label = "Stats", suffix = "pve-{role}-stat-priority" },
            { label = "Enchants", suffix = "pve-{role}-gems-enchants-consumables" },
            { label = "Mythic+", suffix = "pve-{role}-mythic-plus-tips" },
            { label = "Macros", suffix = "pve-{role}-macros-addons" },
        },
        pvp = {
            { label = "Overview", suffix = "pvp-guide" },
            { label = "Talents", suffix = "pvp-talents-and-builds" },
            { label = "Rotation", suffix = "pvp-rotation-and-playstyle" },
            { label = "Gear & Stats", suffix = "pvp-stat-priority-gear-and-trinkets" },
            { label = "Arena", suffix = "pvp-best-arena-compositions" },
            { label = "Races", suffix = "pvp-best-races-and-racials" },
            { label = "Macros", suffix = "pvp-useful-macros" },
            { label = "BG Blitz", suffix = "battleground-blitz-pvp-guide" },
        },
    },
    ugg = {
        pve = {
            { label = "Talents", page = "talents" },
            { label = "Gear", page = "gear" },
            { label = "Enchants & Gems", page = "gems-and-enchants" },
            { label = "Builds", page = "builds" },
            { label = "Trinkets", page = "trinkets" },
        },
        pvp = {
            { label = "PvP", page = "pvp" },
        },
    },
}

local function currentMode()
    local ct = ns.Context and ns.Context.contentType and ns.Context.contentType()
    return (ct == "pvp") and "pvp" or "pve"
end

function ns.SourcePages(source, mode)
    local bySource = SOURCE_PAGE_LIST[source]
    return (bySource and bySource[mode or currentMode()]) or {}
end

function ns.SourcePageUrlByKey(source, page, class, spec)
    if source == "ugg" then return uggPageUrl(class, spec, page.page) end
    return ivPageUrl(class, spec, page.suffix)
end

local function isUggSource(src)
    return src == "ugg" or src == "U.GG"
end

-- Per-spec source prefs win when set; otherwise header links track the source
-- actually rendering the content (the caller's active source override, e.g.
-- the compendium's own source selector, defaulting to the global one).
-- Which data category backs each attribution surface. Used to decide whether
-- the active source actually SUPPLIED what is on screen, or whether the legacy
-- borrow rules below picked it up from Icy Veins / u.gg instead.
local SURFACE_CATEGORY = {
    trinkets = "trinkets", talents = "talents", bis = "gear",
    crafting = "crafting", enhancements = "enchants", stats = "statPriority",
}

local function surfaceSource(surface, ps, active, class, spec)
    active = active or (ns.ActiveSource and ns.ActiveSource()) or "ugg"
    -- Everything below this point collapses to "ugg" or "icyveins", which was
    -- correct when those were the only two sources: it made every surface
    -- borrow from whichever of the pair had the data. With Wowhead and Archon
    -- registered it mis-credits them — Wowhead trinkets were tagged Icy Veins,
    -- Wowhead talents tagged U.GG. So when the active source genuinely carries
    -- this surface's category for this spec, attribute it and stop; only fall
    -- through to the borrow rules when it does not.
    local cat = SURFACE_CATEGORY[surface]
    if cat and class and spec and ns.SOURCES[active]
        and ns.RawSourceSpec and (ns.RawSourceSpec(active, class, spec) or {})[cat] then
        return active
    end
    if surface == "trinkets" then
        if ps and ps.trinketSource then return isUggSource(ps.trinketSource) and "ugg" or "icyveins" end
        return isUggSource(active) and "ugg" or "icyveins"
    elseif surface == "talents" then
        -- The dock's talent content follows the player-level effective source;
        -- an explicit override (compendium) means that source renders instead.
        local ts = active or (ns.GetEffectiveTalentSource and ns.GetEffectiveTalentSource() or "ugg")
        return (ts == "icyveins") and "icyveins" or "ugg"
    elseif surface == "bis" then
        if ps and ps.bisSource then return isUggSource(ps.bisSource) and "ugg" or "icyveins" end
        return isUggSource(active) and "ugg" or "icyveins"
    elseif surface == "crafting" then
        -- u.gg has no crafting page; crafted-gear/embellishment picks live on
        -- the spec gear page, which is what the ugg crafting data backs.
        return isUggSource(active) and "ugg" or "icyveins"
    elseif surface == "enhancements" then
        return "ugg"
    elseif surface == "stats" then
        return (active == "icyveins") and "icyveins" or "ugg"
    end
    return "icyveins"
end

function ns.ResolveAttribution(surface, class, specKey, sourceOverride, mode)
    local ps = perSpec(specKey)
    local spec = specFromKey(class, specKey)
    local source = surfaceSource(surface, ps, sourceOverride, class, spec)
    local url, label = ns.SourceLink(source, surface, class, spec, mode or currentMode())
    if not url then return nil end
    return source, url, label
end
