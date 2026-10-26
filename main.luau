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

-- ดึงข้อมูลสดจากระบบ Bloodlines โดยตรง (Environment / _G / Live Variables / RemoteFunction)
local function getBloodlinesData()
    local renvG = nil
    if getrenv and typeof(getrenv) == "function" then
        pcall(function() renvG = getrenv()._G end)
    end

    local d = (renvG and renvG.Data) or _G.Data
    local mainData = (renvG and renvG.mainData) or _G.mainData
    local vData = (renvG and renvG.v) or _G.v

    if not d or typeof(d) ~= "table" then
        local Rep = game:GetService("ReplicatedStorage")
        local Events = Rep:FindFirstChild("Events")
        if Events and Events:FindFirstChild("DataFunction") then
            pcall(function()
                local d1, d2 = Events.DataFunction:InvokeServer("GetData")
                if typeof(d1) == "table" then d = d1 end
                if typeof(d2) == "table" and not mainData then mainData = d2 end
            end)
        end
    end

    if not d or typeof(d) ~= "table" then
        d = {}
    end

    pcall(function()
        d._v = vData
        d._mainData = mainData
    end)

    return d
end

local function scanBackpack(blData)
    local items = {}
    local itemMap = {}
    local recordedSlots = {} -- [slotId] = { name = itemName, count = qty }

    local renvG = nil
    if getrenv and typeof(getrenv) == "function" then
        pcall(function() renvG = getrenv()._G end)
    end

    blData = blData or getBloodlinesData()
    local liveV = (blData and blData._v) or (renvG and renvG.v) or _G.v
    local liveMainData = (blData and blData._mainData) or (renvG and renvG.mainData) or _G.mainData

    local function recordSlot(slotId, name, count)
        if not name or name == "" or typeof(name) ~= "string" then return end
        name = name:match("^%s*(.-)%s*$") -- Trim whitespace
        if name == "" or name == "None" or name == "Empty" then return end
        count = math.max(1, tonumber(count) or 1)

        if not recordedSlots[slotId] then
            recordedSlots[slotId] = { name = name, count = count }
        else
            recordedSlots[slotId].count = math.max(recordedSlots[slotId].count, count)
            if recordedSlots[slotId].name == "" then
                recordedSlots[slotId].name = name
            end
        end
    end

    local function scanSlotTable(tbl, prefix)
        if typeof(tbl) ~= "table" then return end
        for k, slot in pairs(tbl) do
            local slotKey = tostring(k)
            if typeof(slot) == "table" then
                local itemName = slot.Item or slot.name or slot.Name or slot.item
                if itemName and typeof(itemName) == "string" and itemName ~= "" then
                    local qty = tonumber(slot.Quantity or slot.count or slot.Count or slot.qty or slot.amount) or 1
                    recordSlot(prefix .. slotKey, itemName, qty)
                end
            elseif typeof(slot) == "string" and slot ~= "" then
                recordSlot(prefix .. slotKey, slot, 1)
            elseif typeof(k) == "string" and not tonumber(k) and (typeof(slot) == "number" or typeof(slot) == "boolean") then
                local qty = typeof(slot) == "number" and slot or 1
                if qty > 0 then
                    recordSlot(prefix .. slotKey, k, qty)
                end
            end
        end
    end

    -- 1. แหล่งที่ 1: สแกนจาก Memory Tables (_G.v, _G.mainData, _G.Data)
    -- 1.1 Hotbar / Loadout (1 - 12)
    if liveV and typeof(liveV.Loadout) == "table" then
        scanSlotTable(liveV.Loadout, "Loadout_")
    end
    if blData and typeof(blData.Loadout) == "table" then
        scanSlotTable(blData.Loadout, "Loadout_")
    end

    -- 1.2 กระเป๋า Inventory (1 - 154)
    if liveV and typeof(liveV.Inventory) == "table" then
        scanSlotTable(liveV.Inventory, "Inv_")
    end
    if blData and typeof(blData.Inventory) == "table" then
        scanSlotTable(blData.Inventory, "Inv_")
    end

    -- 1.3 ตู้เซฟธนาคาร (Bank Storage)
    if liveMainData and typeof(liveMainData.Bank) == "table" and typeof(liveMainData.Bank.Slots) == "table" then
        scanSlotTable(liveMainData.Bank.Slots, "Bank_")
    end

    -- 1.4 หมวด Souls / Scrolls / Equipment ใน Memory (ถ้ามี)
    if liveV and typeof(liveV.Souls) == "table" then scanSlotTable(liveV.Souls, "Soul_") end
    if blData and typeof(blData.Souls) == "table" then scanSlotTable(blData.Souls, "Soul_") end
    if liveV and typeof(liveV.Scrolls) == "table" then scanSlotTable(liveV.Scrolls, "Scroll_") end
    if blData and typeof(blData.Scrolls) == "table" then scanSlotTable(blData.Scrolls, "Scroll_") end
    if liveV and typeof(liveV.Equipment) == "table" then scanSlotTable(liveV.Equipment, "Equip_") end
    if blData and typeof(blData.Equipment) == "table" then scanSlotTable(blData.Equipment, "Equip_") end

    -- 2. แหล่งที่ 2: สแกนจากหน้าจอ UI (ClientGui) โดยตรง (ตรวจจับไอเทมสดที่แสดงผล)
    pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        local clientGui = playerGui and playerGui:FindFirstChild("ClientGui")
        local mainframe = clientGui and clientGui:FindFirstChild("Mainframe")
        local loadoutGui = mainframe and mainframe:FindFirstChild("Loadout")

        if loadoutGui then
            -- 2.1 สแกน Hotbar ช่อง Slot1 - Slot12
            for i = 1, 12 do
                local slotFrame = loadoutGui:FindFirstChild("Slot" .. i)
                if slotFrame then
                    local slotText = slotFrame:FindFirstChild("SlotText")
                    local text = slotText and slotText.Text or ""
                    if text ~= "" then
                        local qty = 1
                        local itemNum = slotFrame:FindFirstChild("ItemNumber")
                        local numLabel = itemNum and (itemNum:FindFirstChild("Number") or (itemNum:IsA("TextLabel") and itemNum))
                        if numLabel and numLabel.Text and numLabel.Text ~= "" then
                            local parsed = numLabel.Text:gsub("%D+", "")
                            qty = tonumber(parsed) or 1
                        end
                        recordSlot("Loadout_" .. tostring(i), text, qty)
                    end
                end
            end

            -- 2.2 สแกนกระเป๋าเป้ (InventoryScroll Frame: InvSlot1 - InvSlot154)
            local invGui = loadoutGui:FindFirstChild("Inventory")
            local invScroll = invGui and invGui:FindFirstChild("InventoryScroll")
            local invFrame = invScroll and invScroll:FindFirstChild("Frame")
            if invFrame then
                for _, child in ipairs(invFrame:GetChildren()) do
                    if child.Name:match("^InvSlot") then
                        local slotIdx = child.Name:match("%d+") or child.Name
                        local slotText = child:FindFirstChild("SlotText")
                        local text = slotText and slotText.Text or ""
                        if text ~= "" then
                            local qty = 1
                            local itemNum = child:FindFirstChild("ItemNumber")
                            local numLabel = itemNum and (itemNum:FindFirstChild("Number") or (itemNum:IsA("TextLabel") and itemNum))
                            if numLabel and numLabel.Text and numLabel.Text ~= "" then
                                local parsed = numLabel.Text:gsub("%D+", "")
                                qty = tonumber(parsed) or 1
                            end
                            recordSlot("Inv_" .. tostring(slotIdx), text, qty)
                        end
                    end
                end
            end

            -- 2.3 สแกนคลังธนาคาร (BankScroll Slots)
            local bankGui = loadoutGui:FindFirstChild("Bank")
            local bankScroll = bankGui and bankGui:FindFirstChild("BankScroll")
            if bankScroll then
                for _, child in ipairs(bankScroll:GetChildren()) do
                    if child.Name:match("Slot") then
                        local slotAttr = child:GetAttribute("SlotNumber")
                        local slotIdx = slotAttr and tostring(slotAttr) or (child.Name:match("%d+") or child.Name)
                        local slotText = child:FindFirstChild("SlotText")
                        local text = slotText and slotText.Text or ""
                        if text ~= "" then
                            local qty = 1
                            local itemNum = child:FindFirstChild("ItemNumber")
                            local numLabel = itemNum and (itemNum:FindFirstChild("Number") or (itemNum:IsA("TextLabel") and itemNum))
                            if numLabel and numLabel.Text and numLabel.Text ~= "" then
                                local parsed = numLabel.Text:gsub("%D+", "")
                                qty = tonumber(parsed) or 1
                            end
                            recordSlot("Bank_" .. tostring(slotIdx), text, qty)
                        end
                    end
                end
            end
        end
    end)

    -- รวมจำนวนไอเทมของทุกช่องที่บันทึกได้
    for _, slotData in pairs(recordedSlots) do
        itemMap[slotData.name] = (itemMap[slotData.name] or 0) + slotData.count
    end

    -- 3. ตรวจสอบของในกระเป๋ามาตรฐาน (Backpack) และบนตัวละคร (Character - ทั้ง Tool และ Accessory สวมใส่ เช่น Ice Wraps)
    local function addTool(tool)
        if tool and (tool:IsA("Tool") or tool:IsA("Accessory")) then
            local itemName = tool.Name:match("^%s*(.-)%s*$")
            if itemName ~= "" and itemName ~= "HumanoidRootPart" and itemName ~= "Head" then
                itemMap[itemName] = (itemMap[itemName] or 0) + 1
            end
        end
    end

    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            addTool(tool)
        end
    end

    local char = player.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            addTool(tool)
        end
    end

    -- 4. ตรวจสอบโฟลเดอร์เก็บของในเกม (Inventory, Items, BackpackFolder, Data, Souls, Scrolls)
    local possibleFolders = {
        player:FindFirstChild("Inventory"),
        player:FindFirstChild("Items"),
        player:FindFirstChild("BackpackFolder"),
        player:FindFirstChild("Tools"),
        player:FindFirstChild("Equipment"),
        player:FindFirstChild("Equipped"),
        player:FindFirstChild("Souls"),
        player:FindFirstChild("Scrolls"),
        player:FindFirstChild("Data") and player.Data:FindFirstChild("Inventory"),
        player:FindFirstChild("Data") and player.Data:FindFirstChild("Items"),
        player:FindFirstChild("Data") and player.Data:FindFirstChild("Souls"),
        player:FindFirstChild("Data") and player.Data:FindFirstChild("Scrolls")
    }

    for _, folder in ipairs(possibleFolders) do
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                local itemName = item.Name:match("^%s*(.-)%s*$")
                if itemName ~= "" and not itemMap[itemName] then
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
    end

    -- 5. ตรวจสอบ Custom Items จาก Config (ถ้ามีระบุไว้ใน ArmonConfig)
    if UserConfig.custom_items and type(UserConfig.custom_items) == "table" then
        for _, cItem in ipairs(UserConfig.custom_items) do
            if type(cItem) == "table" and cItem.name then
                local cName = tostring(cItem.name):match("^%s*(.-)%s*$")
                itemMap[cName] = (itemMap[cName] or 0) + (tonumber(cItem.count) or 1)
            elseif type(cItem) == "string" then
                local cName = cItem:match("^%s*(.-)%s*$")
                itemMap[cName] = (itemMap[cName] or 0) + 1
            end
        end
    end

    -- โหลดโมดูล GameManager สำหรับดึง Asset ID รูปภาพของเกม
    local Rep = game:GetService("ReplicatedStorage")
    local GM = nil
    pcall(function()
        if Rep:FindFirstChild("GameManager") then
            GM = require(Rep.GameManager)
        end
    end)

    -- แปลงเป็นโครงสร้างที่เว็บต้องการ
    for name, count in pairs(itemMap) do
        local rarity = "RARE"
        local lower = name:lower()
        if lower:find("candy") or lower:find("pumpkin") or lower:find("firework") or lower:find("snow") or lower:find("wings") or lower:find("halo") then
            rarity = "EVENT"
        elseif lower:find("mythic") or lower:find("affinity") or lower:find("token") then
            rarity = "MYTHIC"
        elseif lower:find("legendary") or lower:find("fruit") or lower:find("soul") or lower:find("schematics") or lower:find("eyes") then
            rarity = "LEGENDARY"
        elseif lower:find("uncommon") or lower:find("bowl") or lower:find("mask") or lower:find("soup") then
            rarity = "UNCOMMON"
        end

        -- ค้นหา Asset ID และ URL รูปภาพจริงของไอเทม
        local itemIcon = "⚔️"
        local assetId = nil
        local storeUrl = nil

        if GM then
            local ok, id = pcall(function() return GM:getImageId(name) end)
            if (not ok or not id or tostring(id) == "" or tostring(id) == "false") and GM.Items then
                -- ค้นหาแบบ Case-Insensitive เผื่อกรณีชื่อเขียนตัวพิมพ์เล็ก/ใหญ่ต่างกัน
                pcall(function()
                    local lowerName = name:lower()
                    for k, v in pairs(GM.Items) do
                        if tostring(k):lower() == lowerName and typeof(v) == "table" and v.ID and tostring(v.ID) ~= "" then
                            id = v.ID
                            break
                        end
                    end
                end)
            end

            if id and tostring(id) ~= "" and tostring(id) ~= "false" then
                assetId = tostring(id)
                itemIcon = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. assetId .. "&width=150&height=150&format=png"
                storeUrl = "https://create.roblox.com/store/asset/" .. assetId .. "/Texture"
            end
        end

        table.insert(items, {
            name = name,
            count = count,
            rarity = rarity,
            icon = itemIcon,
            assetId = assetId,
            storeUrl = storeUrl,
            glow = rarity == "EVENT" and "fuchsia" or rarity == "MYTHIC" and "red" or rarity == "LEGENDARY" and "amber" or "sky"
        })
    end

    return items
end

local function getPlayerData(blData)
    blData = blData or getBloodlinesData()
    local level = 1
    local wen = 0
    local ryo = 0
    local acumen = 0
    local embers = 0
    local race = "Human"
    local bloodline = "None"
    local clan = "None"
    local clanRole = ""
    local village = ""
    local rank = ""
    local age = 0

    if blData then
        ryo = tonumber(blData.Ryo) or 0
        wen = ryo
        acumen = tonumber(blData.Acumen) or 0
        level = acumen > 0 and acumen or 1
        embers = tonumber(blData.Embers) or 0
        bloodline = tostring(blData.Bloodline or "None")
        clan = tostring(blData.Clan or "None")
        village = tostring(blData.Village or "")
        rank = tostring(blData.Rank or "")
        age = tonumber(blData.Age) or 0

        -- ตรวจสอบแคลนเพิ่มเติมจาก mainData และ _v ใน Memory
        if (clan == "None" or clan == "") and blData._mainData and typeof(blData._mainData) == "table" then
            clan = tostring(blData._mainData.Clan or blData._mainData.ClanName or blData._mainData.Clans or clan)
            if bloodline == "None" or bloodline == "" then
                bloodline = tostring(blData._mainData.Bloodline or bloodline)
            end
        end
        if (clan == "None" or clan == "") and blData._v and typeof(blData._v) == "table" then
            clan = tostring(blData._v.Clan or blData._v.ClanName or clan)
            if bloodline == "None" or bloodline == "" then
                bloodline = tostring(blData._v.Bloodline or bloodline)
            end
        end
    end

    -- ดึงค่าเงิน สกุลเงิน แคลน และสายเลือดสำรองจาก GUI
    pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        local clientGui = playerGui and playerGui:FindFirstChild("ClientGui")
        local mainframe = clientGui and clientGui:FindFirstChild("Mainframe")

        if mainframe then
            if ryo == 0 and mainframe:FindFirstChild("Ryo") and mainframe.Ryo:FindFirstChild("Amount") then
                local rText = mainframe.Ryo.Amount.Text:gsub("%D+", "")
                ryo = tonumber(rText) or ryo
                wen = ryo
            end
            if acumen == 0 and mainframe:FindFirstChild("Acumen") and mainframe.Acumen:FindFirstChild("Amount") then
                local aText = mainframe.Acumen.Amount.Text:gsub("%D+", "")
                acumen = tonumber(aText) or acumen
                level = acumen > 0 and acumen or level
            end
            if embers == 0 and mainframe:FindFirstChild("Embers") and mainframe.Embers:FindFirstChild("Amount") then
                local eText = mainframe.Embers.Amount.Text:gsub("%D+", "")
                embers = tonumber(eText) or embers
            end

            -- ตรวจสอบแคลนจาก SlotClans GUI (ช่อง Clan1, Clan2, Clan3)
            if (clan == "None" or clan == "") and mainframe:FindFirstChild("SlotClans") then
                for _, slotName in ipairs({"Clan1", "Clan2", "Clan3"}) do
                    local slot = mainframe.SlotClans:FindFirstChild(slotName)
                    if slot and slot:FindFirstChild("ClanName") and slot.ClanName.Text ~= "" and slot.ClanName.Text ~= "No Clan" and slot.ClanName.Text ~= "None" then
                        clan = slot.ClanName.Text
                        break
                    end
                end
            end
        end
    end)

    -- ตรวจสอบจาก Attributes ของ Player และ Character
    pcall(function()
        if (clan == "None" or clan == "") then
            local pClan = player:GetAttribute("Clan") or player:GetAttribute("ClanName")
            if pClan and tostring(pClan) ~= "" and tostring(pClan) ~= "None" then
                clan = tostring(pClan)
            end
        end
        if (bloodline == "None" or bloodline == "") then
            local pBl = player:GetAttribute("Bloodline") or player:GetAttribute("Lineage")
            if pBl and tostring(pBl) ~= "" and tostring(pBl) ~= "None" then
                bloodline = tostring(pBl)
            end
        end
        if player.Character then
            if (clan == "None" or clan == "") then
                local cClan = player.Character:GetAttribute("Clan")
                if cClan and tostring(cClan) ~= "" and tostring(cClan) ~= "None" then
                    clan = tostring(cClan)
                end
            end
        end
    end)

    -- แคช Clan และ Bloodline ไว้ในตัวแปร Global ป้องกันการสูญหายเมื่อ respawn หรือสลับแมพ
    if clan and clan ~= "None" and clan ~= "" and clan ~= "No Clan" and clan ~= "-" then
        _G.ArmonCachedClan = clan
    elseif _G.ArmonCachedClan and _G.ArmonCachedClan ~= "" and _G.ArmonCachedClan ~= "None" then
        clan = _G.ArmonCachedClan
    end

    if bloodline and bloodline ~= "None" and bloodline ~= "" and bloodline ~= "-" then
        _G.ArmonCachedBloodline = bloodline
    elseif _G.ArmonCachedBloodline and _G.ArmonCachedBloodline ~= "" and _G.ArmonCachedBloodline ~= "None" then
        bloodline = _G.ArmonCachedBloodline
    end

    if (clan == "None" or clan == "") and (bloodline ~= "None" and bloodline ~= "") then
        race = bloodline
    elseif clan ~= "None" and clan ~= "" then
        race = clan
    end

    -- ดึงจากโฟลเดอร์ Stats / leaderstats
    local statsFolder = player:FindFirstChild("leaderstats") or player:FindFirstChild("Stats") or player:FindFirstChild("Data")
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
        race = race,             -- ส่งสายเลือด เช่น Zetsu
        bloodline = bloodline,   -- ส่งสายเลือดนินจา
        clan = clan,             -- ส่งชื่อแคลน
        clanRole = clanRole,     -- ตำแหน่งในแคลน
        village = village,
        rank = rank,
        age = age,
        hp = hp,
        maxHp = maxHp
    }
end

local function sendLiveSync()
    local blData = getBloodlinesData()
    local pData = getPlayerData(blData)
    local backpackItems = scanBackpack(blData)

    -- คำนวณเวลาออนไลน์ต่อเนื่องของตัวเกม (DistributedGameTime / os.clock)
    local sessionUptime = 0
    pcall(function()
        sessionUptime = math.floor(workspace.DistributedGameTime or 0)
        if sessionUptime <= 0 then
            sessionUptime = math.floor(os.clock() or 0)
        end
    end)

    local payload = {
        apiKey = Config.api_key,
        game = Config.game,
        placeId = Config.place_id,
        gameId = Config.game_id,
        pc = Config.pc_name,
        discordId = Config.discord_id,
        uptime = sessionUptime,
        account = {
            username = player.Name,
            displayName = player.DisplayName,
            userId = player.UserId,
            placeId = Config.place_id,
            uptime = sessionUptime,       -- ส่งระยะเวลาที่ออนไลน์จริงในเซสชันนี้
            level = pData.level,
            race = pData.race,
            bloodline = pData.bloodline, -- [รวมแล้ว] สายเลือดนินจา (เช่น Zetsu)
            clan = pData.clan,           -- [รวมแล้ว] ชื่อแคลน
            clanRole = pData.clanRole ~= "" and pData.clanRole or nil,
            village = pData.village ~= "" and pData.village or nil,
            rank = pData.rank ~= "" and pData.rank or nil,
            age = pData.age > 0 and pData.age or nil,
            wen = pData.wen,
            ryo = pData.ryo,
            acumen = pData.acumen,
            embers = pData.embers,
            ember = pData.embers,
            items = backpackItems,       -- รายการไอเทมทั้งหมดรวม Souls, Scrolls, Wraps
            stats = {
                hp = pData.hp,
                maxHp = pData.maxHp,
                stamina = 100,
                maxStamina = 100,
                ryo = pData.ryo,
                acumen = pData.acumen,
                embers = pData.embers,
                ember = pData.embers,
                bloodline = pData.bloodline,
                clan = pData.clan
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

-- ฟังก์ชันแจ้งเตือนออฟไลน์ทันทีเมื่อผู้เล่นปิดเกม หรือออกจากเซิร์ฟเวอร์
local function sendOfflineNotice()
    pcall(function()
        local payload = {
            apiKey = Config.api_key,
            game = Config.game,
            placeId = Config.place_id,
            pc = Config.pc_name,
            discordId = Config.discord_id,
            isOffline = true,
            account = {
                username = player.Name,
                userId = player.UserId,
                statusType = "offline"
            }
        }
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            req({
                Url = Config.api_url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["bypass-tunnel-reminder"] = "true"
                },
                Body = HttpService:JSONEncode(payload)
            })
        end
    end)
end

-- ดักจับเหตุการณ์ตอนปิดเกม (Graceful Disconnect)
pcall(function()
    game:BindToClose(function()
        sendOfflineNotice()
    end)
end)

pcall(function()
    Players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            sendOfflineNotice()
        end
    end)
end)

-- รอให้ข้อมูลในเกมและ GUI โหลดให้สมบูรณ์ก่อนส่งรอบแรก
task.wait(2.5)

-- ส่งข้อมูลทันทีเมื่อโหลดเสร็จ
sendLiveSync()

-- วนลูปส่ง Heartbeat ทุกๆ ช่วงเวลาที่กำหนด (sync_interval)
task.spawn(function()
    while true do
        task.wait(Config.sync_interval or 30)
        sendLiveSync()
    end
end)
