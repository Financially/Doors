local BaseUrl = "https://raw.githubusercontent.com/Financially/Doors/refs/heads/main/"
local CacheVersion = "financially-auto-hotel-v1"
local function SourceUrl(Path)
    return BaseUrl .. Path .. "?v=" .. CacheVersion
end
if game.PlaceId ~= 6516141723 then
    loadstring(game:HttpGet(SourceUrl("Games/Doors/Main.luau")))()
else
    loadstring(game:HttpGet(SourceUrl("Games/Doors/Lobby.luau")))()
end
