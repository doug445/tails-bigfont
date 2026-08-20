#!/usr/bin/env bash
# deploy.sh — install tails-bigfont on this machine (command + shell wiring incl. root).
# Source of record: ~/Projects/tails-bigfont/
set -euo pipefail

# Copyright (C) 2026 Will
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.  This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the LICENSE file, or <https://www.gnu.org/licenses/>, for details.

cd "$(dirname "$0")"
exec ./install.sh --root "$@"
