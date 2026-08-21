local _, ns = ...

local function HeroMatches(entryHero, heroTalent)
    if entryHero == heroTalent then return true end
    if
        heroTalent
        and entryHero:sub(1, #heroTalent) == heroTalent
        and entryHero:sub(#heroTalent + 1, #heroTalent + 1) == " "
    then
        return true
    end
    if
        entryHero
        and heroTalent:sub(1, #entryHero) == entryHero
        and heroTalent:sub(#entryHero + 1, #entryHero + 1) == " "
    then
        return true
    end
    return false
end
ns.HeroMatches = HeroMatches

function ns.GetHeroTalentOptions(specData)
    local seen, options = {}, {}
    local function add(name)
        if name and name ~= "All" and not seen[name] then
            seen[name] = true
            options[#options + 1] = name
        end
    end
    if specData.priorities then
        for _, p in ipairs(specData.priorities) do
            add(p.heroTalent)
        end
    end
    if specData.talents then
        for _, t in ipairs(specData.talents) do
            add(t.heroTalent)
        end
    end
    return options
end

function ns.GetAllTalentBuildsForHero(specData, heroTalent)
    if not specData.talents then return {} end
    local builds = {}
    for _, t in ipairs(specData.talents) do
        if t.heroTalent == heroTalent or t.heroTalent == "All" or HeroMatches(t.heroTalent, heroTalent) then
            builds[#builds + 1] = t
        end
    end
    return builds
end

function ns.FindRotationByContext(rotations, heroTalent, rotContext)
    if not rotations then return nil end
    for _, r in ipairs(rotations) do
        if r.heroTalent == heroTalent and r.context == rotContext then return r end
    end
    for _, r in ipairs(rotations) do
        if HeroMatches(r.heroTalent, heroTalent) and r.context == rotContext then return r end
    end
    for _, r in ipairs(rotations) do
        if r.heroTalent == "All" and r.context == rotContext then return r end
    end
    for _, r in ipairs(rotations) do
        if r.context == rotContext then return r end
    end
    return nil
end

function ns.GetRotationContextOptions(specData, heroTalent)
    if not specData.rotation then return {} end
    local rank = ns.RotationContextRank or function()
        return 0, 0
    end
    local seen, options = {}, {}
    local function add(r)
        local ctx = r.context
        if ctx and not seen[ctx] then
            seen[ctx] = true
            options[#options + 1] = { label = ctx, key = r.key or ctx }
        end
    end
    for _, r in ipairs(specData.rotation) do
        if r.heroTalent == heroTalent or r.heroTalent == "All" or HeroMatches(r.heroTalent, heroTalent) then add(r) end
    end
    if #options == 0 then
        for _, r in ipairs(specData.rotation) do
            add(r)
        end
    end
    -- Source order is pairs()-derived, so sort explicitly: rotations before
    -- openers, AoE target-count splits by their number.
    table.sort(options, function(a, b)
        local ra, ta = rank(a.key)
        local rb, tb = rank(b.key)
        if ra ~= rb then return ra < rb end
        if ta ~= tb then return ta < tb end
        return a.label < b.label
    end)
    for i, o in ipairs(options) do
        options[i] = o.label
    end
    return options
end
