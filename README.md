# ImageSplitter — macOS Multi-Screen Wallpaper Splitter

Split any image across your multi-monitor setup. **Auto-detects your screens**, respects their exact layout, resolution and position, then **applies the wallpapers directly** — or exports them.

---

## Features

### Core
- **Auto-detection** — reads connected screens via `NSScreen.screens` (resolution, Retina scale, position)
- **Real layout mapping** — handles heterogeneous setups (4K center + 1080p sides, vertical stacking, offset monitors)
- **Current wallpaper on launch** — your existing desktop wallpaper is loaded automatically as the starting image
- **One-click apply** — sets each split tile as the desktop wallpaper on the correct screen via `NSWorkspace.setDesktopImageURL()`
- **Real-time fit preview** — changing fit mode or anchor instantly updates the wallpaper on all screens without flickering
- **Persistent save** — wallpapers are saved in `~/Library/Application Support/ImageSplitter/` so they survive reboots
- **Live preview** — see the image mapped onto your exact screen configuration before applying
- **4 fit modes** — Fill (crop edges), Fit (letterbox), Stretch, Center
- **Anchor point** — control where the image is anchored when letterboxed (9 presets + free positioning)
- **Per-screen export** — each tile is resized to the exact native resolution of its target screen
- **Drag & drop** — drop an image anywhere in the window
- **Virtual screens** — add screens not yet connected to plan a future setup

### Browse (Unsplash & Pexels)
- **My Presets** — saved screen configurations shown as a card grid (thumbnail, fit mode, screen count, canvas ratio); select one to restore image + layout instantly
- **Search** by keyword or use quick-tags (Nature, Space, Ocean, City…)
- **Match ratio** filter — show only photos that match your multi-screen aspect ratio
- **One-click use** — click a photo to download the full resolution, apply it to all screens immediately, and switch to the Split tab
- Requires a free API key for each service (stored locally in preferences, never compiled into the app)

### Presets
- Save your screen config + fit mode + source image (image is copied into the app's storage, not a fragile file reference)
- Reload any preset from Browse → My Presets — image, layout and fit are restored and applied instantly
- Delete presets from the card grid with the trash icon on hover

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Open image |
| ⇧⌘R | Refresh screen detection |
| ⇧⌘↩ | Apply wallpapers |
| ⌘E | Export to folder |
| ⌘S | Save preset |
| ⌘? | In-app Help |
| ⌘, | Settings (API keys, license) |

---

## Project Structure

```
ImageSplitter/
├── ImageSplitterApp.swift              # Entry point, window config, menu commands
├── SplitterViewModel.swift             # Central state + all user actions
├── Models/
│   ├── ScreenInfo.swift                # Single display (position, resolution, backing scale)
│   └── SplitTile.swift                 # Cropped image tile for one screen
├── Services/
│   ├── ScreenManager.swift             # NSScreen auto-detection + virtual screen management
│   ├── ImageSplitterService.swift      # Image mapping, cropping, resizing, export
│   ├── WallpaperService.swift          # NSWorkspace apply (quick silent + full) + disk persistence
│   ├── PresetManager.swift             # Save/load screen configs + source image file storage
│   ├── UnsplashService.swift           # Unsplash API — search, random, download
│   └── PexelsService.swift             # Pexels API — search, random, download
└── Views/
    ├── ContentView.swift               # Main layout (Split tab + Browse tab)
    ├── CurrentWallpaperView.swift      # Wallpaper drop zone + current wallpaper display per screen
    ├── ScreenLayoutView.swift          # Visual preview with tiles on screens
    ├── ScreenListView.swift            # Sidebar display list (edit/add/remove)
    ├── BrowseView.swift                # My Presets + Unsplash + Pexels browser
    ├── ToolbarView.swift               # Fit mode, export, apply controls
    ├── TileDetailView.swift            # Selected tile detail + single export
    ├── SettingsView.swift              # API keys, About tabs
    └── HelpView.swift                  # In-app help
```

---

## API Keys

API keys are **never compiled into the app**. They are stored in UserDefaults on the user's machine and entered via **Settings → APIs** (⌘,).

- **Unsplash**: free key at [unsplash.com/developers](https://unsplash.com/developers)
- **Pexels**: free key at [pexels.com/api](https://www.pexels.com/api/)

---

## Build & Run

1. Open `ImageSplitter.xcodeproj` in Xcode
2. Select your Mac as the run destination
3. **⌘R** to build and run

**Requirements**: macOS 13.0+, Xcode 15+, Swift 5.9+

### Sandbox note
If running sandboxed, the app needs **Automation** permission (System Preferences → System Events) to set wallpapers via AppleScript for Mission Control spaces coverage.

---

## Distribution

To distribute outside the App Store (direct download / Gumroad / your own site):

1. Enrol in the **Apple Developer Program** ($99/year) to get a **Developer ID Application** certificate
2. In Xcode: **Product → Archive → Distribute App → Developer ID → Upload** (notarize via Apple's notary service)
3. Export the notarized `.app` and staple the ticket: `xcrun stapler staple ImageSplitter.app`

---

## Reset (test as new user)

```bash
defaults delete com.xaviervitali.ImageSplitter
```
