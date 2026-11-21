# Aethergram (`v1.10`)

**Aethergram** is a native Swift 6 / SwiftUI macOS Telegram client featuring macOS 26+ **Liquid Glass** design, Google **Material Design 3** color tokens, live **TDLib 1.8.70** MTProto transport, iMe-style **Bookmarks & Cloud Albums**, custom wallpapers, and full HTML/JSON chat exports.

## Highlights
- **Liquid Glass & Material 3 UI:** 6 dynamic color palettes (`Material Classic`, `Amber Sunrise`, `Emerald Mint`, `Sapphire Indigo`, `Amethyst Berry`, `AMOLED Dark`), tailless asymmetrical bubbles, and vector/custom photo chat wallpapers with real-time blur & dimming.
- **iMe-Inspired Bookmarks & Cloud Albums:** Bookmark messages, photos, videos, and files with 1-click inline video/photo viewing, Jump to Chat, and Telegram Cloud (`Saved Messages`) sync.
- **Live TDLib 1.8.70 Transport:** Multi-page channel/group/forum topic history, automatic media download hydration, 1.5 MB video prefix pre-loading, native `AVPlayerView` video playback, 256 kbps voice notes, and 94% JPEG photo editor.
- **GitHub Releases Update Feed:** **Settings → Advanced → Check for Updates** queries `https://api.github.com/repos/Mr-Process/Aethergram/releases/latest` (and `updates/current.json`) with SHA-256 verification and staging under `tupdates/ready`.

## Building on macOS
```bash
brew install tdlib
swift build
swift run AethergramKitTests
```
