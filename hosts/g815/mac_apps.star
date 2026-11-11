# Mac apps atoll runs here. Rex stays a manual install until its terminal draws.
MAC_APPS = [
    pkg("coteditor", source = mac(github("coteditor/CotEditor", asset = "*.dmg"))),
    # Electron: atoll install swaps in the matching Linux Electron.
    pkg("notion", source = mac(url("https://desktop-release.notion-static.com/Notion-7.43.0-universal.dmg"))),
]
