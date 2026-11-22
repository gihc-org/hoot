#!/usr/bin/env bash
#
# Install GNU Guix alongside Debian 13 (Trixie), then verify the daemon.
#
# Run this script as your normal user, not with sudo:
#
#   ./install-guix-trixie.sh
#
# The script uses sudo only for package installation, the official Guix
# installer and systemd operations.

set -Eeuo pipefail
IFS=$'\n\t'

readonly GUIX_INSTALLER_URL='https://git.savannah.gnu.org/cgit/guix.git/plain/etc/guix-install.sh'
readonly MIN_FREE_KIB=$((10 * 1024 * 1024))
readonly COMFORTABLE_FREE_KIB=$((20 * 1024 * 1024))

dry_run=false
verify_only=false
installer_dir=""
reviewed_installer_hash=""

log() {
    printf '[guix-install] %s\n' "$*"
}

warn() {
    printf '[guix-install] ADVARSEL: %s\n' "$*" >&2
}

die() {
    printf '[guix-install] FEJL: %s\n' "$*" >&2
    exit 1
}

on_error() {
    local line_number="$1"
    printf '[guix-install] Kommandoen fejlede på linje %s.\n' \
        "$line_number" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: install-guix-trixie.sh [OPTIONS]

Installerer GNU Guix ved siden af Debian 13 (Trixie).

Options:
  --dry-run   Vis kontroller og planlagte handlinger uden at ændre systemet
  --verify-only
              Kontrollér en eksisterende Guix-installation uden at installere
  -h, --help  Vis denne hjælp

Kør scriptet som din normale bruger. Det spørger selv om sudo-adgang.
EOF
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            --dry-run)
                dry_run=true
                ;;
            --verify-only)
                verify_only=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "Ukendt argument: $1"
                ;;
        esac
        shift
    done
}

require_command() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1 ||
        die "Nødvendigt værktøj mangler: $command_name"
}

available_kib() {
    df -Pk / | awk 'NR == 2 { print $4 }'
}

check_environment() {
    if ((EUID == 0)); then
        die "Kør scriptet som din normale bruger, ikke med sudo eller som root."
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    [[ "${ID:-}" == "debian" ]] ||
        die "Guiden kræver Debian. Fundet ID=${ID:-ukendt}."
    [[ "${VERSION_CODENAME:-}" == "trixie" ]] ||
        die "Guiden kræver Trixie. Fundet VERSION_CODENAME=${VERSION_CODENAME:-ukendt}."

    case "$(uname -m)" in
        x86_64)
            ;;
        *)
            die "Dette script er kun testet på x86_64."
            ;;
    esac

    [[ -d /run/systemd/system ]] ||
        die "Systemet ser ikke ud til at være startet med systemd."

    require_command awk
    require_command apt-get
    require_command curl
    require_command df
    require_command getent
    require_command mktemp
    require_command sha256sum
    require_command sudo
    require_command systemctl

    local free_kib
    free_kib="$(available_kib)"
    [[ "$free_kib" =~ ^[0-9]+$ ]] ||
        die "Kunne ikke aflæse ledig diskplads."

    if ((free_kib < MIN_FREE_KIB)); then
        die "Der kræves mindst 10 GiB ledig plads på /. Fundet $(df -h / | awk 'NR == 2 { print $4 }')."
    elif ((free_kib < COMFORTABLE_FREE_KIB)); then
        warn "Der er under 20 GiB ledigt. Installationen kan fortsætte, men pladsen kan blive stram under builds."
    fi

    log "Debian Trixie på x86_64 registreret."
    log "Ledig plads på /: $(df -h / | awk 'NR == 2 { print $4 }')."
}

print_plan() {
    cat <<'EOF'

Følgende systemændringer vil blive udført:

  1. sudo apt-get update
  2. sudo apt-get install ca-certificates curl wget gnupg xz-utils less
  3. Hente Guix' officielle installer over HTTPS
  4. Vise installerens SHA-256 og lade dig gennemgå den
  5. Køre den officielle installer med sudo efter en eksplicit bekræftelse
  6. Kontrollere guix-daemon og dens unprivilegerede konto

Guix oprettes i /gnu/store og /var/guix. Debian-pakker erstattes ikke.
EOF
}

install_prerequisites() {
    log "Autentificerer sudo. Adgangskoden indtastes kun i din terminal."
    sudo -v

    log "Opdaterer apt-pakkeindex."
    sudo apt-get update

    log "Installerer nødvendige værktøjer."
    sudo env DEBIAN_FRONTEND=noninteractive \
        apt-get install --yes --no-install-recommends \
        ca-certificates curl wget gnupg xz-utils less

    for command_name in curl wget gpg tar xz less; do
        require_command "$command_name"
    done
}

download_installer() {
    local installer_dir="$1"
    local installer="$installer_dir/guix-install.sh"

    log "Henter Guix' officielle installer."
    if ! curl \
        --proto '=https' \
        --tlsv1.2 \
        --fail \
        --silent \
        --show-error \
        --location \
        --output "$installer" \
        "$GUIX_INSTALLER_URL"; then
        die "Download fra $GUIX_INSTALLER_URL fejlede."
    fi

    [[ -s "$installer" ]] ||
        die "Den hentede installer er tom."

    chmod 700 "$installer"
}

review_installer() {
    local installer="$1"
    local installer_hash
    local review_answer
    local confirmation

    installer_hash="$(sha256sum "$installer" | awk '{ print $1 }')"
    reviewed_installer_hash="$installer_hash"

    cat <<EOF

Guix-installeren er gemt her:

  $installer

SHA-256:

  $installer_hash

Installerens binære Guix-download bliver desuden signaturkontrolleret af
det officielle installationsscript. Gennemgå nu scriptet, før det køres.
EOF

    [[ -t 0 ]] ||
        die "En interaktiv terminal er nødvendig for gennemgang og bekræftelse."

    read -r -p "Vis installeren i less? [Y/n] " review_answer
    case "${review_answer:-y}" in
        y|Y|yes|YES)
            less "$installer"
            ;;
        n|N|no|NO)
            warn "Installeren blev ikke vist. Du bør selv gennemgå $installer."
            ;;
        *)
            die "Ugyldigt svar."
            ;;
    esac

    printf '\nSkriv RUN for at køre den nu gennemgåede installer: '
    read -r confirmation
    [[ "$confirmation" == "RUN" ]] ||
        die "Installationen blev afbrudt uden ændringer."
}

run_installer() {
    local installer_dir="$1"
    local installer="$installer_dir/guix-install.sh"
    local current_hash

    current_hash="$(sha256sum "$installer" | awk '{ print $1 }')"
    [[ "$current_hash" == "$reviewed_installer_hash" ]] ||
        die "Installeren er ændret efter gennemgangen. Afbryder."

    log "Kører den officielle Guix-installer."
    (
        cd "$installer_dir"
        sudo ./guix-install.sh
    )
}

verify_installation() {
    local daemon_user
    local builder_count

    log "Kontrollerer guix-daemon."
    if ! systemctl is-active --quiet guix-daemon; then
        log "guix-daemon er ikke aktiv; aktiverer tjenesten."
        sudo systemctl enable --now guix-daemon
    fi
    systemctl is-active --quiet guix-daemon ||
        die "guix-daemon kunne ikke startes. Se: journalctl -u guix-daemon -b"

    [[ -S /var/guix/daemon-socket/socket ]] ||
        die "Guix' daemon-socket blev ikke oprettet."

    guix gc --list-roots >/dev/null ||
        die "Kunne ikke kommunikere med guix-daemon over dens socket."

    if getent passwd guix-daemon >/dev/null; then
        daemon_user="guix-daemon"
        builder_count=0
        log "Guix 1.5-model registreret: daemonen kører som $daemon_user."
    elif getent group guixbuild >/dev/null; then
        daemon_user="guixbuild-legacy"
        builder_count="$(
            getent passwd |
                awk -F: '$1 ~ /^guixbuilder[0-9]+$/ { count++ } END { print count + 0 }'
        )"
        ((builder_count > 0)) ||
            die "Den ældre Guix-model har guixbuild-gruppen, men ingen build-brugere."
        log "Ældre Guix-model registreret med $builder_count build-brugere."
    else
        die "Hverken guix-daemon-brugeren eller den ældre guixbuild-gruppe blev fundet."
    fi

    bash --login -c 'command -v guix >/dev/null' ||
        die "guix blev ikke fundet i en ny login-shell."

    log "Guix-daemon er aktiv."
    log "Daemonen svarer korrekt via /var/guix/daemon-socket/socket."
    bash --login -c 'guix --version'
}

print_next_steps() {
    cat <<'EOF'

Guix er installeret. Guix' første brugeropdatering og Hoot er endnu ikke
hentet.

Kør følgende som din normale bruger:

  exec bash --login
  guix pull
  guix shell --pure guile guile-hoot

Inde i Guix-shellet kan installationen kontrolleres med:

  hoot --version

Se GUIX-TRIXIE-HOOT.md for fejlfinding og den videre opsætning.
EOF
}

cleanup() {
    if [[ -n "$installer_dir" && -d "$installer_dir" ]]; then
        rm -rf -- "$installer_dir"
    fi
}

main() {
    parse_args "$@"
    check_environment

    if [[ "$verify_only" == true ]]; then
        if [[ "$dry_run" == true ]]; then
            log "Dry run: en eksisterende Guix-installation ville blive kontrolleret."
            exit 0
        fi
        verify_installation
        print_next_steps
        exit 0
    fi

    print_plan

    if [[ "$dry_run" == true ]]; then
        log "Dry run afsluttet. Systemet er ikke ændret."
        exit 0
    fi

    install_prerequisites

    installer_dir="$(mktemp -d "${TMPDIR:-/tmp}/install-guix-trixie.XXXXXX")"
    trap cleanup EXIT

    download_installer "$installer_dir"
    review_installer "$installer_dir/guix-install.sh"
    run_installer "$installer_dir"
    verify_installation
    print_next_steps
}

trap 'on_error "$LINENO"' ERR
main "$@"
