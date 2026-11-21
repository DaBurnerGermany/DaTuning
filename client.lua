local active, opening = nil, false
local cameraFov = 48.0
local spectators = {}
local allowedClasses = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true,
    [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true,
    [11] = true, [12] = true, [17] = true, [18] = true, [19] = true, [20] = true, [22] = true }
local wheelGroups = {
    'Sport', 'Muscle', 'Lowrider', 'SUV', 'Offroad', 'Tuner', 'Motorrad',
    'High End', 'Benny’s Original', 'Benny’s Maßanfertigung', 'Open Wheel', 'Street', 'Track'
}
local tints = { 'Serie', 'Schwarz', 'Dunkel', 'Leicht', 'Original', 'Limousine', 'Grün' }
local xenon = {
    { 'Weiß (Serie)', 224, 237, 255 }, { 'Weiß', 255, 255, 255 },
    { 'Blau', 47, 102, 255 }, { 'Hellblau', 42, 188, 255 },
    { 'Mint', 66, 255, 188 }, { 'Limette', 115, 255, 45 },
    { 'Gelb', 255, 238, 44 }, { 'Gold', 255, 190, 40 },
    { 'Orange', 255, 120, 20 }, { 'Rot', 255, 41, 36 },
    { 'Rosa', 255, 137, 190 }, { 'Pink', 255, 43, 166 },
    { 'Violett', 164, 70, 255 }, { 'Schwarzlicht', 79, 30, 204 }
}
local combinedOptionsById = {
    underbody = { colorId = 'neonColor', colors = Config.RGB, offset = 0 },
    modXenon = { colorId = 'xenonColor', colors = xenon, offset = 1 },
    modSmokeEnabled = { colorId = 'tyreSmokeColor', colors = Config.RGB, offset = 0, offLabel = 'Serie', offSwatch = '#b6b5b3' }
}
local tyreLetteringIds = { 'modCustomFrontWheels', 'modCustomBackWheels' }
local hornNames = {
    [0] = 'Lkw-Hupe', 'Polizeihupe', 'Clownhupe',
    'Melodie 1', 'Melodie 2', 'Melodie 3', 'Melodie 4', 'Melodie 5', 'Traurige Posaune',
    'Klassik 1', 'Klassik 2', 'Klassik 3', 'Klassik 4', 'Klassik 5', 'Klassik 6', 'Klassik 7',
    'Tonleiter · Do', 'Tonleiter · Re', 'Tonleiter · Mi', 'Tonleiter · Fa',
    'Tonleiter · Sol', 'Tonleiter · La', 'Tonleiter · Ti', 'Tonleiter · Do (hoch)',
    'Jazz 1', 'Jazz 2', 'Jazz 3', 'Jazz (Schleife)',
    'US-Hymne 1', 'US-Hymne 2', 'US-Hymne 3', 'US-Hymne 4',
    'Klassik 8 (Schleife)', 'Klassik 9 (Schleife)', 'Klassik 10 (Schleife)',
    'Klassik 8', 'Klassik 9', 'Klassik 10',
    'Bestattung (Schleife)', 'Bestattung', 'Grusel (Schleife)', 'Grusel',
    'San Andreas (Schleife)', 'San Andreas', 'Liberty City (Schleife)', 'Liberty City',
    'Festlich 1 (Schleife)', 'Festlich 1', 'Festlich 2 (Schleife)', 'Festlich 2',
    'Festlich 3 (Schleife)', 'Festlich 3',
    'Drucklufthorn tief (Schleife)', 'Drucklufthorn tief', 'Drucklufthorn mittel (Schleife)',
    'Drucklufthorn mittel', 'Drucklufthorn hoch (Schleife)', 'Drucklufthorn hoch'
}
local loopingHorns = {
    [27] = true, [32] = true, [33] = true, [34] = true, [38] = true, [40] = true,
    [42] = true, [44] = true, [46] = true, [48] = true, [50] = true, [52] = true,
    [54] = true, [56] = true
}

local function hasWorkshopJob()
    local framework, core = TuningFramework.Resolve()
    if not core then return false end
    local data = core.PlayerData
    if framework == 'qbcore' then data = core.Functions.GetPlayerData() end
    local job = data and data.job
    return job and Config.Jobs[job.name] == true
end

local function stillDriving(vehicle)
    local ped = PlayerPedId()
    return DoesEntityExist(vehicle) and not IsEntityDead(ped)
        and GetPedInVehicleSeat(vehicle, -1) == ped
end

local function notify(message)
    local framework, core = TuningFramework.Resolve()
    if framework == 'esx' then
        core.ShowNotification(message)
    elseif framework == 'qbcore' then
        core.Functions.Notify(message)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

local function server(name, ...)
    local framework, core = TuningFramework.Resolve()
    local callback = 'DaTuning:' .. name
    local ok, response
    if framework == 'esx' then
        ok, response = pcall(core.AwaitServerCallback, callback, ...)
    elseif framework == 'qbcore' then
        local pending = promise.new()
        ok = pcall(core.Functions.TriggerCallback, callback, function(result) pending:resolve(result) end, ...)
        if ok then
            SetTimeout(15000, function() pending:resolve(false) end)
            response = Citizen.Await(pending)
        end
    end
    if ok and response then return response end
    return { ok = false, message = TuningText('Die Werkstatt hat keine Antwort erhalten.') }
end

local function close()
    local session = active
    if not session then return end
    active = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if session.cameraRendering then RenderScriptCams(false, false, 0, true, true) end
    if DoesCamExist(session.camera) then DestroyCam(session.camera, false) end
    if DoesEntityExist(session.preview) then DeleteVehicle(session.preview) end
    if DoesEntityExist(session.vehicle) and not session.wasFrozen then
        FreezeEntityPosition(session.vehicle, false)
    end
    DisplayRadar(not session.radarHidden)
    TriggerServerEvent('DaTuning:close')
end

local function gameLabel(label, fallback)
    if label and label ~= '' then
        local text = GetLabelText(label)
        if text and text ~= '' and text ~= 'NULL' then return text end
    end
    return fallback
end

local function apply(vehicle, props, changes, repair)
    if repair then
        local fuel = GetVehicleFuelLevel(vehicle)
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleFuelLevel(vehicle, fuel)
    end
    if changes.color1 ~= nil then ClearVehicleCustomPrimaryColour(vehicle) end
    if changes.color2 ~= nil then ClearVehicleCustomSecondaryColour(vehicle) end
    if changes.xenonColor ~= nil and ClearVehicleXenonLightsCustomColor then
        ClearVehicleXenonLightsCustomColor(vehicle)
    end

    local framework, core = TuningFramework.Resolve()
    if framework == 'esx' then
        core.Game.SetVehicleProperties(vehicle, props)
    elseif framework == 'qbcore' then
        core.Functions.SetVehicleProperties(vehicle, TuningFramework.ToQBProperties(props))
        -- QB's setter skips false toggle values and has no bulletproof tyre field.
        if props.modTurbo == false then ToggleVehicleMod(vehicle, 18, false) end
        if props.modXenon == false then ToggleVehicleMod(vehicle, 22, false) end
        if props.tyresCanBurst ~= nil then SetVehicleTyresCanBurst(vehicle, props.tyresCanBurst) end
    else
        error('DaTuning framework unavailable')
    end
    -- The ESX setter always enables tyre smoke and does not set slot 49.
    if props.modSmokeEnabled ~= nil then ToggleVehicleMod(vehicle, 20, props.modSmokeEnabled) end
    if props.modLightbar ~= nil then SetVehicleMod(vehicle, 49, props.modLightbar, false) end
end

local function stopPreviewSound(session)
    local playback = session.soundPlayback
    session.soundPlayback = nil
    if not playback or not DoesEntityExist(session.preview) then return end
    if playback.revving then SetVehicleCurrentRpm(session.preview, 0.18) end
    if playback.engineStarted then SetVehicleEngineOn(session.preview, false, true, true) end
end

local function renderPreview(session)
    local preview, baseline, changes = session.preview, session.baseline, session.changes
    stopPreviewSound(session)
    apply(preview, baseline, {}, true)
    local patch = Config.VehiclePatch(baseline, changes)
    if next(patch) then apply(preview, patch, changes, changes.repair ~= nil) end

    -- GTA displays the underglow with the vehicle lights on.
    local neon = patch.neonEnabled or baseline.neonEnabled or {}
    local showNeon = neon[1] or neon[2] or neon[3] or neon[4]
    local showXenon = IsToggleModOn(preview, 22) or changes.xenonColor ~= nil
    SetVehicleLights(preview, (showNeon or showXenon) and 2 or 0)
end

local function currentValue(entry, baseline)
    local id, kind = entry.id, entry.kind
    if kind == 'neon' then
        local lights = baseline.neonEnabled
        if not lights then return 0 end
        for i = 2, 4 do
            if lights[i] ~= lights[1] then return -100 end
        end
        return lights[1] and 1 or 0
    end
    if kind == 'extra' then return baseline.extras[tostring(entry.slot)] and 1 or 0 end
    if kind == 'inverse' then return baseline[id] == false and 1 or 0 end
    if kind == 'toggle' or kind == 'variation' then return baseline[id] and 1 or 0 end
    if kind == 'xenon' then
        if baseline.customXenonColor then return -100 end
        local value = baseline[id]
        if value == nil or value < 0 or value >= 13 then return 0 end
        return value + 1
    end
    if kind == 'rgb' then
        local col = baseline[id]
        for i, rgb in ipairs(Config.RGB) do
            if col and col[1] == rgb[2] and col[2] == rgb[3] and col[3] == rgb[4] then return i end
        end
        return -100
    end
    if kind == 'repair' then return 0 end
    if (id == 'color1' and baseline.customPrimaryColor) or (id == 'color2' and baseline.customSecondaryColor) then
        return -100
    end
    return baseline[id] or entry.min
end

local function combinedOptions(session, entry, spec)
    if entry.id == 'underbody' and session.isBike then return end
    local colorEntry = Config.ById[spec.colorId]
    local enabled = currentValue(entry, session.baseline)
    local color = currentValue(colorEntry, session.baseline)
    local colorChoice = color < 0 and color or color + spec.offset
    local current = enabled == 0 and 0 or enabled == 1 and colorChoice or -100
    local selected = current
    if session.changes[entry.id] == 0 then
        selected = 0
    elseif session.changes[entry.id] == 1 or session.changes[spec.colorId] ~= nil then
        selected = (session.changes[spec.colorId] or color) + spec.offset
    end
    local options = { { value = 0, label = TuningText(spec.offLabel or 'Keine'), price = 0, swatch = spec.offSwatch } }
    if current < 0 then
        local smokeColor = entry.id == 'modSmokeEnabled' and session.baseline.tyreSmokeColor
        options[#options + 1] = { value = current, label = TuningText('Vorhanden'), price = 0,
            swatch = smokeColor and ('#%02x%02x%02x'):format(smokeColor[1], smokeColor[2], smokeColor[3]) or nil }
    end
    for index, option in ipairs(spec.colors) do
        local price = enabled ~= 1 and Config.Price(entry, 1) or 0
        if index ~= colorChoice then price = price + Config.Price(colorEntry, index - spec.offset) end
        options[#options + 1] = { value = index, label = TuningText(option[1]), price = price,
            swatch = ('#%02x%02x%02x'):format(option[2], option[3], option[4]) }
    end
    return { id = entry.id, name = entry.label, group = entry.group, options = options,
        current = current, selected = selected }
end

local function stageCombinedOption(session, item, value, spec)
    local changes = session.changes
    changes[item.id], changes[spec.colorId] = nil, nil
    if value == item.current then return end
    if value == 0 then
        changes[item.id] = 0
        return
    end
    if currentValue(Config.ById[item.id], session.baseline) ~= 1 then changes[item.id] = 1 end
    local color = value - spec.offset
    if currentValue(Config.ById[spec.colorId], session.baseline) ~= color then changes[spec.colorId] = color end
end

local function letteringBaseline(session, id)
    if GetVehicleMod(session.preview, Config.ById[id].slot) < 0 then return end
    return session.changes.wheels == nil and session.baseline[id] and 1 or 0
end

local function letteringOptions(session, entry)
    local current, selected
    local enablePrice, selectedPrice = 0, 0
    for _, id in ipairs(tyreLetteringIds) do
        local baseline = letteringBaseline(session, id)
        if baseline ~= nil then
            local staged = session.changes[id]
            local now = staged == nil and baseline or staged
            if current == nil then
                current, selected = baseline, now
            else
                if current ~= baseline then current = -100 end
                if selected ~= now then selected = -100 end
            end
            if baseline == 0 then enablePrice = enablePrice + Config.Price(Config.ById[id], 1) end
            if staged ~= nil then selectedPrice = selectedPrice + Config.Price(Config.ById[id], staged) end
        end
    end
    if current == nil then return end

    local options = { { value = 0, label = TuningText('Aus'), price = 0 }, { value = 1, label = TuningText('An'), price = enablePrice } }
    if current == -100 or selected == -100 then
        options[#options + 1] = { value = -100, label = TuningText('Teilweise an'), price = current == -100 and 0 or selectedPrice }
    end
    return { id = entry.id, name = entry.label, group = entry.group, options = options,
        current = current, selected = selected }
end

local function stageLettering(session, item, value)
    for _, id in ipairs(tyreLetteringIds) do
        local baseline = letteringBaseline(session, id)
        session.changes[id] = nil
        if baseline ~= nil and value >= 0 and value ~= item.current and value ~= baseline then
            session.changes[id] = value
        end
    end
end

local function optionsFor(session, entry)
    if entry.id == 'modCustomFrontWheels' then return letteringOptions(session, entry) end
    if entry.id == 'modCustomBackWheels' then return end
    local combined = combinedOptionsById[entry.id]
    if combined then return combinedOptions(session, entry, combined) end
    if entry.id == 'neonColor' or entry.id == 'xenonColor' or entry.id == 'tyreSmokeColor' then return end
    local vehicle, changes, baseline = session.preview, session.changes, session.baseline
    local kind, id = entry.kind, entry.id
    local maximum, minimum = entry.max, entry.min
    local options = {}
    local current = currentValue(entry, baseline)
    if kind == 'mod' then
        maximum = math.min(maximum, GetNumVehicleMods(vehicle, entry.slot) - 1)
        if maximum < 0 then return end
        if changes.wheels ~= nil and (entry.slot == 23 or entry.slot == 24) then current = -1 end
    elseif kind == 'livery' then
        maximum = math.min(maximum, math.max(GetNumVehicleMods(vehicle, 48), GetVehicleLiveryCount(vehicle)) - 1)
        if maximum < 0 then return end
    elseif kind == 'roofLivery' then
        if not GetVehicleRoofLiveryCount then return end
        maximum = math.min(maximum, GetVehicleRoofLiveryCount(vehicle) - 1)
        if maximum < 0 then return end
    elseif kind == 'extra' and not DoesExtraExist(vehicle, entry.slot) then
        return
    elseif id == 'wheels' and session.isBike then
        return
    end

    local function add(value, label)
        local paint = kind == 'paint' and PaintPalette[value]
        options[#options + 1] = { value = value, label = TuningText(label), price = Config.Price(entry, value),
            swatch = paint and paint.swatch, colorGroup = paint and paint.group,
            colorGroupOrder = paint and paint.groupOrder, finish = paint and paint.finish }
    end

    if kind == 'repair' then
        options[#options + 1] = { value = 0, label = TuningText('Keine Reparatur'), price = 0 }
    elseif current < minimum or current > maximum then
        add(current, current == -100 and 'Individuell' or 'Vorhanden')
    end

    for value = minimum, maximum do
        local label
        if value == -1 then
            label = id == 'modHorns' and '00 · Serie' or 'Serie'
        elseif id == 'modHorns' then
            local name = hornNames[value]
            name = name and TuningText(name) or gameLabel(GetModTextLabel(vehicle, entry.slot, value), TuningText('Hupe'))
            label = ('%02d · %s'):format(value + 1, name)
        elseif kind == 'mod' then
            label = gameLabel(GetModTextLabel(vehicle, entry.slot, value), TuningText('Variante %d', value + 1))
        elseif kind == 'livery' then
            local key
            if GetNumVehicleMods(vehicle, 48) > value then
                key = GetModTextLabel(vehicle, 48, value)
            elseif GetVehicleLiveryCount(vehicle) > value then
                key = GetLiveryName(vehicle, value)
            end
            label = gameLabel(key, TuningText('Design %d', value + 1))
        elseif kind == 'roofLivery' then
            label = TuningText('Design %d', value + 1)
        elseif kind == 'rgb' then
            label = Config.RGB[value][1]
        elseif kind == 'paint' then
            label = ('%03d · %s'):format(value, PaintPalette[value].name)
        elseif id == 'wheels' then
            label = value ~= 6 and wheelGroups[value + 1] or nil
        elseif id == 'windowTint' then
            label = tints[value + 1]
        elseif id == 'plateIndex' then
            label = ({ 'Blau auf Weiß I', 'Gelb auf Schwarz', 'Gelb auf Blau',
                'Blau auf Weiß II', 'Blau auf Weiß III', 'Yankton' })[value + 1]
        elseif kind == 'repair' then
            label = 'Reparieren'
        else
            label = value == 1 and 'An' or 'Aus'
        end
        if label or value == current then add(value, label or 'Vorhanden') end
    end

    return { id = id, name = entry.label, group = entry.group, options = options,
        current = current, selected = changes[id] or current }
end

local function updateMenu(session)
    local groups, total, count = {}, 0, 0
    session.available = {}
    for _, name in ipairs(Config.Groups) do
        groups[#groups + 1] = { name = name, items = {} }
    end
    for _, entry in ipairs(Config.Catalog) do
        local item = optionsFor(session, entry)
        if item then
            session.available[entry.id] = item
            for _, group in ipairs(groups) do
                if group.name == entry.group then
                    group.items[#group.items + 1] = item
                    break
                end
            end
        end
    end
    for id, value in pairs(session.changes) do
        total = total + Config.Price(Config.ById[id], value)
        count = count + 1
    end
    for id, spec in pairs(combinedOptionsById) do
        if session.changes[id] ~= nil and session.changes[spec.colorId] ~= nil then count = count - 1 end
    end
    if session.changes.modCustomFrontWheels ~= nil and session.changes.modCustomBackWheels ~= nil then count = count - 1 end
    for _, group in ipairs(groups) do group.name = TuningText(group.name) end
    return { ok = true, groups = groups, total = total, count = count }
end

local function updateCamera(session)
    local pos = GetEntityCoords(session.preview)
    local angle = math.rad(session.angle)
    local distance = session.distance * session.zoom
    local target = pos + vector3(0.0, 0.0, session.targetHeight)
    local offset = vector3(math.cos(angle) * distance, math.sin(angle) * distance, distance * 0.28)
    local eye = target + offset
    -- Probe only on open, rotation or zoom. Test world geometry and objects.
    local probe = StartExpensiveSynchronousShapeTestLosProbe(target.x, target.y, target.z,
        eye.x, eye.y, eye.z, 17, session.preview, 7)
    local result, hit, hitPos = GetShapeTestResult(probe)
    if result == 2 and (hit == true or hit == 1) then
        local clearance = #(hitPos - target) - 0.3
        if clearance < 1.8 then return false end
        eye = target + offset * (clearance / #offset)
    end
    -- Move the aim point to the camera's left so the car sits in the open area to the right.
    local horizontalTangent = math.tan(math.rad(cameraFov / 2)) * GetAspectRatio(false)
    local shift = #(eye - target) * horizontalTangent * (session.previewCenter * 2.0 - 1.0)
    local aim = target + vector3(math.sin(angle) * shift, -math.cos(angle) * shift, 0.0)
    SetCamCoord(session.camera, eye.x, eye.y, eye.z)
    PointCamAtCoord(session.camera, aim.x, aim.y, aim.z)
    return true
end

local function previewProperties(vehicle)
    local primary, secondary = GetVehicleColours(vehicle)
    local pearlescent, wheels = GetVehicleExtraColours(vehicle)
    local props = {
        plate = TuningFramework.Trim(GetVehicleNumberPlateText(vehicle)),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        tankHealth = GetVehiclePetrolTankHealth(vehicle),
        fuelLevel = GetVehicleFuelLevel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        color1 = primary, color2 = secondary, pearlescentColor = pearlescent, wheelColor = wheels,
        dashboardColor = GetVehicleDashboardColor(vehicle), interiorColor = GetVehicleInteriorColour(vehicle),
        wheels = GetVehicleWheelType(vehicle), windowTint = GetVehicleWindowTint(vehicle),
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        neonColor = { GetVehicleNeonLightsColour(vehicle) },
        tyreSmokeColor = { GetVehicleTyreSmokeColor(vehicle) },
        tyresCanBurst = GetVehicleTyresCanBurst(vehicle), extras = {}, neonEnabled = {}
    }
    if GetIsVehiclePrimaryColourCustom(vehicle) then props.customPrimaryColor = { GetVehicleCustomPrimaryColour(vehicle) } end
    if GetIsVehicleSecondaryColourCustom(vehicle) then props.customSecondaryColor = { GetVehicleCustomSecondaryColour(vehicle) } end
    local custom, red, green, blue = GetVehicleXenonLightsCustomColor(vehicle)
    if custom then props.customXenonColor = { red, green, blue } end
    for side = 0, 3 do props.neonEnabled[side + 1] = IsVehicleNeonLightEnabled(vehicle, side) end
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then props.extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i) end
    end
    for _, entry in ipairs(Config.Catalog) do
        if entry.kind == 'mod' then
            props[entry.id] = GetVehicleMod(vehicle, entry.slot)
        elseif entry.kind == 'toggle' then
            props[entry.id] = IsToggleModOn(vehicle, entry.slot)
        elseif entry.kind == 'variation' then
            props[entry.id] = GetVehicleModVariation(vehicle, entry.slot)
        end
    end
    props.modLivery = GetVehicleMod(vehicle, 48)
    if props.modLivery == -1 then props.modLivery = GetVehicleLivery(vehicle) end
    props.modRoofLivery = GetVehicleRoofLivery(vehicle)
    return props
end

local function createPreview(vehicle)
    local model, pos = GetEntityModel(vehicle), GetEntityCoords(vehicle)
    local preview = CreateVehicle(model, pos.x, pos.y, pos.z, GetEntityHeading(vehicle), false, false)
    if preview == 0 then return end
    SetEntityAsMissionEntity(preview, true, true)
    SetEntityCoordsNoOffset(preview, pos.x, pos.y, pos.z, false, false, false)
    SetEntityCollision(preview, false, false)
    SetVehicleDoorsLocked(preview, 2)
    FreezeEntityPosition(preview, true)
    return preview
end

local function openWorkshop(vehicle, shopId)
    local response = server('open', VehToNet(vehicle), shopId)
    if not response.ok then return false, response.message end
    local model = GetEntityModel(vehicle)
    RequestModel(model)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) or not stillDriving(vehicle) then
        SetModelAsNoLongerNeeded(model)
        return false, TuningText('Die Fahrzeugvorschau konnte nicht geladen werden.')
    end

    if not hasWorkshopJob() then
        SetModelAsNoLongerNeeded(model)
        return false, TuningText('Dein Job ist für die Tuning-Werkstatt nicht freigegeben.')
    end

    local props = previewProperties(vehicle)
    local heading = GetEntityHeading(vehicle)
    local preview = createPreview(vehicle)
    SetModelAsNoLongerNeeded(model)
    if not preview then return false, TuningText('Die Fahrzeugvorschau konnte nicht erstellt werden.') end

    local minimum, maximum = GetModelDimensions(model)
    local session = {
        vehicle = vehicle, preview = preview, baseline = props, changes = {},
        camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true), angle = heading + 48, zoom = 1.0, previewCenter = 0.64,
        distance = math.max(4.8, (maximum.y - minimum.y) * 1.12),
        targetHeight = (minimum.z + maximum.z) * 0.5,
        isBike = GetVehicleClass(vehicle) == 8, radarHidden = IsRadarHidden(), registered = response.registered,
        wasFrozen = IsEntityPositionFrozen and IsEntityPositionFrozen(vehicle) or false,
        expires = GetGameTimer() + Config.SessionSeconds * 1000
    }
    active = session
    FreezeEntityPosition(vehicle, true)

    renderPreview(session)
    if not DoesCamExist(session.camera) then return false, TuningText('Die Vorschaukamera konnte nicht gestartet werden.') end
    local ready = false
    for _ = 1, 8 do
        if updateCamera(session) then
            ready = true
            break
        end
        session.angle = (session.angle + 45) % 360
    end
    if not ready then return false, TuningText('Rund um das Fahrzeug ist zu wenig Platz für die Vorschaukamera.') end
    SetCamFov(session.camera, cameraFov)

    local data = updateMenu(session)
    data.action = 'open'
    data.locale = TuningLocale()
    data.text = TuningInterface()
    data.vehicle = gameLabel(GetDisplayNameFromVehicleModel(model), TuningText('Fahrzeug'))
    data.plate, data.shop, data.registered = props.plate, Config.Shops[shopId].name, response.registered
    SendNUIMessage(data)
    SetNuiFocus(true, true)
    RenderScriptCams(true, false, 0, true, true)
    session.cameraRendering = true
    DisplayRadar(false)
    TriggerServerEvent('DaTuning:preview', session.changes)
    return true
end

local function nui(name, callback)
    RegisterNUICallback(name, function(data, cb)
        if not active then cb({ ok = false, message = TuningText('Die Werkstatt ist geschlossen.') }) return end
        local ok, result = pcall(callback, active, data)
        if not ok then
            print(('[DaTuning] %s: %s'):format(name, tostring(result)))
            result = { ok = false, message = TuningText('Die Aktion ist fehlgeschlagen.') }
        end
        cb(result or { ok = true })
    end)
end

nui('select', function(session, data)
    local item = session.available[data.id]
    if session.buying or not item then return { ok = false } end
    for _, option in ipairs(item.options) do
        if option.value == data.value then
            local combined = combinedOptionsById[data.id]
            if combined then
                stageCombinedOption(session, item, data.value, combined)
            elseif data.id == 'modCustomFrontWheels' then
                stageLettering(session, item, data.value)
            else
                session.changes[data.id] = data.value
                if data.value == item.current then session.changes[data.id] = nil end
            end
            if data.id == 'wheels' then
                session.changes.modFrontWheels, session.changes.modBackWheels = nil, nil
                session.changes.modCustomFrontWheels, session.changes.modCustomBackWheels = nil, nil
            elseif data.id == 'modFrontWheels' or data.id == 'modBackWheels' then
                if data.value < 0 then
                    local key = data.id == 'modFrontWheels' and 'modCustomFrontWheels' or 'modCustomBackWheels'
                    session.changes[key] = nil
                end
            end
            renderPreview(session)
            TriggerServerEvent('DaTuning:preview', session.changes)
            return updateMenu(session)
        end
    end
    return { ok = false }
end)

nui('reset', function(session)
    if session.buying then return { ok = false } end
    session.changes = {}
    renderPreview(session)
    TriggerServerEvent('DaTuning:preview', session.changes)
    return updateMenu(session)
end)

nui('close', function(session)
    if not session.buying then close() end
end)

nui('camera', function(session, data)
    local oldZoom = session.zoom
    if type(data.turn) == 'number' then
        local degrees = math.max(-360, math.min(360, data.turn))
        session.angle = (session.angle + degrees) % 360
    end
    if type(data.zoom) == 'number' then
        session.zoom = math.min(1.55, math.max(0.73, session.zoom + data.zoom * 0.12))
    end
    if type(data.center) == 'number' then
        session.previewCenter = math.min(0.88, math.max(0.5, data.center))
    end
    if not updateCamera(session) then session.zoom = oldZoom end
end)

local function playPreviewHorn(session, index)
    if session.soundPlayback or not DoesEntityExist(session.preview) then return false end

    local preview = session.preview
    local loop = loopingHorns[index] == true
    local duration = loop and 3600 or 1800
    local playback = { engineStarted = loop and not GetIsVehicleEngineRunning(preview) }
    session.soundPlayback = playback

    SetHornEnabled(preview, true)
    if playback.engineStarted then SetVehicleEngineOn(preview, true, true, false) end
    SetVehicleMod(preview, 14, index, false)
    StartVehicleHorn(preview, duration, GetHashKey(loop and 'HELDDOWN' or 'NORMAL'), false)

    CreateThread(function()
        local deadline = GetGameTimer() + duration
        while session.soundPlayback == playback and DoesEntityExist(preview) do
            local remaining = deadline - GetGameTimer()
            if remaining <= 0 then break end
            if loop then
                -- _SOUND_VEHICLE_HORN_THIS_FRAME holds the musical horn input on the local clone.
                Citizen.InvokeNative(0x9C11908013EA4715, preview)
            end
            Wait(loop and 0 or remaining)
        end
        if session.soundPlayback == playback then stopPreviewSound(session) end
    end)
    return true
end

nui('horn', function(session)
    local horn = session.available.modHorns
    if session.buying or not horn or not DoesEntityExist(session.preview) then
        return { ok = false, message = TuningText('Für dieses Fahrzeug ist keine Hupenvorschau verfügbar.') }
    end
    if playPreviewHorn(session, horn.selected) then
        TriggerServerEvent('DaTuning:previewSound', 'horn', horn.selected)
    end
end)

local function playEnginePreview(session)
    local preview = session.preview
    if session.soundPlayback or not DoesEntityExist(preview) then return false end

    local playback = { revving = true, engineStarted = not GetIsVehicleEngineRunning(preview) }
    session.soundPlayback = playback
    if playback.engineStarted then SetVehicleEngineOn(preview, true, true, false) end

    CreateThread(function()
        local start = GetGameTimer()
        while session.soundPlayback == playback and DoesEntityExist(preview) do
            local elapsed = GetGameTimer() - start
            if elapsed >= 3000 then break end
            local progress = math.max(0.0, (elapsed - 300) / 2700)
            local rev = math.abs(math.sin(progress * math.pi * 2))
            SetVehicleCurrentRpm(preview, 0.18 + rev * 0.67)
            Wait(0)
        end
        if session.soundPlayback == playback then stopPreviewSound(session) end
    end)
    return true
end

nui('engineSound', function(session)
    if session.buying or not DoesEntityExist(session.preview) then
        return { ok = false, message = TuningText('Die Motorvorschau ist gerade nicht verfügbar.') }
    end
    if playEnginePreview(session) then
        TriggerServerEvent('DaTuning:previewSound', 'engine')
    end
end)

local function removeSpectator(worker)
    local session = spectators[worker]
    if not session then return end
    spectators[worker] = nil
    stopPreviewSound(session)
    if DoesEntityExist(session.preview) then DeleteVehicle(session.preview) end
end

local function syncSpectator(worker, entry, coords)
    local vehicle = NetworkDoesEntityExistWithNetworkId(entry.netId) and NetToVeh(entry.netId) or 0
    local nearby = vehicle ~= 0 and DoesEntityExist(vehicle)
        and #(GetEntityCoords(vehicle) - coords) <= Config.PreviewDistance
    local session = spectators[worker]
    if session and (not nearby or vehicle ~= session.vehicle or not DoesEntityExist(session.preview)) then
        removeSpectator(worker)
        session = nil
    end
    if not nearby then return end

    local model = GetEntityModel(vehicle)
    if not session and HasModelLoaded(model) then
        RequestModel(model)
        local baseline = previewProperties(vehicle)
        local preview = createPreview(vehicle)
        SetModelAsNoLongerNeeded(model)
        if preview then
            session = { vehicle = vehicle, preview = preview, baseline = baseline, revision = 0 }
            spectators[worker] = session
        end
    end
    if session and entry.revision > session.revision then
        session.changes, session.revision = entry.changes, entry.revision
        renderPreview(session)
    end
    return session
end

local function syncSpectators()
    local shared = GlobalState.daTuningPreviews or {}
    local workerId = tostring(GetPlayerServerId(PlayerId()))
    local coords = GetEntityCoords(PlayerPedId())
    for worker in pairs(spectators) do
        if not shared[worker] then removeSpectator(worker) end
    end
    for worker, entry in pairs(shared) do
        if worker ~= workerId then syncSpectator(worker, entry, coords) end
    end
end

RegisterNetEvent('DaTuning:previewSound', function(worker, entry, kind, index)
    if source ~= 65535 then return end
    local workerKey = tostring(worker)
    local shared = (GlobalState.daTuningPreviews or {})[workerKey]
    if shared and shared.revision > entry.revision then return end
    local session = syncSpectator(workerKey, entry, GetEntityCoords(PlayerPedId()))
    if not session or session.revision ~= entry.revision then return end
    if kind == 'engine' then
        playEnginePreview(session)
    elseif kind == 'horn' and index < GetNumVehicleMods(session.preview, 14) then
        playPreviewHorn(session, index)
    end
end)

CreateThread(function()
    local nextSync = 0
    while true do
        local now = GetGameTimer()
        if now >= nextSync then
            syncSpectators()
            nextSync = now + 200
        end
        for _, session in pairs(spectators) do
            if DoesEntityExist(session.vehicle) and DoesEntityExist(session.preview) then
                SetEntityLocallyInvisible(session.vehicle)
            end
        end
        Wait(next(spectators) and 0 or 200)
    end
end)

nui('purchase', function(session)
    if session.buying or not next(session.changes) then return { ok = false } end
    if not hasWorkshopJob() then
        close()
        return { ok = false, message = TuningText('Dein Job ist für die Tuning-Werkstatt nicht mehr freigegeben.') }
    end
    if not stillDriving(session.vehicle) or not NetworkHasControlOfEntity(session.vehicle) then
        return { ok = false, message = TuningText('Das Fahrzeug ist für den Umbau nicht verfügbar.') }
    end
    session.buying = true
    local response = server('purchase', session.changes)
    session.buying = false
    if response.ok then
        local vehicle, changes = session.vehicle, session.changes
        local applied = false
        if DoesEntityExist(vehicle) and NetworkHasControlOfEntity(vehicle) then
            local err
            applied, err = pcall(apply, vehicle, Config.VehiclePatch(session.baseline, changes), changes, changes.repair ~= nil)
            if not applied then print(('[DaTuning] apply failed: %s'):format(tostring(err))) end
        end
        close()
        if applied then
            notify(TuningText('Umbau abgeschlossen · $%s', TuningFramework.GroupDigits(response.total)))
        elseif session.registered then
            notify(TuningText('Umbau gespeichert. Lade das Fahrzeug erneut aus der Garage.'))
        else
            notify(TuningText('Der Kauf wurde gebucht, aber das Fahrzeug war für den Einbau nicht mehr verfügbar.'))
        end
    end
    return response
end)

local function requestOpen(vehicle, shopId)
    if active or opening then return end
    opening = true
    CreateThread(function()
        local ran, opened, message = pcall(openWorkshop, vehicle, shopId)
        opening = false
        if not ran or not opened then
            if active then close() else TriggerServerEvent('DaTuning:close') end
            if not ran then print(('[DaTuning] open: %s'):format(tostring(opened))) end
            notify(message or TuningText('Die Werkstatt konnte nicht geöffnet werden.'))
        end
    end)
end

RegisterCommand(Config.Command, function()
    if active or opening then return end
    if not hasWorkshopJob() then
        notify(TuningText('Dein Job ist für die Tuning-Werkstatt nicht freigegeben.'))
        return
    end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 or not stillDriving(vehicle) or not allowedClasses[GetVehicleClass(vehicle)]
        or not NetworkGetEntityIsNetworked(vehicle) or GetEntitySpeed(vehicle) >= 1.0 then
        notify(TuningText('Halte mit einem geeigneten Fahrzeug an und bleib am Steuer.'))
        return
    end

    local coords = GetEntityCoords(vehicle)
    for index, shop in ipairs(Config.Shops) do
        if #(coords - shop.coords) <= Config.OpenDistance then
            requestOpen(vehicle, index)
            return
        end
    end
    notify(TuningText('Fahre zum Werkstattmarker, um das Tuning zu öffnen.'))
end, false)

CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, 72)
        SetBlipColour(blip, 38)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Tuning · ' .. shop.name)
        EndTextCommandSetBlipName(blip)
    end

    while true do
        local delay = 500
        if active then
            delay = 0
            if active.cameraRendering then
                SetEntityLocallyInvisible(active.vehicle)
                SetEntityLocallyInvisible(PlayerPedId())
            end
            if not active.buying then
                if not hasWorkshopJob() then
                    close()
                    notify(TuningText('Dein Job ist für die Tuning-Werkstatt nicht mehr freigegeben.'))
                elseif not stillDriving(active.vehicle) or not DoesEntityExist(active.preview)
                    or GetGameTimer() >= active.expires then
                    close()
                end
            end
        elseif not opening then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if hasWorkshopJob() and vehicle ~= 0 and allowedClasses[GetVehicleClass(vehicle)]
                and NetworkGetEntityIsNetworked(vehicle) and stillDriving(vehicle) then
                local coords = GetEntityCoords(vehicle)
                for index, shop in ipairs(Config.Shops) do
                    local distance = #(coords - shop.coords)
                    if distance < 25.0 then
                        delay = 0
                        DrawMarker(1, shop.coords.x, shop.coords.y, shop.coords.z - 1.15, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, 4.0, 4.0, 0.22, 80, 220, 193, 105, false, false, 2, false, nil, nil, false)
                        if distance <= Config.OpenDistance and GetEntitySpeed(vehicle) < 1.0 then
                            BeginTextCommandDisplayHelp('STRING')
                            AddTextComponentSubstringPlayerName(TuningText('Drücke ~INPUT_CONTEXT~, um die Tuning-Werkstatt zu öffnen.'))
                            EndTextCommandDisplayHelp(0, false, false, -1)
                            if IsControlJustReleased(0, 38) then
                                requestOpen(vehicle, index)
                                break
                            end
                        end
                    end
                end
            end
        end
        Wait(delay)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    close()
    for worker in pairs(spectators) do removeSpectator(worker) end
end)

-- ESX applies the garage's VehicleProperties state bag before these two corrections.
AddStateBagChangeHandler('VehicleProperties', nil, function(bagName, _, props)
    if TuningFramework.Resolve() ~= 'esx' then return end
    if type(props) ~= 'table' or (props.modSmokeEnabled ~= false and props.modLightbar == nil) then return end
    CreateThread(function()
        for _ = 1, 20 do
            Wait(200)
            local vehicle = GetEntityFromStateBagName(bagName)
            if vehicle ~= 0 and NetworkHasControlOfEntity(vehicle) then
                SetVehicleModKit(vehicle, 0)
                if props.modSmokeEnabled == false then ToggleVehicleMod(vehicle, 20, false) end
                if props.modLightbar ~= nil then SetVehicleMod(vehicle, 49, props.modLightbar, false) end
                return
            end
        end
    end)
end)

-- Stock qb-garages forwards mods to QBCore, whose setter doesn't restore bulletproof tyres.
CreateThread(function()
    local checkedVehicle
    while true do
        Wait(500)
        if TuningFramework.Resolve() == 'qbcore' and not active and not opening then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle == 0 then
                checkedVehicle = nil
            elseif vehicle ~= checkedVehicle and stillDriving(vehicle)
                and NetworkGetEntityIsNetworked(vehicle) and NetworkHasControlOfEntity(vehicle) then
                checkedVehicle = vehicle
                local result = server('restoreTyres', VehToNet(vehicle))
                if result.ok and type(result.tyresCanBurst) == 'boolean' and not active and not opening
                    and stillDriving(vehicle) and NetworkHasControlOfEntity(vehicle) then
                    SetVehicleTyresCanBurst(vehicle, result.tyresCanBurst)
                end
            end
        end
    end
end)