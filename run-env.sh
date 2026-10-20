#!/usr/bin/env bash
# Run a justfile command in the talk's environment.
#   ./run-env.sh "dep1 dep2 ..." 'command'          NixOS: inside the flake's dev shell; elsewhere: host tools
#   ./run-env.sh --host "dep1 dep2 ..." 'command'   always on the host (e.g. running a binary as root)
#   ./run-env.sh "dep1 dep2 ..."                    interactive shell
# On non-NixOS hosts every dep is checked first, and the missing ones are listed
# (no install commands: package names differ between distros; see README.md).
# A dep is a command name, name>=X.Y.Z for a minimum version (read from
# `name --version`), or pc:<name> for a library found through pkg-config.
# Override the detection with RUN_ENV=nix or RUN_ENV=native.
# (Nix on other distros isn't the default: nixpkgs' kitty needs nixGL there.)
set -euo pipefail
cd "$(dirname "$0")"

host=""
[ "${1:-}" = "--host" ] && { host=1; shift; }
deps="$1"; cmd="${2:-}"

mode="${RUN_ENV:-}"
[ -n "$mode" ] || { [ -e /etc/NIXOS ] && mode=nix || mode=native; }
[ -n "$host" ] && mode=host

if [ "$mode" = nix ]; then
  # works even where flakes aren't enabled in nix.conf
  nix=(nix --extra-experimental-features "nix-command flakes")
  [ -n "$cmd" ] || exec "${nix[@]}" develop
  exec "${nix[@]}" develop --command bash -c "$cmd"
fi

version_of() { { "$1" --version 2>/dev/null || "$1" version 2>/dev/null; } | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1; }

version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

describe() {
  case "$1" in
    pc:*)       echo "${1#pc:} development files (headers + pkg-config file), and pkg-config" ;;
    llvm-strip) echo "llvm-strip (part of LLVM)" ;;
    *">="*)     echo "${1%%>=*} version ${1#*>=} or newer" ;;
    *)          echo "$1" ;;
  esac
}

have() {
  case "$1" in
    pc:*) command -v pkg-config >/dev/null && pkg-config --exists "${1#pc:}" ;;
    *">="*)
      local v; command -v "${1%%>=*}" >/dev/null || return 1
      v=$(version_of "${1%%>=*}"); [ -n "$v" ] && version_ge "$v" "${1#*>=}" ;;
    *)    command -v "$1" >/dev/null ;;
  esac
}

missing=()
for d in $deps; do
  have "$d" && continue
  line=$(describe "$d")
  name=${d%%>=*}
  if [ "$name" != "$d" ] && command -v "$name" >/dev/null; then
    line="$line (found $(version_of "$name"))"
  fi
  missing+=("$line")
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "This recipe requires the following, which are not installed:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  echo "Install them with your distro's package manager (or from upstream), then run it again." >&2
  echo "The full list of requirements is in README.md." >&2
  exit 1
fi

export PRESENTERM_CONFIG_FILE="$PWD/talk/presenterm.yaml"
[ -n "$cmd" ] || exec "${SHELL:-bash}"
exec bash -c "$cmd"
