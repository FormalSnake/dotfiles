# Mac apps atoll runs here.
MAC_APPS = [
    pkg("coteditor", source = mac(github("coteditor/CotEditor", asset = "*.dmg"))),
    pkg("rex", source = mac(appcast = "https://blob.superlogical.com/public/rex-app/preview/appcast.xml",
        ed_key = "jG2oqfrStpD6pfzWIBAHHbER3yTLaZWToni8eZiBzxE=")),
    # Electron: atoll install swaps in the matching Linux Electron.
    pkg("notion", source = mac(url("https://desktop-release.notion-static.com/Notion-7.43.0-universal.dmg"))),
    # Test targets. Installed so their progress shows here; not all of them start yet.
    # arm64 only: needs the arm64 translator (atoll spec 3.1.2).
    pkg("dia", source = mac(appcast = "https://releases.diabrowser.com/BoostBrowser-updates.xml")),
    pkg("netnewswire", source = mac(github("Ranchero-Software/NetNewsWire", asset = "NetNewsWire*.zip"))),
    pkg("itsycal", source = mac(appcast = "https://s3.amazonaws.com/itsycal/itsycal.xml")),
    pkg("hexfiend", source = mac(github("HexFiend/HexFiend", asset = "*.dmg"))),
    pkg("rectangle", source = mac(github("rxhanson/Rectangle", asset = "*.dmg"))),
    pkg("keka", source = mac(github("aonez/Keka", asset = "*.dmg"))),
    pkg("iina", source = mac(github("iina/iina", asset = "*.dmg"))),
]
