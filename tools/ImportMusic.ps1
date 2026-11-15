Add-Type -AssemblyName System.Windows.Forms
$ErrorActionPreference='Stop'
try {
 $picker=New-Object System.Windows.Forms.OpenFileDialog
 $picker.Title='选择阅兵音乐（自动转换与安装）'; $picker.Filter='音乐文件|*.mp3;*.wav;*.flac;*.ogg;*.m4a'
 if($picker.ShowDialog() -ne 'OK'){exit}
 $runtime=Join-Path $env:LOCALAPPDATA 'MilitaryParade\MusicTools'
 $python=Join-Path $runtime 'python\python.exe'
 $ffmpeg=Get-ChildItem $runtime -Filter ffmpeg.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
 if(!(Test-Path $python) -or !$ffmpeg){
  $answer=[System.Windows.Forms.MessageBox]::Show('首次使用需要下载独立的 Python 与 ffmpeg 到本机工具目录，可能需要数分钟。不会安装到系统或上传音乐。是否继续？','初始化音乐导入工具','YesNo')
  if($answer -ne 'Yes'){exit}
  New-Item -ItemType Directory -Force $runtime | Out-Null
  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
  if(!(Test-Path $python)){
   Invoke-WebRequest 'https://www.python.org/ftp/python/3.12.8/python-3.12.8-embed-amd64.zip' -OutFile "$runtime\python.zip" -UseBasicParsing
   Expand-Archive "$runtime\python.zip" "$runtime\python" -Force
  }
  if(!$ffmpeg){
   Invoke-WebRequest 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile "$runtime\ffmpeg.zip" -UseBasicParsing
   Expand-Archive "$runtime\ffmpeg.zip" "$runtime\ffmpeg" -Force
   $ffmpeg=Get-ChildItem "$runtime\ffmpeg" -Filter ffmpeg.exe -Recurse | Select-Object -First 1
  }
 }
 $pth=Get-ChildItem (Split-Path $python -Parent) -Filter 'python*._pth' | Select-Object -First 1
 if($pth){[IO.File]::WriteAllLines($pth.FullName,@('python312.zip','.', $PSScriptRoot),(New-Object Text.UTF8Encoding($false)))}
 $env:PATH=$ffmpeg.DirectoryName+';'+$env:PATH
 & $python "$PSScriptRoot\custom_music.py" $picker.FileName --install (Split-Path $PSScriptRoot -Parent)
 if($LASTEXITCODE -ne 0){throw '转换失败，请查看窗口中的具体错误。'}
 [System.Windows.Forms.MessageBox]::Show('音乐已安装。重启游戏，在高级设置选择本地自定义音乐，或在阅兵界面切换到自选曲目。','导入完成') | Out-Null
} catch {
 [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'音乐导入失败') | Out-Null
 exit 1
}
