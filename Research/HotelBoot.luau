local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer
local BOOT = "DoorsResearch/HotelBoot.luau"
local COUNT = "DoorsResearch/run_count.txt"
local HOTEL = 6839171747
local LOBBY = 6516141723
local LIMIT = 20

if queue_on_teleport then
	queue_on_teleport('task.wait(5); loadstring(readfile("' .. BOOT .. '"))()')
end

local function count()
	if not isfile(COUNT) then return 0 end
	return tonumber(readfile(COUNT)) or 0
end

if game.PlaceId == LOBBY then
	if count() >= LIMIT then return end
	task.wait(5)
	ReplicatedStorage:WaitForChild("RemotesFolder"):WaitForChild("CreateElevator"):FireServer({
		FriendsOnly=true, MaxPlayers=1, Mods={}, Destination="Hotel", Settings={}
	})
	return
end

if game.PlaceId ~= HOTEL or getgenv().DoorsResearchOrchestrator then return end
getgenv().DoorsResearchOrchestrator = true
local Run = count() + 1
writefile(COUNT, tostring(Run))

task.spawn(function()
	pcall(function() loadstring(readfile("DoorsResearch/HotelCollector.luau"))() end)
	task.wait(1)
	pcall(function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Financially/Doors/main/Loader.luau?research-run=" .. Run))()
	end)
	task.wait(1)
	local Environment = getgenv()
	local Library = Environment.Library or (Environment.Abysall and Environment.Abysall.Interface and Environment.Abysall.Interface.Library)
	local Toggle = Library and Library.Toggles and Library.Toggles.HotelAutoRun
	if Toggle then Toggle:SetValue(true) end
end)

task.spawn(function()
	local Data = ReplicatedStorage:WaitForChild("GameData")
	local Latest = Data:WaitForChild("LatestRoom")
	local LastRoom, ChangedAt = Latest.Value, tick()
	while task.wait(2) do
		local Character = Player.Character
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		if Latest.Value ~= LastRoom then LastRoom, ChangedAt = Latest.Value, tick() end
		local Finished = Latest.Value >= 100
		local Dead = Humanoid and Humanoid.Health <= 0
		local Stalled = tick() - ChangedAt > 180
		if Finished or Dead or Stalled then
			pcall(function()
				appendfile("DoorsResearch/events.jsonl", game:GetService("HttpService"):JSONEncode({
					type="cycle_end", run=Run, room=Latest.Value,
					reason=Finished and "complete" or Dead and "dead" or "stalled", at=os.time()
				}) .. "\n")
			end)
			task.wait(2)
			ReplicatedStorage.RemotesFolder.Lobby:FireServer()
			return
		end
	end
end)
