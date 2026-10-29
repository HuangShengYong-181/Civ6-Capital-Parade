"""Offline tests. Uses Lua 5.4 via ctypes; requires liblua5.4 on Linux."""
import ctypes,ctypes.util,pathlib,xml.etree.ElementTree as ET
root=pathlib.Path(__file__).resolve().parents[1]
for name in ['MilitaryParade.civ6proj','MilitaryParade.modinfo','Parade_UI.xml','Parade_Celebration.xml']:ET.parse(root/name)
# Queue validation is intentionally allowed only after world-ready.
lib=ctypes.CDLL(ctypes.util.find_library('lua5.4') or 'liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p];lib.luaL_loadstring.restype=ctypes.c_int
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p];lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
L=lib.luaL_newstate();lib.luaL_openlibs(L)
ids={name:{x.attrib['ID'] for x in ET.parse(root/(name+'.xml')).iter() if 'ID' in x.attrib} for name in ['Parade_UI','Parade_Celebration']}
xml_contract='TEST_CONTROL_IDS={' + ','.join('["'+name+'"]={'+','.join('["'+x+'"]=true' for x in sorted(names))+'}' for name,names in ids.items()) + '}\n'
code='TEST_ROOT=[==['+root.as_posix()+']==]\n'+xml_contract+(root/'tests/regression.lua').read_text()+'\n'+(root/'tests/panels.lua').read_text()+'\n'+(root/'tests/presentation.lua').read_text()+'\n'+(root/'tests/audio.lua').read_text()

rc=lib.luaL_loadstring(L,code.encode())
if rc==0:rc=lib.lua_pcallk(L,0,0,0,0,None)
if rc:raise RuntimeError(lib.lua_tolstring(L,-1,None).decode())
lib.lua_close(L)
print('PASS: XML and Lua regression tests. Real game test still required.')
