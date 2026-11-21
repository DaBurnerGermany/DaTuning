local framework, core = TuningFramework.Resolve()
if not core then
    print('[DaTuning] Start es_extended or qb-core before DaTuning and check Config.Framework.')
    return
end
local isQB = framework == 'qbcore'
local sessions, busy, lastOpen = {}, {}, {}
local previews, previewRevision = {}, 0
GlobalState.daTuningPreviews = previews

local function discard(source)
    sessions[source] = nil
    if previews[tostring(source)] then
        previews[tostring(source)] = nil
        GlobalState.daTuningPreviews = previews
    end
end

local function failure(message)
    return { ok = false, message = TuningText(message) }
end

local function playerJob(source)
    if isQB then
        local player = core.Functions.GetPlayer(source)
        local data = player and player.PlayerData
        return data and data.citizenid, data and data.job
    end
    local player = core.GetPlayerFromId(source)
    if player then return player.identifier, player.getJob() end
end

local function drivenVehicle(source, netId)
    if type(netId) ~= 'number' or netId % 1 ~= 0 or netId < 1 or netId > 65535 then return end
    local ped = GetPlayerPed(source)
    if ped == 0 then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    if GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    if GetPlayerRoutingBucket(source) ~= GetEntityRoutingBucket(vehicle) then return end
    return vehicle
end

local function context(source, netId, shopId)
    local worker, job = playerJob(source)
    if not worker or not job or Config.Jobs[job.name] ~= true then return end
    local shop = type(shopId) == 'number' and Config.Shops[shopId]
    local vehicle = shop and drivenVehicle(source, netId)
    if not vehicle or #(GetEntityCoords(vehicle) - shop.coords) > Config.OpenDistance + 1.5 then return end
    if GetEntitySpeed(vehicle) > 2.0 then return end
    local plate = TuningFramework.Trim(GetVehicleNumberPlateText(vehicle))
    if plate == '' then return end
    return worker, GetEntityModel(vehicle), plate, job.name
end

local function validate(source, session)
    local worker, model, plate, jobName = context(source, session.netId, session.shopId)
    if worker == session.worker and plate == session.plate and model == session.model then return jobName end
end

local function readVehicle(plate)
    if isQB then
        return MySQL.single.await(
            'SELECT id, plate, vehicle AS modelName, hash AS modelHash, mods AS properties, engine, body FROM player_vehicles WHERE plate = ? LIMIT 1',
            { plate }
        )
    end
    return MySQL.single.await(
        'SELECT owner, plate, vehicle AS properties FROM owned_vehicles WHERE plate = ? LIMIT 1',
        { plate }
    )
end

local function sameModel(first, second)
    local a, b = math.tointeger(first), math.tointeger(second)
    return a and b and (a & 0xffffffff) == (b & 0xffffffff)
end

local function decodeVehicle(row, model)
    if not row then return end
    if isQB then
        local hash = tonumber(row.modelName) or (row.modelName and joaat(row.modelName)) or tonumber(row.modelHash)
        if not sameModel(hash, model) then return end
        if not row.properties or row.properties == '' then return { model = model, plate = row.plate } end
    end
    local ok, props = pcall(json.decode, row.properties)
    if not ok or type(props) ~= 'table' then return end
    if not isQB then
        if sameModel(props.model, model) then return props end
        return
    end
    props.model, props.plate = model, row.plate
    return props
end

local function register(name, handler)
    local callback = function(source, cb, ...)
        local ok, result = pcall(handler, source, ...)
        if not ok then
            print(('[DaTuning] %s failed: %s'):format(name, tostring(result)))
            result = failure('Die Werkstatt ist momentan nicht verfügbar.')
        end
        cb(result)
    end
    if isQB then
        core.Functions.CreateCallback('DaTuning:' .. name, callback)
    else
        core.RegisterServerCallback('DaTuning:' .. name, callback)
    end
end

if isQB then
    register('restoreTyres', function(source, netId)
        local worker = playerJob(source)
        local vehicle = worker and drivenVehicle(source, netId)
        if not vehicle then return failure('Fahrzeug nicht verfügbar.') end
        local plate = TuningFramework.Trim(GetVehicleNumberPlateText(vehicle))
        if plate == '' then return { ok = true } end
        local row = readVehicle(plate)
        local props = decodeVehicle(row, GetEntityModel(vehicle))
        if drivenVehicle(source, netId) ~= vehicle or TuningFramework.Trim(GetVehicleNumberPlateText(vehicle)) ~= plate then
            return failure('Fahrzeug nicht verfügbar.')
        end
        return { ok = true, tyresCanBurst = props and props.tyresCanBurst }
    end)
end

register('open', function(source, netId, shopId)
    local now = os.time()
    if busy[source] or (lastOpen[source] and now - lastOpen[source] < 2) then
        return failure('Bitte warte kurz und versuche es erneut.')
    end
    lastOpen[source] = now

    local worker, model, plate = context(source, netId, shopId)
    if not worker then return failure('Du brauchst einen freigegebenen Job und musst am Steuer in der Werkstatt stehen.') end
    local row = readVehicle(plate)
    local registered = decodeVehicle(row, model) ~= nil

    local session = { worker = worker, registered = registered, model = model, plate = plate, netId = netId, shopId = shopId }
    if not validate(source, session) then return failure('Das Fahrzeug steht nicht mehr in der Werkstatt.') end

    session.expires = now + Config.SessionSeconds
    discard(source)
    sessions[source] = session
    return { ok = true, registered = registered }
end)

local function changeTotal(changes)
    if type(changes) ~= 'table' then return end
    local total = 0
    for id, value in pairs(changes) do
        local entry = Config.ById[id]
        if not entry or type(value) ~= 'number' or value % 1 ~= 0 or value < entry.min or value > entry.max then
            return
        end
        total = total + Config.Price(entry, value)
    end
    return total
end

local function publishPreview(worker, session)
    local key = tostring(worker)
    local previous = previews[key]
    if previous and previous.changes == session.queuedPreview then return previous end
    previewRevision = previewRevision + 1
    local preview = { netId = session.netId, changes = session.queuedPreview, revision = previewRevision }
    previews[key] = preview
    session.nextPreview = GetGameTimer() + 80
    GlobalState.daTuningPreviews = previews
    return preview
end

RegisterNetEvent('DaTuning:preview', function(changes)
    local worker = source
    local session = sessions[worker]
    if not session or busy[worker] or os.time() >= session.expires or not validate(worker, session) then return end

    local now = GetGameTimer()
    local previous = previews[tostring(worker)]
    if not changeTotal(changes) then return end
    session.queuedPreview = changes
    if previous and session.nextPreview and now < session.nextPreview then
        if session.flushPreview then return end
        session.flushPreview = true
        SetTimeout(session.nextPreview - now, function()
            session.flushPreview = nil
            if sessions[worker] ~= session or busy[worker] or not validate(worker, session) then return end
            publishPreview(worker, session)
        end)
        return
    end

    publishPreview(worker, session)
end)

RegisterNetEvent('DaTuning:previewSound', function(kind, index)
    local worker = source
    local session = sessions[worker]
    local preview = previews[tostring(worker)]
    local now = GetGameTimer()
    if not session or not preview or busy[worker] or os.time() >= session.expires
        or (session.nextPreviewSound and now < session.nextPreviewSound) or not validate(worker, session) then return end
    if kind ~= 'horn' and kind ~= 'engine' then return end
    if kind == 'horn' then
        if type(index) ~= 'number' or index % 1 ~= 0 or index < -1 or index > Config.ById.modHorns.max then return end
        local changes = session.queuedPreview or preview.changes
        if changes.modHorns ~= nil and changes.modHorns ~= index then return end
    end

    preview = publishPreview(worker, session)
    session.nextPreviewSound = now + 1500
    local vehicle = NetworkGetEntityFromNetworkId(session.netId)
    local coords, bucket = GetEntityCoords(vehicle), GetEntityRoutingBucket(vehicle)
    for _, id in ipairs(GetPlayers()) do
        local viewer = tonumber(id)
        if viewer and viewer ~= worker and GetPlayerRoutingBucket(viewer) == bucket then
            local ped = GetPlayerPed(viewer)
            if ped ~= 0 and #(GetEntityCoords(ped) - coords) <= Config.PreviewDistance then
                TriggerClientEvent('DaTuning:previewSound', viewer, worker, preview, kind, kind == 'horn' and index or nil)
            end
        end
    end
end)

local function societyAccount(jobName)
    if isQB then
        local name = Config.QBSocietyAccounts[jobName] or jobName
        if GetResourceState('qb-banking') ~= 'started' then return nil, name end
        local banking = exports['qb-banking']
        local account = banking:GetAccount(name)
        if not account or account.account_type ~= 'job' then return nil, name end
        return {
            money = tonumber(account.account_balance) or 0,
            addMoney = function(amount, reason) return banking:AddMoney(name, amount, reason) end,
            removeMoney = function(amount) return banking:RemoveMoney(name, amount, TuningText('DaTuning Werkstatt')) end
        }, name
    end
    local name = Config.SocietyAccounts[jobName] or 'society_' .. jobName
    if GetResourceState('esx_addonaccount') ~= 'started' then return nil, name end
    return exports.esx_addonaccount:GetSharedAccount(name), name
end

local function addSocietyMoney(job, value)
    if Config.Jobs[job] ~= true then return nil, TuningText('Dieser Job ist für DaTuning nicht freigegeben.') end
    local amount = math.tointeger(tonumber(value))
    if not amount or amount <= 0 then return nil, TuningText('Gib einen positiven ganzen Betrag ein.') end
    local account, name = societyAccount(job)
    if not account then return nil, TuningText('Firmenkonto nicht gefunden: %s', name) end
    if amount > 2147483647 - account.money then
        return nil, TuningText('Der Betrag überschreitet das Guthabenlimit des Firmenkontos.')
    end
    local added = account.addMoney(amount, TuningText('DaTuning Admin-Gutschrift'))
    if added == false or added == 0 then return nil, TuningText('Das Firmenkonto konnte nicht aufgeladen werden.') end
    return TuningText('%s gutgeschrieben: $%s', name, TuningFramework.GroupDigits(amount))
end

local adminArguments = {
    { name = 'job', help = TuningText('Jobname, z. B. mechanic'), type = 'string' },
    { name = 'amount', help = TuningText('Positiver ganzer Betrag'), type = 'number' }
}
local adminHelp = TuningText('Firmenkonto eines freigegebenen DaTuning-Jobs aufladen')

if isQB then
    core.Commands.Add('addsocietymoney', adminHelp, adminArguments, true, function(source, args)
        local message, err = addSocietyMoney(args[1], args[2])
        if source ~= 0 then TriggerClientEvent('QBCore:Notify', source, message or err, message and 'success' or 'error') end
        if message or source == 0 then print(('[DaTuning] %s (source %d)'):format(message or err, source)) end
    end, 'admin')
else
    core.RegisterCommand('addsocietymoney', 'admin', function(player, args, showError)
        local message, err = addSocietyMoney(args.job, args.amount)
        if not message then return showError(err) end
        if player then player.showNotification(message) end
        print(('[DaTuning] %s (%s)'):format(message, player and player.identifier or TuningText('Serverkonsole')))
    end, true, { help = adminHelp, validate = true, arguments = adminArguments })
end

local function saveVehicle(row, encoded, repaired)
    if isQB then
        local repair = repaired and 1 or 0
        return MySQL.update.await([[
            UPDATE player_vehicles
            SET mods = ?, engine = IF(? = 1, 1000, engine), body = IF(? = 1, 1000, body)
            WHERE id = ? AND plate = ? AND BINARY COALESCE(mods, '') = ?
        ]], { encoded, repair, repair, row.id, row.plate, row.properties or '' })
    end
    return MySQL.update.await(
        'UPDATE owned_vehicles SET vehicle = ? WHERE owner = ? AND plate = ? AND BINARY vehicle = ?',
        { encoded, row.owner, row.plate, row.properties }
    )
end

local function purchase(source, session, changes)
    if not validate(source, session) then return failure('Das Fahrzeug steht nicht mehr in der Werkstatt.') end
    if type(changes) ~= 'table' or next(changes) == nil then return failure('Wähle zuerst einen Umbau aus.') end

    local total = changeTotal(changes)
    if not total then return failure('Ungültige Auswahl.') end

    local row = session.registered and readVehicle(session.plate)
    local props = decodeVehicle(row, session.model)
    if session.registered and not props then return failure('Der Garageneintrag hat sich geändert.') end
    local jobName = validate(source, session)
    if not jobName then return failure('Das Fahrzeug steht nicht mehr in der Werkstatt.') end

    local encoded
    if props then
        local current = props
        if isQB then
            current = {
                extras = props.extras, modFrontWheels = props.modFrontWheels, modBackWheels = props.modBackWheels,
                modCustomFrontWheels = props.modCustomTiresF, modCustomBackWheels = props.modCustomTiresR
            }
        end
        local patch = Config.VehiclePatch(current, changes)
        if isQB then patch = TuningFramework.ToQBProperties(patch) end
        for key, value in pairs(patch) do props[key] = value end
        if changes.color1 ~= nil then props.customPrimaryColor = nil end
        if changes.color2 ~= nil then props.customSecondaryColor = nil end
        if changes.xenonColor ~= nil then props.customXenonColor = nil end
        encoded = json.encode(props)
    end

    local account
    if total > 0 then
        account = societyAccount(jobName)
        if not account then return failure('Für deinen Job ist kein Firmenkonto eingerichtet.') end
        if account.money < total then return failure('Auf dem Firmenkonto ist zu wenig Guthaben.') end
        local debited = account.removeMoney(total)
        if debited == false or debited == 0 then return failure('Das Firmenkonto konnte nicht belastet werden.') end
        if validate(source, session) ~= jobName then
            account.addMoney(total, TuningText('DaTuning Rückerstattung'))
            return failure('Die Werkstattsitzung hat sich während des Kaufs geändert.')
        end
    end

    local repairStats = isQB and props and changes.repair ~= nil and (row.engine ~= 1000 or row.body ~= 1000)
    if encoded and (encoded ~= row.properties or repairStats) then
        local updated, affected = pcall(saveVehicle, row, encoded, changes.repair ~= nil)
        if not updated or affected ~= 1 then
            if account then account.addMoney(total, TuningText('DaTuning Rückerstattung')) end
            if not updated then print(('[DaTuning] Save failed: %s'):format(tostring(affected))) end
            return failure('Der Umbau konnte nicht gespeichert werden.')
        end
    end

    if sessions[source] == session then discard(source) end
    return { ok = true, total = total }
end

register('purchase', function(source, changes)
    local session = sessions[source]
    if not session or os.time() >= session.expires then
        return failure('Die Werkstattsitzung ist abgelaufen. Öffne die Werkstatt erneut.')
    end
    if busy[source] then return failure('Ein Kauf wird bereits verarbeitet.') end

    local lock = {}
    busy[source] = lock
    local ok, result = pcall(purchase, source, session, changes)
    if busy[source] == lock then busy[source] = nil end
    if not ok then error(result) end
    return result
end)

RegisterNetEvent('DaTuning:close', function()
    if not busy[source] then discard(source) end
end)

AddEventHandler('playerDropped', function()
    discard(source)
    lastOpen[source], busy[source] = nil, nil
end)



CreateThread(function()
    while true do
        Wait(1000)
        for worker, session in pairs(sessions) do
            if not busy[worker] and (os.time() >= session.expires or not validate(worker, session)) then
                discard(worker)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then GlobalState.daTuningPreviews = {} end
end)