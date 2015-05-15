PLUGIN.Title = "Private Messaging"
PLUGIN.Description = "Allows users to chat private with each other"
PLUGIN.Author = "#Domestos"
PLUGIN.Version = V(1, 2, 4)
PLUGIN.HasConfig = false
PLUGIN.ResourceID = 659


local pmHistory = {}
function PLUGIN:Init()
    command.AddChatCommand("pm", self.Object, "cmdPm")
    command.AddChatCommand("r", self.Object, "cmdReply")
end
-- --------------------------------
-- try to find a BasePlayer
-- returns (int) numFound, (table) playerTbl
-- --------------------------------
local function FindPlayer(NameOrIpOrSteamID, checkSleeper)
    local playerTbl = {}
    local enumPlayerList = global.BasePlayer.activePlayerList:GetEnumerator()
    while enumPlayerList:MoveNext() do
        local currPlayer = enumPlayerList.Current
        local currSteamID = rust.UserIDFromPlayer(currPlayer)
        local currIP = currPlayer.net.connection.ipaddress
        if currPlayer.displayName == NameOrIpOrSteamID or currSteamID == NameOrIpOrSteamID or currIP == NameOrIpOrSteamID then
            table.insert(playerTbl, currPlayer)
            return #playerTbl, playerTbl
        end
        local matched, _ = string.find(currPlayer.displayName:lower(), NameOrIpOrSteamID:lower(), 1, true)
        if matched then
            table.insert(playerTbl, currPlayer)
        end
    end
    if checkSleeper then
        local enumSleeperList = global.BasePlayer.sleepingPlayerList:GetEnumerator()
        while enumSleeperList:MoveNext() do
            local currPlayer = enumSleeperList.Current
            local currSteamID = rust.UserIDFromPlayer(currPlayer)
            if currPlayer.displayName == NameOrIpOrSteamID or currSteamID == NameOrIpOrSteamID then
                table.insert(playerTbl, currPlayer)
                return #playerTbl, playerTbl
            end
            local matched, _ = string.find(currPlayer.displayName:lower(), NameOrIpOrSteamID:lower(), 1, true)
            if matched then
                table.insert(playerTbl, currPlayer)
            end
        end
    end
    return #playerTbl, playerTbl
end
-- --------------------------------
-- Chat command for pm
-- --------------------------------
function PLUGIN:cmdPm(player, cmd, args)
    if not player then return end
    local args = self:ArgsToTable(args, "chat")
    local target, message = args[1], ""
    local i = 2
    while args[i] do
        message = message..args[i].." "
        i = i + 1
    end
    if not target or message == "" then
        -- no target or no message is given
        rust.SendChatMessage(player, "Syntax: /pm <name> <message>")
        return
    end
    local numFound, targetPlayerTbl = FindPlayer(target, false)
    if numFound == 0 then
        rust.SendChatMessage(player, "Player not found")
        return
    end
    if numFound > 1 then
        local targetNameString = ""
        for i = 1, numFound do
            targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
        end
        rust.SendChatMessage(player, "Found more than one player, be more specific:")
        rust.SendChatMessage(player, targetNameString)
        return
    end
    local targetPlayer = targetPlayerTbl[1]
    local senderName = player.displayName
    local senderSteamID = rust.UserIDFromPlayer(player)
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    rust.SendChatMessage(targetPlayer, "<color=#ff00ff>PM from "..senderName.."</color>", message, senderSteamID)
    rust.SendChatMessage(player, "<color=#ff00ff>PM to "..targetName.."</color>", message, senderSteamID)
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
    local message = ""
    local i = 1
    while args[i] do
        message = message..args[i].." "
        i = i + 1
    end
    if message == "" then
        -- no args given
        rust.SendChatMessage(player, "Syntax: /r <message> to reply to last pm")
        return
    end
    if pmHistory[senderSteamID] then
        local numFound, targetPlayerTbl = FindPlayer(pmHistory[senderSteamID], false)
        if numFound == 0 then
            rust.SendChatMessage(player, "Player not found")
            return
        end
        if numFound > 1 then
            local targetNameString = ""
            for i = 1, numFound do
                targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
            end
            rust.SendChatMessage(player, "Found more than one player, be more specific:")
            rust.SendChatMessage(player, targetNameString)
            return
        end
        local targetPlayer = targetPlayerTbl[1]
        local targetName = targetPlayer.displayName
        rust.SendChatMessage(targetPlayer, "<color=#ff00ff>PM from "..senderName.."</color>", message, senderSteamID)
        rust.SendChatMessage(player, "<color=#ff00ff>PM to "..targetName.."</color>", message, senderSteamID)
    else
        rust.SendChatMessage(player, "No PM found to reply to")
        return
    end
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
    rust.SendChatMessage(player, "use /pm <name> <message> to pm someone")
    rust.SendChatMessage(player, "use /r <message> to reply to the last pm")
end