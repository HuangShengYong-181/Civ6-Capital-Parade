-- UTF-8. Load with UpdateText, NOT UpdateDatabase.
INSERT OR REPLACE INTO LocalizedText (Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PROJECT_MILITARY_PARADE_NAME','阅兵'),
('zh_Hans_CN','LOC_PROJECT_MILITARY_PARADE_DESCRIPTION','完成“帝国初期”后，仅限首都市中心有本国战斗驻军时进行。[NEWLINE]完成后，按军事分提升全帝国忠诚度、战斗力与宜居度，军事单位生产力+10%，持续10回合；另获大将军点数及时代分。[NEWLINE]大将军驻首都市中心：本项目生产力+50%，鼓舞提升一档。重复完成刷新效果，不叠加。'),
('zh_Hans_CN','LOC_PARADE_INTERNAL_NAME','阅兵资格（脚本管理）'),
('zh_Hans_CN','LOC_PARADE_BUFF_NAME','阅兵鼓舞'),
('zh_Hans_CN','LOC_PARADE_BUFF_DESCRIPTION','军威振奋：提升忠诚度、战斗力、宜居度与军事单位生产力。'),
('zh_Hans_CN','LOC_PARADE_COMBAT_PREVIEW','+{1_Amount} 阅兵鼓舞'),
('en_US','LOC_PROJECT_MILITARY_PARADE_NAME','Military Parade'),
('en_US','LOC_PROJECT_MILITARY_PARADE_DESCRIPTION','Requires Early Empire and your combat garrison in the capital center.[NEWLINE]Grants 10 turns of empire-wide Loyalty, Combat Strength and Amenities based on military strength, plus +10% military unit Production. Also awards Great General points and Era Score.[NEWLINE]A Great General in the capital center gives +50% Production toward this project and raises inspiration by one tier. Repeating refreshes effects without stacking.'),
('en_US','LOC_PARADE_INTERNAL_NAME','Parade eligibility (script managed)'),
('en_US','LOC_PARADE_BUFF_NAME','Parade Inspiration'),
('en_US','LOC_PARADE_BUFF_DESCRIPTION','Inspired forces improve Loyalty, Combat Strength, Amenities and military unit Production.'),
('en_US','LOC_PARADE_COMBAT_PREVIEW','+{1_Amount} Parade Inspiration');
INSERT OR REPLACE INTO LocalizedText (Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PARADE_ACTIVE_STATUS','阅兵鼓舞：剩余{1}回合 · 忠诚度+{2}/回合 · 战斗力+{3} · 宜居度+{4} · 军事生产力+10%'),
('en_US','LOC_PARADE_ACTIVE_STATUS','Parade: {1} turns · Loyalty +{2}/turn · Combat +{3} · Amenities +{4} · Military Production +10%');

-- Eligibility diagnostics are read-only UI text.
INSERT OR REPLACE INTO LocalizedText (Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PARADE_PERMIT_NAME','阅兵许可（首都驻军）'),
('en_US','LOC_PARADE_PERMIT_NAME','Parade Permit (Capital Garrison)'),
('zh_Hans_CN','LOC_PARADE_PERMIT_DESCRIPTION','完成帝国初期且当前首都市中心驻有本国战斗单位时，由脚本授予；不满足条件时撤销。'),
('en_US','LOC_PARADE_PERMIT_DESCRIPTION','Script-managed permit for the current capital with Early Empire and an own combat garrison.'),
('zh_Hans_CN','LOC_PARADE_NEED_CAPITAL','阅兵：需要建立首都'),
('en_US','LOC_PARADE_NEED_CAPITAL','Parade: found your capital'),
('zh_Hans_CN','LOC_PARADE_NEED_CIVIC','阅兵：需要完成“帝国初期”'),
('en_US','LOC_PARADE_NEED_CIVIC','Parade: research Early Empire'),
('zh_Hans_CN','LOC_PARADE_NEED_GARRISON','阅兵：需要本国战斗单位进入首都市中心'),
('en_US','LOC_PARADE_NEED_GARRISON','Parade: move your combat unit into the capital center'),
('zh_Hans_CN','LOC_PARADE_WAIT_PERMIT','阅兵：驻军条件已满足，等待许可同步；可尝试进入下一回合'),
('en_US','LOC_PARADE_WAIT_PERMIT','Parade: waiting for permit sync; advance to your next turn if needed'),
('zh_Hans_CN','LOC_PARADE_ENGINE_BLOCKED','阅兵：许可已生效；若项目未在生产却仍无法选择，请提供日志'),
('en_US','LOC_PARADE_ENGINE_BLOCKED','Parade: permit active; if not already in production and still unavailable, inspect logs'),
('zh_Hans_CN','LOC_PARADE_AVAILABLE','阅兵：首都已具备条件，可在城市生产的“项目”中选择'),
('en_US','LOC_PARADE_AVAILABLE','Parade available: select it under Projects in your capital');

INSERT OR REPLACE INTO LocalizedText (Language,Tag,Text) VALUES ('zh_Hans_CN','LOC_PARADE_DATA_MISSING','阅兵：项目数据库未加载，请检查日志'),('en_US','LOC_PARADE_DATA_MISSING','Parade project data missing: inspect logs');

-- v3.8 presentation strings
INSERT OR REPLACE INTO LocalizedText (Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PARADE_CLOCK_TOOLTIP','阅兵鼓舞[NEWLINE]战斗力 +{1}[NEWLINE]剩余 {2} 回合（与帝国鼓舞同时到期）'),
('en_US','LOC_PARADE_CLOCK_TOOLTIP','Parade Inspiration[NEWLINE]Combat Strength +{1}[NEWLINE]{2} turns remaining; expires with the empire bonus'),
('zh_Hans_CN','LOC_PARADE_FORMER_CAPITAL','原阅兵城市'),
('en_US','LOC_PARADE_FORMER_CAPITAL','Former parade city'),
('zh_Hans_CN','LOC_PARADE_CELEBRATION_FIRST','盛 大 阅 兵'),
('en_US','LOC_PARADE_CELEBRATION_FIRST','GRAND MILITARY PARADE'),
('zh_Hans_CN','LOC_PARADE_CELEBRATION_REPEAT','阅 兵 再 启'),
('en_US','LOC_PARADE_CELEBRATION_REPEAT','MILITARY PARADE RENEWED'),
('zh_Hans_CN','LOC_PARADE_CELEBRATION_REPLAY','阅 兵 纪 录'),
('en_US','LOC_PARADE_CELEBRATION_REPLAY','PARADE RECORD'),
('zh_Hans_CN','LOC_PARADE_PARTICIPANTS','首都周边参阅部队：{1} 支（展示最多8支）'),
('en_US','LOC_PARADE_PARTICIPANTS','Nearby forces: {1} units (up to 8 shown)'),
('zh_Hans_CN','LOC_PARADE_CELEBRATION_REWARD','军事分 {1}  ·  战斗力 +{2}  ·  忠诚度 +{3}/回合  ·  宜居度 +{4}[NEWLINE]军事生产力 +10%  ·  剩余 {5} 回合'),
('en_US','LOC_PARADE_CELEBRATION_REWARD','Military strength {1} · Combat +{2} · Loyalty +{3}/turn · Amenities +{4}[NEWLINE]Military Production +10% · {5} turns remaining'),
('zh_Hans_CN','LOC_PARADE_CELEBRATION_TURN','第 {1} 回合完成'),
('en_US','LOC_PARADE_CELEBRATION_TURN','Completed on turn {1}'),
('zh_Hans_CN','LOC_PARADE_CELEBRATION_CLOSE','检 阅 结 束'),
('en_US','LOC_PARADE_CELEBRATION_CLOSE','Conclude Review');

INSERT OR REPLACE INTO LocalizedText (Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PARADE_SOUND_TEST','重播配乐'),
('en_US','LOC_PARADE_SOUND_TEST','Replay music'),
('zh_Hans_CN','LOC_PARADE_REPLAY_CAMERA','重播镜头'),
('en_US','LOC_PARADE_REPLAY_CAMERA','Replay camera');

INSERT OR REPLACE INTO LocalizedText (Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PARADE_GENERAL_NAME','大将军检阅'),
('en_US','LOC_PARADE_GENERAL_NAME','General Review'),
('zh_Hans_CN','LOC_PARADE_GENERAL_DESCRIPTION','大将军在当前首都市中心且阅兵资格有效时，阅兵项目生产力+50%。'),
('en_US','LOC_PARADE_GENERAL_DESCRIPTION','+50% Production toward Military Parade while a Great General is in the eligible capital center.'),
('zh_Hans_CN','LOC_PARADE_GENERAL_AWARD','本次获得大将军点数 +{1}'),
('en_US','LOC_PARADE_GENERAL_AWARD','Great General points awarded: +{1}'),
('zh_Hans_CN','LOC_PARADE_GENERAL_TIER','大将军检阅：第{1}档 → 第{2}档（最高五档）'),
('en_US','LOC_PARADE_GENERAL_TIER','General review: tier {1} → {2} (maximum 5)'),
('zh_Hans_CN','LOC_PARADE_SOUND_CHOICE','试听 {1}/{2}'),
('en_US','LOC_PARADE_SOUND_CHOICE','Sound {1}/{2}');

INSERT OR REPLACE INTO LocalizedText (Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PARADE_AVAILABLE_GENERAL','阅兵：可进行 · 大将军检阅：阅兵生产力+50%，完成奖励提升一档（最高五档）'),
('en_US','LOC_PARADE_AVAILABLE_GENERAL','Parade available: general supervision gives +50% project Production and +1 reward tier (max 5)');

INSERT OR REPLACE INTO LocalizedText(Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PARADE_FOCUS_NO_GARRISON','首都当前没有军事驻军'),
('en_US','LOC_PARADE_FOCUS_NO_GARRISON','No military garrison currently in the capital');

INSERT OR REPLACE INTO LocalizedText(Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PARADE_CEREMONY_TITLE',' {1} · 第{2}次盛大阅兵'),
('en_US','LOC_PARADE_CEREMONY_TITLE','{1} · Grand Parade No. {2}'),
('zh_Hans_CN','LOC_PARADE_REVIEW_ARMY','诸军列阵 · 首都检阅'),
('en_US','LOC_PARADE_REVIEW_ARMY','Army assembled · Capital review'),
('zh_Hans_CN','LOC_PARADE_REVIEW_SIGNATURE','{1} · 主持检阅'),
('en_US','LOC_PARADE_REVIEW_SIGNATURE','Reviewed by {1}'),
('zh_Hans_CN','LOC_PARADE_SKIP_TO_AWARD','跳至授赏'),
('en_US','LOC_PARADE_SKIP_TO_AWARD','Skip to awards'),
('zh_Hans_CN','LOC_PARADE_STAGE_OPEN','开典 · 举国同庆'),
('en_US','LOC_PARADE_STAGE_OPEN','Opening · A nation celebrates'),
('zh_Hans_CN','LOC_PARADE_STAGE_REVIEW','检阅 · 三军肃立'),
('en_US','LOC_PARADE_STAGE_REVIEW','Review · The army stands ready'),
('zh_Hans_CN','LOC_PARADE_STAGE_QUOTE','宣告 · 以铭壮志'),
('en_US','LOC_PARADE_STAGE_QUOTE','Proclamation · Words to remember'),
('zh_Hans_CN','LOC_PARADE_STAGE_AWARD','礼成 · 国威振奋'),
('en_US','LOC_PARADE_STAGE_AWARD','Ceremony complete · National pride'),
('zh_Hans_CN','LOC_PARADE_RANK_1','军容整肃'),
('en_US','LOC_PARADE_RANK_1','Disciplined Ranks'),
('zh_Hans_CN','LOC_PARADE_RANK_2','士气振奋'),
('en_US','LOC_PARADE_RANK_2','Spirits Raised'),
('zh_Hans_CN','LOC_PARADE_RANK_3','军威赫赫'),
('en_US','LOC_PARADE_RANK_3','Mighty Host'),
('zh_Hans_CN','LOC_PARADE_RANK_4','威震四方'),
('en_US','LOC_PARADE_RANK_4','Far-Reaching Might'),
('zh_Hans_CN','LOC_PARADE_RANK_5','国威远扬'),
('en_US','LOC_PARADE_RANK_5','Glory of the Nation'),
('zh_Hans_CN','LOC_PARADE_NO_GENERAL','首都诸军'),
('en_US','LOC_PARADE_NO_GENERAL','Capital forces');


INSERT OR REPLACE INTO LocalizedText(Language,Tag,Text) VALUES
('zh_Hans_CN','LOC_PARADE_ERA_FIRST_TITLE','旌旗耀日，国威初扬'),
('en_US','LOC_PARADE_ERA_FIRST_TITLE','Banners Aloft, A Nation Rises'),
('zh_Hans_CN','LOC_PARADE_ERA_REPEAT_TITLE','金鼓再振，国威重光'),
('en_US','LOC_PARADE_ERA_REPEAT_TITLE','Drums Resound, Glory Renewed'),
('zh_Hans_CN','LOC_PARADE_ERA_FIRST_BODY','旌旗蔽日，铁甲凝霜。[NEWLINE]六军肃列，万众昂扬。[NEWLINE]陈师帝阙，威震八荒。[NEWLINE]山河永固，国祚隆昌。'),
('en_US','LOC_PARADE_ERA_FIRST_BODY','Banners shade the sun; bright armor gleams.[NEWLINE]Ranks stand firm; the nation lifts its dreams.[NEWLINE]Before the capital, our strength is shown.[NEWLINE]May lasting peace and lasting glory crown our home.'),
('zh_Hans_CN','LOC_PARADE_ERA_REPEAT_BODY','岁序更始，旌旆重张。[NEWLINE]三军砺刃，万众图强。[NEWLINE]承先启后，奋武扬光。[NEWLINE]长缨在手，永镇八荒。'),
('en_US','LOC_PARADE_ERA_REPEAT_BODY','An era dawns; our standards rise again.[NEWLINE]Blades are honed, and hope inspires our ranks.[NEWLINE]We honor those before and strive anew.[NEWLINE]Our watch endures across the lands we guard.'),
('zh_Hans_CN','LOC_PARADE_ERA_GENERAL_BODY','大将秉钺，列阵中央。[NEWLINE]一呼雷动，万甲生光。[NEWLINE]进如山岳，止若金汤。[NEWLINE]扬威四海，卫我封疆。'),
('en_US','LOC_PARADE_ERA_GENERAL_BODY','The general bears the axe before the line.[NEWLINE]One call rings out; ten thousand armors shine.[NEWLINE]Our march is mighty, our defenses strong.[NEWLINE]We guard these lands, where our people belong.'),
('zh_Hans_CN','LOC_PARADE_ERA_GAIN','本次时代分 +{1}'),
('en_US','LOC_PARADE_ERA_GAIN','Era Score awarded: +{1}'),
('zh_Hans_CN','LOC_PARADE_ERA_ALREADY','本次时代分未发放'),
('en_US','LOC_PARADE_ERA_ALREADY','No Era Score awarded for this completion'),
('zh_Hans_CN','LOC_PARADE_ERA_UNAVAILABLE','本次时代分未发放'),
('en_US','LOC_PARADE_ERA_UNAVAILABLE','No Era Score awarded this time');
