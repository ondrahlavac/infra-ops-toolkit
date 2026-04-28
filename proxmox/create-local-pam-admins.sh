#!/usr/bin/env bash
set -euo pipefail

usage() {
cat << EOF
Usage:
  $0 -u user1,user2,... -g group -p temporary_password

Creates local Linux/PAM admin users on this Proxmox node.

Options:
  -u    Comma-separated usernames, no spaces
  -g    Admin group name to place the users in
  -p    Temporary password for all created users
  -h    Show this help

Example:
  $0 -u ondra,vojta -g betleministrators -p 'tempPassword'
EOF
exit 0
}

USERS_CSV=""
ADMIN_GROUP=""
TEMP_PASS=""

while getopts ":u:g:p:h" opt; do
  case "${opt}" in
    u) USERS_CSV="$OPTARG" ;;
    g) ADMIN_GROUP="$OPTARG" ;;
    p) TEMP_PASS="$OPTARG" ;;
    h) usage ;;
    \?)
      echo "Invalid option: -$OPTARG"
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      usage
      ;;
  esac
done

if [[ -z "$USERS_CSV" || -z "$ADMIN_GROUP" || -z "$TEMP_PASS" ]]; then
  echo "Missing required parameters."
  usage
fi

IFS=',' read -r -a USERS <<< "$USERS_CSV"

echo "[+] Ensuring group exists..."
getent group "$ADMIN_GROUP" >/dev/null || groupadd "$ADMIN_GROUP"

echo "[+] Configuring sudo rights..."
cat >/etc/sudoers.d/"$ADMIN_GROUP" <<EOF
%$ADMIN_GROUP ALL=(ALL:ALL) ALL
EOF
chmod 0440 /etc/sudoers.d/"$ADMIN_GROUP"

for USER in "${USERS[@]}"; do
    echo "[+] Processing user: $USER"

    if id "$USER" >/dev/null 2>&1; then
        echo "  User exists, skipping creation."
    else
        adduser --disabled-password --gecos "" "$USER"
        echo "$USER:$TEMP_PASS" | chpasswd
        chage -d 0 "$USER"
        echo "  User created, password set, change forced at first login."
    fi

    usermod -aG "$ADMIN_GROUP" "$USER"

    install -d -m 700 -o "$USER" -g "$USER" "/home/$USER/.ssh"
    touch "/home/$USER/.ssh/authorized_keys"
    chown "$USER:$USER" "/home/$USER/.ssh/authorized_keys"
    chmod 600 "/home/$USER/.ssh/authorized_keys"
done

echo
echo "Done."
echo "Users: ${USERS[*]}"
echo "Admin group: $ADMIN_GROUP"