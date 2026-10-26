local environment = assert(getgenv, "<OH> ~ Your exploit is not supported")()
local rawReadFile = readfile
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
local sourceRevision = branch
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

local HttpService = game:GetService("HttpService")

local function isCommit(value)
    return type(value) == "string"
        and (#value == 40 or #value == 64)
        and not value:find("[^%x]")
end

local function resolveCommit()
    local injectedCommit = rawget(environment, "__HYDROXIDE_COMMIT")

    if isCommit(injectedCommit) then
        return injectedCommit:lower()
    end

    local success, commit = pcall(function()
        local cacheBuster = tostring(os.time and os.time() or tick())
        local url = "https://api.github.com/repos/" .. user .. "/" .. repo .. "/commits/" .. branch .. "?_=" .. cacheBuster
        return HttpService:JSONDecode(httpGet(url))
    end)

    if success and commit and isCommit(commit.sha) then
        return commit.sha:lower()
    end
end

local version = resolveCommit()

if version then
    sourceRevision = version
    environment.__HYDROXIDE_COMMIT = version
    print(("[Hydroxide+] init.lua loaded - commit %s"):format(version))
else
    version = "unversioned:" .. branch
    warn("[Hydroxide+] init.lua was not loaded with an embedded commit; using the mutable " .. branch .. " branch")
end

local function rawUrl(path)
    return "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. sourceRevision .. "/" .. path
end

local assetRevisionCache
local assetRevisionsLoaded = false

local function getAssetRevision(path)
    if not assetRevisionsLoaded then
        assetRevisionsLoaded = true
        assetRevisionCache = {}

        local success, tree = pcall(function()
            local cacheBuster = tostring(os.time and os.time() or tick())
            local url = "https://api.github.com/repos/" .. user .. "/" .. repo .. "/git/trees/" .. sourceRevision .. "?recursive=1&_=" .. cacheBuster
            return HttpService:JSONDecode(httpGet(url))
        end)

        if success and tree and tree.tree then
            for _, item in ipairs(tree.tree) do
                if item.type == "blob" and item.path and item.sha then
                    assetRevisionCache[item.path] = item.sha
                end
            end
        end
    end

    return assetRevisionCache[path]
end

local function luaCachePath(asset, hasFolderFunctions)
    if hasFolderFunctions then
        return "hydroxide_plus/user/" .. user .. "/" .. sourceRevision .. "/" .. asset .. ".lua"
    end

    return "hydroxide-" .. user .. "-" .. sourceRevision .. "-" .. asset:gsub("/", "-") .. ".lua"
end

local function luaChunkName(asset)
    return asset .. ".lua@" .. sourceRevision
end

local assetFiles = {
    ["rbxassetid://11389137937"] = "11389137937.rbxmx",
    ["rbxassetid://5042114982"] = "5042114982.rbxmx",
}

local function ensureAssetFolder(folder)
    if not (rawIsFolder and rawMakeFolder) then
        return
    end

    if not rawIsFolder("hydroxide") then
        rawMakeFolder("hydroxide")
    end

    if not rawIsFolder("hydroxide/assets") then
        rawMakeFolder("hydroxide/assets")
    end

    if folder ~= "hydroxide/assets" and not rawIsFolder(folder) then
        rawMakeFolder(folder)
    end
end

local function cachedAssetRevision(path)
    local revisionPath = path .. ".commit"

    if not (rawReadFile and rawIsFile and rawIsFile(revisionPath)) then
        return
    end

    local success, revision = pcall(rawReadFile, revisionPath)
    return success and revision or nil
end

local function updateAsset(repoPath, path)
    local hasFile = rawIsFile and rawIsFile(path)
    local cachedRevision = cachedAssetRevision(path)
    local remoteRevision = getAssetRevision(repoPath)
    local expectedRevision = remoteRevision or (isCommit(sourceRevision) and sourceRevision or nil)

    if hasFile and expectedRevision and cachedRevision == expectedRevision then
        return
    end

    if not rawWriteFile then
        error("[Hydroxide+] writefile is unavailable; cannot cache asset " .. repoPath)
    end

    print(("[Hydroxide+] Downloading asset %s (revision %s)"):format(repoPath, expectedRevision or sourceRevision))

    local content = httpGet(rawUrl(repoPath))
    rawWriteFile(path, content)
    rawWriteFile(path .. ".commit", expectedRevision or sourceRevision)
end

local function getAssetFile(name)
    local folder = "hydroxide/assets"
    local path = folder .. "/" .. name

    ensureAssetFolder(folder)
    updateAsset("github-assets/" .. name, path)

    return path
end

local function getIconAsset(id)
    if iconCache[id] then
        return iconCache[id]
    end

    local folder = "hydroxide/assets/icons"
    local path = folder .. "/" .. id .. ".png"

    ensureAssetFolder(folder)
    updateAsset("github-assets/icons/" .. id .. ".png", path)

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
    getRenv = getrenv,
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
    setHiddenProperty = sethiddenproperty,
    setStackHidden = setstackhidden,
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
    Commit = sourceRevision,
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
            local hookedIndex = globalMethods.newCClosure(function(object, key)
                if key == "Connected" then
                    return true
                end

                return oldIndex(object, key)
            end)

            if globalMethods.setStackHidden then
                pcall(globalMethods.setStackHidden, hookedIndex, true)
            end

            globalMethods.setReadOnly(metatable, false)
            metatable.__index = hookedIndex
            globalMethods.setReadOnly(metatable, true)
        end

        connection:Disable()
    end
end

if readFile and writeFile then
    local hasFolderFunctions = (isFolder and makeFolder) ~= nil
    local ran, result = pcall(readFile, "__oh_version.txt")

    if hasFolderFunctions then
        local function createFolder(path)
            if not isFolder(path) then
                makeFolder(path)
            end
        end

        createFolder("hydroxide_plus")
        createFolder("hydroxide_plus/user")
        createFolder("hydroxide_plus/user/" .. user)
        createFolder("hydroxide_plus/user/" .. user .. "/" .. sourceRevision)
        createFolder("hydroxide_plus/user/" .. user .. "/" .. sourceRevision .. "/methods")
        createFolder("hydroxide_plus/user/" .. user .. "/" .. sourceRevision .. "/modules")
        createFolder("hydroxide_plus/user/" .. user .. "/" .. sourceRevision .. "/objects")
        createFolder("hydroxide_plus/user/" .. user .. "/" .. sourceRevision .. "/ui")
        createFolder("hydroxide_plus/user/" .. user .. "/" .. sourceRevision .. "/ui/controls")
        createFolder("hydroxide_plus/user/" .. user .. "/" .. sourceRevision .. "/ui/modules")
        createFolder("hydroxide_plus/assets")
    end

    if not ran or version ~= result then
        function environment.import(asset)
            if importCache[asset] then
                return unpack(importCache[asset])
            end

            local assets

            if asset:find("rbxassetid://") then
                assets = { loadAsset(asset) }
            elseif web then
                if readFile and writeFile then
                    local file = luaCachePath(asset, hasFolderFunctions)
                    local content

                    if (isFile and not isFile(file)) or not importCache[asset] then
                        content = httpGet(rawUrl(asset .. ".lua"))
                        writeFile(file, content)
                    else
                        local ran, result = pcall(readFile, file)

                        if (not ran) or not importCache[asset] then
                            content = httpGet(rawUrl(asset .. ".lua"))
                            writeFile(file, content)
                        else
                            content = result
                        end
                    end

                    assets = { loadstring(content, luaChunkName(asset))() }
                else
                    assets = { loadstring(httpGet(rawUrl(asset .. ".lua")), luaChunkName(asset))() }
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
                local file = luaCachePath(asset, hasFolderFunctions)
                local ran, result = pcall(readFile, file)
                local content

                if not ran then
                    content = httpGet(rawUrl(asset .. ".lua"))
                    writeFile(file, content)
                else
                    content = result
                end

                assets = { loadstring(content, luaChunkName(asset))() }
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
