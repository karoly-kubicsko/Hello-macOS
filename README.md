# Hello — a native macOS app

A small SwiftUI application that opens a window with a time-of-day greeting and
today's date. The greeting is shown on one line, and wraps onto centred lines
when the window is too narrow for it. It is the macOS counterpart of the iPhone
web app "Hello", with the same hours and colours:

| Local time    | Greeting                | Background | Text      | Accent    |
|---------------|-------------------------|------------|-----------|-----------|
| 05:00–10:59   | Good Morning, Károly    | `#FFE8D6`  | `#3A2E39` | `#A6480B` |
| 11:00–16:59   | Good Afternoon, Károly  | `#EAF4FB`  | `#16324F` | `#B8790A` |
| 17:00–20:59   | Good Evening, Károly    | `#3B2350`  | `#F3E6D8` | `#F2874B` |
| 21:00–04:59   | Good Night, Károly      | `#0B1026`  | `#E4E0F5` | `#F4D35E` |

The date is shown in Hungarian order with English month and day names, for
example *2026. October 30., Friday*.
The window refreshes every minute, so the greeting and the date change while it
stays open. Closing the window quits the app.

![App icon](Icon/AppIcon.png)

## Bundle layout

`build.sh` produces a standard macOS application bundle:

```
build/Hello.app/
└── Contents/
    ├── Info.plist             bundle metadata (identifier, version, minimum macOS)
    ├── PkgInfo                "APPL????"
    ├── MacOS/
    │   └── Hello              universal executable (arm64 + x86_64)
    ├── Resources/
    │   └── AppIcon.icns       app icon, 16–1024 px
    └── _CodeSignature/
        └── CodeResources      ad-hoc code signature
```

## Building on a Mac

Requirements: macOS 26 Tahoe or later, and either Xcode or the Command Line
Tools (`xcode-select --install`). No Xcode project is needed.

```sh
git clone https://github.com/karoly-kubicsko/Hello-macOS.git
cd Hello-macOS
./build.sh --open          # builds build/Hello.app and launches it
```

To install, drag `build/Hello.app` into `/Applications`.

## Ready-made download

Every push is built on a GitHub-hosted macOS runner
(`.github/workflows/build-macos-app.yml`). Open the latest run under the
repository's **Actions** tab and download the **Hello-macOS** artifact. It
contains `Hello.zip`; unzip it to get `Hello.app`.

The app is ad-hoc signed, not notarised, so Gatekeeper blocks a downloaded copy
the first time it is opened. Either:

- try to open it, then choose **System Settings → Privacy & Security → Open Anyway**, or
- remove the quarantine flag: `xattr -dr com.apple.quarantine Hello.app`.

A copy you build yourself with `build.sh` is not quarantined and opens directly.

## Versions

| Version | Git tag | Changes |
|---------|---------|---------|
| 3.0     | `v3.0`  | Liquid Glass design (macOS 26): the greeting and date sit on a glass card over soft glows in the time-of-day colours. Requires macOS 26 Tahoe. |
| 2.0     | `v2.0`  | Greeting on one line; it wraps onto centred lines only in narrow windows. Greetings capitalised ("Good Afternoon"). Wider default window. |
| 1.0     | `v1.0`  | Time-of-day greeting and colours; date in Hungarian order with English month and day names. |

The installed app's version is shown under **Hello → About Hello**. To build a
specific version, clone its tag (Git's "detached HEAD" note is expected):

```sh
git clone --branch v1.0 https://github.com/karoly-kubicsko/Hello-macOS.git Hello-1.0
cd Hello-1.0
./build.sh --open
```

## Project files

| Path                     | Purpose                                                   |
|--------------------------|-----------------------------------------------------------|
| `Sources/HelloApp.swift` | the whole app: window, greeting view, themes              |
| `Resources/Info.plist`   | bundle metadata, copied into `Contents/`                  |
| `Resources/AppIcon.icns` | generated icon, copied into `Contents/Resources/`         |
| `Icon/make_icon.py`      | regenerates the icon (`python3 Icon/make_icon.py`; needs Pillow and NumPy) |
| `build.sh`               | compiles, assembles and signs the bundle                  |

To greet someone else, change the `name` constant at the top of
`Sources/HelloApp.swift` and rebuild.
