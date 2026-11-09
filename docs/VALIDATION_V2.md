# Demo v2 validation

Release target: Windows x86-64, game 0.2.0, Godot 4.3 stable, Compatibility renderer. Tests use isolated save directories. No personal saves or developer currency grants are distributed.

## Release checks

- Fresh import of the allow-listed public source, without an existing `.godot` cache.
- Windows Desktop release export using the installed matching 4.3 templates.
- Actual exported executable tested both headlessly and with the Compatibility renderer: 19 checks per run, zero failures. These check the menu, JSON and language catalogs, model previews, industrial job definitions, trailer configuration, fresh inventory/currency, saving/loading, pause, cleanup and repeat entry.
- ZIP integrity, executable/pack headers and SHA-256 checked before upload; public source paths and anonymous release download verified after publication.

The rendered smoke test uses the Dummy audio driver. Sound output and a complete human playthrough are not covered by these automated checks. A captured rendered frame is inspected separately; rendered tests do not establish how the controls feel.

## Focused development checks

| Area | Result |
| --- | --- |
| Cart coupling, limits, rollback and persistent cargo | 22/22, headless and rendered |
| Garage details, model previews and bounded panels | 7/7 rendered |
| Workshop menu interactions | 121/121 rendered |
| Menu organization | 49/49 headless |
| Crane and loader, including industrial work | 39/39, headless and rendered |
| Forklift terminal, including industrial work | 32/32, headless and rendered |
| Crafting transactions | 50/50 headless |
| Localization | 21/21 headless |

These tests set up fixtures to cover specific behavior. They are not a claim that all nine industrial jobs have been completed manually in a fresh campaign.

## Known limits

Single player is the verified path; retained multiplayer code is experimental and deferred. Vehicle and trailer physics are assisted, terrain does not deform, and the trailer is not a fully simulated rigid-body coupling. The Windows build is unsigned. Other operating systems and GPUs have not been release-tested.
