if hs.fs.attributes(os.getenv("HOME") .. "/.hammerspoon/Spoons/SpoonInstall.spoon") == nil then
	hs.execute('mkdir -p "' .. os.getenv("HOME") .. '/.hammerspoon/Spoons"')
	hs.execute(
		'curl -L https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonInstall.spoon.zip -o "/tmp/SpoonInstall.spoon.zip"'
	)
	hs.execute('unzip -o "/tmp/SpoonInstall.spoon.zip" -d "' .. os.getenv("HOME") .. '/.hammerspoon/Spoons"')
end

hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true
spoon.SpoonInstall:andUse("LeftRightHotkey", { start = true })

local function bindROptToCmdAltCtrl(key)
	spoon.LeftRightHotkey:bind({ "rOption" }, key, function()
		hs.eventtap.keyStroke({ "cmd", "alt", "ctrl" }, key, 0)
	end)
end

for _, key in ipairs({
	"a",
	"s",
	"d",
	"f",
	"h",
	"j",
	"k",
	"l",
	"q",
	"w",
	"e",
	"r",
	"1",
	"2",
	"3",
	"4",
	"space",
	"return",
	"tab",
}) do
	bindROptToCmdAltCtrl(key)
end

hs.alert.show("Hammerspoon config loaded")
