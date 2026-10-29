-- Extend the installed Firaxis production panel instead of copying its source.
-- Preserve the Heroes-mode extension when its replacement exists.
include('ProductionPanel_Babylon_Heroes.lua')
if not GetData then include('ProductionPanel.lua') end
if not GetData or not AdvanceProject then
    print('[ParadeV38][PANEL] ERROR: base production panel unavailable')
    return
end
local baseGetData=GetData
local baseAdvanceProject=AdvanceProject
local paradeType='PROJECT_MILITARY_PARADE'
local function IsCurrentCapital(city)
    if not city then return false end
    local player=Players[city:GetOwner()]
    local capital=player and player:GetCities():GetCapitalCity()
    return capital~=nil and city:GetID()==capital:GetID()
end
local function CanStartParade(city)
    if not IsCurrentCapital(city) then return false end
    local player=Players[city:GetOwner()]
    local civic=GameInfo.Civics['CIVIC_EARLY_EMPIRE']
    if not civic or not player:GetCulture():HasCivic(civic.Index) then return false end
    for _,unit in player:GetUnits():Members() do
        local row=GameInfo.Units[unit:GetType()]
        if row and ((row.Combat or 0)>0 or (row.RangedCombat or 0)>0)
            and unit:GetX()==city:GetX() and unit:GetY()==city:GetY() then
            return true
        end
    end
    return false
end
function GetData(...)
    local data=baseGetData(...)
    if not data or not data.ProjectItems then return data end
    local city=data.City or UI.GetHeadSelectedCity()
    local capital=IsCurrentCapital(city)
    local canStart=capital and CanStartParade(city)
    for i=#data.ProjectItems,1,-1 do
        local item=data.ProjectItems[i]
        if item.Type==paradeType then
            if not capital then
                -- HIDE, not merely disable, even with "show disabled items" on.
                table.remove(data.ProjectItems,i)
            elseif not canStart then
                item.Disabled=true
                item.ToolTip=(item.ToolTip or '')..'[NEWLINE]'..Locale.Lookup('LOC_PARADE_NEED_GARRISON')
            end
        end
    end
    return data
end
function AdvanceProject(city,entry,...)
    if entry and entry.ProjectType==paradeType and not CanStartParade(city) then
        print('[ParadeV38][PANEL] BLOCK stale parade click')
        Refresh()
        return
    end
    return baseAdvanceProject(city,entry,...)
end
-- The stock refresh function resolves GetData dynamically. Refresh the visible
-- list when garrison or current capital changes, including after city capture.
local function OnEligibilityChanged()
    if not ContextPtr:IsHidden() then Refresh() end
end
for _,name in ipairs({'UnitMoved','UnitMoveComplete','UnitAddedToMap','UnitRemovedFromMap',
    'CityUnitsChanged','CapitalCityChanged','CityTransfered','CivicCompleted'}) do
    if Events[name] then Events[name].Add(OnEligibilityChanged) end
end
print('[ParadeV38][PANEL] READY: current-capital visibility filter')
