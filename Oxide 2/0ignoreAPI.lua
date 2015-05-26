PLUGIN.Title        = "Ignore List API"
PLUGIN.Description  = "An API to manage an ignore list"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(1, 0, 0)
PLUGIN.ResourceId   = _

local debugMode = false

function PLUGIN:Init()
    command.AddChatCommand("ignore", self.Object, "cmdIgnore")
    command.AddConsoleCommand("ignoreapi.debug", self.Object, "ccmdDebug")
    self:LoadDefaultConfig()
    self:LoadDataFile()
end

function PLUGIN:LoadDefaultConfig()
    self.Config.Settings                        = self.Config.Settings or {}
    self.Config.Settings.IgnoreLimit            = self.Config.Settings.IgnoreLimit or 30

    self.Config.Messages                        = self.Config.Messages or {}
    self.Config.Messages.List                   = self.Config.Messages.List or "Ignored {count}: "
    self.Config.Messages.IgnorelistEmpty        = self.Config.Messages.IgnorelistEmpty or "Your ignore list is empty"
    self.Config.Messages.NotOnIgnorelist        = self.Config.Messages.NotOnIgnorelist or "{target} not found on your ignorelist"
    self.Config.Messages.IgnoreRemoved          = self.Config.Messages.IgnoreRemoved or "{target} was removed from your ignorelist"
    self.Config.Messages.PlayerNotFound         = self.Config.Messages.PlayerNotFound or "Player not found"
    self.Config.Messages.CantAddSelf            = self.Config.Messages.CantAddSelf or "You cant ignore yourself"
    self.Config.Messages.AlreadyOnList          = self.Config.Messages.AlreadyOnList or "{target} is already ignored"
    self.Config.Messages.IgnoreAdded            = self.Config.Messages.IgnoreAdded or "{target} is now ignored"
    self.Config.Messages.IgnorelistFull         = self.Config.Messages.IgnorelistFull or "Your ignorelist is full"
    self.Config.Messages.HelpText               = self.Config.Messages.HelpText or "use /ignore <add|remove|list> <name/steamID> to add/remove/list ignores"
end
-- --------------------------------
-- datafile handling
-- --------------------------------
local DataFile = "ignorelist"
local Data = {}
function PLUGIN:LoadDataFile()
    local data = datafile.GetDataTable(DataFile)
    Data = data or {}
end
function PLUGIN:SaveDataFile()
    datafile.SaveDataTable(DataFile)
end
-- --------------------------------
-- prints to server console
-- --------------------------------
local function printToConsole(msg)
    global.ServerConsole.PrintColoured(System.ConsoleColor.Cyan, msg)
end
-- --------------------------------
-- debug print
-- --------------------------------
local function debug(msg)
    if not debugMode then return end
    global.ServerConsole.PrintColoured(System.ConsoleColor.Yellow, msg)
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
-- builds output messages by replacing wildcards
-- --------------------------------
local function buildOutput(str, tags, replacements)
    for i = 1, #tags do
        str = str:gsub(tags[i], replacements[i])
    end
    return str
end
-- --------------------------------
-- handles chat command /ignore
-- --------------------------------
function PLUGIN:cmdIgnore(player, _, args)
    debug("## [IgnoreAPI debug] cmdIgnore() ##")
    if not player then return end
    local args = self:ArgsToTable(args, "chat")
    local func, target = args[1], args[2]
    local playerSteamID = rust.UserIDFromPlayer(player)
    debug("func: "..tostring(func))
    debug("target: "..tostring(target))
    if not func or func ~= "add" and func ~= "remove" and func ~= "list" then
        rust.SendChatMessage(player, "Syntax: /ignore <add/remove> <name/steamID> or /ignore list")
        return
    end
    if func ~= "list" and not target then
        rust.SendChatMessage(player, "Syntax: /ignore <add/remove> <name/steamID>")
        return
    end
    if func == "list" then
        local ignorelist = self:GetIgnorelist(playerSteamID)
        if ignorelist then
            local i, playerCount = 1, 0
            local ignorelistString = ""
            local ignorelistTbl = {}
            -- build ignorelist string
            for _, value in pairs(ignorelist) do
                playerCount = playerCount + 1
                ignorelistString = ignorelistString..value..", "
                if playerCount == 8 then
                    ignorelistTbl[i] = ignorelistString
                    ignorelistString = ""
                    playerCount = 0
                    i = i + 1
                end
            end
            -- remove comma at the end
            if ignorelistString:sub(-2, -2) == "," then
                ignorelistString = ignorelistString:sub(1, -3)
            end
            debug("ignorelistString: "..ignorelistString)
            -- output ignorelist
            if #ignorelistTbl >= 1 then
                rust.SendChatMessage(player, buildOutput(self.Config.Messages.List, {"{count}"}, {"["..tostring(#ignorelist).."/"..tostring(self.Config.Settings.IgnoreLimit).."]"}))
                for i = 1, #ignorelistTbl do
                    rust.SendChatMessage(player, ignorelistTbl[i])
                end
                rust.SendChatMessage(player, ignorelistString)
            else
                rust.SendChatMessage(player, buildOutput(self.Config.Messages.List, {"{count}"}, {"["..tostring(#ignorelist).."/"..tostring(self.Config.Settings.IgnoreLimit).."]"})..ignorelistString)
            end
            return
        end
        debug("ignorelist empty")
        rust.SendChatMessage(player, self.Config.Messages.IgnorelistEmpty)
        return
    end
    local numFound, targetPlayerTbl = FindPlayer(target, true)
    debug("numFound: "..tostring(numFound))
    if numFound == 0 then
        rust.SendChatMessage(player, self.Config.Messages.PlayerNotFound)
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
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    debug("targetName: "..targetName)
    debug("targetSteamID "..targetSteamID)
    if func == "remove" then
        local removed = self:removeIgnore(playerSteamID, targetSteamID)
        debug("removed: "..tostring(removed))
        if not removed then
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.NotOnIgnorelist, {"{target}"}, {targetName}))
        else
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.IgnoreRemoved, {"{target}"}, {targetName}))
        end
        return
    end
    if func == "add" then
        if player == targetPlayer then
            rust.SendChatMessage(player, self.Config.Messages.CantAddSelf)
            return
        end
        local added = self:addIgnore(player, targetSteamID, targetName)
        debug("added: "..tostring(added))
        if added == "max" then
            rust.SendChatMessage(player, self.Config.Messages.IgnorelistFull)
            return
        end
        if not added then
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.AlreadyOnList, {"{target}"}, {targetName}))
        else
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.IgnoreAdded, {"{target}"}, {targetName}))
        end
        return
    end

end
-- --------------------------------
-- returns true if player was removed
-- returns false if not (not on ignorelist)
-- --------------------------------
function PLUGIN:removeIgnore(playerSteamID, target)
    local playerData = self:GetPlayerData(playerSteamID)
    if not playerData then return false end
    for key, _ in pairs(playerData.Ignores) do
        if playerData.Ignores[key].steamID == target or playerData.Ignores[key].name == target then
            table.remove(playerData.Ignores, key)
            if #playerData.Ignores == 0 then
                Data[playerSteamID] = nil
            end
            self:SaveDataFile()
            return true
        end
    end
    return false
end
-- --------------------------------
-- returns true if ignore was added
-- returns false if not (is already on ignorelist)
-- --------------------------------
function PLUGIN:addIgnore(player, targetSteamID, targetName)
    local playerSteamID = rust.UserIDFromPlayer(player)
    local playerName = player.displayName
    local playerData = self:GetPlayerData(playerSteamID, playerName, true)
    if #playerData.Ignores >= self.Config.Settings.IgnoreLimit then
        return "max"
    end
    for key, _ in pairs(playerData.Ignores) do
        if playerData.Ignores[key].steamID == targetSteamID then
            return false
        end
    end
    local newIgnore = {["name"] = targetName, ["steamID"] = targetSteamID}
    table.insert(playerData.Ignores, newIgnore)
    self:SaveDataFile()
    return true
end
-- --------------------------------
-- returns true when player has target on ignorelist
-- returns false if not
-- --------------------------------
function PLUGIN:HasIgnored(playerSteamID, target)
    local playerData = self:GetPlayerData(playerSteamID)
    if not playerData then return false end
    for key, _ in pairs(playerData.Ignores) do
        if playerData.Ignores[key].steamID == target or playerData.Ignores[key].name == target then
            return true
        end
    end
    return false
end
-- --------------------------------
-- returns true when player is on targets ignorelist
-- returns false if hes not
-- --------------------------------
function PLUGIN:IsIgnoredBy(player, targetSteamID)
    local playerData = self:GetPlayerData(targetSteamID)
    if not playerData then return false end
    for key, _ in pairs(playerData.Ignores) do
        if playerData.Ignores[key].steamID == player or playerData.Ignores[key].name == player then
            return true
        end
    end
    return false
end
-- --------------------------------
-- returns true when player and target are ignoring each other
-- returns false when they are not
-- --------------------------------
function PLUGIN:areIgnored(playerSteamID, targetSteamID)
    local hasIgnored = self:HasIgnored(playerSteamID, targetSteamID)
    local isIgnoredBy = self:IsIgnoredBy(playerSteamID, targetSteamID)
    if hasIgnored and isIgnoredBy then
        return true
    end
    return false
end
-- --------------------------------
-- returns a players ignorelist as table
-- if known, the table will return the names, if not it returns steamID
-- returns false if player's ignorelist is empty
-- --------------------------------
function PLUGIN:GetIgnorelist(playerSteamID)
    local playerData = self:GetPlayerData(playerSteamID)
    if not playerData then return false end
    local ignores = {}
    for key, _ in pairs(playerData.Ignores) do
        ignores[key] = playerData.Ignores[key].name
    end
    return ignores
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
        playerData.Ignores = {}
        Data[playerSteamID] = playerData
        self:SaveDataFile()
    end
    return playerData
end
-- --------------------------------
-- sends the helptext
-- --------------------------------
function PLUGIN:SendHelpText(player)
    rust.SendChatMessage(player, self.Config.Messages.HelpText)
end
-- --------------------------------
-- activate/deactivate debug mode
-- --------------------------------
function PLUGIN:ccmdDebug(arg)
    if arg.connection then return end -- terminate if not server console
    local args = self:ArgsToTable(arg, "console")
    if args[1] == "true" then
        debugMode = true
        printToConsole("[IgnoreAPI]: debug mode activated")
    elseif args[1] == "false" then
        debugMode = false
        printToConsole("[IgnoreAPI]: debug mode deactivated")
    else
        printToConsole("Syntax: ignoreapi.debug true/false")
    end
end