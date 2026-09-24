# Logic Bricks documentation audit — 2026-09-24

Audited the documentation website against the current addon source, brick registry, property definitions, recent 3D/2D/UI QA changes, and menu behavior.

## Corrected in this pass

- Removed the obsolete **UI action category** from the 3D and 2D action documentation. UI actions now live in the dedicated UI documentation.
- Removed the hidden legacy **3D Scale** action from the public 3D menu documentation. The implementation remains hidden for backwards compatibility.
- Corrected **2D Set Camera**, which incorrectly described Camera3D and defaulted to Camera3D in the documentation. It now documents Camera2D and the scene-node picker.
- Updated **Game** action options to include **Unpause** and **Toggle Pause**, plus pause-safe usage guidance.
- Added a **Refresh Waypoints** reminder to the 2D Path Follow documentation.

## Verified current

- 3rd Person Camera setup instructions and continuous-use guidance are present.
- 2D Parent documents Node/Group targeting and Keep Transform.
- 2D Object Shake documents Translate, Rotate, and Scale modes.
- The documentation site validator passes local links, assets, IDs, and CSS checks.

## Follow-up maintenance recommendations

- `addon_inventory.json` contains stale generated metadata in a few places (notably old Game choices and older class naming). It should be regenerated from the current registry before using it as an authoritative source for future documentation generation.
- Several older brick pages still contain generic auto-generated “Typical uses”/“Common mistake” prose. It is valid but less useful than the newer brick-specific guidance. Replace these gradually as bricks receive focused documentation updates.
- Some related-brick links on older generated sections cross domains in ways that are technically valid but not always pedagogically useful. These can be curated over time; they do not describe incorrect runtime behavior.
