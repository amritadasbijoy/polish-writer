-- ===== Polish Writer: load the app's own startup file instead of ~/.hammerspoon/init.lua =====
local _args = table.pack(...)
local _res = (_args[1]:gsub("/extensions/?$", ""))          -- …/Polish Writer.app/Contents/Resources
POLISH_APP_RESOURCES = _res
local _data = os.getenv("HOME") .. "/Library/Application Support/Polish Writer"
os.execute('mkdir -p "' .. _data .. '"')
package.path = _res .. "/?.lua;" .. _res .. "/?/init.lua;" .. package.path
_args[3] = "Polish Writer"                                     -- name shown in messages
_args[4] = _res .. "/boot.lua"                                 -- file to run
_args[5] = _data                                               -- hs.configdir
_args[7] = true                                                -- "has an init file"
return require'hs._coresetup'.setup(table.unpack(_args, 1, _args.n))
