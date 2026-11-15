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
include('Parade_Rules.lua')
local R=ParadeRules
local function IsCurrentCapital(city)
    local p=city and Players[city:GetOwner()];local c=p and p:GetCities():GetCapitalCity()
    return c and c:GetID()==city:GetID()
end
function GetData(...)
    local data=baseGetData(...)
    if not data or not data.ProjectItems then return data end
    local city=data.City or UI.GetHeadSelectedCity()
    for i=#data.ProjectItems,1,-1 do
        local item=data.ProjectItems[i];local kind=R.Kind(item.Type)
        if item.Type=='PROJECT_MILITARY_PARADE' then table.remove(data.ProjectItems,i)
        elseif kind then
            if not IsCurrentCapital(city) then table.remove(data.ProjectItems,i)
            else
                local ok,reason=R.Legal(Players[city:GetOwner()],city,kind)
                item.Disabled=not ok
                item.ToolTip=(item.ToolTip or '')..'[NEWLINE]'..reason..'[NEWLINE]筹备开始时扣费；取消不退费。'
            end
        end
    end
    return data
end
function AdvanceProject(city,entry,...)
    local kind=entry and R.Kind(entry.ProjectType or entry.Type)
    if kind and not R.Legal(Players[city:GetOwner()],city,kind) then Refresh();return end
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
