local UserInputService = game:GetService("UserInputService")

local Flags = {
    Farm = 'Self', -- Self, Milky Way, Andromeda, Centaurus A, Hoag's Object, Negative Galaxy, The Eye
    SellAll = true,
    SellAllDebounce = 10,
    AutoEquipRod = true,

    -- Auto-lock settings
    AutoLock = true,              -- Toggle auto-lock on/off
    LockRarityThreshold = "Legendary", -- Rarity or higher will be auto-locked
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Client = Players.LocalPlayer
local Backpack = Client:FindFirstChildWhichIsA("Backpack")

local HiddenFlags = { Connections = {}, SellAllDebounce = 0 }

shared.afy = not shared.afy
print("[afy]", shared.afy)

local RarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Divine = 7 }

local function GetRoot(Character) return Character and Character:FindFirstChild("HumanoidRootPart") end
local function GetHumanoid(Character) return Character and Character:FindFirstChild("Humanoid") end

-- Auto-cast function
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
    local FarmPos = Farming:GetPivot().Position + Vector3.new(0, 5, 0)
    local FarmLook = Farming:GetPivot().LookVector

    ReplicatedStorage.Events.Global.Cast:FireServer(Humanoid, FarmPos, FarmLook, Rod.Model.Nodes.RodTip.Attachment)
    ReplicatedStorage.Events.Global.WithdrawBobber:FireServer(Humanoid)
end

-- Auto-confirm received stars
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

-- Auto-lock function
local function AutoLockStars()
    if not Flags.AutoLock then return end

    local Inventory = ReplicatedStorage:FindFirstChild("PlayerData")
    if not Inventory or not Inventory:FindFirstChild(Client.Name) then return end
    local StarsFolder = Inventory[Client.Name]:FindFirstChild("Stars")
    if not StarsFolder then return end

    for _, Star in ipairs(StarsFolder:GetChildren()) do
        local rarityObj = Star:FindFirstChild("Rarity")
        local rarity = rarityObj and rarityObj.Value
        if rarity and RarityOrder[rarity] >= RarityOrder[Flags.LockRarityThreshold] then
            -- Lock the star
            ReplicatedStorage.Events.Global.LockStar:FireServer(Star.Name, true)
        end
    end
end

-- Keybind toggle: press L to turn AutoLock on/off
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.L then
        Flags.AutoLock = not Flags.AutoLock
        print("[AutoLock] Toggled:", Flags.AutoLock)
    end
end)

-- Main loop
while shared.afy and task.wait(1) do
    local Character = Client.Character
    if not GetRoot(Character) then continue end

    Cast()
    AutoLockStars()

    -- Sell all (respects locked stars)
    if Flags.SellAll and tick() - HiddenFlags.SellAllDebounce >= (Flags.SellAllDebounce or 10) then
        local DialogueEvent = ReplicatedStorage:FindFirstChild("Dialogue") 
            and ReplicatedStorage.Dialogue.Events.Global.ClientChoosesDialogueOption
        if DialogueEvent then
            DialogueEvent:FireServer({
                id = "sell-all",
                text = "Sell <font color='#26ff47'>all</font> of my stars.",
                npc = "Star Merchant"
            })
            HiddenFlags.SellAllDebounce = tick()
        end
    end
end

-- Cleanup connections
for _, Connection in ipairs(HiddenFlags.Connections) do
    Connection:Disconnect()
end
