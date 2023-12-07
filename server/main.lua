local houseowneridentifier = {}
local houseownercid = {}
local housekeyholders = {}
local housesLoaded = false

-- Threads

CreateThread(function()
    local HouseGarages = {}
    local result = MySQL.query.await('SELECT * FROM houselocations', {})
    if result[1] then
        for _, v in pairs(result) do
            local owned = false
            if tonumber(v.owned) == 1 then
                owned = true
            end
            local garage = json.decode(v.garage) or {}
            Config.Houses[v.name] = {
                coords = json.decode(v.coords),
                owned = owned,
                price = v.price,
                locked = true,
                adress = v.label,
                tier = v.tier,
                garage = garage,
                decorations = {}
            }
            HouseGarages[v.name] = {
                label = v.label,
                takeVehicle = garage
            }
        end
    end
    TriggerClientEvent("qb-garages:client:houseGarageConfig", -1, HouseGarages)
    TriggerClientEvent("qb-houses:client:setHouseConfig", -1, Config.Houses)
end)

CreateThread(function()
    while true do
        if not housesLoaded then
            MySQL.query('SELECT * FROM player_houses', {}, function(houses)
                if houses then
                    for _, house in pairs(houses) do
                        houseowneridentifier[house.house] = house.identifier
                        houseownercid[house.house] = house.citizenid
                        housekeyholders[house.house] = json.decode(house.keyholders)
                    end
                end
            end)
            housesLoaded = true
        end
        Wait(7)
    end
end)

-- Commands

lib.addCommand("decorate", {
    help = Lang:t("info.decorate_interior"),
}, function(source, args, raw)
    local src = source
    TriggerClientEvent("qb-houses:client:decorate", src)
end)

lib.addCommand("createhouse", {
    help = Lang:t("info.create_house"),
    params = {
        {
            name = 'price',
            type = 'number',
            help = Lang:t("info.price_of_house"),
            optional = false
        },
        {
            name = 'tier',
            type = 'number',
            help = Lang:t("info.tier_number"),
            optional = false
        }
    },
    restricted = 'group.admin'
}, function(source, args, raw)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if Player.PlayerData.job.name == "realestate" then
        TriggerClientEvent("qb-houses:client:createHouses", src, args.price, args.tier)
    else
        exports.qbx_core:Notify(src, Lang:t('error.realestate_only'), 'error')
    end
end)

lib.addCommand("addgarage", {
    help = Lang:t('info.add_garage'),
}, function(source, args, raw)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if Player.PlayerData.job.name == "realestate" then
        TriggerClientEvent("qb-houses:client:addGarage", src)
    else
        exports.qbx_core:Notify(src, Lang:t('error.realestate_only'), 'error')
    end
end)

lib.addCommand("ring", {
    help = Lang:t("info.ring_doorbell"),
}, function(source, args, raw)
    local src = source
    TriggerClientEvent('qb-houses:client:RequestRing', src)
end)

-- Item

-- Has to be redone after properties refactor
-- exports.qbx_core:CreateUseableItem("police_stormram", function(source, _)
--     local Player = exports.qbx_core:GetPlayer(source)
--     if (Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty) then
--         TriggerClientEvent("qb-houses:client:HomeInvasion", source)
--     else
--         exports.qbx_core:Notify(source, Lang:t('error.emergency_services'), 'error')
--     end
-- end)

-- Functions

local function hasKey(identifier, cid, house)
    if houseowneridentifier[house] and houseownercid[house] then
        if houseowneridentifier[house] == identifier and houseownercid[house] == cid then
            return true
        else
            if housekeyholders[house] then
                for i = 1, #housekeyholders[house], 1 do
                    if housekeyholders[house][i] == cid then
                        return true
                    end
                end
            end
        end
    end
    return false
end

exports('hasKey', hasKey)

local function GetHouseStreetCount(street)
    local count = 0
    local query = '%' .. street .. '%'
    local result = MySQL.Sync.fetchSingle('SELECT * FROM houselocations WHERE name LIKE ? ORDER BY LENGTH(`name`) desc, `name` DESC', {query})
    if result then
        local houseAddress = result.name
        count = tonumber(string.match(houseAddress, '%d[%d.,]*')) --[[@as number]]
    end
    return count + 1
end

local function isHouseOwned(house)
    local result = MySQL.query.await('SELECT owned FROM houselocations WHERE name = ?', {house})
    if result[1] then
        if result[1].owned == 1 then
            return true
        end
    end
    return false
end

local function escape_sqli(source)
    local replacements = {
        ['"'] = '\\"',
        ["'"] = "\\'"
    }
    return source:gsub("['\"]", replacements)
end

-- Events

RegisterNetEvent('qb-houses:server:setHouses', function()
    local src = source
    TriggerClientEvent("qb-houses:client:setHouseConfig", src, Config.Houses)
end)

RegisterNetEvent('qb-houses:server:createBlip', function()
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    TriggerClientEvent("qb-houses:client:createBlip", -1, coords)
end)

RegisterNetEvent('qb-houses:server:addNewHouse', function(street, coords, price, tier)
    local src = source
    street = street:gsub("%'", "")
    price = tonumber(price)
    tier = tonumber(tier)
    local houseCount = GetHouseStreetCount(street)
    local name = street:lower() .. tostring(houseCount)
    local label = street .. " " .. tostring(houseCount)
    MySQL.insert('INSERT INTO houselocations (name, label, coords, owned, price, tier) VALUES (?, ?, ?, ?, ?, ?)',
        {name, label, json.encode(coords), 0, price, tier})
    Config.Houses[name] = {
        coords = coords,
        owned = false,
        price = price,
        locked = true,
        adress = label,
        tier = tier,
        garage = {},
        decorations = {}
    }
    TriggerClientEvent("qb-houses:client:setHouseConfig", -1, Config.Houses)
    exports.qbx_core:Notify(src, Lang:t("info.added_house", {value = label}), 'success')
    TriggerEvent('qb-log:server:CreateLog', 'house', Lang:t("log.house_created"), 'green', Lang:t("log.house_address", {label = label, price = price, tier = tier, agent = GetPlayerName(src)}))
end)

RegisterNetEvent('qb-houses:server:addGarage', function(house, coords)
    local src = source
    MySQL.update('UPDATE houselocations SET garage = ? WHERE name = ?', {json.encode(coords), house})
    local garageInfo = {
        label = Config.Houses[house].adress,
        takeVehicle = coords
    }
    TriggerClientEvent("qb-garages:client:addHouseGarage", -1, house, garageInfo)
    exports.qbx_core:Notify(src, Lang:t("info.added_garage", {value = garageInfo.label}), 'success')
end)

RegisterNetEvent('qb-houses:server:viewHouse', function(house)
    local src = source
    local pData = exports.qbx_core:GetPlayer(src)

    local houseprice = Config.Houses[house].price
    local brokerfee = (houseprice / 100 * 5)
    local bankfee = (houseprice / 100 * 10)
    local taxes = (houseprice / 100 * 6)

    TriggerClientEvent('qb-houses:client:viewHouse', src, houseprice, brokerfee, bankfee, taxes,
        pData.PlayerData.charinfo.firstname, pData.PlayerData.charinfo.lastname)
end)

RegisterNetEvent('qb-houses:server:buyHouse', function(house)
    local src = source
    local pData = exports.qbx_core:GetPlayer(src)
    local price = Config.Houses[house].price
    local HousePrice = math.ceil(price * 1.21)
    local bankBalance = pData.PlayerData.money["bank"]

    local isOwned = isHouseOwned(house)
    if isOwned then
        exports.qbx_core:Notify(src, Lang:t("error.already_owned"), 'error')
        CancelEvent()
        return
    end

    if (bankBalance >= HousePrice) then
        houseowneridentifier[house] = pData.PlayerData.license
        houseownercid[house] = pData.PlayerData.citizenid
        housekeyholders[house] = {
            [1] = pData.PlayerData.citizenid
        }
        MySQL.insert('INSERT INTO player_houses (house, identifier, citizenid, keyholders) VALUES (?, ?, ?, ?)',{house, pData.PlayerData.license, pData.PlayerData.citizenid, json.encode(housekeyholders[house])})
        MySQL.update('UPDATE houselocations SET owned = ? WHERE name = ?', {1, house})
        TriggerClientEvent('qb-houses:client:SetClosestHouse', src)
        TriggerClientEvent('qb-house:client:RefreshHouseTargets', src)
        pData.Functions.RemoveMoney('bank', HousePrice, "bought-house") -- 21% Extra house costs
        exports['qbx_management']:AddMoney("realestate", (HousePrice / 100) * math.random(18, 25))
        TriggerEvent('qb-log:server:CreateLog', 'house', Lang:t("log.house_purchased"), 'green', Lang:t("log.house_purchased_by", {house = house:upper(), price = HousePrice, firstname = pData.PlayerData.charinfo.firstname, lastname = pData.PlayerData.charinfo.lastname}))
        exports.qbx_core:Notify(src, Lang:t("success.house_purchased"), 'success', 5000)
    else
        exports.qbx_core:Notify(src, Lang:t("error.not_enough_money"), 'error')
    end
end)

RegisterNetEvent('qb-houses:server:lockHouse', function(bool, house)
    TriggerClientEvent('qb-houses:client:lockHouse', -1, bool, house)
end)

RegisterNetEvent('qb-houses:server:SetRamState', function(bool, house)
    Config.Houses[house].IsRaming = bool
    TriggerClientEvent('qb-houses:server:SetRamState', -1, bool, house)
end)

RegisterNetEvent('qb-houses:server:giveKey', function(house, target)
    local pData = exports.qbx_core:GetPlayer(target)
    housekeyholders[house][#housekeyholders[house]+1] = pData.PlayerData.citizenid
    MySQL.update('UPDATE player_houses SET keyholders = ? WHERE house = ?',
        {json.encode(housekeyholders[house]), house})
end)

RegisterNetEvent('qb-houses:server:removeHouseKey', function(house, citizenData)
    local src = source
    local newHolders = {}
    if housekeyholders[house] then
        for k, _ in pairs(housekeyholders[house]) do
            if housekeyholders[house][k] ~= citizenData.citizenid then
                newHolders[#newHolders+1] = housekeyholders[house][k]
            end
        end
    end
    housekeyholders[house] = newHolders
    exports.qbx_core:Notify(src, Lang:t("error.remove_key_from", {firstname = citizenData.firstname, lastname = citizenData.lastname}), 'error')
    MySQL.update('UPDATE player_houses SET keyholders = ? WHERE house = ?', {json.encode(housekeyholders[house]), house})
end)

RegisterNetEvent('qb-houses:server:OpenDoor', function(target, house)
    local OtherPlayer = exports.qbx_core:GetPlayer(target)
    if OtherPlayer then
        TriggerClientEvent('qb-houses:client:SpawnInApartment', OtherPlayer.PlayerData.source, house)
    end
end)

RegisterNetEvent('qb-houses:server:RingDoor', function(house)
    local src = source
    TriggerClientEvent('qb-houses:client:RingDoor', -1, src, house)
end)

RegisterNetEvent('qb-houses:server:savedecorations', function(house, decorations)
    MySQL.update('UPDATE player_houses SET decorations = ? WHERE house = ?', {json.encode(decorations), house})
    TriggerClientEvent("qb-houses:server:sethousedecorations", -1, house, decorations)
end)

RegisterNetEvent('qb-houses:server:LogoutLocation', function()
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local MyItems = Player.PlayerData.items
    MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?',
        {json.encode(MyItems), Player.PlayerData.citizenid})
        exports.qbx_core:Logout(src)
    TriggerClientEvent('qb-multicharacter:client:chooseChar', src)
end)

RegisterNetEvent('qb-houses:server:giveHouseKey', function(target, house)
    local src = source
    local tPlayer = exports.qbx_core:GetPlayer(target)
    if tPlayer then
        if housekeyholders[house] then
            for _, cid in pairs(housekeyholders[house]) do
                if cid == tPlayer.PlayerData.citizenid then
                    return exports.qbx_core:Notify(src, Lang:t("error.already_keys"), 'error', 5000)
                end
            end
            housekeyholders[house][#housekeyholders[house]+1] = tPlayer.PlayerData.citizenid
            MySQL.update('UPDATE player_houses SET keyholders = ? WHERE house = ?', {json.encode(housekeyholders[house]), house})
            TriggerClientEvent('qb-houses:client:refreshHouse', tPlayer.PlayerData.source)
            exports.qbx_core:Notify(tPlayer.PlayerData.source, Lang:t("success.recieved_key", {value = Config.Houses[house].adress}), 'success', 2500)
        else
            local sourceTarget = exports.qbx_core:GetPlayer(src)
            housekeyholders[house] = {
                [1] = sourceTarget.PlayerData.citizenid
            }
            housekeyholders[house][#housekeyholders[house]+1] = tPlayer.PlayerData.citizenid
            MySQL.update('UPDATE player_houses SET keyholders = ? WHERE house = ?', {json.encode(housekeyholders[house]), house})
            TriggerClientEvent('qb-houses:client:refreshHouse', tPlayer.PlayerData.source)
            exports.qbx_core:Notify(tPlayer.PlayerData.source, Lang:t("success.recieved_key", {value = Config.Houses[house].adress}), 'success', 2500)
        end
    else
        exports.qbx_core:Notify(src, Lang:t("error.something_wrong"), 'error', 2500)
    end
end)

RegisterNetEvent('qb-houses:server:setLocation', function(coords, house, type)
    if type == 1 then
        MySQL.update('UPDATE player_houses SET stash = ? WHERE house = ?', {json.encode(coords), house})
    elseif type == 2 then
        MySQL.update('UPDATE player_houses SET outfit = ? WHERE house = ?', {json.encode(coords), house})
    elseif type == 3 then
        MySQL.update('UPDATE player_houses SET logout = ? WHERE house = ?', {json.encode(coords), house})
    end
    TriggerClientEvent('qb-houses:client:refreshLocations', -1, house, json.encode(coords), type)
end)

RegisterNetEvent('qb-houses:server:SetHouseRammed', function(bool, house)
    Config.Houses[house].IsRammed = bool
    TriggerClientEvent('qb-houses:client:SetHouseRammed', -1, bool, house)
end)

RegisterNetEvent('qb-houses:server:SetInsideMeta', function(insideId, bool)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local insideMeta = Player.PlayerData.metadata["inside"]
    if bool then
        insideMeta.apartment.apartmentType = nil
        insideMeta.apartment.apartmentId = nil
        insideMeta.house = insideId
        Player.Functions.SetMetaData("inside", insideMeta)
    else
        insideMeta.apartment.apartmentType = nil
        insideMeta.apartment.apartmentId = nil
        insideMeta.house = nil
        Player.Functions.SetMetaData("inside", insideMeta)
    end
end)

-- Callbacks

lib.callback.register('qb-houses:server:buyFurniture', function(source, price)
    local pData = exports.qbx_core:GetPlayer(source)
    local bankBalance = pData.PlayerData.money["bank"]

    if bankBalance >= price then
        pData.Functions.RemoveMoney('bank', price, "bought-furniture")
        return true
    end

    exports.qbx_core:Notify(source, Lang:t("error.not_enough_money"), 'error')
    return false
end)

lib.callback.register('qb-houses:server:ProximityKO', function(source, house)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return end

    local identifier = Player.PlayerData.license
    local CharId = Player.PlayerData.citizenid
    return hasKey(identifier, CharId, house) or Player.PlayerData.job.name == "realestate", houseowneridentifier[house] and houseownercid[house]
end)

lib.callback.register('qb-houses:server:hasKey', function(source, house)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return end

    local identifier = Player.PlayerData.license
    local CharId = Player.PlayerData.citizenid
    return hasKey(identifier, CharId, house) or Player.PlayerData.job.name == "realestate"
end)

lib.callback.register('qb-houses:server:isOwned', function(source, house)
    local Player = exports.qbx_core:GetPlayer(source)
    return Player and Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name == "realestate" or houseowneridentifier[house] and houseownercid[house]
end)

lib.callback.register('qb-houses:server:getHouseOwner', function(_, house)
    return houseownercid[house]
end)

lib.callback.register('qb-houses:server:getHouseKeyHolders', function(source, house)
    local retval = {}
    local Player = exports.qbx_core:GetPlayer(source)
    if housekeyholders[house] then
        for i = 1, #housekeyholders[house], 1 do
            if Player.PlayerData.citizenid ~= housekeyholders[house][i] then
                local result = MySQL.query.await('SELECT charinfo FROM players WHERE citizenid = ?', {housekeyholders[house][i]})
                if result[1] then
                    local charinfo = json.decode(result[1].charinfo)
                    retval[#retval + 1] = {
                        firstname = charinfo.firstname,
                        lastname = charinfo.lastname,
                        citizenid = housekeyholders[house][i]
                    }
                end
            end
        end
        return retval
    end
end)

lib.callback.register('qb-phone:server:TransferCid', function(_, NewCid, house)
    local result = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', {NewCid})
    if result[1] then
        local HouseName = house.name
        housekeyholders[HouseName] = {}
        housekeyholders[HouseName][1] = NewCid
        houseownercid[HouseName] = NewCid
        houseowneridentifier[HouseName] = result[1].license
        MySQL.update('UPDATE player_houses SET citizenid = ?, keyholders = ?, identifier = ? WHERE house = ?', {NewCid, json.encode(housekeyholders[HouseName]), result[1].license, HouseName})
        return true
    end

    return false
end)

lib.callback.register('qb-houses:server:getHouseDecorations', function(_, house)
    local retval = nil
    local result = MySQL.query.await('SELECT * FROM player_houses WHERE house = ?', {house})
    if result[1] then
        if result[1].decorations then
            retval = json.decode(result[1].decorations)
        end
    end
    return retval
end)

lib.callback.register('qb-houses:server:getHouseLocations', function(_, house)
    local result = MySQL.query.await('SELECT * FROM player_houses WHERE house = ?', {house})
    return result[1]
end)

lib.callback.register('qb-houses:server:getOwnedHouses', function(source)
    local pData = exports.qbx_core:GetPlayer(source)
    if not pData then return end
    local houses = MySQL.query.await('SELECT * FROM player_houses WHERE identifier = ? AND citizenid = ?', {pData.PlayerData.license, pData.PlayerData.citizenid})
    if houses then
        local ownedHouses = {}
        for i = 1, #houses, 1 do
            ownedHouses[#ownedHouses+1] = houses[i].house
        end
        return ownedHouses
    end
end)

lib.callback.register('qb-houses:server:getSavedOutfits', function(source)
    local pData = exports.qbx_core:GetPlayer(source)

    if pData then
        local result = MySQL.query.await('SELECT * FROM player_outfits WHERE citizenid = ?', {pData.PlayerData.citizenid})
        return result[1] and result
    end
end)

lib.callback.register('qb-phone:server:GetPlayerHouses', function(source)
    local Player = exports.qbx_core:GetPlayer(source)
    local MyHouses = {}
    local result = MySQL.query.await('SELECT * FROM player_houses WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if result and result[1] then
        for k, v in pairs(result) do
            MyHouses[#MyHouses + 1] = {
                name = v.house,
                keyholders = {},
                owner = Player.PlayerData.citizenid,
                price = Config.Houses[v.house].price,
                label = Config.Houses[v.house].adress,
                tier = Config.Houses[v.house].tier,
                garage = Config.Houses[v.house].garage
            }

            if v.keyholders ~= "null" then
                v.keyholders = json.decode(v.keyholders)
                if v.keyholders then
                    for _, data in pairs(v.keyholders) do
                        local keyholderdata = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', {data})
                        if keyholderdata[1] then
                            keyholderdata[1].charinfo = json.decode(keyholderdata[1].charinfo)

                            local userKeyHolderData = {
                                charinfo = {
                                    firstname = keyholderdata[1].charinfo.firstname,
                                    lastname = keyholderdata[1].charinfo.lastname
                                },
                                citizenid = keyholderdata[1].citizenid,
                                name = keyholderdata[1].name
                            }
                            MyHouses[k].keyholders[#MyHouses[k].keyholders+1] = userKeyHolderData
                        end
                    end
                else
                    MyHouses[k].keyholders[1] = {
                        charinfo = {
                            firstname = Player.PlayerData.charinfo.firstname,
                            lastname = Player.PlayerData.charinfo.lastname
                        },
                        citizenid = Player.PlayerData.citizenid,
                        name = Player.PlayerData.name
                    }
                end
            else
                MyHouses[k].keyholders[1] = {
                    charinfo = {
                        firstname = Player.PlayerData.charinfo.firstname,
                        lastname = Player.PlayerData.charinfo.lastname
                    },
                    citizenid = Player.PlayerData.citizenid,
                    name = Player.PlayerData.name
                }
            end
        end

        Wait(100)
        return MyHouses
    end

    return {}
end)

lib.callback.register('qb-phone:server:GetHouseKeys', function(source)
    local Player = exports.qbx_core:GetPlayer(source)
    local MyKeys = {}

    local result = MySQL.query.await('SELECT * FROM player_houses', {})
    for _, v in pairs(result) do
        if v.keyholders ~= "null" then
            v.keyholders = json.decode(v.keyholders)
            for _, p in pairs(v.keyholders) do
                if p == Player.PlayerData.citizenid and v.citizenid ~= Player.PlayerData.citizenid then
                    MyKeys[#MyKeys + 1] = {
                        HouseData = Config.Houses[v.house]
                    }
                end
            end
        end

        if v.citizenid == Player.PlayerData.citizenid then
            MyKeys[#MyKeys + 1] = {
                HouseData = Config.Houses[v.house]
            }
        end
    end

    return MyKeys
end)

lib.callback.register('qb-phone:server:MeosGetPlayerHouses', function(_, input)
    if input then
        local search = escape_sqli(input)
        local searchData = {}
        local query = '%' .. search .. '%'
        local result = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? OR charinfo LIKE ?', {search, query})
        if result[1] then
            local houses = MySQL.query.await('SELECT * FROM player_houses WHERE citizenid = ?', {result[1].citizenid})
            if houses[1] then
                for _, v in pairs(houses) do
                    searchData[#searchData+1] = {
                        name = v.house,
                        keyholders = v.keyholders,
                        owner = v.citizenid,
                        price = Config.Houses[v.house].price,
                        label = Config.Houses[v.house].adress,
                        tier = Config.Houses[v.house].tier,
                        garage = Config.Houses[v.house].garage,
                        charinfo = json.decode(result[1].charinfo),
                        coords = {
                            x = Config.Houses[v.house].coords.enter.x,
                            y = Config.Houses[v.house].coords.enter.y,
                            z = Config.Houses[v.house].coords.enter.z
                        }
                    }
                end
                return searchData
            end
        end
    end
end)

local function getKeyHolderData()
    return housekeyholders
end

exports("getKeyHolderData", getKeyHolderData)
