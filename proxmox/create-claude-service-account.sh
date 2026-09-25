#!/usr/bin/env bash
set -euo pipefail

DEFAULT_USER="claude"
DEFAULT_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAION5qtmEOAdSaBXdq7+mjLU14fkOd48SFzh2JbSt0QeZ claude@oht-4"

usage() {
cat << EOF
Usage:
  $0 -m check|apply [-u user] [-k "ssh-ed25519 ..."]

Audits or creates a key-only, passwordless-sudo service account for Claude Code
remote administration on a Proxmox (or any Debian-family) node.

Options:
  -m    Mode: 'check' (read-only audit, default-safe) or 'apply' (create/fix)
  -u    Username (default: $DEFAULT_USER)
  -k    SSH public key line to authorize (default: baked-in oht-4 key)
  -h    Show this help

Examples:
  $0 -m check
  $0 -m apply
  $0 -m check -u claude -k "ssh-ed25519 AAAA... claude@somewhere"
EOF
exit 0
}

MODE=""
TARGET_USER="$DEFAULT_USER"
PUBKEY="$DEFAULT_KEY"

while getopts ":m:u:k:h" opt; do
  case "$opt" in
    m) MODE="$OPTARG" ;;
    u) TARGET_USER="$OPTARG" ;;
    k) PUBKEY="$OPTARG" ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

if [[ "$MODE" != "check" && "$MODE" != "apply" ]]; then
  echo "Missing or invalid -m (must be 'check' or 'apply')." >&2
  usage
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "Must be run as root (or via sudo)." >&2
  exit 1
fi

SUDOERS_FILE="/etc/sudoers.d/90-${TARGET_USER}"
SSH_DIR="/home/${TARGET_USER}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"
EXPECTED_SUDOERS="${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"

pass=0
fail=0

report() {
  local ok="$1" msg="$2"
  if [[ "$ok" == "0" ]]; then
    echo "  [OK]   $msg"
    pass=$((pass + 1))
  else
    echo "  [FAIL] $msg"
    fail=$((fail + 1))
  fi
}

echo "=== $(hostname) — mode: $MODE, user: $TARGET_USER ==="

# 1. user exists
if id "$TARGET_USER" >/dev/null 2>&1; then
  report 0 "user '$TARGET_USER' exists"
else
  report 1 "user '$TARGET_USER' does not exist"
  if [[ "$MODE" == "apply" ]]; then
    adduser --disabled-password --gecos "" "$TARGET_USER"
    echo "  [FIX]  created user '$TARGET_USER'"
  fi
fi

# 2. sudo group membership
if id -nG "$TARGET_USER" 2>/dev/null | grep -qw sudo; then
  report 0 "'$TARGET_USER' is in group 'sudo'"
else
  report 1 "'$TARGET_USER' is NOT in group 'sudo'"
  if [[ "$MODE" == "apply" ]]; then
    usermod -aG sudo "$TARGET_USER"
    echo "  [FIX]  added '$TARGET_USER' to sudo group"
  fi
fi

# 3. NOPASSWD sudoers drop-in: correct content + mode 440
if [[ -f "$SUDOERS_FILE" ]] && grep -qF "$EXPECTED_SUDOERS" "$SUDOERS_FILE" 2>/dev/null \
   && [[ "$(stat -c %a "$SUDOERS_FILE" 2>/dev/null)" == "440" ]]; then
  report 0 "sudoers drop-in $SUDOERS_FILE present, NOPASSWD:ALL, mode 440"
else
  report 1 "sudoers drop-in $SUDOERS_FILE missing or incorrect"
  if [[ "$MODE" == "apply" ]]; then
    TMP_SUDOERS="$(mktemp)"
    echo "$EXPECTED_SUDOERS" > "$TMP_SUDOERS"
    if visudo -cf "$TMP_SUDOERS" >/dev/null 2>&1; then
      install -m 440 "$TMP_SUDOERS" "$SUDOERS_FILE"
      echo "  [FIX]  wrote $SUDOERS_FILE"
    else
      echo "  [FIX]  ABORTED: generated sudoers content failed visudo syntax check" >&2
    fi
    rm -f "$TMP_SUDOERS"
  fi
fi

# 4. ~/.ssh ownership/perms — this exact mismatch (root:claude instead of claude:claude)
#    is what made sshd silently refuse authorized_keys on pve1 on 2026-08-28.
if [[ -d "$SSH_DIR" ]]; then
  OWNER="$(stat -c %U:%G "$SSH_DIR")"
  PERM="$(stat -c %a "$SSH_DIR")"
  if [[ "$OWNER" == "${TARGET_USER}:${TARGET_USER}" && "$PERM" == "700" ]]; then
    report 0 "$SSH_DIR owned $OWNER, mode $PERM"
  else
    report 1 "$SSH_DIR owned $OWNER, mode $PERM (expected ${TARGET_USER}:${TARGET_USER}, 700)"
    if [[ "$MODE" == "apply" ]]; then
      chown "${TARGET_USER}:${TARGET_USER}" "$SSH_DIR"
      chmod 700 "$SSH_DIR"
      echo "  [FIX]  corrected ownership/perms on $SSH_DIR"
    fi
  fi
else
  report 1 "$SSH_DIR does not exist"
  if [[ "$MODE" == "apply" ]]; then
    install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$SSH_DIR"
    echo "  [FIX]  created $SSH_DIR"
  fi
fi

# 5. authorized_keys: contains expected key, correct ownership/perms
if [[ -f "$AUTH_KEYS" ]] && grep -qF "$PUBKEY" "$AUTH_KEYS" 2>/dev/null; then
  OWNER="$(stat -c %U:%G "$AUTH_KEYS")"
  PERM="$(stat -c %a "$AUTH_KEYS")"
  if [[ "$OWNER" == "${TARGET_USER}:${TARGET_USER}" && "$PERM" == "600" ]]; then
    report 0 "$AUTH_KEYS contains expected key, owned $OWNER, mode $PERM"
  else
    report 1 "$AUTH_KEYS has expected key but wrong owner/perm ($OWNER, $PERM)"
    if [[ "$MODE" == "apply" ]]; then
      chown "${TARGET_USER}:${TARGET_USER}" "$AUTH_KEYS"
      chmod 600 "$AUTH_KEYS"
      echo "  [FIX]  corrected ownership/perms on $AUTH_KEYS"
    fi
  fi
else
  report 1 "$AUTH_KEYS missing or does not contain expected key"
  if [[ "$MODE" == "apply" ]]; then
    touch "$AUTH_KEYS"
    grep -qF "$PUBKEY" "$AUTH_KEYS" 2>/dev/null || echo "$PUBKEY" >> "$AUTH_KEYS"
    chown "${TARGET_USER}:${TARGET_USER}" "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    echo "  [FIX]  wrote key to $AUTH_KEYS"
  fi
fi

# 6. password login locked (key-only auth intended for a service account)
if passwd -S "$TARGET_USER" 2>/dev/null | awk '{print $2}' | grep -qE '^L$'; then
  report 0 "password login is locked for '$TARGET_USER'"
else
  report 1 "password login is NOT locked for '$TARGET_USER'"
  if [[ "$MODE" == "apply" ]]; then
    passwd -l "$TARGET_USER"
    echo "  [FIX]  locked password login"
  fi
fi

echo
echo "=== Summary: $pass OK, $fail FAIL (as found, before any fixes) ==="
if [[ "$MODE" == "check" && "$fail" -gt 0 ]]; then
  echo "Run with -m apply to fix the above."
fi
