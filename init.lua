local environment = assert(getgenv, "<OH> ~ Your exploit is not supported")()
local rawWriteFile = writefile
local rawIsFile = isfile
local rawMakeFolder = makefolder
local rawIsFolder = isfolder
local rawGetCustomAsset = getcustomasset

if oh then
    oh.Exit()
end

local web = true
local user = "NPSummers"
local repo = "Hydroxide-"
local branch = "main"
local importCache = {}
local iconCache = {}

local function httpGet(url)
    if request then
        local success, response = pcall(request, { Url = url, Method = "GET" })

        if success and response and response.Success then
            return response.Body
        end
    end

    return game:HttpGet(url)
end

local assetFiles = {
    ["rbxassetid://11389137937"] = "11389137937.rbxmx",
    ["rbxassetid://5042114982"] = "5042114982.rbxmx",
}

local function getAssetFile(name)
    local folder = "hydroxide/assets"
    local path = folder .. "/" .. name

    if isFolder and makeFolder and not isFolder(folder) then
        makeFolder(folder)
    end

    if not (isFile and isFile(path)) then
        writeFile(path, httpGet("https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. branch .. "/github-assets/" .. name))
    end

    return path
end

local function getIconAsset(id)
    if iconCache[id] then
        return iconCache[id]
    end

    local folder = "hydroxide/assets/icons"
    local path = folder .. "/" .. id .. ".png"

    if rawIsFolder and rawMakeFolder and not rawIsFolder("hydroxide/assets") then
        rawMakeFolder("hydroxide/assets")
    end

    if rawIsFolder and rawMakeFolder and not rawIsFolder(folder) then
        rawMakeFolder(folder)
    end

    if not rawWriteFile then
        error("[Hydroxide+] writefile is unavailable; cannot cache icon " .. id)
    end

    if not (rawIsFile and rawIsFile(path)) then
        rawWriteFile(path, httpGet("https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. branch .. "/github-assets/icons/" .. id .. ".png"))
    end

    iconCache[id] = rawGetCustomAsset(path)
    return iconCache[id]
end

local function unwrapAsset(object)
    while object and object.ClassName == "Model" and #object:GetChildren() == 1 do
        object = object:GetChildren()[1]
    end

    return object
end

local function localizeImages(root)
    local objects = { root }
    for _, object in ipairs(root:GetDescendants()) do
        objects[#objects + 1] = object
    end

    for _, object in ipairs(objects) do
        local properties
        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            properties = { "Image", "HoverImage", "PressedImage", "DisabledImage" }
        elseif object:IsA("Decal") or object:IsA("Texture") then
            properties = { "Texture" }
        end

        if properties then
            for _, property in ipairs(properties) do
                local success, value = pcall(function()
                    return object[property]
                end)
                local id = success and tostring(value):match("[?&]id=(%d+)") or success and tostring(value):match("rbxassetid://(%d+)")

                if id then
                    object[property] = getIconAsset(id)
                end
            end

            if object.ScaleType == Enum.ScaleType.Slice and object.SliceCenter.Min.X == 25 and object.SliceCenter.Min.Y == 25 and object.SliceCenter.Max.X == 25 and object.SliceCenter.Max.Y == 25 then
                object.SliceCenter = Rect.new(512, 512, 512, 512)
                object.SliceScale = object.SliceScale * 25 / 512
            end
        end
    end

    return root
end

local function loadAsset(asset)
    local name = assetFiles[asset]
    local reason = name and "getcustomasset unavailable" or "no local file"

    if name and getcustomasset then
        local pathSuccess, path = pcall(getAssetFile, name)

        if pathSuccess and path then
            reason = "getcustomasset failed"

            local contentSuccess, content = pcall(getcustomasset, path)

            if contentSuccess and content then
                reason = "local loader failed"

                local loadSuccess, object = pcall(function()
                    return game:GetService("InsertService"):LoadLocalAsset(content)
                end)

                if loadSuccess and object then
                    return localizeImages(unwrapAsset(object))
                end

                local objectsSuccess, objects = pcall(function()
                    return game:GetObjects(content)
                end)

                if objectsSuccess and objects and objects[1] then
                    return localizeImages(unwrapAsset(objects[1]))
                end

                reason = (not loadSuccess and tostring(object)) or (not objectsSuccess and tostring(objects)) or "local loader returned nil"
            else
                reason = tostring(content)
            end
        else
            reason = tostring(path)
        end
    end

    error(("[Hydroxide+] Could not load %s locally (%s)"):format(asset, reason))
end

local function hasMethods(methods)
    for name in pairs(methods) do
        if not environment[name] then
            return false
        end
    end

    return true
end

local function useMethods(module)
    for name, method in pairs(module) do
        if method then
            environment[name] = method
        end
    end
end

local globalMethods = {
    checkCaller = checkcaller,
    newCClosure = newcclosure,
    hookFunction = hookfunction,
    restoreFunction = restorefunction,
    getGc = getgc,
    getInfo = debug.getinfo,
    getSenv = getsenv,
    getContext = getthreadidentity,
    getConnections = getconnections,
    getScriptClosure = getscriptclosure,
    getNamecallMethod = getnamecallmethod,
    getCallingScript = getcallingscript,
    getLoadedModules = getloadedmodules,
    getConstants = debug.getconstants,
    getUpvalues = debug.getupvalues,
    getProtos = debug.getprotos,
    getStack = debug.getstack,
    getConstant = debug.getconstant,
    getUpvalue = debug.getupvalue,
    getProto = debug.getproto,
    getMetatable = getrawmetatable,
    getHui = gethui,
    setClipboard = setclipboard or toclipboard,
    setConstant = debug.setconstant,
    setContext = setthreadidentity,
    setUpvalue = debug.setupvalue,
    setStack = debug.setstack,
    setReadOnly = setreadonly,
    isLClosure = islclosure,
    isReadOnly = isreadonly,
    isXClosure = isexecutorclosure,
    hookMetaMethod = hookmetamethod,
    readFile = readfile,
    writeFile = writefile,
    makeFolder = makefolder,
    isFolder = isfolder,
    isFile = isfile,
}

local oldGetUpvalue = globalMethods.getUpvalue
local oldGetUpvalues = globalMethods.getUpvalues

globalMethods.getUpvalue = function(closure, index)
    if type(closure) == "table" then
        return oldGetUpvalue(closure.Data, index)
    end

    return oldGetUpvalue(closure, index)
end

globalMethods.getUpvalues = function(closure)
    if type(closure) == "table" then
        return oldGetUpvalues(closure.Data)
    end

    return oldGetUpvalues(closure)
end

useMethods(globalMethods)

environment.hasMethods = hasMethods
environment.oh = {
    Events = {},
    Hooks = {},
    Cache = importCache,
    Methods = globalMethods,
    getIconAsset = getIconAsset,
    Constants = {
        Types = {
            ["nil"] = getIconAsset("4800232219"),
            table = getIconAsset("4666594276"),
            string = getIconAsset("4666593882"),
            number = getIconAsset("4666593882"),
            boolean = getIconAsset("4666593882"),
            userdata = getIconAsset("4666594723"),
            vector = getIconAsset("4666594723"),
            ["function"] = getIconAsset("4666593447"),
            ["thread"] = getIconAsset("4666593447"),
            ["integral"] = getIconAsset("4666593882")
        },
        Syntax = {
            ["nil"] = Color3.fromRGB(244, 135, 113),
            table = Color3.fromRGB(225, 225, 225),
            string = Color3.fromRGB(225, 150, 85),
            number = Color3.fromRGB(170, 225, 127),
            boolean = Color3.fromRGB(127, 200, 255),
            userdata = Color3.fromRGB(225, 225, 225),
            vector = Color3.fromRGB(225, 225, 225),
            ["function"] = Color3.fromRGB(225, 225, 225),
            ["thread"] = Color3.fromRGB(225, 225, 225),
            ["unnamed_function"] = Color3.fromRGB(175, 175, 175)
        }
    },
    Exit = function()
        for _i, event in pairs(oh.Events) do
            event:Disconnect()
        end

        for original, hooked in pairs(oh.Hooks) do
            if globalMethods.restoreFunction then
                globalMethods.restoreFunction(hooked)
            else
                globalMethods.hookFunction(hooked, original)
            end
        end

        local ui = importCache["rbxassetid://11389137937"]
        local assets = importCache["rbxassetid://5042114982"]

        if ui then
            unpack(ui):Destroy()
        end

        if assets then
            unpack(assets):Destroy()
        end
    end
}

if globalMethods.getConnections and globalMethods.getMetatable and globalMethods.setReadOnly and globalMethods.newCClosure then
    for _i, connection in pairs(globalMethods.getConnections(game:GetService("ScriptContext").Error)) do
        local metatable = globalMethods.getMetatable(connection)
        local oldIndex = metatable and metatable.__index

        if oldIndex then
            globalMethods.setReadOnly(metatable, false)
            metatable.__index = globalMethods.newCClosure(function(object, key)
                if key == "Connected" then
                    return true
                end

                return oldIndex(object, key)
            end)
            globalMethods.setReadOnly(metatable, true)
        end

        connection:Disable()
    end
end

local HttpService = game:GetService("HttpService")

local function getVersion()
    local success, releases = pcall(function()
        return HttpService:JSONDecode(httpGet("https://api.github.com/repos/" .. user .. "/" .. repo .. "/releases"))
    end)
    local release = success and releases and releases[1]

    if release and release.tag_name then
        return release.tag_name
    end

    local commitSuccess, commit = pcall(function()
        return HttpService:JSONDecode(httpGet("https://api.github.com/repos/" .. user .. "/" .. repo .. "/commits/" .. branch))
    end)

    if commitSuccess and commit and commit.sha then
        return commit.sha
    end

    return "unknown"
end

local version = getVersion()
print(("[Hydroxide+] init.lua loaded - commit %s"):format(version))

if readFile and writeFile then
    local hasFolderFunctions = (isFolder and makeFolder) ~= nil
    local ran, result = pcall(readFile, "__oh_version.txt")

    if not ran or version ~= result then
        if hasFolderFunctions then
            local function createFolder(path)
                if not isFolder(path) then
                    makeFolder(path)
                end
            end

            createFolder("hydroxide")
            createFolder("hydroxide/user")
            createFolder("hydroxide/user/" .. user)
            createFolder("hydroxide/user/" .. user .. "/methods")
            createFolder("hydroxide/user/" .. user .. "/modules")
            createFolder("hydroxide/user/" .. user .. "/objects")
            createFolder("hydroxide/user/" .. user .. "/ui")
            createFolder("hydroxide/user/" .. user .. "/ui/controls")
            createFolder("hydroxide/user/" .. user .. "/ui/modules")
            createFolder("hydroxide/assets")
        end

        function environment.import(asset)
            if importCache[asset] then
                return unpack(importCache[asset])
            end

            local assets

            if asset:find("rbxassetid://") then
                assets = { loadAsset(asset) }
            elseif web then
                if readFile and writeFile then
                    local file = (hasFolderFunctions and "hydroxide/user/" .. user .. '/' .. asset .. ".lua") or ("hydroxide-" .. user .. '-' .. asset:gsub('/', '-') .. ".lua")
                    local content

                    if (isFile and not isFile(file)) or not importCache[asset] then
                        content = httpGet("https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. branch .. '/' .. asset .. ".lua")
                        writeFile(file, content)
                    else
                        local ran, result = pcall(readFile, file)

                        if (not ran) or not importCache[asset] then
                            content = httpGet("https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. branch .. '/' .. asset .. ".lua")
                            writeFile(file, content)
                        else
                            content = result
                        end
                    end

                    assets = { loadstring(content, asset .. '.lua')() }
                else
                    assets = { loadstring(httpGet("https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. branch .. '/' .. asset .. ".lua"), asset .. '.lua')() }
                end
            else
                assets = { loadstring(readFile("hydroxide/" .. asset .. ".lua"), asset .. '.lua')() }
            end

            importCache[asset] = assets
            return unpack(assets)
        end

        writeFile("__oh_version.txt", version)
    elseif ran and version == result then
        function environment.import(asset)
            if importCache[asset] then
                return unpack(importCache[asset])
            end

            if asset:find("rbxassetid://") then
                assets = { loadAsset(asset) }
            elseif web then
                local file = (hasFolderFunctions and "hydroxide/user/" .. user .. '/' .. asset .. ".lua") or ("hydroxide-" .. user .. '-' .. asset:gsub('/', '-') .. ".lua")
                local ran, result = pcall(readFile, file)
                local content

                if not ran then
                    content = httpGet("https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. branch .. '/' .. asset .. ".lua")
                    writeFile(file, content)
                else
                    content = result
                end

                assets = { loadstring(content, asset .. '.lua')() }
            else
                assets = { loadstring(readFile("hydroxide/" .. asset .. ".lua"), asset .. '.lua')() }
            end

            importCache[asset] = assets
            return unpack(assets)
        end

    end

    useMethods({ import = environment.import })
end

useMethods(import("methods/string"))
useMethods(import("methods/table"))
useMethods(import("methods/userdata"))
useMethods(import("methods/environment"))

--import("ui/main")
