#!/usr/bin/env bash

clone_dotfiles() {
  require_command git
  rm -rf "$DOTFILES_CLONE_DIR"

  log "Cloning dotfiles from $DOTFILES_REPO"
  if ! git clone --depth 1 --branch "$DOTFILES_BRANCH" \
      "$DOTFILES_REPO" "$DOTFILES_CLONE_DIR"; then
    warn "Branch '$DOTFILES_BRANCH' was not cloned; trying the repository default branch."
    rm -rf "$DOTFILES_CLONE_DIR"
    git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_CLONE_DIR"
  fi
}

expand_dotfiles_destination() {
  local value=$1
  value=${value//'${USER_HOME}'/$USER_HOME}
  value=${value//'${USERNAME}'/$USERNAME}
  printf '%s\n' "$value"
}

validate_dotfiles_entry() {
  local type=$1 source_rel=$2 destination_template=$3
  local source="$DOTFILES_CLONE_DIR/$source_rel"
  local destination
  destination=$(expand_dotfiles_destination "$destination_template")

  [[ -n "$source_rel" ]] || die "Dotfiles map contains an empty source."
  [[ "$source_rel" != /* ]] || die "Dotfiles source must be repository-relative: $source_rel"
  [[ "$source_rel" != *'..'* ]] || die "Dotfiles source may not contain '..': $source_rel"
  [[ "$destination" == /* ]] || die "Dotfiles destination must be absolute: $destination"

  case "$type" in
    file|config|system)
      [[ -f "$source" ]] || die "Dotfiles file not found: $source_rel"
      ;;
    dir)
      [[ -d "$source" ]] || die "Dotfiles directory not found: $source_rel"
      ;;
    *)
      die "Unknown dotfiles map type '$type' for $source_rel"
      ;;
  esac

  if [[ "$type" == system ]]; then
    [[ "$destination" == /usr/* || "$destination" == /etc/* || "$destination" == /opt/* ]] \
      || die "System dotfile destination is outside allowed system paths: $destination"
  fi
}

validate_dotfiles_map() {
  local map_file=$1
  local type source destination
  local count=0

  log "Validating dotfiles map"
  while IFS='|' read -r type source destination; do
    [[ -z "${type// }" || "$type" == \#* ]] && continue
    [[ -n "${destination:-}" ]] || die "Malformed dotfiles map entry: $type|$source|${destination:-}"
    validate_dotfiles_entry "$type" "$source" "$destination"
    ((count += 1))
  done < "$map_file"

  ((count > 0)) || die "Dotfiles map has no installable entries."
  log "Dotfiles map validated: $count entries"
}

copy_dotfiles_entry() {
  local type=$1 source_rel=$2 destination_template=$3
  local source="$DOTFILES_CLONE_DIR/$source_rel"
  local destination
  destination=$(expand_dotfiles_destination "$destination_template")

  case "$type" in
    file)
      install -Dm755 "$source" "$destination"
      ;;
    config)
      install -Dm644 "$source" "$destination"
      ;;
    system)
      install -Dm755 -o root -g root "$source" "$destination"
      ;;
    dir)
      mkdir -p "$destination"
      cp -a "$source"/. "$destination"/
      ;;
  esac
}

install_dotfiles() {
  local map_file=${1:-"$PROJECT_DIR/dotfiles.map"}
  USERNAME=${USERNAME:-$USERNAME_DEFAULT}
  USER_HOME="/home/$USERNAME"

  [[ -f "$map_file" ]] || die "Dotfiles map not found: $map_file"
  id "$USERNAME" >/dev/null 2>&1 || die "User does not exist: $USERNAME"

  clone_dotfiles
  validate_dotfiles_map "$map_file"
  log "Installing dotfiles for $USERNAME"

  local type source destination
  while IFS='|' read -r type source destination; do
    [[ -z "${type// }" || "$type" == \#* ]] && continue
    copy_dotfiles_entry "$type" "$source" "$destination"
  done < "$map_file"

  # User-owned paths only. Global /usr and /etc files remain owned by root.
  chown -R "$USERNAME:$USERNAME" \
    "$USER_HOME/bin" \
    "$USER_HOME/.screenlayout" \
    "$USER_HOME/go" \
    "$USER_HOME/.xkb" \
    "$USER_HOME/.config/i3" \
    "$USER_HOME/Scripts" 2>/dev/null || true

  find "$USER_HOME/bin" -maxdepth 1 -type f -exec chmod 0755 {} + 2>/dev/null || true
  find "$USER_HOME/Scripts" -type f -exec chmod u+rx {} + 2>/dev/null || true

  [[ -x /usr/bin/xkbcomp ]] || die "/usr/bin/xkbcomp was not installed as an executable."
  log "Dotfiles installed"
}
