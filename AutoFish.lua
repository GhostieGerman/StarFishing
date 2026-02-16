-- Auto Fish with Auto-Lock & Auto-Sell
local Flags = Flags or {
    Farm = "Self", -- Self, Milky Way, Andromeda, Centaurus A, Hoag's Object, Negative Galaxy, The Eye
    AutoEquipRod = true,

    -- Toggle features
    AutoSell = true,
    AutoLock = true,

    SellAllDebounce = 10,    -- seconds between sell attempts
    LockRarity = "Legendary", -- locks stars of this rarity or higher
    KeepBestCount = 5,        -- number of top stars to protect
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Client = Players.LocalPlayer
local Backpack = Client:FindFirstChildWhichIsA("Backpack")

local HiddenFlags = {
    Connections = {},
    LastSell = 0,
}

shared.afy = not shared.afy
print("[afy]", shared.afy)

local RarityOrder = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythic = 6,
    Divine = 7
}

local function GetRoot(Character)
    return Character and Character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(Character)
    return Character and Character:FindFirstChild("Humanoid")
end

-- Cast function remains the same
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

    local Farming =
        Flags.Farm == "Self"
        and Root
        or workspace.Galaxies:FindFirstChild(Flags.Farm)
        or Root

    local FarmPos = Farming:GetPivot().Position + Vector3.new(0, 5, 0)
    local FarmLook = Farming:GetPivot().LookVector

    ReplicatedStorage.Events.Global.Cast:FireServer(
        Humanoid,
        FarmPos,
        FarmLook,
        Rod.Model.Nodes.RodTip.Attachment
    )

    ReplicatedStorage.Events.Global.WithdrawBobber:FireServer(Humanoid)
end

-- Listen for items and confirm
local ClientRecieveItems = ReplicatedStorage.Events.Global.ClientRecieveItems
table.insert(HiddenFlags.Connections, ClientRecieveItems.OnClientEvent:Connect(function(...)
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
end))

-- AutoFish loop
while shared.afy and task.wait() do
    local Character = Client.Character
    local Root = GetRoot(Character)
    if not Root then continue end

    Cast()

    local Inventory = ReplicatedStorage:FindFirstChild("PlayerData")
    local StarsFolder
    if Inventory and Inventory:FindFirstChild(Client.Name) then
        StarsFolder = Inventory[Client.Name]:FindFirstChild("Stars")
    end

    if StarsFolder then
        local Stars = StarsFolder:GetChildren()

        -- Sort stars by Value/Power
        table.sort(Stars, function(a, b)
            local av = (a:FindFirstChild("Value") or a:FindFirstChild("Power"))
            local bv = (b:FindFirstChild("Value") or b:FindFirstChild("Power"))
            return (av and av.Value or 0) > (bv and bv.Value or 0)
        end)

        -- Protect top N best stars
        local Protected = {}
        if Flags.KeepBestCount then
            for i = 1, math.min(Flags.KeepBestCount, #Stars) do
                Protected[Stars[i]] = true
            end
        end

        -- Auto-Lock stars
        if Flags.AutoLock then
            for _, Star in ipairs(Stars) do
                local rarityObj = Star:FindFirstChild("Rarity")
                local rarity = rarityObj and rarityObj.Value
                if rarity and RarityOrder[rarity] >= RarityOrder[Flags.LockRarity] then
                    -- Lock the star using the server event (example, adjust if game differs)
                    local LockEvent = ReplicatedStorage.Events.Global.LockStar
                    if LockEvent then
                        LockEvent:FireServer({ Star = Star.Name, Lock = true })
                        print("Auto-Locking:", Star.Name, "(", rarity, ")")
                    end
                end
            end
        end

        -- Auto-Sell
        if Flags.AutoSell and tick() - HiddenFlags.LastSell >= (Flags.SellAllDebounce or 10) then
            local SellEvent = ReplicatedStorage.Dialogue.Events.Global.ClientChoosesDialogueOption
            if SellEvent then
                SellEvent:FireServer({
                    id = "sell-all",
                    text = "Sell <font color='#26ff47'>all</font> of my stars.",
                    npc = "Star Merchant"
                })
                HiddenFlags.LastSell = tick()
                print("Auto-Sell triggered")
            end
        end
    end
end

-- Clean up connections on exit
for _, Connection in ipairs(HiddenFlags.Connections) do
    Connection:Disconnect()
end
