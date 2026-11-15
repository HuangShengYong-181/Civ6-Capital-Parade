param([switch]$Restore)
Add-Type -AssemblyName System.Windows.Forms
$ErrorActionPreference='Stop'
try {
 $picker=New-Object System.Windows.Forms.FolderBrowserDialog
 $picker.Description='选择文明6游戏安装目录（包含 Base 文件夹），不是模组目录'
 if($picker.ShowDialog() -ne 'OK'){exit}
 $game=$picker.SelectedPath
 if(!(Test-Path "$game\Base\ArtDefs\Camera.artdef")){throw '所选目录中没有 Base/ArtDefs/Camera.artdef。'}
 $files=@(Get-ChildItem "$game\Base" -Filter Camera.artdef -Recurse)
 if(Test-Path "$game\DLC"){$files+=Get-ChildItem "$game\DLC" -Filter Camera.artdef -Recurse}
 $count=0
 $details=New-Object System.Collections.Generic.List[string]
 foreach($file in $files){
  $backup=$file.FullName+'.MilitaryParade.backup'
  if($Restore){if(Test-Path $backup){Copy-Item $backup $file.FullName -Force;$count++};continue}
  $raw=[IO.File]::ReadAllText($file.FullName)
  [xml]$xml=$raw.Replace('AssetObjects::','AssetObjects__')
  $changed=$false
  foreach($camera in $xml.SelectNodes('//m_RootCollections/Element/Element')){
   # Camera presets differ by game/DLC build. Match actual HeightCurve data, not a guessed preset name.
   $hasHeight=$camera.SelectSingleNode('m_ChildCollections/Element[m_CollectionName/@text="HeightCurve"]')
   if(!$hasHeight){continue}
   foreach($v in $camera.SelectNodes('m_Fields/m_Values/Element')){
    if($v.m_ParamName.text -eq 'MinHexesVisible'){$v.m_fValue='0.750000';$changed=$true}
   }
   foreach($collection in $camera.SelectNodes('m_ChildCollections/Element')){
    if($collection.m_CollectionName.text -ne 'HeightCurve'){continue}
    foreach($point in $collection.SelectNodes('Element')){
     $time=$point.SelectSingleNode('m_Fields/m_Values/Element[m_ParamName/@text="Time"]/m_fValue')
     $height=$point.SelectSingleNode('m_Fields/m_Values/Element[m_ParamName/@text="Height"]/m_fValue')
     if($time -and $height -and [double]$time.InnerText -eq 0){
      $details.Add($file.FullName+' | '+$camera.m_Name.text+' | '+$height.InnerText+' -> 18')
      $height.InnerText='18.000000';$changed=$true
     }
    }
   }
  }
  if($changed){
   if(!(Test-Path $backup)){Copy-Item $file.FullName $backup}
   [IO.File]::WriteAllText($file.FullName,$xml.OuterXml.Replace('AssetObjects__','AssetObjects::'),(New-Object Text.UTF8Encoding($false)))
   $count++
  }
 }
 if($count -eq 0){throw '没有找到可修改或可还原的相机配置；没有完成安装。请确认游戏目录。'}
 $details | Set-Content (Join-Path $PSScriptRoot 'CameraInstallReport.txt') -Encoding UTF8
 [System.Windows.Forms.MessageBox]::Show("处理了 $count 个相机文件。请完全重启游戏。近景补丁会同时放宽普通地图的最近缩放，恢复脚本可还原备份。",'相机设置') | Out-Null
} catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'相机设置失败') | Out-Null;exit 1 }
