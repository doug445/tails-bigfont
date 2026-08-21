# tails-bigfont

Enlarge the microscopic **GRUB boot/kernel-select menu** text on a Tails USB stick.

## Why this works (and the font approach doesn't)

GRUB's `gfxterm` keeps its **embedded ~16px `unicode` font** as the default no
matter what you `loadfont`. So building a bigger PF2 font and loading it does
**nothing** (verified — no visible change). The dependable lever is **graphics
resolution**: a smaller canvas makes the unchanged native font occupy a much
larger share of the screen.

The tool writes this line into Tails' GRUB config, right before
`terminal_output gfxterm`:

```
set gfxmode=640x480,800x600,1024x768,auto
```

GRUB picks the **first mode the firmware's GOP actually offers** (smallest →
biggest text), with `auto` as a safety fallback so it can never blank. It also
sets `set timeout=15`.

Only the unencrypted **Tails** system partition (vfat, label `Tails`) is touched
— never the LUKS Persistent Storage partition. A one-time `.bak` of each config
is kept for easy revert.

## Install (any Linux)

`install.sh` is **self-contained** — it carries the whole tool embedded. Copy
just that one file to any machine and run it:

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
tails-bigfont -d /dev/sdb1   # force a specific partition
tails-bigfont --revert  # restore from .bak (or just remove the gfxmode line)
```

**Auto-discovery:** the tool finds the stick itself via
`lsblk` (matches `LABEL=Tails`, `FSTYPE=vfat`). Override with `-d` only if you
have more than one plugged in.

It mounts with `udisksctl` (no sudo) when available, falls back to `sudo mount`,
and unmounts the same way it mounted. The edit is **idempotent** — re-running
strips any prior `gfxmode`/custom-font lines first, so it's always safe to run
again (e.g. after a Tails auto-upgrade rewrites the boot files). You will need 
to re-run `tailsbig` after any Tails OS system upgrade. Tails always re-writes
GRUB during the upgrade, and `tails-bigfont` is removed from GRUB.

## Files

- `tails-bigfont` — the standalone tool.
- `install.sh` — self-contained installer (embeds an identical copy of the tool).
- `deploy.sh` — separate local one-shot: runs `install.sh --root`.
- `LICENSE` — GNU General Public License v3.

`install.sh` is the canonical portable artifact; the embedded copy is kept
byte-identical to `tails-bigfont` at build time.

## License

MIT License — see [`LICENSE`](LICENSE).

Each script carries the copyright and licence notice in its own header, so the
terms travel with `install.sh` even when it is copied to another machine on its
own, without the rest of the repository.
