PLUGIN.Title = "Private Messaging"
PLUGIN.Description = "Allows users to chat private with each other"
PLUGIN.Author = "#Domestos"
PLUGIN.Version = V(1, 2, 0)
PLUGIN.HasConfig = false
PLUGIN.ResourceID = 659


local pmHistory = {}
function PLUGIN:Init()
    command.AddChatCommand("pm", self.Object, "cmdPm")
    command.AddChatCommand("r", self.Object, "cmdReply")
end

-- --------------------------------
-- Chat command for pm
-- --------------------------------
function PLUGIN:cmdPm(player, cmd, args)
    if not player then return end
    local args = self:ArgsToTable(args, "chat")
    local target, message, argsOverhead = args[1], args[2], args[3]
    if not args or not message then
        -- no args or no message is given
        rust.SendChatMessage(player, "Syntax: \"/pm <name> <message>\"")
        return
    end
    if argsOverhead then
        -- too many args, probably message without brackets
        rust.SendChatMessage(player, "You need to use brackets to wrap your message - \"message\"")
        return
    end
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        rust.SendChatMessage(player, "Player not found")
        return
    end
    local senderName = player.displayName
    local senderSteamID = rust.UserIDFromPlayer(player)
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    rust.SendChatMessage(targetPlayer, "PM from "..senderName, message)
    rust.SendChatMessage(player, "PM to "..targetName, message)
    pmHistory[targetSteamID] = senderSteamID
end
-- --------------------------------
-- Chat command for reply
-- --------------------------------
function PLUGIN:cmdReply(player, cmd, args)
    if not player then return end
    local senderName = player.displayName
    local senderSteamID = rust.UserIDFromPlayer(player)
    local args = self:ArgsToTable(args, "chat")
    local target, message, argsOverhead = args[1], args[2], args[3]
    if not args then
        -- no args given
        rust.SendChatMessage(player, "Syntax: \"/r <name> <message>\" or \"/r <message> to reply to last pm\"")
        return
    end
    if argsOverhead then
        -- too many args, probably message without brackets
        rust.SendChatMessage(player, "You need to use brackets to wrap your message - \"message\"")
        return
    end
    if not message then
        -- message is first arg, no target given - reply to last pm recieved
        local message = target
        if pmHistory[senderSteamID] then
            local targetPlayer = global.BasePlayer.Find(pmHistory[senderSteamID])
            if not targetPlayer then
                rust.SendChatMessage(player, "Player is offline")
                return
            end
            local targetName = targetPlayer.displayName
            rust.SendChatMessage(targetPlayer, "PM from "..senderName, message)
            rust.SendChatMessage(player, "PM to "..targetName, message)
        else
            rust.SendChatMessage(player, "Syntax: \"/r <name> <message>\" or \"/r <message> to reply to last pm\"")
            return
        end
        return
    end
    -- name and message is given
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        rust.SendChatMessage(player, "Player not found")
        return
    end
    local targetName = targetPlayer.displayName
    rust.SendChatMessage(targetPlayer, "PM from "..senderName, message)
    rust.SendChatMessage(player, "PM to "..targetName, message)
end
-- --------------------------------
-- returns args as a table
-- --------------------------------
function PLUGIN:ArgsToTable(args, src)
    local argsTbl = {}
    if src == "chat" then
        local length = args.Length
        for i = 0, length - 1, 1 do
            argsTbl[i + 1] = args[i]
        end
        return argsTbl
    end
    if src == "console" then
        local i = 1
        while args:HasArgs(i) do
            argsTbl[i] = args:GetString(i - 1)
            i = i + 1
        end
        return argsTbl
    end
    return argsTbl
end

function PLUGIN:OnPlayerDisconnected(player)
    local steamID = rust.UserIDFromPlayer(player)
    if pmHistory[steamID] then
        pmHistory[steamID] = nil
    end
end

function PLUGIN:SendHelpText(player)
    rust.SendChatMessage(player, "use \"/pm <name> <message>\" to pm someone")
    rust.SendChatMessage(player, "use \"/r <name (optional)> <message>\" to reply to a pm")
end