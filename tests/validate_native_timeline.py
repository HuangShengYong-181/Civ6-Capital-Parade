"""Usage: python validate_native_timeline.py /installed/HistoricMoments.lua [...]
Runs original XP1/XP2 Lua against mocked controls. Does not run the Firaxis UI.
The game file is read only and is deliberately not bundled with this mod.
"""
import ctypes,ctypes.util,pathlib,re,sys
r=pathlib.Path(__file__).resolve().parents[1]
lib=ctypes.CDLL(ctypes.util.find_library('lua5.4') or 'liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p];lib.luaL_loadstring.restype=ctypes.c_int
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p];lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
assert len(sys.argv)>1,'Supply original installed-game timeline Lua files'
for fn in sys.argv[1:]:
 source=pathlib.Path(fn).read_text(encoding='utf-8-sig')
 source=re.sub(r':\s*(?:number|string|table|boolean)\b','',source)
 code='TEST_ROOT=[==['+r.as_posix()+']==]\nTEST_NATIVE=[==['+source+']==]\n'+(r/'tests/timeline.lua').read_text()
 state=lib.luaL_newstate();lib.luaL_openlibs(state)
 rc=lib.luaL_loadstring(state,code.encode())
 if rc==0:rc=lib.lua_pcallk(state,0,0,0,0,None)
 if rc:raise RuntimeError(fn+': '+lib.lua_tolstring(state,-1,None).decode())
 lib.lua_close(state)
 print('PASS:',fn)
