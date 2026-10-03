#!/usr/bin/env bash
set -Eeuo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# SVM V6 • PREMIUM INSTALLER
# Made by AnkitCoder
# ══════════════════════════════════════════════════════════════════════════════

R='\e[38;5;196m'
O='\e[38;5;208m'
Y='\e[38;5;226m'
G='\e[38;5;46m'
B='\e[38;5;33m'
P='\e[38;5;129m'
C='\e[38;5;51m'
W='\e[97m'
RESET='\e[0m'

APP_NAME="SVM Panel"
VERSION="V6"
AUTHOR="AnkitCoder"
PORT="3000"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIP_FILE="${SCRIPT_DIR}/Svm-v6.zip"
INSTALL_DIR="/opt/svm-v6"
SERVICE_NAME="svm-panel"

show_header() {
    clear
    echo -e "${R}################################################################################${RESET}"
    echo -e "${O}   ███████╗██╗   ██╗███╗   ███╗    ██╗   ██╗ ██████╗${RESET}"
    echo -e "${Y}   ██╔════╝██║   ██║████╗ ████║    ██║   ██║██╔════╝${RESET}"
    echo -e "${G}   ███████╗██║   ██║██╔████╔██║    ██║   ██║██║${RESET}"
    echo -e "${B}   ╚════██║╚██╗ ██╔╝██║╚██╔╝██║    ╚██╗ ██╔╝██║${RESET}"
    echo -e "${P}   ███████║ ╚████╔╝ ██║ ╚═╝ ██║     ╚████╔╝ ╚██████╗${RESET}"
    echo -e "${C}   ╚══════╝  ╚═══╝  ╚═╝     ╚═╝      ╚═══╝   ╚═════╝${RESET}"
    echo -e "${R}################################################################################${RESET}"
    echo -e "${P}          SVM PANEL ${VERSION} • PREMIUM EDITION • MADE BY ${AUTHOR}${RESET}"
    echo -e "${R}################################################################################${RESET}"
    echo
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${Y}[!] Please run as root:${RESET}"
        echo -e "${C}sudo bash install.sh${RESET}"
        exit 1
    fi
}

check_license() {
    while true; do
        show_header

        echo -e "${Y}        [!] AUTHENTICATION REQUIRED [!]${RESET}"
        echo
        read -r -p "        Enter License Key: " KEY

        if [[ "$KEY" == 'AnkitDev99$@' ]]; then
            echo
            echo -e "${G}        [✔] License Verified! Access Granted.${RESET}"
            sleep 1
            menu
            return
        fi

        echo
        echo -e "${R}        [✖] Invalid License Key!${RESET}"
        sleep 2
    done
}

check_zip() {
    if [[ ! -f "$ZIP_FILE" ]]; then
        echo -e "${R}[✖] Svm-v6.zip was not found.${RESET}"
        echo
        echo -e "${Y}Expected location:${RESET}"
        echo -e "${C}${ZIP_FILE}${RESET}"
        echo
        echo -e "${Y}Place Svm-v6.zip beside install.sh and run again.${RESET}"
        exit 1
    fi
}

prepare_system() {
    echo -e "${C}--> [1/6] Updating package index...${RESET}"
    apt-get update -y

    echo -e "${C}--> [2/6] Installing required packages...${RESET}"
    apt-get install -y \
        unzip \
        curl \
        wget \
        ca-certificates \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        snapd

    echo -e "${G}[✔] Core packages installed.${RESET}"
}

install_lxd() {
    echo -e "${C}--> [3/6] Preparing LXD...${RESET}"

    if ! command -v lxc >/dev/null 2>&1; then
        snap install lxd
    else
        echo -e "${G}[✔] LXD/LXC already available.${RESET}"
    fi

    if getent group lxd >/dev/null 2>&1; then
        # Add the invoking user when available.
        REAL_USER="${SUDO_USER:-root}"

        if [[ "$REAL_USER" != "root" ]]; then
            usermod -aG lxd "$REAL_USER" || true
        fi
    fi

    if command -v lxd >/dev/null 2>&1; then
        lxd init --auto >/dev/null 2>&1 || true
    fi
}

extract_panel() {
    echo -e "${C}--> [4/6] Installing SVM Panel ${VERSION}...${RESET}"

    mkdir -p "$INSTALL_DIR"

    # Backup previous installation if present.
    if [[ -d "${INSTALL_DIR}/app" ]]; then
        BACKUP="/opt/svm-v6-backup-$(date +%Y%m%d-%H%M%S)"
        echo -e "${Y}[!] Existing installation detected.${RESET}"
        echo -e "${Y}[!] Creating backup: ${BACKUP}${RESET}"
        cp -a "${INSTALL_DIR}/app" "$BACKUP"
    fi

    rm -rf "${INSTALL_DIR}/app"
    mkdir -p "${INSTALL_DIR}/app"

    unzip -o "$ZIP_FILE" -d "${INSTALL_DIR}/app" >/dev/null

    # Handle ZIPs containing a single top-level directory.
    shopt -s nullglob
    entries=("${INSTALL_DIR}/app"/*)

    if [[ ${#entries[@]} -eq 1 && -d "${entries[0]}" ]]; then
        TMP_DIR="${INSTALL_DIR}/tmp-extract"
        rm -rf "$TMP_DIR"
        mkdir -p "$TMP_DIR"

        cp -a "${entries[0]}"/. "$TMP_DIR"/
        rm -rf "${INSTALL_DIR}/app"
        mv "$TMP_DIR" "${INSTALL_DIR}/app"
    fi

    chmod -R u+rwX,go+rX "${INSTALL_DIR}/app"

    echo -e "${G}[✔] Svm-v6.zip extracted successfully.${RESET}"
}

prepare_python() {
    echo -e "${C}--> [5/6] Preparing Python environment...${RESET}"

    cd "${INSTALL_DIR}/app"

    if [[ ! -d venv ]]; then
        python3 -m venv venv
    fi

    source venv/bin/activate

    python -m pip install --upgrade pip setuptools wheel

    if [[ -f requirements.txt ]]; then
        echo -e "${C}[+] Installing requirements.txt...${RESET}"
        pip install -r requirements.txt
    else
        echo -e "${Y}[!] requirements.txt not found; continuing.${RESET}"
    fi

    deactivate
}

detect_entrypoint() {
    cd "${INSTALL_DIR}/app"

    if [[ -f "Svm.py" ]]; then
        echo "Svm.py"
        return
    fi

    if [[ -f "svm.py" ]]; then
        echo "svm.py"
        return
    fi

    if [[ -f "app.py" ]]; then
        echo "app.py"
        return
    fi

    if [[ -f "main.py" ]]; then
        echo "main.py"
        return
    fi

    echo ""
}

create_service() {
    echo -e "${C}--> [6/6] Creating systemd service...${RESET}"

    ENTRYPOINT="$(detect_entrypoint)"

    if [[ -z "$ENTRYPOINT" ]]; then
        echo -e "${R}[✖] No Python entrypoint found.${RESET}"
        echo -e "${Y}Expected one of: Svm.py, svm.py, app.py, main.py${RESET}"
        exit 1
    fi

    cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=SVM Panel V6 - ${AUTHOR}
Documentation=file://${INSTALL_DIR}/app/README.md
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}/app
ExecStart=${INSTALL_DIR}/app/venv/bin/python3 ${INSTALL_DIR}/app/${ENTRYPOINT} --port ${PORT}
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1
Environment=SVM_VERSION=${VERSION}
Environment=SVM_AUTHOR=${AUTHOR}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"

    systemctl restart "$SERVICE_NAME"

    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        STATUS="RUNNING"
    else
        STATUS="FAILED"
    fi
}

create_readme() {
    if [[ -f "${INSTALL_DIR}/app/README.md" ]]; then
        return
    fi

    cat > "${INSTALL_DIR}/app/README.md" <<'EOF'
# 🚀 SVM Panel V6

**SVM Panel V6** is a VPS management panel deployment package.

> **Made by AnkitCoder**

## ✨ Version

`V6 Premium Edition`

## 📦 Installation

Run:

```bash
sudo bash install.sh
