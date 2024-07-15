local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Constants for limb modification
local TARGET_LIMB = "Head"
local LIMB_SIZE = 20
local LIMB_TRANSPARENCY = 0.5
local LIMB_CAN_COLLIDE = false
local LIMB_MASSLESS = true

-- Highlight constants
local USE_HIGHLIGHT = true
local DEPTH_MODE = Enum.HighlightDepthMode.Occluded
local HIGHLIGHT_FILL_COLOR = Color3.fromRGB(255, 0, 0)
local HIGHLIGHT_FILL_TRANSPARENCY = 0.5
local HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local HIGHLIGHT_OUTLINE_TRANSPARENCY = 0

-- Global storage for connections and process state
_G.PlayerConnections = _G.PlayerConnections or {}
_G.PlayerAddedConnection = nil
_G.PlayerRemovingConnection = nil
_G.ProcessEnabled = _G.ProcessEnabled ~= nil and _G.ProcessEnabled or true
_G.OriginalProperties = _G.OriginalProperties or {}

-- Function to check if a player's character is alive
local function isPlayerAlive(character)
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local limb = character:FindFirstChild(TARGET_LIMB)
        return humanoid and limb and humanoid.Health > 0
    end
    return false
end

-- Store original limb properties for restoration
local function storeOriginalProperties(limb)
    _G.OriginalProperties[limb] = {
        Size = limb.Size,
        Transparency = limb.Transparency,
        CanCollide = limb.CanCollide,
        Massless = limb.Massless
    }
end

-- Restore original limb properties
local function restoreOriginalProperties(limb)
    local properties = _G.OriginalProperties[limb]
    if properties then
        limb.Size = properties.Size
        limb.Transparency = properties.Transparency
        limb.CanCollide = properties.CanCollide
        limb.Massless = properties.Massless
    end
    local highlight = limb:FindFirstChild("LimbExtenderHighlight")
    if highlight then
        highlight:Destroy()
    end
end

-- Modify the limb properties
local function modifyLimb(character)
    local limb = character:WaitForChild(TARGET_LIMB)
    storeOriginalProperties(limb)
    
    limb.Transparency = LIMB_TRANSPARENCY
    limb.CanCollide = LIMB_CAN_COLLIDE
    limb.Massless = LIMB_MASSLESS
    limb.Size = Vector3.new(LIMB_SIZE, LIMB_SIZE, LIMB_SIZE)

    if USE_HIGHLIGHT then
        local highlight = limb:FindFirstChild("LimbExtenderHighlight") or Instance.new("Highlight")
        highlight.Name = "LimbExtenderHighlight"
        highlight.Enabled = true
        highlight.DepthMode = DEPTH_MODE
        highlight.Adornee = limb
        highlight.FillColor = HIGHLIGHT_FILL_COLOR
        highlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
        highlight.OutlineColor = HIGHLIGHT_OUTLINE_COLOR
        highlight.OutlineTransparency = HIGHLIGHT_OUTLINE_TRANSPARENCY
        highlight.Parent = limb
    end
end

-- Handle character added event
local function onCharacterAdded(player)
    if _G.PlayerConnections[player] then
        _G.PlayerConnections[player]:Disconnect()
    end
    _G.PlayerConnections[player] = player.CharacterAdded:Connect(function(character)
        if LocalPlayer.Team == nil or Players:GetPlayerFromCharacter(character).Team ~= LocalPlayer.Team then
            coroutine.wrap(function()
                while not isPlayerAlive(character) do
                    wait()
                end
                modifyLimb(character)
                character.Humanoid.Died:Wait()
                character:Destroy()
            end)()
        end
    end)
end

-- Handle player added event
local function onPlayerAdded(player)
    onCharacterAdded(player)
    if player.Character then
        handleCharacter(player.Character)
    end
end

-- Handle player removing event
local function onPlayerRemoving(player)
    if _G.PlayerConnections[player] then
        _G.PlayerConnections[player]:Disconnect()
        _G.PlayerConnections[player] = nil
    end
end

-- Enable the limb modification process
local function enableProcess()
    -- Disconnect existing connections
    if _G.PlayerAddedConnection then
        _G.PlayerAddedConnection:Disconnect()
    end
    if _G.PlayerRemovingConnection then
        _G.PlayerRemovingConnection:Disconnect()
    end

    -- Disconnect all player connections
    for player, connection in pairs(_G.PlayerConnections) do
        if connection then
            connection:Disconnect()
            _G.PlayerConnections[player] = nil
        end
    end

    -- Connect to PlayerAdded and PlayerRemoving events
    _G.PlayerAddedConnection = Players.PlayerAdded:Connect(onPlayerAdded)
    _G.PlayerRemovingConnection = Players.PlayerRemoving:Connect(onPlayerRemoving)

    -- Set process state
    _G.ProcessEnabled = true
end

-- Disable the limb modification process
local function disableProcess()
    -- Disconnect PlayerAdded and PlayerRemoving connections
    if _G.PlayerAddedConnection then
        _G.PlayerAddedConnection:Disconnect()
        _G.PlayerAddedConnection = nil
    end
    if _G.PlayerRemovingConnection then
        _G.PlayerRemovingConnection:Disconnect()
        _G.PlayerRemovingConnection = nil
    end

    -- Disconnect all player connections
    for player, connection in pairs(_G.PlayerConnections) do
        if connection then
            connection:Disconnect()
            _G.PlayerConnections[player] = nil
        end
    end

    -- Restore original limb properties for all players
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character then
            local limb = character:FindFirstChild(TARGET_LIMB)
            if limb then
                restoreOriginalProperties(limb)
            end
        end
    end

    -- Set process state
    _G.ProcessEnabled = false
end

-- Toggle the limb modification process
local function toggleProcess()
    if _G.ProcessEnabled then
        disableProcess()
    else
        enableProcess()
    end
end

-- Handle key press event for toggling the process
local function onKeyPress(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == Enum.KeyCode.K then
        toggleProcess()
    end
end

-- Connect to the InputBegan event for key presses
UserInputService.InputBegan:Connect(onKeyPress)

-- Initialize the process state based on _G.ProcessEnabled
if _G.ProcessEnabled then
    enableProcess()
else
    disableProcess()
end
