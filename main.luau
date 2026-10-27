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
    local recordedSlots = {} -- [slotId] = { name = itemName, count = qty, assetId = aId }
    local itemAssetMap = {}  -- [itemName] = assetId

    local renvG = nil
    if getrenv and typeof(getrenv) == "function" then
        pcall(function() renvG = getrenv()._G end)
    end

    blData = blData or getBloodlinesData()
    local liveV = (blData and blData._v) or (renvG and renvG.v) or _G.v
    local liveMainData = (blData and blData._mainData) or (renvG and renvG.mainData) or _G.mainData

    -- ฟังก์ชันช่วยสกัด Asset ID จาก Instance, Number หรือ String
    local function extractAssetId(obj)
        if not obj then return nil end
        if typeof(obj) == "number" then
            local s = tostring(math.floor(obj))
            if #s >= 4 and tonumber(s) and tonumber(s) > 1000 then return s end
            return nil
        end
        if typeof(obj) == "string" then
            local num = obj:match("%d%d%d%d+")
            if num and tonumber(num) and tonumber(num) > 1000 then return num end
            return nil
        end
        if typeof(obj) == "Instance" then
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                local img = obj.Image
                if img and img ~= "" then
                    local num = tostring(img):match("%d%d%d%d+")
                    if num and tonumber(num) and tonumber(num) > 1000 then return num end
                end
            end
            if obj:IsA("Tool") then
                local tex = obj.TextureId
                if tex and tex ~= "" then
                    local num = tostring(tex):match("%d%d%d%d+")
                    if num and tonumber(num) and tonumber(num) > 1000 then return num end
                end
            end
            if obj:IsA("Decal") or obj:IsA("Texture") then
                local tex = obj.Texture
                if tex and tex ~= "" then
                    local num = tostring(tex):match("%d%d%d%d+")
                    if num and tonumber(num) and tonumber(num) > 1000 then return num end
                end
            end
            if obj:IsA("SpecialMesh") then
                local tex = obj.TextureId
                if tex and tex ~= "" then
                    local num = tostring(tex):match("%d%d%d%d+")
                    if num and tonumber(num) and tonumber(num) > 1000 then return num end
                end
            end
            if obj:IsA("StringValue") or obj:IsA("IntValue") or obj:IsA("NumberValue") then
                local num = tostring(obj.Value):match("%d%d%d%d+")
                if num and tonumber(num) and tonumber(num) > 1000 then return num end
            end
            if obj.GetAttributes then
                local attrs = obj:GetAttributes()
                for k, val in pairs(attrs) do
                    local kl = tostring(k):lower()
                    if kl:find("icon") or kl:find("image") or kl:find("asset") or kl:find("id") or kl:find("tex") then
                        local num = tostring(val):match("%d%d%d%d+")
                        if num and tonumber(num) and tonumber(num) > 1000 then return num end
                    end
                end
            end

            -- ค้นหาใน Descendants: ให้ความสำคัญกับ Element ที่ชื่อระบุว่าเป็นไอคอนของไอเทมก่อน
            local descs = obj:GetDescendants()
            for _, desc in ipairs(descs) do
                if (desc:IsA("ImageLabel") or desc:IsA("ImageButton")) and desc.Image and desc.Image ~= "" then
                    local dname = desc.Name:lower()
                    if dname:find("icon") or dname:find("item") or dname:find("thumb") or dname:find("image") or dname:find("art") or dname:find("slot") then
                        local num = tostring(desc.Image):match("%d%d%d%d+")
                        if num and tonumber(num) and tonumber(num) > 1000 then return num end
                    end
                end
            end

            -- ค้นหาใน Image อื่นๆ ที่ไม่ใช่ Background หรือ Border
            for _, desc in ipairs(descs) do
                if (desc:IsA("ImageLabel") or desc:IsA("ImageButton")) and desc.Image and desc.Image ~= "" then
                    local dname = desc.Name:lower()
                    if not (dname:find("bg") or dname:find("back") or dname:find("border") or dname:find("stroke") or dname:find("shadow") or dname:find("frame") or dname:find("glow") or dname:find("gradient")) then
                        local num = tostring(desc.Image):match("%d%d%d%d+")
                        if num and tonumber(num) and tonumber(num) > 1000 then return num end
                    end
                end
            end
        end
        return nil
    end

    local function recordSlot(slotId, name, count, assetId)
        if not name or name == "" or typeof(name) ~= "string" then return end
        name = name:match("^%s*(.-)%s*$") -- Trim whitespace
        if name == "" or name == "None" or name == "Empty" then return end
        count = math.max(1, tonumber(count) or 1)

        if not recordedSlots[slotId] then
            recordedSlots[slotId] = { name = name, count = count, assetId = assetId }
        else
            recordedSlots[slotId].count = math.max(recordedSlots[slotId].count, count)
            if not recordedSlots[slotId].assetId and assetId then
                recordedSlots[slotId].assetId = assetId
            end
            if recordedSlots[slotId].name == "" then
                recordedSlots[slotId].name = name
            end
        end
        if assetId and not itemAssetMap[name] then
            itemAssetMap[name] = assetId
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
                    local slotImg = slot.ID or slot.Id or slot.AssetId or slot.Image or slot.ImageId or slot.Texture or slot.TextureId or slot.Icon
                    local aId = extractAssetId(slotImg)
                    recordSlot(prefix .. slotKey, itemName, qty, aId)
                end
            elseif typeof(slot) == "string" and slot ~= "" then
                recordSlot(prefix .. slotKey, slot, 1, nil)
            elseif typeof(k) == "string" and not tonumber(k) and (typeof(slot) == "number" or typeof(slot) == "boolean") then
                local qty = typeof(slot) == "number" and slot or 1
                if qty > 0 then
                    recordSlot(prefix .. slotKey, k, qty, nil)
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

    -- 2. แหล่งที่ 2: สแกนจากหน้าจอ UI (ClientGui) โดยตรง (ตรวจจับไอเทมสดและรูปภาพจริงที่แสดงผลบนจอ)
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
                        local aId = extractAssetId(slotFrame)
                        recordSlot("Loadout_" .. tostring(i), text, qty, aId)
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
                            local aId = extractAssetId(child)
                            recordSlot("Inv_" .. tostring(slotIdx), text, qty, aId)
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
                            local aId = extractAssetId(child)
                            recordSlot("Bank_" .. tostring(slotIdx), text, qty, aId)
                        end
                    end
                end
            end

            -- 2.4 สแกน Outfits / Armors / Wardrobe / Customization Slots ใน GUI (ถ้ามี)
            local extraContainers = {
                loadoutGui:FindFirstChild("Outfits"),
                loadoutGui:FindFirstChild("Armor"),
                loadoutGui:FindFirstChild("Clothing"),
                loadoutGui:FindFirstChild("Wardrobe"),
                mainframe and mainframe:FindFirstChild("Outfits"),
                mainframe and mainframe:FindFirstChild("Armor"),
                mainframe and mainframe:FindFirstChild("Wardrobe"),
                mainframe and mainframe:FindFirstChild("Customization")
            }
            for _, cont in ipairs(extraContainers) do
                if cont then
                    for _, child in ipairs(cont:GetDescendants()) do
                        if child:IsA("GuiObject") and (child.Name:match("Slot") or child.Name:match("Item") or child:FindFirstChild("SlotText")) then
                            local slotText = child:FindFirstChild("SlotText") or child:FindFirstChildWhichIsA("TextLabel")
                            local text = slotText and slotText.Text or ""
                            if text ~= "" and text ~= "None" and text ~= "Empty" and not text:match("^%d+$") then
                                local aId = extractAssetId(child)
                                recordSlot("Extra_" .. child.Name .. "_" .. text, text, 1, aId)
                            end
                        end
                    end
                end
            end
        end
    end)

    -- รวมจำนวนไอเทมของทุกช่องที่บันทึกได้
    for _, slotData in pairs(recordedSlots) do
        itemMap[slotData.name] = (itemMap[slotData.name] or 0) + slotData.count
        if slotData.assetId and not itemAssetMap[slotData.name] then
            itemAssetMap[slotData.name] = slotData.assetId
        end
    end

    -- 3. ตรวจสอบของในกระเป๋ามาตรฐาน (Backpack) และบนตัวละคร (Character - ทั้ง Tool และ Accessory สวมใส่ เช่น Ice Wraps)
    local function addTool(tool)
        if tool and (tool:IsA("Tool") or tool:IsA("Accessory")) then
            local itemName = tool.Name:match("^%s*(.-)%s*$")
            if itemName ~= "" and itemName ~= "HumanoidRootPart" and itemName ~= "Head" then
                itemMap[itemName] = (itemMap[itemName] or 0) + 1
                local aId = extractAssetId(tool)
                if aId and not itemAssetMap[itemName] then
                    itemAssetMap[itemName] = aId
                end
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
                    local aId = extractAssetId(item)
                    if aId and not itemAssetMap[itemName] then
                        itemAssetMap[itemName] = aId
                    end
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

    local function cleanKey(str)
        if not str then return "" end
        local s = tostring(str):gsub("’", "'"):gsub("‘", "'")
        return s:lower():gsub("[^%w]", "")
    end

    local KNOWN_BLOODLINES_ASSETS = {
    ["chicken"] = "5526820471",
    ["ramen"] = "6656248718",
    ["chickenangameatbowl"] = "6886885033",
    ["apparangefruitbowl"] = "6656247255",
    ["tangerinafruitbowl"] = "6656248396",
    ["mangananafruitbowl"] = "6656247624",
    ["pumpkinanafruitbowl"] = "11639207784",
    ["pearapplefruitbowl"] = "6656248048",
    ["allstarfruitbowl"] = "6874976278",
    ["shukakusoul"] = "94186640999329",
    ["matatabisoul"] = "126211013131318",
    ["isobusoul"] = "134388170034788",
    ["saltwaterseaweedbowl"] = "6887188283",
    ["apple"] = "5526821264",
    ["candy"] = "96816874499079",
    ["candycane"] = "89991732037434",
    ["alluringapple"] = "17684711150",
    ["alluringfruitbowl"] = "17684725643",
    ["frostypear"] = "79779651415475",
    ["frostedfruitbowl"] = "105758316795124",
    ["pear"] = "5947190893",
    ["banana"] = "5947190031",
    ["enchantedbanana"] = "85958281768667",
    ["orange"] = "5947190615",
    ["mango"] = "5947190287",
    ["pumpkin"] = "11639149080",
    ["groundskey"] = "8722769066",
    ["desolatedkey"] = "8722770053",
    ["cookbook"] = "10361152941",
    ["ayruiaffinity"] = "11163520468",
    ["harunoaffinity"] = "120274348230537",
    ["akimichiaffinity"] = "83991446229526",
    ["senjuaffinity"] = "90557349010965",
    ["gaaraaffinity"] = "118197897617001",
    ["yukiaffinity"] = "122899636836544",
    ["hoshigakiaffinity"] = "11163518681",
    ["uzumakiaffinity"] = "11163519726",
    ["ringschematics"] = "11639167608",
    ["raijinschematics"] = "92329431574626",
    ["spookyraijinschematics"] = "127065269041970",
    ["bloodyraijinschematics"] = "83218771197999",
    ["nutcrackerraijinschematics"] = "108734139668149",
    ["executionerschematics"] = "132018376047931",
    ["bloodyexecutionerschematics"] = "138193011864006",
    ["frozenexecutionerschematics"] = "100761373831631",
    ["samehadaschematics"] = "134060452334251",
    ["pumpkinsamehadaschematics"] = "83781986016789",
    ["treesamehadaschematics"] = "90588159422501",
    ["gunbaischematics"] = "92847231404048",
    ["spidergunbaischematics"] = "74031051961772",
    ["gingerbreadgunbaischematics"] = "112455551008359",
    ["kusanagischematics"] = "90620025231327",
    ["hallowedkusanagischematics"] = "136185921257587",
    ["spookykusanagischematics"] = "111145108401664",
    ["candycanekusanagischematics"] = "100163994513300",
    ["staffschematics"] = "106567006313891",
    ["skeletalstaffschematics"] = "70446772549612",
    ["spikystaffschematics"] = "76457897771624",
    ["jinglebellstaffschematics"] = "93660059382647",
    ["chefskiss"] = "10925183680",
    ["snakeskin"] = "10925200820",
    ["lavasnakeskin"] = "75399420230136",
    ["barbaritwraps"] = "11156020512",
    ["mangekyoeyes"] = "11242510768",
    ["sharinganeyes"] = "10924835061",
    ["ketsuryuganeyes"] = "88724877064873",
    ["byakuganeyes"] = "10924830958",
    ["rinneganeyes"] = "11156009893",
    ["trainingbells"] = "8722715060",
    ["sealingbells"] = "8722722183",
    ["brokenleafarmor"] = "8722712597",
    ["brokenbiyoarmor"] = "10048709777",
    ["brokenmelloarmor"] = "10458592268",
    ["hashiramacells"] = "11639243346",
    ["extractionspoon"] = "11242652553",
    ["parkourscroll"] = "8582006277",
    ["combatscroll"] = "8582006277",
    ["lightningscroll"] = "8789136282",
    ["healingscroll"] = "9480423710",
    ["fighterswraps"] = "11272168715",
    ["chakrascroll"] = "8582006277",
    ["sealingscroll"] = "8582006277",
    ["windscroll"] = "8582006277",
    ["lavahorn"] = "10361137546",
    ["biyorelic"] = "10924807159",
    ["mellorelic"] = "10924837998",
    ["lifeupfruit"] = "6874854383",
    ["fruitofforgetfulness"] = "11239212617",
    ["chakrafruit"] = "8144391738",
    ["flamegem"] = "6887459132",
    ["icegem"] = "131324952306268",
    ["blackflamegem"] = "10529181353",
    ["spookygem"] = "96100751344684",
    ["aquagem"] = "6887459990",
    ["sparkgem"] = "8144526742",
    ["poisongem"] = "10924875330",
    ["groundgem"] = "6887462240",
    ["windgem"] = "6887463895",
    ["ghostlybracelet"] = "8011520572",
    ["silverbracelet"] = "5965583425",
    ["silvernecklace"] = "5965583248",
    ["silverring"] = "5965583646",
    ["silverenclosedring"] = "5965583809",
    ["goldbracelet"] = "5949023095",
    ["goldnecklace"] = "5949023217",
    ["goldring"] = "5949023388",
    ["goldenclosedring"] = "5965582961",
    ["ringoftheneoncat"] = "78674454561641",
    ["ringoftheneoncat1"] = "78674454561641",
    ["ringoftheneoncat2"] = "78674454561641",
    ["ringoftheneoncat3"] = "78674454561641",
    ["bloodbitering"] = "70505254810210",
    ["bloodbitering1"] = "70505254810210",
    ["bloodbitering2"] = "70505254810210",
    ["bloodbitering3"] = "70505254810210",
    ["ringofbeauty"] = "89537790206685",
    ["ringofbeauty1"] = "89537790206685",
    ["ringofbeauty2"] = "89537790206685",
    ["ringofbeauty3"] = "89537790206685",
    ["ringofnightmares"] = "89830265721261",
    ["ringofnightmares1"] = "89830265721261",
    ["ringofnightmares2"] = "89830265721261",
    ["ringofnightmares3"] = "89830265721261",
    ["ringofnightmares4"] = "89830265721261",
    ["ringoffavor"] = "71408799840824",
    ["ringoffavor1"] = "71408799840824",
    ["ringoffavor2"] = "71408799840824",
    ["ringoffavor3"] = "71408799840824",
    ["ringoffavor4"] = "71408799840824",
    ["ringofinfusion"] = "74283242177678",
    ["ringofinfusion1"] = "74283242177678",
    ["ringofinfusion2"] = "74283242177678",
    ["ringofinfusion3"] = "74283242177678",
    ["ringofinfusion4"] = "74283242177678",
    ["ringofvampirism"] = "73932604319440",
    ["ringofvampirism1"] = "73932604319440",
    ["ringofvampirism2"] = "73932604319440",
    ["ringofvampirism3"] = "73932604319440",
    ["plainring"] = "82782643762305",
    ["masterringofduality"] = "100680659149337",
    ["ringofsubstitution"] = "80848597960128",
    ["ringofsubstitution1"] = "80848597960128",
    ["ringofsubstitution2"] = "80848597960128",
    ["ringofsubstitution3"] = "80848597960128",
    ["ringofremedy"] = "131939080274601",
    ["ringofremedy1"] = "131939080274601",
    ["ringofremedy2"] = "131939080274601",
    ["ringofremedy3"] = "131939080274601",
    ["ringofremedy4"] = "131939080274601",
    ["ringofresistance"] = "99044866580795",
    ["ringofresistance1"] = "99044866580795",
    ["ringofresistance2"] = "99044866580795",
    ["ringofresistance3"] = "99044866580795",
    ["ringofresistance4"] = "99044866580795",
    ["ringofnourishment"] = "126505851620693",
    ["ringofvitality"] = "119079358435575",
    ["ringofvitality1"] = "119079358435575",
    ["ringofvitality2"] = "119079358435575",
    ["ringofvitality3"] = "119079358435575",
    ["ringofvitality4"] = "119079358435575",
    ["ringofahelpinghand"] = "136929385081890",
    ["ringofahelpinghand1"] = "136929385081890",
    ["ringofahelpinghand2"] = "136929385081890",
    ["ringofahelpinghand3"] = "136929385081890",
    ["ringofahelpinghand4"] = "136929385081890",
    ["ringofdexterity"] = "87484631876410",
    ["ringofdexterity1"] = "87484631876410",
    ["ringofdexterity2"] = "87484631876410",
    ["ringofdexterity3"] = "87484631876410",
    ["arkoromosblessing"] = "8528044293",
    ["reanimatedsoul"] = "10420074818",
    ["memorysoul"] = "17602146417",
    ["samuraisoul"] = "95217265686605",
    ["progressionsoul"] = "17602147796",
    ["mashedupcells"] = "11760800933",
    ["seaweed"] = "6887297179",
    ["gloweed"] = "11760742618",
    ["chakracrops"] = "10924817115",
    ["bolivecrops"] = "10924811904",
    ["bolivesoup"] = "9247129810",
    ["chakrasoup"] = "9247128957",
    ["chakrabone"] = "6509579101",
    ["curiousbone"] = "133784908219880",
    ["snowglobe"] = "103617141655048",
    ["chakrashard"] = "6634507203",
    ["chakrashaaard"] = "6634507203",
    ["chakrafragments"] = "6635420276",
    ["cursedfragments"] = "11911532919",
    ["infernalfragments"] = "15187922212",
    ["lovefragments"] = "89024392910061",
    ["innkeepersletter"] = "6843082302",
    ["soakedinnkeepersletter"] = "6843082907",
    ["outkeepersletter"] = "6843082302",
    ["torch"] = "6501408517",
    ["bowl"] = "6104255182",
    ["waterbowl"] = "6104255750",
    ["freshwaterbowl"] = "6656246414",
    ["chakraheart"] = "10924820422",
    ["kamuiessence"] = "10924852383",
    ["redsmithsmold"] = "9952353338",
    ["furhoodie"] = "7174318769",
    ["orangespiralmask"] = "7255568583",
    ["pinkspiralmask"] = "8144490502",
    ["yellowstripedmask"] = "7255569453",
    ["swirlymask"] = "7255567532",
    ["blackswirlymask"] = "8144499578",
    ["facemask"] = "11639175630",
    ["facewraps"] = "11639171868",
    ["redanbumask"] = "11639164687",
    ["festivecracker"] = "102700093995041",
    ["rudolphsnose"] = "109699979477182",
    ["rudolphsantlers"] = "89438424729327",
    ["snowmanhead"] = "128200721410073",
    ["halo"] = "89226311362321",
    ["heartbreakerglasses"] = "109986783617607",
    ["purewings"] = "117703123747723",
    ["bloodredwings"] = "102051104535624",
    ["harvestwings"] = "90764876654911",
    ["nocturnewings"] = "124168774436345",
    ["ghostlypumpkinhead"] = "94403734682059",
    ["toxicpumpkinhead"] = "98264497518351",
    ["voidpumpkinhead"] = "117087526929225",
    ["orangepumpkinhead"] = "11639220678",
    ["purplepumpkinhead"] = "11639225028",
    ["icypumpkinhead"] = "11639227465",
    ["yellowpumpkinhead"] = "11639223065",
    ["whitehood"] = "10585529441",
    ["blackhood"] = "10585523584",
    ["crackedmask"] = "10924826634",
    ["froggysuit"] = "80527498591576",
    ["slugsuit"] = "88212705877645",
    ["mandasuit"] = "76216232218966",
    ["catears"] = "7174313630",
    ["goggles"] = "6970390956",
    ["faceguard"] = "8144494296",
    ["merchanthat"] = "8144676139",
    ["medichelm"] = "8144496823",
    ["blackobi"] = "8144482857",
    ["blackheadband"] = "8144502398",
    ["blackduragband"] = "10585535382",
    ["metallicbow"] = "92687568928640",
    ["chakrabow"] = "139610963880030",
    ["valentinebow"] = "82401888387375",
    ["silverresanagi"] = "6358323507",
    ["goldenresanagi"] = "6358323894",
    ["onyxresanagi"] = "6445487927",
    ["silverkunai"] = "6363071873",
    ["goldenkunai"] = "6363072181",
    ["onyxkunai"] = "6450255956",
    ["silverzabunagi"] = "6992492755",
    ["goldenzabunagi"] = "6992486595",
    ["onyxzabunagi"] = "6992493481",
    ["kusanagi"] = "101511175203645",
    ["spookykusanagi"] = "88510663313749",
    ["hallowedkusanagi"] = "138534012942474",
    ["cursedsword"] = "11915336957",
    ["cursedzabunagi"] = "11915333615",
    ["cursedtrident"] = "11915327642",
    ["adamantinestaff"] = "122229616668974",
    ["spikyadamantinestaff"] = "127383119656728",
    ["raijinkunai"] = "97293628329475",
    ["spookyraijinkunai"] = "98677145874795",
    ["bloodyraijinkunai"] = "98023320145493",
    ["curseddagger"] = "11915330361",
    ["silverhalberd"] = "7277783114",
    ["goldenhalberd"] = "7277783673",
    ["onyxhalberd"] = "7277784313",
    ["silverasumai"] = "8144475545",
    ["goldenasumai"] = "8144478245",
    ["onyxasumai"] = "8144480334",
    ["bagofryo"] = "95859803338262",
    ["acumenstone"] = "91012915272448",
    ["agingserum"] = "113480744516606",
    ["traitscroll"] = "78378114625487",
    ["glowingtraitscroll"] = "86754771661288",
    ["treatbasket"] = "117233569289772",
    ["masteryscroll"] = "121097120944142",
    ["surgicalkit"] = "112540498337369",
    ["bloodlinetoken"] = "108726559085404",
    ["reanimationtoken"] = "108726559085404",
    ["customizationtoken"] = "108726559085404",
    ["sandcloud"] = "135856279379052",
    ["azurefirework"] = "86190376438259",
    ["greenfirework"] = "75863897670260",
    ["pinkfirework"] = "85581659357077",
    ["yellowfirework"] = "93209780707328",
    ["orangejumpsuit"] = "81560450487145",
    ["ascendedorangejumpsuit"] = "81560450487145",
    ["avengersoutfit"] = "70418310568668",
    ["bankslot"] = "74060568797158",
    ["hallowedwings"] = "116175810000323",
    ["pumpkinzetsu"] = "132625004373050",
    ["deathlychains"] = "132212335118055",
    ["phantombugs"] = "102336006202533",
    ["crimsonshark"] = "76363679007243",
    ["hallowedbloodweapons"] = "130302498939530",
    ["hellboundobito"] = "89249904484531",
    ["ghostlyitachi"] = "132578563096908",
    ["infernalsasuke"] = "87233369912627",
    ["blazingmadara"] = "135961632572215",
    ["vampiricsasukesrinnegan"] = "134367048839064",
    ["hallowedbyakugan"] = "113943536062701",
    ["hallowedneji"] = "119411308219028",
    ["vampirichinata"] = "95111318037442",
    ["glowingbones"] = "101202586977638",
    ["festivewings"] = "116575857506721",
    ["frozenchains"] = "75124446020465",
    ["icyzetsu"] = "99116584133655",
    ["festivebugs"] = "131543971123653",
    ["bloodfrostweapons"] = "134720522484856",
    ["frostyobito"] = "94708734692300",
    ["frostysasuke"] = "124216436114827",
    ["frostyitachi"] = "92174749625652",
    ["frostymadara"] = "102148910269925",
    ["beautyandthebugs"] = "106389576911584",
    ["enchantedwings"] = "124625368373864",
    ["enchantedketsuryugan"] = "124088995375192",
    ["attractivepainsrinnegan"] = "116919947179443",
    ["charmingshisui"] = "92062228885588",
    ["substitution"] = "6877034346",
    ["chakratreejump"] = "6877029881",
    ["chakrafeet"] = "6877027681",
    ["chakrapunch"] = "6992498492",
    ["chakradash"] = "6889048431",
    ["chakracharge"] = "6893252534",
    ["chakraressurection"] = "7174291815",
    ["kunaithrow"] = "7277782306",
    ["multikunaithrow"] = "7282103827",
    ["wiredkunai"] = "10924848166",
    ["twinstrike"] = "11639201780",
    ["chargedram"] = "11639188976",
    ["overheadspin"] = "11639199021",
    ["chainpull"] = "11639183423",
    ["chakrainfusedslam"] = "11639186582",
    ["leafwhirlwind"] = "9467861275",
    ["dynamicentry"] = "9467828290",
    ["smolderingearth"] = "6915154832",
    ["earthwall"] = "7174334386",
    ["earthgolem"] = "10524446216",
    ["fireball"] = "6970371932",
    ["phoenixflower"] = "7174298850",
    ["dragonicflames"] = "7174294477",
    ["flamecompany"] = "8204563340",
    ["chidori"] = "7182549279",
    ["revivalhealing"] = "7267050653",
    ["injuryheal"] = "11639160808",
    ["hundredhealings"] = "9480271723",
    ["blossomtouch"] = "126167448442913",
    ["greengates"] = "11269350690",
    ["bluegates"] = "105236325166663",
    ["redgates"] = "75671451116742",
    ["bindingseal"] = "8528043336",
    ["sealingbarrierrod"] = "8722713596",
    ["sealingbanners"] = "8528043840",
    ["healingzone"] = "8144467219",
    ["selfpurification"] = "8144462458",
    ["yinseal"] = "9480247797",
    ["coalescence"] = "10361132081",
    ["chakraexchange"] = "8204672598",
    ["lightningstream"] = "7193886301",
    ["lightningripple"] = "7255566856",
    ["waterpool"] = "7267053588",
    ["sealingfloor"] = "8528032736",
    ["waterfountain"] = "7277779994",
    ["waterdragon"] = "7267054991",
    ["waterwave"] = "8528045395",
    ["windtornado"] = "8144471829",
    ["galepalm"] = "8204674389",
    ["risingwind"] = "6915158186",
    ["aerialheavyattack"] = "6893281680",
    ["triplejump"] = "6877023841",
    ["chipdamage"] = "7177951631",
    ["sharinganstage1"] = "7174326332",
    ["sharinganstage2"] = "7245353709",
    ["sharinganstage3"] = "7245930185",
    ["obitosmangekyo"] = "7286096199",
    ["obitoseternalmangekyo"] = "11266409852",
    ["itachismangekyo"] = "9484712296",
    ["itachiseternalmangekyo"] = "11263859792",
    ["sasukesmangekyo"] = "10800228871",
    ["sasukeseternalmangekyo"] = "15190048032",
    ["madarasmangekyo"] = "108272000086081",
    ["madaraseternalmangekyo"] = "139791763329895",
    ["shisuismangekyo"] = "84921057592517",
    ["shisuiseternalmangekyo"] = "120599021548031",
    ["painsrinnegan"] = "10809160363",
    ["sasukesrinnegan"] = "106514074149219",
    ["ketsuryuganstage1"] = "127702680893576",
    ["ketsuryuganstage2"] = "137018271214942",
    ["ketsuryuganstage3"] = "74500207900585",
    ["cloakoflightning"] = "8789089933",
    ["cloakoflightningstage2"] = "133990498740221",
    ["byakuganstage1"] = "7246195779",
    ["byakuganstage2"] = "7246195779",
    ["byakuganstage3"] = "7246195779",
    ["byakuganstage4"] = "7246195779",
    ["nejisbyakugan"] = "7246195779",
    ["hinatasbyakugan"] = "7246195779",
    ["rasenshuriken"] = "73296706468819",
    ["smallgourd"] = "79687367076244",
    ["gourd"] = "121786409776019",
    ["sandtsunami"] = "83253058004510",
    ["sandsuspension"] = "98494237628015",
    ["quicksand"] = "107297190933279",
    ["sandmasoleum"] = "93679273226400"
    }

    -- ฟังก์ชันค้นหา Asset ID จาก GameManager หรือ ReplicatedStorage
    local function findAssetFor(name)
        if not name or name == "" then return nil end
        if itemAssetMap[name] then return itemAssetMap[name] end
        local cleanTarget = cleanKey(name)
        if itemAssetMap[cleanTarget] then return itemAssetMap[cleanTarget] end
        if KNOWN_BLOODLINES_ASSETS[cleanTarget] then return KNOWN_BLOODLINES_ASSETS[cleanTarget] end

        if GM then
            local ok, id = pcall(function() return GM:getImageId(name) end)
            local num = ok and extractAssetId(id)
            if num then return num end

            pcall(function()
                if GM.getItemData then
                    local parsed = extractAssetId(GM:getItemData(name))
                    if parsed then num = parsed end
                end
            end)
            if num then return num end

            for _, tblKey in ipairs({"Items", "Armors", "Outfits", "Equipment", "Drops", "Weapons", "Souls", "Scrolls", "Clothing", "Cosmetics", "Costumes", "Accessories"}) do
                local tbl = GM[tblKey]
                if typeof(tbl) == "table" then
                    for k, v in pairs(tbl) do
                        if cleanKey(k) == cleanTarget then
                            local found = extractAssetId(v)
                            if found then return found end
                        end
                    end
                end
            end
        end

        -- ค้นหาใน ReplicatedStorage
        local searchFolders = {
            Rep:FindFirstChild("Items"),
            Rep:FindFirstChild("Armors"),
            Rep:FindFirstChild("Outfits"),
            Rep:FindFirstChild("Equipment"),
            Rep:FindFirstChild("ItemData"),
            Rep:FindFirstChild("Drops"),
            Rep:FindFirstChild("Weapons"),
            Rep:FindFirstChild("Clothing"),
            Rep:FindFirstChild("Assets"),
            Rep:FindFirstChild("Wardrobe"),
            Rep:FindFirstChild("Accessories")
        }
        for _, f in ipairs(searchFolders) do
            if f then
                for _, child in ipairs(f:GetChildren()) do
                    if cleanKey(child.Name) == cleanTarget then
                        local found = extractAssetId(child)
                        if found then return found end
                    end
                end
            end
        end

        return nil
    end

    if not _G.ArmonRobloxCdnCache then _G.ArmonRobloxCdnCache = {} end

    -- รวบรวม Asset IDs เพื่อแปลงเป็น URL รูปจริงผ่าน thumbnails.roblox.com
    local pendingAssetIds = {}
    for name, _ in pairs(itemMap) do
        local aId = itemAssetMap[name] or findAssetFor(name)
        if aId then
            itemAssetMap[name] = aId
            if not _G.ArmonRobloxCdnCache[tostring(aId)] then
                table.insert(pendingAssetIds, tostring(aId))
            end
        end
    end

    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if #pendingAssetIds > 0 and requestFunc then
        pcall(function()
            local batch = table.concat(pendingAssetIds, ",")
            local res = requestFunc({
                Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. batch .. "&size=150x150&format=Png&isCircular=false",
                Method = "GET",
                Headers = { ["Accept"] = "application/json" }
            })
            if res and res.Body then
                local decoded = HttpService:JSONDecode(res.Body)
                if decoded and decoded.data then
                    for _, entry in ipairs(decoded.data) do
                        if entry.state == "Completed" and entry.imageUrl and entry.imageUrl ~= "" then
                            _G.ArmonRobloxCdnCache[tostring(entry.targetId)] = entry.imageUrl
                        end
                    end
                end
            end
        end)
    end

    -- แปลงเป็นโครงสร้างที่เว็บต้องการ
    for name, count in pairs(itemMap) do
        local rarity = "RARE"
        local lower = name:lower()
        if lower:find("candy") or lower:find("pumpkin") or lower:find("firework") or lower:find("snow") or lower:find("wings") or lower:find("halo") then
            rarity = "EVENT"
        elseif lower:find("mythic") or lower:find("affinity") or lower:find("token") or lower:find("outfit") or lower:find("fuiiko") then
            rarity = "MYTHIC"
        elseif lower:find("legendary") or lower:find("fruit") or lower:find("soul") or lower:find("schematics") or lower:find("eyes") then
            rarity = "LEGENDARY"
        elseif lower:find("uncommon") or lower:find("bowl") or lower:find("mask") or lower:find("soup") then
            rarity = "UNCOMMON"
        end

        local assetId = itemAssetMap[name] or findAssetFor(name)
        local cdnUrl = (assetId and _G.ArmonRobloxCdnCache[tostring(assetId)]) or nil

        table.insert(items, {
            name = name,
            count = count,
            rarity = rarity,
            assetId = assetId,
            imageUrl = cdnUrl,
            image = cdnUrl,
            icon = cdnUrl or "⚔️",
            glow = rarity == "EVENT" and "fuchsia" or rarity == "MYTHIC" and "red" or rarity == "LEGENDARY" and "amber" or "sky"
        })
    end

    -- แคชรายการไอเทมในตัวแปร Global ป้องกันการสูญหายเมื่อตัวละครตายเกิด สลับแมพ หรือปิดเกม
    if #items > 0 then
        _G.ArmonCachedItems = items
    elseif _G.ArmonCachedItems and #_G.ArmonCachedItems > 0 then
        items = _G.ArmonCachedItems
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

    -- แคชค่าเงิน และสถิติต่างๆ ในตัวแปร Global ป้องกันการส่งค่า 0 เมื่อสลับแมพหรือตอนปิดเกม
    if not _G.ArmonCachedStats then _G.ArmonCachedStats = {} end
    if ryo > 0 then _G.ArmonCachedStats.ryo = ryo elseif _G.ArmonCachedStats.ryo then ryo = _G.ArmonCachedStats.ryo end
    if acumen > 0 then _G.ArmonCachedStats.acumen = acumen elseif _G.ArmonCachedStats.acumen then acumen = _G.ArmonCachedStats.acumen end
    if level > 1 then _G.ArmonCachedStats.level = level elseif _G.ArmonCachedStats.level then level = _G.ArmonCachedStats.level end
    if embers > 0 then _G.ArmonCachedStats.embers = embers elseif _G.ArmonCachedStats.embers then embers = _G.ArmonCachedStats.embers end
    wen = ryo

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

local function sendLiveSync(isOfflineMode)
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

    local isOffline = isOfflineMode == true

    local payload = {
        apiKey = Config.api_key,
        game = Config.game,
        placeId = Config.place_id,
        gameId = Config.game_id,
        pc = Config.pc_name,
        discordId = Config.discord_id,
        uptime = sessionUptime,
        isOffline = isOffline,
        account = {
            username = player.Name,
            displayName = player.DisplayName,
            userId = player.UserId,
            placeId = Config.place_id,
            uptime = sessionUptime,
            statusType = isOffline and "offline" or "online",
            level = pData.level,
            race = pData.race,
            bloodline = pData.bloodline, -- [รวมแล้ว] สายเลือดนินจา (เช่น Zetsu)
            clan = pData.clan,           -- [รวมแล้ว] ชื่อแคลน (ไม่ว่างแน่นอน)
            clanRole = pData.clanRole ~= "" and pData.clanRole or nil,
            village = pData.village ~= "" and pData.village or nil,
            rank = pData.rank ~= "" and pData.rank or nil,
            age = pData.age > 0 and pData.age or nil,
            wen = pData.wen,
            ryo = pData.ryo,
            acumen = pData.acumen,
            embers = pData.embers,
            ember = pData.embers,
            items = backpackItems,       -- รายการไอเทมครบถ้วน 100% แม้กระทั่งตอนสั่งปิดเกม
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

-- ฟังก์ชันแจ้งเตือนออฟไลน์ทันทีเมื่อผู้เล่นปิดเกม หรือออกจากเซิร์ฟเวอร์ (ส่งของครบ ไม่ถูกล้าง)
local function sendOfflineNotice()
    pcall(function()
        sendLiveSync(true)
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
