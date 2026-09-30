local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ROOT = "DoorsResearch"
local SESSION = ROOT .. "/sessions.jsonl"
local ROOMS = ROOT .. "/rooms.jsonl"
local EVENTS = ROOT .. "/events.jsonl"
local SOURCE = ROOT .. "/HotelCollector.luau"
if makefolder then pcall(makefolder, ROOT) end

local function round(Number, Places)
	local Scale = 10 ^ (Places or 2)
	return math.round(Number * Scale) / Scale
end

local function vec(Vector)
	return {round(Vector.X), round(Vector.Y), round(Vector.Z)}
end

local function append(Path, Data)
	pcall(appendfile, Path, HttpService:JSONEncode(Data) .. "\n")
end

local GameData = ReplicatedStorage:WaitForChild("GameData")
local LatestRoom = GameData:WaitForChild("LatestRoom")
local FloorValue = GameData:WaitForChild("Floor")
local CurrentRooms = Workspace:WaitForChild("CurrentRooms")
local Player = Players.LocalPlayer
local runId = HttpService:GenerateGUID(false)
local seen = {}
local lastPosition
local lastMovedAt = tick()
local lastRoom = -1
local hiding

local function localPosition(Entrance, Position)
	return vec(Entrance.CFrame:PointToObjectSpace(Position))
end

local function roomSignature(Room, Entrance, Exit)
	local Attribute = Room:GetAttribute("OriginalName") or Room:GetAttribute("RoomName")
		or Room:GetAttribute("Template") or Room:GetAttribute("Type")
	if Attribute then return tostring(Attribute) end
	local Delta = Entrance.CFrame:PointToObjectSpace(Exit.Position)
	local Counts = {parts=0, prompts=0, crouch=0, stairs=0}
	for _, Object in Room:GetDescendants() do
		if Object:IsA("BasePart") and Object.CanCollide then Counts.parts += 1 end
		if Object:IsA("ProximityPrompt") then Counts.prompts += 1 end
		local Name = string.lower(Object.Name)
		if string.find(Name, "crouch", 1, true) or string.find(Name, "duck", 1, true) then Counts.crouch += 1 end
		if string.find(Name, "stair", 1, true) then Counts.stairs += 1 end
	end
	return string.format("d%.0f_%.0f_%.0f-p%d-r%d-c%d-s%d", Delta.X, Delta.Y, Delta.Z,
		Counts.parts, Counts.prompts, Counts.crouch, Counts.stairs)
end

local function snapshot(Room)
	if FloorValue.Value ~= "Hotel" then return end
	if not Room or seen[Room] then return end
	local Entrance = Room:FindFirstChild("RoomEntrance")
	local Exit = Room:FindFirstChild("RoomExit")
	if not Entrance or not Exit or not Entrance:IsA("BasePart") or not Exit:IsA("BasePart") then return end
	seen[Room] = true
	local Data = {
		type="room", run=runId, at=os.time(), number=tonumber(Room.Name),
		signature=roomSignature(Room, Entrance, Exit), exit=localPosition(Entrance, Exit.Position),
		attributes=Room:GetAttributes(), prompts={}, landmarks={}, blockers={}
	}
	for _, Object in Room:GetDescendants() do
		if Object:IsA("ProximityPrompt") and Object.Parent then
			local Parent = Object.Parent:IsA("Attachment") and Object.Parent.Parent or Object.Parent
			local Position = Parent:IsA("BasePart") and Parent.Position
				or Parent:IsA("Model") and Parent:GetPivot().Position
			if Position then
				table.insert(Data.prompts, {name=Object.Name, parent=Parent.Name,
					pos=localPosition(Entrance, Position), distance=Object.MaxActivationDistance,
					action=Object.ActionText, attributes=Object:GetAttributes()})
			end
		elseif Object:IsA("BasePart") then
			local Name = string.lower(Object.Name)
			local Important = Object.Name == "CrouchPart" or Object.Name == "TriggerEventCollision"
				or Object.Name == "RoomEntrance" or Object.Name == "RoomExit"
				or string.find(Name, "stair", 1, true) or string.find(Name, "gate", 1, true)
				or string.find(Name, "lever", 1, true) or string.find(Name, "collision", 1, true)
			if Important then
				table.insert(Data.landmarks, {name=Object.Name, parent=Object.Parent and Object.Parent.Name,
					pos=localPosition(Entrance, Object.Position), size=vec(Object.Size), collide=Object.CanCollide})
			elseif Object.CanCollide and Object.Size.Magnitude > 9 then
				table.insert(Data.blockers, {name=Object.Name, parent=Object.Parent and Object.Parent.Name,
					pos=localPosition(Entrance, Object.Position), size=vec(Object.Size)})
			end
		end
	end
	append(ROOMS, Data)
end

append(SESSION, {type="start", run=runId, at=os.time(), job=game.JobId, version=game.PlaceVersion, floor=FloorValue.Value})
for _, Room in CurrentRooms:GetChildren() do task.defer(snapshot, Room) end
local connections = {}
table.insert(connections, CurrentRooms.ChildAdded:Connect(function(Room) task.wait(0.5) snapshot(Room) end))
table.insert(connections, Workspace.ChildAdded:Connect(function(Object)
	if Object:IsA("Model") and (string.find(Object.Name, "Rush") or string.find(Object.Name, "Ambush")
		or Object.Name == "A60" or Object.Name == "A120" or Object.Name == "SallyMoving") then
		append(EVENTS, {type="entity_spawn", run=runId, t=tick(), room=LatestRoom.Value, name=Object.Name})
	end
end))

task.spawn(function()
	while task.wait(0.2) do
		if FloorValue.Value ~= "Hotel" then continue end
		local Character = Player.Character
		local Root = Character and Character:FindFirstChild("HumanoidRootPart")
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		if Root and Humanoid then
			local Room = LatestRoom.Value
			local NowHiding = Character:GetAttribute("Hiding") == true
			if NowHiding ~= hiding then
				hiding = NowHiding
				append(EVENTS, {type="hiding", run=runId, t=tick(), room=Room, value=NowHiding, pos=vec(Root.Position)})
			end
			if not lastPosition or (Root.Position-lastPosition).Magnitude > 0.6 then
				lastPosition, lastMovedAt = Root.Position, tick()
			elseif Humanoid.MoveDirection.Magnitude > 0.2 and tick()-lastMovedAt > 2 then
				append(EVENTS, {type="stuck", run=runId, t=tick(), room=Room, pos=vec(Root.Position),
					move=vec(Humanoid.MoveDirection), crouching=Character:GetAttribute("Crouching")})
				lastMovedAt = tick()
			end
			if Room ~= lastRoom then
				append(EVENTS, {type="room_enter", run=runId, t=tick(), room=Room, pos=vec(Root.Position), health=Humanoid.Health})
				lastRoom = Room
			end
			if Humanoid.Health <= 0 then
				append(EVENTS, {type="death", run=runId, t=tick(), room=Room, pos=vec(Root.Position)})
				break
			end
		end
	end
end)

if queue_on_teleport and isfile and isfile(SOURCE) then
	queue_on_teleport('task.wait(3); loadstring(readfile("' .. SOURCE .. '"))()')
end

getgenv().DoorsResearchStop = function()
	for _, Connection in connections do Connection:Disconnect() end
	append(SESSION, {type="stop", run=runId, at=os.time(), room=LatestRoom.Value})
end
