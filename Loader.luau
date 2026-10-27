-- ==============================================================================
--                   ARMON HUB - UNIVERSAL REMOTE LOADER
--                   Automatic Live Sync & In-Memory Execution
-- ==============================================================================

repeat task.wait() until game:IsLoaded()

local UserConfig = getgenv().ArmonConfig or {}
local pcName = UserConfig.PC_NAME or UserConfig.pc_name or UserConfig.pc or "PC-001"
local hostUrl = UserConfig.api_url or UserConfig.loader_url or "https://sacred-down-strategy-interact.trycloudflare.com"

-- Clean domain to fetch script
local baseDomain = hostUrl:match("^(https?://[^/]+)") or "https://sacred-down-strategy-interact.trycloudflare.com"
local loaderUrl = baseDomain .. "/api/script.luau?pc=" .. tostring(pcName)

local success, result = pcall(function()
    return game:HttpGet(loaderUrl)
end)

if success and result and result ~= "" then
    local fn, err = loadstring(result)
    if fn then
        fn()
    else
        warn("[Armon Hub Loader] Syntax error in fetched script: " .. tostring(err))
    end
else
    warn("[Armon Hub Loader] Failed to fetch script from server: " .. tostring(result))
end
