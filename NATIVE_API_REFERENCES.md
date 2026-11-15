# API参考与验证边界

- Firaxis原版WorldInput.lua镜头输入：UI.SpinMap累计归一化拖拽量，UI.SetMapZoom；原版Options.lua的UserConfiguration QuickMovement读写。来源镜像：https://github.com/mrobaczyk/civ6/tree/main/Base/Assets/UI
- Firaxis海盗场景城市与接触：GetCities():Create(x,y)、GetDiplomacy():SetHasMet(id)。https://github.com/mrobaczyk/civ6/blob/main/DLC/PiratesScenario/Scripts/PiratesScenario_StartScript.lua
- Firaxis冷战场景科技SetTech：https://github.com/mrobaczyk/civ6/blob/main/Base/Assets/Scenarios/ColdWarScenario/ColdWarScenario_StartScript.lua
- Hemmelfort模组作者Lua API记录：CreateDistrict(district.Index,plotIndex)、HasDistrict、GetDistrictLocation与可放置检查；这些新增接口仍需实机确认。https://github.com/Hemmelfort/Civ6ModdingNotes/blob/master/文明6_Lua手册.md

离线测试只检验调用协议和逻辑，不能替代原生引擎渲染与规则验收。
