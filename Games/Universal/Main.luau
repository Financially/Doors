local Services = setmetatable({}, {
    __index = function(self, Name)
        if Abysall.Environment.cloneref then
            return Abysall.Environment.cloneref(game:GetService(Name))
        else
            return game:GetService(Name)
        end
    end
})

local Bindable = Instance.new("BindableFunction")
Bindable.OnInvoke = function(Response)
    local Success, Result = pcall(function()
        toclipboard("https://github.com/Financially/Doors")
    end)
    if not Success then
        Services.LocalPlayer:Kick("Failed to copy project link.\nhttps://github.com/Financially/Doors")
    end
end

Services.StarterGui:SetCore("SendNotification", {
    Title = "ISO",
    Text = "Only DOORS is supported right now, sorry :)",
    Duration = 10,
    Button1 = "Copy Project Link",
    Callback = Bindable,
})
