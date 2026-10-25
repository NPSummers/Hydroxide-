local aux = {}

local getGc = getgc
local getInfo = debug.getinfo
local getUpvalue = debug.getupvalue
local getConstants = debug.getconstants
local isXClosure = isexecutorclosure
local isLClosure = islclosure

assert(getGc and getInfo and getConstants and isXClosure and isLClosure, "This executor does not support the required sUNC functions")

local placeholderUserdataConstant = newproxy(false)

local function matchConstants(closure, list)
    if not list then
        return true
    end
    
    local constants = getConstants(closure)
    
    for index, value in pairs(list) do
        if constants[index] ~= value and value ~= placeholderUserdataConstant then
            return false
        end
    end
    
    return true
end

local function searchClosure(script, name, upvalueIndex, constants)
    for _i, v in pairs(getGc()) do
        local parentScript = rawget(getfenv(v), "script")

        if type(v) == "function" and 
            isLClosure(v) and 
            not isXClosure(v) and 
            (
                (script == nil and parentScript.Parent == nil) or script == parentScript
            ) 
            and pcall(getUpvalue, v, upvalueIndex)
        then
            if ((name and name ~= "Unnamed function") and getInfo(v).name == name) and matchConstants(v, constants) then
                return v
            elseif (not name or name == "Unnamed function") and matchConstants(v, constants) then
                return v
            end
        end
    end
end

aux.placeholderUserdataConstant = placeholderUserdataConstant
aux.searchClosure = searchClosure

return aux
