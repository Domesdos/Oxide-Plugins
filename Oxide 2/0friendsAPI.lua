PLUGIN.Title        = "FriendsAPI"
PLUGIN.Description  = "An API to manage friends"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(1, 1, 0)
PLUGIN.HasConfig    = false
PLUGIN.ResourceID   = 686



function PLUGIN:Init()
    command.AddChatCommand("friend", self.Object, "cmdFriend")
    self:LoadDataFile()
end

local DataFile = "friends"
local Data = {}
function PLUGIN:LoadDataFile()
    local data = datafile.GetDataTable(DataFile)
    Data = data or {}
end

function PLUGIN:SaveDataFile()
    datafile.SaveDataTable(DataFile)
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

function PLUGIN:cmdFriend(player, cmd, args)
if not player then return end
    local args = self:ArgsToTable(args, "chat")
    local func, target = args[1], args[2]
    local playerSteamID = rust.UserIDFromPlayer(player)
    if not func or func ~= "add" and func ~= "remove" and func ~= "list" then
        self:ChatMessage(player, "Syntax: \"/friend <add/remove> <name>\" or \"/friend list\"")
        return
    end
    if func ~= "list" and not target then
        self:ChatMessage(player, "Syntax: \"/friend <add/remove> <name>\"")
        return
    end
    if func == "list" then
        local friendlist = self:GetFriendlist(playerSteamID)
        if friendlist then
            local i, playerCount = 1, 0
            local friendlistString = ""
            local friendlistTbl = {}
            -- build friendlist string
            for key, value in pairs(friendlist) do
                playerCount = playerCount + 1
                friendlistString = friendlistString..value..", "
                if playerCount == 8 then
                    friendlistTbl[i] = friendlistString
                    friendlistString = ""
                    i = i + 1
                end
            end
            -- remove comma at the end
            if string.sub(friendlistString, -2, -2) == "," then
                friendlistString = string.sub(friendlistString, 1, -3)
            end
            -- output friendlist
            if #friendlistTbl >= 1 then
                player:ChatMessage("Friends:")
                for i = 1, #friendlistTbl do
                    self:ChatMessage(player, friendlistTbl[i])
                end
                self:ChatMessage(player, friendlistString)
            else
                self:ChatMessage(player, "Friends: "..friendlistString)
            end
            return
        end
        self:ChatMessage(player, "You dont have friends :(")
        return
    end
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        self:ChatMessage(player, "Player not found")
        return
    end
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    if func == "add" then
        if player == targetPlayer then
            self:ChatMessage(player, "You cant add yourself")
            return
        end
        local added = self:addFriend(player, targetSteamID)
        if not added then
            self:ChatMessage(player, targetName.." is already your friend")
        else
            self:ChatMessage(player, targetName.." is now your friend")
        end
        return
    end
    if func == "remove" then
        local removed = self:removeFriend(playerSteamID, targetSteamID)
        if not removed then
            self:ChatMessage(player, "You already dont have "..targetName.." on your friendlist")
        else
            self:ChatMessage(player, targetName.." was removed from your friendlist")
        end
    end
end

-- --------------------------------
-- returns true if player was removed
-- returns false if not (not on friendlist)
-- --------------------------------
function PLUGIN:removeFriend(playerSteamID, targetSteamID)
    local playerData = self:GetPlayerData(playerSteamID)
    if not playerData then return false end
    for key, value in pairs(playerData.Friends) do
        if value == targetSteamID then
            table.remove(playerData.Friends, key)
            if #playerData.Friends == 0 then
                Data[playerSteamID] = nil
            end
            self:SaveDataFile()
            return true
        end
    end
    return false
end

-- --------------------------------
-- returns true if friend was added
-- returns false if not (is already on friendlist, wants to add himself)
-- --------------------------------
function PLUGIN:addFriend(player, targetSteamID)
    local playerSteamID = rust.UserIDFromPlayer(player)
    local playerName = player.displayName
    --if playerSteamID == targetSteamID then return false end
    local playerData = self:GetPlayerData(playerSteamID, playerName, true)
    for key, value in pairs(playerData.Friends) do
        if value == targetSteamID then
            return false
        end
    end
    table.insert(playerData.Friends, targetSteamID)
    self:SaveDataFile()
    return true
end

-- --------------------------------
-- returns true when player has target on friendlist
-- returns false if not
-- --------------------------------
function PLUGIN:HasFriend(playerSteamID, targetSteamID)
    local playerData = self:GetPlayerData(playerSteamID)
    if not playerData then return false end
    for key, value in pairs(playerData.Friends) do
        if value == targetSteamID then
            return true
        end
    end
    return false
end

-- --------------------------------
-- returns true when player is on targets friendlist
-- returns false if hes not
-- --------------------------------
function PLUGIN:IsFriendFrom(playerSteamID, targetSteamID)
    local playerData = self:GetPlayerData(targetSteamID)
    if not playerData then return false end
    for key, value in pairs(playerData.Friends) do
        if value == playerSteamID then
            return true
        end
    end
    return false
end

-- --------------------------------
-- returns true when player and target are friends
-- returns false when they are not
-- --------------------------------
function PLUGIN:areFriends(playerSteamID, targetSteamID)
    local hasFriend = self:HasFriend(playerSteamID, targetSteamID)
    local isFriend = self:IsFriendFrom(playerSteamID, targetSteamID)
    if hasFriend and isFriend then
        return true
    end
    return false
end

-- --------------------------------
-- returns a players friendlist as table
-- if known, the table will return the names, if not it returns steamID
-- returns false if player has no friends
-- --------------------------------
function PLUGIN:GetFriendlist(playerSteamID)
    local playerData = self:GetPlayerData(playerSteamID)
    if not playerData then return false end
    local friends = playerData.Friends
    for key, value in pairs(friends) do
        local name = self:GetPlayerName(value)
        if name then
            friends[key] = name
        end
    end
    return friends
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

-- --------------------------------
-- returns table with player data
-- --------------------------------
function PLUGIN:GetPlayerData(playerSteamID, playerName, addNewEntry)
    local playerData = Data[playerSteamID]
    if not playerData and addNewEntry then
        playerData = {}
        playerData.SteamID = playerSteamID
        playerData.Name = playerName
        playerData.Friends = {}
        Data[playerSteamID] = playerData
        self:SaveDataFile()
    end
    return playerData
end

-- --------------------------------
-- tries to find a name for a steamID
-- --------------------------------
function PLUGIN:GetPlayerName(steamID)
    if Data[steamID] then
        return Data[steamID].Name
    end
    local player = global.BasePlayer.Find(steamID)
    if player then
        return player.displayName
    end
    return false
end

function PLUGIN:SendHelpText(player)
    self:ChatMessage(player, "use \"/friend <add|remove|list> <name>\" to add/remove/list friends")
end