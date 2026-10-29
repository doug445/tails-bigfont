# tails-bigfont

Enlarge the microscopic **GRUB boot/kernel-select menu** text on a Tails USB stick.

Free and open source under the [MIT licence](LICENSE).

## How it works

GRUB's text size on screen depends on two things: the font's pixel size and the
screen resolution GRUB runs at. Tails ships GRUB's default ~16px `unicode` font
at whatever resolution the firmware picks, which on a HiDPI panel is tiny.

`tails-bigfont` uses both levers and writes one clearly marked block into Tails'
GRUB config, right before `terminal_output gfxterm`:

```
# >>> tails-bigfont >>>
# orig-timeout=4
if loadfont /EFI/debian/grub/fonts/tailsbig.pf2; then
  set gfxterm_font="TailsBig Bold 32"
  set gfxmode=1024x768,auto
else
  set gfxmode=640x480,800x600,1024x768,auto
fi
# <<< tails-bigfont <<<
```

1. **A large bundled font.** A 32px DejaVu Sans Mono Bold PF2 is copied to the
   stick and selected **by name** via `gfxterm_font`. That is
   resolution-independent, so it works even where the firmware only offers the
   native panel mode.
2. **A lower resolution as a fallback.** If GRUB refuses the font, it uses the
   v1 behaviour: the smallest mode the firmware offers, with `auto` as a
   safety net so the screen can never blank.

It also sets `set timeout=15` and records Tails' original timeout inside the
block so `--revert` can put it back.

Only the unencrypted **Tails** system partition (vfat, label `Tails`) is touched,
never the LUKS Persistent Storage partition.

### Why v1 worked on some machines but not others

v1 only lowered `gfxmode`. GRUB can only switch to resolutions the firmware's
GOP actually lists. Many PCs list 640x480, so the menu got big. Many Macs and
HiDPI laptops list **only the native mode** (e.g. 2880x1800). There, GRUB fell
straight through to `auto` and the text stayed microscopic. The bundled font
fixes those machines.

### Secure Boot

With Secure Boot **on**, the signed Debian GRUB runs in lockdown mode and
refuses to load fonts from disk. On those machines `tails-bigfont` falls back
to the lower-resolution trick automatically. That is as big as the text can get
there; if the firmware also offers only its native mode, the menu stays small
unless Secure Boot is disabled.

## Install (any Linux)

`install.sh` is **self-contained**: it carries the whole tool, font included.
Copy just that one file to any machine and run it:

```sh
./install.sh          # install command + `tailsfont` function / `tailsbig` alias
./install.sh --root   # also wire root's shells
```

It installs `tails-bigfont` to `/usr/local/bin` (or `~/.local/bin` if it can't),
and adds a `tailsfont` function + `tailsbig` alias to bash, zsh, and fish.

## Use

Plug in the Tails stick and run any of:

```sh
tails-bigfont           # auto-detects the vfat 'Tails' partition
tailsfont               # shell function (same thing)
tailsbig                # alias

tails-bigfont -t 10     # custom GRUB timeout (default 15)
tails-bigfont -s 48     # bigger font (needs grub-mkfont + DejaVu Sans Mono locally)
tails-bigfont -d /dev/sdb1   # force a specific partition
tails-bigfont --revert  # remove all edits and the font, restore Tails' timeout
tails-bigfont --version
```

**Auto-discovery:** the tool finds the stick itself via `lsblk` (matches
`LABEL=Tails`, `FSTYPE=vfat`). Override with `-d` only if you have more than one
plugged in.

**Font size:** 32px is bundled and suits most screens. On a 4K panel where the
firmware offers no lower mode, try `-s 48`; that size gets cramped on machines
that do run at 1024x768.

It mounts with `udisksctl` (no sudo) when available, falls back to `sudo mount`,
and unmounts the same way it mounted. The edit is **idempotent**: re-running
replaces its own block (and cleans up v1's unmarked `gfxmode` line), so it's
always safe to run again.

**Re-run after every Tails upgrade.** Tails rewrites its GRUB config during an
upgrade, which removes the enlarged menu. When the tool finds an unmodified
config, it refreshes the `.bak` copy so the backup always matches the installed
Tails version.

## Upgrading from v1

Just run `tails-bigfont` again. It removes v1's `gfxmode` line, adds the new
block and font, and reads Tails' original timeout from the existing `.bak`.

## Files

- `tails-bigfont`: the standalone tool (the font is embedded at the end of it).
- `install.sh`: self-contained installer (embeds an identical copy of the tool).
- `deploy.sh`: separate local one-shot for root that runs `install.sh --root`.
- `CHANGELOG.md`: release history.
- `LICENSE`: MIT License (scripts).
- `LICENSE-font-DejaVu`: Bitstream Vera / DejaVu licence (bundled font).

`install.sh` is the canonical portable artifact; the embedded copy is kept
byte-identical to `tails-bigfont` at build time.

## License

Scripts: MIT License, see [`LICENSE`](LICENSE). Each script carries the
copyright and licence notice in its own header, so the terms travel with
`install.sh` even when it is copied to another machine on its own.

Bundled font: a renamed subset of DejaVu Sans Mono Bold, (c) Bitstream, Inc.
with public-domain DejaVu changes, under the Bitstream Vera Fonts licence, see
[`LICENSE-font-DejaVu`](LICENSE-font-DejaVu).
