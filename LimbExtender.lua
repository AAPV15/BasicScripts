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

_G.Settings = setmetatable(_G.Settings or {}, {__index = defaultSettings})
_G.MainInfo = _G.MainInfo or {}

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local killProcess = LocalPlayer:FindFirstChild("KillProcess") or Instance.new("Configuration", LocalPlayer)
killProcess.Name = "KillProcess"

local function isPlayerAlive(character)
    if character then
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        local limb = character:FindFirstChild(_G.Settings.TARGET_LIMB)
        if humanoid and limb then
            ContentProvider:PreloadAsync({humanoid, limb})
            return true
        end
    end
    return false
end

local function storeOriginalProperties(limb)
    if not _G.MainInfo[limb] then
        _G.MainInfo[limb] = {
            Size = limb.Size,
            Transparency = limb.Transparency,
            CanCollide = limb.CanCollide,
            Massless = limb.Massless
        }
    end
end

local function restoreOriginalProperties(limb)
    local properties = _G.MainInfo[limb]
    if properties then
        limb.Size = properties.Size
        limb.Transparency = properties.Transparency
        limb.CanCollide = properties.CanCollide
        limb.Massless = properties.Massless
        _G.MainInfo[limb] = nil
    end
    local highlight = limb:FindFirstChild("LimbExtenderHighlight")
    if highlight then
        highlight:Destroy()
    end
end

local function modifyLimb(character)
    local limb = character[_G.Settings.TARGET_LIMB]
    storeOriginalProperties(limb)

    limb.Transparency = _G.Settings.LIMB_TRANSPARENCY
    limb.CanCollide = _G.Settings.LIMB_CAN_COLLIDE
    limb.Massless = _G.Settings.LIMB_MASSLESS
    limb.Size = Vector3.new(_G.Settings.LIMB_SIZE, _G.Settings.LIMB_SIZE, _G.Settings.LIMB_SIZE)

    if _G.Settings.USE_HIGHLIGHT then
        local highlight = Instance.new("Highlight", limb)
        highlight.Name = "LimbExtenderHighlight"
        highlight.Enabled = true
        highlight.DepthMode = _G.Settings.DEPTH_MODE
        highlight.Adornee = limb
        highlight.FillColor = _G.Settings.HIGHLIGHT_FILL_COLOR
        highlight.FillTransparency = _G.Settings.HIGHLIGHT_FILL_TRANSPARENCY
        highlight.OutlineColor = _G.Settings.HIGHLIGHT_OUTLINE_COLOR
        highlight.OutlineTransparency = _G.Settings.HIGHLIGHT_OUTLINE_TRANSPARENCY
    end
end

local function handleCharacter(character)
    if _G.Settings.RESTORE_ORIGINAL_LIMB_ON_DEATH then
        local humanoid = character:WaitForChild("Humanoid")
        _G.MainInfo[humanoid] = humanoid.HealthChanged:Connect(function(newHealth)
            local limb = character:FindFirstChild(_G.Settings.TARGET_LIMB)
            if limb and newHealth <= 0 then
                restoreOriginalProperties(limb)
            end
        end)
    end

    local function checkAndModifyLimb()
        while not isPlayerAlive(character) do
            task.wait()
        end
        modifyLimb(character)
    end

    if _G.Settings.TEAM_CHECK then
        if LocalPlayer.Team == nil or Players:GetPlayerFromCharacter(character).Team ~= LocalPlayer.Team then
            coroutine.wrap(checkAndModifyLimb)()
        end
    else
        coroutine.wrap(checkAndModifyLimb)()
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
    if _G.MainInfo[player] then
        _G.MainInfo[player]:Disconnect()
        _G.MainInfo[player] = nil
    end
    local limb = player.Character and player.Character:FindFirstChild(_G.Settings.TARGET_LIMB)
    if limb then
        restoreOriginalProperties(limb)
    end
end

local function killEntireProcess(detectInput)
    for _, connection in pairs(_G.MainInfo) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            local limb = player.Character:FindFirstChild(_G.Settings.TARGET_LIMB)
            if limb then
                restoreOriginalProperties(limb)
            end
            if killProcess:GetAttribute("PreviousLimb") then
                local limb = player.Character:FindFirstChild(killProcess:GetAttribute("PreviousLimb"))
                if limb then
                    restoreOriginalProperties(limb)
                end
            end
        end
    end
    _G.MainInfo = {}
    if detectInput then 
        _G.MainInfo["InputBegan"] = UserInputService.InputBegan:Connect(onKeyPress)
    end
end

local function startProcess()
    killEntireProcess()
    killProcess:SetAttribute("PreviousLimb", _G.Settings.TARGET_LIMB)
    _G.MainInfo["PlayerAdded"] = Players.PlayerAdded:Connect(onPlayerAdded)
    _G.MainInfo["PlayerRemoving"] = Players.PlayerRemoving:Connect(onPlayerRemoving)
    _G.MainInfo["InputBegan"] = UserInputService.InputBegan:Connect(onKeyPress)
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            onPlayerAdded(player)
        end
    end
end

function onKeyPress(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == _G.Settings.KEYCODE then
        local killProcessActive = killProcess:GetAttribute("KillProcess")
        killProcess:SetAttribute("KillProcess", not killProcessActive)
        if killProcessActive then
            killEntireProcess(true)
        else
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
    killEntireProcess(true)
end
