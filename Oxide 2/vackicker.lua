PLUGIN.Title = "VAC Kicker"
PLUGIN.Description = "Dont allow poeple with a VAC ban in any game to join the server"
PLUGIN.Author = "#Domestos"
PLUGIN.Version = V(1, 0, 0)
PLUGIN.HasConfig = true

local debug = true

function PLUGIN:Init()
    self:LoadDefaultConfig()
end

function PLUGIN:OnPlayerConnected(packet)
    local connection = packet.connection
    local playerSteamID = rust.UserIDFromConnection(connection)
    local playerName = connection.username
    self:VACCheck(playerSteamID, playerName, connection)
end

function PLUGIN:LoadDefaultConfig()
    self.Config.Settings = self.Config.Settings or {}
    self.Config.Settings.ApiKey = self.Config.Settings.ApiKey or ""
    self.Config.Settings.LogToConsole = self.Config.Settings.LogToConsole or "true"
    self.Config.Settings.Threshold = self.Config.Settings.Threshold or 0
    if not self.Config.Settings.ApiKey or self.Config.Settings.ApiKey == "" then
        print(self.Title.." No Steam API key found")
        return
    end
    self:SaveConfig()
end

function PLUGIN:VACCheck(targetSteamID, targetName, connection)
    local url = "http://api.steampowered.com/ISteamUser/GetPlayerBans/v0001/?key="..self.Config.Settings.ApiKey.."&steamids="..targetSteamID
    webrequests.EnqueueGet(url, function(code, response)
        if code == 401 then
            print(self.Title..": ERROR - Webreqquest failed. Invalid steam api key")
            return
        elseif code == 404 or code == 503 then
            print(self.Title..": ERROR - Webrequest failed. Steam api unavailable")
            return
        elseif code == 200 then
            local response = json.decode(response)
            -- Set variables for easier string formatting
            local daysSinceLastBan = tostring(response.players[1].DaysSinceLastBan)
            local targetInfo = targetName.." ("..targetSteamID..")"
            local threshold = self.Config.Settings.Threshold
            -- Debug
            if debug then
                print(self.Title..": DEBUG - daysSinceLastBan: "..daysSinceLastBan)
                print(self.Title..": DEBUG - response.players[1].VACBanned: "..response.players[1].VACBanned)
                print(self.Title..": DEBUG - threshold: "..threshold)
            end
            -- Check if vac banned
            if response.players[1].VACBanned then
                -- Check if days since last ban are above threshold if set
                if threshold > 0 then
                    if response.players[1].DaysSinceLastBan < threshold then
                        if self.Config.Settings.LogToConsole == "true" then
                            -- Print console message when set to true and kick
                            print(self.Title..": VAC ban detected on "..targetInfo.."["..daysSinceLastBan.." days]. Kicking player...")
                            Network.Net.sv:Kick(connection, "VAC banned")
                            print(self.Title..": "..targetInfo.." has been kicked.")
                        else
                            -- Kick without message
                            Network.Net.sv:Kick(connection, "VAC banned")
                        end
                    else -- Days since last ban is above threshold
                        print(self.Title..": "..targetInfo.." VAC ban detected but above threshold ["..daysSinceLastBan.." days]. Not kicking")
                    end
                else -- No threshold is set
                    if self.Config.Settings.LogToConsole == "true" then
                        -- Print console message when set to true and kick
                        print(self.Title..": VAC ban detected on "..targetInfo..". Kicking player...")
                        Network.Net.sv:Kick(connection, "VAC banned")
                        print(self.Title..": "..playerInfo.." has been kicked.")
                    else
                        -- Kick without message
                        Network.Net.sv:Kick(connection, "VAC banned")
                    end
                end
            else
                -- Victim not vac banned
                if self.Config.Settings.LogToConsole == "true" then
                    print(self.Title..": "..targetInfo.." no ban detected")
                end
            end
        else
            print(self.Title..": ERROR - Webrequest failed. Errorcode: "..tostring(code))
            return
        end
    end, self.Object)
    if debug then
        print(self.Title..": DEBUG - request: "..tostring(r))
    end
end

