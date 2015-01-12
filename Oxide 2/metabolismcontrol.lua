PLUGIN.Title        = "Metabolism Control"
PLUGIN.Description  = "Allows you to control metabolism stats"
PLUGIN.Author       = "#Domestos"
PLUGIN.Version      = V(1, 1, 0)
PLUGIN.HasConfig    = true
PLUGIN.ResourceID   = 680

local debug = false
-- for debug purposes
local lastCalories = 1000
local lastHydration = 1000
local lastHealth = 1
-- ------------------------


function PLUGIN:Init()
    self:LoadDefaultConfig()
end

function PLUGIN:LoadDefaultConfig()
    self.Config.Settings = self.Config.Settings or {}
    -- Health
    self.Config.Settings.Health = self.Config.Settings.Health or {}
    self.Config.Settings.Health.maxValue = self.Config.Settings.Health.maxValue or 100
    self.Config.Settings.Health.spawnValue = self.Config.Settings.Health.spawnValue or "default"
    self.Config.Settings.Health.gainRate = self.Config.Settings.Health.gainRate or "default"
    -- Calories
    self.Config.Settings.Calories = self.Config.Settings.Calories or {}
    self.Config.Settings.Calories.maxValue = self.Config.Settings.Calories.maxValue or 1000
    self.Config.Settings.Calories.spawnValue = self.Config.Settings.Calories.spawnValue or "default"
    self.Config.Settings.Calories.loseRate = self.Config.Settings.Calories.loseRate or "default"
    -- Hydration
    self.Config.Settings.Hydration = self.Config.Settings.Hydration or {}
    self.Config.Settings.Hydration.maxValue = self.Config.Settings.Hydration.maxValue or 1000
    self.Config.Settings.Hydration.spawnValue = self.Config.Settings.Hydration.spawnValue or "default"
    self.Config.Settings.Hydration.loseRate = self.Config.Settings.Hydration.loseRate or "default"

    self:SaveConfig()
end

function PLUGIN:OnPlayerSpawn(player)
    self:SetMetabolismValues(player)
end

function PLUGIN:OnPlayerInit(player)
    self:SetMetabolismValues(player)
end

-- ----------------------------
-- Rust default rates
-- ----------------------------
-- healthgain = 0.03
-- caloriesloss = 0 - 0.05
-- hydrationloss = 0 - 0.025
-- ----------------------------
function PLUGIN:OnRunPlayerMetabolism(metabolism)
    local caloriesLoseRate = self.Config.Settings.Calories.loseRate
    local hydrationLoseRate = self.Config.Settings.Hydration.loseRate
    local healthGainRate = self.Config.Settings.Health.gainRate
    local heartRate = metabolism.heartrate.value
    if caloriesLoseRate ~= "default" then
        if calorieLoseRate == 0 or calorieLoseRate == "0" then
            metabolism.calories.value = metabolism.calories.value
        else
            metabolism.calories.value = metabolism.calories.value - (tonumber(caloriesLoseRate) + (heartRate / 10))
        end
    end
    if hydrationLoseRate ~= "default" then
        if hydrationLoseRate == 0 or hydrationLoseRate == "0" then
            metabolism.hydration.value = metabolism.hydration.value
        else
            metabolism.hydration.value = metabolism.hydration.value - (tonumber(hydrationLoseRate) + (heartRate / 10))
        end
    end
    if healthGainRate ~= "default" then
        if healthGainRate == 0 or healthGainRate == "0" then
            metabolism.health.value = metabolism.health.value
        else
            metabolism.health.value = metabolism.health.value + tonumber(healthGainRate) - 0.03
        end
    end
    if debug then
        self:DebugPrints(metabolism)
    end
end

function PLUGIN:SetMetabolismValues(player)
    local maxHydration = tonumber(self.Config.Settings.Hydration.maxValue)
    local maxCalories = tonumber(self.Config.Settings.Calories.maxValue)
    local maxHealth = tonumber(self.Config.Settings.Health.maxValue)
    local hydrationValue, caloriesValue, healthValue = false, false, false
    if self.Config.Settings.Hydration.spawnValue ~= "default" then
        hydrationValue = tonumber(self.Config.Settings.Hydration.spawnValue)
    end
    if self.Config.Settings.Calories.spawnValue ~= "default" then
        caloriesValue = tonumber(self.Config.Settings.Calories.spawnValue)
    end
    if self.Config.Settings.Health.spawnValue ~= "default" then
        healthValue = tonumber(self.Config.Settings.Health.spawnValue)
    end
    player.metabolism.calories.max = maxCalories
    player.metabolism.health.max = maxHealth
    player.metabolism.hydration.max = maxHydration
    if healthValue then
        player.metabolism.health.value = healthValue
    else
        player.metabolism.health.value = maxHealth
    end
    if caloriesValue then
        player.metabolism.calories.value = caloriesValue
    end
    if hydrationValue then
        player.metabolism.hydration.value = hydrationValue
    end
end

function PLUGIN:DebugPrints(metabolism)
    local diffCalories = lastCalories - metabolism.calories.value
    local diffHydration = lastHydration - metabolism.hydration.value
    local diffHealth = metabolism.health.value - lastHealth
    print("calories: "..metabolism.calories.value)
    print("health: "..metabolism.health.value)
    print("hydration: "..metabolism.hydration.value)
    print("temperature: "..metabolism.temperature.value)
    print("heartrate: "..metabolism.heartrate.value)
    print("diffcalories: "..tostring(diffCalories))
    print("diffhydration: "..tostring(diffHydration))
    print("diffhealth: "..tostring(diffHealth))
    print("---------------------------------------------------")
    lastCalories = metabolism.calories.value
    lastHydration = metabolism.hydration.value
    lastHealth = metabolism.health.value
end