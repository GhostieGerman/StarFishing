-- === FLAGS ===
local Flags = Flags or {
    Farm = 'Self',                 -- Self or galaxy name
    SellAll = true,                
    SellAllDebounce = 10,
    AutoEquipRod = true,
    KeepRarities = {
        ["Legendary"] = true,
        ["Mythic"] = true,
        ["Divine"] = true,
    },
    SellBelowRarity = "Legendary",
    KeepBestCount = 5,

    AutoLock = true,               -- Toggle auto-lock
    LockRarity = "Legendary",      -- Lock this rarity or higher
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Client = Players.LocalPlayer
local Backpack = Client:FindFirstChildWhichIsA("Backpack")

local HiddenFlags = {
    Connections = {},
    SellAllDebounce = 0,
    AutoLockDebounce = 0
}

shared.afy = not shared.afy
print("[afy]", shared.afy)

-- Rarity order
local RarityOrder = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythic = 6,
    Divine = 7
}

-- === UTILITIES ===
local function GetRoot(Character) return Character and Character:FindFirstChild("HumanoidRootPart") end
local function GetHumanoid(Character) return Character and Character:FindFirstChild("Humanoid") end

-- === CAST FISH ===
local function Cast()
    local Character = Client.Character
    local Humanoid = GetHumanoid(Character)
    local Root = GetRoot(Character)
    if not Root then return end

    local Rod = Character:FindFirstChild("Rod")
    if not Rod then
        Rod = Backpack and Backpack:FindFirstChild("Rod")
        if not Rod or not Flags.AutoEquipRod then return end
        Rod.Parent = Character
    end

    local Farming = Flags.Farm == "Self" and Root or workspace.Galaxies:FindFirstChild(Flags.Farm) or Root
    local FarmPos = Farming:GetPivot().Position + vector.create(0, 5, 0)
    local FarmLook = Farming:GetPivot().LookVector

    ReplicatedStorage.Events.Global.Cast:FireServer(Humanoid, FarmPos, FarmLook, Rod.Model.Nodes.RodTip.Attachment)
    ReplicatedStorage.Events.Global.WithdrawBobber:FireServer(Humanoid)
end

-- === SHOULD SELL STAR ===
local function ShouldSell(star, protected)
    if protected[star] then return false end

    local rarityObj = star:FindFirstChild("Rarity")
    local rarity = rarityObj and rarityObj.Value

    if rarity and Flags.KeepRarities and Flags.KeepRarities[rarity] then return false end
    if Flags.SellBelowRarity and rarity then
        if RarityOrder[rarity] >= RarityOrder[Flags.SellBelowRarity] then return false end
    end

    return true
end

-- === AUTO-LOCK SETUP ===
local LockEvent
for _, v in pairs(ReplicatedStorage:GetDescendants()) do
    if v:IsA("RemoteEvent") and v.Name:lower():find("lock") then
        LockEvent = v
        print("[DEBUG] Lock event found:", v:GetFullName())
        break
    end
end
if not LockEvent then warn("[DEBUG] LockStar RemoteEvent not found!") end

local function AutoLockStars()
    if not LockEvent then return end
    if tick() - HiddenFlags.AutoLockDebounce < 1 then return end

    local Inventory = ReplicatedStorage:FindFirstChild("PlayerData")
    if not Inventory or not Inventory:FindFirstChild(Client.Name) then return end
    local StarsFolder = Inventory[Client.Name]:FindFirstChild("Stars")
    if not StarsFolder then return end

    for _, Star in ipairs(StarsFolder:GetChildren()) do
        local rarityObj = Star:FindFirstChild("Rarity")
        if rarityObj and RarityOrder[rarityObj.Value] >= RarityOrder[Flags.LockRarity] then
            LockEvent:FireServer({ Star = Star.Name, Lock = true })
            print("[DEBUG] Locked star:", Star.Name)
        end
    end

    HiddenFlags.AutoLockDebounce = tick()
end

-- === CLIENT RECEIVE ITEMS ===
local ClientRecieveItems = ReplicatedStorage.Events.Global.ClientRecieveItems
table.insert(HiddenFlags.Connections,
    ClientRecieveItems.OnClientEvent:Connect(function(...)
        local Data = {...}
        local Info = Data[4] or {}
        local TimingTbl = Data[6] or {}

        for Index, StarData in Info do
            local Id = StarData["id"]
            if Id then
                task.wait(TimingTbl[Index] or 3)
                ReplicatedStorage.Events.Global.ClientItemConfirm:FireServer(Id)
            end
        end
    end)
)

-- === MAIN LOOP ===
while shared.afy and task.wait(1) do
    local Character = Client.Character
    local Root = GetRoot(Character)
    if not Root then continue end

    Cast()

    -- Auto-sell
    if Flags.SellAll and tick() - HiddenFlags.SellAllDebounce >= (Flags.SellAllDebounce or 10) then
        local Inventory = ReplicatedStorage:FindFirstChild("PlayerData")
        if Inventory and Inventory:FindFirstChild(Client.Name) then
            local StarsFolder = Inventory[Client.Name]:FindFirstChild("Stars")
            if StarsFolder then
                local Stars = StarsFolder:GetChildren()

                table.sort(Stars, function(a, b)
                    local av = (a:FindFirstChild("Value") or a:FindFirstChild("Power"))
                    local bv = (b:FindFirstChild("Value") or b:FindFirstChild("Power"))
                    return (av and av.Value or 0) > (bv and bv.Value or 0)
                end)

                local Protected = {}
                if Flags.KeepBestCount then
                    for i = 1, math.min(Flags.KeepBestCount, #Stars) do
                        Protected[Stars[i]] = true
                    end
                end

                for _, Star in ipairs(Stars) do
                    if ShouldSell(Star, Protected) then
                        ReplicatedStorage.Events.Global.SellStar:FireServer(Star.Name)
                        task.wait(0.05)
                    end
                end
            end
        end
        HiddenFlags.SellAllDebounce = tick()
    end

    -- Auto-lock
    if Flags.AutoLock then
        AutoLockStars()
    end
end

-- === CLEANUP ===
for _, Connection in ipairs(HiddenFlags.Connections) do
    Connection:Disconnect()
end
