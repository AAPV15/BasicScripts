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
LimbsFolder.Parent = workspace

local function isCharacterAlive(character)
    local humanoid = character:FindFirstChild("Humanoid")
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
    local highlightInstance = limb:FindFirstChild("LimbHighlight") or Instance.new("Highlight", limb)
    highlightInstance.Name = "LimbHighlight"
    highlightInstance.DepthMode = Settings.DEPTH_MODE == 1 and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
    highlightInstance.FillColor = Settings.HIGHLIGHT_FILL_COLOR
    highlightInstance.FillTransparency = Settings.HIGHLIGHT_FILL_TRANSPARENCY
    highlightInstance.OutlineColor = Settings.HIGHLIGHT_OUTLINE_COLOR
    highlightInstance.OutlineTransparency = Settings.HIGHLIGHT_OUTLINE_TRANSPARENCY
    highlightInstance.Adornee = limb
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

    local weld = visualizer:FindFirstChild("WeldConstraint") or Instance.new("WeldConstraint")
    visualizer.CFrame = limb.CFrame
    weld.Part0 = limb
    weld.Part1 = visualizer
    weld.Parent = visualizer

    if Settings.USE_HIGHLIGHT then
        applyLimbHighlight(visualizer)
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
    local waited = 0
    while not isCharacterAlive(character) and waited <= 10 do 
        task.wait(0.1) waited += 0.1 
    end
    if not isCharacterAlive(character) then return end

    if Settings.TEAM_CHECK and (LocalPlayer.Team == nil or PlayersService:GetPlayerFromCharacter(character).Team ~= LocalPlayer.Team) then
        modifyTargetLimb(character)
    elseif not Settings.TEAM_CHECK then
        modifyTargetLimb(character)
    end

    local humanoid = character:WaitForChild("Humanoid")
    if Settings.RESTORE_ORIGINAL_LIMB_ON_DEATH then
        getgenv().GlobalData[character.Name .. " OnDeath"] = humanoid.HealthChanged:Connect(function(health)
            if health <= 0 then
                restoreLimbProperties(character:FindFirstChild(Settings.TARGET_LIMB))
            end
        end)
    else
        getgenv().GlobalData[character.Name .. " OnDeath"] = humanoid.Died:Connect(function()
            restoreLimbProperties(character:FindFirstChild(Settings.TARGET_LIMB))
        end)
    end
end

local function onPlayerCharacterAdded(player)
    getgenv().GlobalData[player.Name .. " CharacterAdded"] = player.CharacterAdded:Connect(function(character)
        if player == LocalPlayer then
            LimbsFolder.Parent = character
        else
            processCharacterLimb(character)
        end
    end)

    getgenv().GlobalData[player.Name .. " CharacterRemoving"] = player.CharacterRemoving:Connect(function(character)
        if player == LocalPlayer then
            LimbsFolder.Parent = workspace
        else
            restoreLimbProperties(character:FindFirstChild(Settings.TARGET_LIMB))
        end
    end)


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

local function LocalTransparencyModifier(part)
	getgenv().GlobalData[part.Name .. " LocalTransparencyModifier"] = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
		part.LocalTransparencyModifier = 0
	end)
	
	part.LocalTransparencyModifier = 0
end

local function endProcess(specialProcess)
    for name, connection in pairs(getgenv().GlobalData) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
            getgenv().GlobalData[name] = {}
            getgenv().GlobalData[name] = nil
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
    getgenv().GlobalData.LimbsFolderChildAdded = LimbsFolder.ChildAdded:Connect(LocalTransparencyModifier)
    getgenv().GlobalData.InputBeganConnection = UserInputService.InputBegan:Connect(handleKeyInput)
    getgenv().GlobalData.PlayerAddedConnection = PlayersService.PlayerAdded:Connect(onPlayerCharacterAdded)
    getgenv().GlobalData.PlayerRemovingConnection = PlayersService.PlayerRemoving:Connect(onPlayerRemoved)
    getgenv().GlobalData.FolderProtection = LimbsFolder.AncestryChanged:Connect(FolderProtection)

    for _, player in pairs(PlayersService:GetPlayers()) do
        onPlayerCharacterAdded(player)
    end
end

function FolderProtection(child, parent)
    if not parent and child:IsA("Folder") then
        warn("LimbFolder was deleted! Script may have worse performance in this game.")
        getgenv().GlobalData.LimbsFolder = Instance.new("Folder")
        LimbsFolder = getgenv().GlobalData.LimbsFolder
        startProcess()
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

for _, part in LimbsFolder:GetChildren() do
    LocalTransparencyModifier(part)
end
