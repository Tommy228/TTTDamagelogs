Damagelog.events = Damagelog.events or {}
Damagelog.IncludedEvents = Damagelog.IncludedEvents or {}

function Damagelog:AddEvent(event, f)
    local id = #self.events + 1

    function event.CallEvent(tbl, force_time, force_index)
        if GetRoundState() ~= ROUND_ACTIVE then
            return
        end

        local time

        if force_time then
            time = tbl[force_time]
        else
            time = self.Time
        end

        local infos = {
            id = id,
            time = time,
            infos = tbl
        }

        if force_index then
            self.DamageTable[tbl[force_index]] = infos
        else
            table.insert(self.DamageTable, infos)
        end

        local recip = {}

        for _, v in pairs(player.GetHumans()) do
            if v:CanUseDamagelog() then
                table.insert(recip, v)
            end
        end

        net.Start("DL_RefreshDamagelog")
        net.WriteTable(infos)
        net.Send(recip)
    end

    self.events[id] = event
    table.insert(self.IncludedEvents, Damagelog.CurrentFile)
end

if SERVER then
    Damagelog.event_hooks = {}

    function Damagelog:InitializeEventHooks()
        for _, name in pairs(self.event_hooks) do
            hook.Add(name, "Damagelog_events_" .. name, function(...)
                for _, v in pairs(self.events) do
                    if v[name] then
                        v[name](v, ...)
                    end
                end
            end)
        end
    end

    function Damagelog:EventHook(name)
        if not table.HasValue(self.event_hooks, name) then
            table.insert(self.event_hooks, name)
        end
    end
end

function Damagelog:InfoFromID(tbl, id)
    return tbl[id] or {
        steamid64 = -1,
        role = -1,
        nick = "<unknown>"
    }
end

function Damagelog:IsTeamkill(role1, role2)
	if role1 == role2 then 
		return true
	elseif role1 == ROLE_DETECTIVE and role2 == ROLE_INNOCENT then 
		return true
	elseif role1 == ROLE_INNOCENT and role2 == ROLE_DETECTIVE then 
		return true
	end
	return false
end

--[[function Damagelog:IsTeamkill(attacker, victim)
    if not IsValid(attacker) or not IsValid(victim) then
        return false
    end

    local role1 = attacker:GetRole()
    local role2 = victim:GetRole()

    if not ROLES then
        if role1 == role2 then
            return true
        elseif role1 == ROLE_DETECTIVE and role2 == ROLE_INNOCENT then
            return true
        elseif role1 == ROLE_INNOCENT and role2 == ROLE_DETECTIVE then
            return true
        end
    else
        local rda = attacker:GetRoleData()
        local rdv = victim:GetRoleData()
        local rdaTeam = hook.Run("TTT2_ModifyRole", attacker) or rda
        rdaTeam = rdaTeam.team
        local rdvTeam = hook.Run("TTT2_ModifyRole", victim) or rdv
        rdvTeam = rdvTeam.team

        if rdaTeam and rdaTeam == rdvTeam and (not rdv.unknownTeam or rdaTeam == TEAM_TRAITOR) then
            return true
        end
    end

    return false
end]]

local function includeEventFile(f)
    f = "damagelogs/shared/events/" .. f

    if SERVER then
        AddCSLuaFile(f)
    end

    include(f)
end

for _, v in pairs(file.Find("damagelogs/shared/events/*.lua", "LUA")) do
    if not table.HasValue(Damagelog.IncludedEvents, v) then
        Damagelog.CurrentFile = v
        includeEventFile(v)
    end
end

if CLIENT then
    Damagelog:SaveColors()
    Damagelog:SaveFilters()
else
    Damagelog:InitializeEventHooks()
end