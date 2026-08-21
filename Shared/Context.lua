local _, ns = ...

local WILDCARD = "all"
local DEFAULT_CONTENT = "mplus"

local function toDataContext(contentType)
    return contentType or WILDCARD
end
ns.ContextToDataContext = toDataContext

local Context = {}
ns.Context = Context

local subscribers = {}

local function store()
    local specKey = ns.GetSpecKey and ns.GetSpecKey()
    if not specKey or not ClassCodexCharDB then return nil end
    ClassCodexCharDB.perSpec = ClassCodexCharDB.perSpec or {}
    local ps = ClassCodexCharDB.perSpec[specKey]
    if not ps then
        ps = {}
        ClassCodexCharDB.perSpec[specKey] = ps
    end
    ps.ctx = ps.ctx or {}
    return ps.ctx, ps
end

function Context.contentType()
    local ctx = store()
    return (ctx and ctx.contentType) or DEFAULT_CONTENT
end

function Context.heroSpec()
    local ctx, ps = store()

    return (ctx and ctx.heroSpec) or (ps and ps.heroTalent) or nil
end

function Context.source()
    local ctx = store()
    return ctx and ctx.source or nil
end

function Context.dataContext()
    return toDataContext(Context.contentType())
end

function Context.set(key, value, silent)
    local ctx, ps = store()
    if not ctx then return end
    ctx[key] = value
    if key == "heroSpec" and ps then ps.heroTalent = value end
    if not silent then Context.notify() end
end

function Context.OnChange(fn)
    subscribers[#subscribers + 1] = fn
end

function Context.notify()
    for _, fn in ipairs(subscribers) do
        pcall(fn)
    end
end
