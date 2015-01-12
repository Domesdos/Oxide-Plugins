PLUGIN.Title        = "WebChat"
PLUGIN.Description  = "Sends your chat to an external script"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(1, 0, 0)
PLUGIN.HasConfig    = true

local debugMode = false

function PLUGIN:Init()
    self:LoadDefaultConfig()
    self:LoadDataFiles()
end

function PLUGIN:LoadDefaultConfig()
    self.Config.Settings = self.Config.Settings or {}
    self.Config.Settings.ScriptUrl = self.Config.Settings.ScriptUrl or ""
    self:SaveConfig()
end

local dataTable = {}
local dataFile = "webchat"
function PLUGIN:LoadDataFiles()
    dataTable = datafile.GetDataTable(dataFile) or {}
    dataTable.data = dataTable.data or {}
end
function PLUGIN:SaveDataFiles()
    datafile.SaveDataTable(dataFile)
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
-- capture player chat
-- --------------------------------
function PLUGIN:OnRunCommand(arg)
    if not arg.connection then return end
    if not arg.cmd then return end
    local cmd = arg.cmd.namefull
    local msg = arg:GetString(0, "text")
    local player = arg.connection.player
    if cmd == "chat.say" and string.sub(msg, 1, 1) ~= "/" then
        self:LogChat(player, msg)
        self:SendChat()
    end
end
-- --------------------------------
-- logs chat to data file
-- --------------------------------
function PLUGIN:LogChat(player, msg)
    local playerName = player.displayName
    local playerSteamID = rust.UserIDFromPlayer(player)
    local timestamp = time.GetUnixTimestamp()
    local newChatEntry = {}
    newChatEntry.name = playerName
    newChatEntry.steamID = playerSteamID
    newChatEntry.timestamp = timestamp
    newChatEntry.message = msg
    if #dataTable >= 5 then
        table.remove(dataTable, 1)
    end
    table.insert(dataTable.data, newChatEntry)
    self:SaveDataFiles()
end
-- --------------------------------
-- sends all chat data to the external script
-- --------------------------------
function PLUGIN:SendChat()
    local url = self.Config.Settings.ScriptUrl
    if not url or url == "" then
        error("No script-url found")
        return
    end
    local postData = "chatdata="..dataTable.data
    Webrequests.EnqueuePost(url, postData, function (httpCode, response)
        if httpCode == 404 then
            error("Webreqquest failed. Script not found, check script-url")
            return
        end
        if httpCode == 503 then
            error("Webrequest failed. Webserver unavailable")
            return
        end
        if httpCode == 200 then
            debug("Webrequest successful")
            return
        end
        error("Webrequest failed. Error code: "..tostring(httpCode))
    end, nil)
end