PLUGIN.Name = "playerlocation"
PLUGIN.Title = "Player location"
PLUGIN.Description = "Allows users to see their current location"
PLUGIN.Author = "#Domestos"
PLUGIN.Version = V(1, 1, 0)
PLUGIN.HasConfig = false
PLUGIN.ResourceID = 663

function PLUGIN:Init()
    command.AddChatCommand("location", self.Object, "cmdLocation")
    command.AddChatCommand("loc", self.Object, "cmdLocation")
end

local function QuoteSafe(string)
    return UnityEngine.StringExtensions.QuoteSafe(string)
end

function PLUGIN:ChatMessage(targetPlayer, chatName, msg)
    if msg then
        targetPlayer:SendConsoleCommand("chat.add "..QuoteSafe(chatName).." "..QuoteSafe(msg))
    else
        msg = chatName
        targetPlayer:SendConsoleCommand("chat.add SERVER "..QuoteSafe(msg))
    end
end

function PLUGIN:cmdLocation(player, cmd, args)
    if (not player) then return end
    local x = string.format("%.0f", player.transform.position.x)
    local y = string.format("%.0f", player.transform.position.y)
    local z = string.format("%.0f", player.transform.position.z)
    self:ChatMessage(player, "Current location: x: "..x.." y: "..y.." z: "..z)
end

function PLUGIN:SendHelpText(player)
    self:ChatMessage(player, "use \"/location\" or \"/loc\" to see your current location")
end

-- Yep, thats all