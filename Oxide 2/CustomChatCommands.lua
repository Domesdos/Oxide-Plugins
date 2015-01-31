PLUGIN.Title = "Custom Chat Commands"
PLUGIN.Description = "Set completely custom chat commands"
PLUGIN.Author = "#Domestos"
PLUGIN.Version = V(2, 2, 0)
PLUGIN.HasConfig = true
PLUGIN.ResourceID = 649

function PLUGIN:Init()
    for key, value in pairs(self.Config.ChatCommands) do
        command.AddChatCommand(key, self.Object, "cmdChatCmd")
    end
    self:LoadDefaultConfig()
end

local function IsAdmin(player)
    return player:GetComponent("BaseNetworkable").net.connection.authLevel > 0
end

function PLUGIN:LoadDefaultConfig()
    self.Config.Settings = self.Config.Settings or {}
    self.Config.Settings.ChatName = self.Config.Settings.ChatName or "SERVER"
    self.Config.ChatCommands = self.Config.ChatCommands or {
        ["command1"] = {
            ["text"] = {"This is an example text"},
            ["helptext"] = "This is the helptext for this command",
            ["admin"] = false
        },
        ["command2"] = {
            ["text"] = {"This is an example text for admins only", "You can also use multiline messages"},
            ["helptext"] = "This is the helptext for this command, also admin only",
            ["admin"] = true
        }
    }
    self:SaveConfig()
end

function PLUGIN:cmdChatCmd(player, cmd, args)
    for key, value in pairs(self.Config.ChatCommands) do
        if cmd == key then
            -- Check if command is admin only
            if self.Config.ChatCommands[key].admin then
                -- Check if user has permission to use command
                if IsAdmin(player) then
                    -- Output the text
                    for k, v in pairs(self.Config.ChatCommands[key].text) do
                        rust.SendChatMessage(player, self.Config.Settings.ChatName, self.Config.ChatCommands[key].text[k])
                    end
                end
            else
                -- Command can be used by everyone
                for k, v in pairs(self.Config.ChatCommands[key].text) do
                    rust.SendChatMessage(player, self.Config.Settings.ChatName, self.Config.ChatCommands[key].text[k])
                end
            end
        end
    end
end

function PLUGIN:SendHelpText(player)
    for key, value in pairs(self.Config.ChatCommands) do
        if self.Config.ChatCommands[key].helptext and self.Config.ChatCommands[key] ~= "" then
            if self.Config.ChatCommands[key].admin then
                if IsAdmin(player) then
                    rust.SendChatMessage(player, self.Config.Settings.ChatName, self.Config.ChatCommands[key].helptext)
                end
            else
                rust.SendChatMessage(player, self.Config.Settings.ChatName, self.Config.ChatCommands[key].helptext)
            end
        end
    end
end