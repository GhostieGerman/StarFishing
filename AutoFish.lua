local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = Players.LocalPlayer
local Backpack = Client:FindFirstChildWhichIsA("Backpack")

local Flags = {
    Farm = "Self",
    SellAll = true,
    SellAllDebounce = 10,
    AutoEquipRod = true,

    AutoLock = true,
    LockRarityThreshold = "Legendary",
}

local HiddenFlags = { SellAllDebounce = 0 }

shared.afy = not shared.afy
print("[AutoFish Running]:", shared.afy)

local RarityOrder = {
    Common = 1, Uncommon = 2, Rare = 3, Epic = 4,
    Legendary = 5, Mythic = 6, Divine = 7
}

local function GetRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(char)
    return char and char:FindFirstChild("Humanoid")
end

--------------------------------------------------
-- 🔎 FIND PLAYERDATA (AUTO)
--------------------------------------------------
local function FindPlayerData()
    local pd = ReplicatedStorage:FindFirstChild("PlayerData")
    if pd and pd:FindFirstChild(Client.Name) then
        return pd[Client.Name]
    end

    pd = Client:FindFirstChild("PlayerData")
    if pd then return pd end

    warn("[DEBUG] PlayerData NOT FOUND")
    return nil
end

--------------------------------------------------
-- 🎣 AUTO CAST
--------------------------------------------------
local function Cast()
    local char = Client.Character
    local root = GetRoot(char)
    local hum = GetHumanoid(char)
    if not root then return end

    local rod = char:FindFirstChild("Rod") or (Backpack and Backpack:FindFirstChild("Rod"))
    if not rod or not Flags.AutoEquipRod then return end
    rod.Parent = char

    local farmObj = Flags.Farm == "Self" and root or workspace.Galaxies:FindFirstChild(Flags.Farm) or root
    local pos = farmObj:GetPivot().Position + Vector3.new(0,5,0)
    local look = farmObj:GetPivot().LookVector

    ReplicatedStorage.Events.Global.Cast:FireServer(hum, pos, look, rod.Model.Nodes.RodTip.Attachment)
    ReplicatedStorage.Events.Global.WithdrawBobber:FireServer(hum)
end

--------------------------------------------------
-- 🔒 AUTO LOCK DEBUG
--------------------------------------------------
local function AutoLockStars()
    if not Flags.AutoLock then return end

    local playerData = FindPlayerData()
    if not playerData then return end

    local starsFolder = playerData:FindFirstChild("Stars")
    if not starsFolder then
        warn("[DEBUG] Stars folder NOT FOUND")
        return
    end

    local lockEvent = ReplicatedStorage:FindFirstChild("Events")
        and ReplicatedStorage.Events.Global:FindFirstChild("LockStar")

    if not lockEvent then
        warn("[DEBUG] LockStar EVENT NOT FOUND")
        return
    end

    for _, star in ipairs(starsFolder:GetChildren()) do
        local rarityObj = star:FindFirstChild("Rarity")
        local rarity = rarityObj and rarityObj.Value

        if rarity and RarityOrder[rarity] >= RarityOrder[Flags.LockRarityThreshold] then
            print("[LOCKING]", star.Name, rarity)
            lockEvent:FireServer(star.Name, true)
        end
    end
end

--------------------------------------------------
-- 💰 AUTO SELL DEBUG
--------------------------------------------------
local function AutoSell()
    if not Flags.SellAll then return end
    if tick() - HiddenFlags.SellAllDebounce < Flags.SellAllDebounce then return end

    local dialogue = ReplicatedStorage:FindFirstChild("Dialogue")
    local sellEvent = dialogue
        and dialogue:FindFirstChild("Events")
        and dialogue.Events.Global:FindFirstChild("ClientChoosesDialogueOption")

    if not sellEvent then
        warn("[DEBUG] Sell Dialogue EVENT NOT FOUND")
        return
    end

    print("[SELLING ALL]")
    sellEvent:FireServer({
        id = "sell-all",
        text = "Sell <font color='#26ff47'>all</font> of my stars.",
        npc = "Star Merchant"
    })

    HiddenFlags.SellAllDebounce = tick()
end

--------------------------------------------------
-- ⌨️ TOGGLES
--------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    if input.KeyCode == Enum.KeyCode.L then
        Flags.AutoLock = not Flags.AutoLock
        print("[AutoLock]:", Flags.AutoLock)
    end

    if input.KeyCode == Enum.KeyCode.K then
        Flags.SellAll = not Flags.SellAll
        print("[AutoSell]:", Flags.SellAll)
    end
end)

--------------------------------------------------
-- 🔁 MAIN LOOP
--------------------------------------------------
while shared.afy and task.wait(1) do
    local char = Client.Character
    if not GetRoot(char) then continue end

    Cast()
    AutoLockStars()
    AutoSell()
end
