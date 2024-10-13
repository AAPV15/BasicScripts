if getgenv().IsProcessActive and type(getgenv().GlobalData.LimbExtenderTerminateOldProcess) == "function" then
    getgenv().GlobalData.LimbExtenderTerminateOldProcess("FullKill")
end

local defaultSettings = {
    TOGGLE = "K",
    TARGET_LIMB = "Head",
    LIMB_SIZE = 10,
    LIMB_TRANSPARENCY = 0.5,
    LIMB_CAN_COLLIDE = false,
    TEAM_CHECK = true,
    USE_HIGHLIGHT = true,
    DEPTH_MODE = 2,
    HIGHLIGHT_FILL_COLOR = Color3.fromRGB(0, 255, 0),
    HIGHLIGHT_FILL_TRANSPARENCY = 0.5,
    HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255),
    HIGHLIGHT_OUTLINE_TRANSPARENCY = 0,
    RESTORE_ORIGINAL_LIMB_ON_DEATH = true
}

getgenv().Settings = setmetatable(getgenv().Settings or {}, {__index = defaultSettings})
getgenv().GlobalData = getgenv().GlobalData or {}

local Settings = getgenv().Settings

local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = PlayersService.LocalPlayer

getgenv().GlobalData.LimbsFolder = getgenv().GlobalData.LimbsFolder or Instance.new("Folder")
local LimbsFolder = getgenv().GlobalData.LimbsFolder

local function isCharacterAlive(character)
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    local limb = character:FindFirstChild(Settings.TARGET_LIMB)
    return humanoid and limb
end

local function saveOriginalLimbProperties(limb)
    if getgenv().GlobalData[limb] then return end
    getgenv().GlobalData[limb] = {
        Size = limb.Size,
        Transparency = limb.Transparency,
        CanCollide = limb.CanCollide,
        Massless = limb.Massless,
    }
end

local function restoreLimbProperties(limb)
    local storedProperties = getgenv().GlobalData[limb]
    if not storedProperties then return end

    limb.Size = storedProperties.Size
    limb.Transparency = storedProperties.Transparency
    limb.CanCollide = storedProperties.CanCollide
    limb.Massless = storedProperties.Massless

    getgenv().GlobalData[limb] = nil

    local visualizer = LimbsFolder:FindFirstChild(limb.Parent.Name)
    if visualizer then
        visualizer:Destroy()
    end
end

local function applyLimbHighlight(limb)
    if not limb.Parent then return end

    local limbb = LimbsFolder:FindFirstChild(limb.Parent.Name)
    if not limbb then return end

    local highlightInstance = limbb:FindFirstChild("LimbHighlight") or Instance.new("Highlight", limbb)
    highlightInstance.Name = "LimbHighlight"
    highlightInstance.DepthMode = Settings.DEPTH_MODE == 1 and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
    highlightInstance.FillColor = Settings.HIGHLIGHT_FILL_COLOR
    highlightInstance.FillTransparency = Settings.HIGHLIGHT_FILL_TRANSPARENCY
    highlightInstance.OutlineColor = Settings.HIGHLIGHT_OUTLINE_COLOR
    highlightInstance.OutlineTransparency = Settings.HIGHLIGHT_OUTLINE_TRANSPARENCY
end

local function createVisualizer(limb)
    local visualizer = LimbsFolder:FindFirstChild(limb.Parent.Name) or Instance.new("Part")
    visualizer.Size = Vector3.new(Settings.LIMB_SIZE, Settings.LIMB_SIZE, Settings.LIMB_SIZE)
    visualizer.Transparency = Settings.LIMB_TRANSPARENCY
    visualizer.CanCollide = Settings.LIMB_CAN_COLLIDE
    visualizer.Anchored = false
    visualizer.Massless = true
    visualizer.Name = limb.Parent.Name
    visualizer.Color = limb.Color
    visualizer.Parent = LimbsFolder

    local weld = Instance.new("WeldConstraint")
    visualizer.CFrame = limb.CFrame
    weld.Part0 = limb
    weld.Part1 = visualizer
    weld.Parent = visualizer

    if Settings.USE_HIGHLIGHT then
        applyLimbHighlight(limb)
    end
end

local function modifyTargetLimb(character)
    local limb = character:WaitForChild(Settings.TARGET_LIMB)
    saveOriginalLimbProperties(limb)

    limb.Transparency = 1
    limb.CanCollide = false
    limb.Size = Vector3.new(Settings.LIMB_SIZE, Settings.LIMB_SIZE, Settings.LIMB_SIZE)
    limb.Massless = true

    createVisualizer(limb)
end

local function processCharacterLimb(character)
    if not isCharacterAlive(character) then return end
    modifyTargetLimb(character)

    local humanoid = character:WaitForChild("Humanoid")
    if Settings.RESTORE_ORIGINAL_LIMB_ON_DEATH then
        getgenv().GlobalData[humanoid] = humanoid.HealthChanged:Connect(function(health)
            if health <= 0 then
                restoreLimbProperties(character:FindFirstChild(Settings.TARGET_LIMB))
            end
        end)
    else
        humanoid.Died:Connect(function()
            restoreLimbProperties(character:FindFirstChild(Settings.TARGET_LIMB))
        end)
    end
end

local function onPlayerCharacterAdded(player)
    getgenv().GlobalData[player] = {
        player.CharacterAdded:Connect(function(character)
            if player == LocalPlayer then
                LimbsFolder.Parent = character
            else
                processCharacterLimb(character)
            end
        end),
        player.CharacterRemoving:Connect(function(character)
            if player == LocalPlayer then
                LimbsFolder.Parent = character
            else
                restoreLimbProperties(character:FindFirstChild(Settings.TARGET_LIMB))
            end
        end)
    }

    if player.Character then
        if player == LocalPlayer then
            LimbsFolder.Parent = player.Character
        else
            processCharacterLimb(player.Character)
        end
    end
end

local function onPlayerRemoved(player)
    restoreLimbProperties(player.Character and player.Character:FindFirstChild(Settings.TARGET_LIMB))
    if getgenv().GlobalData[player] then
        for _, connection in pairs(getgenv().GlobalData[player]) do 
            connection:Disconnect()
        end
        getgenv().GlobalData[player] = nil
    end
end

local function endProcess(specialProcess)
    for _, connection in pairs(getgenv().GlobalData) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect() 
        end
    end

    for _, player in pairs(PlayersService:GetPlayers()) do
        restoreLimbProperties(player.Character and player.Character:FindFirstChild(Settings.TARGET_LIMB))
        if getgenv().GlobalData.LastLimbName then
            restoreLimbProperties(player.Character and player.Character:FindFirstChild(getgenv().GlobalData.LastLimbName))
        end
    end

    if specialProcess == "DetectInput" then 
        getgenv().GlobalData.InputBeganConnection = UserInputService.InputBegan:Connect(handleKeyInput)
    elseif specialProcess == "FullKill" then
        getgenv().GlobalData = {}
        script:Destroy()
    end
end

local function startProcess()
    endProcess()
    getgenv().GlobalData.LastLimbName = Settings.TARGET_LIMB
    getgenv().GlobalData.InputBeganConnection = UserInputService.InputBegan:Connect(handleKeyInput)
    getgenv().GlobalData.PlayerAddedConnection = PlayersService.PlayerAdded:Connect(onPlayerCharacterAdded)
    getgenv().GlobalData.PlayerRemovingConnection = PlayersService.PlayerRemoving:Connect(onPlayerRemoved)

    for _, player in pairs(PlayersService:GetPlayers()) do
        onPlayerCharacterAdded(player)
    end
end

function handleKeyInput(input, isProcessed)
    if isProcessed or input.KeyCode ~= Enum.KeyCode[Settings.TOGGLE] then return end
    getgenv().GlobalData.IsProcessActive = not getgenv().GlobalData.IsProcessActive
    if getgenv().GlobalData.IsProcessActive then
        startProcess()
    else
        endProcess("DetectInput")
    end
end

if getgenv().GlobalData.IsProcessActive == nil then
    getgenv().GlobalData.IsProcessActive = true
end

if getgenv().GlobalData.IsProcessActive then
    startProcess()
else
    endProcess("DetectInput")
end

getgenv().GlobalData.LimbExtenderTerminateOldProcess = endProcess
