-- Frontend configuration only. Deliberately independent of the gameplay mod ID.
-- Exact configuration IDs are the public interface consumed by Parade 2.0.
DELETE FROM Parameters
 WHERE ConfigurationGroup='Game'
 AND ConfigurationId IN ('PARADE2_MUSIC');
DELETE FROM DomainValues WHERE Domain='Parade2StandaloneMusic';
INSERT INTO DomainValues (Domain,Value,Name,Description,SortIndex) VALUES
 ('Parade2StandaloneMusic','DEFAULT','国际歌（默认）','播放阅兵模组附带的国际歌片段。',0),
 ('Parade2StandaloneMusic','CUSTOM','本地自定义音乐','先退出游戏，双击附带的选择阅兵音乐工具选MP3，自动导入后重启；这里选择已导入曲目。',1),
 ('Parade2StandaloneMusic','OFF','关闭阅兵音乐','不播放阅兵音乐，保留正常背景音乐。',2);
-- Global parameters use NULL Key1/Key2, matching the stock Parameters query.
INSERT INTO Parameters
 (ParameterId,Name,Description,Domain,DefaultValue,ConfigurationGroup,ConfigurationId,
  GroupId,SortIndex,SupportsSinglePlayer,SupportsLANMultiplayer,
  SupportsInternetMultiplayer,SupportsHotSeat,SupportsPlayByCloud,Visible)
VALUES
 ('Parade2Music','阅兵音乐','选择国际歌、已导入的本地曲目或关闭。',
  'Parade2StandaloneMusic','DEFAULT','Game','PARADE2_MUSIC','GameOptions',975,1,0,0,0,0,1);
CREATE TABLE IF NOT EXISTS Parade2SettingsInfo
 (ID INTEGER PRIMARY KEY,Build TEXT NOT NULL);
INSERT OR REPLACE INTO Parade2SettingsInfo(ID,Build) VALUES(1,'settings-2.0.5');
