-- Gameplay only. Military-score queries belong to Parade_UI.lua, not this file.
print('[ParadeV38][Gameplay] BOOT')
local VERSION = '3.20.0-b1'
local DURATION = 10
local GENERAL_POINTS_BY_ERA={
    ERA_ANCIENT=5,ERA_CLASSICAL=10,ERA_MEDIEVAL=20,ERA_RENAISSANCE=35,
    ERA_INDUSTRIAL=50,ERA_MODERN=70,ERA_ATOMIC=90,ERA_INFORMATION=120,ERA_FUTURE=150
}
local GENERAL_POINTS_BY_ORDER={5,10,20,35,50,70,90,120,150}
local KEY_END = 'PARADE_V3_END'
local KEY_TIER = 'PARADE_V3_TIER'
local KEY_SCORE = 'PARADE_V3_SCORE'
local KEY_LAST = 'PARADE_V3_LAST_COMPLETION'
local KEY_PENDING = 'PARADE_V3_PENDING_CITY'
local KEY_PENDING_TURN = 'PARADE_V3_PENDING_TURN'
local project = GameInfo.Projects['PROJECT_MILITARY_PARADE']
local civic = GameInfo.Civics['CIVIC_EARLY_EMPIRE']
local permit = GameInfo.Buildings['BUILDING_PARADE_ELIGIBLE']
local generalPermit=GameInfo.Buildings['BUILDING_PARADE_GENERAL']
local generalClass=GameInfo.GreatPersonClasses and GameInfo.GreatPersonClasses['GREAT_PERSON_CLASS_GENERAL']
if not project or not civic or not permit or not generalPermit or not generalClass or not GameInfo.ParadeTiers then
    print('[ParadeV38][FATAL] Database missing: project, civic, permit or tier table')
    return
end
local quoteIDs={}
if GameInfo.ParadeQuotes then
    for row in GameInfo.ParadeQuotes() do quoteIDs[#quoteIDs+1]=row.QuoteID end
end
table.sort(quoteIDs)
local tiers = {}
for row in GameInfo.ParadeTiers() do
    -- Copy database fields. Do not write derived values into GameInfo rows.
    local building = GameInfo.Buildings['BUILDING_PARADE_BUFF_' .. row.Tier]
    local ability = GameInfo.UnitAbilities['ABILITY_PARADE_' .. row.Tier]
    if not building or not ability then
        print('[ParadeV38][FATAL] Missing buff building/ability for tier ' .. row.Tier)
        return
    end
    tiers[#tiers+1] = {
        Tier=row.Tier, MinimumStrength=row.MinimumStrength,
        Loyalty=row.Loyalty, Combat=row.Combat, Amenities=row.Amenities,
        BuildingIndex=building.Index, AbilityType=ability.UnitAbilityType
    }
end
table.sort(tiers,function(a,b) return a.Tier<b.Tier end)
if #tiers ~= 5 then print('[ParadeV38][FATAL] Expected 5 tiers'); return end
local function Log(s) print('[ParadeV38][Gameplay] ' .. s) end
local function Turn() return Game.GetCurrentGameTurn() end
-- An unset engine property can return ZERO Lua values, not one nil value.
-- Assignment normalizes this to one nil before tonumber receives it.
local function NumberProperty(player,key,default)
    local value=player:GetProperty(key)
    return tonumber(value) or default
end
local knownPlayers={}
local ready=false
local function RememberPlayer(playerID)
    if type(playerID)~='number' or playerID<0 then return nil end
    local player=Players[playerID]
    if player then knownPlayers[playerID]=true end
    return player
end
local function IsMilitary(unit)
    local row=GameInfo.Units[unit:GetType()]
    return row and ((row.Combat or 0)>0 or (row.RangedCombat or 0)>0)
end
local function HasGarrison(player,city)
    for _,unit in player:GetUnits():Members() do
        if IsMilitary(unit) and unit:GetX()==city:GetX() and unit:GetY()==city:GetY() then
            return true
        end
    end
    return false
end
local function GeneralPointsReward(player)
    -- Query only on a legal completion, after world-ready. No load-time player access.
    local ok,eraID=pcall(function()return player:GetEra()end)
    if not ok or type(eraID)~='number' or eraID<0 then return 5 end
    local row=GameInfo.Eras and GameInfo.Eras[eraID]
    if row and GENERAL_POINTS_BY_ERA[row.EraType] then return GENERAL_POINTS_BY_ERA[row.EraType] end
    local order=row and tonumber(row.ChronologyIndex)
    if order then
        return GENERAL_POINTS_BY_ORDER[math.max(1,math.min(#GENERAL_POINTS_BY_ORDER,math.floor(order)+1))]
    end
    return 5
end
local function ReviewGeneral(player,city)
    local found=nil
    for _,unit in player:GetUnits():Members() do
        local row=GameInfo.Units[unit:GetType()]
        if row and row.UnitType==generalClass.UnitType
            and unit:GetX()==city:GetX() and unit:GetY()==city:GetY() then
            if not found or (unit.GetID and found.GetID and unit:GetID()<found:GetID()) then found=unit end
        end
    end
    return found
end
local function HasGeneral(player,city)return ReviewGeneral(player,city)~=nil end
local function ReviewGeneralName(player,city)
    local unit=city and ReviewGeneral(player,city)
    if not unit then return '' end
    local ok,name=pcall(function()
        local individual=unit:GetGreatPerson():GetIndividual()
        local row=GameInfo.GreatPersonIndividuals and GameInfo.GreatPersonIndividuals[individual]
        return row and row.Name
    end)
    return ok and type(name)=='string' and name or 'LOC_UNIT_GREAT_GENERAL_NAME'
end
local function EraName(player)
    local ok,name=pcall(function()
        local row=GameInfo.Eras[player:GetEra()]
        return row and (row.Name or row.EraType)
    end)
    return ok and type(name)=='string' and name or ''
end
-- Native era score: first +2, then +1 for each unique legal completion.
local function AwardEraScore(player,playerID)
    if type(Game.GetEras)~='function' then return 0,3,-1 end
    local ok,eras,eraID=pcall(function()
        local manager=Game.GetEras()
        return manager,manager:GetCurrentEra()
    end)
    if not ok or not eras or type(eraID)~='number' or eraID<0
        or type(eras.ChangePlayerEraScore)~='function' then return 0,3,-1 end
    eraID=math.floor(eraID)
    local key='PARADE_V313_ERA_DONE_'..eraID
    local first=NumberProperty(player,'PARADE_V313_ERA_HAS_AWARD',0)==0
    local amount=first and 2 or 1
    local awarded,err=pcall(function()eras:ChangePlayerEraScore(playerID,amount)end)
    if not awarded then
        Log('ERA SCORE ERROR: '..tostring(err));return 0,4,eraID
    end
    player:SetProperty(key,1)
    player:SetProperty('PARADE_V313_ERA_HAS_AWARD',1)
    Log('ERA SCORE player='..playerID..' worldEra='..eraID..' amount='..amount)
    return amount,first and 1 or 2,eraID
end
local function IsEligible(player,cityID)
    if not player:GetCulture():HasCivic(civic.Index) then return false,'Early Empire incomplete' end
    local capital=player:GetCities():GetCapitalCity()
    if not capital or capital:GetID()~=cityID then return false,'not current capital' end
    if not HasGarrison(player,capital) then return false,'no own combat garrison' end
    return true
end
local function SetBuilding(city,index,wanted)
    local buildings=city:GetBuildings()
    if wanted and not buildings:HasBuilding(index) then
        city:GetBuildQueue():CreateBuilding(index)
        if not buildings:HasBuilding(index) then error('CreateBuilding failed, city='..city:GetID()..' index='..index) end
    elseif not wanted and buildings:HasBuilding(index) then
        buildings:RemoveBuilding(index)
        if buildings:HasBuilding(index) then error('RemoveBuilding failed, city='..city:GetID()..' index='..index) end
    end
end
local function ActiveTier(player)
    if Turn() >= NumberProperty(player,KEY_END,-1) then return 0 end
    return NumberProperty(player,KEY_TIER,0)
end
local function MigrateTimeline(player)
    if player:GetProperty('PARADE_V315_ARCHIVE_STARTED')==1 then return end
    local era=NumberProperty(player,'PARADE_V313_WORLD_ERA',-1)
    local score=NumberProperty(player,'PARADE_V313_ERA_SCORE',0)
    if era<0 then return end
    if score<=0 and player:GetProperty('PARADE_V313_ERA_DONE_'..era)~=1 then return end
    local prefix='PARADE_V314_MOMENT_'..era..'_'
    if player:GetProperty(prefix..'READY')==1 then return end
    player:SetProperty(prefix..'TURN',NumberProperty(player,'PARADE_V35_TURN',Turn()))
    player:SetProperty(prefix..'SCORE',score)
    player:SetProperty(prefix..'CITY',player:GetProperty('PARADE_V312_CITY_NAME') or '')
    player:SetProperty(prefix..'GENERAL',NumberProperty(player,'PARADE_V38_GENERAL',0))
    player:SetProperty(prefix..'NAME',player:GetProperty('PARADE_V312_GENERAL_NAME') or '')
    player:SetProperty(prefix..'READY',1)
end
local function SyncPlayer(player)
    MigrateTimeline(player)
    local active=ActiveTier(player)
    local refreshModifiers=player:GetProperty('PARADE_V316_MODIFIERS_VERSION')~=316
    local capital=player:GetCities():GetCapitalCity()
    local capitalID=capital and capital:GetID() or -1
    local unlocked=player:GetCulture():HasCivic(civic.Index)
    for _,city in player:GetCities():Members() do
        local allowed=unlocked and city:GetID()==capitalID and HasGarrison(player,city)
        local hadPermit=city:GetBuildings():HasBuilding(permit.Index)
        SetBuilding(city,permit.Index,allowed)
        local supervised=allowed and HasGeneral(player,city)
        local hadGeneral=city:GetBuildings():HasBuilding(generalPermit.Index)
        SetBuilding(city,generalPermit.Index,supervised)
        if hadGeneral~=supervised then Log('GENERAL city='..city:GetID()..' active='..tostring(supervised)) end
        if hadPermit~=allowed then
            Log('PERMIT city='..tostring(city:GetID())..' allowed='..tostring(allowed))
        end
        -- Removing a prerequisite does not itself revalidate an existing queue.
        -- Gameplay-only API, only on a live city, protected by SyncAll's guard.
        if hadPermit and not allowed then
            city:GetBuildQueue():CheckActiveProduction()
        end
        -- Rebuild saved helper buildings once after this modifier migration,
        -- so an already-active old save attaches the new unit-specific rows.
        if refreshModifiers then
            for _,row in ipairs(tiers) do SetBuilding(city,row.BuildingIndex,false) end
        end
        -- Remove old tier BEFORE adding new tier. Repetition cannot stack them.
        for _,row in ipairs(tiers) do
            if row.Tier~=active then SetBuilding(city,row.BuildingIndex,false) end
        end
        for _,row in ipairs(tiers) do
            if row.Tier==active then SetBuilding(city,row.BuildingIndex,true) end
        end
    end
    if refreshModifiers then player:SetProperty('PARADE_V316_MODIFIERS_VERSION',316) end
    for _,unit in player:GetUnits():Members() do
        local ability=unit:GetAbility()
        local military=IsMilitary(unit)
        for _,row in ipairs(tiers) do
            local wanted=(military and active==row.Tier) and 1 or 0
            local current=ability:GetAbilityCount(row.AbilityType) or 0
            if current~=wanted then ability:ChangeAbilityCount(row.AbilityType,wanted-current) end
        end
    end
end
local syncing=false
local function SyncAll()
    if not ready or syncing then return end
    syncing=true
    -- Only handles seen in valid player-turn callbacks; never all player slots.
    for id in pairs(knownPlayers) do
        local player=Players[id]
        if player then
            local ok,err=pcall(SyncPlayer,player)
            if not ok then Log('SYNC ERROR player='..tostring(id)..': '..tostring(err)) end
        end
    end
    syncing=false
end
local function IsParade(id)
    return id==project.Index or id==project.Hash or id==project.ProjectType
end
local function ReadUIScore(playerID)
    local ui=ExposedMembers.ParadeV3UI
    if ui and ui.GetMilitaryScore then
        local ok,value=pcall(ui.GetMilitaryScore,playerID)
        if ok and type(value)=='number' and value==value and value>=0 and value<math.huge then
            return math.floor(value)
        end
        Log('UI score unavailable: '..tostring(value))
    end
    return nil
end
local function Complete(playerID,cityID,projectID,cancelled)
    if not ready or not IsParade(projectID) or cancelled==true or cancelled==1 then return end
    local player=RememberPlayer(playerID)
    if not player then return end
    local ok,reason=IsEligible(player,cityID)
    if not ok then Log('REJECTED player='..playerID..' city='..cityID..': '..reason);return end
    -- Native and UI reporting can describe the same completion. Process it once.
    local stamp=tostring(Turn())..':'..tostring(cityID)
    if player:GetProperty(KEY_LAST)==stamp then return end
    local score=ReadUIScore(playerID)
    if score==nil then
        player:SetProperty(KEY_PENDING,cityID)
        player:SetProperty(KEY_PENDING_TURN,Turn())
        Log('PENDING completion: waiting for UI bridge, player='..playerID)
        return
    end
    local selected=tiers[1]
    for _,row in ipairs(tiers) do if score>=row.MinimumStrength then selected=row end end
    local baseTier=selected.Tier
    local capital=player:GetCities():GetCapitalCity()
    local reviewed=capital and HasGeneral(player,capital) or false
    if reviewed then selected=tiers[math.min(#tiers,baseTier+1)] end
    local previousQuote=NumberProperty(player,'PARADE_V35_QUOTE',-1)
    local choices={}
    for _,id in ipairs(quoteIDs) do if id~=previousQuote then choices[#choices+1]=id end end
    if #choices==0 then choices=quoteIDs end
    local quoteID=choices[1] or 1
    if #choices>1 then quoteID=choices[Game.GetRandNum(#choices,'Parade quotation')+1] end
    local count=NumberProperty(player,'PARADE_V35_COUNT',0)+1
    local ending=Turn()+DURATION
    player:SetProperty(KEY_SCORE,score)
    player:SetProperty(KEY_TIER,selected.Tier)
    player:SetProperty(KEY_END,ending)
    player:SetProperty(KEY_LAST,stamp)
    player:SetProperty(KEY_PENDING,-1)
    SyncPlayer(player)
    local points=0
    local rewardPoints=GeneralPointsReward(player)
    local gave,err=pcall(function()player:GetGreatPeoplePoints():ChangePointsTotal(generalClass.Index,rewardPoints)end)
    if gave then points=rewardPoints else Log('GENERAL POINTS ERROR: '..tostring(err)) end
    player:SetProperty('PARADE_V38_BASE_TIER',baseTier)
    player:SetProperty('PARADE_V38_GENERAL',reviewed and 1 or 0)
    player:SetProperty('PARADE_V38_GENERAL_POINTS',points)
    Log('GENERAL REWARD baseTier='..baseTier..' finalTier='..selected.Tier..' reviewed='..tostring(reviewed)..' points='..points)
    -- Persist the complete presentation record. COUNT is committed last so UI
    -- never observes a new completion with half-written details.
    player:SetProperty('PARADE_V35_QUOTE',quoteID)
    player:SetProperty('PARADE_V35_CITY',cityID)
    player:SetProperty('PARADE_V35_TURN',Turn())
    local cityName=capital and capital:GetName() or ''
    local generalName=ReviewGeneralName(player,capital)
    local eraName=EraName(player)
    player:SetProperty('PARADE_V312_CITY_NAME',cityName)
    player:SetProperty('PARADE_V312_GENERAL_NAME',generalName)
    player:SetProperty('PARADE_V312_ERA_NAME',eraName)
    local eraScore,eraStatus,worldEra=AwardEraScore(player,playerID)
    player:SetProperty('PARADE_V313_ERA_SCORE',eraScore)
    player:SetProperty('PARADE_V313_ERA_STATUS',eraStatus)
    player:SetProperty('PARADE_V313_WORLD_ERA',worldEra)
    -- One immutable card per completed project, committed before COUNT. UI is
    -- read-only and cannot grant a second payout when cards are opened/replayed.
    if worldEra>=0 then
        local prefix='PARADE_V315_MOMENT_'..count..'_'
        player:SetProperty(prefix..'TURN',Turn())
        player:SetProperty(prefix..'ERA',worldEra)
        player:SetProperty(prefix..'SCORE',eraScore)
        player:SetProperty(prefix..'CITY',cityName)
        player:SetProperty(prefix..'GENERAL',reviewed and 1 or 0)
        player:SetProperty(prefix..'NAME',generalName)
        player:SetProperty(prefix..'READY',1)
        player:SetProperty('PARADE_V315_ARCHIVE_STARTED',1)
    end
    player:SetProperty('PARADE_V35_COUNT',count)
    Log(string.format('AWARDED player=%d score=%d tier=%d loyalty=%d combat=%d amenities=%d expiry=%d',
        playerID,score,selected.Tier,selected.Loyalty,selected.Combat,selected.Amenities,ending))
end
local function SafeComplete(...)
    local ok,err=pcall(Complete,...)
    if not ok then Log('COMPLETION ERROR: '..tostring(err)) end
end
local function OnNativeComplete(playerID,cityID,projectID,buildingIndex,x,y,cancelled)
    if IsParade(projectID) then
        Log('NATIVE COMPLETE player='..tostring(playerID)..' city='..tostring(cityID)..' ready='..tostring(ready)..' cancelled='..tostring(cancelled))
    end
    SafeComplete(playerID,cityID,projectID,cancelled)
end
local function Refresh()
    if not ready then return end
    for playerID in pairs(knownPlayers) do
        local player=Players[playerID]
        if player then
            local pending=NumberProperty(player,KEY_PENDING,-1)
            if pending>=0 then
                if player:GetProperty(KEY_PENDING_TURN)==Turn() then
                    SafeComplete(playerID,pending,project.Index,false)
                else
                    player:SetProperty(KEY_PENDING,-1)
                    Log('Pending completion expired without UI score, player='..playerID)
                end
            end
        end
    end
    SyncAll()
end
-- UI may read this status, but receives no game-state mutation callbacks.
ExposedMembers.ParadeV3Gameplay={Version=VERSION,Ready=false}
local function OnPlayerTurnActivated(playerID)
    local player=RememberPlayer(playerID)
    if not player then return end
    if not ready then
        ready=true
        ExposedMembers.ParadeV3Gameplay.Ready=true
        Log('WORLD READY: first activated player='..tostring(playerID))
    end
    Refresh()
end
Events.CityProjectCompleted.Add(OnNativeComplete)
Events.PlayerTurnActivated.Add(OnPlayerTurnActivated)
Events.TurnBegin.Add(Refresh)
for _,name in ipairs({'UnitMoved','UnitMoveComplete','UnitTeleported','UnitAddedToMap','UnitRemovedFromMap',
    'CityUnitsChanged','CapitalCityChanged','CityProductionCompleted','CityProductionChanged','CityProductionUpdated','PlayerTurnDeactivated',
    'UnitUpgraded','CityAddedToMap','CityRemovedFromMap','CityTransfered','CivicCompleted','CitySelectionChanged'}) do
    if Events[name] then Events[name].Add(Refresh) end
end
-- Registration only at load: no Players enumeration, properties, cities or queues.
Log('REGISTERED version='..VERSION..'; waiting for PlayerTurnActivated')
