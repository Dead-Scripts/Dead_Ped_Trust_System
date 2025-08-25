-- PedTrustSystem Server Script
-- Prefix
local prefix = '^0[^6PedTrustSystem^0] '

-- Reload whitelist for a player
RegisterServerEvent("PedTrustSystem:reloadwl")
AddEventHandler("PedTrustSystem:reloadwl", function()
    local _source = source
    local identifiers = GetPlayerIdentifiers(_source) or {}
    TriggerClientEvent("PedTrustSystem:loadIdentifiers", _source, identifiers)
end)

-- Save JSON whitelist
RegisterServerEvent("PedTrustSystem:saveFile")
AddEventHandler("PedTrustSystem:saveFile", function(data)
    SaveResourceFile(GetCurrentResourceName(), "whitelist.json", json.encode(data, { indent = true }), -1)
end)

-- Helper functions
local function has_value(tab, val)
    for _, value in ipairs(tab) do
        if value == val then return true end
    end
    return false
end

local function get_index(tab, val)
    for i, value in ipairs(tab) do
        if value == val then return i end
    end
    return nil
end

-- Server-side ped check
RegisterNetEvent('PedTrustSystem:Server:Check')
AddEventHandler('PedTrustSystem:Server:Check', function()
    local configFile = LoadResourceFile(GetCurrentResourceName(), "whitelist.json")
    if not configFile then return end
    local cfg = json.decode(configFile)
    TriggerClientEvent('PedTrustSystem:RunCode:Client', source, cfg)
end)

-- COMMANDS --

-- List allowed peds
RegisterCommand("peds", function(source)
    local whitelist = LoadResourceFile(GetCurrentResourceName(), "whitelist.json")
    local cfg = json.decode(whitelist)
    local allowed = {}
    local myIds = GetPlayerIdentifiers(source) or {}

    for pair,_ in pairs(cfg) do
        if pair == myIds[1] then
            for _, v in ipairs(cfg[pair]) do
                if v.allowed then table.insert(allowed, v.spawncode) end
            end
        end
    end

    if #allowed > 0 then
        TriggerClientEvent('chatMessage', source, prefix .. "^2You are allowed access to drive the following peds:")
        TriggerClientEvent('chatMessage', source, "^0" .. table.concat(allowed, ', '))
    else
        TriggerClientEvent('chatMessage', source, prefix .. "^1Sadly no one has given you access to drive a personal ped :(")
    end
end)

-- Clear ped data
RegisterCommand("clearPed", function(source, args)
    if not IsPlayerAceAllowed(source, "PedTrustSystem.Access") then return end

    if #args < 1 then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: Not enough arguments... ^1Valid: /clearPed <spawncode>")
        return
    end

    local pedToClear = string.upper(args[1])
    local whitelist = LoadResourceFile(GetCurrentResourceName(), "whitelist.json")
    local cfg = json.decode(whitelist)

    for pair,_ in pairs(cfg) do
        for i = #cfg[pair], 1, -1 do
            if string.upper(cfg[pair][i].spawncode) == pedToClear then
                table.remove(cfg[pair], i)
            end
        end
    end

    TriggerClientEvent('chatMessage', source, prefix .. "^2Success: Removed all data of ped ^5" .. pedToClear .. "^2")
    TriggerClientEvent('pedwl:Cache:Update:Clearped', -1, pedToClear)
    TriggerEvent("PedTrustSystem:saveFile", cfg)
end)

-- Set ped owner
RegisterCommand("setPedOwner", function(source, args)
    if not IsPlayerAceAllowed(source, "PedTrustSystem.Access") then return end

    if #args < 2 then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: Not enough arguments... ^1Valid: /setPedOwner <id> <pedspawncode>")
        return
    end

    local id = tonumber(args[1])
    if not id or not GetPlayerIdentifiers(id) or not GetPlayerIdentifiers(id)[1] then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: That is not a valid server ID of a player...")
        return
    end

    local pedSpawn = string.upper(args[2])
    local steam = GetPlayerIdentifiers(id)[1]
    local whitelist = LoadResourceFile(GetCurrentResourceName(), "whitelist.json")
    local cfg = json.decode(whitelist)

    -- Check if ped is already owned
    local peddOwned = false
    for _,peds in pairs(cfg) do
        for _,ped in ipairs(peds) do
            if string.upper(ped.spawncode) == pedSpawn and ped.owner then
                peddOwned = true
            end
        end
    end

    if peddOwned then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: That ped is owned by someone already... Use /clearPed <spawncode> first")
        return
    end

    -- Add or update ped ownership
    cfg[steam] = cfg[steam] or {}
    local index = nil
    for i,ped in ipairs(cfg[steam]) do
        if string.upper(ped.spawncode) == pedSpawn then index = i end
    end

    if index then
        cfg[steam][index].owner = true
        cfg[steam][index].allowed = true
    else
        table.insert(cfg[steam], { owner = true, allowed = true, spawncode = pedSpawn })
    end

    TriggerEvent("PedTrustSystem:saveFile", cfg)
    TriggerClientEvent('chatMessage', source, prefix .. "^2Success: Set ^5" .. GetPlayerName(id) .. "^2 as owner of ped ^5" .. pedSpawn)
    TriggerClientEvent('chatMessage', id, prefix .. "^2You are now owner of ped ^5" .. pedSpawn .. "^2")
end)

-- Trust ped
RegisterCommand("trustPed", function(source, args)
    if #args < 2 then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: Not enough arguments... ^1Valid: /trustPed <id> <pedspawncode>")
        return
    end

    local id = tonumber(args[1])
    local pedSpawn = string.upper(args[2])
    if not id or id == source or not GetPlayerIdentifiers(id) or not GetPlayerIdentifiers(id)[1] then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: Invalid target player")
        return
    end

    local steam = GetPlayerIdentifiers(id)[1]
    local whitelist = LoadResourceFile(GetCurrentResourceName(), "whitelist.json")
    local cfg = json.decode(whitelist)

    -- Check ownership
    local peddOwned = false
    local sourceID = GetPlayerIdentifiers(source)[1]
    for pair,_ in pairs(cfg) do
        if pair == sourceID then
            for _,ped in ipairs(cfg[pair]) do
                if string.upper(ped.spawncode) == pedSpawn and ped.owner then
                    peddOwned = true
                end
            end
        end
    end

    if not peddOwned then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: You do not own this ped...")
        return
    end

    -- Give permission
    cfg[steam] = cfg[steam] or {}
    local index = nil
    for i,ped in ipairs(cfg[steam]) do
        if string.upper(ped.spawncode) == pedSpawn then index = i end
    end

    if index then
        cfg[steam][index].owner = false
        cfg[steam][index].allowed = true
    else
        table.insert(cfg[steam], { owner = false, allowed = true, spawncode = pedSpawn })
    end

    TriggerEvent("PedTrustSystem:saveFile", cfg)
    TriggerClientEvent('chatMessage', source, prefix .. "^2Success: You gave ^5" .. GetPlayerName(id) .. "^2 permission to use ped ^5" .. pedSpawn)
    TriggerClientEvent('chatMessage', id, prefix .. "^2You have been trusted to use ped ^5" .. pedSpawn)
end)

-- Untrust ped
RegisterCommand("untrustPed", function(source, args)
    if #args < 2 then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: Not enough arguments... ^1Valid: /untrustPed <id> <pedspawncode>")
        return
    end

    local id = tonumber(args[1])
    local pedSpawn = string.upper(args[2])
    if not id or id == source or not GetPlayerIdentifiers(id) or not GetPlayerIdentifiers(id)[1] then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: Invalid target player")
        return
    end

    local steam = GetPlayerIdentifiers(id)[1]
    local whitelist = LoadResourceFile(GetCurrentResourceName(), "whitelist.json")
    local cfg = json.decode(whitelist)

    -- Check ownership
    local peddOwned = false
    local sourceID = GetPlayerIdentifiers(source)[1]
    for pair,_ in pairs(cfg) do
        if pair == sourceID then
            for _,ped in ipairs(cfg[pair]) do
                if string.upper(ped.spawncode) == pedSpawn and ped.owner then
                    peddOwned = true
                end
            end
        end
    end

    if not peddOwned then
        TriggerClientEvent('chatMessage', source, prefix .. "^1ERROR: You do not own this ped...")
        return
    end

    -- Revoke permission
    cfg[steam] = cfg[steam] or {}
    local index = nil
    for i,ped in ipairs(cfg[steam]) do
        if string.upper(ped.spawncode) == pedSpawn then index = i end
    end

    if index then
        cfg[steam][index].owner = false
        cfg[steam][index].allowed = false
    else
        table.insert(cfg[steam], { owner = false, allowed = false, spawncode = pedSpawn })
    end

    TriggerEvent("PedTrustSystem:saveFile", cfg)
    TriggerClientEvent('chatMessage', source, prefix .. "^2Success: ^1Player " .. GetPlayerName(id) .. "^1 no longer has permission for ped ^5" .. pedSpawn)
    TriggerClientEvent('chatMessage', id, prefix .. "^1Your permission to use ped ^5" .. pedSpawn .. "^1 has been revoked by owner ^5" .. GetPlayerName(source))
end)
