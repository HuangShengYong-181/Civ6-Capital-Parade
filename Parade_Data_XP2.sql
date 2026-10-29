-- Loaded ONLY when Expansion2 is the active GameCore.
INSERT OR IGNORE INTO Projects_XP2
 (ProjectType,RequiredPowerWhileActive,ReligiousPressureModifier,UnlocksFromEffect,
 RequiredBuilding,CreateBuilding,FullyPoweredWhileActive,MaxSimultaneousInstances)
VALUES ('PROJECT_MILITARY_PARADE',0,0,0,'BUILDING_PARADE_ELIGIBLE',NULL,0,1);
UPDATE Projects_XP2 SET RequiredBuilding='BUILDING_PARADE_ELIGIBLE',UnlocksFromEffect=0
 WHERE ProjectType='PROJECT_MILITARY_PARADE';
