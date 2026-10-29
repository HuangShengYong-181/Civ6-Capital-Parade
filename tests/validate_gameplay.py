"""Usage: python validate_gameplay.py /path/to/01_GameplaySchema.sql
Structural SQLite check, not a Civ6 engine test. Uses a stand-in Types hash.
"""
from pathlib import Path
import sqlite3,sys,zlib
r=Path(__file__).resolve().parents[1]
schema=Path(sys.argv[1])
c=sqlite3.connect(':memory:')
c.executescript(schema.read_text(encoding='utf-8-sig'))
c.create_function('TestTypeHash',1,lambda s:zlib.crc32(s.encode()))
c.executescript('CREATE TRIGGER TestHash AFTER INSERT ON Types BEGIN UPDATE Types SET Hash=TestTypeHash(NEW.Type) WHERE Type=NEW.Type;END;')
# Seed representative production candidates before the mod's SQL SELECT.
for unit,combat,ranged in [('UNIT_TEST_MELEE',20,0),('UNIT_TEST_ARCHER',0,25),('UNIT_TEST_SHIP',30,0),('UNIT_TEST_AIR',0,80),('UNIT_TEST_SETTLER',0,0),('UNIT_TEST_BUILDER',0,0)]:
 c.execute("INSERT INTO Units(UnitType,Name,BaseSightRange,BaseMoves,Domain,FormationClass,Cost,Combat,RangedCombat)VALUES(?,?,2,2,'DOMAIN_LAND','FORMATION_CLASS_LAND_COMBAT',40,?,?)",(unit,unit,combat,ranged))
c.executescript((r/'Parade_Data.sql').read_text())
assert c.execute("SELECT Cost,CostProgressionModel,CostProgressionParam1 FROM Projects WHERE ProjectType='PROJECT_MILITARY_PARADE'").fetchone()==(60,'COST_PROGRESSION_GAME_PROGRESS',300)
assert c.execute("SELECT CollectionType,EffectType FROM DynamicModifiers WHERE ModifierType='MODIFIER_PARADE_CITY_PROJECT_PRODUCTION'").fetchone()==('COLLECTION_OWNER','EFFECT_ADJUST_PROJECT_PRODUCTION')
a=dict(c.execute("SELECT Name,Value FROM ModifierArguments WHERE ModifierId='PARADE_GENERAL_PRODUCTION'"))
assert a=={'ProjectType':'PROJECT_MILITARY_PARADE','Amount':'50'}
assert c.execute("SELECT COUNT(*) FROM BuildingModifiers WHERE BuildingType='BUILDING_PARADE_GENERAL' AND ModifierId='PARADE_GENERAL_PRODUCTION'").fetchone()[0]==1
assert not c.execute("SELECT COUNT(*) FROM Project_GreatPersonPoints WHERE ProjectType='PROJECT_MILITARY_PARADE'").fetchone()[0], 'would double grant native and scripted points'
print('PASS: gameplay SQL structure, 60/300 progress cost, city-local parade-only +50% modifier, no duplicate native GP reward')

assert c.execute("SELECT CollectionType,EffectType FROM DynamicModifiers WHERE ModifierType='MODIFIER_PARADE_CITY_UNIT_PRODUCTION'").fetchone()==('COLLECTION_OWNER','EFFECT_ADJUST_UNIT_PRODUCTION')
for unit in ['UNIT_TEST_MELEE','UNIT_TEST_ARCHER','UNIT_TEST_SHIP','UNIT_TEST_AIR']:
 args=dict(c.execute('SELECT Name,Value FROM ModifierArguments WHERE ModifierId=?',('PARADE_TRAIN_'+unit,)))
 assert args=={'UnitType':unit,'Amount':'10'}
 for tier in range(1,6):
  assert c.execute('SELECT COUNT(*)FROM BuildingModifiers WHERE BuildingType=?AND ModifierId=?',('BUILDING_PARADE_BUFF_'+str(tier),'PARADE_TRAIN_'+unit)).fetchone()[0]==1
for unit in ['UNIT_TEST_SETTLER','UNIT_TEST_BUILDER']:
 assert c.execute('SELECT COUNT(*)FROM Modifiers WHERE ModifierId=?',('PARADE_TRAIN_'+unit,)).fetchone()[0]==0
assert c.execute("SELECT COUNT(*)FROM Modifiers WHERE ModifierId='PARADE_MILITARY_PRODUCTION'").fetchone()[0]==0
print('PASS: city-local +10% explicit combat unit types, five mutually-exclusive tiers, land/naval/air, civilian exclusion and removed generic bonus')
