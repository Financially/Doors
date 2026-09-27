local BaseUrl = "https://raw.githubusercontent.com/drawback/Doors/refs/heads/main/"
local CacheVersion = "56dabc890ece42313aff64ea993855bea8ef0551"
local function SourceUrl(Path)
    return BaseUrl .. Path .. "?v=" .. CacheVersion
end
if game.PlaceId ~= 6516141723 then
    loadstring(game:HttpGet(SourceUrl("Games/Doors/Main.luau")))()
else
    loadstring(game:HttpGet(SourceUrl("Games/Doors/Lobby.luau")))()
end
