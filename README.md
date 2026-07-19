# MMG Launcher

```
mark@launcher ~/games $ tree ~/games
```

A gruvbox, terminal-styled game launcher for [markmakes.games](https://markmakes.games). One controller-friendly place to browse, play, and give feedback on everything I have shipped, prototyped, or jammed: Steam releases, open source projects, prototypes, game jam entries, and trailers.

## Download

**Grab the launcher at [markmakes.games/mmg-launcher](https://markmakes.games/mmg-launcher)** for Windows and Linux (Steam Deck friendly).

Unzip, run, and browse with a controller or keyboard. Games launch from the `Games/` folder next to the launcher binary, or through Steam for the released titles.

## Features

- **10-foot UI**: browse everything with a controller. D-Pad to move, A for details, B to back out
- **Game details**: terminal-window cards with descriptions, features, release dates, and dev time pulled straight from git history
- **Controls view**: per-game controller layouts drawn on a gruvbox Xbox 360 pad
- **Trailers and prototypes on video**: mp4 playback in the launcher with a fullscreen player, pause, and seek
- **Wishlist QR codes**: point a phone at the screen to wishlist a game on Steam
- **Feedback survey**: when you quit a game, an optional controller-navigable survey (with an on-screen keyboard) stores playtest feedback in a local SQLite database

## Tech

Built with [Godot 4.7](https://godotengine.org) using a custom engine build that adds an mp4 `VideoStream` module (FFmpeg on Linux, Media Foundation on Windows). Feedback storage uses [godot-sqlite](https://github.com/2shady4u/godot-sqlite). Games are plain Godot `Resource` files (`Resources/Games/*.tres`) referenced by a single library resource, so adding a game is a couple of clicks in the Inspector.

## Watch it get built

The launcher, and most of the games inside it, are built live on stream: [twitch.tv/bearlikelion](https://twitch.tv/bearlikelion)
