-- ==============================================================================
--                      ARMON HUB - UNIVERSAL ROBLOX SCRIPT
--                 Supports Multi-Map Auto Detection & Live Sync
--                      (100% Silent Mode - No Console Prints)
-- ==============================================================================

repeat task.wait() until game:IsLoaded()

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StatsService = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer

-- Configuration
local UserConfig = getgenv().ArmonConfig or {}
local currentPlaceId = game.PlaceId
local currentGameId = game.GameId

-- Mapping Place IDs directly to Armon Hub games (รันได้ทุกแมพ)
local PLACE_ID_MAPPING = {
    -- Bloodlines
    [10266164381] = "[⌛] Bloodlines",
    [5571328985]  = "[⌛] Bloodlines",

    -- Project Slayers
    [5956785391]  = "Project Slayers",
    [6938803436]  = "Project Slayers",
    [11468159863] = "Project Slayers",

    -- Blox Fruits
    [2753915549]  = "Blox Fruits",
    [4442272183]  = "Blox Fruits",
    [7449423635]  = "Blox Fruits",

    -- King Legacy
    [4520749081]  = "King Legacy",
    [6375144348]  = "King Legacy",

    -- Fisch
    [16732694052] = "Fisch",

    -- Rivals
    [17625359962] = "Rivals",

    -- Anime Vanguards
    [16146832113] = "Anime Vanguards"
}

-- Auto Detect Game Name from PlaceId or Marketplace
local detectedGame = PLACE_ID_MAPPING[currentPlaceId]
if not detectedGame then
    pcall(function()
        local info = MarketplaceService:GetProductInfo(currentPlaceId)
        if info and info.Name then
            detectedGame = info.Name
        end
    end)
end
if not detectedGame or detectedGame == "" then
    detectedGame = "[⌛] Bloodlines"
end

local Config = {
    api_url       = UserConfig.api_url or UserConfig.apiUrl or "https://maple-providers-scenic-homework.trycloudflare.com/api/sync",
    api_key       = UserConfig.api_key or UserConfig.apiKey or "armon-hub-2026",
    pc_name       = UserConfig.PC_NAME or UserConfig.pc_name or UserConfig.pc or "PC-001",
    discord_id    = UserConfig.discord_id or UserConfig.discordId or "825282265609011211",
    game          = UserConfig.game or detectedGame,
    place_id      = currentPlaceId,
    game_id       = currentGameId,
    sync_interval = tonumber(UserConfig.sync_interval) or 30
}

local function getPing()
    local ping = 45
    pcall(function()
        local item = StatsService.Network.ServerStatsItem["Data Ping"]
        if item then
            ping = math.floor(item:GetValue())
        end
    end)
    return ping
end

-- ดึงข้อมูลสดจากระบบ Bloodlines โดยตรง (Environment / _G / RemoteFunction)
local function getBloodlinesData()
    if getrenv and typeof(getrenv) == "function" then
        local ok, renv = pcall(getrenv)
        if ok and renv and renv._G and typeof(renv._G.Data) == "table" and renv._G.Data.Inventory then
            return renv._G.Data
        end
    end

    if typeof(_G.Data) == "table" and _G.Data.Inventory and _G.Data.Loadout then
        return _G.Data
    end

    local Rep = game:GetService("ReplicatedStorage")
    local Events = Rep:FindFirstChild("Events")
    if Events and Events:FindFirstChild("DataFunction") then
        local success, res = pcall(function()
            return Events.DataFunction:InvokeServer("GetData")
        end)
        if success and typeof(res) == "table" and res.Inventory then
            return res
        end
    end

    return nil
end

local function scanBackpack(blData)
    local items = {}
    local itemMap = {}

    local function addTool(tool)
        if tool and tool:IsA("Tool") then
            local itemName = tool.Name
            itemMap[itemName] = (itemMap[itemName] or 0) + 1
        end
    end

    -- 1. ตรวจสอบข้อมูลไอเทมจาก Bloodlines โดยตรง (Hotbar 1-12 & กระเป๋า Inventory 1-154)
    blData = blData or getBloodlinesData()
    if blData then
        -- ตรวจสอบช่อง Hotbar / Loadout (1 - 12)
        if blData.Loadout and typeof(blData.Loadout) == "table" then
            for i = 1, 12 do
                local slot = blData.Loadout[tostring(i)]
                if slot and slot.Item and slot.Item ~= "" then
                    local qty = tonumber(slot.Quantity) or 1
                    itemMap[slot.Item] = (itemMap[slot.Item] or 0) + qty
                end
            end
        end

        -- ตรวจสอบช่อง Inventory (1 - 154)
        if blData.Inventory and typeof(blData.Inventory) == "table" then
            for _, slot in pairs(blData.Inventory) do
                if slot and slot.Item and slot.Item ~= "" then
                    local qty = tonumber(slot.Quantity) or 1
                    itemMap[slot.Item] = (itemMap[slot.Item] or 0) + qty
                end
            end
        end
    end

    -- 2. ตรวจสอบของในกระเป๋ามาตรฐาน (Backpack)
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            addTool(tool)
        end
    end

    -- 3. ตรวจสอบของที่ถืออยู่ในมือ (Character)
    local char = player.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            addTool(tool)
        end
    end

    -- 4. ตรวจสอบโฟลเดอร์เก็บของในเกม (Inventory, Items, BackpackFolder, Data)
    local possibleFolders = {
        player:FindFirstChild("Inventory"),
        player:FindFirstChild("Items"),
        player:FindFirstChild("BackpackFolder"),
        player:FindFirstChild("Tools"),
        player:FindFirstChild("Data") and player.Data:FindFirstChild("Inventory"),
        player:FindFirstChild("Data") and player.Data:FindFirstChild("Items")
    }

    for _, folder in ipairs(possibleFolders) do
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                local itemName = item.Name
                local count = 1
                if item:IsA("NumberValue") or item:IsA("IntValue") then
                    count = math.max(1, tonumber(item.Value) or 1)
                elseif item:FindFirstChild("Amount") or item:FindFirstChild("Count") or item:FindFirstChild("Quantity") then
                    local val = item:FindFirstChild("Amount") or item:FindFirstChild("Count") or item:FindFirstChild("Quantity")
                    count = math.max(1, tonumber(val.Value) or 1)
                end
                itemMap[itemName] = (itemMap[itemName] or 0) + count
            end
        end
    end

    -- 5. ตรวจสอบ Custom Items จาก Config (ถ้ามีระบุไว้ใน ArmonConfig)
    if UserConfig.custom_items and type(UserConfig.custom_items) == "table" then
        for _, cItem in ipairs(UserConfig.custom_items) do
            if type(cItem) == "table" and cItem.name then
                itemMap[cItem.name] = (itemMap[cItem.name] or 0) + (tonumber(cItem.count) or 1)
            elseif type(cItem) == "string" then
                itemMap[cItem] = (itemMap[cItem] or 0) + 1
            end
        end
    end

    -- แปลงเป็นโครงสร้างส่งเข้าเว็บ (ระบบเว็บจะจับคู่รูปภาพแท้ในระบบให้อัตโนมัติจากชื่อไอเทม)
    for name, count in pairs(itemMap) do
        local rarity = "RARE"
        local lower = name:lower()
        if lower:find("mythic") or lower:find("sun") or lower:find("crimson") or lower:find("haori") then
            rarity = "MYTHIC"
        elseif lower:find("legendary") or lower:find("tome") or lower:find("mark") or lower:find("remedy") then
            rarity = "LEGENDARY"
        elseif lower:find("uncommon") or lower:find("ticket") then
            rarity = "UNCOMMON"
        end

        table.insert(items, {
            name = name,
            count = count,
            rarity = rarity
        })
    end

    return items
end

local function getPlayerData(blData)
    local level = 1
    local wen = 0
    local ryo = 0
    local acumen = 0
    local embers = 0
    local race = "Human"
    local clan = "None"

    -- 1. [ลำดับแรก] ดึงจาก GUI ของ Bloodlines โดยตรง (ClientGui.Mainframe)
    pcall(function()
        local clientGui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("ClientGui")
        if clientGui and clientGui:FindFirstChild("Mainframe") then
            local mf = clientGui.Mainframe

            -- Ryo จาก ClientGui.Mainframe.Ryo.Amount.Text
            if mf:FindFirstChild("Ryo") and mf.Ryo:FindFirstChild("Amount") then
                local obj = mf.Ryo.Amount
                local raw = (obj:IsA("TextLabel") or obj:IsA("TextBox")) and obj.Text or (obj.Value and tostring(obj.Value))
                if raw then
                    local clean = tostring(raw):gsub("[^%d]", "")
                    if clean ~= "" then
                        ryo = tonumber(clean) or ryo
                        wen = ryo
                    end
                end
            end

            -- Acumen จาก ClientGui.Mainframe.Acumen.Amount.Text
            if mf:FindFirstChild("Acumen") and mf.Acumen:FindFirstChild("Amount") then
                local obj = mf.Acumen.Amount
                local raw = (obj:IsA("TextLabel") or obj:IsA("TextBox")) and obj.Text or (obj.Value and tostring(obj.Value))
                if raw then
                    local clean = tostring(raw):gsub("[^%d]", "")
                    if clean ~= "" then
                        acumen = tonumber(clean) or acumen
                        level = acumen
                    end
                end
            end

            -- Embers จาก ClientGui.Mainframe.Embers.Amount.Text
            if mf:FindFirstChild("Embers") and mf.Embers:FindFirstChild("Amount") then
                local obj = mf.Embers.Amount
                local raw = (obj:IsA("TextLabel") or obj:IsA("TextBox")) and obj.Text or (obj.Value and tostring(obj.Value))
                if raw then
                    local clean = tostring(raw):gsub("[^%d]", "")
                    if clean ~= "" then
                        embers = tonumber(clean) or embers
                    end
                end
            end
        end
    end)

    -- 2. ดึงจาก Bloodlines Data (กรณี GUI ยังไม่โหลดหรือเป็น 0)
    blData = blData or getBloodlinesData()
    if blData then
        if blData.Clan and tostring(blData.Clan) ~= "" then
            clan = tostring(blData.Clan)
        end
        if blData.Bloodline and tostring(blData.Bloodline) ~= "" then
            race = tostring(blData.Bloodline)
        end
        if ryo == 0 and blData.Ryo then
            ryo = tonumber(blData.Ryo) or 0
            wen = ryo
        end
        if acumen == 0 and blData.Acumen then
            acumen = tonumber(blData.Acumen) or 0
            level = acumen
        end
        if embers == 0 and blData.Embers then
            embers = tonumber(blData.Embers) or 0
        end
    end

    -- 3. ตรวจสอบ leaderstats เผื่อเกมอื่นๆ
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            local sName = stat.Name:lower()
            if sName:find("ember") and embers == 0 then
                embers = tonumber(stat.Value) or embers
            elseif sName:find("acumen") and acumen == 0 then
                acumen = tonumber(stat.Value) or acumen
                level = acumen
            elseif sName:find("level") or sName:find("lvl") then
                if level == 1 then level = tonumber(stat.Value) or level end
            elseif sName:find("ryo") and ryo == 0 then
                ryo = tonumber(stat.Value) or ryo
                wen = ryo
            elseif sName:find("wen") or sName:find("cash") or sName:find("beli") or sName:find("gold") or sName:find("yen") then
                if wen == 0 then wen = tonumber(stat.Value) or wen end
            elseif sName:find("clan") and clan == "None" then
                clan = tostring(stat.Value)
            elseif sName:find("race") and race == "Human" then
                race = tostring(stat.Value)
            end
        end
    end

    -- 4. ตรวจสอบ Stats หรือ Data Folder อื่นๆ
    local statsFolder = player:FindFirstChild("Stats") or player:FindFirstChild("Data")
    if statsFolder then
        for _, stat in ipairs(statsFolder:GetChildren()) do
            local sName = stat.Name:lower()
            if sName:find("ember") and embers == 0 then
                embers = tonumber(stat.Value) or embers
            elseif sName:find("acumen") and acumen == 0 then
                acumen = tonumber(stat.Value) or acumen
                level = acumen
            elseif sName:find("level") and level == 1 then
                level = tonumber(stat.Value) or level
            elseif sName:find("ryo") and ryo == 0 then
                ryo = tonumber(stat.Value) or ryo
                wen = ryo
            elseif (sName:find("wen") or sName:find("cash") or sName:find("money") or sName:find("yen")) and wen == 0 then
                wen = tonumber(stat.Value) or wen
            elseif sName:find("clan") and clan == "None" then
                clan = tostring(stat.Value)
            elseif sName:find("race") and race == "Human" then
                race = tostring(stat.Value)
            end
        end
    end

    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local hp = humanoid and math.floor(humanoid.Health) or 100
    local maxHp = humanoid and math.floor(humanoid.MaxHealth) or 100

    return {
        level = level,
        wen = wen,
        ryo = ryo,
        acumen = acumen,
        embers = embers,
        race = race,
        clan = clan,
        hp = hp,
        maxHp = maxHp
    }
end

local function sendLiveSync()
    local blData = getBloodlinesData()
    local pData = getPlayerData(blData)
    local backpackItems = scanBackpack(blData)

    local payload = {
        apiKey = Config.api_key,
        game = Config.game,
        placeId = Config.place_id,
        gameId = Config.game_id,
        pc = Config.pc_name,
        discordId = Config.discord_id,
        account = {
            username = player.Name,
            displayName = player.DisplayName,
            userId = player.UserId,
            placeId = Config.place_id,
            level = pData.level,
            race = pData.race,
            clan = pData.clan,
            wen = pData.wen,
            ryo = pData.ryo,
            acumen = pData.acumen,
            embers = pData.embers,
            ember = pData.embers,
            items = backpackItems,      -- รายการไอเทมพร้อม URL รูปภาพจริง
            stats = {
                hp = pData.hp,
                maxHp = pData.maxHp,
                stamina = 100,
                maxStamina = 100,
                ryo = pData.ryo,
                acumen = pData.acumen,
                embers = pData.embers,
                ember = pData.embers
            }
        },
        system = {
            cpu = 20,
            ram = 45,
            ping = getPing()
        }
    }

    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if not requestFunc then
        return
    end

    pcall(function()
        return requestFunc({
            Url = Config.api_url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["bypass-tunnel-reminder"] = "true"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

-- ส่งข้อมูลทันทีเมื่อเปิดสคริปต์
sendLiveSync()

-- วนลูปส่ง Heartbeat ทุกๆ ช่วงเวลาที่กำหนด (sync_interval)
task.spawn(function()
    while true do
        task.wait(Config.sync_interval or 30)
        sendLiveSync()
    end
end)
