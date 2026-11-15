#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Convert a local audio file into the mod's private custom Wwise bank.
Usage: python tools/custom_music.py [music.mp3] [--start 0] [--duration 30]
Requires Python 3 and ffmpeg on PATH. No upload or network access.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import wave
import json
import build_audio

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('music',nargs='?')
    parser.add_argument('--install',type=Path,default=build_audio.ROOT,help='已安装的 MilitaryParade 目录')
    parser.add_argument('--start',type=float,default=0)
    parser.add_argument('--duration',type=float,default=30)
    args=parser.parse_args()
    if not args.music:
        from tkinter import Tk,filedialog
        root=Tk();root.withdraw()
        args.music=filedialog.askopenfilename(title='选择阅兵音乐（只在本机转换）',filetypes=[('Audio','*.mp3 *.wav *.flac *.ogg *.m4a'),('All','*.*')])
        root.destroy()
    if not args.music:
        return
    source=Path(args.music).resolve()
    if not source.is_file():
        parser.error('音频文件不存在')
    destination=args.install.resolve()
    if not (destination/'MilitaryParade.modinfo').is_file(): parser.error('目标不是 MilitaryParade 模组目录')
    ffmpeg=shutil.which('ffmpeg')
    if not ffmpeg:
        parser.error('未找到 ffmpeg：请先安装并添加到 PATH，再重新运行。')
    if args.start<0 or not 1<=args.duration<=60:
        parser.error('开始时间须非负，片段长度须为1至60秒')
    with tempfile.TemporaryDirectory(prefix='military-parade-music-') as tmp:
        wav=Path(tmp)/'music.wav'
        subprocess.run([ffmpeg,'-nostdin','-v','error','-ss',str(args.start),'-i',str(source),'-t',str(args.duration),'-vn','-ac','2','-ar','44100','-c:a','pcm_s16le','-af','afade=t=in:d=0.4,afade=t=out:st='+str(max(0,args.duration-1))+':d=1','-y',str(wav)],check=True)
        with wave.open(str(wav),'rb') as audio: duration=audio.getnframes()/audio.getframerate()
        bank=destination/'Platforms/Windows/Audio/MilitaryParade_Custom_Bank.bnk'
        if bank.exists(): shutil.copy2(bank,bank.with_suffix('.bnk.backup'))
        build_audio.build(wav,custom=True,output_root=destination)
        # JSON quoted UTF-8 text is valid Lua for file names except control escapes.
        title=''.join(c for c in source.stem if ord(c)>=32)
        quoted='"'+''.join('\\%03d'%b for b in title.encode('utf-8'))+'"'
        (destination/'Parade_CustomMusic.lua').write_text('ParadeCustomMusic={Installed=true,Title='+quoted+',Duration='+str(duration)+'}\n',encoding='utf-8')
    print('完成，已安装到：',destination,'\n重启游戏后，高级设置选“本地自定义音乐”；阅兵页面的切换音乐按钮也可切换到自选曲目。')

if __name__=='__main__':
    main()
