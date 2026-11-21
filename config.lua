Config = {
    Locale = 'de', -- 'de' or 'en'
    Framework = 'auto', -- 'auto', 'esx', 'qbcore'
    QBSocietyAccounts = {}, -- qb-banking defaults to the job name
    SocietyAccounts = { mechanic = 'society_mechanic' }, -- Other jobs default to society_<job>
    Command = 'tuning',
    Jobs = { mechanic = true }, -- List the job names allowed to use the workshop
    SessionSeconds = 600,
    OpenDistance = 4.5,
    PreviewDistance = 45.0,
    Shops = {
        { name = 'Burton', coords = vector3(-337.40, -135.50, 39.01) },
        { name = 'La Mesa', coords = vector3(732.12, -1088.78, 22.17) },
        { name = 'Blaine County', coords = vector3(1174.75, 2640.10, 37.75) },
        { name = 'Paleto Bay', coords = vector3(110.88, 6626.39, 31.79) }
    },
    Groups = { 'Service', 'Leistung', 'Karosserie', 'Innenraum', 'Lack', 'Räder', 'Licht' },
    Catalog = {},
    ById = {},
    RGB = {
        { 'Weiß', 255, 255, 255 }, { 'Rot', 255, 30, 35 }, { 'Orange', 255, 110, 0 },
        { 'Gelb', 255, 215, 0 }, { 'Grün', 25, 235, 90 }, { 'Cyan', 0, 220, 245 },
        { 'Blau', 25, 85, 255 }, { 'Violett', 145, 45, 255 }, { 'Pink', 255, 35, 150 }
    }
}

local function item(group, id, label, kind, min, max, price, slot, step)
    local entry = {
        group = group, id = id, label = TuningText(label), kind = kind, min = min,
        max = max, price = price, slot = slot, step = step or 0
    }
    Config.Catalog[#Config.Catalog + 1] = entry
    Config.ById[id] = entry
end

local function mod(group, id, label, slot, price, step, max)
    item(group, id, label, 'mod', -1, max or 255, price, slot, step)
end

item('Service', 'repair', 'Fahrzeug reparieren', 'repair', 1, 1, 650)
mod('Leistung', 'modEngine', 'Motor', 11, 8500, 4500, 3)
mod('Leistung', 'modBrakes', 'Bremsen', 12, 3500, 2250, 3)
mod('Leistung', 'modTransmission', 'Getriebe', 13, 5000, 3750, 3)
mod('Leistung', 'modSuspension', 'Fahrwerk', 15, 2600, 1400, 4)
mod('Leistung', 'modArmor', 'Panzerung', 16, 5500, 4500, 4)
item('Leistung', 'modTurbo', 'Turbo', 'toggle', 0, 1, 18500, 18)

for _, part in ipairs({
    { 'modSpoilers', 'Spoiler', 0 }, { 'modFrontBumper', 'Frontstoßstange', 1 },
    { 'modRearBumper', 'Heckstoßstange', 2 }, { 'modSideSkirt', 'Seitenschweller', 3 },
    { 'modExhaust', 'Auspuff', 4 }, { 'modFrame', 'Rahmen', 5 },
    { 'modGrille', 'Kühlergrill', 6 }, { 'modHood', 'Motorhaube', 7 },
    { 'modFender', 'Kotflügel links', 8 }, { 'modRightFender', 'Kotflügel rechts', 9 },
    { 'modRoof', 'Dach', 10 }, { 'modPlateHolder', 'Kennzeichenhalter', 25 },
    { 'modVanityPlate', 'Zierkennzeichen', 26 }, { 'modHydrolic', 'Hydraulik', 38 },
    { 'modEngineBlock', 'Motorblock', 39 }, { 'modAirFilter', 'Luftfilter', 40 },
    { 'modStruts', 'Domstrebe', 41 }, { 'modArchCover', 'Radläufe', 42 },
    { 'modAerials', 'Antennen', 43 }, { 'modTank', 'Tank', 45 },
    { 'modWindows', 'Fenster', 46 }, { 'modLightbar', 'Lichtleiste', 49 }
}) do
    mod('Karosserie', part[1], part[2], part[3], 1800, 300)
end

item('Karosserie', 'windowTint', 'Scheibentönung', 'value', 0, 6, 1400)
item('Karosserie', 'plateIndex', 'Kennzeichenstil', 'value', 0, 5, 450)
for extra = 1, 14 do
    item('Karosserie', 'extra' .. extra, TuningText('Zusatzausstattung %d', extra), 'extra', 0, 1, 750, extra)
end

for _, part in ipairs({
    { 'modHorns', 'Hupe', 14 }, { 'modTrimA', 'Verkleidung', 27 },
    { 'modOrnaments', 'Dekoration', 28 }, { 'modDashboard', 'Armaturen', 29 },
    { 'modDial', 'Instrumente', 30 }, { 'modDoorSpeaker', 'Türlautsprecher', 31 },
    { 'modSeats', 'Sitze', 32 }, { 'modSteeringWheel', 'Lenkrad', 33 },
    { 'modShifterLeavers', 'Schalthebel', 34 }, { 'modAPlate', 'Zierplakette', 35 },
    { 'modSpeakers', 'Lautsprecher', 36 }, { 'modTrunk', 'Kofferraum', 37 },
    { 'modTrimB', 'Innenverkleidung', 44 }
}) do
    mod('Innenraum', part[1], part[2], part[3], 1100, 180)
end
item('Innenraum', 'interiorColor', 'Innenraumfarbe', 'paint', 0, 159, 750)
item('Innenraum', 'dashboardColor', 'Armaturenfarbe', 'paint', 0, 159, 750)

item('Lack', 'color1', 'Primärlack', 'paint', 0, 159, 1800)
item('Lack', 'color2', 'Sekundärlack', 'paint', 0, 159, 1500)
item('Lack', 'pearlescentColor', 'Perleffekt (Schimmer)', 'paint', 0, 159, 1100)
item('Lack', 'modLivery', 'Beklebung', 'livery', -1, 255, 3100)
item('Lack', 'modRoofLivery', 'Dachbeklebung', 'roofLivery', -1, 255, 1800)

item('Räder', 'wheels', 'Felgenkategorie', 'value', 0, 12, 750)
mod('Räder', 'modFrontWheels', 'Felgen', 23, 2200, 130)
mod('Räder', 'modBackWheels', 'Hinterradfelge', 24, 1800, 100)
item('Räder', 'modCustomFrontWheels', 'Reifenbeschriftung', 'variation', 0, 1, 650, 23)
item('Räder', 'modCustomBackWheels', 'Reifenbeschriftung hinten', 'variation', 0, 1, 650, 24)
item('Räder', 'wheelColor', 'Felgenfarbe', 'paint', 0, 159, 700)
item('Räder', 'tyresCanBurst', 'Kugelsichere Reifen', 'inverse', 0, 1, 6200)
item('Räder', 'modSmokeEnabled', 'Reifenrauch', 'toggle', 0, 1, 1700, 20)
item('Räder', 'tyreSmokeColor', 'Reifenrauchfarbe', 'rgb', 1, #Config.RGB, 600)

item('Licht', 'modXenon', 'Xenon', 'toggle', 0, 1, 3400, 22)
item('Licht', 'xenonColor', 'Xenonfarbe', 'xenon', 0, 13, 950)
item('Licht', 'underbody', 'Unterbodenbeleuchtung', 'neon', 0, 1, 3800)
item('Licht', 'neonColor', 'Unterbodenfarbe', 'rgb', 1, #Config.RGB, 650)

function Config.Price(entry, value)
    if value == -1 or (value == 0 and (
        entry.kind == 'toggle' or entry.kind == 'neon' or entry.kind == 'inverse'
        or entry.kind == 'extra' or entry.kind == 'variation'
    )) then
        return 0
    end
    return entry.price + math.max(value, 0) * entry.step
end

function Config.VehiclePatch(current, changes)
    local patch = {}
    if changes.wheels ~= nil then
        patch.modFrontWheels, patch.modBackWheels = -1, -1
        patch.modCustomFrontWheels, patch.modCustomBackWheels = false, false
    end

    for _, entry in ipairs(Config.Catalog) do
        local id = entry.id
        local value = changes[id]
        if value ~= nil then
            local kind = entry.kind
            if kind == 'repair' then
                patch.bodyHealth, patch.engineHealth, patch.tankHealth = 1000, 1000, 1000
                patch.dirtLevel = 0
                patch.doorsBroken, patch.windowsBroken, patch.tyreBurst = {}, {}, {}
            elseif kind == 'neon' then
                local enabled = value == 1
                patch.neonEnabled = { enabled, enabled, enabled, enabled }
            elseif kind == 'extra' then
                if not patch.extras then
                    patch.extras = {}
                    for key, enabled in pairs(current.extras or {}) do
                        patch.extras[tostring(key)] = enabled
                    end
                end
                patch.extras[tostring(entry.slot)] = value == 1
            elseif kind == 'rgb' then
                local rgb = Config.RGB[value]
                patch[id] = { rgb[2], rgb[3], rgb[4] }
            elseif kind == 'toggle' then
                patch[id] = value == 1
            elseif kind == 'variation' then
                local wheel = entry.slot == 23 and 'modFrontWheels' or 'modBackWheels'
                patch[wheel] = patch[wheel] or current[wheel] or -1
                patch[id] = value == 1 and patch[wheel] >= 0
            elseif kind == 'xenon' then
                patch[id] = value == 0 and 255 or value - 1
            elseif kind == 'inverse' then
                patch[id] = value == 0
            else
                patch[id] = value
                if id == 'modFrontWheels' or id == 'modBackWheels' then
                    local variation = entry.slot == 23 and 'modCustomFrontWheels' or 'modCustomBackWheels'
                    patch[variation] = changes.wheels == nil and value >= 0 and current[variation] == true
                end
            end
        end
    end
    return patch
end

