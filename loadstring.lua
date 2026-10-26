local owner = "NPSummers"
local repo = "Hydroxide-"
local branch = "main"
local HttpService = game:GetService("HttpService")

local function fetch(url)
    if request then
        local success, response = pcall(request, { Url = url, Method = "GET" })

        if success and response and response.Success then
            return response.Body
        end
    end

    return game:HttpGet(url)
end

local commitInfo = HttpService:JSONDecode(fetch(("https://api.github.com/repos/%s/%s/commits/%s?_=%s"):format(owner, repo, branch, tostring(os.time()))))
local commit = assert(commitInfo.sha, "GitHub did not return a commit ID")

assert(commit:match("^[%x]+$") and (#commit == 40 or #commit == 64), "GitHub returned an invalid commit ID")
getgenv().__HYDROXIDE_COMMIT = commit

local function webImport(file)
    local url = ("https://raw.githubusercontent.com/%s/%s/%s/%s.lua"):format(owner, repo, commit, file)
    return loadstring(fetch(url), ("%s.lua@%s"):format(file, commit))()
end

webImport("init")
webImport("ui/main")
