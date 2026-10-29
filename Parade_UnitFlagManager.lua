-- Stock UI extension. Reuse the original flag positioning/visibility and leave
-- native levy/promotion indicators alone. Our clock is an independent child.
include('UnitFlagManager.lua')
if not UnitFlag or not GetUnitFlag then
    print('[ParadeV38][FLAGS] ERROR: stock unit flags unavailable');return
end
local baseStats=UnitFlag.UpdateStats
local baseDestroy=UnitFlag.destroy
local function UpdateClock(flag)
    local instance=flag.m_Instance
    if not instance or not instance.FlagRoot then return end
    local badge=instance.ParadeClock
    local bridge=ExposedMembers.ParadeV3Gameplay
    local unit=flag:GetUnit()
    if not bridge or not bridge.Ready or not unit or unit:GetOwner()~=Game.GetLocalPlayer() then
        if badge then badge.Root:SetHide(true) end
        return
    end
    local player=Players[unit:GetOwner()]
    local rawEnd=player:GetProperty('PARADE_V3_END')
    local rawTier=player:GetProperty('PARADE_V3_TIER')
    local remaining=(tonumber(rawEnd) or -1)-Game.GetCurrentGameTurn()
    local tier=tonumber(rawTier) or 0
    local row=GameInfo.Units[unit:GetType()]
    if remaining<=0 or tier<=0 or not row or ((row.Combat or 0)<=0 and (row.RangedCombat or 0)<=0) then
        if badge then badge.Root:SetHide(true) end
        return
    end
    local host=ExposedMembers.ParadeV38UI
    if not badge and host and host.BuildClock then
        badge=host.BuildClock(instance.FlagRoot)
        instance.ParadeClock=badge
    end
    if not badge then return end
    local combat=tier
    for t in GameInfo.ParadeTiers() do if t.Tier==tier then combat=t.Combat;break end end
    badge.ClockText:SetText('[ICON_Turn]'..tostring(remaining))
    badge.Root:SetToolTipString(Locale.Lookup('LOC_PARADE_CLOCK_TOOLTIP',combat,remaining))
    badge.Root:SetHide(false)
end
local reportedClockError=false
local function SafeUpdateClock(flag)
    local ok,err=pcall(UpdateClock,flag)
    if not ok and not reportedClockError then
        reportedClockError=true
        print('[ParadeV38][FLAGS] CLOCK ERROR: '..tostring(err))
    end
end
function UnitFlag.UpdateStats(self,...)
    local result=baseStats(self,...)
    SafeUpdateClock(self)
    return result
end
function UnitFlag.destroy(self,...)
    if self.m_Instance and self.m_Instance.ParadeClock then
        pcall(function() self.m_Instance.FlagRoot:DestroyChild(self.m_Instance.ParadeClock.Root) end)
        self.m_Instance.ParadeClock=nil
    end
    return baseDestroy(self,...)
end
local function RefreshClocks()
    local bridge=ExposedMembers.ParadeV3Gameplay
    if not bridge or not bridge.Ready then return end
    local id=Game.GetLocalPlayer()
    if type(id)~='number' or id<0 then return end
    local player=Players[id]
    if not player then return end
    for _,unit in player:GetUnits():Members() do
        local flag=GetUnitFlag(id,unit:GetID())
        if flag then SafeUpdateClock(flag) end
    end
end
LuaEvents.ParadeV38_RefreshClocks.Add(RefreshClocks)
for _,name in ipairs({'PlayerTurnActivated','TurnBegin','UnitAddedToMap','UnitUpgraded',
    'UnitCaptured','GameCoreEventPublishComplete'}) do
    if Events[name] then Events[name].Add(RefreshClocks) end
end
print('[ParadeV38][FLAGS] READY: independent parade clocks')
