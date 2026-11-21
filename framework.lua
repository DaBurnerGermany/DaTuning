TuningFramework = {}

local framework, core, resource

function TuningFramework.Resolve()
    if resource and GetResourceState(resource) == 'started' then return framework, core end
    framework, core, resource = nil, nil, nil
    local mode = Config.Framework
    if (mode == 'auto' or mode == 'esx') and GetResourceState('es_extended') == 'started' then
        framework, core, resource = 'esx', exports.es_extended:getSharedObject(), 'es_extended'
    elseif (mode == 'auto' or mode == 'qbcore') and GetResourceState('qb-core') == 'started' then
        framework, core, resource = 'qbcore', exports['qb-core']:GetCoreObject(), 'qb-core'
    end
    return framework, core
end

function TuningFramework.Trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

function TuningFramework.GroupDigits(amount)
    local formatted = tostring(amount)
    local grouped = formatted:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
    if TuningLocale() == 'en' then grouped = grouped:gsub('%.', ',') end
    return grouped
end

function TuningFramework.ToQBProperties(props)
    local qb = {}
    for key, value in pairs(props) do qb[key] = value end
    qb.color1 = props.customPrimaryColor or props.color1
    qb.color2 = props.customSecondaryColor or props.color2
    qb.xenonColor = props.customXenonColor or props.xenonColor
    qb.modCustomTiresF, qb.modCustomTiresR = props.modCustomFrontWheels, props.modCustomBackWheels
    qb.liveryRoof, qb.modKit49 = props.modRoofLivery, props.modLightbar
    qb.customPrimaryColor, qb.customSecondaryColor, qb.customXenonColor = nil, nil, nil
    qb.modCustomFrontWheels, qb.modCustomBackWheels = nil, nil
    qb.modRoofLivery, qb.modLightbar = nil, nil
    if props.doorsBroken ~= nil then qb.doorStatus = {} end
    if props.windowsBroken ~= nil then qb.windowStatus = {} end
    if props.tyreBurst ~= nil then
        qb.tireBurstState, qb.tireBurstCompletely, qb.tireHealth = {}, {}, {}
    end
    qb.doorsBroken, qb.windowsBroken, qb.tyreBurst = nil, nil, nil
    return qb
end