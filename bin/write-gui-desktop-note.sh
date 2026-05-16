#!/bin/bash
set -euo pipefail

# Intent: Replace the legacy popup reminder with a deterministic Desktop note so
# GUI users still get clipboard guidance without notifier/autostart complexity.
# Source: DI-004-20260430-182956 (TODO/004)

remote_user="${DECOMK_REMOTE_USER:-}"

if [[ -z "$remote_user" ]]; then
  echo "ERROR: DECOMK_REMOTE_USER must be set by the container/stage-0 environment" >&2
  exit 1
fi

if ! passwd_entry="$(getent passwd "$remote_user")"; then
  echo "ERROR: unable to resolve passwd entry for $remote_user" >&2
  exit 1
fi

IFS=: read -r _passwd_name _passwd_password _passwd_uid _passwd_gid _passwd_gecos user_home _passwd_shell <<<"$passwd_entry"
if [[ -z "$user_home" ]]; then
  echo "ERROR: unable to resolve home directory for $remote_user" >&2
  exit 1
fi

desktop_dir="$user_home/Desktop"
note_path="$desktop_dir/clipboard-help.md"

install -d -o "$remote_user" -g "$remote_user" -m 0755 "$desktop_dir"

cat >"$note_path" <<'EOF'
# noVNC Clipboard Help

* Clipboard integration in browser-based desktops can be inconsistent.
* If paste fails, use the browser's paste controls or your terminal/context-menu paste.
* Plain-text paste is the safest option for commands and code snippets.
EOF

chown "$remote_user:$remote_user" "$note_path"
chmod 0644 "$note_path"

echo "Wrote $note_path"
