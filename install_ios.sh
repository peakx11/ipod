#!/data/data/com.termux/files/usr/bin/bash
#######################################################
#  📱 iOS EMULATOR LAB - QEMU-iOS Installer
#  
#  Features:
#  - Auto-compilation of devos50/qemu-ios (ipod_touch_2g branch)
#  - Auto-downloads requested BootROM, NOR, and NAND images
#  - Native Termux toolchain setup with OpenSSL
#  - Termux-X11 + Openbox integration
#  - One-click emulator launch script
#######################################################

# ============== CONFIGURATION ==============
TOTAL_STEPS=9
CURRENT_STEP=0

# ============== COLORS ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# ============== PROGRESS FUNCTIONS ==============
# Update overall progress
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    
    # Create progress bar
    FILLED=$((PERCENT / 5))
    EMPTY=$((20 - FILLED))
    
    BAR="${GREEN}"
    for ((i=0; i<FILLED; i++)); do BAR+="█"; done
    BAR+="${GRAY}"
    for ((i=0; i<EMPTY; i++)); do BAR+="░"; done
    BAR+="${NC}"
    
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  📊 OVERALL PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Spinner animation for running tasks
spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r  ${YELLOW}⏳${NC} ${message} ${CYAN}${spin:$i:1}${NC}  "
        sleep 0.1
    done
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC} ${message}                    \n"
    else
        printf "\r  ${RED}✗${NC} ${message} ${RED}(failed)${NC}     \n"
    fi
    
    return $exit_code
}

# Install package with progress
install_pkg() {
    local pkg=$1
    local name=${2:-$pkg}
    
    (yes | pkg install $pkg -y > /dev/null 2>&1) &
    spinner $! "Installing ${name}..."
}

# ============== BANNER ==============
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
    ╔══════════════════════════════════════╗
    ║                                      ║
    ║   🍏  QEMU-iOS INSTALLER v2.0  🍏    ║
    ║                                      ║
    ║        Powered by Termux-X11         ║
    ║                                      ║
    ╚══════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo -e "${WHITE}       Builds devos50/qemu-ios for Android${NC}"
    echo ""
}

# ============== DEVICE DETECTION ==============
detect_device() {
    echo -e "${PURPLE}[*] Detecting your device...${NC}"
    echo ""
    
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    CPU_CORES=$(nproc 2>/dev/null || echo "4")
    
    echo -e "  ${GREEN}📱${NC} Device: ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  ${GREEN}⚙️${NC}  CPU Cores: ${WHITE}${CPU_CORES} (Used for compiling)${NC}"
    echo ""
    sleep 1
}

# ============== STEP 1: UPDATE SYSTEM ==============
step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating system packages...${NC}"
    echo ""
    
    (yes | pkg update -y > /dev/null 2>&1) &
    spinner $! "Updating package lists..."
    
    (yes | pkg upgrade -y > /dev/null 2>&1) &
    spinner $! "Upgrading installed packages..."
}

# ============== STEP 2: REPOSITORIES & X11 ==============
step_x11_setup() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Setting up X11 Environment...${NC}"
    echo ""
    
    install_pkg "x11-repo" "X11 Repository"
    install_pkg "termux-x11-nightly" "Termux-X11 Display Server"
    install_pkg "openbox" "Openbox Window Manager"
    install_pkg "xterm" "Xterm Emulator"
}

# ============== STEP 3: INSTALL DEPENDENCIES ==============
step_dependencies() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Build Toolchain & Libraries...${NC}"
    echo ""
    
    install_pkg "wget" "Wget"
    install_pkg "unzip" "Unzip"
    install_pkg "git" "Git"
    install_pkg "clang" "Clang Compiler"
    install_pkg "make" "Make Build Tool"
    install_pkg "pkg-config" "Pkg-Config"
    install_pkg "python" "Python 3"
    install_pkg "glib" "GLib Library"
    install_pkg "pixman" "Pixman Library"
    install_pkg "zlib" "Zlib"
    install_pkg "sdl2" "SDL2 Video Library"
    install_pkg "openssl" "OpenSSL (for AES/SHA1)"
}

# ============== STEP 4: CLONE REPOSITORY ==============
step_clone() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Fetching QEMU-iOS Source...${NC}"
    echo ""
    
    cd ~
    if [ -d "qemu-ios" ]; then
        echo -e "  ${YELLOW}⚠️${NC} Existing qemu-ios directory found. Backing it up..."
        mv qemu-ios qemu-ios_backup_$(date +%s)
    fi
    
    # Clone specifically the ipod_touch_2g branch
    (git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git > /dev/null 2>&1) &
    spinner $! "Cloning devos50/qemu-ios (ipod_touch_2g branch)..."
}

# ============== STEP 5: CONFIGURE BUILD ==============
step_configure() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring Build Environment...${NC}"
    echo ""
    
    cd ~/qemu-ios
    mkdir -p build
    cd build
    
    # Configure using parameters from RUNNING.md modified for Termux environment
    (../configure \
        --enable-sdl \
        --disable-cocoa \
        --target-list=arm-softmmu \
        --disable-capstone \
        --disable-slirp \
        --disable-werror \
        --enable-pie \
        --extra-cflags="-I$PREFIX/include -I$PREFIX/include/openssl" \
        --extra-ldflags="-L$PREFIX/lib -lcrypto" > configure.log 2>&1) &
    spinner $! "Running ./configure for ARM-softmmu..."
}

# ============== STEP 6: COMPILE QEMU ==============
step_build() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Compiling QEMU-iOS (This takes a while)...${NC}"
    echo ""
    
    CORES=$(nproc 2>/dev/null || echo "4")
    cd ~/qemu-ios/build
    
    echo -e "  ${GRAY}💡 Tip: You can open a new Termux session and type 'tail -f ~/qemu-ios/build/build.log' to monitor.${NC}"
    (make -j${CORES} > build.log 2>&1) &
    spinner $! "Compiling with ${CORES} cores..."
    
    if [ -f "arm-softmmu/qemu-system-arm" ]; then
        echo -e "  ${GREEN}✓${NC} Compilation successful! Binary created."
    else
        echo -e "  ${RED}✗${NC} Compilation may have failed. Check ~/qemu-ios/build/build.log for details."
    fi
}

# ============== STEP 7: DIRECTORY & FILE SETUP ==============
step_directories_and_files() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Downloading iPod Touch 2G ROMs/Files...${NC}"
    echo ""
    
    mkdir -p ~/ios-workspace/roms
    
    (wget -q "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4" -O ~/ios-workspace/roms/bootrom_240_4) &
    spinner $! "Downloading BootROM..."
    
    (wget -q "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin" -O ~/ios-workspace/roms/nor_n72ap.bin) &
    spinner $! "Downloading NOR image..."
    
    (wget -q "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip" -O ~/ios-workspace/nand_n72ap.zip) &
    spinner $! "Downloading NAND zip file..."
    
    # Extract the NAND zip (which contains a directory named 'nand') into workspace
    (unzip -o -q ~/ios-workspace/nand_n72ap.zip -d ~/ios-workspace/ && rm ~/ios-workspace/nand_n72ap.zip) &
    spinner $! "Extracting NAND file system..."
}

# ============== STEP 8: LAUNCHER SCRIPT ==============
step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Launchers...${NC}"
    echo ""
    
    cat > ~/start-ios.sh << 'LAUNCHEREOF'
#!/data/data/com.termux/files/usr/bin/bash

echo ""
echo "🍏 Starting iOS Emulator Environment..."
echo ""

# Kill existing sessions
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "openbox" 2>/dev/null

echo "📺 Starting X11 display server..."
termux-x11 :0 -ac &
sleep 2

export DISPLAY=:0

echo "🖥️ Launching Window Manager..."
openbox-session &
sleep 1

# Launch Terminal in the workspace
cd ~/ios-workspace
xterm -fa 'Monospace' -fs 10 -geometry 80x24 -title "QEMU-iOS Launcher" -e "
echo '===================================='
echo '       🍏 QEMU-iOS TERMINAL 🍏      '
echo '===================================='
echo 'Launching the iPod Touch 2G Emulator...'
echo ''
echo 'Command:'
echo '~/qemu-ios/build/arm-softmmu/qemu-system-arm \\'
echo '  -M iPod-Touch,bootrom=roms/bootrom_240_4,nand=nand,nor=roms/nor_n72ap.bin \\'
echo '  -serial mon:stdio -cpu max -m 2G -d unimp'
echo '===================================='
echo ''
~/qemu-ios/build/arm-softmmu/qemu-system-arm -M iPod-Touch,bootrom=roms/bootrom_240_4,nand=nand,nor=roms/nor_n72ap.bin -serial mon:stdio -cpu max -m 2G -d unimp
echo ''
echo '[Emulator closed. Press enter to exit...]'
read
" &

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📱 Open the Termux-X11 app to view!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
LAUNCHEREOF
    
    chmod +x ~/start-ios.sh
    echo -e "  ${GREEN}✓${NC} Created ~/start-ios.sh"
}

# ============== COMPLETION ==============
show_completion() {
    echo ""
    echo -e "${GREEN}"
    cat << 'COMPLETE'
    
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║         ✅  QEMU-iOS BUILD COMPLETE!  ✅                      ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
    
COMPLETE
    echo -e "${NC}"
    
    echo -e "${WHITE}📱 Your emulator is built and files are staged!${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}🚀 TO START THE GUI ENVIROMENT:${NC}"
    echo -e "   ${GREEN}bash ~/start-ios.sh${NC}"
    echo ""
    echo -e "${WHITE}⚡ TIP: Open the Termux-X11 app immediately after running start-ios.sh${NC}"
    echo ""
}

# ============== MAIN PROCESS ==============
main() {
    show_banner
    
    echo -e "${WHITE}  This script compiles devos50/qemu-ios (ipod_touch_2g branch)${NC}"
    echo -e "${WHITE}  and downloads the required ROMs automatically.${NC}"
    echo ""
    echo -e "${GRAY}  Estimated time: 10-45 minutes (depending on CPU speed)${NC}"
    echo ""
    echo -e "${YELLOW}  Press Enter to start installation, or Ctrl+C to cancel...${NC}"
    read
    
    # Execution pipeline
    detect_device
    step_update
    step_x11_setup
    step_dependencies
    step_clone
    step_configure
    step_build
    step_directories_and_files
    step_launchers
    
    # Output wrap-up
    show_completion
}

# ============== RUN ==============
main
