#!/bin/bash
# PS5 Payload SDK Installer
# Copyright (C) 2025 earthonion
# Licensed under GPL v3

set -e

SDK_DIR="/opt/ps5-payload-sdk"
SDK_URL="https://github.com/ps5-payload-dev/sdk/releases/latest/download/ps5-payload-sdk.zip"
TEMP_ZIP="/tmp/ps5-payload-sdk.zip"

echo "========================================="
echo "PS5 Payload SDK Installer"
echo "========================================="
echo ""

# Detect OS
detect_os() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/fedora-release ]]; then
        echo "fedora"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo "[*] Detected OS: $OS"
echo ""

# Install dependencies
install_dependencies() {
    echo "[*] Installing dependencies..."

    case "$OS" in
        debian)
            echo "[*] Installing Debian/Ubuntu dependencies..."
            sudo apt-get update
            sudo apt-get install -y bash clang-18 lld-18 wget unzip
            echo "[*] Optionally installing build tools..."
            sudo apt-get install -y socat cmake meson pkg-config || true
            ;;
        fedora)
            echo "[*] Installing Fedora dependencies..."
            sudo dnf install -y bash llvm-devel clang lld wget unzip
            echo "[*] Optionally installing build tools..."
            sudo dnf install -y socat cmake meson pkg-config || true
            ;;
        macos)
            echo "[*] Installing macOS dependencies..."
            if ! command -v brew &> /dev/null; then
                echo "[!] Homebrew not found. Please install from https://brew.sh"
                exit 1
            fi
            brew install llvm@18 wget
            echo "[*] Optionally installing build tools..."
            brew install socat cmake meson || true
            export LLVM_CONFIG=/opt/homebrew/opt/llvm@18/bin/llvm-config
            ;;
        *)
            echo "[!] Unsupported OS. Please install dependencies manually:"
            echo "    - bash, clang-18, lld-18, wget, unzip"
            echo "    - Optional: socat, cmake, meson, pkg-config"
            exit 1
            ;;
    esac

    echo "[✓] Dependencies installed"
    echo ""
}

# Download and install SDK
install_sdk() {
    if [[ -d "$SDK_DIR" ]]; then
        echo "[*] SDK already exists at $SDK_DIR"
        read -p "    Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "[*] Skipping SDK installation"
            return
        fi
        echo "[*] Removing existing SDK..."
        sudo rm -rf "$SDK_DIR"
    fi

    echo "[*] Downloading SDK from latest release..."
    if [[ -f "$TEMP_ZIP" ]]; then
        echo "[*] Using cached SDK zip"
    else
        wget -O "$TEMP_ZIP" "$SDK_URL"
    fi

    echo "[*] Installing SDK to $SDK_DIR..."
    sudo mkdir -p /opt
    sudo unzip -q "$TEMP_ZIP" -d /opt

    echo "[✓] SDK installed to $SDK_DIR"
    echo ""
}

# Add to bashrc
configure_environment() {
    local BASHRC="$HOME/.bashrc"
    local EXPORT_LINE="export PS5_PAYLOAD_SDK=$SDK_DIR"

    echo "[*] Configuring environment variables..."

    # Check if already in bashrc
    if grep -q "PS5_PAYLOAD_SDK" "$BASHRC" 2>/dev/null; then
        echo "[*] PS5_PAYLOAD_SDK already in $BASHRC"
    else
        echo "" >> "$BASHRC"
        echo "# PS5 Payload SDK" >> "$BASHRC"
        echo "$EXPORT_LINE" >> "$BASHRC"
        echo "[✓] Added PS5_PAYLOAD_SDK to $BASHRC"
    fi

    # Export for current session
    export PS5_PAYLOAD_SDK="$SDK_DIR"

    # Optional: Add PS5_HOST and PS5_PORT
    if ! grep -q "PS5_HOST" "$BASHRC" 2>/dev/null; then
        echo "[*] Configure PS5 connection (optional):"
        read -p "    PS5 IP address (default: ps5): " PS5_HOST_INPUT
        read -p "    PS5 Port (default: 9021): " PS5_PORT_INPUT

        PS5_HOST_INPUT=${PS5_HOST_INPUT:-ps5}
        PS5_PORT_INPUT=${PS5_PORT_INPUT:-9021}

        echo "export PS5_HOST=$PS5_HOST_INPUT" >> "$BASHRC"
        echo "export PS5_PORT=$PS5_PORT_INPUT" >> "$BASHRC"
        echo "[✓] Added PS5_HOST and PS5_PORT to $BASHRC"
    fi

    echo ""
}

# Test installation
test_installation() {
    echo "[*] Testing installation..."

    if [[ ! -d "$SDK_DIR" ]]; then
        echo "[!] SDK directory not found at $SDK_DIR"
        exit 1
    fi

    if [[ ! -f "$SDK_DIR/bin/prospero-clang" ]]; then
        echo "[!] SDK appears incomplete (missing prospero-clang)"
        exit 1
    fi

    # Make SDK binaries executable
    echo "[*] Making SDK binaries executable..."
    sudo chmod +x "$SDK_DIR/bin/"* 2>/dev/null || true

    echo "[✓] SDK installation verified"
    echo ""
}

# Main installation flow
main() {
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "[!] Do not run this script as root"
        echo "    It will use sudo when needed"
        exit 1
    fi

    # Check for required commands
    if ! command -v wget &> /dev/null; then
        echo "[*] wget not found, installing dependencies first..."
        install_dependencies
    fi

    install_sdk
    test_installation
    configure_environment

    echo "========================================="
    echo "Installation Complete!"
    echo "========================================="
    echo ""
    echo "SDK installed at: $SDK_DIR"
    echo ""
    echo "To use the SDK:"
    echo "  1. Restart your terminal or run: source ~/.bashrc"
    echo "  2. Build a sample: make -C $SDK_DIR/../samples/hello_world"
    echo "  3. Deploy to PS5: make -C $SDK_DIR/../samples/hello_world test"
    echo ""
    echo "For manual setup, add to your shell profile:"
    echo "  export PS5_PAYLOAD_SDK=$SDK_DIR"
    echo "  export PS5_HOST=<your-ps5-ip>"
    echo "  export PS5_PORT=9021"
    echo ""
}

# Run installation
main
