PLUGIN.Title = "Private Messaging"
PLUGIN.Description = "Allows users to chat private with each other"
PLUGIN.Author = "#Domestos"
PLUGIN.Version = V(1, 1, 0)
PLUGIN.HasConfig = false
PLUGIN.ResourceID = 659

local pmHistory = {}

function PLUGIN:Init()
    command.AddChatCommand("pm", self.Object, "cmdPm")
    command.AddChatCommand("r", self.Object, "cmdReply")
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
-- --------------------------------
-- Chat command for pm
-- --------------------------------
function PLUGIN:cmdPm(player, cmd, args)
    if not player then return end
    local args = self:ArgsToTable(args, "chat")
    local target, message, argsOverhead = args[1], args[2], args[3]
    if not args or not message then
        -- no args or no message is given
        self:ChatMessage(player, "Syntax: \"/pm <name> <message>\"")
        return
    end
    if argsOverhead then
        -- too many args, probably message without brackets
        self:ChatMessage(player, "You need to use brackets to wrap your message - \"message\"")
        return
    end
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        self:ChatMessage(player, "Player not found")
        return
    end
    local senderName = player.displayName
    local senderSteamID = rust.UserIDFromPlayer(player)
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    targetPlayer:SendConsoleCommand("chat.add \"PM from "..senderName.."\" \""..message.."\"")
    player:SendConsoleCommand("chat.add \"PM to "..targetName.."\" \""..message.."\"")
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
        self:ChatMessage(player, "Syntax: \"/r <name> <message>\" or \"/r <message> to reply to last pm\"")
        return
    end
    if argsOverhead then
        -- too many args, probably message without brackets
        self:ChatMessage(player, "You need to use brackets to wrap your message - \"message\"")
        return
    end
    if not message then
        -- message is first arg, no target given - reply to last pm recievedl
        local message = target
        if pmHistory[senderSteamID] then
            local targetPlayer = global.BasePlayer.Find(pmHistory[senderSteamID])
            if not targetPlayer then
                self:ChatMessage(player, "Player is offline")
                return
            end
            local targetName = targetPlayer.displayName
            targetPlayer:SendConsoleCommand("chat.add \"PM from "..senderName.."\" \""..message.."\"")
            player:SendConsoleCommand("chat.add \"PM to "..targetName.."\" \""..message.."\"")
        else
            self:ChatMessage(player, "Syntax: \"/r <name> <message>\" or \"/r <message> to reply to last pm\"")
            return
        end
        return
    end
    -- name and message is given
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        self:ChatMessage(player, "Player not found")
        return
    end
    local targetName = targetPlayer.displayName
    targetPlayer:SendConsoleCommand("chat.add \"PM from "..senderName.."\" \""..message.."\"")
    player:SendConsoleCommand("chat.add \"PM to "..targetName.."\" \""..message.."\"")
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
    self:ChatMessage(player, "use \"/pm <name> <message>\" to pm someone")
    self:ChatMessage(player, "use \"/r <name (optional)> <message>\" to reply to a pm")
end