local identifiers = {}

function ShowInfo(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    DrawNotification(false, false)
end

Citizen.CreateThread(function()
    local myIds = getIdentifiers()
    print(json.encode(myIds)) -- safer debug
    while true do
        Citizen.Wait(5000)
        TriggerServerEvent('PedTrustSystem:reloadwl') 
        TriggerServerEvent('PedTrustSystem:Server:Check')
    end
end)

function getConfig()
    return LoadResourceFile(GetCurrentResourceName(), "whitelist.json")
end

AddEventHandler("playerSpawned", function()
    TriggerServerEvent("PedTrustSystem:reloadwl")
end)

function getIdentifiers()
    return identifiers
end

allowedPed = 'a_m_y_skater_01'

RegisterNetEvent('PedTrustSystem:RunCode:Client')
AddEventHandler('PedTrustSystem:RunCode:Client', function(cfg)
    local ped = PlayerPedId()
    local hashAllowedSkin = GetHashKey(allowedPed)
    local currentModel = GetEntityModel(ped)
    local exists, allowed = false, false

    RequestModel(hashAllowedSkin)
    local timeout = GetGameTimer() + 5000 -- 5 second timeout
    while not HasModelLoaded(hashAllowedSkin) and GetGameTimer() < timeout do 
        RequestModel(hashAllowedSkin)
        Citizen.Wait(0)
    end

    local myIds = getIdentifiers()
    for pair,_ in pairs(cfg) do
        for _,vehic in ipairs(cfg[pair]) do
            if (GetHashKey(vehic.spawncode) == currentModel) then
                exists = true
            end
        end
        if (pair == myIds[1]) then
            for _,v in ipairs(cfg[pair]) do
                if (currentModel == GetHashKey(v.spawncode)) and v.allowed then
                    allowed = true
                    print("Allowed was set to true with ped == " .. v.spawncode)
                end
            end
        end
    end

    if (exists and not allowed) then
        SetPlayerModel(PlayerId(), hashAllowedSkin)
        SetModelAsNoLongerNeeded(hashAllowedSkin)
        TriggerEvent('PedTrustSystem:RunCode:Success') -- removed `source`
    end
end)

RegisterNetEvent('PedTrustSystem:RunCode:Success')
AddEventHandler('PedTrustSystem:RunCode:Success', function()
    ShowInfo('~r~ERROR: You do not have access to this personal ped')
end)

RegisterNetEvent("PedTrustSystem:loadIdentifiers")
AddEventHandler("PedTrustSystem:loadIdentifiers", function(id)
    identifiers = id
end)

RegisterCommand("reloadPedWL", function()
    TriggerServerEvent("PedTrustSystem:reloadwl")
end)
