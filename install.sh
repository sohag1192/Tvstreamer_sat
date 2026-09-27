#!/usr/bin/env bash
# ==============================================================================
# TVStreammerSAT5 - All-in-One Ubuntu / Debian Installer
# ==============================================================================
# Builds and installs TVStreammerSAT5, dependencies, web assets, and systemd service.
#
# Usage:
#   sudo bash install.sh [options]
#
# Options:
#   --install-dir DIR   Target installation directory (default: /opt/TVStreammerSAT5)
#   --no-start          Build and install, but do not start/enable systemd service
#   --skip-deps         Skip installing apt packages (if already installed)
#   --skip-build        Skip compilation (use existing build/TVStreammerSAT5 binary)
#   --with-oscam        Also build and install vendored OSCam-mini
#   -y, --yes           Non-interactive mode (assume Yes to all prompts)
#   -h, --help          Show help message
# ==============================================================================

set -Eeuo pipefail

# --- Color formatting helpers ---
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    ncolors=$(tput colors 2>/dev/null || echo 0)
    if [[ "$ncolors" -ge 8 ]]; then
        C_RESET="$(tput sgr0)"
        C_BOLD="$(tput bold)"
        C_GREEN="$(tput setaf 2)"
        C_BLUE="$(tput setaf 4)"
        C_CYAN="$(tput setaf 6)"
        C_YELLOW="$(tput setaf 3)"
        C_RED="$(tput setaf 1)"
    else
        C_RESET="" C_BOLD="" C_GREEN="" C_BLUE="" C_CYAN="" C_YELLOW="" C_RED=""
    fi
else
    C_RESET="" C_BOLD="" C_GREEN="" C_BLUE="" C_CYAN="" C_YELLOW="" C_RED=""
fi

log_info()    { echo -e "${C_BLUE}${C_BOLD}[INFO]${C_RESET} $*"; }
log_success() { echo -e "${C_GREEN}${C_BOLD}[SUCCESS]${C_RESET} $*"; }
log_warn()    { echo -e "${C_YELLOW}${C_BOLD}[WARNING]${C_RESET} $*"; }
log_error()   { echo -e "${C_RED}${C_BOLD}[ERROR]${C_RESET} $*" >&2; }

# --- Defaults ---
APP_NAME="TVStreammerSAT5"
SERVICE_NAME="tvstreammersat5.service"
DEFAULT_INSTALL_DIR="/opt/TVStreammerSAT5"
INSTALL_DIR="${TVS_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BUILD_DIR="${SCRIPT_DIR}/build"

AUTO_YES=0
NO_START=0
SKIP_DEPS=0
SKIP_BUILD=0
WITH_OSCAM=0

usage() {
    cat <<EOF
${C_BOLD}TVStreammerSAT5 - Automatic Ubuntu / Debian Installer${C_RESET}

${C_CYAN}Usage:${C_RESET}
  sudo bash install.sh [options]

${C_CYAN}Options:${C_RESET}
  --install-dir DIR   Target directory for TVStreammerSAT5 (default: ${DEFAULT_INSTALL_DIR})
  --no-start          Do not start or enable systemd service after installation
  --skip-deps         Skip installing apt packages
  --skip-build        Skip compilation and deploy existing build/TVStreammerSAT5
  --with-oscam        Build and install vendored OSCam-mini card reader module
  -y, --yes           Automatically answer Yes to all confirmation prompts
  -h, --help          Show this help message and exit

${C_CYAN}Example:${C_RESET}
  sudo bash install.sh
  sudo bash install.sh --with-oscam -y
EOF
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-dir)
            [[ $# -ge 2 ]] || { log_error "--install-dir requires an argument"; exit 1; }
            INSTALL_DIR="$2"
            shift 2
            ;;
        --no-start)
            NO_START=1
            shift
            ;;
        --skip-deps)
            SKIP_DEPS=1
            shift
            ;;
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --with-oscam)
            WITH_OSCAM=1
            shift
            ;;
        -y|--yes)
            AUTO_YES=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# --- Root Check ---
if [[ "${EUID}" -ne 0 ]]; then
    log_error "This script must be run as root or with sudo:"
    echo "  sudo bash install.sh"
    exit 1
fi

echo -e "${C_CYAN}${C_BOLD}"
cat << "BANNER"
  _____ __     __ _____  _                                            
 |_   _|\ \   / // ____|| |                                           
   | |   \ \_/ /| (___  | |_  _ __  ___   __ _  _ __ ___   ___  _ __  
   | |    \   /  \___ \ | __|| '__|/ _ \ / _` || '_ ` _ \ / _ \| '__|
  _| |_    | |   ____) || |_ | |  |  __/| (_| || | | | | ||  __/| |   
 |_____|   |_|  |_____/  \__||_|   \___| \__,_||_| |_| |_| \___||_|   
                      SAT5 Streaming Server                           
BANNER
echo -e "${C_RESET}"
log_info "Starting TVStreammerSAT5 installation on Ubuntu / Debian..."
log_info "Target Directory: ${INSTALL_DIR}"
log_info "Source Directory: ${SCRIPT_DIR}"

# --- OS and Distribution Check ---
if [[ ! -f /etc/os-release ]]; then
    log_warn "Could not read /etc/os-release. Proceeding, but apt is required."
else
    . /etc/os-release
    log_info "Detected OS: ${PRETTY_NAME:-Linux} (${ID:-unknown} ${VERSION_ID:-unknown})"
    if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" && "${ID_LIKE:-}" != *"ubuntu"* && "${ID_LIKE:-}" != *"debian"* ]]; then
        log_warn "This installer is optimized for Ubuntu and Debian systems."
        if (( ! AUTO_YES )); then
            read -r -p "Continue anyway? [y/N]: " confirm
            [[ "$confirm" =~ ^[yYдД] ]] || { log_error "Installation cancelled."; exit 1; }
        fi
    fi
fi

# ==============================================================================
# 1. Install System Dependencies
# ==============================================================================
if (( ! SKIP_DEPS )); then
    log_info "Step 1/6: Installing required build and runtime dependencies via apt..."

    BOOST_PKG="libboost-dev"
    if apt-cache show libboost-system-dev >/dev/null 2>&1; then
        BOOST_PKG="libboost-system-dev"
    fi

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y

    DEPENDENCY_PACKAGES=(
        build-essential
        cmake
        pkg-config
        curl
        ca-certificates
        libpcsclite-dev
        pcscd
        pcsc-tools
        libccid
        libcurl4-openssl-dev
        libjsoncpp-dev
        libssl-dev
        libcrypt-dev
        libdvbcsa-dev
        "${BOOST_PKG}"
        libboost-thread-dev
        libgstreamer1.0-dev
        libgstreamer-plugins-base1.0-dev
        libgstreamer-plugins-bad1.0-dev
        gstreamer1.0-tools
        gstreamer1.0-plugins-base
        gstreamer1.0-plugins-good
        gstreamer1.0-plugins-bad
        gstreamer1.0-plugins-ugly
        gstreamer1.0-libav
        gstreamer1.0-rtsp
        gstreamer1.0-vaapi
        vainfo
        intel-media-va-driver
    )

    apt-get install -y --no-install-recommends "${DEPENDENCY_PACKAGES[@]}"
    log_success "Dependencies successfully installed."
else
    log_info "Step 1/6: Skipping dependency installation (--skip-deps)."
fi

# ==============================================================================
# 2. Tune Network Buffers (Sysctl)
# ==============================================================================
log_info "Step 2/6: Configuring high-bitrate UDP network socket buffers..."
SYSCTL_CONF="/etc/sysctl.d/99-tvstreammer-udp.conf"
if [[ -f "${SCRIPT_DIR}/packaging/sysctl/99-tvstreammer-udp.conf" ]]; then
    install -m 0644 "${SCRIPT_DIR}/packaging/sysctl/99-tvstreammer-udp.conf" "${SYSCTL_CONF}"
else
    cat > "${SYSCTL_CONF}" << 'EOF'
# TVStreammerSAT5 high-bitrate UDP/multicast ingest socket buffer tuning
net.core.rmem_default=4194304
net.core.rmem_max=33554432
net.core.netdev_max_backlog=10000
EOF
fi

if command -v sysctl >/dev/null 2>&1; then
    sysctl -p "${SYSCTL_CONF}" >/dev/null 2>&1 || true
fi
log_success "Network socket buffers configured (${SYSCTL_CONF})."

# ==============================================================================
# 3. Ensure Web Preview Player Assets
# ==============================================================================
log_info "Step 3/6: Verifying web player preview assets (hls.js & mpegts.js)..."
mkdir -p "${SCRIPT_DIR}/web/vendor" "${SCRIPT_DIR}/web/preview"

HLS_FILE="${SCRIPT_DIR}/web/vendor/hls.min.js"
MPEGTS_FILE="${SCRIPT_DIR}/web/vendor/mpegts.min.js"

if [[ ! -s "$HLS_FILE" || ! -s "$MPEGTS_FILE" ]]; then
    log_info "Downloading browser streaming libraries into web/vendor..."
    if [[ -x "${SCRIPT_DIR}/scripts/vendor_preview_libs.sh" ]]; then
        bash "${SCRIPT_DIR}/scripts/vendor_preview_libs.sh"
    else
        curl -fLsS --retry 3 --connect-timeout 10 'https://cdn.jsdelivr.net/npm/hls.js@1.6.15/dist/hls.min.js' -o "$HLS_FILE" || true
        curl -fLsS --retry 3 --connect-timeout 10 'https://cdn.jsdelivr.net/npm/mpegts.js@1.7.3/dist/mpegts.js' -o "$MPEGTS_FILE" || true
    fi
fi

if [[ -s "$MPEGTS_FILE" ]]; then
    log_success "Web preview player libraries verified."
else
    log_warn "mpegts.min.js is missing or empty; HTTP live preview might be limited in browser."
fi

# ==============================================================================
# 4. Compile TVStreammerSAT5 with CMake
# ==============================================================================
if (( ! SKIP_BUILD )); then
    log_info "Step 4/6: Building TVStreammerSAT5 with CMake..."
    CPU_CORES=$(nproc 2>/dev/null || echo 2)
    log_info "Building with ${CPU_CORES} parallel jobs..."

    CMAKE_OPTIONS=(
        -S "${SCRIPT_DIR}"
        -B "${BUILD_DIR}"
        -DCMAKE_BUILD_TYPE=Release
    )

    if (( WITH_OSCAM )); then
        CMAKE_OPTIONS+=("-DTVSTREAMMERSAT5_BUILD_OSCAM_MINI=ON")
    else
        # Disable OSCam compilation if third_party source is absent or not requested
        if [[ ! -f "${SCRIPT_DIR}/third_party/oscam-mini/CMakeLists.txt" ]]; then
            CMAKE_OPTIONS+=("-DTVSTREAMMERSAT5_BUILD_OSCAM_MINI=OFF")
        fi
    fi

    cmake "${CMAKE_OPTIONS[@]}"
    cmake --build "${BUILD_DIR}" --parallel "${CPU_CORES}"

    BINARY_PATH="${BUILD_DIR}/${APP_NAME}"
    [[ -x "$BINARY_PATH" ]] || { log_error "Build failed: binary $BINARY_PATH was not produced."; exit 1; }
    log_success "Build completed successfully."
else
    log_info "Step 4/6: Skipping compilation (--skip-build)."
    BINARY_PATH="${BUILD_DIR}/${APP_NAME}"
    if [[ ! -x "$BINARY_PATH" && -x "${SCRIPT_DIR}/${APP_NAME}" ]]; then
        BINARY_PATH="${SCRIPT_DIR}/${APP_NAME}"
    fi
    [[ -x "$BINARY_PATH" ]] || { log_error "No executable binary found at $BINARY_PATH"; exit 1; }
fi

# ==============================================================================
# 5. Deploy Files to Target Directory
# ==============================================================================
log_info "Step 5/6: Deploying files to ${INSTALL_DIR}..."

# Gracefully stop running service during binary replacement
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        log_info "Stopping active ${SERVICE_NAME} for deployment..."
        systemctl stop "${SERVICE_NAME}" || true
    fi
fi

mkdir -p "${INSTALL_DIR}" "${INSTALL_DIR}/ca-plugins" "${INSTALL_DIR}/web"

# Copy main binary
install -m 0755 "${BINARY_PATH}" "${INSTALL_DIR}/${APP_NAME}"

# Copy CA Newcamd backend plugin if compiled
if [[ -f "${BUILD_DIR}/tvstreammersat5-ca-newcamd.so" ]]; then
    install -m 0644 "${BUILD_DIR}/tvstreammersat5-ca-newcamd.so" "${INSTALL_DIR}/ca-plugins/tvstreammersat5-ca-newcamd.so"
elif [[ -f "${SCRIPT_DIR}/ca-plugins/tvstreammersat5-ca-newcamd.so" ]]; then
    install -m 0644 "${SCRIPT_DIR}/ca-plugins/tvstreammersat5-ca-newcamd.so" "${INSTALL_DIR}/ca-plugins/tvstreammersat5-ca-newcamd.so"
fi

# Copy web files
cp -r "${SCRIPT_DIR}/web/." "${INSTALL_DIR}/web/"

# Deploy OSCam-mini if available
if [[ -f "${BUILD_DIR}/oscam-mini/oscam-mini" ]]; then
    mkdir -p "${INSTALL_DIR}/oscam-mini/config"
    install -m 0755 "${BUILD_DIR}/oscam-mini/oscam-mini" "${INSTALL_DIR}/oscam-mini/oscam-mini"
    if [[ -d "${SCRIPT_DIR}/packaging/oscam-mini/default-config" ]]; then
        cp -rn "${SCRIPT_DIR}/packaging/oscam-mini/default-config/." "${INSTALL_DIR}/oscam-mini/config/" 2>/dev/null || true
    fi
fi

# Ensure correct file permissions
chmod -R u=rwX,go=rX "${INSTALL_DIR}/web" 2>/dev/null || true

log_success "Files successfully deployed to ${INSTALL_DIR}."

# ==============================================================================
# 6. Configure systemd Service
# ==============================================================================
log_info "Step 6/6: Configuring systemd service..."

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=TVStreammerSAT5 DVB Streaming & Transcoding Service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/${APP_NAME}
Restart=on-failure
RestartSec=3
TimeoutStopSec=35
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "${SERVICE_FILE}"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}" >/dev/null

if (( ! NO_START )); then
    log_info "Starting ${SERVICE_NAME}..."
    systemctl restart "${SERVICE_NAME}"
    sleep 2

    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        log_success "Service ${SERVICE_NAME} is active and running!"
    else
        log_warn "Service was started, but status is not active. Check: journalctl -u ${SERVICE_NAME} -e"
    fi
else
    log_info "Service registered and enabled, but not started (--no-start)."
fi

# ==============================================================================
# Installation Complete Summary
# ==============================================================================
PRIMARY_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[[ -n "$PRIMARY_IP" ]] || PRIMARY_IP="127.0.0.1"

echo
echo -e "${C_GREEN}${C_BOLD}======================================================================${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}           TVStreammerSAT5 Installation Completed Successfully!       ${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}======================================================================${C_RESET}"
echo
echo -e "  ${C_BOLD}Installation path :${C_RESET} ${INSTALL_DIR}"
echo -e "  ${C_BOLD}Systemd service   :${C_RESET} ${SERVICE_NAME}"
echo -e "  ${C_BOLD}Default web port  :${C_RESET} 9000"
echo
echo -e "  ${C_BOLD}Web Control Panel :${C_RESET} ${C_CYAN}http://${PRIMARY_IP}:9000/${C_RESET}"
echo -e "  ${C_BOLD}Localhost URL     :${C_RESET} ${C_CYAN}http://localhost:9000/${C_RESET}"
echo
echo -e "  ${C_BOLD}Default Login     :${C_RESET} admin"
echo -e "  ${C_BOLD}Default Password  :${C_RESET} admin  ${C_YELLOW}(Please change after first login!)${C_RESET}"
echo
echo -e "${C_BOLD}Useful Service Commands:${C_RESET}"
echo -e "  Check status  : ${C_CYAN}sudo systemctl status ${SERVICE_NAME}${C_RESET}"
echo -e "  Restart service: ${C_CYAN}sudo systemctl restart ${SERVICE_NAME}${C_RESET}"
echo -e "  Stop service  : ${C_CYAN}sudo systemctl stop ${SERVICE_NAME}${C_RESET}"
echo -e "  View live logs: ${C_CYAN}sudo journalctl -u ${SERVICE_NAME} -f${C_RESET}"
echo -e "  Uninstall     : ${C_CYAN}sudo bash ${SCRIPT_DIR}/uninstall_tvstreammersat5.sh${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}======================================================================${C_RESET}"
echo
