-- Polish Writer.app — startup file (runs instead of ~/.hammerspoon/init.lua).
-- Program files live inside the app; personal files go to ~/Library/Application Support/Polish Writer.
POLISH_BUNDLED = true
POLISH_DIR = POLISH_APP_RESOURCES .. "/polish"
POLISH_DATA = hs.configdir
require("polish")
