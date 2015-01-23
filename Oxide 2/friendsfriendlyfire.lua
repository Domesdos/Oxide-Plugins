PLUGIN.Title        = "Friends Friendly Fire"
PLUGIN.Description  = "Allows you to toggle friendly fire for friends"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(1, 3, 0)
PLUGIN.HasConfig    = true
PLUGIN.ResourceID   = 687

local friendsAPI
local debugMode = false

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
    return player:GetComponent("BaseNetworkable").net.connection.authLevel > 0
end
-- --------------------------------
-- init
-- --------------------------------
function PLUGIN:Init()
    if not plugins.Exists("0friendsAPI") then
        error("FriendsAPI not found")
        error("Get it here: http://forum.rustoxide.com/plugins/friends-api.686/")
        return
    end
    command.AddChatCommand("fff", self.Object, "SetConfig")
    self:LoadDefaultConfig()
    -- Get plugin instance of friendsAPI
    local pluginList = plugins.GetAll()
    for i = 0, pluginList.Length - 1 do
        local pluginTitle = pluginList[i].Object.Title
        if pluginTitle == "FriendsAPI" then
            friendsAPI = pluginList[i].Object
            break
        end
    end
end
-- --------------------------------
-- load the default config
-- --------------------------------
function PLUGIN:LoadDefaultConfig()
    self.Config.FriendlyFire = self.Config.FriendlyFire or "true"
    self:SaveConfig()
end
-- --------------------------------
-- hook to catch player attacks
-- --------------------------------
function PLUGIN:OnPlayerAttack(attacker, hitinfo)
    debug("OnPlayerAttack()")
    if self.Config.FriendlyFire == "false" then
        debug("HitEntity: "..tostring(hitinfo.HitEntity))
        if hitinfo.HitEntity then
            if string.match(tostring(hitinfo.HitEntity), "BasePlayer") then
                local targetPlayer = hitinfo.HitEntity
                local targetSteamID = rust.UserIDFromPlayer(targetPlayer)
                local attackerSteamID = rust.UserIDFromPlayer(attacker)
                local hasFriend = friendsAPI:HasFriend(attackerSteamID, targetSteamID)
                debug("hasFriend: "..tostring(hasFriend))
                if hasFriend then
                    rust.SendChatMessage(attacker, "You cant damage your friend")
                    hitinfo.damageTypes = new(Rust.DamageTypeList._type, nil)
                    hitinfo.HitMaterial = 0
                end
            end
        end
    end
end
-- --------------------------------
-- set config vars ingame
-- --------------------------------
function PLUGIN:SetConfig(player)
    if not IsAdmin(player) then return false end
    if self.Config.FriendlyFire == "false" then
        self.Config.FriendlyFire = "true"
        rust.SendChatMessage(player, "FriendlyFire on")
    else
        self.Config.FriendlyFire = "false"
        rust.SendChatMessage(player, "FriendlyFire off")
    end
    self:SaveConfig()
end