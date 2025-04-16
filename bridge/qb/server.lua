local QBCore = exports['qb-core']:GetCoreObject()
local Bridge = {}

local function getPlayerSource(citizenid)
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.citizenid == citizenid then
            return player.PlayerData.source
        end
    end
    return false
end

local function queryDatabaseProfiles(first, last)
    local result = MySQL.query.await("SELECT * FROM players")
    local profiles = {}
    
    for i=1, #result do
        local item = result[i]
        local charinfo = json.decode(item.charinfo)
        local firstname = (charinfo.firstname or ""):lower()
        local lastname = (charinfo.lastname or ""):lower()

        if (first == "" or firstname:find(first)) and (last == "" or lastname:find(last)) then
            local metadata = json.decode(item.metadata or '{}')
            profiles[item.citizenid] = {
                firstName = charinfo.firstname,
                lastName = charinfo.lastname,
                dob = charinfo.birthdate,
                gender = charinfo.gender,
                phone = charinfo.phone,
                id = getPlayerSource(item.citizenid),
                img = metadata.image or "user.jpg",
                ethnicity = charinfo.nationality
            }
        end
    end
    
    return profiles
end

function Bridge.nameSearch(src, first, last)
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not config.policeAccess[player.PlayerData.job.name] then return false end

    local firstname = (first or ""):lower()
    local lastname = (last or ""):lower()
    return queryDatabaseProfiles(firstname, lastname)
end

function Bridge.characterSearch(source, citizenid)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or not config.policeAccess[player.PlayerData.job.name] then return false end

    local result = MySQL.query.await("SELECT * FROM players WHERE citizenid = ?", {citizenid})
    if not result or not result[1] then return {} end
    
    local item = result[1]
    local charinfo = json.decode(item.charinfo)
    local metadata = json.decode(item.metadata or '{}')
    
    return {
        [item.citizenid] = {
            firstName = charinfo.firstname,
            lastName = charinfo.lastname,
            dob = charinfo.birthdate,
            gender = charinfo.gender,
            phone = charinfo.phone,
            id = getPlayerSource(item.citizenid),
            img = metadata.image or "user.jpg",
            ethnicity = charinfo.nationality
        }
    }
end

function Bridge.getPlayerInfo(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return {} end
    
    local metadata = player.PlayerData.metadata
    return {
        firstName = player.PlayerData.charinfo.firstname,
        lastName = player.PlayerData.charinfo.lastname,
        job = player.PlayerData.job.name,
        jobLabel = player.PlayerData.job.label,
        callsign = metadata.callsign or "",
        img = player.PlayerData.charinfo.image or "user.jpg",
        characterId = player.PlayerData.citizenid
    }
end

local function getVehicleCharacter(owner)
    local result = MySQL.query.await("SELECT * FROM players WHERE citizenid = ?", {owner})
    if not result or not result[1] then return nil end
    
    local charinfo = json.decode(result[1].charinfo)
    return {
        firstName = charinfo.firstname,
        lastName = charinfo.lastname,
        characterId = result[1].citizenid
    }
end

local function queryDatabaseVehicles(find, findData)
    local query = find == "plate" and 
        "SELECT * FROM player_vehicles WHERE plate = ?" or
        "SELECT * FROM player_vehicles WHERE citizenid = ?"
    
    local result = MySQL.query.await(query, {findData})
    local vehicles = {}
    
    for i=1, #result do
        local item = result[i]
        local character = getVehicleCharacter(item.citizenid)
        local mods = json.decode(item.mods or '{}')
        
        vehicles[#vehicles+1] = {
            id = item.id,
            color = mods.color1 and ("%d"):format(mods.color1) or "0",
            make = QBCore.Shared.Vehicles[item.vehicle]?.brand or "Unknown",
            model = QBCore.Shared.Vehicles[item.vehicle]?.name or "Unknown",
            plate = item.plate,
            class = QBCore.Shared.Vehicles[item.vehicle]?.category or "0",
            stolen = false,
            character = character
        }
    end
    
    return vehicles
end

function Bridge.viewVehicles(src, searchBy, data)
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not config.policeAccess[player.PlayerData.job.name] then return false end

    if searchBy ~= "plate" and searchBy ~= "owner" then return {} end
    return queryDatabaseVehicles(searchBy, data)
end

function Bridge.getProperties(citizenid)
    if GetResourceState("qb-houses") ~= "started" then return {} end
    
    local result = MySQL.query.await("SELECT * FROM player_houses WHERE citizenid = ?", {citizenid})
    local addresses = {}
    
    for i=1, #result do
        addresses[#addresses+1] = result[i].house
    end
    
    return addresses
end

function Bridge.getLicenses(citizenid)
    local result = MySQL.query.await("SELECT * FROM players WHERE citizenid = ?", {citizenid})
    if not result or not result[1] then return {} end
    
    local metadata = json.decode(result[1].metadata or '{}')
    return metadata.licenses or {}
end

function Bridge.editPlayerLicense(source, citizenid, licenseIdentifier, newLicenseStatus)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    
    if targetPlayer then
        local metadata = targetPlayer.PlayerData.metadata
        if metadata.licenses and metadata.licenses[licenseIdentifier] then
            metadata.licenses[licenseIdentifier].status = newLicenseStatus
            targetPlayer.Functions.SetMetaData("licenses", metadata.licenses)
        end
    else
        local result = MySQL.query.await("SELECT metadata FROM players WHERE citizenid = ?", {citizenid})
        if result and result[1] then
            local metadata = json.decode(result[1].metadata or '{}')
            if metadata.licenses and metadata.licenses[licenseIdentifier] then
                metadata.licenses[licenseIdentifier].status = newLicenseStatus
                MySQL.update.await("UPDATE players SET metadata = ? WHERE citizenid = ?", {
                    json.encode(metadata), citizenid
                })
            end
        end
    end
end

function Bridge.createInvoice(citizenid, amount)
    exports['qb-phone']:CreateInvoice(citizenid, amount, "Government Fine", "police")
end

function Bridge.vehicleStolen(id, stolen, plate)
    MySQL.update.await("UPDATE player_vehicles SET stolen = ? WHERE id = ?", {stolen, id })
end

function Bridge.getStolenVehicles()
    local plates = {}
    
    local result = MySQL.query.await("SELECT plate FROM player_vehicles WHERE stolen")
    for i=1, #result do
        plates[#plates+1] = result[i].plate
    end

    local bolos = MySQL.query.await("SELECT `data` FROM `nd_mdt_bolos` WHERE `type` = 'vehicle'")
    for i=1, #bolos do
        local veh = bolos[i]
        local info = json.decode(veh.data) or {}
        if info.plate then
            plates[#plates+1] = info.plate
        end
    end
    
    return plates
end

function Bridge.getPlayerImage(citizenid)
    local result = MySQL.query.await("SELECT metadata FROM players WHERE citizenid = ?", {citizenid})
    if not result or not result[1] then return "user.jpg" end
    
    local metadata = json.decode(result[1].metadata or '{}')
    return metadata.image or "user.jpg"
end

function Bridge.updatePlayerMetadata(source, citizenid, key, value)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if targetPlayer then
        targetPlayer.Functions.SetMetaData(key, value)
    else
        local result = MySQL.query.await("SELECT metadata FROM players WHERE citizenid = ?", {citizenid})
        if result and result[1] then
            local metadata = json.decode(result[1].metadata or '{}')
            metadata[key] = value
            MySQL.update.await("UPDATE players SET metadata = ? WHERE citizenid = ?", {
                json.encode(metadata), citizenid
            })
        end
    end
end

function Bridge.getRecords(citizenid)
    local result = MySQL.query.await("SELECT records FROM nd_mdt_records WHERE citizenid = ? LIMIT 1", {citizenid})
    if not result or not result[1] then return {}, false end
    return json.decode(result[1].records), true
end

function Bridge.viewEmployees(src, search)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not config.policeAccess[Player.PlayerData.job.name] then return {} end

    local employees = {}
    local onlinePlayers = QBCore.Functions.GetPlayers()
    local result = MySQL.query.await("SELECT * FROM players")
    
    search = (search or ""):lower()
    
    for i=1, #result do
        local info = result[i]
        local charinfo = json.decode(info.charinfo)
        local job = info.job
        local metadata = json.decode(info.metadata or '{}')
        
        if config.policeAccess[job] then
            local toSearch = ("%s %s %s"):format(
                charinfo.firstname:lower(),
                charinfo.lastname:lower(),
                metadata.callsign and tostring(metadata.callsign):lower() or ""
            )
            
            if search == "" or toSearch:find(search) then
                local isOnline = false
                for _, playerId in ipairs(onlinePlayers) do
                    local xPlayer = QBCore.Functions.GetPlayer(playerId)
                    if xPlayer and xPlayer.PlayerData.citizenid == info.citizenid then
                        isOnline = true
                        break
                    end
                end
                
                employees[#employees+1] = {
                    source = isOnline and getPlayerSource(info.citizenid) or nil,
                    charId = info.citizenid,
                    first = charinfo.firstname,
                    last = charinfo.lastname,
                    img = metadata.image or "user.jpg",
                    callsign = metadata.callsign or "",
                    job = job,
                    jobInfo = {
                        grade = info.gang.grade,
                        label = QBCore.Shared.Jobs[job]?.grades[info.job.grade]?.label or job
                    },
                    dob = charinfo.birthdate,
                    gender = charinfo.gender,
                    phone = charinfo.phone
                }
            end
        end
    end
    
    return employees
end

function Bridge.employeeUpdateCallsign(src, citizenid, callsign)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, "Player not found" end
    
    if not tonumber(callsign) then return false, "Callsign must be a number" end
    
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if targetPlayer then
        if Player.PlayerData.job.grade.level <= targetPlayer.PlayerData.job.grade.level then
            return false, "You can only update lower rank employees"
        end
    else
        local result = MySQL.query.await("SELECT job FROM players WHERE citizenid = ?", {citizenid})
        if result and result[1] then
            if Player.PlayerData.job.grade.level <= result[1].job.grade.level then
                return false, "You can only update lower rank employees"
            end
        end
    end
    
    if targetPlayer then
        local metadata = targetPlayer.PlayerData.metadata
        metadata.callsign = callsign
        targetPlayer.Functions.SetMetaData("metadata", metadata)
    else
        local result = MySQL.query.await("SELECT metadata FROM players WHERE citizenid = ?", {citizenid})
        if result and result[1] then
            local metadata = json.decode(result[1].metadata or '{}')
            metadata.callsign = callsign
            MySQL.update.await("UPDATE players SET metadata = ? WHERE citizenid = ?", {
                json.encode(metadata), citizenid
            })
        else
            return false, "Employee not found"
        end
    end
    
    return callsign
end

function Bridge.updateEmployeeRank(src, update)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, "Player not found" end
    
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(update.charid)
    if not targetPlayer then return false, "Employee not found" end
    
    if Player.PlayerData.job.grade.level <= targetPlayer.PlayerData.job.grade.level then
        return false, "You can't promote to higher rank than yourself"
    end
    
    targetPlayer.Functions.SetJob(update.job, update.newRank)
    return QBCore.Shared.Jobs[update.job]?.grades[update.newRank]?.name or "Rank "..update.newRank
end

function Bridge.removeEmployeeJob(src, citizenid)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, "Player not found" end
    
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not targetPlayer then return false, "Employee not found" end
    
    if Player.PlayerData.job.grade.level <= targetPlayer.PlayerData.job.grade.level then
        return false, "You can't remove equal or higher rank employees"
    end
    
    targetPlayer.Functions.SetJob("unemployed", 0)
    return true
end

function Bridge.invitePlayerToJob(src, target)
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(target)
    
    if not Player or not Target then return false end
    
    Target.Functions.SetJob(Player.PlayerData.job.name, 1)
    return true
end

return Bridge
