local Flags = Flags or {
    Farm = 'Self',
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
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = Players.LocalPlayer
local Backpack = Client:FindFirstChildWhichIsA("Backpack")

local HiddenFlags = {
    Connections = {},
    SellAllDebounce = 0
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

    local FarmPos = Farming:GetPivot().Position + vector.create(0, 5, 0)
    local FarmLook = Farming:GetPivot().LookVector

    ReplicatedStorage.Events.Global.Cast:FireServer(
        Humanoid,
        FarmPos,
        FarmLook,
        Rod.Model.Nodes.RodTip.Attachment
    )

    ReplicatedStorage.Events.Global.WithdrawBobber:FireServer(Humanoid)
end

local function ShouldSell(star, protected)
    if protected[star] then
        return false
    end

    local rarityObj = star:FindFirstChild("Rarity")
    local rarity = rarityObj and rarityObj.Value

    if rarity and Flags.KeepRarities and Flags.KeepRarities[rarity] then
        return false
    end

    if Flags.SellBelowRarity and rarity then
        if RarityOrder[rarity] >= RarityOrder[Flags.SellBelowRarity] then
            return false
        end
    end

    return true
end

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

while shared.afy and task.wait() do
    local Character = Client.Character
    local Root = GetRoot(Character)
    if not Root then continue end

    Cast()
    
        print("AutoSell system loaded")
    
    while shared.afy and task.wait() do
        local Character = Client.Character
        local Root = GetRoot(Character)
        if not Root then continue end
    
        Cast()
    
        -- Debounce check
        if not Flags.SellAll then
            print("SellAll disabled")
            continue
        end
    
        if tick() - HiddenFlags.SellAllDebounce < (Flags.SellAllDebounce or 10) then
            continue
        end
    
        print("=== SELL CHECK START ===")
    
        local Inventory = ReplicatedStorage:FindFirstChild("PlayerData")
        if not Inventory then
            print("PlayerData folder NOT found")
            continue
        end
    
        local PlayerFolder = Inventory:FindFirstChild(Client.Name)
        if not PlayerFolder then
            print("Player folder NOT found:", Client.Name)
            continue
        end
    
        local StarsFolder = PlayerFolder:FindFirstChild("Stars")
        if not StarsFolder then
            print("Stars folder NOT found")
            continue
        end
    
        local Stars = StarsFolder:GetChildren()
        print("Total stars found:", #Stars)
    
        if #Stars == 0 then
            print("No stars to sell")
            HiddenFlags.SellAllDebounce = tick()
            continue
        end
    
        -- Sort by Value/Power
        table.sort(Stars, function(a, b)
            local av = (a:FindFirstChild("Value") or a:FindFirstChild("Power"))
            local bv = (b:FindFirstChild("Value") or b:FindFirstChild("Power"))
            return (av and av.Value or 0) > (bv and bv.Value or 0)
        end)
    
        -- Protect best N
        local Protected = {}
        if Flags.KeepBestCount then
            for i = 1, math.min(Flags.KeepBestCount, #Stars) do
                Protected[Stars[i]] = true
                print("Protecting:", Stars[i].Name)
            end
        end
    
        -- Sell loop
        for _, Star in ipairs(Stars) do
            local rarityObj = Star:FindFirstChild("Rarity")
            local rarity = rarityObj and rarityObj.Value or "Unknown"
    
            local blockedReason = nil
    
            if Protected[Star] then
                blockedReason = "Protected (Top Best)"
            elseif Flags.KeepRarities and Flags.KeepRarities[rarity] then
                blockedReason = "Blocked by KeepRarities"
            elseif Flags.SellBelowRarity and rarity and RarityOrder[rarity] then
                if RarityOrder[rarity] >= RarityOrder[Flags.SellBelowRarity] then
                    blockedReason = "Above SellBelowRarity"
                end
            end
    
            if blockedReason then
                print("KEEPING:", Star.Name, "| Rarity:", rarity, "| Reason:", blockedReason)
            else
                print("SELLING:", Star.Name, "| Rarity:", rarity)
                ReplicatedStorage.Events.Global.SellStar:FireServer(Star.Name)
                task.wait(0.05)
            end
        end

        print("=== SELL CHECK END ===")
        HiddenFlags.SellAllDebounce = tick()
    end
end

for _, Connection in ipairs(HiddenFlags.Connections) do
    Connection:Disconnect()
end
