PLUGIN.Title        = "ChatMute"
PLUGIN.Description  = "Helps moderating chat by muting players"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(1, 0, 0)
PLUGIN.ResourceId   = _

local debugMode = false

function PLUGIN:Init()
    self:LoadDefaultConfig()
    self:LoadCommands()
    self:LoadDataFiles()
    self:RegisterPermissions()
end
-- --------------------------------
-- generates default config
-- --------------------------------
function PLUGIN:LoadDefaultConfig()
    self.Config.Settings                                = self.Config.Settings or {}
    -- General Settings
    self.Config.Settings.General                        = self.Config.Settings.General or {}
    self.Config.Settings.General.BroadcastMutes         = self.Config.Settings.General.BroadcastMutes or "true"
    self.Config.Settings.General.LogToConsole           = self.Config.Settings.General.LogToConsole or "true"
    -- Chat commands
    self.Config.Settings.ChatCommands                   = self.Config.Settings.ChatCommands or {}
    self.Config.Settings.ChatCommands.Mute              = self.Config.Settings.ChatCommands.Mute or {"mute"}
    self.Config.Settings.ChatCommands.Unmute            = self.Config.Settings.ChatCommands.Unmute or {"unmute"}
    self.Config.Settings.ChatCommands.GlobalMute        = self.Config.Settings.ChatCommands.GlobalMute or {"globalmute"}
    -- command permissions
    self.Config.Settings.Permissions                    = self.Config.Settings.Permissions or {}
    self.Config.Settings.Permissions.Mute               = self.Config.Settings.Permissions.Mute or "canmute"
    self.Config.Settings.Permissions.GlobalMute         = self.Config.Settings.Permissions.GlobalMute or "canglobalmute"
    self.Config.Settings.Permissions.AntiGlobalMute     = self.Config.Settings.Permissions.AntiGlobalMute or "notglobalmuted"
    -- Messages
    self.Config.Messages                                = self.Config.Messages or {}
    -- admin messages
    self.Config.Messages.Admin                          = self.Config.Messages.Admin or {}
    self.Config.Messages.Admin.NoPermission             = self.Config.Messages.Admin.NoPermission or "You dont have permission to use this command"
    self.Config.Messages.Admin.PlayerNotFound           = self.Config.Messages.Admin.PlayerNotFound or "Player not found"
    self.Config.Messages.Admin.MultiplePlayerFound      = self.Config.Messages.Admin.MultiplePlayerFound or "Found more than one player, be more specific:"
    self.Config.Messages.Admin.AlreadyMuted             = self.Config.Messages.Admin.AlreadyMuted or "{name} is already muted"
    self.Config.Messages.Admin.PlayerMuted              = self.Config.Messages.Admin.PlayerMuted or "{name} has been muted"
    self.Config.Messages.Admin.InvalidTimeFormat        = self.Config.Messages.Admin.InvalidTimeFormat or "Invalid time format"
    self.Config.Messages.Admin.PlayerMutedTimed         = self.Config.Messages.Admin.PlayerMutedTimed or "{name} has been muted for {time}"
    self.Config.Messages.Admin.MutelistCleared          = self.Config.Messages.Admin.MutelistCleared or "Cleared {count} entries from mutelist"
    self.Config.Messages.Admin.PlayerUnmuted            = self.Config.Messages.Admin.PlayerUnmuted or "{name} has been unmuted"
    self.Config.Messages.Admin.PlayerNotMuted           = self.Config.Messages.Admin.PlayerNotMuted or "{name} is not muted"
    -- player messages
    self.Config.Messages.Player                         = self.Config.Messages.Player or {}
    self.Config.Messages.Player.GlobalMuteEnabled       = self.Config.Messages.Player.GlobalMuteEnabled or "Chat is now globally muted"
    self.Config.Messages.Player.GlobalMuteDisabled      = self.Config.Messages.Player.GlobalMuteDisabled or "Global chat mute disabled"
    self.Config.Messages.Player.BroadcastMutes          = self.Config.Messages.Player.BroadcastMutes or "{name} has been muted"
    self.Config.Messages.Player.Muted                   = self.Config.Messages.Player.Muted or "You have been muted"
    self.Config.Messages.Player.BroadcastMutesTimed     = self.Config.Messages.Player.BroadcastMutesTimed or "{name} has been muted for {time}"
    self.Config.Messages.Player.MutedTimed              = self.Config.Messages.Player.MutedTimed or "You have been muted for {time}"
    self.Config.Messages.Player.BroadcastUnmutes        = self.Config.Messages.Player.BroadcastUnmutes or "{name} has been unmuted"
    self.Config.Messages.Player.Unmuted                 = self.Config.Messages.Player.Unmuted or "You have been unmuted"
    self.Config.Messages.Player.IsMuted                 = self.Config.Messages.Player.IsMuted or "You are muted"
    self.Config.Messages.Player.IsTimeMuted             = self.Config.Messages.Player.IsTimeMuted or "You are muted for {timeMuted}"
    self.Config.Messages.Player.GlobalMuted             = self.Config.Messages.Player.GlobalMuted or "Chat is globally muted by an admin"

    self:SaveConfig()
end

local GlobalMute = false
local muteList = "chatmute"
local muteData = {}
function PLUGIN:LoadDataFiles()
    muteData = datafile.GetDataTable(muteList) or {}
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
-- load all commands, depending on settings
-- --------------------------------
function PLUGIN:LoadCommands()
    for _, cmd in pairs(self.Config.Settings.ChatCommands.Mute) do
        command.AddChatCommand(cmd, self.Object, "cmdMute")
    end
    for _, cmd in pairs(self.Config.Settings.ChatCommands.Unmute) do
        command.AddChatCommand(cmd, self.Object, "cmdUnMute")
    end
    for _, cmd in pairs(self.Config.Settings.ChatCommands.GlobalMute) do
        command.AddChatCommand(cmd, self.Object, "cmdGlobalMute")
    end
    -- Console commands
    command.AddConsoleCommand("player.mute", self.Object, "ccmdMute")
    command.AddConsoleCommand("player.unmute", self.Object, "ccmdUnMute")
end
-- --------------------------------
-- permission check
-- --------------------------------
local function HasPermission(player, perm)
    local steamID = rust.UserIDFromPlayer(player)
    if permission.UserHasPermission(steamID, "admin") then
        return true
    end
    if permission.UserHasPermission(steamID, perm) then
        return true
    end
    return false
end
-- --------------------------------
-- builds output messages by replacing wildcards
-- --------------------------------
local function buildOutput(str, tags, replacements)
    for i = 1, #tags do
        str = string.gsub(str, tags[i], replacements[i])
    end
    return str
end
-- --------------------------------
-- prints to server console
-- --------------------------------
local function printToConsole(msg)
    --global.ServerConsole.PrintColoured(System.ConsoleColor.Cyan, msg)
    UnityEngine.Debug.Log.methodarray[0]:Invoke(nil, util.TableToArray({msg}))
end
-- --------------------------------
-- register all permissions for group system
-- --------------------------------
function PLUGIN:RegisterPermissions()
    for _, perm in pairs(self.Config.Settings.Permissions) do
        if not permission.PermissionExists(perm) then
            permission.RegisterPermission(perm, self.Object)
        end
    end
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
-- Function to call by external plugins to check mute status
-- --------------------------------
-- return values:
-- true (bool) if muted permanent
-- expirationDate (timestamp) if muted for specific time
-- false (bool) if not muted
-- --------------------------------
function PLUGIN:IsMuted(player)
    local now = time.GetUnixTimestamp()
    local targetSteamID = rust.UserIDFromPlayer(player)
    if GlobalMute and not HasPermission(player, self.Config.Settings.Permissions.AntiGlobalMute) then
        return true
    end
    if not muteData[targetSteamID] then
        return false
    end
    if muteData[targetSteamID].expiration < now and muteData[targetSteamID].expiration ~= 0 then
        muteData[targetSteamID] = nil
        datafile.SaveDataTable(muteList)
        return false
    end
    if muteData[targetSteamID].expiration == 0 then
        return true
    else
        return muteData[targetSteamID].expiration
    end
    return false
end
function PLUGIN:muteData(steamID)
    return muteData[steamID] ~= nil
end
function PLUGIN:APIMute(steamID, expiration)
    if muteData[steamID] then return false end
    muteData[steamID] = {}
    muteData[steamID].steamID = steamID
    muteData[steamID].expiration = expiration
    table.insert(muteData, muteData[steamID])
    datafile.SaveDataTable(muteList)
    return true
end
-- --------------------------------
-- handles chat command /globalmute
-- --------------------------------
function PLUGIN:cmdGlobalMute(player)
    if not HasPermission(player, self.Config.Settings.Permissions.GlobalMute) then
        rust.SendChatMessage(player, self.Config.Messages.Admin.NoPermission)
        return
    end
    if not GlobalMute then
        GlobalMute = true
        rust.BroadcastChat(self.Config.Messages.Player.GlobalMuteEnabled)
    else
        GlobalMute = false
        rust.BroadcastChat(self.Config.Messages.Player.GlobalMuteDisabled)
    end
end
-- --------------------------------
-- handles chat command /mute
-- --------------------------------
function PLUGIN:cmdMute(player, cmd, args)
    if not HasPermission(player, self.Config.Settings.Permissions.Mute) then
        rust.SendChatMessage(player, self.Config.Messages.Admin.NoPermission)
        return
    end
    local args = self:ArgsToTable(args, "chat")
    local target, duration = args[1], args[2]
    if not target then
        rust.SendChatMessage(player, "Syntax: /mute <name/steamID> <time[m/h] (optional)>")
        return
    end
    local numFound, targetPlayerTbl = FindPlayer(target, false)
    if numFound == 0 then
        rust.SendChatMessage(player, self.Config.Messages.Admin.PlayerNotFound)
        return
    end
    if numFound > 1 then
        local targetNameString = ""
        for i = 1, numFound do
            targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
        end
        rust.SendChatMessage(player, self.Config.Messages.Admin.MultiplePlayerFound)
        rust.SendChatMessage(player, targetNameString)
        return
    end
    local targetPlayer = targetPlayerTbl[1]
    self:Mute(player, targetPlayer, duration, nil)
end
-- --------------------------------
-- handles console command player.mute
-- --------------------------------
function PLUGIN:ccmdMute(arg)
    local player, F1Console
    if arg.connection then
        player = arg.connection.player
    end
    if player then F1Console = true end
    if player and not HasPermission(player, self.Config.Settings.Permissions.Mute) then
        arg:ReplyWith(self.Config.Messages.Admin.NoPermission)
        return true
    end
    local args = self:ArgsToTable(arg, "console")
    local target, duration = args[1], args[2]
    if not target then
        if F1Console then
            arg:ReplyWith("Syntax: player.mute <name/steamID> <time[m/h] (optional)>")
        else
            printToConsole("Syntax: player.mute <name/steamID> <time[m/h] (optional)>")
        end
        return
    end
    local numFound, targetPlayerTbl = FindPlayer(target, false)
    if numFound == 0 then
        if F1Console then
            arg:ReplyWith(self.Config.Messages.Admin.PlayerNotFound)
        else
            printToConsole(self.Config.Messages.Admin.PlayerNotFound)
        end
        return
    end
    if numFound > 1 then
        local targetNameString = ""
        for i = 1, numFound do
            targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
        end
        if F1Console then
            arg:ReplyWith(self.Config.Messages.Admin.MultiplePlayerFound)
            for i = 1, numFound do
                arg:ReplyWith(targetPlayerTbl[i].displayName)
            end
        else
            printToConsole(self.Config.Messages.Admin.MultiplePlayerFound)
            for i = 1, numFound do
                printToConsole(targetPlayerTbl[i].displayName)
            end
        end
        return
    end
    local targetPlayer = targetPlayerTbl[1]
    self:Mute(player, targetPlayer, duration, arg)
end
-- --------------------------------
-- mute target
-- --------------------------------
function PLUGIN:Mute(player, targetPlayer, duration, arg)
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    -- define source of command trigger
    local F1Console, srvConsole, chatCmd
    if player and arg then F1Console = true end
    if not player then srvConsole = true end
    if player and not arg then chatCmd = true end
    -- Check if target is already muted
    local isMuted = self:IsMuted(targetPlayer)
    if isMuted then
        if F1Console then
            arg:ReplyWith(buildOutput(self.Config.Messages.Admin.AlreadyMuted, {"{name}"}, {targetName}))
        end
        if srvConsole then
            printToConsole(buildOutput(self.Config.Messages.Admin.AlreadyMuted, {"{name}"}, {targetName}))
        end
        if chatCmd then
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.Admin.AlreadyMuted, {"{name}"}, {targetName}))
        end
        return
    end
    if not duration then
        -- No time is given, mute permanently
        muteData[targetSteamID] = {}
        muteData[targetSteamID].steamID = targetSteamID
        muteData[targetSteamID].expiration = 0
        table.insert(muteData, muteData[targetSteamID])
        datafile.SaveDataTable(muteList)
        -- Send mute notice
        if self.Config.Settings.General.BroadcastMutes == "true" then
            rust.BroadcastChat(buildOutput(self.Config.Messages.Player.BroadcastMutes, {"{name}"}, {targetName}))
            if F1Console then
                arg:ReplyWith(buildOutput(self.Config.Messages.Admin.PlayerMuted, {"{name}"}, {targetName}))
            end
            if srvConsole then
                printToConsole(buildOutput(self.Config.Messages.Admin.PlayerMuted, {"{name}"}, {targetName}))
            end
        else
            if F1Console then
                arg:ReplyWith(buildOutput(self.Config.Messages.Admin.PlayerMuted, {"{name}"}, {targetName}))
            end
            if srvConsole then
                printToConsole(buildOutput(lself.Config.Messages.Admin.PlayerMuted, {"{name}"}, {targetName}))
            end
            if chatCmd then
                rust.SendChatMessage(player, buildOutput(self.Config.Messages.Admin.PlayerMuted, {"{name}"}, {targetName}))
            end
            rust.SendChatMessage(targetPlayer, self.Config.Messages.Player.Muted)
        end
        -- Send console log
        if self.Config.Settings.General.LogToConsole == "true" then
            if not player then
                printToConsole("[ChatMute] An admin muted "..targetName)
            else
                printToConsole("[ChatMute] "..player.displayName.." muted "..targetName)
            end
        end
        return
    end
    -- Time is given, mute only for this timeframe
    -- Check for valid time format
    local c = string.match(duration, "^%d*[mh]$")
    if string.len(duration) < 2 or not c then
        if F1Console then
            arg:ReplyWith(self.Config.Messages.Admin.InvalidTimeFormat)
        end
        if srvConsole then
            printToConsole(self.Config.Messages.Admin.InvalidTimeFormat)
        end
        if chatCmd then
            rust.SendChatMessage(player, self.Config.Messages.Admin.InvalidTimeFormat)
        end
        return
    end
    -- Build expiration time
    local now = time.GetUnixTimestamp()
    local muteTime = tonumber(string.sub(duration, 1, -2))
    local timeUnit = string.sub(duration, -1)
    local timeMult, timeUnitLong
    if timeUnit == "m" then
        timeMult = 60
        timeUnitLong = "minutes"
    end
    if timeUnit == "h" then
        timeMult = 3600
        timeUnitLong = "hours"
    end
    local expiration = (now + (muteTime * timeMult))
    local time = muteTime.." "..timeUnitLong
    -- Mute player for given duration
    muteData[targetSteamID] = {}
    muteData[targetSteamID].steamID = targetSteamID
    muteData[targetSteamID].expiration = expiration
    table.insert(muteData, muteData[targetSteamID])
    datafile.SaveDataTable(muteList)
    -- Send mute notice
    if self.Config.Settings.General.BroadcastMutes == "true" then
        rust.BroadcastChat(buildOutput(self.Config.Messages.Player.BroadcastMutesTimed, {"{name}", "{time}"}, {targetName, time}))
        if F1Console then
            arg:ReplyWith(buildOutput(self.Config.Messages.Admin.PlayerMutedTimed, {"{name}", "{time}"}, {targetName, time}))
        end
        if srvConsole then
            printToConsole(buildOutput(self.Config.Messages.Admin.PlayerMutedTimed, {"{name}", "{time}"}, {targetName, time}))
        end
    else
        rust.SendChatMessage(targetPlayer, buildOutput(self.Config.Messages.Player.MutedTimed, {"{time}"}, {time}))
        if F1Console then
            arg:ReplyWith(buildOutput(self.Config.Messages.Admin.PlayerMutedTimed, {"{name}", "{time}"}, {targetName, time}))
        end
        if srvConsole then
            printToConsole(buildOutput(self.Config.Messages.Admin.PlayerMutedTimed, {"{name}", "{time}"}, {targetName, time}))
        end
        if chatCmd then
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.Admin.PlayerMutedTimed, {"{name}", "{time}"}, {targetName, time}))
        end
    end
    -- Send console log
    if self.Config.Settings.General.LogToConsole == "true" then
        if not player then
            printToConsole("[ChatMute] An admin muted "..targetName.." for "..muteTime.." "..timeUnitLong)
        else
            printToConsole("[ChatMute] "..player.displayName.." muted "..targetName.." for "..muteTime.." "..timeUnitLong)
        end
    end
end
-- --------------------------------
-- handles chat command /unmute
-- --------------------------------
function PLUGIN:cmdUnMute(player, cmd, args)
    if not HasPermission(player, self.Config.Settings.Permissions.Mute) then
        rust.SendChatMessage(player, self.Config.Messages.Admin.NoPermission)
        return
    end
    local args = self:ArgsToTable(args, "chat")
    local target = args[1]
    -- Check for valid syntax
    if not target then
        rust.SendChatMessage(player, "Syntax: /unmute <name|steamID> or /unmute all to clear mutelist")
        return
    end
    -- Check if "all" is used to clear the whole mutelist
    if target == "all" then
        local mutecount = #muteData
        muteData = {}
        datafile.SaveDataTable(muteList)
        rust.SendChatMessage(player, buildOutput(self.Config.Messages.Admin.MutelistCleared, {"{count}"}, {tostring(mutecount)}))
        return
    end
    -- Try to get target netuser
    local numFound, targetPlayerTbl = FindPlayer(target, false)
    if numFound == 0 then
        rust.SendChatMessage(player, self.Config.Messages.Admin.PlayerNotFound)
        return
    end
    if numFound > 1 then
        local targetNameString = ""
        for i = 1, numFound do
            targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
        end
        rust.SendChatMessage(player, self.Config.Messages.Admin.MultiplePlayerFound)
        rust.SendChatMessage(player, targetNameString)
        return
    end
    local targetPlayer = targetPlayerTbl[1]
    self:Unmute(player, targetPlayer, nil)
end
-- --------------------------------
-- handles console command player.unmute
-- --------------------------------
function PLUGIN:ccmdUnMute(arg)
    local player, F1Console
    if arg.connection then
        player = arg.connection.player
    end
    if player then F1Console = true end
    if player and not HasPermission(player, self.Config.Settings.Permissions.Mute) then
        arg:ReplyWith(self.Config.Messages.Admin.NoPermission)
        return true
    end
    local args = self:ArgsToTable(arg, "console")
    local target = args[1]
    if not target then
        if F1Console then
            arg:ReplyWith("Syntax: player.unmute <name/steamID> or player.unmute all to clear mutelist")
        else
            printToConsole("Syntax: player.unmute <name/steamID> or player.unmute all to clear mutelist")
        end
        return
    end
    -- Check if "all" is used to clear the whole mutelist
    if target == "all" then
        local mutecount = #muteData
        muteData = {}
        datafile.SaveDataTable(muteList)
        if F1Console then
            arg:ReplyWith(buildOutput(self.Config.Messages.Admin.MutelistCleared, {"{count}"}, {tostring(mutecount)}))
        else
            printToConsole(buildOutput(self.Config.Messages.Admin.MutelistCleared, {"{count}"}, {tostring(mutecount)}))
        end
        return
    end
    local numFound, targetPlayerTbl = FindPlayer(target, false)
    if numFound == 0 then
        if F1Console then
            arg:ReplyWith(self.Config.Messages.Admin.PlayerNotFound)
        else
            printToConsole(self.Config.Messages.Admin.PlayerNotFound)
        end
        return
    end
    if numFound > 1 then
        local targetNameString = ""
        for i = 1, numFound do
            targetNameString = targetNameString..targetPlayerTbl[i].displayName..", "
        end
        if F1Console then
            arg:ReplyWith(self.Config.Messages.Admin.MultiplePlayerFound)
            for i = 1, numFound do
                arg:ReplyWith(targetPlayerTbl[i].displayName)
            end
        else
            printToConsole(self.Config.Messages.Admin.MultiplePlayerFound)
            for i = 1, numFound do
                printToConsole(targetPlayerTbl[i].displayName)
            end
        end
        return
    end
    local targetPlayer = targetPlayerTbl[1]
    self:Unmute(player, targetPlayer, arg)
end
-- --------------------------------
-- unmute target
-- --------------------------------
function PLUGIN:Unmute(player, targetPlayer, arg)
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    -- define source of command trigger
    local F1Console, srvConsole, chatCmd
    if player and arg then F1Console = true end
    if not player then srvConsole = true end
    if player and not arg then chatCmd = true end
    -- Unmute player
    if muteData[targetSteamID] then
        muteData[targetSteamID] = nil
        datafile.SaveDataTable(muteList)
        -- Send unmute notice
        if self.Config.Settings.General.BroadcastMutes == "true" then
            rust.BroadcastChat(buildOutput(self.Config.Messages.Player.BroadcastUnmutes, {"{name}"}, {targetName}))
            if F1Console then
                arg:ReplyWith(buildOutput(self.Config.Messages.Admin.PlayerUnmuted, {"{name}"}, {targetName}))
            end
            if srvConsole then
                printToConsole(buildOutput(self.Config.Messages.Admin.PlayerUnmuted, {"{name}"}, {targetName}))
            end
        else
            rust.SendChatMessage(targetPlayer, self.Config.Messages.Player.Unmuted)
            if F1Console then
                arg:ReplyWith(buildOutput(self.Config.Messages.Admin.PlayerUnmuted, {"{name}"}, {targetName}))
            end
            if srvConsole then
                printToConsole(buildOutput(self.Config.Messages.Admin.PlayerUnmuted, {"{name}"}, {targetName}))
            end
            if chatCmd then
                rust.SendChatMessage(player, buildOutput(self.Config.Messages.Admin.PlayerUnmuted, {"{name}"}, {targetName}))
            end
        end
        -- Send console log
        if self.Config.Settings.General.LogToConsole == "true" then
            if player then
                printToConsole("[ChatMute] "..player.displayName.." unmuted "..targetName)
            else
                printToConsole("[ChatMute] An admin unmuted "..targetName)
            end
        end
        return
    end
    -- player is not muted
    if F1Console then
        arg:ReplyWith(buildOutput(self.Config.Messages.Admin.PlayerNotMuted, {"{name}"}, {targetName}))
    end
    if srvConsole then
        printToConsole(buildOutput(self.Config.Messages.Admin.PlayerNotMuted, {"{name}"}, {targetName}))
    end
    if chatCmd then
        rust.SendChatMessage(player, buildOutput(self.Config.Messages.Admin.PlayerNotMuted, {"{name}"}, {targetName}))
    end
end
-- --------------------------------
-- capture player chat
-- --------------------------------
function PLUGIN:OnRunCommand(arg)
    if not arg.connection then return end
    if not arg.cmd then return end
    local cmd = arg.cmd.namefull
    local msg = arg:GetString(0, "text")
    local player = arg.connection.player
    if cmd == "chat.say" and msg:sub(1, 1) ~= "/" then
        if GlobalMute and not HasPermission(player, self.Config.Settings.Permissions.AntiGlobalMute) then
            rust.SendChatMessage(player, self.Config.Messages.Player.GlobalMuted)
            return true
        end
        local IsMuted = self:IsMuted(player)
        if not IsMuted then return end
        if IsMuted ~= true and IsMuted > 0 then
            local now = time.GetUnixTimestamp()
            local expiration = IsMuted
            local muteTime = expiration - now
            local hours = tostring(math.floor(muteTime / 3600)):format("%02.f")
            local minutes = tostring(math.floor(muteTime / 60 - (hours * 60))):format("%02.f")
            local seconds = tostring(math.floor(muteTime - (hours * 3600) - (minutes * 60))):format("%02.f")
            local expirationString = tostring(hours.."h "..minutes.."m "..seconds.."s")
            rust.SendChatMessage(player, buildOutput(self.Config.Messages.Player.IsTimeMuted, {"{timeMuted}"}, {expirationString}))
            return true
        else
            rust.SendChatMessage(player, self.Config.Messages.Player.IsMuted)
            return true
        end
    end
end