#!/usr/bin/env bash

configure_mirrors() {
    log "Preparing Arch Linux package mirrors"

    local mirrorlist="/etc/pacman.d/mirrorlist"
    local backup="/etc/pacman.d/mirrorlist.archiso-backup"

    cp -f "$mirrorlist" "$backup"

    if ! command -v reflector >/dev/null 2>&1; then
        log "Installing reflector in the live environment"

        if ! pacman -Sy --noconfirm reflector; then
            warn "Failed to install reflector. Restoring Arch ISO mirrorlist."
            cp -f "$backup" "$mirrorlist"
            pacman -Syy
            return 0
        fi
    fi

    if reflector \
        --country Kazakhstan,Russia,Germany \
        --protocol https \
        --latest 30 \
        --sort rate \
        --save "$mirrorlist"; then
        log "Mirrorlist generated for: Kazakhstan,Russia,Germany"
    else
        warn "Reflector failed. Restoring Arch ISO mirrorlist."
        cp -f "$backup" "$mirrorlist"
    fi

    log "Synchronizing package databases"
    pacman -Syy
}

collect_official_packages() {
    local package_file
    local line

    OFFICIAL_PACKAGES=()

    shopt -s nullglob
    local package_files=("$PROJECT_DIR"/packages/*.txt)
    shopt -u nullglob

    ((${#package_files[@]} > 0)) || die "No package list files found in $PROJECT_DIR/packages"

    for package_file in "${package_files[@]}"; do
        [[ "$(basename "$package_file")" == "10-aur.txt" ]] && continue

        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line%%#*}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"

            [[ -z "$line" ]] && continue
            OFFICIAL_PACKAGES+=("$line")
        done < "$package_file"
    done
}

validate_official_packages() {
    log "Validating official package names"

    collect_official_packages

    local missing=()
    local pkg

    for pkg in "${OFFICIAL_PACKAGES[@]}"; do
        if ! pacman -Si "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if ((${#missing[@]} > 0)); then
        printf 'ERROR: Unknown official package(s): %s\n' "${missing[*]}" >&2
        return 1
    fi
}

install_official_packages() {
    collect_official_packages

    log "Installing official packages into /mnt"
    pacstrap -K /mnt "${OFFICIAL_PACKAGES[@]}"
}