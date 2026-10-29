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

# Copyright (c) 2026 https://github.com/doug445 [spilled-bowline0j@icloud.com]
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

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
# Two levers, so it works on every firmware:
#   1. A large bundled font (DejaVu Sans Mono Bold 32px PF2), selected
#      explicitly via gfxterm_font. This is resolution-independent, so it also
#      works on machines whose GOP only offers the native panel mode (Macs,
#      HiDPI laptops), where lowering gfxmode silently does nothing.
#   2. A lower gfxmode. If GRUB refuses the font (Secure Boot lockdown in the
#      signed Debian GRUB rejects fonts from disk) we fall back to the old
#      640x480,800x600,1024x768,auto list, so the menu is never worse than before.
#
# Idempotent + reversible. Only touches the unencrypted Tails system partition
# (vfat, label "Tails"); never the LUKS Persistent Storage partition.
#
# Usage:
#   tails-bigfont [-d /dev/sdX1] [-t SECONDS] [-s PX] [--no-unmount]
#   tails-bigfont --revert [-d /dev/sdX1]
#   tails-bigfont --version
#
#   -s PX  font pixel size (default 32, bundled). Other sizes need grub-mkfont
#          (or grub2-mkfont) and DejaVu Sans Mono Bold on this machine.
#
set -euo pipefail

# Copyright (c) 2026 https://github.com/doug445 [spilled-bowline0j@icloud.com]
# SPDX-License-Identifier: MIT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

VERSION=2.0.0
FALLBACK_GFXMODE='640x480,800x600,1024x768,auto'   # used only if the font won't load
FONT_GFXMODE='1024x768,auto'                       # with the big font, native is fine too
FONT_REL='EFI/debian/grub/fonts/tailsbig.pf2'
FONT_FAMILY='TailsBig'
FONT_RANGE='0x20-0x7E,0xA0-0xFF,0x2190-0x21FF,0x2500-0x25FF'
BEGIN_MARK='# >>> tails-bigfont >>>'
END_MARK='# <<< tails-bigfont <<<'
TIMEOUT=15
SIZE=32
DEVICE=""
REVERT=0
NO_UNMOUNT=0

die()  { printf 'tails-bigfont: %s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }

usage() {
  sed -n '2,30{/^#/!q;s/^# \{0,1\}//p}' "$0"
  exit "${1:-0}"
}

# The bundled 32px font lives as gzip+base64 after the __TAILSBIG_FONT__ line at
# the end of this file.
emit_font() { sed '1,/^__TAILSBIG_FONT__$/d' "$0" | base64 -d | gunzip; }

# ---- args ----
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--device)  DEVICE="${2:-}"; shift 2 ;;
    -t|--timeout) TIMEOUT="${2:-}"; shift 2 ;;
    -s|--size)    SIZE="${2:-}"; shift 2 ;;
    --revert)     REVERT=1; shift ;;
    --no-unmount) NO_UNMOUNT=1; shift ;;
    -h|--help)    usage 0 ;;
    -V|--version) echo "tails-bigfont $VERSION"; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done
[ "$REVERT" = 1 ] || case "$TIMEOUT" in (''|*[!0-9]*) die "timeout must be an integer" ;; esac
[ "$REVERT" = 1 ] || case "$SIZE" in (''|*[!0-9]*) die "font size must be an integer" ;; esac

# ---- build the font up front (before mounting, so failures leave the stick alone) ----
FONT_TMP=""
if [ "$REVERT" = 0 ]; then
  FONT_TMP=$(mktemp)
  if [ "$SIZE" = 32 ]; then
    emit_font > "$FONT_TMP" 2>/dev/null || true
  else
    MKFONT=$(command -v grub-mkfont || command -v grub2-mkfont || true)
    [ -n "$MKFONT" ] || die "-s $SIZE needs grub-mkfont/grub2-mkfont (the bundled font is 32px)"
    TTF=$(fc-match -f '%{file}' 'DejaVu Sans Mono:bold' 2>/dev/null || true)
    [ -f "$TTF" ] || die "-s $SIZE needs the DejaVu Sans Mono Bold font installed"
    "$MKFONT" -n "$FONT_FAMILY" -s "$SIZE" -r "$FONT_RANGE" -o "$FONT_TMP" "$TTF" \
      || die "grub-mkfont failed"
  fi
  # grub-mkfont names the font "<family> <style> <size>"; read it back rather than guess
  FONT_NAME=$(head -c 128 "$FONT_TMP" | LC_ALL=C grep -aoE "${FONT_FAMILY} [A-Za-z ]+ [0-9]+" | head -n1 || true)
  [ -n "$FONT_NAME" ] || die "bundled font is unreadable (corrupt copy of the tool?)"
fi

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
if [ -n "$MP" ] && findmnt -nfo OPTIONS "$DEVICE" | grep -qE '(^|,)ro(,|$)'; then
  die "$DEVICE is mounted read-only at $MP — unmount it first (udisksctl unmount -b $DEVICE)"
fi
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
  rm -f "$FONT_TMP"
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

# Remove everything we have ever added: the marked block, and the unmarked
# gfxmode / big.pf2 lines left by older versions of this tool. If the block
# recorded Tails' original timeout, put it back.
strip_ours() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { inblk=1; next }
    $0 == e { inblk=0; next }
    inblk   { if (match($0, /^# orig-timeout=[0-9]+$/)) orig=substr($0, 16); next }
    /fonts\/big\.pf2/ { next }
    /^set gfxmode=/   { next }
    { line[++n]=$0 }
    END {
      for (i=1; i<=n; i++) {
        if (orig != "" && line[i] ~ /^set timeout=/) line[i]="set timeout=" orig
        print line[i]
      }
    }
  ' "$1"
}

# ---- 4. apply (or revert) ----
if [ "$REVERT" = 1 ]; then
  echo "Reverting..."
  for f in "${CFGS[@]}"; do
    tmp=$(mktemp); strip_ours "$f" > "$tmp"
    $SUDO cp "$tmp" "$f"; rm -f "$tmp"
    info "removed tails-bigfont edits from $f"
  done
  $SUDO rm -f "$MP/$FONT_REL" "$MP/EFI/debian/grub/fonts/big.pf2" 2>/dev/null || true
  $SUDO rmdir "$MP/EFI/debian/grub/fonts" 2>/dev/null || true
else
  echo "Applying big-font fix (${FONT_NAME}, timeout=$TIMEOUT)..."
  $SUDO mkdir -p "$(dirname "$MP/$FONT_REL")"
  $SUDO cp "$FONT_TMP" "$MP/$FONT_REL"
  $SUDO rm -f "$MP/EFI/debian/grub/fonts/big.pf2" 2>/dev/null || true
  info "font: /$FONT_REL"
  for f in "${CFGS[@]}"; do
    # A pristine config (no edits of ours, e.g. right after a Tails upgrade)
    # becomes the new .bak, so the backup always matches the installed Tails.
    if ! grep -qE "^set gfxmode=|^${BEGIN_MARK}\$|fonts/big\.pf2" "$f"; then
      $SUDO cp "$f" "$f.bak"
    fi
    clean=$(mktemp); strip_ours "$f" > "$clean"
    orig_src=$clean
    # v1 edits carry no record of Tails' own timeout; the .bak still has it
    if ! grep -qx "$BEGIN_MARK" "$f" && grep -qE '^set gfxmode=|fonts/big\.pf2' "$f" && [ -f "$f.bak" ]; then
      orig_src=$f.bak
    fi
    orig_to=$(sed -n 's/^set timeout=\([0-9]*\).*/\1/p' "$orig_src" | head -n1)
    tmp=$(mktemp)
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v font="/$FONT_REL" -v name="$FONT_NAME" \
        -v fgfx="$FONT_GFXMODE" -v gfx="$FALLBACK_GFXMODE" -v to="$TIMEOUT" -v orig="$orig_to" '
      function block() {
        print b
        if (orig != "") print "# orig-timeout=" orig
        print "if loadfont " font "; then"
        print "  set gfxterm_font=\"" name "\""
        print "  set gfxmode=" fgfx
        print "else"
        print "  set gfxmode=" gfx
        print "fi"
        print e
        ins=1
      }
      BEGIN { ins=0; tset=0 }
      /^[[:space:]]*terminal_output[[:space:]]+gfxterm/ && !ins { block() }
      /^set timeout=/        { print "set timeout=" to; tset=1; next }
      /^menuentry / && !ins  { block() }                   # fallback: no gfxterm anchor
      /^menuentry / && !tset { print "set timeout=" to; tset=1 }
      { print }
      END { if(!ins) block(); if(!tset) print "set timeout=" to }
    ' "$clean" > "$tmp"
    $SUDO cp "$tmp" "$f"; rm -f "$tmp" "$clean"
    info "patched: $f"
  done
fi

# ---- 5. show evidence ----
echo "Result:"
for f in "${CFGS[@]}"; do
  printf '  %s\n' "$f"
  grep -nE 'set gfxmode=|gfxterm_font|^set timeout=|loadfont' "$f" | sed 's/^/      /'
done
if [ "$REVERT" = 1 ]; then
  echo "Done. The Tails boot menu is back to stock."
else
  echo "Done. Reboot the stick to see the enlarged menu (revert with: tails-bigfont --revert)."
fi
exit 0

# Bundled font: a subset of DejaVu Sans Mono Bold, renamed TailsBig, converted with
#   grub-mkfont -n TailsBig -s 32 -r "$FONT_RANGE" DejaVuSansMono-Bold.ttf | gzip -9n | base64
# Fonts are (c) 2003 Bitstream, Inc. (Bitstream Vera is a trademark of Bitstream,
# Inc.); DejaVu changes are in the public domain. Distributed under the Bitstream
# Vera Fonts licence: see LICENSE-font-DejaVu in the tails-bigfont repository, or
# https://dejavu-fonts.github.io/License.html
__TAILSBIG_FONT__
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
mXSJ1EiBm6amKEyCv7O2wlmg7f8DnWrEbOKCAAA=
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
  *":$BIN_DIR:") : ;;
  *) echo "NOTE: $BIN_DIR is not on your PATH — add it or run $BIN directly." ;;
esac

cat <<EOF

Installed.
  command : $BIN
  function: tailsfont   alias: tailsbig
Reload your shell (exec \$SHELL) then run:  tailsfont
It auto-detects the vfat 'Tails' partition; override with: tailsfont -d /dev/sdX1
EOF
