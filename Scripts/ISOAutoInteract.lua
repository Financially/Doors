local environment = getgenv and getgenv() or _G

if environment.ISOAutoInteract and environment.ISOAutoInteract.Unload then
  environment.ISOAutoInteract:Unload()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local AutoInteract = {
  Enabled = true,
  ToggleKey = Enum.KeyCode.Q,
  Delay = 0.05,
  Range = 12,
  Instant = true,
  Categories = {
    Drawers = true,
    Chest = true,
    ["Locked Chest"] = true,
    Gold = true,
    Keys = true,
    ["Library Hints"] = true,
    Pickups = true,
    ["Doors / Locks"] = true,
    Objectives = true,
    ["Hiding Places"] = false,
    Other = false,
  },
}

local interactions = {}
local interactionSet = setmetatable({}, { __mode = "k" })
local categoryCache = setmetatable({}, { __mode = "k" })
local originalHoldDuration = setmetatable({}, { __mode = "k" })
local connections = {}
local elapsed = 0
local unloaded = false

local hidingNames = {
  Backdoor_Wardrobe = true,
  Bed = true,
  CircularVent = true,
  Double_Bed = true,
  Locker_Large = true,
  Locker_Small = true,
  Locker_Small_Locked = true,
  RetroWardrobe = true,
  Rooms_Locker = true,
  Rooms_Locker_Fridge = true,
  Toolshed = true,
  Wardrobe = true,
}

local objectiveNames = {
  LeverForGate = true,
  TimerLever = true,
  LeverForTimer = true,
  BackdoorLever = true,
  MinesAnchor = true,
  FuseObtain = true,
  MinesGenerator = true,
  MinesGateButton = true,
  LiveBreakerPolePickup = true,
  Generator = true,
  ElectricalRoom = true,
  WaterPump = true,
  VineGuillotine = true,
}

local pickupNames = {
  AlarmClock = true, Bandage = true, BandagePack = true, Battery = true,
  BatteryPack = true, Briefcase = true, Bulklight = true, Candle = true,
  Candy = true, CD1 = true, CompactDisc = true, Compass = true,
  Crucifix = true, CrucifixWall = true, ElectricalRoomKey = true,
  FihFood = true, Flashlight = true, Glowsticks = true, GoldGun = true,
  GreenHerb = true, GummyFlashlight = true, GweenSoda = true,
  HolyGrenade = true, HoneyPot = true, Journal = true, KeyIron = true,
  Lantern = true, LaserPointer = true, LibraryHintPaper = true,
  Lighter = true, Lockpick = true, LotusPetalPickup = true,
  LunchBox = true, MoonlightCandle = true, MoonlightFloat = true,
  Mug = true, Multitool = true, Note = true, NVCS3000 = true,
  PackOfGweenSoda = true, PaperCup = true, PaperPlane = true,
  Pizza = true, PocketMirror = true, PuzzlePainting = true,
  RoomKey = true, Shakelight = true, Shears = true, ShieldBig = true,
  ShieldMini = true, SkeletonKey = true, Smoothie = true,
  SolutionPaper = true, StarBottle = true, StardustPickup = true,
  StarJug = true, StarVial = true, Straplight = true, Vitamins = true,
  WaitingTicket = true,
}

local keyNames = {
  KeyObtain = true, ElectricalKeyObtain = true, ElectricalRoomKey = true,
  RoomKey = true, Key = true, KeyBackdoor = true, KeyElectrical = true,
  KeyIron = true, SkeletonKey = true,
}

local libraryHintNames = {
  HintBook = true, HintBooks = true, LiveHintBook = true, LibraryBook = true,
  HintPaper = true, LibraryHintPaper = true, LibraryHintPaperHard = true,
  SolutionPaper = true,
}

local function getCategory(prompt)
  local cached = categoryCache[prompt]
  if cached then return cached end

  if prompt.Name == "HidePrompt" or prompt.Name == "EnterPrompt"
    or prompt.Name == "NoHidingLilBro" then
    categoryCache[prompt] = "Hiding Places"
    return "Hiding Places"
  end

  local current = prompt
  local category

  for _ = 1, 8 do
    current = current.Parent
    if not current then break end

    local name = current.Name
    local lowerName = string.lower(name)

    if hidingNames[name] then
      category = "Hiding Places"
      break
    elseif name == "ChestBoxLocked" or name == "Chest_Vine"
      or name == "Toolbox_Locked" then
      category = "Locked Chest"
      break
    elseif name == "ChestBox" then
      category = "Chest"
      break
    elseif name == "GoldPile" then
      category = "Gold"
      break
    elseif name == "Drawer" or string.find(lowerName, "drawer", 1, true)
      or string.find(lowerName, "cabinet", 1, true)
      or string.find(lowerName, "desk", 1, true) then
      category = "Drawers"
      break
    elseif objectiveNames[name] then
      category = "Objectives"
      break
    elseif keyNames[name] then
      category = "Keys"
      break
    elseif libraryHintNames[name] then
      category = "Library Hints"
      break
    elseif pickupNames[name] or current:IsA("Tool") then
      category = "Pickups"
      break
    elseif name == "Padlock" or name == "Door" or name == "Lock"
      or string.find(lowerName, "doorlock", 1, true) then
      category = "Doors / Locks"
      break
    end
  end

  category = category or "Other"
  categoryCache[prompt] = category
  return category
end

local function isAllowed(prompt)
  return AutoInteract.Categories[getCategory(prompt)] == true
end

local function getTargetPart(prompt)
  local current = prompt and prompt.Parent

  for _ = 1, 6 do
    if not current then
      return nil
    elseif current:IsA("BasePart") then
      return current
    elseif current:IsA("Model") then
      local part = current.PrimaryPart
        or current:FindFirstChildWhichIsA("BasePart", true)

      if part then return part end
    end

    current = current.Parent
  end

  return nil
end

local function addPrompt(prompt)
  if not prompt
    or not prompt:IsA("ProximityPrompt")
    or interactionSet[prompt] then
    return
  end

  interactionSet[prompt] = true
  table.insert(interactions, prompt)

  if AutoInteract.Instant then
    originalHoldDuration[prompt] = prompt.HoldDuration
    prompt.HoldDuration = 0
  end
end

local function firePrompt(prompt)
  if fireproximityprompt then
    fireproximityprompt(prompt)
  else
    prompt:InputHoldBegin()
    task.wait(prompt.HoldDuration)
    prompt:InputHoldEnd()
  end
end

local function shouldSkip(prompt)
  if not isAllowed(prompt) then return true end

  local parent = prompt.Parent
  if not parent then return true end

  if parent.Name == "KeyObtainFake"
    or parent.Name == "Mandrake" then
    return true
  end

  if parent.Name == "GoldPile" then
    local gameData =
      game:GetService("ReplicatedStorage"):FindFirstChild("GameData")
    local floor = gameData and gameData:FindFirstChild("Floor")

    if floor and floor.Value == "Fools" then
      return true
    end
  end

  if prompt:GetAttribute("InfItems")
    and prompt.Name ~= "InfPrompt" then
    return true
  end

  return false
end

local function update(deltaTime)
  if unloaded or not AutoInteract.Enabled then return end

  elapsed = elapsed + (deltaTime or 0.016)
  if elapsed < AutoInteract.Delay then return end
  elapsed = 0

  local character = LocalPlayer.Character
  local root =
    character and character:FindFirstChild("HumanoidRootPart")

  if not root then return end

  for index = #interactions, 1, -1 do
    local prompt = interactions[index]

    if not prompt or not prompt.Parent then
      interactionSet[prompt] = nil
      table.remove(interactions, index)
    elseif prompt:GetAttribute("Interactions")
      and prompt:GetAttribute("Interactions") > 0 then
      interactionSet[prompt] = nil
      table.remove(interactions, index)
    elseif not shouldSkip(prompt) then
      local targetPart = getTargetPart(prompt)

      if targetPart
        and (root.Position - targetPart.Position).Magnitude
          <= AutoInteract.Range then
        if not prompt.Enabled then
          prompt.Enabled = true
        end

        task.spawn(firePrompt, prompt)
      end
    end
  end
end

function AutoInteract:SetEnabled(value)
  self.Enabled = value == true
end

function AutoInteract:Toggle()
  self:SetEnabled(not self.Enabled)
end

function AutoInteract:SetCategory(category, value)
  self.Categories[category] = value == true
end

function AutoInteract:Unload()
  if unloaded then return end

  unloaded = true
  self.Enabled = false

  for _, connection in ipairs(connections) do
    connection:Disconnect()
  end

  for prompt, duration in pairs(originalHoldDuration) do
    if prompt and prompt.Parent then
      prompt.HoldDuration = duration
    end
  end

  table.clear(connections)
  table.clear(interactions)
  table.clear(interactionSet)

  if environment.ISOAutoInteract == self then
    environment.ISOAutoInteract = nil
  end
end

for _, instance in ipairs(Workspace:GetDescendants()) do
  if instance:IsA("ProximityPrompt") then
    addPrompt(instance)
  end
end

table.insert(
  connections,
  Workspace.DescendantAdded:Connect(function(instance)
    if instance:IsA("ProximityPrompt") then
      addPrompt(instance)
    end
  end)
)

table.insert(
  connections,
  RunService.Heartbeat:Connect(update)
)

table.insert(
  connections,
  UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or UserInputService:GetFocusedTextBox() then
      return
    end

    if input.KeyCode == AutoInteract.ToggleKey then
      AutoInteract:Toggle()
    end
  end)
)

environment.ISOAutoInteract = AutoInteract
