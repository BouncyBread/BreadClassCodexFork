local _, ns = ...

-------------------------------------------------------------------------------
-- Data-source registry — single source of truth for every external provider
-- whose data the addon surfaces. Name, homepage and brand icon all live here;
-- dropdown labels, About-tab links and per-section attribution buttons read
-- from this table instead of redefining texture-escape strings inline.
-------------------------------------------------------------------------------

local TEX = "Interface\\AddOns\\BreadClassCodex\\Textures\\"

-- `color` is the brand accent (r, g, b 0-1) used by the About-tab source cards.
ns.SOURCES = {
    icyveins = { key = "icyveins", name = "Icy Veins", homepage = "https://www.icy-veins.com", iconTex = "icyveins", color = { 0.30, 0.62, 0.90 } },
    ugg      = { key = "ugg",      name = "u.gg",      homepage = "https://u.gg/wow",          iconTex = "ugg",      color = { 0.36, 0.09, 0.77 } },
    wowhead  = { key = "wowhead",  name = "Wowhead",   homepage = "https://www.wowhead.com",   iconTex = "wowhead",  color = { 0.92, 0.62, 0.20 } },
    -- Keyed `archongg`, not `archon`: the Priest hero talent is already called
    -- Archon throughout the talent data, and a bare `archon` key sitting beside
    -- it at a different nesting level reads as the same thing. No runtime
    -- collision, but a genuine trap for the next reader.
    archongg = { key = "archongg", name = "Archon",    homepage = "https://www.archon.gg/wow", iconTex = "archon",  color = { 0.85, 0.31, 0.31 } },
    bnet     = { key = "bnet",     name = "Blizzard",  homepage = "https://worldofwarcraft.blizzard.com", iconTex = "bnet", color = { 0.10, 0.58, 0.90 } },
}

-- Scrape date for a source, as an ISO date string, or nil.
--
-- The four sources are refreshed by different processes on different days, but
-- the footer read one global `ClassCodex_LastScrape` for all of them — so every
-- source showed upstream's own scrape date (Aug 6) however recently Wowhead or
-- Archon had actually been regenerated.
--
-- EVERY generator already published this and nothing read it. Upstream's own
-- files carry it too: db_icyveins is 2026-07-31 while db_ugg and db_blizzard are
-- 2026-08-06, so the single global was wrong even for the sources that shipped
-- with the addon. Key names differ by generator — scrape_wowhead.py writes
-- `meta.generatedAt`, upstream writes `meta.generatedAt`, and scrape_archon.py
-- writes `meta.generated` (when we scraped) plus `meta.lastUpdated` (archon's
-- own data timestamp) — hence the three-way lookup.
--
-- The ClassCodex_LastScrape fallback is therefore rarely hit in practice; it
-- covers a source whose file predates meta, and an unknown/nil key.
--
-- Only the leading YYYY-MM-DD is kept: archon's and upstream's are full
-- timestamps, and the footer formatter parses a plain ISO date.
-- Registry key -> ClassCodexSource data key, where they differ. The PvP source is
-- registered as `bnet` (its icon and homepage are Battle.net) but its generated
-- file registers `ClassCodexSource["blizzard"]`, so a direct lookup missed and
-- the PvP tab silently showed the global fallback date instead of its own.
local SOURCE_DATA_KEY = { bnet = "blizzard" }

function ns.SourceDate(key)
    key = key and (SOURCE_DATA_KEY[key] or key)
    local src = key and ClassCodexSource and ClassCodexSource[key]
    local meta = src and src.meta
    local iso = meta and (meta.generatedAt or meta.generated or meta.lastUpdated)
    if type(iso) == "string" then
        local d = iso:match("^(%d%d%d%d%-%d%d%-%d%d)")
        if d then return d end
    end
    if type(ClassCodex_LastScrape) == "string" and ClassCodex_LastScrape ~= "" then
        return ClassCodex_LastScrape
    end
    return nil
end

-- Inline 12px brand icon (texture-escape string) for a source key.
function ns.SourceIcon(key, size, yoff)
    local src = ns.SOURCES[key]
    if not src then return "" end
    size = size or 12
    return "|T" .. TEX .. src.iconTex .. ":" .. size .. ":" .. size .. ":0:" .. (yoff or 0) .. "|t"
end

-- "<icon>  Name" label used by the source dropdowns.
function ns.SourceLabelText(key)
    local src = ns.SOURCES[key]
    if not src then return "" end
    return ns.SourceIcon(key) .. "  " .. src.name
end

-- The texture path consumed by Texture:SetTexture for a source key.
function ns.SourceTexturePath(key)
    local src = ns.SOURCES[key]
    return src and (TEX .. src.iconTex) or nil
end

-------------------------------------------------------------------------------
-- Source attribution affordance — a footer source tag (see CreateSourceTag).
-------------------------------------------------------------------------------
-- Source tag: a right-aligned, click-to-copy label reading "Source:  <logo>
-- Name" (or just "<logo> Name" when opts.noPrefix) for whatever source feeds
-- the active view. The caller anchors it. Call :SetSource(key, url) per render;
-- a nil/unknown key hides it.
function ns.CreateSourceTag(parent, opts)
    opts = opts or {}
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(18)
    btn:RegisterForClicks("LeftButtonUp")

    -- Source logo as a real texture pinned to the right edge. Both the logo and
    -- the text anchor independently to the button (not to each other), so the
    -- +1 y-nudge lifts the logo onto the text's visual centre — the small font's
    -- unused descender space sits the bbox centre ~1px below the visual middle.
    local ICON = 11
    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:SetSize(ICON, ICON)
    icon:SetPoint("RIGHT", btn, "RIGHT", 0, 1)
    btn.icon = icon

    -- Resting text colour; caller can override (e.g. the Compendium, where the
    -- default dim grey blends into the lighter inset background).
    local rc = opts.textColor or { 0.5, 0.5, 0.5 }
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("RIGHT", btn, "RIGHT", -(ICON + 3), 0)
    fs:SetJustifyH("RIGHT")
    fs:SetTextColor(rc[1], rc[2], rc[3])
    btn.text = fs
    btn:Hide()

    function btn:SetSource(key, url)
        local src = key and ns.SOURCES[key]
        if not src then
            self.url, self.srcName = nil, nil
            self:Hide()
            return
        end
        self.url = url
        self.srcName = src.name
        -- "[Check out] Name <logo>" — text, then the source logo at the end.
        self.icon:SetTexture(ns.SourceTexturePath(key))
        local cta = opts.noPrefix and "" or (ns.L["attribution.visit_cta"] .. " ")
        fs:SetText(cta .. src.name)
        self:SetWidth(fs:GetStringWidth() + 3 + self.icon:GetWidth() + 1)
        self:Show()
    end

    btn:SetScript("OnEnter", function(self)
        if not self.srcName then return end
        self.text:SetTextColor(0.9, 0.9, 0.9)
        -- Footer tags sit at the bottom of the panel — anchor the tooltip above
        -- them so it doesn't run off-screen. Others anchor to the left.
        if opts.tooltipAbove then
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 4)
        else
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        end
        -- Title invites the visit, the page URL shows the destination, then a
        -- blank line and a green actionable hint (the WoW instruction-line idiom).
        GameTooltip:SetText(ns.L["attribution.visit_source"]:format(self.srcName), 1, 0.82, 0)
        if self.url then GameTooltip:AddLine(self.url, 0.6, 0.6, 0.6, true) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.L["attribution.copy_url"], 0.45, 0.75, 0.45)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self.text:SetTextColor(rc[1], rc[2], rc[3])
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self)
        if self.url and ns.ShowCopyPopup then ns.ShowCopyPopup(self.url, self) end
    end)

    return btn
end

-------------------------------------------------------------------------------
-- Attribution resolution
--
-- Given a logical surface (the active tab / section) and the current class /
-- spec, return the source key + exact page URL to credit. Resolution reads the
-- same saved-vars and data accessors the sections themselves use, so it tracks
-- whatever the user currently has selected without reaching into render state.
-- Returns (key, url) or nil when there's nothing to attribute.
-------------------------------------------------------------------------------

local function perSpec(specKey)
    if specKey and ClassCodexCharDB and ClassCodexCharDB.perSpec then
        return ClassCodexCharDB.perSpec[specKey]
    end
    return nil
end

-- Attribution URLs live at the spec level in the normalized data, read through
-- the SourceData seam: ns.SourceSpec(source, class, spec).links[page]
--   e.g. links = { bis, talents, leveling } (Icy Veins). The helpers below wrap
-- that lookup and fall back to each source's homepage.

-- Player's class token + spec slug, for the no-arg helpers (docked pane / About
-- tab), which always credit the active spec.
local function playerClassSpec()
    local classToken = select(2, UnitClass("player"))
    local specKey = ns.GetSpecKey and ns.GetSpecKey()
    local spec = specKey and (specKey:match("-(.+)") or specKey) or nil
    return classToken, spec
end

local function srcUrl(class, spec, source, page)
    if not (class and spec) then class, spec = playerClassSpec() end
    -- Guide links live at the spec level in the normalized data (Icy Veins only,
    -- as before — u.gg had no per-spec URLs and falls back to its homepage).
    local sd = class and spec and ns.SourceSpec and ns.SourceSpec(source, class, spec)
    local links = sd and sd.links
    return links and links[page] or nil
end

local function icyVeinsGearUrl(class, spec)
    return srcUrl(class, spec, "icyveins", "bis") or ns.SOURCES.icyveins.homepage
end

-- Icy Veins talents page; pass leveling=true for the leveling-guide URL.
local function icyVeinsTalentsUrl(class, spec, leveling)
    if leveling then
        return srcUrl(class, spec, "icyveins", "leveling")
            or srcUrl(class, spec, "icyveins", "talents")
            or ns.SOURCES.icyveins.homepage
    end
    return srcUrl(class, spec, "icyveins", "talents") or ns.SOURCES.icyveins.homepage
end

-- u.gg spec pages are fully deterministic from class + spec, so we build the
-- exact page we scrape each surface from (e.g. .../frost/death_knight/gear)
-- rather than storing per-spec URLs. `page` nil yields the spec root.
local UGG_CLASS_SLUG = { DEATHKNIGHT = "death_knight", DEMONHUNTER = "demon_hunter" }
local function uggPageUrl(class, spec, page)
    if not class or not spec then return ns.SOURCES.ugg.homepage end
    local classSlug = UGG_CLASS_SLUG[class] or class:lower()
    local specSlug = spec:gsub("-", "_")
    local base = string.format("https://u.gg/wow/%s/%s", specSlug, classSlug)
    return page and (base .. "/" .. page) or base
end

local function uggOverviewUrl(class, spec) return uggPageUrl(class, spec, "talents") end
local function uggTalentsUrl(class, spec)  return uggPageUrl(class, spec, "talents") end
local function uggGearUrl(class, spec)     return uggPageUrl(class, spec, "gear") end
local function uggEnchantsUrl(class, spec) return uggPageUrl(class, spec, "gems-and-enchants") end
local function uggTrinketsUrl(class, spec) return uggPageUrl(class, spec, "trinkets") end

-- Wowhead guide pages are deterministic from class + spec the same way u.gg's
-- are (.../guide/classes/death-knight/blood/bis-gear), so we can build the exact
-- page. The scraped data also carries per-spec `links`, so prefer those and fall
-- back to the constructed URL — that keeps working if Wowhead reshuffles a slug
-- for one spec without breaking the other 39.
local WOWHEAD_CLASS_SLUG = { DEATHKNIGHT = "death-knight", DEMONHUNTER = "demon-hunter" }
local function wowheadPageUrl(class, spec, page)
    if not class or not spec then return ns.SOURCES.wowhead.homepage end
    local classSlug = WOWHEAD_CLASS_SLUG[class] or class:lower()
    local base = string.format("https://www.wowhead.com/guide/classes/%s/%s", classSlug, spec)
    return page and (base .. "/" .. page) or base
end

local function wowheadGearUrl(class, spec)
    return srcUrl(class, spec, "wowhead", "bis") or wowheadPageUrl(class, spec, "bis-gear")
end

local function wowheadTalentsUrl(class, spec)
    return srcUrl(class, spec, "wowhead", "talents") or wowheadPageUrl(class, spec, "talents")
end

-- archon.gg build pages. Note the slug order is spec-then-class, the reverse of
-- Wowhead and u.gg (.../builds/frost/mage/..., not .../mage/frost/...).
--
-- The two zone types take a different number of trailing segments, and archon
-- 307s an unrecognised /wow/* path to its landing page rather than 404ing, so a
-- wrong arity here silently lands the user on the front page. M+ takes
-- <difficulty>/<encounter>/<affixes>; raid takes <difficulty>/<encounter>.
local ARCHON_CLASS_SLUG = { DEATHKNIGHT = "death-knight", DEMONHUNTER = "demon-hunter" }
local ARCHON_TAIL = {
    mplus = "mythic-plus/%s/10/all-dungeons/this-week",
    raid  = "raid/%s/mythic/all-bosses",
}

local function archonPageUrl(class, spec, category, context)
    if not class or not spec then return ns.SOURCES.archongg.homepage end
    local tail = ARCHON_TAIL[context or "mplus"] or ARCHON_TAIL.mplus
    local classSlug = ARCHON_CLASS_SLUG[class] or class:lower()
    return string.format("https://www.archon.gg/wow/builds/%s/%s/%s",
        spec, classSlug, string.format(tail, category or "overview"))
end

-- Prefer the scraped per-spec link, fall back to the constructed URL — same
-- reasoning as Wowhead: one reshuffled slug shouldn't break the other 39.
local function archonGearUrl(class, spec, context)
    return srcUrl(class, spec, "archongg", "bis")
        or archonPageUrl(class, spec, "gear-and-tier-set", context)
end

local function archonTalentsUrl(class, spec, context)
    return srcUrl(class, spec, "archongg", "talents")
        or archonPageUrl(class, spec, "talents", context)
end

local function archonEnchantsUrl(class, spec, context)
    return archonPageUrl(class, spec, "enchants-and-gems", context)
end

local function archonTrinketsUrl(class, spec, context)
    return archonPageUrl(class, spec, "trinkets", context)
end

-- Wowhead item page for an item id. Wowhead resolves /item=<id> without the name
-- slug, so the id alone is a complete link.
function ns.WowheadItemUrl(itemId)
    itemId = tonumber(itemId)
    if not itemId then return nil end
    return "https://www.wowhead.com/item=" .. itemId
end

-- URL helpers exposed for surfaces that resolve their own selection state
-- (e.g. the Compendium, the talent dropdown). Each falls back to the source
-- homepage when the exact page is unavailable.
ns.SourceUrls = {
    icyVeinsGear   = icyVeinsGearUrl,
    icyVeinsTalents = icyVeinsTalentsUrl,
    uggOverview    = uggOverviewUrl,
    uggTalents     = uggTalentsUrl,
    wowheadGear    = wowheadGearUrl,
    wowheadTalents = wowheadTalentsUrl,
    archonGear     = archonGearUrl,
    archonTalents  = archonTalentsUrl,
    archonEnchants = archonEnchantsUrl,
    archonTrinkets = archonTrinketsUrl,
}

-- BiS page URL for a resolved gear-source key (u.gg, Icy Veins, Wowhead or Archon).
function ns.BisUrlForKey(key, class, spec, context)
    if key == "icyveins" then return icyVeinsGearUrl(class, spec) end
    if key == "wowhead" then return wowheadGearUrl(class, spec) end
    if key == "archongg" then return archonGearUrl(class, spec, context) end
    return uggGearUrl(class, spec)
end

-- Trinket page URL for a resolved trinket-source key. Icy Veins and Wowhead
-- both list trinkets inside their BiS gear page rather than on one of their own,
-- so those attribute to the gear page — the link that always resolves.
function ns.TrinketUrlForKey(key, class, spec, context)
    if key == "ugg" then return uggTrinketsUrl(class, spec) end
    if key == "wowhead" then return wowheadGearUrl(class, spec) end
    if key == "archongg" then return archonTrinketsUrl(class, spec, context) end
    return icyVeinsGearUrl(class, spec)
end

-- Map a Gear/Enhancements dropdown string ("Icy Veins"/"u.gg"/"Wowhead"/"Archon"/"PvP")
-- to a registry key + URL. PvP gear comes from u.gg; defaults to u.gg.
local function fromDropdown(picked, dataType, class, spec)
    if picked == "Icy Veins" then return "icyveins", icyVeinsGearUrl(class, spec) end
    if picked == "Wowhead" then return "wowhead", wowheadGearUrl(class, spec) end
    if picked == "Archon" then return "archongg", archonGearUrl(class, spec) end
    return "ugg", uggGearUrl(class, spec)
end

-- surface: the active tab. class: class token ("MAGE"). specKey: the per-spec
-- saved-var key ("MAGE-frost"); the data-lookup slug ("frost") is derived from
-- it. Returns (key, url) or nil.
function ns.ResolveAttribution(surface, class, specKey, renderedSource)
    local ps = perSpec(specKey)
    local spec = specKey and (specKey:match("-(.+)") or specKey) or nil

    if surface == "guide" then
        -- The Guide's stat priority + talent preview are both Icy Veins.
        return "icyveins", icyVeinsTalentsUrl(class, spec)

    elseif surface == "trinkets" then
        -- Default Icy Veins (tier rankings); the rest are per-spec opt-ins. This
        -- only knew icyveins and ugg, so the panel — which has offered Archon
        -- since it shipped — credited Icy Veins for Archon's rows and linked an
        -- Icy Veins page. Route every key through the shared resolver.
        -- Saved vars can hold a key from an older build; an unknown one would
        -- return a key CreateSourceTag can't resolve, which silently hides the
        -- whole attribution tag. Fall back rather than vanish.
        local picked = (ps and ps.trinketSource) or "icyveins"
        if not ns.SOURCES[picked] then picked = "icyveins" end
        return picked, ns.TrinketUrlForKey(picked, class, spec)

    elseif surface == "talents" then
        -- PvP talents come from Blizzard's armory (bnet); the rest from u.gg /
        -- Icy Veins.
        -- The full Talents panel permits a session-local pick while source
        -- pinning is off. Its renderer passes that actual source explicitly;
        -- otherwise attribution would recompute the persisted/default source
        -- and disagree with the content on screen.
        local ts = renderedSource
            or (ns.GetEffectiveTalentSource and ns.GetEffectiveTalentSource()) or "ugg"
        if ts == "icyveins" then return "icyveins", icyVeinsTalentsUrl(class, spec) end
        if ts == "wowhead" then return "wowhead", wowheadTalentsUrl(class, spec) end
        if ts == "archongg" then return "archongg", archonTalentsUrl(class, spec) end
        if ts == "pvp" then return "bnet", ns.SOURCES.bnet.homepage end
        return "ugg", uggTalentsUrl(class, spec)

    elseif surface == "bis" then
        local picked = (ps and ps.bisSource) or "Icy Veins"
        return fromDropdown(picked, "bis", class, spec)

    elseif surface == "enhancements" then
        -- Follow the Enhancements tab's own source picker rather than assuming
        -- u.gg — otherwise the footer credits u.gg for rows Wowhead or Archon
        -- supplied.
        local key = ns.Sections and ns.Sections.Enhancements
            and ns.Sections.Enhancements.GetActiveSourceKey
            and ns.Sections.Enhancements.GetActiveSourceKey() or "ugg"
        -- Wowhead's enchants/gems/consumables live on a page whose role suffix
        -- (dps/tank/healer) the scraper resolves from the bis-gear nav and never
        -- guesses, and no per-spec link for it is stored. So attribute to the
        -- bis-gear page, which is stored and always resolves, rather than
        -- constructing a URL that would 404 for two thirds of specs.
        if key == "wowhead" then return "wowhead", wowheadGearUrl(class, spec) end
        if key == "archongg" then return "archongg", archonEnchantsUrl(class, spec) end
        return "ugg", uggEnchantsUrl(class, spec)

    elseif surface == "crafting" then
        return "icyveins", icyVeinsGearUrl(class, spec)

    elseif surface == "stats" then
        -- Stat targets are summed from u.gg's BiS gear list.
        return "ugg", uggGearUrl(class, spec)
    end

    return nil
end
