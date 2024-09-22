if getgenv().IsProcessActive and type(getgenv().GlobalData.LimbExtenderTerminateOldProcess) == "function" then
    getgenv().GlobalData.LimbExtenderTerminateOldProcess("FullKill")
end

local defaultSettings = {
    KEYCODE = Enum.KeyCode.K,
    TARGET_LIMB = "True",
    LIMB_SIZE = 20,
    LIMB_TRANSPARENCY = 0.5,
    LIMB_CAN_COLLIDE = false,
    TEAM_CHECK = false,
    USE_HIGHLIGHT = true,
    DEPTH_MODE = 1,
    HIGHLIGHT_FILL_COLOR = Color3.fromRGB(0, 255, 0),
    HIGHLIGHT_FILL_TRANSPARENCY = 0.5,
    HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255),
    HIGHLIGHT_OUTLINE_TRANSPARENCY = 0,
    RESTORE_ORIGINAL_LIMB_ON_DEATH = false
}

getgenv().Settings = setmetatable(getgenv().Settings or {}, {__index = defaultSettings})
getgenv().GlobalData = getgenv().GlobalData or {}

local Settings = getgenv().Settings

local ContentProvider = game:GetService("ContentProvider")
local PlayersService = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = PlayersService.LocalPlayer

local function isCharacterAlive(character)
    if character then
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        local limb = character:FindFirstChild(Settings.TARGET_LIMB)
        if humanoid and limb then
            local assets = {}
            table.insert(assets, limb)
            for _, asset in pairs(limb:GetDescendants()) do
                table.insert(assets, asset)
            end
            ContentProvider:PreloadAsync(assets)
            return true
        end
    end
    return false
end

local function saveOriginalLimbProperties(limb)
    if getgenv().GlobalData[limb] then return end
    local meshPart = limb:FindFirstChildWhichIsA("SpecialMesh") or limb:FindFirstChildWhichIsA("MeshPart")
    getgenv().GlobalData[limb] = {
        Size = limb.Size,
        Transparency = limb.Transparency,
        CanCollide = limb.CanCollide,
        Massless = limb.Massless,
        Mesh = meshPart and {
            ClassName = meshPart.ClassName,
            MeshId = meshPart:IsA("SpecialMesh") and meshPart.MeshId or "",
            TextureId = meshPart:IsA("SpecialMesh") and meshPart.TextureId or "",
            Scale = meshPart:IsA("SpecialMesh") and meshPart.Scale or Vector3.new(),
            Offset = meshPart:IsA("SpecialMesh") and meshPart.Offset or Vector3.new()
        }
    }
end

local function restoreLimbProperties(limb)
    local storedProperties = getgenv().GlobalData[limb]
    if not storedProperties then return end

    limb.Size = storedProperties.Size
    limb.Transparency = storedProperties.Transparency
    limb.CanCollide = storedProperties.CanCollide
    limb.Massless = storedProperties.Massless

    if storedProperties.Mesh then
        local mesh = limb:FindFirstChildWhichIsA("SpecialMesh") or Instance.new(storedProperties.Mesh.ClassName, limb)
        if mesh:IsA("SpecialMesh") then
            mesh.MeshId = storedProperties.Mesh.MeshId
            mesh.TextureId = storedProperties.Mesh.TextureId
            mesh.Scale = storedProperties.Mesh.Scale
            mesh.Offset = storedProperties.Mesh.Offset
        end
    end

    getgenv().GlobalData[limb] = nil
    local highlightInstance = limb:WaitForChild("LimbHighlight", 3)
    if highlightInstance then highlightInstance:Destroy() end
end

local function applyLimbHighlight(limb, currentTick)
    local highlightInstance = limb:FindFirstChildWhichIsA("Highlight") or Instance.new("Highlight", limb)
    highlightInstance.Name = "LimbHighlight"
    if Settings.DEPTH_MODE == 1 then
        highlightInstance.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    else
        highlightInstance.DepthMode = Enum.HighlightDepthMode.Occluded
    end
    highlightInstance.FillColor = Settings.HIGHLIGHT_FILL_COLOR
    highlightInstance.FillTransparency = Settings.HIGHLIGHT_FILL_TRANSPARENCY
    highlightInstance.OutlineColor = Settings.HIGHLIGHT_OUTLINE_COLOR
    highlightInstance.OutlineTransparency = Settings.HIGHLIGHT_OUTLINE_TRANSPARENCY

    getgenv().GlobalData[highlightInstance] = highlightInstance.AncestryChanged:Once(function()
        if tick() - currentTick <= 0.7 then
            highlightInstance:Destroy()
            applyLimbHighlight(limb.Parent)
        else
            getgenv().GlobalData[highlightInstance] = nil
        end
    end)
end

local function modifyTargetLimb(character)
    local limb = character:WaitForChild(Settings.TARGET_LIMB)
    saveOriginalLimbProperties(limb)

    limb.Transparency = Settings.LIMB_TRANSPARENCY
    limb.CanCollide = Settings.LIMB_CAN_COLLIDE
    limb.Size = Vector3.new(Settings.LIMB_SIZE, Settings.LIMB_SIZE, Settings.LIMB_SIZE)
    limb.Massless = true

    local meshPart = limb:FindFirstChildWhichIsA("SpecialMesh")
    if meshPart then meshPart:Destroy() end

    if Settings.USE_HIGHLIGHT then
        applyLimbHighlight(limb, tick())
    end
end

local function processCharacterLimb(character)
    local function modifyIfCharacterAlive()
        while not isCharacterAlive(character) do task.wait() end
        modifyTargetLimb(character)
    end

    if Settings.TEAM_CHECK and (LocalPlayer.Team == nil or PlayersService:GetPlayerFromCharacter(character).Team ~= LocalPlayer.Team) then
        coroutine.wrap(modifyIfCharacterAlive)()
    elseif not Settings.TEAM_CHECK then
        coroutine.wrap(modifyIfCharacterAlive)()
    end

    if Settings.RESTORE_ORIGINAL_LIMB_ON_DEATH then
        local humanoid = character:WaitForChild("Humanoid")
        getgenv().GlobalData[humanoid] = humanoid.HealthChanged:Connect(function(health)
            if health <= 0 then
                restoreLimbProperties(character:FindFirstChild(Settings.TARGET_LIMB))
            end
        end)
    end
end

local function onPlayerCharacterAdded(player)

    getgenv().GlobalData[player] = player.CharacterAdded:Connect(function(character)
        processCharacterLimb(character)
    end)

    player.CharacterRemoving:Connect(function()
        restoreLimbProperties(player.Character:FindFirstChild(Settings.TARGET_LIMB or player.Character:FindFirstChild(getgenv().GlobalData.LastLimbName)))
    end)

    if player.Character then
        processCharacterLimb(player.Character)
    end
end

local function onPlayerRemoved(player)
    if player.Character then
        restoreLimbProperties(player.Character:FindFirstChild(Settings.TARGET_LIMB))
    end
    if getgenv().GlobalData[player] then
        getgenv().GlobalData[player]:Disconnect()
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
        if player.Character then
            if getgenv().GlobalData.LastLimbName then
                local limb = player.Character:FindFirstChild(getgenv().GlobalData.LastLimbName)
                if limb then
                    restoreLimbProperties(limb)
                end
            end
            local limb = player.Character:FindFirstChild(Settings.TARGET_LIMB)
            if limb then
                restoreLimbProperties(limb)
            end
        end
    end

    if specialProcess == "DetectInput" then 
        getgenv().GlobalData.InputBeganConnection = UserInputService.InputBegan:Connect(handleKeyInput)
    elseif specialProcess == "FullKill" then
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
        if player ~= LocalPlayer then 
            onPlayerCharacterAdded(player)
        end 
    end
end

function handleKeyInput(input, isProcessed)
    if isProcessed or input.KeyCode ~= Settings.KEYCODE then return end

    getgenv().GlobalData.IsProcessActive = not getgenv().GlobalData.IsProcessActive
    if getgenv().GlobalData.IsProcessActive then
        startProcess()
    else
        endProcess("DetectInput")
    end
end

getgenv().GlobalData.LimbExtenderTerminateOldProcess = endProcess

if getgenv().GlobalData.IsProcessActive == nil then
    getgenv().GlobalData.IsProcessActive = true
end

if getgenv().GlobalData.IsProcessActive then
    startProcess()
else
    endProcess("DetectInput")
end
