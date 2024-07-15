local KillEntireProcess = true

local TARGET_LIMB = "Torso"

local LIMB_SIZE = 20
local LIMB_TRANSPARENCY = 0.5
local LIMB_CAN_COLLIDE = false
local LIMB_MASSLESS = true

local USE_HIGHLIGHT = true
local DEPTH_MODE = Enum.HighlightDepthMode.Occluded
local HIGHLIGHT_FILL_COLOR = Color3.fromRGB(255, 0, 0)
local HIGHLIGHT_FILL_TRANSPARENCY = 0.5
local HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local HIGHLIGHT_OUTLINE_TRANSPARENCY = 0

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

_G.PlayerConnections = _G.PlayerConnections or {}
_G.PlayerAdded = _G.PlayerAdded or nil

local function isPlayerAlive(character)
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        local LIMB = character:FindFirstChild(TARGET_LIMB)
        return LIMB and humanoid and humanoid.Health > 0
    end
    return false
end

local function modifyLimb(character)
    local LIMB = character:WaitForChild(TARGET_LIMB)
    LIMB.Transparency = LIMB_TRANSPARENCY
    LIMB.CanCollide = LIMB_CAN_COLLIDE
    LIMB.Massless = LIMB_MASSLESS
    LIMB.Size = Vector3.new(LIMB_SIZE, LIMB_SIZE, LIMB_SIZE)

    if USE_HIGHLIGHT then
        local highlight = LIMB:FindFirstChild("LimbExtenderHighlight")
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "LimbExtenderHighlight"
            highlight.Parent = LIMB
        end
        highlight.Enabled = true
        highlight.DepthMode = DEPTH_MODE
        highlight.Adornee = LIMB
        highlight.FillColor = HIGHLIGHT_FILL_COLOR
        highlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
        highlight.OutlineColor = HIGHLIGHT_OUTLINE_COLOR
        highlight.OutlineTransparency = HIGHLIGHT_OUTLINE_TRANSPARENCY
    else
        local highlight = LIMB:FindFirstChild("LimbExtenderHighlight")
        if highlight then
            highlight.Enabled = false
        end
    end
end

local function handleCharacter(character)
    if LocalPlayer.Team == nil or Players:GetPlayerFromCharacter(character).Team ~= LocalPlayer.Team then
        coroutine.wrap(function()
            while not isPlayerAlive(character) do
                task.wait()
            end
            modifyLimb(character)
            character.Humanoid.Died:Once(function()
                character:Destroy()
            end)
        end)()
    end
end

local function onCharacterAdded(player)
    if _G.PlayerConnections[player] then
        _G.PlayerConnections[player]:Disconnect()
    end
    _G.PlayerConnections[player] = player.CharacterAdded:Connect(handleCharacter)
end

local function onPlayerAdded(player)
    onCharacterAdded(player)
    if player.Character then
        handleCharacter(player.Character)
    end
end

local function onPlayerRemoving(player)
    if _G.PlayerConnections[player] then
        _G.PlayerConnections[player]:Disconnect()
        _G.PlayerConnections[player] = nil
    end
end

local killProcessEvent = LocalPlayer:FindFirstChild("KillProcess") or Instance.new("BindableEvent")
killProcessEvent.Name = "KillProcess"
killProcessEvent.Parent = LocalPlayer


local function handleKillEntireProcess(value)
    if value == true then
        if _G.PlayerAdded then
            _G.PlayerAdded:Disconnect()
        end
        for player, connection in pairs(_G.PlayerConnections) do
            if connection then
                connection:Disconnect()
                _G.PlayerConnections[player] = nil
            end
        end
        script:Destroy()
    end
end

killProcessEvent.Event:Connect(handleKillEntireProcess)

if KillEntireProcess then
    killProcessEvent:Fire(true)
end

for player, connection in pairs(_G.PlayerConnections) do
    if connection then
        connection:Disconnect()
        _G.PlayerConnections[player] = nil
    end
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        onPlayerAdded(player)
    end
end

if _G.PlayerAdded then
    _G.PlayerAdded:Disconnect()
end

_G.PlayerAdded = Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
