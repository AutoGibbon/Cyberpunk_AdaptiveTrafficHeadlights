local Settings = require("modules/settings")
local Theme = require("modules/theme")
local UI = require("modules/ui")
local Cron = require("modules/Cron")

local ERROR_MESSAGES = {
    WEATHER_SYSTEM_NOT_AVAILABLE = "Weather system not available",
    WEATHER_ENVIRONMENT_NOT_AVAILABLE = "Weather environment definition not available",
    TIME_SYSTEM_NOT_AVAILABLE = "Time system not available",
    GAME_TIME_NOT_AVAILABLE = "Game time not available",
    INVALID_ENV = "Invalid .env"
}

S = {
    settings                = Settings.defaultSettings(),
    weatherStates           = {},
    headlightColors         = Settings.defaultHeadlightColors(),
    headlightCategories     = Settings.defaultHeadlightCategories(),
    vehicleCategories       = Settings.defaultVehicleCategories(),
    lightsShouldBeOn        = false,
    lightTransitionFactor   = 1,
    lastLightDecisionTime   = -1,
    playerSpawned           = false,
    cetOpen                 = false,
    cetLightOverrideColor   = nil,
    cetLightOverrideName    = nil,
    cetLightOverrideChecked = false,
    foundEnv                = false,
    gotWeatherStates        = false,
    state                   = "none",
    lastState               = "none",
    hours                   = 0,
    minutes                 = 0,
    currentTime             = 0,
    lastUpdateTime          = 0,
    errors                  = {},
    cls                     = nil,
    streetLightsSetOnce     = false,
    streetLightsOn          = false,
    weatherChanged          = false,
    timeWasSkipped          = false
}


registerForEvent("onOverlayOpen", function()
    S.cetOpen = true
end)

registerForEvent("onOverlayClose", function()
    S.cetOpen = false
end)

registerForEvent("onDraw", function()
    if not S.cetOpen then return end
    UI.DrawMainWindow()
    --UI.DrawDummyWindow()
end)

local colorNames = {}
local colorCount = 0
local vehicleToCategory = {}

function BuildMappings()
    --build colorNames array for random selection
    for colorName, _ in pairs(S.headlightColors) do
        colorCount = colorCount + 1
        colorNames[colorCount] = colorName
    end

    -- Build reverse lookup table for O(1) vehicle category lookup
    for category, vehicles in pairs(S.vehicleCategories) do
        for _, vehicleName in ipairs(vehicles) do
            vehicleToCategory[vehicleName] = category
        end
    end

    if #vehicleToCategory and #colorNames then
        print("[AdaptiveTrafficHeadlights] Vehicles and Headlights config loaded and ready.")
    end
end

local floor = math.floor
local max = math.max
local min = math.min
function AdjustBrightness(colorProfile, multiplier)
    -- Clamp multiplier to reasonable bounds
    local alpha = colorProfile.Alpha
    if multiplier == 0.0 then alpha = 255 end

    local adjustedColor = {
        Red = floor(colorProfile.Red * multiplier + 0.5), -- Round to nearest whole number
        Green = floor(colorProfile.Green * multiplier + 0.5),
        Blue = floor(colorProfile.Blue * multiplier + 0.5),
        Alpha = alpha
    }

    -- Ensure values stay within 0-255 range
    adjustedColor.Red = max(0, min(255, adjustedColor.Red))
    adjustedColor.Green = max(0, min(255, adjustedColor.Green))
    adjustedColor.Blue = max(0, min(255, adjustedColor.Blue))

    return adjustedColor
end

local function CalculateLightState(turnOnTime, turnOffTime)
    -- Calculate sliding value for light decision timing
    S.currentTime = S.hours + S.minutes / 60.0
    local timeDelta = (S.currentTime - S.lastUpdateTime + 24) % 24

    -- Detect time jump (accounting for day rollover)
    if S.lastUpdateTime > 0 and timeDelta > 2.0 and timeDelta < 23.5 then
        S.timeWasSkipped = true
        print("[AdaptiveTrafficHeadlights] Time jump detected: " ..
            timeDelta .. " hours, lights will be updated immediately")
    end

    -- Determine if lights should be on
    if S.currentTime >= turnOnTime or S.currentTime < turnOffTime then
        if not S.timeWasSkipped and (not S.lightsShouldBeOn or S.lastLightDecisionTime == -1) then
            S.lastLightDecisionTime = S.currentTime
        end
        S.lightsShouldBeOn = true
    elseif S.currentTime < turnOnTime and S.currentTime >= turnOffTime then
        if not S.timeWasSkipped and (S.lightsShouldBeOn or S.lastLightDecisionTime == -1) then
            S.lastLightDecisionTime = S.currentTime
        end
        S.lightsShouldBeOn = false
    end

    local timeToOn = (turnOnTime - S.currentTime + 24) % 24
    local timeToOff = (turnOffTime - S.currentTime + 24) % 24
    local timeSinceLastDecision = (S.lastLightDecisionTime - S.currentTime + 24) % 24

    if timeSinceLastDecision <= 1 or timeSinceLastDecision >= 23 then
        --print("time since last decision: " .. timeSinceLastDecision)
        -- Within 1 hour of the last decision, allows vehicles to appear to be reacting naturally to changing conditions
        local distance = min(timeSinceLastDecision, 24 - timeSinceLastDecision)
        S.lightTransitionFactor = 0.5 + (distance / 2.0)
    elseif timeToOn <= 1 or timeToOn >= 23 then
        --print("time to on: " .. timeToOn)
        -- Within 1 hour of turn ON time
        local distance = min(timeToOn, 24 - timeToOn)
        S.lightTransitionFactor = 0.5 + (distance / 2.0)
    elseif timeToOff <= 1 or timeToOff >= 23 then
        --print("time to off: " .. timeToOff)
        -- Within 1 hour of turn OFF time
        local distance = min(timeToOff, 24 - timeToOff)
        S.lightTransitionFactor = 0.5 + (distance / 2.0)
    else
        S.lightTransitionFactor = 1.0
    end

    UpdateStreetLights()
    S.timeWasSkipped = false
    S.lastUpdateTime = S.currentTime
end

-- runs every 10 seconds
function Update()
    if not S.gotWeatherStates then return end
    S.hours = Game.GetTimeSystem():GetGameTime():Hours()
    S.minutes = Game.GetTimeSystem():GetGameTime():Minutes()
    local state = tostring(Game.GetWeatherSystem():GetWeatherState().name.value)

    -- track weather changes for light decision timing
    if S.state ~= state then
        if S.lastState == "none" then
            S.lastState = state
        else
            S.weatherChanged = true
            S.lastState = S.state
        end
        S.state = state
    end

    if not S.settings.adjustAllWeatherStates then
        local stateFound = false
        for i, v in ipairs(S.weatherStates) do
            if v.name and v.name == S.state then
                stateFound = true
            end
            if stateFound then
                CalculateLightState(v.turnOnTime, v.turnOffTime)
                break
            end
        end
    else
        CalculateLightState(S.settings.allOnTime, S.settings.allOffTime)
    end

    S.playerSpawned = true
end

function UpdateStreetLights()
    if not S.settings.enableStreetLightControl then return end
    S.cls = S.cls or Game.GetScriptableSystemsContainer():Get("CityLightSystem")
    if not S.cls then return end

    -- Use transition factor only when weather changed and caused a light decision
    -- If weather changed and caused a light decision, streetlights should turn on/off when transition factor > 0.75
    local shouldUpdateLights = false

    if S.lightsShouldBeOn and (not S.streetLightsOn or not S.streetLightsSetOnce) then
        -- Check if we should delay the light change due to weather change + transition factor
        -- But always apply initial state (when streetLightsSetOnce is false)
        -- Only apply natural mode delay if useNaturalMode is enabled
        -- Skip delays if timeskip just finished
        if not S.streetLightsSetOnce or S.timeWasSkipped or not (S.settings.useNaturalMode and S.weatherChanged and S.lightTransitionFactor <= 0.75) then
            shouldUpdateLights = true
        end
    elseif not S.lightsShouldBeOn and (S.streetLightsOn or not S.streetLightsSetOnce) then
        -- Check if we should delay the light change due to weather change + transition factor
        -- But always apply initial state (when streetLightsSetOnce is false)
        -- Only apply natural mode delay if useNaturalMode is enabled
        -- Skip delays if timeskip just finished
        if not S.streetLightsSetOnce or S.timeWasSkipped or not (S.settings.useNaturalMode and S.weatherChanged and S.lightTransitionFactor <= 0.75) then
            shouldUpdateLights = true
        end
    end

    --[[
		print(("Lon:%s Son:%s Sonce:%s WC:%s TR:%.2f UD:%s"):format(
		tostring(S.lightsShouldBeOn), tostring(S.streetLightsOn), tostring(S.streetLightsSetOnce),
		tostring(S.weatherChanged), S.lightTransitionFactor, tostring(shouldUpdateLights)))
		]] --

    if shouldUpdateLights then
        if S.lightsShouldBeOn then
            print("[AdaptiveTrafficHeadlights] street lights on")
            local request = ForceCLSStateRequest.new()
            request.state = ECLSForcedState.ForcedON
            request.sourceName = CName.new("PlayerPuppet")
            request.priority = EPriority.Absolute
            request.removePreviousRequests = true
            request.savable = false
            S.cls:QueueRequest(request)
            S.streetLightsOn = true
            S.streetLightsSetOnce = true
        else
            print("[AdaptiveTrafficHeadlights] street lights off")
            local request = ForceCLSStateRequest.new()
            request.state = ECLSForcedState.ForcedOFF
            request.sourceName = CName.new("PlayerPuppet")
            request.priority = EPriority.Absolute
            request.removePreviousRequests = true
            request.savable = false
            S.cls:QueueRequest(request)
            S.streetLightsOn = false
            S.streetLightsSetOnce = true
        end
        -- Reset weather change flag and timeskip flag after applying street light changes
        S.weatherChanged = false
    end
end

function TryGetWeatherData()
    if S.gotWeatherStates then return end
    S.errors = {}

    S.cls = Game.GetScriptableSystemsContainer():Get("CityLightSystem")

    if not Game.GetWeatherSystem() then
        table.insert(S.errors, ERROR_MESSAGES.WEATHER_SYSTEM_NOT_AVAILABLE)
    end

    if not Game.GetWeatherSystem():GetEnvironmentDefinition() then
        table.insert(S.errors, ERROR_MESSAGES.WEATHER_ENVIRONMENT_NOT_AVAILABLE)
    end

    if not Game.GetTimeSystem() then
        table.insert(S.errors, ERROR_MESSAGES.TIME_SYSTEM_NOT_AVAILABLE)
    end

    if not Game.GetTimeSystem():GetGameTime() then
        table.insert(S.errors, ERROR_MESSAGES.GAME_TIME_NOT_AVAILABLE)
    end

    if #S.errors > 0
        or Game.GetSystemRequestsHandler():IsPreGame()
        or Game.GetSystemRequestsHandler():IsGamePaused() then
        return
    end
    print("[AdaptiveTrafficHeadlights] Loading weather data from file or game systems")
    if not S.foundEnv then
        if Game.GetWeatherSystem():GetEnvironmentDefinition().path then
            local path = Game.GetWeatherSystem():GetEnvironmentDefinition().path:ToString()
            if path and not string.find(path:lower(), "v002") then
                S.foundEnv = true
            else
                table.insert(S.errors, ERROR_MESSAGES.INVALID_ENV)
                table.insert(S.errors, path)
                if not path then
                    table.insert(S.errors, "no path???")
                end
            end
        end
    end
    if S.foundEnv and not S.gotWeatherStates then
        local tempStates = Game.GetWeatherSystem():GetEnvironmentDefinition().weatherStates
        local isFound = false
        for i, v in ipairs(tempStates) do
            if v.name then
                local stateName = tostring(v.name.value)
                if #S.weatherStates > 0 then
                    for j, k in ipairs(S.weatherStates) do
                        if stateName == k.name then
                            isFound = true
                            break
                        end
                    end
                    if not isFound then
                        table.insert(S.weatherStates, { name = stateName, turnOnTime = 19, turnOffTime = 7 })
                    end
                else
                    table.insert(S.weatherStates, { name = stateName, turnOnTime = 19, turnOffTime = 7 })
                end
            end
        end
        Settings.SaveWeatherStates()
        S.gotWeatherStates = true
        print("[AdaptiveTrafficHeadlights] Weather data loaded")
    end
end

function TryFirstUpdate()
    if S.playerSpawned
        or not S.gotWeatherStates
        or not Game.GetWeatherSystem()
        or Game.GetSystemRequestsHandler():IsPreGame()
        or Game.GetSystemRequestsHandler():IsGamePaused()
        or not Game.GetTimeSystem()
        or not Game.GetTimeSystem():GetGameTime()
    then
        return
    end

    if not S.playerSpawned then
        Update()
    end
end

local cronCallback = function()
    if Game.GetSystemRequestsHandler():IsPreGame() or Game.GetSystemRequestsHandler():IsGamePaused() or not Game.GetTimeSystem() or not Game.GetTimeSystem():GetGameTime() then return end

    if S.gotWeatherStates and S.playerSpawned then
        Update()
    end
end

registerForEvent('onInit', function()
    Settings.LoadSettings()
    Settings.LoadWeatherStates()
    Settings.LoadHeadlightsAndVehicles()
    BuildMappings()

    -- support startup mid session
    TryGetWeatherData()
    TryFirstUpdate()

    Override("WeatherScriptListener", "OnRainIntensityChanged", function(this, rainIntensity, wrappedMethod)
        if not S.playerSpawned then return wrappedMethod(rainIntensity) end
        return
    end)
    Override("WeatherScriptListener", "OnRainIntensityTypeChanged", function(this, rainIntensityType, wrappedMethod)
        if not S.playerSpawned then return wrappedMethod(rainIntensityType) end
        return
    end)

    Override("CLSWeatherListener", "OnRainIntensityChanged", function(this, rainIntensity, wrappedMethod)
        if not S.playerSpawned then return wrappedMethod(rainIntensity) end
        return
    end)
    Override("CLSWeatherListener", "OnRainIntensityTypeChanged", function(this, rainIntensityType, wrappedMethod)
        if not S.playerSpawned then return wrappedMethod(rainIntensityType) end
        return
    end)

    Override("CLSWeatherListener", "TurnOnLights", function(this, reason, wrappedMethod)
        if not S.playerSpawned then return wrappedMethod(reason) end
        if reason.value == "PlayerPuppet" then
            return wrappedMethod(reason)
        end
        return
    end)
    Override("CLSWeatherListener", "TurnOffLights", function(this, reason, wrappedMethod)
        if not S.playerSpawned then return wrappedMethod(reason) end
        if reason.value == "PlayerPuppet" then
            return wrappedMethod(reason)
        end
        return
    end)

    Observe("TimeskipGameController", "OnCloseAfterFinishing",
        ---@param proxy inkAnimProxy
        function(proxy)
            -- Set flag to negate any delayed streetlight updates after timeskip
            -- The next update cycle will detect this and apply changes immediately
            S.timeWasSkipped = true
            print("[AdaptiveTrafficHeadlights] Timeskip finished - streetlight update queued")
        end)

    Observe("vehicleBaseObject", "OnGameAttached",
        ---@param vehicle VehicleObject
        function(vehicle)
            if not vehicle:IsVehicle()
                or vehicle:IsPlayerVehicle()
                or not vehicle:IsCrowdVehicle()
                or vehicle:IsAbandoned()
            then
                return
            end

            --shift the lights update logic to a delayed callback to increase compatibility with mods that do funky shenanigans with cycling appearances
            Cron.After(0.1, function()
                if not IsDefined(vehicle)
                    or not vehicle:GetVehicleComponent()
                    or not vehicle:GetVehicleComponent():GetVehicleController()
                then
                    return
                end

                -- using transition factor here allows vehicles to have delayed response to weather state changes
                -- but also turn on and off a bit earlier and later than the desired time, to make it more realistic
                local lightsShouldBeOn = S.lightsShouldBeOn
                if S.settings.useNaturalMode and S.lightTransitionFactor < 1.0 and math.random() > S.lightTransitionFactor then
                    lightsShouldBeOn = not lightsShouldBeOn
                end

                -- Get vehicle name and find appropriate headlight color
                local vehicleController = vehicle:GetVehicleComponent():GetVehicleController()
                local vehicleName = tostring(vehicle:GetRecord():GetID().value)
                local vehicleCategory = vehicleToCategory[vehicleName]
                local headlightCategory = vehicleCategory and S.headlightCategories[vehicleCategory] or nil
                local colorName = headlightCategory and headlightCategory[math.random(1, #headlightCategory)] or
                    colorNames[math.random(1, colorCount)]

                --print("[AdaptiveTrafficHeadlights] Vehicle: " ..(vehicleName or "unknown") .." | Category: " .. (vehicleCategory or "none") .. " | Color: " .. colorName)
                local selectedColor = S.headlightColors[colorName]
                if S.cetLightOverrideColor ~= nil then
                    selectedColor = S.cetLightOverrideColor
                end
                local multiplier = lightsShouldBeOn and 1.0 or
                    max(0, min(S.settings.lightsOffBrightnessMultiplier, 1.0))

                local dimmedColor = AdjustBrightness(selectedColor, multiplier)
                local applyColor = Color.new({
                    Red = dimmedColor.Red,
                    Green = dimmedColor.Green,
                    Blue = dimmedColor.Blue,
                    Alpha = dimmedColor.Alpha
                })
                local applycolorTbd = { dimmedColor.Red, dimmedColor.Green, dimmedColor.Blue, dimmedColor.Alpha }

                -- Apply to vehicle
                TweakDB:SetFlat(vehicle:GetRecord():GetID().value .. ".headlightColor", applycolorTbd)

                vehicleController:SetLightColor(vehicleELightType.Head, applyColor, 0)
                vehicleController:SetLightParameters(vehicleELightType.Head, multiplier, applyColor, 0)
                vehicleController:SetLightStrength(vehicleELightType.Head, multiplier, 0)

                if multiplier == 0.0 then
                    vehicleController:ToggleLights(false, vehicleELightType.Head)
                end

                if lightsShouldBeOn then
                    vehicleController:ToggleLights(true)
                    return
                end
                local otherLightsOffColor = Color.new({ Red = 0, Blue = 0, Green = 0, Alpha = 255 })
                if S.settings.turnOffBrakeLights then
                    vehicleController:SetLightColor(vehicleELightType.Brake, otherLightsOffColor, 0)
                    vehicleController:SetLightParameters(vehicleELightType.Brake, 0, otherLightsOffColor, 0)
                    vehicleController:SetLightStrength(vehicleELightType.Brake, 0, 0)
                    vehicleController:ToggleLights(false, vehicleELightType.Brake)
                end

                if S.settings.turnOffBlinkers then
                    vehicleController:SetLightColor(vehicleELightType.Blinkers, otherLightsOffColor, 0)
                    vehicleController:SetLightParameters(vehicleELightType.Blinkers, 0, otherLightsOffColor, 0)
                    vehicleController:SetLightStrength(vehicleELightType.Blinkers, 0, 0)
                    vehicleController:ToggleLights(false, vehicleELightType.Blinkers)
                end

                if S.settings.turnOffUtilityLights then
                    vehicleController:SetLightColor(vehicleELightType.Utility, otherLightsOffColor, 0)
                    vehicleController:SetLightParameters(vehicleELightType.Utility, 0, otherLightsOffColor, 0)
                    vehicleController:SetLightStrength(vehicleELightType.Utility, 0, 0)
                    vehicleController:ToggleLights(false, vehicleELightType.Utility)
                end
            end, nil)
        end)

    Observe("PlayerPuppet", "OnMakePlayerVisibleAfterSpawn", function(this, evt)
        S.playerSpawned = false
        S.streetLightsSetOnce = false
        S.streetLightsOn = false
        S.weatherChanged = false
        S.lastLightDecisionTime = -1
        S.cls = nil
        TryGetWeatherData()
    end)

    ObserveAfter("PlayerPuppet", "OnMakePlayerVisibleAfterSpawn", function(this, evt)
        S.playerSpawned = false
        S.streetLightsSetOnce = false
        S.streetLightsOn = false
        S.weatherChanged = false
        S.lastLightDecisionTime = -1
        S.cls = nil
        TryFirstUpdate()
    end)

    Observe("LoadGameMenuGameController", "LoadGame", function(this, controller)
        S.playerSpawned = false
        S.streetLightsSetOnce = false
        S.streetLightsOn = false
        S.weatherChanged = false
        S.lastLightDecisionTime = -1
        S.cls = nil
    end)
    Observe("inkISystemRequestsHandler", "LoadLastCheckpoint", function(this, onlySamePlaythrough)
        S.playerSpawned = false
        S.streetLightsSetOnce = false
        S.streetLightsOn = false
        S.weatherChanged = false
        S.timeWasSkipped = false
        S.lastLightDecisionTime = -1
        S.cls = nil
    end)
    Observe("inkISystemRequestsHandler", "LoadSavedGame", function(this, saveId)
        S.playerSpawned = false
        S.streetLightsSetOnce = false
        S.streetLightsOn = false
        S.weatherChanged = false
        S.timeWasSkipped = false
        S.lastLightDecisionTime = -1
        S.cls = nil
    end)

    Cron.Every(10.0, cronCallback, nil)
    print("[AdaptiveTrafficHeadlights] Initialized. Load a save to complete mod startup!")
end)

registerForEvent('onUpdate', function(delta)
    Cron.Update(delta)
end)
