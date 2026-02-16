-- Auto Fish with debug
local Flags = Flags or {
    Farm = 'Self', -- Self, Milky Way, Andromeda, etc.
    SellAll = true,
    SellAllDebounce = 10,
    AutoEquipRod = true,

    -- Rarity protection
    KeepRarities = {
        ["Legendary"] = true,
        ["Mythic"] = true,
        ["Divine"] = true,
    },
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

local function GetRoot(Character) return Character and Character:FindFirstChild("HumanoidRootPart") end
local function GetHumanoid(Character) return Character and Character:FindFirstChild("Humanoid") end

-- Cast function
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
    local FarmPos = Farming:GetPivot().Position + Vector3.new(0,5,0)
    local FarmLook = Farming:GetPivot().LookVector

    ReplicatedStorage.Events.Global.Cast:FireServer(Humanoid, FarmPos, FarmLook, Rod.Model.Nodes.RodTip.Attachment)
    ReplicatedStorage.Events.Global.WithdrawBobber:FireServer(Humanoid)
end

-- Debug wrapper for selling
local function DebugSell()
    print("=== SELL CHECK START ===")
    local success, err = pcall(function()
        local ClientChoosesDialogueOption = ReplicatedStorage.Dialogue.Events.Global.ClientChoosesDialogueOption
        ClientChoosesDialogueOption:FireServer({
            id = "sell-all",
            text = "Sell <font color='#26ff47'>all</font> of my stars.",
            npc = "Star Merchant"
        })
    end)
    if success then
        print("Sell event fired successfully!")
    else
        print("Sell failed:", err)
    end
end

-- Hook client receive items (auto confirm)
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

-- Main loop
while shared.afy and task.wait() do
    local Character = Client.Character
    local Root = GetRoot(Character)
    if not Root then continue end

    Cast()

    if Flags.SellAll and tick() - HiddenFlags.SellAllDebounce >= (Flags.SellAllDebounce or 10) then
        DebugSell()
        HiddenFlags.SellAllDebounce = tick()
    end
end

-- Disconnect
for _, Connection in ipairs(HiddenFlags.Connections) do
    Connection:Disconnect()
end
