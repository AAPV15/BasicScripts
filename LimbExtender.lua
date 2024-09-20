local defaultSettings = {
    KEYCODE = Enum.KeyCode.K,
    TARGET_LIMB = "Head",
    LIMB_SIZE = 10,
    LIMB_TRANSPARENCY = 0.5,
    LIMB_CAN_COLLIDE = false,
    LIMB_MASSLESS = true,
    TEAM_CHECK = false,
    USE_HIGHLIGHT = true,
    DEPTH_MODE = Enum.HighlightDepthMode.Occluded,
    HIGHLIGHT_FILL_COLOR = Color3.fromRGB(0, 255, 0),
    HIGHLIGHT_FILL_TRANSPARENCY = 0.5,
    HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255),
    HIGHLIGHT_OUTLINE_TRANSPARENCY = 0,
    RESTORE_ORIGINAL_LIMB_ON_DEATH = false
}

getgenv().Settings = setmetatable(getgenv().Settings or {}, {__index = defaultSettings})
getgenv().MainInfo = getgenv().MainInfo or {}

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local MiscData = LocalPlayer:FindFirstChild("MiscData") or Instance.new("Configuration", LocalPlayer)
MiscData.Name = "MiscData"

local function isPlayerAlive(character)
    if character then
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        local limb = character:FindFirstChild(getgenv().Settings.TARGET_LIMB)
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

local function storeOriginalProperties(limb)
    local mesh = limb:FindFirstChildWhichIsA("SpecialMesh") or limb:FindFirstChildWhichIsA("MeshPart")
    if not getgenv().MainInfo[limb] then
        getgenv().MainInfo[limb] = {
            Size = limb.Size,
            Transparency = limb.Transparency,
            CanCollide = limb.CanCollide,
            Massless = limb.Massless,
            Mesh = mesh and {
                ClassName = mesh.ClassName,
                MeshId = mesh:IsA("SpecialMesh") and mesh.MeshId or "",
                TextureId = mesh:IsA("SpecialMesh") and mesh.TextureId or "",
                Scale = mesh:IsA("SpecialMesh") and mesh.Scale or Vector3.new(),
                Offset = mesh:IsA("SpecialMesh") and mesh.Offset or Vector3.new()
            } or nil
        }
    end
end

local function restoreOriginalProperties(limb)
    local properties = getgenv().MainInfo[limb]
    if properties then
        limb.Size = properties.Size
        limb.Transparency = properties.Transparency
        limb.CanCollide = properties.CanCollide
        limb.Massless = properties.Massless

        if properties.Mesh then
            local mesh = limb:FindFirstChildWhichIsA("SpecialMesh") or limb:FindFirstChildWhichIsA("MeshPart")
            if not mesh then
                if properties.Mesh.ClassName == "SpecialMesh" then
                    mesh = Instance.new("SpecialMesh", limb)
                else
                    mesh = Instance.new("MeshPart", limb)
                end
            end
            if properties.Mesh.ClassName == "SpecialMesh" then
                mesh.MeshId = properties.Mesh.MeshId
                mesh.TextureId = properties.Mesh.TextureId
                mesh.Scale = properties.Mesh.Scale
                mesh.Offset = properties.Mesh.Offset
            end
        end

        getgenv().MainInfo[limb] = nil
    end

    local highlight = limb:FindFirstChild("LimbExtenderHighlight")
    if highlight then
        highlight:Destroy()
    end
end

local function modifyLimb(character)
    local limb = character:WaitForChild(getgenv().Settings.TARGET_LIMB)
    local mesh = limb:FindFirstChildWhichIsA("SpecialMesh")
    local currentTick = tick()
    storeOriginalProperties(limb)

    limb.Transparency = getgenv().Settings.LIMB_TRANSPARENCY
    limb.CanCollide = getgenv().Settings.LIMB_CAN_COLLIDE
    limb.Massless = getgenv().Settings.LIMB_MASSLESS
    limb.Size = Vector3.new(getgenv().Settings.LIMB_SIZE, getgenv().Settings.LIMB_SIZE, getgenv().Settings.LIMB_SIZE)

    if mesh then
        mesh:Destroy()
    end

    if getgenv().Settings.USE_HIGHLIGHT then
        local highlight = limb:FindFirstChild("LimbExtenderHighlight") or Instance.new("Highlight")
        highlight.Name = "LimbExtenderHighlight"
        highlight.Enabled = true
        highlight.DepthMode = getgenv().Settings.DEPTH_MODE
        highlight.Adornee = limb
        highlight.FillColor = getgenv().Settings.HIGHLIGHT_FILL_COLOR
        highlight.FillTransparency = getgenv().Settings.HIGHLIGHT_FILL_TRANSPARENCY
        highlight.OutlineColor = getgenv().Settings.HIGHLIGHT_OUTLINE_COLOR
        highlight.OutlineTransparency = getgenv().Settings.HIGHLIGHT_OUTLINE_TRANSPARENCY
        highlight.Parent = limb

        getgenv().MainInfo[highlight] = highlight.AncestryChanged:Once(function()
            if tick() - currentTick <= 0.7 then
                getgenv().MainInfo[highlight]:Disconnect()
                getgenv().MainInfo[highlight] = nil
                highlight:Destroy()
                modifyLimb(character)     
            else
                getgenv().MainInfo[highlight] = nil
            end
        end)
    end
end

local function handleCharacter(character)
    if getgenv().Settings.RESTORE_ORIGINAL_LIMB_ON_DEATH then
        local humanoid = character:WaitForChild("Humanoid")
        getgenv().MainInfo[humanoid] = humanoid.HealthChanged:Connect(function(newHealth)
            local limb = character:FindFirstChild(getgenv().Settings.TARGET_LIMB)
            if limb and newHealth <= 0 then
                restoreOriginalProperties(limb)
                getgenv().MainInfo[humanoid] = nil
            end
        end)
    end

    local function checkAndModifyLimb()
        while not isPlayerAlive(character) do
            task.wait()
        end
        modifyLimb(character)
    end

    if getgenv().Settings.TEAM_CHECK then
        if LocalPlayer.Team == nil or Players:GetPlayerFromCharacter(character).Team ~= LocalPlayer.Team then
            coroutine.wrap(checkAndModifyLimb)()
        end
    else
        coroutine.wrap(checkAndModifyLimb)()
    end
end

local function onPlayerAdded(player)
    if getgenv().MainInfo[player] then
        getgenv().MainInfo[player]:Disconnect()
    end
    getgenv().MainInfo[player] = player.CharacterAdded:Connect(function(character)
        handleCharacter(character)
    end)
    if player.Character then
        handleCharacter(player.Character)
    end
end

local function onPlayerRemoving(player)
    if getgenv().MainInfo[player] then
        getgenv().MainInfo[player]:Disconnect()
        getgenv().MainInfo[player] = nil
    end
    local limb = player.Character and player.Character:FindFirstChild(getgenv().Settings.TARGET_LIMB)
    if limb then
        restoreOriginalProperties(limb)
    end
end

local function terminateProcess(detectInput)
    for _, connection in pairs(getgenv().MainInfo) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            local limb = player.Character:FindFirstChild(getgenv().Settings.TARGET_LIMB)
            if limb then
                restoreOriginalProperties(limb)
            end
            if MiscData:GetAttribute("PreviousLimb") then
                local limb = player.Character:FindFirstChild(MiscData:GetAttribute("PreviousLimb"))
                if limb then
                    restoreOriginalProperties(limb)
                end
            end
        end
    end
    getgenv().MainInfo = {}
    if detectInput then 
        getgenv().MainInfo["InputBegan"] = UserInputService.InputBegan:Connect(handleKeyPress)
    end
end

local function initiateProcess()
    terminateProcess()
    MiscData:SetAttribute("PreviousLimb", getgenv().Settings.TARGET_LIMB)
    getgenv().MainInfo["PlayerAdded"] = Players.PlayerAdded:Connect(onPlayerAdded)
    getgenv().MainInfo["PlayerRemoving"] = Players.PlayerRemoving:Connect(onPlayerRemoving)
    getgenv().MainInfo["InputBegan"] = UserInputService.InputBegan:Connect(handleKeyPress)
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            onPlayerAdded(player)
        end
    end
end

function handleKeyPress(input, isGameProcessed)
    if isGameProcessed then return end
    
    if input.KeyCode == getgenv().Settings.KEYCODE then
        local isProcessActive = MiscData:GetAttribute("IsProcessActive")
        MiscData:SetAttribute("IsProcessActive", not isProcessActive)
        if isProcessActive then
            initiateProcess()
        else
            terminateProcess(true)
        end
    end
end

if MiscData:GetAttribute("IsProcessActive") == nil then
    MiscData:SetAttribute("IsProcessActive", false)
end

if MiscData:GetAttribute("IsProcessActive") == false then
    initiateProcess()
else
    terminateProcess(true)
end
