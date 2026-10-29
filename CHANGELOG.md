# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [2.0.0] - 2026-10-29

### Fixed
- **Menu text stayed microscopic on many machines** (Macs, HiDPI laptops). v1
  only lowered `gfxmode`, which does nothing when the firmware's GOP offers only
  the native panel mode, because GRUB falls through to `auto`. The tool now
  bundles a 32px font and selects it explicitly with `gfxterm_font`, which
  works at any resolution. Verified in QEMU/OVMF with Tails 7.15.1's own GRUB
  2.12 at a native-only 2560x1600 mode.
- **`--revert` could restore a stale config.** `.bak` was written once and never
  refreshed, so after a Tails upgrade it held the previous release's boot
  entries and kernel command line (e.g. 7.9 on a 7.15.1 stick). Revert now
  removes the tool's own edits in place, and `.bak` is refreshed whenever an
  unmodified config is found.
- `--revert` now restores Tails' original GRUB timeout instead of leaving 15.

### Changed (breaking)
- GRUB config edits are now a marked `# >>> tails-bigfont >>>` block containing
  an `if loadfont …; then … else … fi` fallback, instead of a single bare
  `set gfxmode=` line. The tool also writes `EFI/debian/grub/fonts/tailsbig.pf2`
  to the stick. Configs patched by v1 are migrated automatically on the next run.
- With the font loaded, GRUB uses `gfxmode=1024x768,auto`. The v1 list
  (`640x480,800x600,1024x768,auto`) is now only the fallback when the font
  can't be loaded (e.g. Secure Boot lockdown).

### Added
- `-s PX` / `--size PX`: generate a different font size with
  `grub-mkfont`/`grub2-mkfont` (32px is bundled; no tools needed for it).
- `-V` / `--version`.
- Refuses to run if the Tails partition is already mounted read-only.
- `LICENSE-font-DejaVu` for the bundled font.

## [1.0.1] - 2026-08-20

### Changed
- Licence and copyright notices only; no functional change. (Later relicensed
  from GPL-3.0-or-later to MIT on `main`.)

## [1.0.0] - 2026-08-20

### Added
- First release: enlarge the Tails GRUB menu by lowering the graphics resolution
  (`set gfxmode=640x480,800x600,1024x768,auto`).
- Auto-detects the vfat `Tails` partition; never touches LUKS Persistent Storage.
- Idempotent and reversible (`--revert`, one-time `.bak` per config).
- Configurable GRUB timeout (`-t`, default 15).
- Self-contained `install.sh`: command + `tailsfont` function + `tailsbig` alias
  for bash, zsh and fish (`--root` also wires root's shells).

[2.0.0]: https://github.com/doug445/tails-bigfont/compare/v1.0.1...v2.0.0
[1.0.1]: https://github.com/doug445/tails-bigfont/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/doug445/tails-bigfont/releases/tag/v1.0.0
