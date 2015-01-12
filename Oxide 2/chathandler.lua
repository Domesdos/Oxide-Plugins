PLUGIN.Title        = "Chat Handler"
PLUGIN.Description  = "Many features to help moderate the chat"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(2, 2, 1)
PLUGIN.HasConfig    = true
PLUGIN.ResourceID   = 707

local debugMode = false


function PLUGIN:Init()
    self:LoadDefaultConfig()
    self:LoadChatCommands()
    self:LoadDataFiles()
end
-- --------------------------------
-- error and debug reporting
-- --------------------------------
local pluginTitle = PLUGIN.Title
local pluginVersion = string.match(tostring(PLUGIN.Version), "(%d+.%d+.%d+)")
local function error(msg)
    local message = "[Error] "..pluginTitle.."(v"..pluginVersion.."): "..msg
    local array = util.TableToArray({message})
    UnityEngine.Debug.LogError.methodarray[0]:Invoke(nil, array)
    print(message)
end
local function debug(msg)
    if not debugMode then return end
    local message = "[Debug] "..pluginTitle.."(v"..pluginVersion.."): "..msg
    local array = util.TableToArray({message})
    UnityEngine.Debug.LogWarning.methodarray[0]:Invoke(nil, array)
end
-- --------------------------------
-- admin permission check
-- --------------------------------
local function IsAdmin(player)
    if player:GetComponent("BaseNetworkable").net.connection.authLevel == 0 then
        return false
    end
    return true
end

function PLUGIN:LoadDefaultConfig()
    -- Config settings
    self.Config.Settings = self.Config.Settings or {}
    self.Config.Settings.BroadcastMutes = self.Config.Settings.BroadcastMutes or "true"
    self.Config.Settings.BlockServerAds = self.Config.Settings.BlockServerAds or "true"
    self.Config.Settings.EnableWordFilter = self.Config.Settings.EnableWordFilter or "false"
    self.Config.Settings.EnableChatHistory = self.Config.Settings.EnableChatHistory or "true"
    self.Config.Settings.ChatHistoryMaxLines = self.Config.Settings.ChatHistoryMaxLines or 10
    -- Logging settings
    self.Config.Settings.Logging = self.Config.Settings.Logging or {}
    self.Config.Settings.Logging.LogToConsole = self.Config.Settings.Logging.LogToConsole or "true"
    self.Config.Settings.Logging.LogBlockedMessages = self.Config.Settings.Logging.LogBlockedMessages or "true"
    self.Config.Settings.Logging.LogChatToOxide = self.Config.Settings.Logging.LogChatToOxide or "true"
    -- Admin mode settings
    self.Config.Settings.AdminMode = self.Config.Settings.AdminMode or {}
    self.Config.Settings.AdminMode.ChatCommand = self.Config.Settings.AdminMode.ChatCommand or "/admin"
    self.Config.Settings.AdminMode.ReplaceChatName = self.Config.Settings.AdminMode.ReplaceChatName or "true"
    self.Config.Settings.AdminMode.AdminChatName = self.Config.Settings.AdminMode.AdminChatName or "- Server Admin -"
    -- Antispam settings
    self.Config.Settings.AntiSpam = self.Config.Settings.AntiSpam or {}
    self.Config.Settings.AntiSpam.EnableAntiSpam = self.Config.Settings.AntiSpam.EnableAntiSpam or "true"
    self.Config.Settings.AntiSpam.MaxLines = self.Config.Settings.AntiSpam.MaxLines or 4
    self.Config.Settings.AntiSpam.TimeFrame = self.Config.Settings.AntiSpam.TimeFrame or 6
    -- HelpText messages
    self.Config.Settings.HelpText = self.Config.Settings.HelpText or {}
    self.Config.Settings.HelpText.ChatHistory = self.Config.Settings.HelpText.ChatHistory or "Use /history or /h to view recent chat history"
    self.Config.Settings.HelpText.Wordfilter = self.Config.Settings.HelpText.Wordfilter or "Use /wordfilter list to see blacklisted words"
    -- Serverip whitelist
    self.Config.AllowedIPsToPost = self.Config.AllowedIPsToPost or {}
    -- Wordfilter
    self.Config.WordFilter = self.Config.WordFilter or {
        ["bitch"] = "sweety",
        ["fucking hell"] = "lovely heaven",
        ["cunt"] = "****"
    }
    -- Check wordfilter for conflicts
    if self.Config.Settings.EnableWordFilter == "true" then
        for key, value in pairs(self.Config.WordFilter) do
            local first, _ = string.find(string.lower(value), string.lower(key))
            if first then
                self.Config.WordFilter[key] = nil
                error("Config error in word filter: [\""..key.."\":\""..value.."\"] both contain the same word")
                error("[\""..key.."\":\""..value.."\"] was removed from word filter")
            end
        end
    end
    self:SaveConfig()
end

function PLUGIN:LoadChatCommands()
    command.AddChatCommand("mute", self.Object, "cmdMute")
    command.AddChatCommand("unmute", self.Object, "cmdUnMute")
    if string.sub(self.Config.Settings.AdminMode.ChatCommand, 1, 1) == "/" then
        self.Config.Settings.AdminMode.ChatCommand = string.sub(self.Config.Settings.AdminMode.ChatCommand, 2)
    end
    command.AddChatCommand(self.Config.Settings.AdminMode.ChatCommand, self.Object, "cmdAdminMode")
    if self.Config.Settings.EnableChatHistory == "true" then
        command.AddChatCommand("history", self.Object, "cmdHistory")
        command.AddChatCommand("h", self.Object, "cmdHistory")
    end
    if self.Config.Settings.EnableWordFilter == "true" then
        command.AddChatCommand("wordfilter", self.Object, "cmdEditWordFilter")
    end
    command.AddChatCommand("globalmute", self.Object, "cmdGlobalMute")
    command.AddConsoleCommand("player.mute", self.Object, "ccmdMute")
    command.AddConsoleCommand("player.unmute", self.Object, "ccmdUnMute")
end

-- --------------------------------
-- declare some plugin wide vars
-- --------------------------------
local muteData, spamData = {}, {}
local MuteList = "chathandler-mutelist"
local SpamList = "chathandler-spamlist"
local AntiSpam, ChatHistory, AdminMode = {}, {}, {}
local GlobalMute = false
-- --------------------------------
-- handles data files
-- --------------------------------
function PLUGIN:LoadDataFiles()
    muteData = datafile.GetDataTable(MuteList) or {}
    spamData = datafile.GetDataTable(SpamList) or {}
end
function PLUGIN:SaveDataFiles()
    datafile.SaveDataTable(MuteList)
    datafile.SaveDataTable(SpamList)
end
-- --------------------------------
-- removes expired mutes from the mutelist
-- --------------------------------
function PLUGIN:CleanUpMuteList()
    local now = time.GetUnixTimestamp()
    for key, _ in pairs(muteData) do
        if muteData[key].expiration < now and muteData[key].expiration ~= 0 then
            table.remove(muteData, key)
            self:SaveDataFiles()
        end
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
-- --------------------------------
-- quote safe string
-- --------------------------------
local function QuoteSafe(string)
    return UnityEngine.StringExtensions.QuoteSafe(string)
end
-- --------------------------------
-- sends a chat message
-- --------------------------------
function PLUGIN:ChatMessage(targetPlayer, chatName, msg)
    if msg then
        targetPlayer:SendConsoleCommand("chat.add "..QuoteSafe(chatName).." "..QuoteSafe(msg))
    else
        msg = chatName
        targetPlayer:SendConsoleCommand("chat.add SERVER "..QuoteSafe(msg))
    end
end
-- --------------------------------
-- broadcasts a message
-- --------------------------------
function PLUGIN:Broadcast(arg1, arg2)
    if arg2 then
        global.ConsoleSystem.Broadcast("chat.add "..QuoteSafe(arg1).." "..QuoteSafe(arg2).."")
    else
        global.ConsoleSystem.Broadcast("chat.add SERVER "..QuoteSafe(arg1).."")
    end
end
-- --------------------------------
-- returns (bool)IsMuted, (string)timeMuted
-- --------------------------------
function PLUGIN:CheckMute(targetSteamID)
    local now = time.GetUnixTimestamp()
    if not muteData[targetSteamID] then return false, false end
    if muteData[targetSteamID].expiration < now and muteData[targetSteamID].expiration ~= 0 then
        muteData[targetSteamID] = nil
        self:SaveDataFiles()
        return false, false
    end
    if muteData[targetSteamID].expiration == 0 then
        return true, false
    else
        local expiration = muteData[targetSteamID].expiration
        local muteTime = expiration - now
        local hours = string.format("%02.f", math.floor(muteTime / 3600))
        local minutes = string.format("%02.f", math.floor(muteTime / 60 - (hours * 60)))
        local seconds = string.format("%02.f", math.floor(muteTime - (hours * 3600) - (minutes * 60)))
        local expirationString = tostring(hours.."h "..minutes.."m "..seconds.."s")
        return true, expirationString
    end
    return false, false
end
-- --------------------------------
-- handles chat command /admin
-- --------------------------------
function PLUGIN:cmdAdminMode(player)
    if not IsAdmin(player) then
        self:ChatMessage(player, "You dont have permission to use this command")
        return
    end
    local steamID = rust.UserIDFromPlayer(player)
    if AdminMode[steamID] then
        AdminMode[steamID] = nil
        self:ChatMessage(player, "You switched back to player mode")
    else
        AdminMode[steamID] = true
        self:ChatMessage(player, "You switched to admin mode")
    end
end
-- --------------------------------
-- handles chat command /globalmute
-- --------------------------------
function PLUGIN:cmdGlobalMute(player)
    if not IsAdmin(player) then
        self:ChatMessage(player, "You dont have permission to use this command")
        return
    end
    if not GlobalMute then
        GlobalMute = true
        self:Broadcast("Chat is now globally muted")
    else
        GlobalMute = false
        self:Broadcast("Global chatmute is now deactivated")
    end
end
-- --------------------------------
-- handles chat command /mute
-- --------------------------------
function PLUGIN:cmdMute(player, cmd, args)
    if not IsAdmin(player) then
        self:ChatMessage(player, "You dont have permission to use this command")
        return
    end
    local args = self:ArgsToTable(args, "chat")
    local target, duration = args[1], args[2]
    if not target then
        self:ChatMessage(player, "Syntax: \"/mute <name/steamID> <time[m|h] (optional)>\"")
        return
    end
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        self:ChatMessage(player, "Player not found")
        return
    end
    self:Mute(player, targetPlayer, duration)
end
-- --------------------------------
-- handles console command player.mute
-- --------------------------------
function PLUGIN:ccmdMute(arg)
    local player
    if arg.connection then
        player = arg.connection.player
    end
    if player and not IsAdmin(player) then
        arg:ReplyWith("You dont have permission to use this command")
        return true
    end
    local args = self:ArgsToTable(arg, "console")
    local target, duration = args[1], args[2]
    if not target then
        print("Syntax: \"player.mute <name/steamID> <time[m|h] (optional)>\"")
        return
    end
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        print("Player not found")
        return
    end
    self:Mute(player, targetPlayer, duration)
end
-- --------------------------------
-- mute target
-- --------------------------------
function PLUGIN:Mute(player, targetPlayer, duration)
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    -- Check if target is already muted
    local isMuted, _ = self:CheckMute(targetSteamID)
    if isMuted then
        if player then
            self:ChatMessage(player, targetName.." is already muted")
        else
            print(targetName.." is already muted")
        end
        return
    end
    if not duration then
    -- No time is given, mute permanently
        muteData[targetSteamID] = {}
        muteData[targetSteamID].steamID = targetSteamID
        muteData[targetSteamID].expiration = 0
        table.insert(muteData, muteData[targetSteamID])
        self:SaveDataFiles()
        -- Send mute notice
        if self.Config.Settings.BroadcastMutes == "true" then
            self:Broadcast(targetName.." has been muted")
            if not player and self.Config.Settings.Logging.LogToConsole == "false" then
                print(targetName.." has been muted")
            end
        else
            if not player and self.Config.Settings.Logging.LogToConsole == "false" then
                print(targetName.." has been muted")
            else
                self:ChatMessage(player, targetName.." has been muted")
            end
            targetPlayer:ChatMessage("You have been muted")
        end
        -- Send console log
        if self.Config.Settings.Logging.LogToConsole == "true" then
            if not player then
                print(self.Title..": Admin muted "..targetName.." per remote console")
            else
                print(self.Title..": "..player.displayName.." muted "..targetName)
            end
        end
        return
    end
    -- Time is given, mute only for this timeframe
    -- Check for valid time format
    local c = string.match(duration, "^%d*[mh]$")
    if string.len(duration) < 2 or not c then
        if not player then
            print("Invalid time format")
        else
            self:ChatMessage(player, "Invalid time format")
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
    -- Mute player for given duration
    muteData[targetSteamID] = {}
    muteData[targetSteamID].steamID = targetSteamID
    muteData[targetSteamID].expiration = expiration
    table.insert(muteData, muteData[targetSteamID])
    self:SaveDataFiles()
    -- Send mute notice
    if self.Config.Settings.BroadcastMutes == "true" then
        if not player and self.Config.Settings.Logging.LogToConsole == "false" then
            print(targetName.." has been muted for "..muteTime.." "..timeUnitLong)
        end
        self:Broadcast(targetName.." has been muted for "..muteTime.." "..timeUnitLong)
    else
        targetPlayer:ChatMessage("You have been muted for "..muteTime.." "..timeUnitLong)
        if not player and self.Config.Settings.Logging.LogToConsole == "false" then
            print(targetName.." has been muted for "..muteTime.." "..timeUnitLong)
        else
            self:ChatMessage(player, targetName.." has been muted for "..muteTime.." "..timeUnitLong)
        end
    end
    -- Send console log
    if self.Config.Settings.Logging.LogToConsole == "true" then
        if not player then
            print(self.Title..": Admin muted "..targetName.." for "..muteTime.." "..timeUnitLong.." per remote console")
        else
            print(self.Title..": "..player.displayName.." muted "..targetName.." for "..muteTime.." "..timeUnitLong)
        end
    end
end
-- --------------------------------
-- handles chat command /unmute
-- --------------------------------
function PLUGIN:cmdUnMute(player, cmd, args)
    if not IsAdmin(player) then
        self:ChatMessage(player, "You dont have permission to use this command")
        return
    end
    local args = self:ArgsToTable(args, "chat")
    local target = args[1]
    -- Check for valid syntax
    if not target then
        self:ChatMessage(player, "Syntax: \"/unmute <name|steamID>\" or \"/unmute all\" to clear mutelist")
        return
    end
    -- Check if "all" is used to clear the whole mutelist
    if target == "all" then
        local mutecount = #muteData
        muteData = {}
        self:SaveDataFiles()
        self:ChatMessage(player, "Cleared "..tostring(mutecount).." entries from mutelist")
        return
    end
    -- Try to get target netuser
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        self:ChatMessage(player, "Player not found")
        return
    end
    self:Unmute(player, targetPlayer)
end
-- --------------------------------
-- handles console command player.unmute
-- --------------------------------
function PLUGIN:ccmdUnMute(arg)
    local player
    if arg.connection then
        player = arg.connection.player
    end
    if player and not IsAdmin(player) then
        arg:ReplyWith("You dont have permission to use this command")
        return true
    end
    local args = self:ArgsToTable(arg, "console")
    local target = args[1]
    if not target then
        print("Syntax: \"player.unmute <name/steamID>\" or \"player.unmute all\" to clear mutelist")
        return
    end
    local targetPlayer = global.BasePlayer.Find(target)
    if not targetPlayer then
        print("Player not found")
        return
    end
    self:Unmute(player, targetPlayer)
end
-- --------------------------------
-- unmute target
-- --------------------------------
function PLUGIN:Unmute(player, targetPlayer)
    local targetName = targetPlayer.displayName
    local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
    -- Unmute player
    if muteData[targetSteamID] then
        muteData[targetSteamID] = nil
        self:SaveDataFiles()
        -- Send unmute notice
        if self.Config.Settings.BroadcastMutes == "true" then
            self:Broadcast(targetName.." has been unmuted")
            if not player and self.Config.Settings.Logging.LogToConsole == "false" then
                print(targetName.." has been unmuted")
            end
        else
            targetPlayer:ChatMessage("You have been unmuted")
            if not player and self.Config.Settings.Logging.LogToConsole == "false" then
                print(targetName.." has been unmuted")
            else
                self:ChatMessage(player, targetName.." has been unmuted")
            end
        end
        -- Send console log
        if self.Config.Settings.Logging.LogToConsole == "true" then
            if not player then
                print(self.Title..": Admin unmuted "..targetName.." per remote console")
            else
                print(self.Title..": "..player.displayName.." unmuted "..targetName)
            end
        end
        return
    end
    if not player then
        print(targetName.." is not muted")
    else
        self:ChatMessage(player, targetName.." is not muted")
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
    if cmd == "chat.say" and string.sub(msg, 1, 1) ~= "/" then
        local blockChat = self:OnPlayerChat(player, msg)
        if blockChat then
            return true
        end
    end
end
-- --------------------------------
-- handles chat messages
-- returns true if chat should be blocked
-- --------------------------------
function PLUGIN:OnPlayerChat(player, msg)
    local steamID = rust.UserIDFromPlayer(player)
    -- Spam prevention
    if self.Config.Settings.AntiSpam.EnableAntiSpam == "true" then
        local isSpam, punishTime = self:AntiSpamCheck(player)
        if isSpam then
            self:ChatMessage(player, "Auto mute: "..punishTime.." for spam")
            timer.Once(4, function() self:ChatMessage(player, "If you keep spamming your punishment will raise") end)
            if self.Config.Settings.BroadcastMutes == "true" then
                self:Broadcast(player.displayName.." auto mute: "..punishTime.." for spam")
            end
            if self.Config.Settings.Logging.LogToConsole == "true" then
                print(self.Title..": "..player.displayName.." got a "..punishTime.." auto mute for spam")
            end
            return true
        end
    end
    -- Parse message to filter stuff and check if message should be blocked
    local canChat, msg, error, prefix = self:ParseChat(player, msg)
    -- Chat is blocked
    if not canChat then
        if self.Config.Settings.Logging.LogBlockedMessages == "true" then
            print("[CHAT]"..prefix.." "..player.displayName..": "..msg)
        end
        self:ChatMessage(player, error)
        return true
    end
    -- Chat is ok and not blocked
    local username, message = self:BuildNameMessage(player, msg)
    self:SendChat(player, username, message)
    return true
end
-- --------------------------------
-- checks for chat spam
-- returns (bool)IsSpam, (string)punishTime
-- --------------------------------
function PLUGIN:AntiSpamCheck(player)
    local steamID = rust.UserIDFromPlayer(player)
    local now = time.GetUnixTimestamp()
    if muteData[steamID] then return false, false end
    if AdminMode[steamID] then return false, false end
    if AntiSpam[steamID] then
        local firstMsg = AntiSpam[steamID].timestamp
        local msgCount = AntiSpam[steamID].msgcount
        if msgCount < self.Config.Settings.AntiSpam.MaxLines then
            AntiSpam[steamID].msgcount = AntiSpam[steamID].msgcount + 1
            return false, false
        else
            if now - firstMsg <= self.Config.Settings.AntiSpam.TimeFrame then
                -- punish
                local punishCount = 1
                local expiration, punishTime, newEntry
                if spamData[steamID] then
                    newEntry = false
                    punishCount = spamData[steamID].punishcount + 1
                    spamData[steamID].punishcount = punishCount
                    self:SaveDataFiles()
                end
                if punishCount == 1 then
                    expiration =  now + 300
                    punishTime = "5 minutes"
                elseif punishCount == 2 then
                    expiration = now + 3600
                    punishTime = "1 hour"
                else
                    expiration = 0
                    punishTime = "permanent"
                end
                if newEntry ~= false then
                    spamData[steamID] = {}
                    spamData[steamID].steamID = steamID
                    spamData[steamID].punishcount = punishCount
                    table.insert(spamData, spamData[steamID])
                    self:SaveDataFiles()
                end
                muteData[steamID] = {}
                muteData[steamID].steamID = steamID
                muteData[steamID].expiration = expiration
                table.insert(muteData, muteData[steamID])
                self:SaveDataFiles()
                AntiSpam[steamID] = nil
                return true, punishTime
            else
                AntiSpam[steamID].timestamp = now
                AntiSpam[steamID].msgcount = 1
                return false, false
            end
        end
    else
        AntiSpam[steamID] = {}
        AntiSpam[steamID].timestamp = now
        AntiSpam[steamID].msgcount = 1
        return false, false
    end
end
-- --------------------------------
-- parses the chat
-- returns (bool)canChat, (string)msg, (string)errorMsg, (string)errorPrefix
-- --------------------------------
function PLUGIN:ParseChat(player, msg)
    local msg = tostring(msg)
    local steamID = rust.UserIDFromPlayer(player)
    if AdminMode[steamID] then return true, msg, false, false end
    -- Check player specific mute
    local isMuted, timeMuted = self:CheckMute(steamID)
    if isMuted then
        if not timeMuted then
            return false, msg, "You are muted", "[MUTED]"
        else
            return false, msg, "You are muted for "..timeMuted, "[MUTED]"
        end
    end
    -- Check global mute
    if GlobalMute and not IsAdmin(player) then
        return false, msg, "Chat is currently global muted", "[MUTED]"
    end
    -- Check for server advertisements
    if self.Config.Settings.BlockServerAds == "true" then
        local ipCheck
        local ipString = ""
        local chunks = {string.match(msg, "(%d+)%.(%d+)%.(%d+)%.(%d+)") }
        if #chunks == 4 then
            for _,v in pairs(chunks) do
                if tonumber(v) < 0 or tonumber(v) > 255 then
                    ipCheck = false
                    break
                end
                ipString = ipString..v.."."
                ipCheck = true
            end
            -- remove the last dot
            if string.sub(ipString, -1) == "." then
                ipString = string.sub(ipString, 1, -2)
            end
        else
            ipCheck = false
        end
        if ipCheck then
            for key, value in pairs(self.Config.AllowedIPsToPost) do
                if string.match(self.Config.AllowedIPsToPost[key], ipString) then
                    return true, msg, false, false
                end
            end
            return false, msg, "Its not allowed to advertise other servers", "[BLOCKED]"
        end
    end
    -- Check for blacklisted words
    if self.Config.Settings.EnableWordFilter == "true" then
        for key, value in pairs(self.Config.WordFilter) do
            local first, last = string.find(string.lower(msg), key)
            if first then
                while first do
                    local before = string.sub(msg, 1, first - 1)
                    local after = string.sub(msg, last + 1)
                    msg = before..value..after
                    first, last = string.find(string.lower(msg), key)
                end
            end
        end
        return true, msg, false, false
    end
    return true, msg, false, false
end
-- --------------------------------
-- builds username and chatmessage
-- returns (string)username, (string)message
-- --------------------------------
function PLUGIN:BuildNameMessage(player, msg)
    local username = player.displayName
    local message = msg
    local steamID = rust.UserIDFromPlayer(player)
    if AdminMode[steamID] then
        if self.Config.Settings.AdminMode.ReplaceChatName == "true" then
            username = self.Config.Settings.AdminMode.AdminChatName
        end
    end
    return username, message
end
-- --------------------------------
-- sends and logs chat messages
-- --------------------------------
function PLUGIN:SendChat(player, name, msg)
    -- Broadcast chat ingame
    self:Broadcast(name, msg)
    -- Log to Rusty chat stream
    local arr = util.TableToArray({name..": "..msg})
    UnityEngine.Debug.Log.methodarray[0]:Invoke(nil, arr)
    -- Log to Oxide log file
    if self.Config.Settings.Logging.LogChatToOxide == "true" then
        print("[CHAT] "..name..": "..msg)
    end
    -- Log to Webchat if installed
    --[[
    if(self.webchatPlugin ~= nil) then
        local timestamp = util.GetTime()
        local steam64 = rust.GetLongUserID(netuser)
        local newWebchatInsert = {timestamp, name, logMsg, steam64 }
        if(#self.webchatPlugin.ChatData >= self.webchatPlugin.Config.maxlines) then
            table.remove(self.webchatPlugin.ChatData, 1)
        end
        -- Insert new data, save the file and send it
        table.insert(self.webchatPlugin.ChatData, newWebchatInsert)
        self.webchatPlugin:Save()
        self.webchatPlugin:SendChat()
    end
    ]]--
    -- Log chat history
    if self.Config.Settings.EnableChatHistory == "true" then
        self:InsertHistory(name, msg)
    end
end
-- --------------------------------
-- remove data on disconnect
-- --------------------------------
function PLUGIN:OnPlayerDisconnected(player)
    local steamID = rust.UserIDFromPlayer(player)
    AntiSpam[steamID] = nil
    AdminMode[steamID] = nil
end
-- --------------------------------
-- handles chat command /history and /h
-- --------------------------------
function PLUGIN:cmdHistory(player)
    if #ChatHistory > 0 then
        player:SendConsoleCommand("chat.add \"ChatHistory\" \"----------\"")
        local i = 1
        while ChatHistory[i] do
            player:SendConsoleCommand("chat.add "..UnityEngine.StringExtensions.QuoteSafe(ChatHistory[i].name).." "..UnityEngine.StringExtensions.QuoteSafe(ChatHistory[i].msg).."")
            i = i + 1
        end
        player:SendConsoleCommand("chat.add \"ChatHistory\" \"----------\"")
    else
        player:SendConsoleCommand("chat.add \"ChatHistory\" \"No history found\"")
    end
end
-- --------------------------------
-- inserts chat messages into history
-- --------------------------------
function PLUGIN:InsertHistory(name, msg)
    if #ChatHistory == self.Config.Settings.ChatHistoryMaxLines then
        table.remove(ChatHistory, 1)
    end
    table.insert(ChatHistory, {["name"] = name, ["msg"] = msg})
end
-- --------------------------------
-- handles chat command /wordfilter
-- --------------------------------
function PLUGIN:cmdEditWordFilter(player, cmd, args)
    local args = self:ArgsToTable(args, "chat")
    local func, word, replacement = args[1], args[2], args[3]
    if not func or func ~= "add" and func ~= "remove" and func ~= "list" then
        if not IsAdmin(player) then
            self:ChatMessage(player, "Syntax \"/wordfilter list\"")
        else
            self:ChatMessage(player, "Syntax: \"/wordfilter add <word> <replacement>\" or \"/wordfilter remove <word>\"")
        end
        return
    end
    if func ~= "list" and not IsAdmin(player) then
        self:ChatMessage(player, "You dont have permission to use this command")
        return
    end
    if func == "add" then
        if not replacement then
            self:ChatMessage(player, "Syntax: \"/wordfilter add <word> <replacement>\"")
            return
        end
        local first, last = string.find(string.lower(replacement), string.lower(word))
        if first then
            self:ChatMessage(player, "Error: "..replacement.." contains the word "..word)
            return
        else
            self.Config.WordFilter[word] = replacement
            self:SaveConfig()
            self:ChatMessage(player, "WordFilter added. \""..word.."\" will now be replaced with \""..replacement.."\"")
        end
        return
    end
    if func == "remove" then
        if not word then
            self:ChatMessage(player, "Syntax: \"/wordfilter remove <word>\"")
            return
        end
        if self.Config.WordFilter[word] then
            self.Config.WordFilter[word] = nil
            self:SaveConfig()
            self:ChatMessage(player, "\""..word.."\" successfully removed from the word filter")
        else
            self:ChatMessage(player, "No filter for \""..word.."\" found")
        end
        return
    end
    if func == "list" then
        local wordFilterList = ""
        for key, value in pairs(self.Config.WordFilter) do
            wordFilterList = wordFilterList..key..", "
        end
        self:ChatMessage(player, "Blacklisted words: "..wordFilterList)
    end
end
-- --------------------------------
-- handles chat command /help
-- --------------------------------
function PLUGIN:SendHelpText(player)
    if self.Config.Settings.EnableChatHistory == "true" then
        self:ChatMessage(player, self.Config.Settings.HelpText.ChatHistory)
    end
    if self.Config.Settings.EnableWordFilter == "true" then
        self:ChatMessage(player, self.Config.Settings.HelpText.Wordfilter)
    end
end