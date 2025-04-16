local QBCore = exports['qb-core']:GetCoreObject()
local Bridge = {}

---@return table
function Bridge.getPlayerInfo()
    local player = QBCore.Functions.GetPlayerData()
    return {
        firstName = player.charinfo?.firstname or "",
        lastName = player.charinfo?.lastname or "",
        job = player.job?.name or "",
        jobLabel = player.job?.label or player.job?.name or "",
        callsign = player.metadata?.callsign or "",
        img = player.charinfo?.image or "user.jpg",
        isBoss = player.job?.grade?.level == 10
    }
end

---@param job string
---@return boolean
function Bridge.hasAccess(job)
    return config.policeAccess[job] or config.fireAccess[job]
end

---@return string
function Bridge.rankName()
    local player = QBCore.Functions.GetPlayerData()
    return player.job?.grade?.name or ""
end

---@param id string|number
---@param info table
---@return table
function Bridge.getCitizenInfo(id, info)
    return {
        img = info.img or "user.jpg",
        characterId = id,
        firstName = info.firstName or info.charinfo?.firstname,
        lastName = info.lastName or info.charinfo?.lastname,
        dob = info.dob or info.charinfo?.birthdate,
        gender = info.gender or info.charinfo?.gender,
        phone = info.phone or info.charinfo?.phone,
        ethnicity = info.ethnicity or info.charinfo?.nationality
    }
end

---@param job string
---@return table, string
function Bridge.getRanks(job)
    local jobData = QBCore.Shared.Jobs[job]
    if not jobData or not jobData.grades then return nil, job end

    local options = {}
    for grade, gradeData in pairs(jobData.grades) do
        options[#options+1] = {
            value = grade,
            label = gradeData.name
        }
    end

    table.sort(options, function(a, b)
        return tonumber(a.value) < tonumber(b.value)
    end)

    return options, job
end

return Bridge
