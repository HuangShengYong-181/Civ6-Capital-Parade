-- UTF-8. Requires Rise & Fall or Gathering Storm loyalty rules.
-- Install as a replacement of the old mod; use a NEW game.
CREATE TABLE ParadeTiers (
 Tier INTEGER PRIMARY KEY, MinimumStrength INTEGER NOT NULL,
 Loyalty INTEGER NOT NULL, Combat INTEGER NOT NULL, Amenities INTEGER NOT NULL
);
INSERT INTO ParadeTiers VALUES
 (1,0,4,1,1),(2,200,6,2,1),(3,500,8,3,1),
 (4,1000,10,4,2),(5,2000,12,5,2);

-- No civilization receives this trait: these helper buildings cannot be built normally.
INSERT INTO Types (Type,Kind) VALUES ('TRAIT_PARADE_INTERNAL','KIND_TRAIT');
INSERT INTO Traits (TraitType,Name,Description) VALUES
 ('TRAIT_PARADE_INTERNAL','LOC_PARADE_INTERNAL_NAME','LOC_PARADE_INTERNAL_NAME');
-- The script places this non-buildable permit ONLY in the eligible current capital.
INSERT INTO Types (Type,Kind) VALUES ('BUILDING_PARADE_ELIGIBLE','KIND_BUILDING');
INSERT INTO Buildings
 (BuildingType,Name,Description,Cost,PrereqDistrict,TraitType,InternalOnly)
VALUES ('BUILDING_PARADE_ELIGIBLE','LOC_PARADE_PERMIT_NAME','LOC_PARADE_PERMIT_DESCRIPTION',
 1,'DISTRICT_CITY_CENTER','TRAIT_PARADE_INTERNAL',0);
INSERT INTO CivilopediaPageExcludes (SectionId,PageId)
VALUES ('BUILDINGS','BUILDING_PARADE_ELIGIBLE');

INSERT INTO Types (Type,Kind) VALUES ('PROJECT_MILITARY_PARADE','KIND_PROJECT');
INSERT INTO Projects
 (ProjectType,Name,ShortName,Description,Cost,CostProgressionModel,
 CostProgressionParam1,PrereqDistrict,RequiredBuilding,AdvisorType,PrereqCivic,UnlocksFromEffect)
VALUES ('PROJECT_MILITARY_PARADE','LOC_PROJECT_MILITARY_PARADE_NAME',
 'LOC_PROJECT_MILITARY_PARADE_NAME','LOC_PROJECT_MILITARY_PARADE_DESCRIPTION',
 60,'COST_PROGRESSION_GAME_PROGRESS',300,'DISTRICT_CITY_CENTER',
 'BUILDING_PARADE_ELIGIBLE','ADVISOR_CONQUEST','CIVIC_EARLY_EMPIRE',0);

-- City-local modifiers: no nationwide modifier stacking through multiple cities.
INSERT INTO Types (Type,Kind) VALUES
 ('MODIFIER_PARADE_CITY_LOYALTY','KIND_MODIFIER');
INSERT INTO DynamicModifiers (ModifierType,CollectionType,EffectType) VALUES
 ('MODIFIER_PARADE_CITY_LOYALTY','COLLECTION_OWNER','EFFECT_ADJUST_CITY_IDENTITY_PER_TURN');

INSERT INTO Types (Type,Kind)
 SELECT 'BUILDING_PARADE_BUFF_'||Tier,'KIND_BUILDING' FROM ParadeTiers;
INSERT INTO Buildings
 (BuildingType,Name,Description,Cost,PrereqDistrict,TraitType,InternalOnly,Entertainment)
 SELECT 'BUILDING_PARADE_BUFF_'||Tier,'LOC_PARADE_BUFF_NAME',
 'LOC_PARADE_BUFF_DESCRIPTION',1,'DISTRICT_CITY_CENTER','TRAIT_PARADE_INTERNAL',0,Amenities
 FROM ParadeTiers;
INSERT INTO CivilopediaPageExcludes (SectionId,PageId)
 SELECT 'BUILDINGS','BUILDING_PARADE_BUFF_'||Tier FROM ParadeTiers;
INSERT INTO Modifiers (ModifierId,ModifierType)
 SELECT 'PARADE_LOYALTY_'||Tier,'MODIFIER_PARADE_CITY_LOYALTY' FROM ParadeTiers;
INSERT INTO ModifierArguments (ModifierId,Name,Value)
 SELECT 'PARADE_LOYALTY_'||Tier,'Amount',Loyalty FROM ParadeTiers;
INSERT INTO BuildingModifiers (BuildingType,ModifierId)
 SELECT 'BUILDING_PARADE_BUFF_'||Tier,'PARADE_LOYALTY_'||Tier FROM ParadeTiers;

-- Explicit native unit-type percentage modifiers. Local to this city; only
-- combat unit production receives +10%. No extra production granted by Lua.
INSERT INTO Types (Type,Kind) VALUES ('MODIFIER_PARADE_CITY_UNIT_PRODUCTION','KIND_MODIFIER');
INSERT INTO DynamicModifiers (ModifierType,CollectionType,EffectType)
 VALUES ('MODIFIER_PARADE_CITY_UNIT_PRODUCTION','COLLECTION_OWNER','EFFECT_ADJUST_UNIT_PRODUCTION');
INSERT INTO Modifiers (ModifierId,ModifierType)
 SELECT 'PARADE_TRAIN_'||UnitType,'MODIFIER_PARADE_CITY_UNIT_PRODUCTION'
 FROM Units WHERE Combat>0 OR RangedCombat>0;
INSERT INTO ModifierArguments (ModifierId,Name,Value)
 SELECT 'PARADE_TRAIN_'||UnitType,'UnitType',UnitType
 FROM Units WHERE Combat>0 OR RangedCombat>0;
INSERT INTO ModifierArguments (ModifierId,Name,Value)
 SELECT 'PARADE_TRAIN_'||UnitType,'Amount',10
 FROM Units WHERE Combat>0 OR RangedCombat>0;
INSERT INTO BuildingModifiers (BuildingType,ModifierId)
 SELECT 'BUILDING_PARADE_BUFF_'||t.Tier,'PARADE_TRAIN_'||u.UnitType
 FROM ParadeTiers t CROSS JOIN Units u WHERE u.Combat>0 OR u.RangedCombat>0;

-- Explicitly enabled per unit by gameplay Lua; disabled by default.
INSERT INTO Types (Type,Kind)
 SELECT 'ABILITY_PARADE_'||Tier,'KIND_ABILITY' FROM ParadeTiers;
INSERT INTO UnitAbilities (UnitAbilityType,Name,Description,Inactive)
 SELECT 'ABILITY_PARADE_'||Tier,'LOC_PARADE_BUFF_NAME','LOC_PARADE_BUFF_DESCRIPTION',1
 FROM ParadeTiers;
INSERT INTO Modifiers (ModifierId,ModifierType)
 SELECT 'PARADE_COMBAT_'||Tier,'MODIFIER_UNIT_ADJUST_COMBAT_STRENGTH' FROM ParadeTiers;
INSERT INTO ModifierArguments (ModifierId,Name,Value)
 SELECT 'PARADE_COMBAT_'||Tier,'Amount',Combat FROM ParadeTiers;
INSERT INTO UnitAbilityModifiers (UnitAbilityType,ModifierId)
 SELECT 'ABILITY_PARADE_'||Tier,'PARADE_COMBAT_'||Tier FROM ParadeTiers;
INSERT INTO ModifierStrings (ModifierId,Context,Text)
 SELECT 'PARADE_COMBAT_'||Tier,'Preview','LOC_PARADE_COMBAT_PREVIEW' FROM ParadeTiers;

-- Associate inactive abilities with combat units; enable them explicitly in Lua.
INSERT INTO TypeTags (Type,Tag)
 SELECT 'ABILITY_PARADE_'||Tier,'CLASS_ALL_COMBAT_UNITS' FROM ParadeTiers;

-- General supervision is a city-local, project-specific native modifier.
-- No total-city production injection, and no bonus to settlers/wonders.
INSERT INTO Types (Type,Kind) VALUES
 ('BUILDING_PARADE_GENERAL','KIND_BUILDING'),
 ('MODIFIER_PARADE_CITY_PROJECT_PRODUCTION','KIND_MODIFIER');
INSERT INTO Buildings (BuildingType,Name,Description,Cost,PrereqDistrict,TraitType,InternalOnly)
 VALUES ('BUILDING_PARADE_GENERAL','LOC_PARADE_GENERAL_NAME','LOC_PARADE_GENERAL_DESCRIPTION',
 1,'DISTRICT_CITY_CENTER','TRAIT_PARADE_INTERNAL',0);
INSERT INTO CivilopediaPageExcludes (SectionId,PageId) VALUES ('BUILDINGS','BUILDING_PARADE_GENERAL');
INSERT INTO DynamicModifiers (ModifierType,CollectionType,EffectType)
 VALUES ('MODIFIER_PARADE_CITY_PROJECT_PRODUCTION','COLLECTION_OWNER','EFFECT_ADJUST_PROJECT_PRODUCTION');
INSERT INTO Modifiers (ModifierId,ModifierType)
 VALUES ('PARADE_GENERAL_PRODUCTION','MODIFIER_PARADE_CITY_PROJECT_PRODUCTION');
INSERT INTO ModifierArguments (ModifierId,Name,Value) VALUES
 ('PARADE_GENERAL_PRODUCTION','ProjectType','PROJECT_MILITARY_PARADE'),
 ('PARADE_GENERAL_PRODUCTION','Amount',50);
INSERT INTO BuildingModifiers (BuildingType,ModifierId)
 VALUES ('BUILDING_PARADE_GENERAL','PARADE_GENERAL_PRODUCTION');

-- Visible build identity; never used to grant or alter gameplay rewards.
CREATE TABLE ParadeBuildInfo(ID INTEGER PRIMARY KEY, Version TEXT NOT NULL);
INSERT INTO ParadeBuildInfo VALUES(1,'3.20 B1');
