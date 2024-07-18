local defaultSettings = {
    KEYCODE = Enum.KeyCode.K,
    TARGET_LIMB = "Head",
    LIMB_SIZE = 10,
    LIMB_TRANSPARENCY = 0.5,
    LIMB_CAN_COLLIDE = false,
    LIMB_MASSLESS = true,
    TEAM_CHECK = true,
    USE_HIGHLIGHT = true,
    DEPTH_MODE = Enum.HighlightDepthMode.Occluded,
    HIGHLIGHT_FILL_COLOR = Color3.fromRGB(0, 255, 0),
    HIGHLIGHT_FILL_TRANSPARENCY = 0.5,
    HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255),
    HIGHLIGHT_OUTLINE_TRANSPARENCY = 0,
    RESTORE_ORIGINAL_LIMB_ON_DEATH = false
}

_G.Settings = _G.Settings or defaultSettings

for key, value in pairs(defaultSettings) do
    if _G.Settings[key] == nil then
        _G.Settings[key] = value
    end
end

_G.MainInfo = _G.MainInfo or {}

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local killProcess = LocalPlayer:FindFirstChild("KillProcess") or Instance.new("Configuration")
killProcess.Name = "KillProcess"
killProcess.Parent = LocalPlayer

local function isPlayerAlive(character)
    if character then
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        local LIMB = character:FindFirstChild(_G.Settings.TARGET_LIMB)
        if humanoid and LIMB then      
            ContentProvider:PreloadAsync({humanoid, LIMB})
            return humanoid and LIMB
        end
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
    local LIMB = character[_G.Settings.TARGET_LIMB]
    storeOriginalProperties(LIMB)
    
    LIMB.Transparency = _G.Settings.LIMB_TRANSPARENCY
    LIMB.CanCollide = _G.Settings.LIMB_CAN_COLLIDE
    LIMB.Massless = _G.Settings.LIMB_MASSLESS
    LIMB.Size = Vector3.new(_G.Settings.LIMB_SIZE, _G.Settings.LIMB_SIZE, _G.Settings.LIMB_SIZE)

    if _G.Settings.USE_HIGHLIGHT then
        local highlight = LIMB:FindFirstChild("LimbExtenderHighlight") or Instance.new("Highlight", LIMB)
        highlight.Name = "LimbExtenderHighlight"
        highlight.Enabled = true
        highlight.DepthMode = _G.Settings.DEPTH_MODE
        highlight.Adornee = LIMB
        highlight.FillColor = _G.Settings.HIGHLIGHT_FILL_COLOR
        highlight.FillTransparency = _G.Settings.HIGHLIGHT_FILL_TRANSPARENCY
        highlight.OutlineColor = _G.Settings.HIGHLIGHT_OUTLINE_COLOR
        highlight.OutlineTransparency = _G.Settings.HIGHLIGHT_OUTLINE_TRANSPARENCY
    end
end

local function handleCharacter(character)

    if _G.Settings.RESTORE_ORIGINAL_LIMB_ON_DEATH == true then
        local holdtick = tick()
        while not isPlayerAlive(character) do
            task.wait()
        end
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        local player = Players:GetPlayerFromCharacter(character)
        if humanoid and player then
            _G.MainInfo[player.Name .. " Humanoid"] = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                if humanoid.Health <= 0 then
                    local LIMB = character:FindFirstChild(_G.Settings.TARGET_LIMB)
                    if LIMB then
                        restoreOriginalProperties(LIMB)
                    end
                    _G.MainInfo[player.Name .. " Humanoid"]:Disconnect()
                    _G.MainInfo[player.Name .. " Humanoid"] = nil
                end
            end)
        end
    end
    
    if _G.Settings.TEAM_CHECK then
        if LocalPlayer.Team == nil or Players:GetPlayerFromCharacter(character).Team ~= LocalPlayer.Team then
            coroutine.wrap(function()
                while not isPlayerAlive(character) do
                    task.wait()
                end
                modifyLimb(character)
            end)()
        end
    else
        coroutine.wrap(function()
            while not isPlayerAlive(character) do
                task.wait()
            end
            modifyLimb(character)
        end)()
    end
end

local function onCharacterAdded(player)
    if _G.MainInfo[player.Name .. " Character"] then
        _G.MainInfo[player.Name .. " Character"]:Disconnect()
    end
    _G.MainInfo[player.Name .. " Character"] = player.CharacterAdded:Connect(handleCharacter)
end

local function onPlayerAdded(player)
    onCharacterAdded(player)
    if player.Character then
        handleCharacter(player.Character)
    end
end

local function onPlayerRemoving(player)
    if _G.MainInfo[player.Name .. " Character"] then
        _G.MainInfo[player.Name .. " Character"]:Disconnect()
        _G.MainInfo[player.Name .. " Character"] = nil
    end
    if _G.MainInfo[player.Name .. " Humanoid"] then
        _G.MainInfo[player.Name .. " Humanoid"]:Disconnect()
        _G.MainInfo[player.Name .. " Humanoid"] = nil
    end
end

local function killEntireProcess()
    for connectionName, connection in pairs(_G.MainInfo) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
            _G.MainInfo[connectionName] = nil
        end
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            local LIMB = player.Character:FindFirstChild(_G.Settings.TARGET_LIMB)
            if LIMB then
                restoreOriginalProperties(LIMB)
            end
        end
    end
    _G.MainInfo["InputBegan"] = UserInputService.InputBegan:Connect(onKeyPress)
end

local function startProcess()
    for connectionName, connection in pairs(_G.MainInfo) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
            _G.MainInfo[connectionName] = nil
        end
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if player.Character then
                local prevLimb = killProcess:GetAttribute("PreviousLimb")
                if prevLimb then
                    local LIMB = player.Character:FindFirstChild(killProcess:GetAttribute("PreviousLimb"))
                    if LIMB then
                        restoreOriginalProperties(LIMB)
                    end
                end
            end
            onPlayerAdded(player)
        end
    end
    
    killProcess:SetAttribute("PreviousLimb", _G.Settings.TARGET_LIMB)
    _G.MainInfo["PlayerAdded"] = Players.PlayerAdded:Connect(onPlayerAdded)
    _G.MainInfo["PlayerRemoving"] = Players.PlayerRemoving:Connect(onPlayerRemoving)
    _G.MainInfo["InputBegan"] = UserInputService.InputBegan:Connect(onKeyPress)
end

function onKeyPress(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == _G.Settings.KEYCODE then
        if killProcess:GetAttribute("KillProcess") == false then
            killProcess:SetAttribute("KillProcess", true)
            killEntireProcess()
        else
            killProcess:SetAttribute("KillProcess", false)
            startProcess()
        end
    end
end

if killProcess:GetAttribute("KillProcess") == nil then 
    killProcess:SetAttribute("KillProcess", false)
end

if killProcess:GetAttribute("KillProcess") == false then
    startProcess()
else
    killEntireProcess()
end
