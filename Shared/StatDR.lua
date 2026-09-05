local _, ns = ...

-- Secondary-stat diminishing returns, mirroring TrueStatValues' implementation
-- of the game's item_scaling curve 21024 (per-level conversion factors from
-- SimulationCraft's generated scale data): rating to raw percent, then a
-- penalty on each bracket of raw percent.
-- https://github.com/MSchiavi/TrueStatValues

-- Bracket widths in raw percent; the penalty applies to the rating inside.
local BRACKETS = {
    { size = 30, penalty = 0 },
    { size = 10, penalty = 0.1 },
    { size = 10, penalty = 0.2 },
    { size = 10, penalty = 0.3 },
    { size = 20, penalty = 0.4 },
    { size = 120, penalty = 0.5 },
}

-- Rating per 1%, indexed by character level (SimC generated data).
-- stylua: ignore start
local CONVERSION = {
    crit = {
        3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805,
        3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805,
        3.056530805, 3.209357346, 3.362183886, 3.515010426, 3.667836966,
        3.820663507, 3.973490047, 4.126316587, 4.279143127, 4.431969668,
        4.477766688, 4.525529532, 4.575310357, 4.627163874, 4.681147453,
        4.737321222, 4.795748184, 4.856494328, 4.919628754, 4.985223804,
        5.053355196, 5.124102169, 5.197547633, 5.273778332, 5.352885007,
        5.434962577, 5.520110324, 5.608432089, 5.70003648, 5.795037088,
        5.893552718, 5.995707632, 6.1016318, 6.211461173, 6.325337961,
        6.443410936, 6.565835744, 6.692775235, 6.824399815, 6.960887811,
        7.102425863, 7.249209331, 7.401442727, 7.559340172, 7.723125876,
        7.893034645, 8.069312419, 8.252216833, 8.442017821, 8.638998236,
        8.843454528, 9.055697437, 9.276052741, 9.504862042, 9.742483593,
        9.989293177, 10.24568504, 10.51207285, 10.78889076, 11.07659452,
        11.18028258, 11.28494127, 11.39057967, 11.49720694, 11.60483236,
        11.71346526, 11.82311507, 11.93379132, 12.04550361, 12.15826163,
        13.58403151, 15.17699796, 16.95676773, 18.94524679, 21.16690997,
        23.6491022, 26.42237511, 29.520863, 32.98270306, 46,
    },
    haste = {
        2.923638162, 2.923638162, 2.923638162, 2.923638162, 2.923638162,
        2.923638162, 2.923638162, 2.923638162, 2.923638162, 2.923638162,
        2.923638162, 3.06982007, 3.216001978, 3.362183886, 3.508365794,
        3.654547702, 3.80072961, 3.946911518, 4.093093426, 4.239275334,
        4.283081179, 4.328767379, 4.37638382, 4.425982836, 4.477619303,
        4.531350734, 4.587237394, 4.6453424, 4.705731852, 4.768474943,
        4.833644101, 4.901315118, 4.971567301, 5.044483622, 5.120150876,
        5.198659856, 5.280105527, 5.364587216, 5.452208807, 5.543078954,
        5.637311296, 5.735024692, 5.836343461, 5.941397644, 6.050323267,
        6.163262635, 6.280364625, 6.401785008, 6.527686779, 6.658240515,
        6.793624739, 6.934026317, 7.079640869, 7.230673208, 7.387337794,
        7.549859225, 7.718472748, 7.893424797, 8.074973567, 8.263389617,
        8.458956505, 8.661971461, 8.8727461, 9.09160717, 9.31889735,
        9.554976083, 9.800220469, 10.0550262, 10.31980856, 10.59500345,
        10.69418334, 10.79429165, 10.89533707, 10.99732838, 11.10027443,
        11.20418416, 11.30906659, 11.41493083, 11.52178606, 11.62964156,
        12.99342144, 14.51712849, 16.21951696, 18.12154041, 20.24660954,
        22.62088037, 25.27357619, 28.23734722, 31.5486725, 44,
    },
    mastery = {
        3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805,
        3.056530805, 3.056530805, 3.056530805, 3.056530805, 3.056530805,
        3.056530805, 3.209357346, 3.362183886, 3.515010426, 3.667836966,
        3.820663507, 3.973490047, 4.126316587, 4.279143127, 4.431969668,
        4.477766688, 4.525529532, 4.575310357, 4.627163874, 4.681147453,
        4.737321222, 4.795748184, 4.856494328, 4.919628754, 4.985223804,
        5.053355196, 5.124102169, 5.197547633, 5.273778332, 5.352885007,
        5.434962577, 5.520110324, 5.608432089, 5.70003648, 5.795037088,
        5.893552718, 5.995707632, 6.1016318, 6.211461173, 6.325337961,
        6.443410936, 6.565835744, 6.692775235, 6.824399815, 6.960887811,
        7.102425863, 7.249209331, 7.401442727, 7.559340172, 7.723125876,
        7.893034645, 8.069312419, 8.252216833, 8.442017821, 8.638998236,
        8.843454528, 9.055697437, 9.276052741, 9.504862042, 9.742483593,
        9.989293177, 10.24568504, 10.51207285, 10.78889076, 11.07659452,
        11.18028258, 11.28494127, 11.39057967, 11.49720694, 11.60483236,
        11.71346526, 11.82311507, 11.93379132, 12.04550361, 12.15826163,
        13.58403151, 15.17699796, 16.95676773, 18.94524679, 21.16690997,
        23.6491022, 26.42237511, 29.520863, 32.98270306, 46,
    },
    versatility = {
        3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.58810138,
        3.58810138, 3.58810138, 3.58810138, 3.58810138, 3.58810138,
        3.58810138, 3.767506449, 3.946911518, 4.126316587, 4.305721656,
        4.485126725, 4.664531794, 4.843936863, 5.023341932, 5.202747001,
        5.25650872, 5.312578146, 5.371016506, 5.431888026, 5.495260053,
        5.561203174, 5.629791347, 5.701102037, 5.775216363, 5.852219248,
        5.932199578, 6.015250372, 6.101468961, 6.190957172, 6.28382153,
        6.38017346, 6.480129511, 6.583811583, 6.691347172, 6.802869625,
        6.918518409, 7.038439394, 7.162785157, 7.29171529, 7.425396737,
        7.564004143, 7.707720221, 7.856736146, 8.011251956, 8.171476996,
        8.337630361, 8.509941389, 8.688650158, 8.874008028, 9.066278202,
        9.265736322, 9.4726711, 9.687384978, 9.910194833, 10.14143271,
        10.38144662, 10.63060134, 10.8892793, 11.15788153, 11.43682857,
        11.72656156, 12.0275433, 12.34025943, 12.66521959, 13.00295878,
        13.12467955, 13.24753975, 13.37155004, 13.4967212, 13.62306408,
        13.75058965, 13.879309, 14.00923329, 14.1403738, 14.27274192,
        15.94647177, 17.81647587, 19.90577082, 22.24007232, 24.8481117,
        27.76198954, 31.01757078, 34.65492613, 38.71882534, 54,
    },
}
-- stylua: ignore end

local function conversionFor(statKey, level)
    local t = CONVERSION[statKey]
    if not t then return nil end
    return t[math.max(1, math.min(level or #t, #t))]
end

ns.StatDR = {}

-- Raw percent needed to reach `realPct` on the DR curve; nil past the cap.
function ns.StatDR.RawPercentFor(realPct)
    local real, prev = 0, 0
    for _, b in ipairs(BRACKETS) do
        local gain = b.size * (1 - b.penalty)
        if realPct <= real + gain + 1e-9 then return prev + (realPct - real) / (1 - b.penalty) end
        real, prev = real + gain, prev + b.size
    end
    return nil
end

-- Percent the DR curve grants `rating` at `conversionFactor` (rating per 1%);
-- for mastery this is mastery points, not effect percent. Caps at 126.
local function realPercentFor(rating, conversionFactor)
    if not rating or rating <= 0 then return 0 end
    local raw, real, prev = rating / conversionFactor, 0, 0
    for _, b in ipairs(BRACKETS) do
        if raw < prev + b.size then return real + (raw - prev) * (1 - b.penalty) end
        real, prev = real + b.size * (1 - b.penalty), prev + b.size
    end
    return real
end

local MASTERY_BASE = 8
local CRIT_BASE = 5
-- A live pair outside this band around the shipped table reads as garbage,
-- not as a patch drift worth self-correcting against.
local LIVE_BAND_LOW, LIVE_BAND_HIGH = 0.5, 2

-- Primary mastery effect per point, by class token and spec key (Maxroll's
-- diminishing-returns tables, 12.0.1). Display-only: targets for specs the
-- player isn't playing have no live stats to calibrate from. Specs without
-- a quotable per-point value (mistweaver, outlaw, devourer) are omitted.
local MASTERY_COEFF = {
    DEATHKNIGHT = { blood = 2.0, frost = 2.0, unholy = 1.8 },
    DEMONHUNTER = { havoc = 2.25, vengeance = 1.88 },
    DRUID = { balance = 0.75, feral = 2.0, guardian = 1.0, restoration = 0.7 },
    EVOKER = { augmentation = 0.272, devastation = 1.5, preservation = 1.8 },
    HUNTER = { ["beast-mastery"] = 1.9, marksmanship = 1.4, survival = 0.85 },
    MAGE = { arcane = 1.32, fire = 0.483, frost = 1.57 },
    MONK = { brewmaster = 0.924, windwalker = 2.33 },
    PALADIN = { holy = 1.5, protection = 1.0, retribution = 1.35 },
    PRIEST = { discipline = 1.35, holy = 0.908, shadow = 0.5 },
    ROGUE = { assassination = 1.7, subtlety = 2.45 },
    SHAMAN = { elemental = 0.684, enhancement = 2.0, restoration = 3.0 },
    WARLOCK = { affliction = 2.5, demonology = 1.45, destruction = 1.0 },
    WARRIOR = { arms = 1.1, fury = 1.4, protection = 0.5 },
}

--- The percent the character pane would show at `targetRating`, given the
--- player's live `statPct` at `currentRating`. For crit/haste/versatility the
--- conversion factor is re-derived from the live pair first, so a stale table
--- self-corrects. Mastery resolves its spec coefficient from the live effect
--- percent instead (each spec converts points differently). nil when the live
--- stats can't anchor the extrapolation.
function ns.StatDR.GoalPercent(statKey, level, statPct, currentRating, targetRating)
    if not (statPct and currentRating and targetRating and targetRating > 0 and currentRating > 0) then return nil end
    local k = conversionFor(statKey, level)
    if not k then return nil end

    if statKey == "mastery" then
        local currentPts = realPercentFor(currentRating, k)
        if currentPts < 1 then return nil end
        local coefficient = (statPct - MASTERY_BASE) / currentPts
        if coefficient < 0.3 or coefficient > 3.2 then return nil end
        return statPct + coefficient * (realPercentFor(targetRating, k) - currentPts)
    end

    local kEff = k
    local base = (statKey == "crit") and CRIT_BASE or 0
    local rawNow = ns.StatDR.RawPercentFor(statPct - base)
    if rawNow and rawNow > 0 then
        local kLive = currentRating / rawNow
        if kLive >= k * LIVE_BAND_LOW and kLive <= k * LIVE_BAND_HIGH then kEff = kLive end
    end
    return statPct + realPercentFor(targetRating, kEff) - realPercentFor(currentRating, kEff)
end

--- The percent the character pane would show at `rating` for a spec the
--- player isn't playing (no live stats to anchor on). Mastery resolves
--- through the coefficient table; specs without a quotable per-point value
--- return nil. Uses the shipped table factor.
function ns.StatDR.TargetPercent(statKey, level, rating, classToken, specKey)
    local k = conversionFor(statKey, level)
    if not k or not rating or rating <= 0 then return nil end
    if statKey == "mastery" then
        local coeff = classToken and specKey and MASTERY_COEFF[classToken] and MASTERY_COEFF[classToken][specKey]
        if not coeff then return nil end
        return MASTERY_BASE + coeff * realPercentFor(rating, k)
    end
    return ((statKey == "crit") and CRIT_BASE or 0) + realPercentFor(rating, k)
end
