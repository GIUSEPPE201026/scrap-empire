# Scrap Empire

A playable single-player first-person scrapyard game made with **Godot 4.3 stable**, GDScript and the Compatibility renderer.

Collect scrap → fill your bag → deposit → sell → upgrade your equipment → start another expedition with saved progression. Explore the desert, dismantle multi-stage salvage, craft useful objects and buy vehicles. The current release includes a scooter, skateboard, utility buggy and dirt bike.

## Play on Windows

Download the [Windows demo ZIP](https://github.com/GIUSEPPE201026/scrap-empire/releases/download/demo-2026-11-08/ScrapEmpire-Windows-x86_64-demo-2026-11-08.zip). Extract the entire ZIP, then run **ScrapEmpire.exe**. Keep **ScrapEmpire.pck** beside the executable. Godot does not need to be installed. Windows x86-64 and an OpenGL 3.3-compatible GPU are required. This is an unsigned prototype.

Choose **ENTRA NELLA DISCARICA / GIOCA** from the main menu. The game opens in a resizable window. Settings include optional fullscreen, audio, mouse sensitivity and key remapping. Progress is stored locally; the download contains no developer save files.

## Controls

| Action | Default control |
|---|---|
| Move / look | WASD / mouse |
| Sprint / jump | Shift / Space |
| Collect / dismantle | Hold left mouse while aiming within 3 m |
| Interact / open a station | E, while aiming at the object |
| Drag loose scrap | Hold right mouse |
| Equipment / journal / map | I / J / M |
| Select tools | 1, 2, 3, 5, 6 |
| Equip or stow selected scooter/skateboard | 4 |
| Intact component recovery mode | R |
| Scanner / light | F / L |
| Pause | Esc |
| Vehicle throttle, brake/reverse, steering | W, S, A/D |
| Buggy handbrake / parking brake | Space / P |
| Vehicle camera / dismount | V / E (buggy and dirt bike) |
| Scooter jump / skateboard ollie / bike hop | Space |
| Placement preview | E or left click confirm; wheel/R rotate; right click/Esc cancel |

## First expedition

1. Pick up nearby metal with the correct tool. Your initial bag holds **20 kg**.
2. At the scale, press **E** and **deposit** your bag. Depositing and selling are separate actions.
3. Sell spare materials. Keep ingredients you need for orders and crafting.
4. Buy equipment upgrades at the office monitor; buy vehicles at the garage; craft at the garage workbench.
5. **J** shows the next objective. **M** sets a waypoint; **Rimuovi meta** clears it.
6. To place a crafted handcart, open **I → Costruzioni**, choose the ready cart, move the green preview and confirm with **E**. Red means the location is blocked or too steep.

The skateboard costs 350 in-game **Bulloni**; the dirt bike costs 2,400 and requires the East Lot. Vehicles are gameplay alternatives: the dirt bike has no cargo bed. Multiplayer code is retained, but multiplayer development/testing is deferred; single player requires no server or account.

## Open the source

Import **ScrapEmpire/project.godot** into **Godot 4.3 stable** and press F6 on `scenes/boot.tscn` or F5 to run the project. The full scenes, scripts, assets and balance data are included, not just screenshots or an export.

Install matching Godot 4.3 export templates, then export the **Windows Desktop** preset. From a shell:

```sh
godot --headless --path ScrapEmpire --editor --import --quit
godot --headless --path ScrapEmpire --export-release "Windows Desktop" ../dist/windows/ScrapEmpire.exe
```

Create `dist/windows` before exporting. Keep the EXE and PCK together. `scenes/review_export_smoke.tscn` is an explicit QA scene; it checks menu, resource loading and world startup using an isolated save folder.

## Status and credits

This is an AI-assisted prototype in active development. Vehicle handling is arcade; art and progression balance are still being improved. The earlier internal revision passed 38 headless suites and 32 graphical suites; the packaged executable has its own export smoke check. These are automated checks, not a promise of compatibility with every PC.

Original game code and procedural art are published for review. Third-party license notices are retained under `ScrapEmpire/third_party`. Godot's MIT license and bundled third-party notices accompany the Windows download. See **THIRD_PARTY_NOTICES.md**. No unrelated itch.io devlog is used as the demo.
