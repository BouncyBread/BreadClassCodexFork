local _, ns = ...

ns.L = setmetatable({}, {
    __index = function(_, k)
        return k
    end,
})
