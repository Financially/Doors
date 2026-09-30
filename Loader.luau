if getgenv().Abysall then
    local Existing = getgenv().Abysall
    if Existing.Interface and Existing.Interface.Library and Existing.Interface.Library.Unload then
        pcall(function()
            Existing.Interface.Library:Unload()
        end)
        task.wait()
    end
    getgenv().Abysall = nil
end
getgenv().Abysall = {
    Legit = true
}

local GameList = {
  [2440500124] = "Doors"
}

local BaseUrl = "https://raw.githubusercontent.com/Financially/Doors/refs/heads/main/"
local CacheVersion = "financially-auto-hotel-v7-research"
local function SourceUrl(Path)
    return BaseUrl .. Path .. "?v=" .. CacheVersion
end
getgenv().Abysall = {
    Environment = loadstring(game:HttpGet(SourceUrl("Components/Environment.luau")))(),
    ESPLibrary = loadstring(game:HttpGet(SourceUrl("Components/ESP.luau")))(),

    Legit = true, -- pog
}

local function CloneReference(Object)
    if Abysall and Abysall.Environment.cloneref then
        return Abysall.Environment.cloneref(Object)
    else
        return Object
    end
end

local Services = setmetatable({}, {
    __index = function(self, Name)
        return CloneReference(game:GetService(Name))
    end
})

if Abysall.Environment.writefile and Abysall.Environment.readfile then
    if not Abysall.Environment.isfile("Abysall/UserData.json") then
        local Data = {
            TotalExecutions = 0,
            UILibrary = "Obsidian"
        }
        Abysall.Environment.writefile("Abysall/UserData.json", Services.HttpService:JSONEncode(Data))
    end

    local UserData = Abysall.Environment.readfile("Abysall/UserData.json")
    local Decoded = Services.HttpService:JSONDecode(UserData)
    if not Decoded.TotalExecutions then
        Decoded.TotalExecutions = 0    
    end

    Decoded.TotalExecutions = Decoded.TotalExecutions + 1

    if not Decoded.UILibrary then
        Decoded.UILibrary = "Obsidian"
    end

    Abysall.TotalExecutions = Decoded.TotalExecutions
    Abysall.UILibrary = Decoded.UILibrary

    Abysall.Environment.writefile("Abysall/UserData.json", Services.HttpService:JSONEncode(Decoded))
end

Abysall.Interface = loadstring(game:HttpGet(SourceUrl("Components/Interface.luau")))()
Abysall.Analytics = loadstring(game:HttpGet(SourceUrl("Components/Analytics.luau")))()

local CurrentGame = GameList[game.GameId]
if CurrentGame then
    loadstring(game:HttpGet(SourceUrl("Games/" .. CurrentGame .. "/Loader.luau")))()
else
    loadstring(game:HttpGet(SourceUrl("Games/Universal/Loader.luau")))()
end
