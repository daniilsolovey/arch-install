#!/usr/bin/env bash

clone_or_update_user_repo() {
  local repo=$1
  local destination="$USER_HOME/go/src/github.com/$GITHUB_OWNER/$repo"

  install -d -o "$USERNAME" -g "$USERNAME" "$(dirname "$destination")"
  if [[ -d "$destination/.git" ]]; then
    log "Updating $repo"
    sudo -H -u "$USERNAME" git -C "$destination" pull --ff-only
  else
    log "Cloning $repo"
    sudo -H -u "$USERNAME" git clone "https://github.com/$GITHUB_OWNER/$repo" "$destination"
  fi
}

build_user_go_binary() {
  local repo=$1 output_name=${2:-$1}
  local source="$USER_HOME/go/src/github.com/$GITHUB_OWNER/$repo"

  log "Building $repo -> ~/go/bin/$output_name"
  install -d -o "$USERNAME" -g "$USERNAME" "$USER_HOME/go/bin"
  sudo -H -u "$USERNAME" bash -lc \
    "cd '$source' && GOBIN='$USER_HOME/go/bin' go build -o '$USER_HOME/go/bin/$output_name' ."
}

install_volume_control() {
  local source="$USER_HOME/go/src/github.com/$GITHUB_OWNER/volume-control-go"
  local bin_dir="$USER_HOME/go/bin"
  local scripts_dir="$USER_HOME/Scripts"

  install -d -o "$USERNAME" -g "$USERNAME" "$bin_dir" "$scripts_dir"
  install -m755 -o "$USERNAME" -g "$USERNAME" "$source/decrease-volume" "$bin_dir/decrease-volume"
  install -m755 -o "$USERNAME" -g "$USERNAME" "$source/increase-volume" "$bin_dir/increase-volume"

  cat > "$scripts_dir/volume_control.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  down) exec "$HOME/go/bin/decrease-volume" ;;
  up)   exec "$HOME/go/bin/increase-volume" ;;
  *) printf 'Usage: %s {up|down}\n' "$0" >&2; exit 2 ;;
esac
SCRIPT
  chown "$USERNAME:$USERNAME" "$scripts_dir/volume_control.sh"
  chmod 0755 "$scripts_dir/volume_control.sh"
}

install_user_projects() {
  USERNAME=${USERNAME:-$USERNAME_DEFAULT}
  USER_HOME="/home/$USERNAME"

  require_command git
  require_command go
  require_command sudo
  id "$USERNAME" >/dev/null 2>&1 || die "User does not exist: $USERNAME"

  local status=0 repo
  for repo in "${GO_REPOSITORIES[@]}"; do
    if ! clone_or_update_user_repo "$repo"; then
      warn "Optional repository failed and was skipped: $repo"
      status=1
    fi
  done

  if [[ -d "$USER_HOME/go/src/github.com/$GITHUB_OWNER/volume-control-go/.git" ]]; then
    install_volume_control || { warn "volume-control-go installation failed"; status=1; }
  fi
  if [[ -d "$USER_HOME/go/src/github.com/$GITHUB_OWNER/sensors-info-linux/.git" ]]; then
    build_user_go_binary sensors-info-linux sensors-info-linux || { warn "sensors-info-linux build failed"; status=1; }
  fi
  if [[ -d "$USER_HOME/go/src/github.com/$GITHUB_OWNER/cpu-monitoring/.git" ]]; then
    build_user_go_binary cpu-monitoring cpu-monitoring || { warn "cpu-monitoring build failed"; status=1; }
  fi
  if [[ -d "$USER_HOME/go/src/github.com/$GITHUB_OWNER/low-battery-notify/.git" ]]; then
    build_user_go_binary low-battery-notify low-battery-notify || { warn "low-battery-notify build failed"; status=1; }
  fi

  [[ -d "$USER_HOME/go/src/github.com/$GITHUB_OWNER" ]] && \
    chown -R "$USERNAME:$USERNAME" "$USER_HOME/go/src/github.com/$GITHUB_OWNER"
  ((status == 0)) && log "User repositories installed"
  return "$status"
}
