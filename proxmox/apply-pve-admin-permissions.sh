#!/usr/bin/env bash
set -euo pipefail

usage() {
cat << EOF
Usage:
  $0 -u user1,user2,... -g group [-r role] [-p path]

Applies cluster-wide Proxmox VE permissions for PAM users.

Options:
  -u    Comma-separated usernames, without realm
        Example: ondra,vojta

  -g    Proxmox group name
        Example: admins

  -r    Proxmox role
        Default: Administrator

  -p    Proxmox ACL path
        Default: /

  -h    Show this help

Example:
  $0 -u ondra,vojta -g pve-admins

Equivalent to:
  pveum group add pve-admins
  pveum user add ondra@pam
  pveum user modify ondra@pam --groups pve-admins
  pveum acl modify / --groups pve-admins --roles Administrator
EOF
exit 0
}

USERS_CSV=""
GROUP=""
ROLE="Administrator"
ACL_PATH="/"

while getopts ":u:g:r:p:h" opt; do
  case "$opt" in
    u) USERS_CSV="$OPTARG" ;;
    g) GROUP="$OPTARG" ;;
    r) ROLE="$OPTARG" ;;
    p) ACL_PATH="$OPTARG" ;;
    h) usage ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

if [[ -z "$USERS_CSV" || -z "$GROUP" ]]; then
  echo "Missing required parameters." >&2
  usage
fi

IFS=',' read -r -a USERS <<< "$USERS_CSV"

echo "[+] Ensuring Proxmox group exists: $GROUP"
pveum group add "$GROUP" 2>/dev/null || true

for USER in "${USERS[@]}"; do
  USER="$(echo "$USER" | xargs)"

  if [[ -z "$USER" ]]; then
    continue
  fi

  PAM_USER="${USER}@pam"

  echo "[+] Ensuring Proxmox user exists: $PAM_USER"
  pveum user add "$PAM_USER" 2>/dev/null || true

  echo "[+] Adding $PAM_USER to group: $GROUP"
  pveum user modify "$PAM_USER" --groups "$GROUP"
done

echo "[+] Applying ACL:"
echo "    Path:  $ACL_PATH"
echo "    Group: $GROUP"
echo "    Role:  $ROLE"

pveum acl modify "$ACL_PATH" --groups "$GROUP" --roles "$ROLE"

echo
echo "Done."
echo "Users: ${USERS[*]}"
echo "Group: $GROUP"
echo "Role: $ROLE"
echo "ACL path: $ACL_PATH"