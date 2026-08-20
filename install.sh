#!/usr/bin/env bash
#
# install.sh — SELF-CONTAINED installer for `tails-bigfont` (works on any Linux).
#
# This single file carries the whole tool embedded inside it. Copy it to any
# machine and run it; no other files are needed.
#
#   ./install.sh           # install command + shell function/alias for you
#   ./install.sh --root    # also add the function/alias to root's shells
#
# It installs the `tails-bigfont` command (to /usr/local/bin when possible, else
# ~/.local/bin) and adds a `tailsfont` shell function + `tailsbig` alias to your
# bash / zsh / fish configs.
#
set -euo pipefail

CMD=tails-bigfont
DO_ROOT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) DO_ROOT=1; shift ;;
    -h|--help) sed -n '2,18{/^#/!q;s/^# \{0,1\}//p}' "$0"; exit 0 ;;
    *) echo "install.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# ---- 1. pick a bin dir + sudo strategy ----
if [ "$(id -u)" = 0 ]; then
  BIN_DIR=/usr/local/bin; SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  BIN_DIR=/usr/local/bin; SUDO="sudo"
else
  BIN_DIR="$HOME/.local/bin"; SUDO=""
fi
BIN="$BIN_DIR/$CMD"
$SUDO mkdir -p "$BIN_DIR"

# ---- 2. write the embedded tool ----
echo "Installing $CMD -> $BIN"
tmptool=$(mktemp)
cat > "$tmptool" <<'TAILS_BIGFONT_EOF'
#!/usr/bin/env bash
#
# tails-bigfont — enlarge the microscopic GRUB boot/kernel-select menu text on a
# Tails USB stick.
#
# The dependable fix is NOT a bigger font (GRUB's gfxterm keeps its embedded
# ~16px "unicode" font as the default regardless of any loadfont), but lowering
# the GRUB graphics resolution: a smaller canvas makes the native font occupy a
# much larger share of the screen. We set a gfxmode fallback list so GRUB picks
# the smallest mode the firmware actually offers (largest text), falling back to
# 'auto' so it can never blank.
#
# Idempotent + reversible. Only touches the unencrypted Tails system partition
# (vfat, label "Tails"); never the LUKS Persistent Storage partition.
#
# Usage:
#   tails-bigfont [-d /dev/sdX1] [-t SECONDS] [--no-unmount]
#   tails-bigfont --revert [-d /dev/sdX1]
#
set -euo pipefail

GFXMODE_LINE='set gfxmode=640x480,800x600,1024x768,auto'
TIMEOUT=15
DEVICE=""
REVERT=0
NO_UNMOUNT=0

die()  { printf 'tails-bigfont: %s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }

usage() {
  sed -n '2,30{/^#/!q;s/^# \{0,1\}//p}' "$0"
  exit "${1:-0}"
}

# ---- args ----
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--device)  DEVICE="${2:-}"; shift 2 ;;
    -t|--timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --revert)     REVERT=1; shift ;;
    --no-unmount) NO_UNMOUNT=1; shift ;;
    -h|--help)    usage 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done
[ "$REVERT" = 1 ] || case "$TIMEOUT" in (''|*[!0-9]*) die "timeout must be an integer" ;; esac

# ---- 1. find the Tails system partition ----
if [ -z "$DEVICE" ]; then
  DEVICE=$(lsblk -rno NAME,LABEL,FSTYPE 2>/dev/null | awk '$2=="Tails" && $3=="vfat"{print "/dev/"$1; exit}')
  [ -n "$DEVICE" ] || die "no vfat partition labelled 'Tails' found — plug in the stick or pass -d /dev/sdX1"
fi
[ -b "$DEVICE" ] || die "$DEVICE is not a block device"
printf 'Tails system partition: %s\n' "$DEVICE"

# ---- 2. mount it (symmetrically: remember how, so we can undo) ----
WE_MOUNTED=0
MOUNT_METHOD=""
MP=$(findmnt -nfo TARGET "$DEVICE" 2>/dev/null || true)
if [ -z "$MP" ]; then
  if command -v udisksctl >/dev/null 2>&1; then
    out=$(udisksctl mount -b "$DEVICE") || die "udisksctl mount failed"
    MP=${out#*' at '}; MP=${MP%.}
    MOUNT_METHOD=udisks
  else
    MP=$(mktemp -d)
    sudo mount "$DEVICE" "$MP" || die "sudo mount failed"
    MOUNT_METHOD=sudo
  fi
  WE_MOUNTED=1
fi
[ -d "$MP" ] || die "could not determine mountpoint"
info "mounted at: $MP"

cleanup() {
  sync || true
  if [ "$WE_MOUNTED" = 1 ] && [ "$NO_UNMOUNT" = 0 ]; then
    case "$MOUNT_METHOD" in
      udisks) udisksctl unmount -b "$DEVICE" >/dev/null 2>&1 || true ;;
      sudo)   sudo umount "$MP" 2>/dev/null || true; rmdir "$MP" 2>/dev/null || true ;;
    esac
    info "unmounted — safe to remove"
  fi
}
trap cleanup EXIT

# ---- 3. locate the GRUB config(s) ----
CFGS=()
for c in "$MP/EFI/debian/grub.cfg" "$MP/EFI/debian/grub/grub.cfg"; do
  [ -f "$c" ] && CFGS+=("$c")
done
if [ "${#CFGS[@]}" -eq 0 ]; then
  while IFS= read -r c; do CFGS+=("$c"); done \
    < <(find "$MP" -maxdepth 4 -name grub.cfg -path '*debian*' 2>/dev/null)
fi
[ "${#CFGS[@]}" -gt 0 ] || die "no Tails GRUB config found under $MP/EFI/debian/"

# Need sudo for writes if the files aren't owned by us (e.g. sudo-mounted vfat).
SUDO=""; [ -w "${CFGS[0]}" ] || SUDO="sudo"

# ---- 4. apply (or revert) ----
if [ "$REVERT" = 1 ]; then
  echo "Reverting..."
  for f in "${CFGS[@]}"; do
    if [ -f "$f.bak" ]; then
      $SUDO cp "$f.bak" "$f"; info "restored $(basename "$(dirname "$f")")/$(basename "$f") from .bak"
    else
      tmp=$(mktemp); grep -v '^set gfxmode=' "$f" > "$tmp"; $SUDO cp "$tmp" "$f"; rm -f "$tmp"
      info "no .bak; removed gfxmode line from $f"
    fi
  done
else
  echo "Applying big-font fix (lower gfxmode + timeout=$TIMEOUT)..."
  for f in "${CFGS[@]}"; do
    $SUDO cp -n "$f" "$f.bak" 2>/dev/null || true   # one-time backup
    tmp=$(mktemp)
    awk -v gfx="$GFXMODE_LINE" -v to="$TIMEOUT" '
      BEGIN { ins=0; tset=0 }
      /fonts\/big\.pf2/      { next }                       # drop any old custom-font line
      /^set gfxmode=/        { next }                       # drop existing gfxmode (re-add cleanly)
      /^[[:space:]]*terminal_output[[:space:]]+gfxterm/ && !ins { print gfx; ins=1 }
      /^set timeout=/        { print "set timeout=" to; tset=1; next }
      /^menuentry / && !ins  { print gfx; ins=1 }           # fallback: no gfxterm anchor
      /^menuentry / && !tset { print "set timeout=" to; tset=1 }
      { print }
      END { if(!ins) print gfx; if(!tset) print "set timeout=" to }
    ' "$f" > "$tmp"
    $SUDO cp "$tmp" "$f"; rm -f "$tmp"
    info "patched: $f"
  done
  # remove any leftover custom font from earlier attempts
  $SUDO rm -f "$MP/EFI/debian/grub/fonts/big.pf2" 2>/dev/null || true
  $SUDO rmdir "$MP/EFI/debian/grub/fonts" 2>/dev/null || true
fi

# ---- 5. show evidence ----
echo "Result:"
for f in "${CFGS[@]}"; do
  printf '  %s\n' "$f"
  grep -nE '^set gfxmode=|^set timeout=|loadfont' "$f" | sed 's/^/      /'
done
echo "Done. Reboot the stick to see the enlarged menu (revert with: tails-bigfont --revert)."
TAILS_BIGFONT_EOF
$SUDO cp "$tmptool" "$BIN"
$SUDO chmod 0755 "$BIN"
rm -f "$tmptool"

# ---- 3. wire up shell function + alias ----
MB="# >>> tails-bigfont >>>"
ME="# <<< tails-bigfont <<<"

sh_block() {
  cat <<EOF
$MB
tailsfont() { command $CMD "\$@"; }   # enlarge Tails GRUB menu font
alias tailsbig='tailsfont'
$ME
EOF
}

# strip any previous block (between markers) from stdin
strip_block() {
  awk -v b="$MB" -v e="$ME" '
    $0==b {skip=1} skip==1 {if($0==e) skip=0; next} {print}'
}

add_block_user() {  # $1 = rc file owned by current user
  local rc="$1"
  [ -e "$rc" ] || command -v "$2" >/dev/null 2>&1 || return 0
  touch "$rc"
  local tmp; tmp=$(mktemp)
  strip_block < "$rc" > "$tmp"
  { cat "$tmp"; printf '\n'; sh_block; } > "$rc"
  rm -f "$tmp"; echo "  updated $rc"
}

add_block_root() {  # $1 = root-owned rc file
  local rc="$1"
  sudo test -e "$rc" || return 0
  local tmp; tmp=$(mktemp)
  sudo cat "$rc" | strip_block > "$tmp"
  { cat "$tmp"; printf '\n'; sh_block; } | sudo tee "$rc" >/dev/null
  rm -f "$tmp"; echo "  updated $rc (root)"
}

echo "Wiring shell function 'tailsfont' + alias 'tailsbig':"
add_block_user "$HOME/.bashrc" bash
add_block_user "$HOME/.zshrc"  zsh

# fish (function files, since fish has no `alias` in rc the same way)
if [ -d "$HOME/.config/fish" ] || command -v fish >/dev/null 2>&1; then
  fdir="$HOME/.config/fish/functions"; mkdir -p "$fdir"
  cat > "$fdir/tailsfont.fish" <<EOF
function tailsfont --description 'Enlarge Tails GRUB boot-menu font'
    command $CMD \$argv
end
EOF
  cat > "$fdir/tailsbig.fish" <<EOF
function tailsbig --description 'alias for tailsfont'
    tailsfont \$argv
end
EOF
  echo "  updated fish functions ($fdir)"
fi

if [ "$DO_ROOT" = 1 ]; then
  add_block_root /root/.bashrc
  add_block_root /root/.zshrc
fi

# ---- 4. PATH sanity + done ----
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) echo "NOTE: $BIN_DIR is not on your PATH — add it or run $BIN directly." ;;
esac

cat <<EOF

Installed.
  command : $BIN
  function: tailsfont   alias: tailsbig
Reload your shell (exec \$SHELL) then run:  tailsfont
It auto-detects the vfat 'Tails' partition; override with: tailsfont -d /dev/sdX1
EOF
