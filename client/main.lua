QBCore = exports['qb-core']:GetCoreObject()
IsInside = false
ClosestHouse = nil
HasHouseKey = false

local isOwned = false
local cam = nil
local viewCam = false
local FrontCam = false
local stashLocation = nil
local outfitLocation = nil
local logoutLocation = nil
local OwnedHouseBlips = {}
local UnownedHouseBlips = {}
local CurrentDoorBell = 0
local rangDoorbell = nil
local houseObj = {}
local POIOffsets = nil
local entering = false
local data = nil
local CurrentHouse = nil
local fetchingHouseKeys = false

-- zone check
local stashTargetBoxID = 'stashTarget'
local stashTargetBox = nil
local isInsideStashTarget = false

local outfitsTargetBoxID = 'outfitsTarget'
local outfitsTargetBox = nil
local isInsideOutfitsTarget = false

local charactersTargetBoxID = 'charactersTarget'
local charactersTargetBox = nil
local isInsiteCharactersTarget = false

Houses = {}
local Targets = {}

-- Functions
local function showEntranceHeaderMenu()
    local headerMenu = {}

    if QBCore.Functions.GetPlayerData().job and QBCore.Functions.GetPlayerData().job.name == 'realestate' then
        isOwned = true
    end

    if not isOwned then
        headerMenu[#headerMenu + 1] = {
            title = Lang:t("menu.view_house"),
            icon = "fa-solid fa-house",
            event = "qb-houses:client:ViewHouse"
        }
    else
        if isOwned and HasHouseKey then
            headerMenu[#headerMenu + 1] = {
                title = Lang:t("menu.enter_house"),
                icon = "fa-solid fa-door-open",
                event = "qb-houses:client:EnterHouse"
            }
            headerMenu[#headerMenu + 1] = {
                title = Lang:t("menu.give_house_key"),
                icon = "fa-solid fa-key",
                event = "qb-houses:client:giveHouseKey"
            }
        elseif isOwned and not HasHouseKey then
            headerMenu[#headerMenu + 1] = {
                title = Lang:t("menu.ring_door"),
                icon = "fa-solid fa-bell",
                event = "qb-houses:client:RequestRing"
            }
            headerMenu[#headerMenu + 1] = {
                title = Lang:t("menu.enter_unlocked_house"),
                icon = "fa-solid fa-door-open",
                event = "qb-houses:client:EnterHouse"
            }

            if QBCore.Functions.GetPlayerData().job and QBCore.Functions.GetPlayerData().job.type == 'leo' then
                headerMenu[#headerMenu + 1] = {
                    title = Lang:t("menu.lock_door_police"),
                    icon = "fa-solid fa-lock",
                    event = "qb-houses:client:ResetHouse"
                }
            end
        else
            headerMenu = {}
        end
    end

    lib.registerContext({
        id = 'open_housesEntranceMenu',
        title = "House",
        options = headerMenu
    })
    lib.showContext('open_housesEntranceMenu')
end

local function showExitHeaderMenu()
    local headerMenu = {}

    headerMenu[#headerMenu + 1] = {
        title = Lang:t("menu.exit_property"),
        icon = "fa-solid fa-door-open",
        event = "qb-houses:client:ExitOwnedHouse"
    }

    if isOwned then
        headerMenu[#headerMenu + 1] = {
            title = Lang:t("menu.front_camera"),
            icon = "fa-solid fa-video",
            event = "qb-houses:client:FrontDoorCam"
        }
        headerMenu[#headerMenu + 1] = {
            title = Lang:t("menu.open_door"),
            icon = "fa-solid fa-lock",
            event = "qb-houses:client:AnswerDoorbell"
        }
    end

    lib.registerContext({
        id = 'open_houseExit',
        title = "House: Exit door",
        options = headerMenu
    })
    lib.showContext('open_houseExit')
end

local function RegisterStashTarget()
    if not stashLocation then
        return
    end

    stashTargetBox = BoxZone:Create(vec3(stashLocation.x, stashLocation.y, stashLocation.z), 1.5, 1.5, {
        name = stashTargetBoxID,
        heading = 0.0,
        minZ = stashLocation.z - 1.0,
        maxZ = stashLocation.z + 1.0
    })
    stashTargetBox:onPlayerInOut(function(isPointInside)
        if isPointInside and not entering and isOwned then
            lib.showTextUI(Lang:t("target.open_stash"))
        else
            lib.hideTextUI()
        end

        isInsideStashTarget = isPointInside
    end)
end

local function RegisterOutfitsTarget()
    if not outfitLocation then
        return
    end

    outfitsTargetBox = BoxZone:Create(vec3(outfitLocation.x, outfitLocation.y, outfitLocation.z), 1.5, 1.5, {
        name = outfitsTargetBoxID,
        heading = 0.0,
        minZ = outfitLocation.z - 1.0,
        maxZ = outfitLocation.z + 1.0
    })

    outfitsTargetBox:onPlayerInOut(function(isPointInside)
        if isPointInside and not entering and isOwned then
            lib.showTextUI(Lang:t("target.outfits"))
        else
            lib.hideTextUI()
        end

        isInsideOutfitsTarget = isPointInside
    end)
end

local function RegisterCharactersTarget()
    if not logoutLocation then
        return
    end

    charactersTargetBox = BoxZone:Create(vec3(logoutLocation.x, logoutLocation.y, logoutLocation.z), 1.5, 1.5, {
        name = charactersTargetBoxID,
        heading = 0.0,
        minZ = logoutLocation.z - 1.0,
        maxZ = logoutLocation.z + 1.0
    })
    charactersTargetBox:onPlayerInOut(function(isPointInside)
        if isPointInside and not entering and isOwned then
            lib.showTextUI(Lang:t("target.change_character"))
        else
            lib.hideTextUI()
        end

        isInsiteCharactersTarget = isPointInside
    end)
end

local function RegisterHouseExitZone(id)
    if not Houses[id] then
        return
    end

    local boxName = 'houseExit_' .. id
    local boxData = Targets[boxName] or {}

    if boxData and boxData.created then
        return
    end

    if not POIOffsets then
        return
    end

    local house = Houses[id]
    local coords = vec3(house.coords['enter'].x + POIOffsets.exit.x, house.coords['enter'].y + POIOffsets.exit.y, house.coords['enter'].z  - Config.MinZOffset + POIOffsets.exit.z + 1.0)
    local zone = BoxZone:Create(coords, 2, 1, {
        name = boxName,
        heading = 0.0,
        minZ = coords.z - 2.0,
        maxZ = coords.z + 1.0,
    })
    zone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            showExitHeaderMenu()
        else
            lib.hideContext()
        end
    end)

    Targets[boxName] = {created = true, zone = zone}
end

local function RegisterHouseEntranceZone(id, house)
    local coords = vec3(house.coords['enter'].x, house.coords['enter'].y, house.coords['enter'].z)
    local boxName = 'houseEntrance_' .. id
    local boxData = Targets[boxName] or {}

    if boxData and boxData.created then
        return
    end

    local zone = BoxZone:Create(coords, 2, 1, {
        name = boxName,
        heading = house.coords['enter'].h,
        minZ = house.coords['enter'].z - 1.0,
        maxZ = house.coords['enter'].z + 1.0
    })
    zone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            showEntranceHeaderMenu()
        else
            lib.hideContext()
        end
    end)

    Targets[boxName] = {created = true, zone = zone}
end

local function DeleteBoxTarget(box)
    if not box then
        return
    end

    box:remove()
end

local function DeleteHousesTargets()
    if Targets and next(Targets) then
        for id, target in pairs(Targets) do
            if not string.find(id, "Exit") then
                target.zone:remove()

                Targets[id] = nil
            end
        end
    end
end

local function SetHousesEntranceTargets()
    if Houses and next(Houses) then
        for id, house in pairs(Houses) do
            if house and house.coords and house.coords['enter'] then
                RegisterHouseEntranceZone(id, house)
            end
        end
    end
end

RegisterNetEvent('qb-houses:client:setHouseConfig', function(houseConfig)
    Houses = houseConfig

    DeleteHousesTargets()
    SetHousesEntranceTargets()
end)

local function openHouseAnim()
    lib.requestAnimDict("anim@heists@keycard@")

    TaskPlayAnim(cache.ped, "anim@heists@keycard@", "exit", 5.0, 1.0, -1, 16, 0, 0, 0, 0)
    RemoveAnimDict("anim@heists@keycard@")

    Wait(400)

    ClearPedTasks(cache.ped)
end

local function openContract(bool)
    SetNuiFocus(bool, bool)
    SendNUIMessage({
        type = "toggle",
        status = bool
    })
end

local function GetClosestPlayer()
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(cache.ped)

    for i = 1, #closestPlayers, 1 do
        if closestPlayers[i] ~= cache.playerId then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
	end

	return closestPlayer, closestDistance
end

local function DoRamAnimation(bool)
    local dict = "missheistfbi3b_ig7"

    lib.requestAnimDict(dict)

    if bool then
        TaskPlayAnim(cache.ped, dict, "lift_fibagent_loop", 8.0, 8.0, -1, 1, -1, false, false, false)
    else
        TaskPlayAnim(cache.ped, dict, "exit", 8.0, 8.0, -1, 1, -1, false, false, false)
    end

    RemoveAnimDict(dict)
end

local function setViewCam(coords, h, yaw)
    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords.x, coords.y, coords.z, yaw, 0.00, h, 80.00, false, 0)

    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)

    viewCam = true
end

local function InstructionButton(ControlButton)
    ScaleformMovieMethodAddParamPlayerNameString(ControlButton)
end

local function InstructionButtonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

local function CreateInstuctionScaleform(scaleform)
    scaleform = RequestScaleformMovie(scaleform)
    while not HasScaleformMovieLoaded(scaleform) do
        Wait(0)
    end

    PushScaleformMovieFunction(scaleform, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()
    PushScaleformMovieFunction(scaleform, "SET_CLEAR_SPACE")
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()
    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(1)

    InstructionButton(GetControlInstructionalButton(1, 194, true))
    InstructionButtonMessage(Lang:t("info.exit_camera"))

    PopScaleformMovieFunctionVoid()
    PushScaleformMovieFunction(scaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
    PopScaleformMovieFunctionVoid()
    PushScaleformMovieFunction(scaleform, "SET_BACKGROUND_COLOUR")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(80)
    PopScaleformMovieFunctionVoid()

    return scaleform
end

local function FrontDoorCam(coords)
    DoScreenFadeOut(150)
    Wait(500)

    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords.x, coords.y, coords.z + 0.5, 0.0, 0.00, coords.h - 180, 80.00, false, 0)

    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)

    TriggerEvent('qb-weathersync:client:EnableSync')

    FrontCam = true

    FreezeEntityPosition(cache.ped, true)

    Wait(500)
    DoScreenFadeIn(150)

    SendNUIMessage({
        type = "frontcam",
        toggle = true,
        label = Houses[ClosestHouse].adress
    })

    CreateThread(function()
        while FrontCam do
            local instructions = CreateInstuctionScaleform("instructional_buttons")

            DrawScaleformMovieFullscreen(instructions, 255, 255, 255, 255, 0)
            SetTimecycleModifier("scanline_cam_cheap")
            SetTimecycleModifierStrength(1.0)

            if IsControlJustPressed(1, 194) then -- Backspace
                DoScreenFadeOut(150)

                SendNUIMessage({
                    type = "frontcam",
                    toggle = false
                })

                Wait(500)

                RenderScriptCams(false, true, 500, true, true)
                FreezeEntityPosition(cache.ped, false)
                SetCamActive(cam, false)
                DestroyCam(cam, true)
                ClearTimecycleModifier("scanline_cam_cheap")

                cam = nil
                FrontCam = false

                Wait(500)

                DoScreenFadeIn(150)
            end

            local getCameraRot = GetCamRot(cam, 2)

            -- ROTATE UP
            if IsControlPressed(0, 32) then -- W
                if getCameraRot.x <= 0.0 then
                    SetCamRot(cam, getCameraRot.x + 0.7, 0.0, getCameraRot.z, 2)
                end
            end

            -- ROTATE DOWN
            if IsControlPressed(0, 33) then -- S
                if getCameraRot.x >= -50.0 then
                    SetCamRot(cam, getCameraRot.x - 0.7, 0.0, getCameraRot.z, 2)
                end
            end

            -- ROTATE LEFT
            if IsControlPressed(0, 34) then -- A
                SetCamRot(cam, getCameraRot.x, 0.0, getCameraRot.z + 0.7, 2)
            end

            -- ROTATE RIGHT
            if IsControlPressed(0, 35) then -- D
                SetCamRot(cam, getCameraRot.x, 0.0, getCameraRot.z - 0.7, 2)
            end

            Wait(0)
        end
    end)
end

local function disableViewCam()
    if viewCam then
        RenderScriptCams(false, true, 500, true, true)
        SetCamActive(cam, false)
        DestroyCam(cam, true)

        viewCam = false
    end
end

local function SetClosestHouse()
    local pos = GetEntityCoords(cache.ped, true)
    local current = nil
    local dist = nil

    if not IsInside then
        for id, _ in pairs(Houses) do
            local distcheck = #(pos - vec3(Houses[id].coords.enter.x, Houses[id].coords.enter.y, Houses[id].coords.enter.z))

            if current then
                if distcheck < dist then
                    current = id
                    dist = distcheck
                end
            else
                dist = distcheck
                current = id
            end
        end

        ClosestHouse = current

        if ClosestHouse and tonumber(dist) < 30 then
            QBCore.Functions.TriggerCallback('qb-houses:server:ProximityKO', function(key, owned)
                HasHouseKey = key
                isOwned = owned
            end, ClosestHouse)
        end
    end

    TriggerEvent('qb-garages:client:setHouseGarage', ClosestHouse, HasHouseKey)
end

local function setHouseLocations()
    if ClosestHouse then
        QBCore.Functions.TriggerCallback('qb-houses:server:getHouseLocations', function(result)
            if result then
                if result.stash then
                    stashLocation = json.decode(result.stash)

                    RegisterStashTarget()
                end

                if result.outfit then
                    outfitLocation = json.decode(result.outfit)

                    RegisterOutfitsTarget()
                end

                if result.logout then
                    logoutLocation = json.decode(result.logout)

                    RegisterCharactersTarget()
                end
            end
        end, ClosestHouse)
    end
end

local function UnloadDecorations()
	if ObjectList then
		for _, v in pairs(ObjectList) do
			if DoesEntityExist(v.object) then
				DeleteObject(v.object)
			end
		end
	end
end

local function LoadDecorations(house)
	if not Houses[house].decorations or not next(Houses[house].decorations) then
		QBCore.Functions.TriggerCallback('qb-houses:server:getHouseDecorations', function(result)
			Houses[house].decorations = result

			if Houses[house].decorations then
				ObjectList = {}

				for k, _ in pairs(Houses[house].decorations) do
					if Houses[house].decorations[k] then
						if Houses[house].decorations[k].object then
							if DoesEntityExist(Houses[house].decorations[k].object) then
								DeleteObject(Houses[house].decorations[k].object)
							end
						end

                        local modelHash = joaat(Houses[house].decorations[k].hashname)

                        lib.requestModel(modelHash)

                        local decorateObject = CreateObject(modelHash, Houses[house].decorations[k].x, Houses[house].decorations[k].y, Houses[house].decorations[k].z, false, false, false)

                        FreezeEntityPosition(decorateObject, true)
						SetEntityCoordsNoOffset(decorateObject, Houses[house].decorations[k].x, Houses[house].decorations[k].y, Houses[house].decorations[k].z)
						SetEntityRotation(decorateObject, Houses[house].decorations[k].rotx, Houses[house].decorations[k].roty, Houses[house].decorations[k].rotz)

                        ObjectList[Houses[house].decorations[k].objectId] = {hashname = Houses[house].decorations[k].hashname, x = Houses[house].decorations[k].x, y = Houses[house].decorations[k].y, z = Houses[house].decorations[k].z, rotx = Houses[house].decorations[k].rotx, roty = Houses[house].decorations[k].roty, rotz = Houses[house].decorations[k].rotz, object = decorateObject, objectId = Houses[house].decorations[k].objectId}
					end
				end
			end
		end, house)
	elseif Houses[house].decorations then
		ObjectList = {}

		for k, _ in pairs(Houses[house].decorations) do
			if Houses[house].decorations[k] then
				if Houses[house].decorations[k].object then
					if DoesEntityExist(Houses[house].decorations[k].object) then
						DeleteObject(Houses[house].decorations[k].object)
					end
				end

				local modelHash = joaat(Houses[house].decorations[k].hashname)

				lib.requestModel(modelHash)

				local decorateObject = CreateObject(modelHash, Houses[house].decorations[k].x, Houses[house].decorations[k].y, Houses[house].decorations[k].z, false, false, false)

                PlaceObjectOnGroundProperly(decorateObject)
				FreezeEntityPosition(decorateObject, true)
				SetEntityCoordsNoOffset(decorateObject, Houses[house].decorations[k].x, Houses[house].decorations[k].y, Houses[house].decorations[k].z)

                Houses[house].decorations[k].object = decorateObject

                SetEntityRotation(decorateObject, Houses[house].decorations[k].rotx, Houses[house].decorations[k].roty, Houses[house].decorations[k].rotz)

                ObjectList[Houses[house].decorations[k].objectId] = {hashname = Houses[house].decorations[k].hashname, x = Houses[house].decorations[k].x, y = Houses[house].decorations[k].y, z = Houses[house].decorations[k].z, rotx = Houses[house].decorations[k].rotx, roty = Houses[house].decorations[k].roty, rotz = Houses[house].decorations[k].rotz, object = decorateObject, objectId = Houses[house].decorations[k].objectId}
			end
		end
	end
end

local function CheckDistance(target, distance)
    local pos = GetEntityCoords(cache.ped)

    return #(pos - target) <= distance
end

-- GUI Functions
local function RemoveHouseKey(citizenData)
    TriggerServerEvent('qb-houses:server:removeHouseKey', ClosestHouse, citizenData)

    lib.hideContext()
end

local function getKeyHolders()
    if fetchingHouseKeys then
        return
    end

    fetchingHouseKeys = true

    local p = promise.new()

    QBCore.Functions.TriggerCallback('qb-houses:server:getHouseKeyHolders', function(holders)
        p:resolve(holders)
    end,ClosestHouse)

    return Await(p)
end

function HouseKeysMenu()
    local holders = getKeyHolders()

    fetchingHouseKeys = false

    if not holders or not next(holders) then
        QBCore.Functions.Notify(Lang:t("error.no_key_holders"), "error", 3500)

        lib.hideContext()
    else
        local keyholderMenu = {}

        for k, _ in pairs(holders) do
            keyholderMenu[#keyholderMenu + 1] = {
                title = holders[k].firstname .. " " .. holders[k].lastname,
                event = "qb-houses:client:OpenClientOptions",
                args = {
                    citizenData = holders[k]
                }
            }
        end

        lib.registerContext({
            id = 'open_houseKeyholders',
            title = "House: Key holders",
            options = keyholderMenu
        })
        lib.showContext('open_houseKeyholders')
    end
end

local function optionMenu(citizenData)
    lib.registerContext({
        id = 'open_houseKeyholder',
        title = "House: Key holder",
        options = {
            {
                title = Lang:t("menu.remove_key"),
                icon = "fa-solid fa-circle-minus",
                event = "qb-houses:client:RevokeKey",
                args = {
                    citizenData = citizenData
                }
            },
            {
                title = Lang:t("menu.back"),
                icon = "fa-solid fa-arrow-left",
                event = "qb-houses:client:removeHouseKey"
            }
        }
    })
    lib.showContext('open_houseKeyholder')
end

-- Shell Configuration
local function getDataForHouseTier(house, coords)
    if Houses[house].tier == 1 then
        return exports['qb-interior']:CreateApartmentShell(coords)
    elseif Houses[house].tier == 2 then
        return exports['qb-interior']:CreateTier1House(coords)
    elseif Houses[house].tier == 3 then
        return exports['qb-interior']:CreateTrevorsShell(coords)
    elseif Houses[house].tier == 4 then
        return exports['qb-interior']:CreateCaravanShell(coords)
    elseif Houses[house].tier == 5 then
        return exports['qb-interior']:CreateLesterShell(coords)
    elseif Houses[house].tier == 6 then
        return exports['qb-interior']:CreateRanchShell(coords)
    elseif Houses[house].tier == 7 then
        return exports['qb-interior']:CreateContainer(coords)
    elseif Houses[house].tier == 8 then
        return exports['qb-interior']:CreateFurniMid(coords)
    elseif Houses[house].tier == 9 then
        return exports['qb-interior']:CreateFurniMotelModern(coords)
    elseif Houses[house].tier == 10 then
        return exports['qb-interior']:CreateFranklinAunt(coords)
    elseif Houses[house].tier == 11 then
        return exports['qb-interior']:CreateGarageMed(coords)
    elseif Houses[house].tier == 12 then
        return exports['qb-interior']:CreateMichael(coords)
    elseif Houses[house].tier == 13 then
        return exports['qb-interior']:CreateOffice1(coords)
    elseif Houses[house].tier == 14 then
        return exports['qb-interior']:CreateStore1(coords)
    elseif Houses[house].tier == 15 then
        return exports['qb-interior']:CreateWarehouse1(coords)
    elseif Houses[house].tier == 16 then
        return exports['qb-interior']:CreateFurniMotelStandard(coords) -- End of free shells
    elseif Houses[house].tier == 17 then
        return exports['qb-interior']:CreateMedium2(coords)
    elseif Houses[house].tier == 18 then
        return exports['qb-interior']:CreateMedium3(coords)
    elseif Houses[house].tier == 19 then
        return exports['qb-interior']:CreateBanham(coords)
    elseif Houses[house].tier == 20 then
        return exports['qb-interior']:CreateWestons(coords)
    elseif Houses[house].tier == 21 then
        return exports['qb-interior']:CreateWestons2(coords)
    elseif Houses[house].tier == 22 then
        return exports['qb-interior']:CreateClassicHouse(coords)
    elseif Houses[house].tier == 23 then
        return exports['qb-interior']:CreateClassicHouse2(coords)
    elseif Houses[house].tier == 24 then
        return exports['qb-interior']:CreateClassicHouse3(coords)
    elseif Houses[house].tier == 25 then
        return exports['qb-interior']:CreateHighend1(coords)
    elseif Houses[house].tier == 26 then
        return exports['qb-interior']:CreateHighend2(coords)
    elseif Houses[house].tier == 27 then
        return exports['qb-interior']:CreateHighend3(coords)
    elseif Houses[house].tier == 28 then
        return exports['qb-interior']:CreateHighend(coords)
    elseif Houses[house].tier == 29 then
        return exports['qb-interior']:CreateHighendV2(coords)
    elseif Houses[house].tier == 30 then
        return exports['qb-interior']:CreateStashHouse(coords)
    elseif Houses[house].tier == 31 then
        return exports['qb-interior']:CreateStashHouse2(coords)
    elseif Houses[house].tier == 32 then
        return exports['qb-interior']:CreateGarageLow(coords)
    elseif Houses[house].tier == 33 then
        return exports['qb-interior']:CreateGarageHigh(coords)
    elseif Houses[house].tier == 34 then
        return exports['qb-interior']:CreateOffice2(coords)
    elseif Houses[house].tier == 35 then
        return exports['qb-interior']:CreateOfficeBig(coords)
    elseif Houses[house].tier == 36 then
        return exports['qb-interior']:CreateBarber(coords)
    elseif Houses[house].tier == 37 then
        return exports['qb-interior']:CreateGunstore(coords)
    elseif Houses[house].tier == 38 then
        return exports['qb-interior']:CreateStore2(coords)
    elseif Houses[house].tier == 39 then
        return exports['qb-interior']:CreateStore3(coords)
    elseif Houses[house].tier == 40 then
        return exports['qb-interior']:CreateWarehouse2(coords)
    elseif Houses[house].tier == 41 then
        return exports['qb-interior']:CreateWarehouse3(coords)
    elseif Houses[house].tier == 42 then
        return exports['qb-interior']:CreateK4Coke(coords)
    elseif Houses[house].tier == 43 then
        return exports['qb-interior']:CreateK4Meth(coords)
    elseif Houses[house].tier == 44 then
        return exports['qb-interior']:CreateK4Weed(coords)
    elseif Houses[house].tier == 45 then
        return exports['qb-interior']:CreateContainer2(coords)
    elseif Houses[house].tier == 46 then
        return exports['qb-interior']:CreateFurniStash1(coords)
    elseif Houses[house].tier == 47 then
        return exports['qb-interior']:CreateFurniStash3(coords)
    elseif Houses[house].tier == 48 then
        return exports['qb-interior']:CreateFurniLow(coords)
    elseif Houses[house].tier == 49 then
        return exports['qb-interior']:CreateFurniMotel(coords)
    elseif Houses[house].tier == 50 then
        return exports['qb-interior']:CreateFurniMotelClassic(coords)
    elseif Houses[house].tier == 51 then
        return exports['qb-interior']:CreateFurniMotelHigh(coords)
    elseif Houses[house].tier == 52 then
        return exports['qb-interior']:CreateFurniMotelModern2(coords)
    elseif Houses[house].tier == 53 then
        return exports['qb-interior']:CreateFurniMotelModern3(coords)
    elseif Houses[house].tier == 54 then
        return exports['qb-interior']:CreateCoke(coords)
    elseif Houses[house].tier == 55 then
        return exports['qb-interior']:CreateCoke2(coords)
    elseif Houses[house].tier == 56 then
        return exports['qb-interior']:CreateMeth(coords)
    elseif Houses[house].tier == 57 then
        return exports['qb-interior']:CreateWeed(coords)
    elseif Houses[house].tier == 58 then
        return exports['qb-interior']:CreateWeed2(coords)
    elseif Houses[house].tier == 59 then
        return exports['qb-interior']:CreateMansion(coords)
    elseif Houses[house].tier == 60 then
        return exports['qb-interior']:CreateMansion2(coords)
    elseif Houses[house].tier == 61 then
        return exports['qb-interior']:CreateMansion3(coords)
    elseif Houses[house].tier == 62 then
        return exports['qb-interior']:CreateHotel1(coords)
    elseif Houses[house].tier == 63 then
        return exports['qb-interior']:CreateHotel2(coords)
    elseif Houses[house].tier == 64 then
        return exports['qb-interior']:CreateHotel3(coords)
    elseif Houses[house].tier == 65 then
        return exports['qb-interior']:CreateMotel1(coords)
    elseif Houses[house].tier == 66 then
        return exports['qb-interior']:CreateMotel2(coords)
    elseif Houses[house].tier == 67 then
        return exports['qb-interior']:CreateMotel3(coords)
    elseif Houses[house].tier == 68 then
        return exports['qb-interior']:CreateV2Default1(coords)
    elseif Houses[house].tier == 69 then
        return exports['qb-interior']:CreateV2Default2(coords)
    elseif Houses[house].tier == 70 then
        return exports['qb-interior']:CreateV2Default3(coords)
    elseif Houses[house].tier == 71 then
        return exports['qb-interior']:CreateV2Default4(coords)
    elseif Houses[house].tier == 72 then
        return exports['qb-interior']:CreateV2Default5(coords)
    elseif Houses[house].tier == 73 then
        return exports['qb-interior']:CreateV2Default6(coords)
    elseif Houses[house].tier == 74 then
        return exports['qb-interior']:CreateV2Deluxe1(coords)
    elseif Houses[house].tier == 75 then
        return exports['qb-interior']:CreateV2Deluxe2(coords)
    elseif Houses[house].tier == 76 then
        return exports['qb-interior']:CreateV2Deluxe3(coords)
    elseif Houses[house].tier == 77 then
        return exports['qb-interior']:CreateV2HighEnd1(coords)
    elseif Houses[house].tier == 78 then
        return exports['qb-interior']:CreateV2HighEnd2(coords)
    elseif Houses[house].tier == 79 then
        return exports['qb-interior']:CreateV2HighEnd3(coords)
    elseif Houses[house].tier == 80 then
        return exports['qb-interior']:CreateV2Medium1(coords)
    elseif Houses[house].tier == 81 then
        return exports['qb-interior']:CreateV2Medium2(coords)
    elseif Houses[house].tier == 82 then
        return exports['qb-interior']:CreateV2Medium3(coords)
    elseif Houses[house].tier == 83 then
        return exports['qb-interior']:CreateV2Modern1(coords)
    elseif Houses[house].tier == 84 then
        return exports['qb-interior']:CreateV2Modern2(coords)
    elseif Houses[house].tier == 85 then
        return exports['qb-interior']:CreateV2Modern3(coords)
    elseif Houses[house].tier == 86 then
        return exports['qb-interior']:VineWoodHouse1(coords)
    elseif Houses[house].tier == 87 then
        return exports['qb-interior']:VineWoodHouse2(coords)
    elseif Houses[house].tier == 88 then
        return exports['qb-interior']:VineWoodHouse3(coords)
    elseif Houses[house].tier == 89 then
        return exports['qb-interior']:CreateK4GunWarehouse(coords)
    elseif Houses[house].tier == 90 then
        return exports['qb-interior']:CreateK4LuxuryHouse1(coords)
    elseif Houses[house].tier == 91 then
        return exports['qb-interior']:CreateK4LuxuryHouse2(coords)
    elseif Houses[house].tier == 92 then
        return exports['qb-interior']:CreateK4LuxuryHouse3(coords)
    elseif Houses[house].tier == 93 then
        return exports['qb-interior']:CreateK4LuxuryHouse4(coords)
    elseif Houses[house].tier == 94 then
        return exports['qb-interior']:CreateK4ManorHouse(coords)
    elseif Houses[house].tier == 95 then
        return exports['qb-interior']:CreateK4Garage1(coords)
    elseif Houses[house].tier == 96 then
        return exports['qb-interior']:CreateK4Garage2(coords)
    elseif Houses[house].tier == 97 then
        return exports['qb-interior']:CreateK4Garage3(coords)
    elseif Houses[house].tier == 98 then
        return exports['qb-interior']:CreateK4Garage4(coords)
    elseif Houses[house].tier == 99 then
        return exports['qb-interior']:CreateK4Safehouse(coords)
    elseif Houses[house].tier == 100 then
        return exports['qb-interior']:CreateK4Warehouse(coords)
    else
        QBCore.Functions.Notify(Lang:t("error.invalid_tier"), 'error')
    end
end

local function enterOwnedHouse(house)
    CurrentHouse = house
    ClosestHouse = house

    TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.25)

    openHouseAnim()
    
    IsInside = true

    Wait(250)

    local coords = { x = Houses[house].coords.enter.x, y = Houses[house].coords.enter.y, z= Houses[house].coords.enter.z - Config.MinZOffset}
    LoadDecorations(house)

    data = getDataForHouseTier(house, coords)

    Wait(100)

    houseObj = data[1]
    POIOffsets = data[2]
    entering = true

    Wait(500)

    TriggerServerEvent('qb-houses:server:SetInsideMeta', house, true)
    TriggerEvent('qb-weathersync:client:EnableSync')
    TriggerEvent('qb-weed:client:getHousePlants', house)

    entering = false

    setHouseLocations()

    lib.hideContext()

    Wait(5000)

    RegisterHouseExitZone(house)
end

local function LeaveHouse(house)
    if not FrontCam then
        IsInside = false
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.25)

        openHouseAnim()

        Wait(250)
        DoScreenFadeOut(250)
        Wait(500)

        exports['qb-interior']:DespawnInterior(houseObj, function()
            UnloadDecorations()

            TriggerEvent('qb-weathersync:client:EnableSync')

            Wait(250)
            DoScreenFadeIn(250)

            SetEntityCoords(cache.ped, Houses[CurrentHouse].coords.enter.x, Houses[CurrentHouse].coords.enter.y, Houses[CurrentHouse].coords.enter.z)
            SetEntityHeading(cache.ped, Houses[CurrentHouse].coords.enter.h)

            TriggerEvent('qb-weed:client:leaveHouse')
            TriggerServerEvent('qb-houses:server:SetInsideMeta', house, false)

            CurrentHouse = nil

            DeleteBoxTarget(stashTargetBox)

            isInsideStashTarget = false

            DeleteBoxTarget(outfitsTargetBox)

            isInsideOutfitsTarget = false

            DeleteBoxTarget(charactersTargetBox)

            isInsiteCharactersTarget = false

            DeleteBoxTarget(Targets['houseExit_' .. house].zone)

            Targets['houseExit_' .. house] = nil
        end)
    end
end

local function enterNonOwnedHouse(house)
    CurrentHouse = house
    ClosestHouse = house

    TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.25)

    openHouseAnim()

    IsInside = true

    Wait(250)

    local coords = { x = Houses[ClosestHouse].coords.enter.x, y = Houses[ClosestHouse].coords.enter.y, z= Houses[ClosestHouse].coords.enter.z - Config.MinZOffset}
    
    LoadDecorations(house)

    data = getDataForHouseTier(house, coords)
    houseObj = data[1]
    POIOffsets = data[2]
    entering = true

    Wait(500)

    TriggerServerEvent('qb-houses:server:SetInsideMeta', house, true)
    TriggerEvent('qb-weathersync:client:EnableSync')
    TriggerEvent('qb-weed:client:getHousePlants', house)

    entering = false
    InOwnedHouse = true

    setHouseLocations()

    lib.hideContext()

    RegisterHouseExitZone(house)
end

local function isNearHouses()
    local pos = GetEntityCoords(cache.ped)

    if ClosestHouse then
        local dist = #(pos - vec3(Houses[ClosestHouse].coords.enter.x, Houses[ClosestHouse].coords.enter.y, Houses[ClosestHouse].coords.enter.z))
        
        if dist <= 1.5 then
            if HasHouseKey then
                return true
            end
        end
    end
end
exports('isNearHouses', isNearHouses)

-- Events
RegisterNetEvent('qb-houses:server:sethousedecorations', function(house, decorations)
	Houses[house].decorations = decorations

	if IsInside and ClosestHouse == house then
		LoadDecorations(house)
	end
end)

RegisterNetEvent('qb-houses:client:sellHouse', function()
    if ClosestHouse and HasHouseKey then
        TriggerServerEvent('qb-houses:server:viewHouse', ClosestHouse)
    end
end)

RegisterNetEvent('qb-houses:client:EnterHouse', function()
    local pos = GetEntityCoords(cache.ped)

    if ClosestHouse then
        local dist = #(pos - vec3(Houses[ClosestHouse].coords.enter.x, Houses[ClosestHouse].coords.enter.y, Houses[ClosestHouse].coords.enter.z))

        if dist <= 1.5 then
            if HasHouseKey then
                enterOwnedHouse(ClosestHouse)
            else
                if not Houses[ClosestHouse].locked then
                    enterNonOwnedHouse(ClosestHouse)
                end
            end
        end
    end
end)

RegisterNetEvent('qb-houses:client:RequestRing', function()
    if ClosestHouse then
        TriggerServerEvent('qb-houses:server:RingDoor', ClosestHouse)
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('qb-houses:server:setHouses')

    SetClosestHouse()

    TriggerEvent('qb-houses:client:setupHouseBlips')

    if Config.UnownedBlips then TriggerEvent('qb-houses:client:setupHouseBlips2') end

    Wait(100)

    TriggerEvent('qb-garages:client:setHouseGarage', ClosestHouse, HasHouseKey)
    TriggerServerEvent("qb-houses:server:setHouses")
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    IsInside = false
    ClosestHouse = nil
    HasHouseKey = false
    isOwned = false

    for _, v in pairs(OwnedHouseBlips) do
        RemoveBlip(v)
    end

    if Config.UnownedBlips then
        for _, v in pairs(UnownedHouseBlips) do
            RemoveBlip(v)
        end
    end

    DeleteHousesTargets()
end)

RegisterNetEvent('qb-houses:client:lockHouse', function(bool, house)
    Houses[house].locked = bool
end)

RegisterNetEvent('qb-houses:client:createHouses', function(price, tier)
    local pos = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)
	local s1, _ = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    local street = GetStreetNameFromHashKey(s1)
    local coords = {
        enter = { x = pos.x, y = pos.y, z = pos.z, h = heading},
        cam = { x = pos.x, y = pos.y, z = pos.z, h = heading, yaw = -10.00},
    }

    street = street:gsub("%-", " ")

    TriggerServerEvent('qb-houses:server:addNewHouse', street, coords, price, tier)

    if Config.UnownedBlips then TriggerServerEvent('qb-houses:server:createBlip') end
end)

RegisterNetEvent('qb-houses:client:addGarage', function()
    if ClosestHouse then
        local pos = GetEntityCoords(cache.ped)
        local heading = GetEntityHeading(cache.ped)
        local coords = {
            x = pos.x,
            y = pos.y,
            z = pos.z,
            h = heading
        }

        TriggerServerEvent('qb-houses:server:addGarage', ClosestHouse, coords)
    else
        QBCore.Functions.Notify(Lang:t("error.no_house"), "error")
    end
end)

RegisterNetEvent('qb-houses:client:toggleDoorlock', function()
    local pos = GetEntityCoords(cache.ped)
    local dist = #(pos - vec3(Houses[ClosestHouse].coords.enter.x, Houses[ClosestHouse].coords.enter.y, Houses[ClosestHouse].coords.enter.z))

    if dist <= 1.5 then
        if HasHouseKey then
            if Houses[ClosestHouse].locked then
                TriggerServerEvent('qb-houses:server:lockHouse', false, ClosestHouse)

                QBCore.Functions.Notify(Lang:t("success.unlocked"), "success", 2500)
            else
                TriggerServerEvent('qb-houses:server:lockHouse', true, ClosestHouse)

                QBCore.Functions.Notify(Lang:t("error.locked"), "error", 2500)
            end
        else
            QBCore.Functions.Notify(Lang:t("error.no_keys"), "error", 3500)
        end
    else
        QBCore.Functions.Notify(Lang:t("error.no_door"), "error", 3500)
    end
end)

RegisterNetEvent('qb-houses:client:RingDoor', function(player, house)
    if ClosestHouse == house and IsInside then
        CurrentDoorBell = player

        TriggerServerEvent("InteractSound_SV:PlayOnSource", "doorbell", 0.1)

        QBCore.Functions.Notify(Lang:t("info.door_ringing"))
    end
end)

RegisterNetEvent('qb-houses:client:giveHouseKey', function()
    local player, distance = GetClosestPlayer()

    if player ~= -1 and distance < 2.5 and ClosestHouse then
        local playerId = GetPlayerServerId(player)
        local pedpos = GetEntityCoords(cache.ped)
        local housedist = #(pedpos - vec3(Houses[ClosestHouse].coords.enter.x, Houses[ClosestHouse].coords.enter.y, Houses[ClosestHouse].coords.enter.z))

        if housedist < 10 then
            TriggerServerEvent('qb-houses:server:giveHouseKey', playerId, ClosestHouse)
        else
            QBCore.Functions.Notify(Lang:t("error.no_door"), "error")
        end
    elseif not ClosestHouse then
        QBCore.Functions.Notify(Lang:t("error.no_house"), "error")
    else
        QBCore.Functions.Notify(Lang:t("error.no_one_near"), "error")
    end
end)

RegisterNetEvent('qb-houses:client:removeHouseKey', function()
    if ClosestHouse then
        local pedpos = GetEntityCoords(cache.ped)
        local housedist = #(pedpos - vec3(Houses[ClosestHouse].coords.enter.x, Houses[ClosestHouse].coords.enter.y, Houses[ClosestHouse].coords.enter.z))

        if housedist <= 5 then
            QBCore.Functions.TriggerCallback('qb-houses:server:getHouseOwner', function(result)
                if QBCore.Functions.GetPlayerData().citizenid == result then
                    HouseKeysMenu()
                else
                    QBCore.Functions.Notify(Lang:t("error.not_owner"), "error")
                end
            end, ClosestHouse)
        else
            QBCore.Functions.Notify(Lang:t("error.no_door"), "error")
        end
    else
        QBCore.Functions.Notify(Lang:t("error.no_door"), "error")
    end
end)

RegisterNetEvent('qb-houses:client:RevokeKey', function(cData)
    RemoveHouseKey(cData.citizenData)
end)

RegisterNetEvent('qb-houses:client:refreshHouse', function()
    Wait(100)

    SetClosestHouse()
end)

RegisterNetEvent('qb-houses:client:SpawnInApartment', function(house)
    local pos = GetEntityCoords(cache.ped)

    if rangDoorbell then
        if #(pos - vec3(Houses[house].coords.enter.x, Houses[house].coords.enter.y, Houses[house].coords.enter.z)) > 5 then
            return
        end
    end

    ClosestHouse = house

    enterNonOwnedHouse(house)
end)

RegisterNetEvent('qb-houses:client:enterOwnedHouse', function(house)
    QBCore.Functions.GetPlayerData(function(PlayerData)
		if PlayerData.metadata.injail == 0 then
			enterOwnedHouse(house)
		end
	end)
end)

RegisterNetEvent('qb-houses:client:LastLocationHouse', function(houseId)
    QBCore.Functions.GetPlayerData(function(PlayerData)
		if PlayerData.metadata.injail == 0 then
			enterOwnedHouse(houseId)
		end
	end)
end)

RegisterNetEvent('qb-houses:client:setupHouseBlips', function() -- Setup owned on load
    CreateThread(function()
        Wait(2000)

        if LocalPlayer.state.isLoggedIn then
            QBCore.Functions.TriggerCallback('qb-houses:server:getOwnedHouses', function(ownedHouses)
                if ownedHouses then
                    for k, _ in pairs(ownedHouses) do
                        local house = Houses[ownedHouses[k]]
                        local HouseBlip = AddBlipForCoord(house.coords.enter.x, house.coords.enter.y, house.coords.enter.z)

                        SetBlipSprite(HouseBlip, 40)
                        SetBlipDisplay(HouseBlip, 4)
                        SetBlipScale(HouseBlip, 0.65)
                        SetBlipAsShortRange(HouseBlip, true)
                        SetBlipColour(HouseBlip, 3)

                        AddTextEntry('OwnedHouse', house.adress)
                        BeginTextCommandSetBlipName('OwnedHouse')
                        EndTextCommandSetBlipName(HouseBlip)

                        OwnedHouseBlips[#OwnedHouseBlips + 1] = HouseBlip
                    end
                end
            end)
        end
    end)
end)

RegisterNetEvent('qb-houses:client:setupHouseBlips2', function() -- Setup unowned on load
    for _, v in pairs(Houses) do
        if not v.owned then
            local HouseBlip2 = AddBlipForCoord(v.coords.enter.x, v.coords.enter.y, v.coords.enter.z)

            SetBlipSprite(HouseBlip2, 40)
            SetBlipDisplay(HouseBlip2, 4)
            SetBlipScale(HouseBlip2, 0.65)
            SetBlipAsShortRange(HouseBlip2, true)
            SetBlipColour(HouseBlip2, 3)

            AddTextEntry('UnownedHouse', Lang:t("info.house_for_sale"))
            BeginTextCommandSetBlipName('UnownedHouse')
            EndTextCommandSetBlipName(HouseBlip2)

            UnownedHouseBlips[#UnownedHouseBlips + 1] = HouseBlip2
        end
    end
end)

RegisterNetEvent('qb-houses:client:createBlip', function(coords) -- Create unowned on command
    local NewHouseBlip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(NewHouseBlip, 40)
    SetBlipDisplay(NewHouseBlip, 4)
    SetBlipScale(NewHouseBlip, 0.65)
    SetBlipAsShortRange(NewHouseBlip, true)
    SetBlipColour(NewHouseBlip, 3)

    AddTextEntry('NewHouseBlip', Lang:t("info.house_for_sale"))
    BeginTextCommandSetBlipName('NewHouseBlip')
    EndTextCommandSetBlipName(NewHouseBlip)

    UnownedHouseBlips[#UnownedHouseBlips + 1] = NewHouseBlip
end)

RegisterNetEvent('qb-houses:client:refreshBlips', function() -- Refresh unowned on buy
    for _, v in pairs(UnownedHouseBlips) do
        RemoveBlip(v)
    end

    Wait(250)

    TriggerEvent('qb-houses:client:setupHouseBlips2')

    DeleteHousesTargets()
    SetHousesEntranceTargets()
end)

RegisterNetEvent('qb-houses:client:SetClosestHouse', function()
    SetClosestHouse()
end)

RegisterNetEvent('qb-houses:client:viewHouse', function(houseprice, brokerfee, bankfee, taxes, firstname, lastname)
    setViewCam(Houses[ClosestHouse].coords.cam, Houses[ClosestHouse].coords.cam.h, Houses[ClosestHouse].coords.yaw)

    Wait(500)

    openContract(true)

    SendNUIMessage({
        type = "setupContract",
        firstname = firstname,
        lastname = lastname,
        street = Houses[ClosestHouse].adress,
        houseprice = houseprice,
        brokerfee = brokerfee,
        bankfee = bankfee,
        taxes = taxes,
        totalprice = houseprice + brokerfee + bankfee + taxes
    })
end)

RegisterNetEvent('qb-houses:client:setLocation', function(cData)
    local pos = GetEntityCoords(cache.ped)
    local coords = {x = pos.x, y = pos.y, z = pos.z}

    if IsInside then
        if HasHouseKey then
            if cData.id == 'setstash' then
                TriggerServerEvent('qb-houses:server:setLocation', coords, ClosestHouse, 1)
            elseif cData.id == 'setoutift' then
                TriggerServerEvent('qb-houses:server:setLocation', coords, ClosestHouse, 2)
            elseif cData.id == 'setlogout' then
                TriggerServerEvent('qb-houses:server:setLocation', coords, ClosestHouse, 3)
            end
        else
            QBCore.Functions.Notify(Lang:t("error.not_owner"), "error")
        end
    else
        QBCore.Functions.Notify(Lang:t("error.not_in_house"), "error")
    end
end)

RegisterNetEvent('qb-houses:client:refreshLocations', function(house, location, type)
    if ClosestHouse == house then
        if IsInside then
            if type == 1 then
                stashLocation = json.decode(location)

                DeleteBoxTarget(stashTargetBox)

                isInsideStashTarget = false

                RegisterStashTarget()
            elseif type == 2 then
                outfitLocation = json.decode(location)

                DeleteBoxTarget(outfitsTargetBox)

                isInsideOutfitsTarget = false

                RegisterOutfitsTarget()
            elseif type == 3 then
                logoutLocation = json.decode(location)

                DeleteBoxTarget(charactersTargetBox)

                isInsiteCharactersTarget = false

                RegisterCharactersTarget()
            end
        end
    end
end)

RegisterNetEvent('qb-houses:client:HomeInvasion', function()
    local pos = GetEntityCoords(cache.ped)

    if ClosestHouse then
        QBCore.Functions.TriggerCallback('police:server:IsPoliceForcePresent', function(IsPresent)
            if IsPresent then
                local dist = #(pos - vec3(Houses[ClosestHouse].coords.enter.x, Houses[ClosestHouse].coords.enter.y, Houses[ClosestHouse].coords.enter.z))

                if not Houses[ClosestHouse].IsRaming then
                    Houses[ClosestHouse].IsRaming = false
                end

                if dist < 1 then
                    if Houses[ClosestHouse].locked then
                        if not Houses[ClosestHouse].IsRaming then
                            DoRamAnimation(true)

                            local difficulty = {}

                            for _ = 1, Config.RamsNeeded, 1 do
                                difficulty[#difficulty + 1] = 'medium'
                            end

                            local success = lib.skillCheck(difficulty)

                            if success then
                                TriggerServerEvent('qb-houses:server:lockHouse', false, ClosestHouse)

                                QBCore.Functions.Notify(Lang:t("success.home_invasion"), 'success')

                                TriggerServerEvent('qb-houses:server:SetHouseRammed', true, ClosestHouse)
                                TriggerServerEvent('qb-houses:server:SetRamState', false, ClosestHouse)

                                DoRamAnimation(false)
                            else
                                TriggerServerEvent('qb-houses:server:SetRamState', false, ClosestHouse)

                                QBCore.Functions.Notify(Lang:t("error.failed_invasion"), 'error')

                                DoRamAnimation(false)
                            end

                            TriggerServerEvent('qb-houses:server:SetRamState', true, ClosestHouse)
                        else
                            QBCore.Functions.Notify(Lang:t("error.inprogress_invasion"), 'error')
                        end
                    else
                        QBCore.Functions.Notify(Lang:t("error.already_open"), 'error')
                    end
                else
                    QBCore.Functions.Notify(Lang:t("error.no_house"), "error")
                end
            else
                QBCore.Functions.Notify(Lang:t("error.no_police"), 'error')
            end
        end)
    else
        QBCore.Functions.Notify(Lang:t("error.no_house"), "error")
    end
end)

RegisterNetEvent('qb-houses:client:SetRamState', function(bool, house)
    Houses[house].IsRaming = bool

    DeleteHousesTargets()
    SetHousesEntranceTargets()
end)

RegisterNetEvent('qb-houses:client:SetHouseRammed', function(bool, house)
    Houses[house].IsRammed = bool

    DeleteHousesTargets()
    SetHousesEntranceTargets()
end)

RegisterNetEvent('qb-houses:client:ResetHouse', function()
    if ClosestHouse then
        if not Houses[ClosestHouse].IsRammed then
            Houses[ClosestHouse].IsRammed = false

            TriggerServerEvent('qb-houses:server:SetHouseRammed', false, ClosestHouse)
            TriggerServerEvent('qb-houses:server:SetRamState', false, ClosestHouse)
        end

        if Houses[ClosestHouse].IsRammed then
            openHouseAnim()

            TriggerServerEvent('qb-houses:server:SetHouseRammed', false, ClosestHouse)
            TriggerServerEvent('qb-houses:server:SetRamState', false, ClosestHouse)
            TriggerServerEvent('qb-houses:server:lockHouse', true, ClosestHouse)

            QBCore.Functions.Notify(Lang:t("success.lock_invasion"), 'success')
        else
            QBCore.Functions.Notify(Lang:t("error.no_invasion"), 'error')
        end
    end
end)

RegisterNetEvent('qb-houses:client:ExitOwnedHouse', function()
    local door = vec3(Houses[CurrentHouse].coords.enter.x + POIOffsets.exit.x, Houses[CurrentHouse].coords.enter.y + POIOffsets.exit.y, Houses[CurrentHouse].coords.enter.z - Config.MinZOffset + POIOffsets.exit.z)

    if CheckDistance(door, 1.5) then
        LeaveHouse(CurrentHouse)
    end
end)

RegisterNetEvent('qb-houses:client:FrontDoorCam', function()
    local door = vec3(Houses[CurrentHouse].coords.enter.x + POIOffsets.exit.x, Houses[CurrentHouse].coords.enter.y + POIOffsets.exit.y, Houses[CurrentHouse].coords.enter.z - Config.MinZOffset + POIOffsets.exit.z)

    if CheckDistance(door, 1.5) then
        FrontDoorCam(Houses[CurrentHouse].coords.enter)
    end
end)

RegisterNetEvent('qb-houses:client:AnswerDoorbell', function()
    if not CurrentDoorBell or CurrentDoorBell == 0 then
        QBCore.Functions.Notify(Lang:t('error.nobody_at_door'))
        return
    end

    local door = vec3(Houses[CurrentHouse].coords.enter.x + POIOffsets.exit.x, Houses[CurrentHouse].coords.enter.y + POIOffsets.exit.y, Houses[CurrentHouse].coords.enter.z - Config.MinZOffset + POIOffsets.exit.z)

    if CheckDistance(door, 1.5) and CurrentDoorBell ~= 0 then
        TriggerServerEvent("qb-houses:server:OpenDoor", CurrentDoorBell, ClosestHouse)

        CurrentDoorBell = 0
    end
end)

RegisterNetEvent('qb-houses:client:OpenStash', function()
    local stashLoc = vec3(stashLocation.x, stashLocation.y, stashLocation.z)

    if CheckDistance(stashLoc, 1.5) then
        TriggerServerEvent("inventory:server:OpenInventory", "stash", CurrentHouse)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "StashOpen", 0.4)
    end
end)

RegisterNetEvent('qb-houses:client:ChangeCharacter', function()
    local stashLoc = vec3(logoutLocation.x, logoutLocation.y, logoutLocation.z)

    if CheckDistance(stashLoc, 1.5) then
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do
            Wait(10)
        end

        exports['qb-interior']:DespawnInterior(houseObj, function()
            TriggerEvent('qb-weathersync:client:EnableSync')

            SetEntityCoords(cache.ped, Houses[CurrentHouse].coords.enter.x, Houses[CurrentHouse].coords.enter.y, Houses[CurrentHouse].coords.enter.z + 0.5)
            SetEntityHeading(cache.ped, Houses[CurrentHouse].coords.enter.h)

            InOwnedHouse = false
            IsInside = false

            TriggerServerEvent('qb-houses:server:LogoutLocation')
        end)
    end
end)

RegisterNetEvent('qb-houses:client:ChangeOutfit', function()
    local outfitLoc = vec3(outfitLocation.x, outfitLocation.y, outfitLocation.z)

    if CheckDistance(outfitLoc, 1.5) then
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "Clothes1", 0.4)
        TriggerEvent('qb-clothing:client:openOutfitMenu')
    end
end)

RegisterNetEvent('qb-houses:client:ViewHouse', function()
    local houseCoords = vec3(Houses[ClosestHouse].coords.enter.x, Houses[ClosestHouse].coords.enter.y, Houses[ClosestHouse].coords.enter.z)

    if CheckDistance(houseCoords, 1.5) then
        TriggerServerEvent('qb-houses:server:viewHouse', ClosestHouse)
    end
end)

RegisterNetEvent('qb-houses:client:KeyholderOptions', function(cData)
    optionMenu(cData.citizenData)
end)

RegisterNetEvent('qb-house:client:RefreshHouseTargets', function()
    DeleteHousesTargets()
    SetHousesEntranceTargets()
end)

-- NUI Callbacks
RegisterNUICallback('HasEnoughMoney', function(cData, cb)
    QBCore.Functions.TriggerCallback('qb-houses:server:HasEnoughMoney', function(_)
        cb('ok')
    end, cData.objectData)
end)

RegisterNUICallback('buy', function(_, cb)
    openContract(false)
    disableViewCam()

    Houses[ClosestHouse].owned = true

    if Config.UnownedBlips then
        TriggerEvent('qb-houses:client:refreshBlips')
    end

    TriggerServerEvent('qb-houses:server:buyHouse', ClosestHouse)

    cb("ok")
end)

RegisterNUICallback('exit', function(_, cb)
    openContract(false)
    disableViewCam()

    cb("ok")
end)

-- Threads
CreateThread(function()
    local wait = 500

    while not LocalPlayer.state.isLoggedIn do
        Wait(wait)
    end

    TriggerServerEvent('qb-houses:server:setHouses')
    TriggerEvent('qb-houses:client:setupHouseBlips')

    if Config.UnownedBlips then
        TriggerEvent('qb-houses:client:setupHouseBlips2')
    end

    Wait(wait)

    TriggerEvent('qb-garages:client:setHouseGarage', ClosestHouse, HasHouseKey)
    TriggerServerEvent("qb-houses:server:setHouses")

    while true do
        wait = 5000

        if not IsInside then
            SetClosestHouse()
        end

        if IsInside then
            wait = 1000

            if isInsideStashTarget then
                wait = 0

                if IsControlJustPressed(0, 38) then
                    TriggerEvent('qb-houses:client:OpenStash')

                    lib.hideTextUI()
                end
            end

            if isInsideOutfitsTarget then
                wait = 0

                if IsControlJustPressed(0, 38) then
                    TriggerEvent('qb-houses:client:ChangeOutfit')

                    lib.hideTextUI()
                end
            end

            if isInsiteCharactersTarget then
                wait = 0

                if IsControlJustPressed(0, 38) then
                    TriggerEvent('qb-houses:client:ChangeCharacter')

                    lib.hideTextUI()
                end
            end
        end

        Wait(wait)
    end
end)

RegisterCommand('getoffset', function()
    local coords = GetEntityCoords(cache.ped)
    local houseCoords = vec3(
        Houses[CurrentHouse].coords.enter.x,
        Houses[CurrentHouse].coords.enter.y,
        Houses[CurrentHouse].coords.enter.z - Config.MinZOffset
    )

    if IsInside then
        local xdist = houseCoords.x - coords.x
        local ydist = houseCoords.y - coords.y
        local zdist = houseCoords.z - coords.z

        print('X: ' .. xdist)
        print('Y: ' .. ydist)
        print('Z: ' .. zdist)
    end
end)