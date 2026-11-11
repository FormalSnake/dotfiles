# Mac apps atoll runs here.
MAC_APPS = [
    pkg("coteditor", source = mac(github("coteditor/CotEditor", asset = "*.dmg"))),
    pkg("rex", source = mac(appcast = "https://blob.superlogical.com/public/rex-app/preview/appcast.xml",
        ed_key = "jG2oqfrStpD6pfzWIBAHHbER3yTLaZWToni8eZiBzxE=")),
    # Electron: atoll install swaps in the matching Linux Electron.
    pkg("notion", source = mac(url("https://desktop-release.notion-static.com/Notion-7.43.0-universal.dmg"))),
]
