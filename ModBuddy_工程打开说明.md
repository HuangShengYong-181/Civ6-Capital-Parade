# 工程与发行目录

使用Source/MilitaryParade/MilitaryParade.sln打开完整工程。

Steam首发无需重新Build，直接在Steam Workshop Uploader中选择Release/MilitaryParade/MilitaryParade.modinfo。

若需要重新编译源码，项目的Mod.Art.xml会触发SDK美术依赖构建；需安装Development Assets并设置正确Assets Path。资源根目录下必须存在Civ6/pantry/Civ6.Art.xml。

工程保留原有GUID，采用UTF-8 BOM与CRLF；旧EmptyMod1解决方案名称已停用。
