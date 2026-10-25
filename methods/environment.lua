local methods = {}

local function secureCall(closure, ...)
    local env = getfenv(1)
    local renv = getrenv()

    setfenv(1, setmetatable({ script = script }, {
        __index = renv
    }))

    local results = { closure(...) }

    setfenv(1, env)

    return unpack(results)
end

methods.secureCall = secureCall
return methods
