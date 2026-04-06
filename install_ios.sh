#!/data/data/com.termux/files/usr/bin/bash

TOTAL_STEPS=10
CURRENT_STEP=0
CPU_CORES=4 

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

update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
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

spinner() {
    local pid=$1
    local message=$2
    local logfile=$3
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
        if [ -n "$logfile" ] && [ -f "$logfile" ]; then
            echo -e "\n${RED}================ ERROR LOG =================${NC}"
            tail -n 20 "$logfile"
            echo -e "${RED}============================================${NC}\n"
        fi
        echo -e "${RED}Script aborted due to error in step ${CURRENT_STEP}. Please fix the issue and run again.${NC}"
        exit 1
    fi
    return $exit_code
}

install_pkg() {
    local pkg=$1
    local name=${2:-$pkg}
    local tmplog=$(mktemp)
    (yes | pkg install $pkg -y > "$tmplog" 2>&1) &
    spinner $! "Installing ${name}..." "$tmplog"
    rm -f "$tmplog"
}

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

detect_device() {
    echo -e "${PURPLE}[*] Detecting your device...${NC}"
    echo ""
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    MAX_CORES=$(nproc 2>/dev/null || echo "4")
    echo -e "  ${GREEN}📱${NC} Device: ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  ${GREEN}⚙️${NC}  Available CPU Cores: ${WHITE}${MAX_CORES}${NC}"
    echo ""
    echo -n -e "  ${YELLOW}❓ How many cores would you like to use for compiling? [Default: ${MAX_CORES}]: ${NC}"
    read USER_CORES
    if [[ -z "$USER_CORES" ]]; then
        CPU_CORES=$MAX_CORES
    elif ! [[ "$USER_CORES" =~ ^[0-9]+$ ]]; then
        echo -e "  ${RED}✗ Invalid input. Using default: ${MAX_CORES}${NC}"
        CPU_CORES=$MAX_CORES
    elif [ "$USER_CORES" -gt "$MAX_CORES" ]; then
        echo -e "  ${YELLOW}⚠️ Warning: Requested ${USER_CORES} cores but only ${MAX_CORES} available. Capping at ${MAX_CORES}.${NC}"
        CPU_CORES=$MAX_CORES
    elif [ "$USER_CORES" -le 0 ]; then
        echo -e "  ${RED}✗ Invalid input. Using default: ${MAX_CORES}${NC}"
        CPU_CORES=$MAX_CORES
    else
        CPU_CORES=$USER_CORES
    fi
    echo -e "  ${GREEN}✓${NC} Proceeding with ${WHITE}${CPU_CORES}${NC} cores for compilation."
    echo ""
    sleep 1
}

step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating system packages...${NC}"
    echo ""
    local tmplog=$(mktemp)
    (yes | pkg update -y > "$tmplog" 2>&1) &
    spinner $! "Updating package lists..." "$tmplog"
    (yes | pkg upgrade -y >> "$tmplog" 2>&1) &
    spinner $! "Upgrading installed packages..." "$tmplog"
    rm -f "$tmplog"
}

step_x11_setup() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Setting up X11 Environment...${NC}"
    echo ""
    install_pkg "x11-repo" "X11 Repository"
    install_pkg "termux-x11-nightly" "Termux-X11 Display Server"
    install_pkg "openbox" "Openbox Window Manager"
    install_pkg "xterm" "Xterm Emulator"
}

step_dependencies() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Build Toolchain & Libraries...${NC}"
    echo ""
    install_pkg "wget" "Wget"
    install_pkg "unzip" "Unzip"
    install_pkg "git" "Git"
    install_pkg "clang" "Clang Compiler"
    install_pkg "make" "Make Build Tool"
    install_pkg "ninja" "Ninja Build System"
    install_pkg "pkg-config" "Pkg-Config"
    install_pkg "python" "Python 3"
    install_pkg "glib" "GLib Library"
    install_pkg "libpixman" "Pixman Library"
    install_pkg "zlib" "Zlib"
    install_pkg "sdl2" "SDL2 Video Library"
    install_pkg "openssl" "OpenSSL (for AES/SHA1)"
}

step_clone() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Fetching QEMU-iOS Source...${NC}"
    echo ""
    cd ~
    if [ -d "qemu-ios" ]; then
        echo -e "  ${YELLOW}⚠️${NC} Existing qemu-ios directory found. Backing it up..."
        mv qemu-ios qemu-ios_backup_$(date +%s)
    fi
    local tmplog=$(mktemp)
    (git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git > "$tmplog" 2>&1) &
    spinner $! "Cloning devos50/qemu-ios (ipod_touch_2g branch)..." "$tmplog"
    rm -f "$tmplog"
}

step_configure() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring Build Environment...${NC}"
    echo ""
    cd ~/qemu-ios
    mkdir -p build
    cd build
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
    spinner $! "Running ./configure for ARM-softmmu..." "configure.log"
}

step_build() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Compiling QEMU-iOS (This takes a while)...${NC}"
    echo ""
    cd ~/qemu-ios/build
    echo -e "  ${GRAY}💡 Tip: You can open a new Termux session and type 'tail -f ~/qemu-ios/build/build.log' to monitor.${NC}"
    (make -j${CPU_CORES} > build.log 2>&1) &
    spinner $! "Compiling with ${CPU_CORES} cores..." "build.log"
    if [ ! -f "arm-softmmu/qemu-system-arm" ]; then
        echo -e "  ${RED}✗${NC} Compilation may have failed. Executable not found."
        echo -e "\n${RED}================ ERROR LOG =================${NC}"
        tail -n 20 build.log
        echo -e "${RED}============================================${NC}\n"
        exit 1
    fi
}

step_directories_and_files() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Downloading iPod Touch 2G ROMs/Files...${NC}"
    echo ""
    mkdir -p ~/ios-workspace/roms
    local tmplog=$(mktemp)
    (wget "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4" -O ~/ios-workspace/roms/bootrom_240_4 > "$tmplog" 2>&1) &
    spinner $! "Downloading BootROM..." "$tmplog"
    (wget "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin" -O ~/ios-workspace/roms/nor_n72ap.bin > "$tmplog" 2>&1) &
    spinner $! "Downloading NOR image..." "$tmplog"
    (wget "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip" -O ~/ios-workspace/nand_n72ap.zip > "$tmplog" 2>&1) &
    spinner $! "Downloading NAND zip file..." "$tmplog"
    (unzip -o -q ~/ios-workspace/nand_n72ap.zip -d ~/ios-workspace/ && rm ~/ios-workspace/nand_n72ap.zip >> "$tmplog" 2>&1) &
    spinner $! "Extracting NAND file system..." "$tmplog"
    rm -f "$tmplog"
}

step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Launchers...${NC}"
    echo ""
    cat > ~/start-ios.sh << 'LAUNCHEREOF'
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "🍏 Starting iOS Emulator Environment..."
echo ""
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "openbox" 2>/dev/null
echo "📺 Starting X11 display server..."
termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0
echo "🖥️ Launching Window Manager..."
openbox-session &
sleep 1
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

step_enjoy() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Wrap-up...${NC}"
    echo ""
    echo -e "  ${GREEN}Enjoy! 🍏${NC}"
    echo ""
}

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
}

main() {
    show_banner
    echo -e "${WHITE}  This script compiles devos50/qemu-ios (ipod_touch_2g branch)${NC}"
    echo -e "${WHITE}  and downloads the required ROMs automatically.${NC}"
    echo ""
    echo -e "${GRAY}  Estimated time: 10-45 minutes (depending on CPU speed)${NC}"
    echo ""
    echo -e "${YELLOW}  Press Enter to start installation, or Ctrl+C to cancel...${NC}"
    read
    detect_device
    step_update
    step_x11_setup
    step_dependencies
    step_clone
    step_configure
    step_build
    step_directories_and_files
    step_launchers
    step_enjoy
    show_completion
}

main
