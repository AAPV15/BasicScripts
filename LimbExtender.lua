local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

_G.MainInfo = {}

local killProcessEvent = LocalPlayer:FindFirstChild("KillProcess") or Instance.new("BindableEvent")
killProcessEvent.Name = "KillProcess"
killProcessEvent.Parent = LocalPlayer
killProcessEvent:SetAttribute("KillProcess", true)

local function isPlayerAlive(character)
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        local LIMB = character:FindFirstChild(TARGET_LIMB)
        return LIMB and humanoid and humanoid.Health > 0
    end
    return false
end

local function storeOriginalProperties(LIMB)
    _G.MainInfo[LIMB] = {
        Size = LIMB.Size,
        Transparency = LIMB.Transparency,
        CanCollide = LIMB.CanCollide,
        Massless = LIMB.Massless
    }
end

local function restoreOriginalProperties(LIMB)
    local properties = _G.MainInfo[LIMB]
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
    if _G.MainInfo[player] then
        _G.MainInfo[player]:Disconnect()
    end
    _G.MainInfo[player] = player.CharacterAdded:Connect(handleCharacter)
end

local function onPlayerAdded(player)
    onCharacterAdded(player)
    if player.Character then
        handleCharacter(player.Character)
    end
end

local function onPlayerRemoving(player)
    _G.MainInfo[player]:Disconnect()
    _G.MainInfo[player] = nil
end

local function killEntireProcess()
    for connectionName, connection in pairs(_G.MainInfo) do
        if typeof(connection) ~= "table" then
            if connection then
                connection:Disconnect()
                _G.MainInfo[connectionName] = nil
            end
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
end

local function startProcess()
    for connectionName, connection in pairs(_G.MainInfo) do
        if typeof(connection) ~= "table" then
            if connection then
                connection:Disconnect()
                _G.MainInfo[connectionName] = nil
            end
        end
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            onPlayerAdded(player)
        end
    end

    _G.MainInfo["PlayerAdded"] = Players.PlayerAdded:Connect(onPlayerAdded)
    _G.MainInfo["PlayerRemoving"] = Players.PlayerRemoving:Connect(onPlayerRemoving)
    _G.MainInfo["InputBegan"] = UserInputService.InputBegan:Connect(onKeyPress)
end

startProcess()
killProcessEvent.Event:Connect(killEntireProcess)

local function onKeyPress(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == Enum.KeyCode.K then
        if killProcessEvent:GetAttribute("KillProcess") == true then
            killProcessEvent:Fire()
            killProcessEvent:SetAttribute("KillProcess", false)
        else
            startProcess()
            killProcessEvent:SetAttribute("KillProcess", true)
        end
    end
end
