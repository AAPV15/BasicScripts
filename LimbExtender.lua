local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

_G.PlayerConnections = _G.PlayerConnections or {}
_G.PlayerAdded = _G.PlayerAdded or nil
_G.PlayerRemoving = _G.PlayerRemoving or nil
_G.OriginalProperties = _G.OriginalProperties or {}
_G.ProcessEnabled = _G.ProcessEnabled ~= nil and _G.ProcessEnabled or true

local function isPlayerAlive(character)
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        local LIMB = character:FindFirstChild(TARGET_LIMB)
        return LIMB and humanoid and humanoid.Health > 0
    end
    return false
end

local function storeOriginalProperties(LIMB)
    _G.OriginalProperties[LIMB] = {
        Size = LIMB.Size,
        Transparency = LIMB.Transparency,
        CanCollide = LIMB.CanCollide,
        Massless = LIMB.Massless
    }
end

local function restoreOriginalProperties(LIMB)
    local properties = _G.OriginalProperties[LIMB]
    if properties then
        LIMB.Size = properties.Size
        LIMB.Transparency = properties.Transparency
        LIMB.CanCollide = properties.CanCollide
        LIMB.Massless = properties.Massless
    end
    local highlight = LIMB:FindFirstChild("LimbExtenderHighlight")
    if highlight then
        highlight:Destroy()
    end
end

local function modifyLimb(character)
    local LIMB = character:WaitForChild(TARGET_LIMB)
    storeOriginalProperties(LIMB)
    
    LIMB.Transparency = LIMB_TRANSPARENCY
    LIMB.CanCollide = LIMB_CAN_COLLIDE
    LIMB.Massless = LIMB_MASSLESS
    LIMB.Size = Vector3.new(LIMB_SIZE, LIMB_SIZE, LIMB_SIZE)

    if USE_HIGHLIGHT then
        local highlight = LIMB:FindFirstChild("LimbExtenderHighlight") or Instance.new("Highlight", LIMB)
        highlight.Name = "LimbExtenderHighlight"
        highlight.Enabled = true
        highlight.DepthMode = DEPTH_MODE
        highlight.Adornee = LIMB
        highlight.FillColor = HIGHLIGHT_FILL_COLOR
        highlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
        highlight.OutlineColor = HIGHLIGHT_OUTLINE_COLOR
        highlight.OutlineTransparency = HIGHLIGHT_OUTLINE_TRANSPARENCY
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

local function enableProcess()
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

    if _G.PlayerRemoving then
        _G.PlayerRemoving:Disconnect()
    end

    _G.PlayerAdded = Players.PlayerAdded:Connect(onPlayerAdded)
    _G.PlayerRemoving = Players.PlayerRemoving:Connect(onPlayerRemoving)
    _G.ProcessEnabled = true
end

local function disableProcess()
    if _G.PlayerAdded then
        _G.PlayerAdded:Disconnect()
    end

    if _G.PlayerRemoving then
        _G.PlayerRemoving:Disconnect()
    end

    for player, connection in pairs(_G.PlayerConnections) do
        if connection then
            connection:Disconnect()
            _G.PlayerConnections[player] = nil
        end
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            local LIMB = player.Character:FindFirstChild(TARGET_LIMB)
            if LIMB then
                restoreOriginalProperties(LIMB)
            end
        end
    end
    _G.ProcessEnabled = false
end

local function toggleProcess()
    if _G.ProcessEnabled then
        disableProcess()
    else
        enableProcess()
    end
end

local function onKeyPress(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == TOGGLE_KEYCODE then
        toggleProcess()
    end
end

if _G.PlayerAdded then
    _G.PlayerAdded:Disconnect()
end

if _G.PlayerRemoving then
    _G.PlayerRemoving:Disconnect()
end

for player, connection in pairs(_G.PlayerConnections) do
    if connection then
        connection:Disconnect()
        _G.PlayerConnections[player] = nil
    end
end

UserInputService.InputBegan:Disconnect(onKeyPress)
UserInputService.InputBegan:Connect(onKeyPress)

if _G.ProcessEnabled then
    enableProcess()
else
    disableProcess()
end
