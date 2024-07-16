local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local killProcess = LocalPlayer:FindFirstChild("KillProcess") or Instance.new("Configuration")
killProcess.Name = "KillProcess"
killProcess.Parent = LocalPlayer

local function isPlayerAlive(character)
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        local LIMB = character:FindFirstChild(TARGET_LIMB)
        return LIMB and humanoid and humanoid.Health > 0
    end
    return false
end

local function storeOriginalProperties(LIMB)
    if not _G.MainInfo[LIMB] then
    _G.MainInfo[LIMB] = {
        Size = LIMB.Size,
        Transparency = LIMB.Transparency,
        CanCollide = LIMB.CanCollide,
        Massless = LIMB.Massless
    }
    end
end

local function restoreOriginalProperties(LIMB)
    local properties = _G.MainInfo[LIMB]
    if properties then
        LIMB.Size = properties.Size
        LIMB.Transparency = properties.Transparency
        LIMB.CanCollide = properties.CanCollide
        LIMB.Massless = properties.Massless
        _G.MainInfo[LIMB] = nil
    end
    local highlight = LIMB:FindFirstChild("LimbExtenderHighlight")
    if highlight then
        highlight:Destroy()
    end
end

local function modifyLimb(character)
    local LIMB = character:WaitForChild(TARGET_LIMB)
    storeOriginalProperties(LIMB)
    
    LIMB.Transparency = _G.MainInfo.LIMB_TRANSPARENCY
    LIMB.CanCollide = _G.MainInfo.LIMB_CAN_COLLIDE
    LIMB.Massless = _G.MainInfo.LIMB_MASSLESS
    LIMB.Size = Vector3.new(_G.MainInfo.LIMB_SIZE, _G.MainInfo.LIMB_SIZE, _G.MainInfo.LIMB_SIZE)

    if USE_HIGHLIGHT then
        local highlight = LIMB:FindFirstChild("LimbExtenderHighlight") or Instance.new("Highlight", LIMB)
        highlight.Name = "LimbExtenderHighlight"
        highlight.Enabled = true
        highlight.DepthMode = _G.MainInfo.DEPTH_MODE
        highlight.Adornee = LIMB
        highlight.FillColor = _G.MainInfo.HIGHLIGHT_FILL_COLOR
        highlight.FillTransparency = _G.MainInfo.HIGHLIGHT_FILL_TRANSPARENCY
        highlight.OutlineColor =_G.MainInfo.HIGHLIGHT_OUTLINE_COLOR
        highlight.OutlineTransparency = _G.MainInfo.HIGHLIGHT_OUTLINE_TRANSPARENCY
    end
end

local function handleCharacter(character)
    if LocalPlayer.Team == nil or Players:GetPlayerFromCharacter(character).Team ~= LocalPlayer.Team then
        coroutine.wrap(function()
            while not isPlayerAlive(character) do
                task.wait()
            end
            modifyLimb(character)
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
        if typeof(connection) == "connection" then
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
    killProcess:SetAttribute("KillProcess", true)
    _G.MainInfo["InputBegan"] = UserInputService.InputBegan:Connect(onKeyPress)
end

local function startProcess()
    for connectionName, connection in pairs(_G.MainInfo) do
        print(typeof(connection))
        if typeof(connection) == "connection" then
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
    killProcess:SetAttribute("KillProcess", false)
end

if killProcess:GetAttribute("KillProcess") == nil then 
    killProcess:SetAttribute("KillProcess", false)
end

function onKeyPress(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == KEYCODE then
        if killProcess:GetAttribute("KillProcess") == false then
            killEntireProcess()
        else
            startProcess()
        end
    end
end

if killProcess:GetAttribute("KillProcess") == false then
    startProcess()
else
    killEntireProcess()
end
