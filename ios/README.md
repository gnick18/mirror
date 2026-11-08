# McQueen Mirror (iPhone app)

A native version of the phone remote (`portal/web/remote.html`) with the things a web page can't do: home-screen and Lock Screen widgets with buttons, and a Control Center toggle. It talks to the portal server's JSON API over the home Wi-Fi, so it only works at home.

- The app has the same controls as the web remote. That covers the display mode, which widgets the mirror shows, Spotify (play, pause, skip and "Play on the mirror's speakers"), the "Pretend someone's here" test switch and "Reload the mirror". It also lists the next buses, with a live "in N min" countdown. Pull down to refresh. The gear button opens Settings for the server address.
- "Bus and Music" is a medium home-screen widget. It shows the next two buses beside what's playing, with a play/pause button and a mirror on/off button.
- "Next Bus" is a Lock Screen widget, in rectangular and inline sizes.
- "Mirror Widgets" is a Control Center control. It can also go in a Lock Screen control slot.

Mirror on/off, in the widget and in Control Center, means Auto or Mirror only. Off switches to Mirror only. On goes back to Auto, so the presence sensor decides. The actions also show up in the Shortcuts app.

iOS decides when widgets refresh, usually every 15 to 30 minutes. As a result, a widget shows a snapshot, not live data. Widget bus times are clock times ("Leave 10:25") rather than countdowns, and the medium widget says when it was last updated. Between refreshes, a widget drops each bus once its leave time has passed and moves the next one up. Tapping a widget button calls the API and then refreshes the widgets straight away.

## Layout

- `McQueenMirror/`: the app (SwiftUI, iOS 18).
- `McQueenMirrorWidgets/`: the widget extension (WidgetKit, App Intents).
- `Shared/`: code compiled into both, i.e. the API client and models (`MirrorAPI.swift`), the server address (`MirrorSettings.swift`), the widget button actions (`MirrorIntents.swift`) and the bus helpers.
- `Config/`: Info.plists and entitlements. The app and the extension share the server address through the app group `group.com.grantnickles.McQueenMirror`.
- `tools/make_icon.swift` draws the app icon. It is the web remote's icon redrawn at 1024 px.

The Xcode project uses synchronized folders, so new files in these folders are picked up without editing the project.

## Running it in the Simulator

Start the portal from the main checkout (`portal/.venv/bin/python3 portal/server.py --port 8080`), then open `McQueenMirror.xcodeproj` and run the McQueenMirror scheme. In the Simulator the default server address is `http://127.0.0.1:8080`, which is the Mac itself. On a phone it is `http://mirror.local:8080`. Either can be changed in Settings.

From the command line:

```bash
env -u LD -u CC -u CXX -u LDFLAGS -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u SDKROOT xcodebuild -project ios/McQueenMirror.xcodeproj -scheme McQueenMirror -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

The `env -u` part matters on this Mac. The shell profile activates Anaconda, which sets `LD`, `CC` and other compiler variables. `xcodebuild` treats those as build settings, and the widget extension then fails to link ("ld: unknown option: -Xlinker"). Xcode itself, started from the Dock, isn't affected. Also, `xcode-select` points at the Command Line Tools, so either run `sudo xcode-select -s ~/Applications/Xcode.app/Contents/Developer` once, or put `DEVELOPER_DIR=~/Applications/Xcode.app/Contents/Developer` in front of the command.

## Installing it on the iPhone

1. In Xcode, select each of the two targets, open Signing & Capabilities and pick your team. Xcode then registers the bundle IDs (`com.grantnickles.McQueenMirror` and `.Widgets`) and the app group.
2. Run it on the phone while it's on the home Wi-Fi. The first request asks for Local Network access, which the app and its widgets need to reach `mirror.local`. If you tap Don't Allow, turn it back on under Settings, Privacy & Security, Local Network.
3. Add the widgets as usual: long-press the home screen and tap Edit, then Add Widget. For the Lock Screen, long-press it and tap Customize. For Control Center, open it and tap +.

This project was built with Xcode 16.2, which only has the iOS 18.2 SDK. Xcode 16.2 can't install apps on a phone running a newer iOS than it knows about. If the phone is on a newer iOS, open the project in a newer Xcode instead. The project should open there unchanged.

Plain HTTP to `.local` names and local IP addresses is allowed through `NSAllowsLocalNetworking`, so App Transport Security doesn't block the Pi. Reaching the mirror from outside the house isn't supported.
