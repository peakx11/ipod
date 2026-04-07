#!/data/data/com.termux/files/usr/bin/bash

TOTAL_STEPS=11
CURRENT_STEP=0
CPU_CORES=4 
LOG_FILE="$HOME/qemu-ios-install.log"
WORKSPACE="$HOME/ios-workspace"
REPO_DIR="$HOME/qemu-ios"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

cleanup() {
    echo -e "\n\n${RED}⚠️ Script interrupted or encountered a fatal error.${NC}"
    echo -e "${YELLOW}Check ${WHITE}$LOG_FILE${YELLOW} for detailed error logs.${NC}"
    pkill -P $$ 2>/dev/null
    exit 1
}
trap cleanup SIGINT SIGTERM ERR

initialize_log() {
    echo "=== QEMU-iOS Build Log ===" > "$LOG_FILE"
    echo "Started at $(date)" >> "$LOG_FILE"
    echo "==========================" >> "$LOG_FILE"
}

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
    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  📊 OVERALL PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    local tick=0
    local progress=""

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        
        if [ $((tick % 10)) -eq 0 ]; then
            progress=$(tail -n 10 "$LOG_FILE" 2>/dev/null | grep -o "\[[0-9]*/[0-9]*\]" | tail -n 1)
        fi
        tick=$((tick + 1))

        if [ -n "$progress" ]; then
            printf "\r  ${YELLOW}⏳${NC} ${WHITE}${progress}${NC} ${message} ${CYAN}${spin:$i:1}${NC}   "
        else
            printf "\r  ${YELLOW}⏳${NC} ${message} ${CYAN}${spin:$i:1}${NC}   "
        fi
        sleep 0.1
    done
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC} ${message}                    \n"
    else
        printf "\r  ${RED}✗${NC} ${message} ${RED}(failed)${NC}     \n"
        cleanup
    fi
}

install_pkg() {
    local pkg=$1
    (yes | pkg install $pkg -y >> "$LOG_FILE" 2>&1) &
    spinner $! "Installing ${pkg}"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
    ╔══════════════════════════════════════════════╗
    ║                                              ║
    ║      🍏 QEMU-iOS TERMUX BUILDER v3.0 🍏      ║
    ║                                              ║
    ║    Robust, Automated, & Termux-Optimized     ║
    ║                                              ║
    ╚══════════════════════════════════════════════╝
BANNER
    echo -e "${NC}${WHITE}         Target: devos50/qemu-ios (ipod_touch_2g)${NC}\n"
}

step_preflight() {
    update_progress
    echo -e "${PURPLE}[*] Running System Checks...${NC}"
    
    echo -n -e "  ${YELLOW}⏳${NC} Checking connectivity..."
    if ! ping -c 1 github.com > /dev/null 2>&1; then
        echo -e "\r  ${RED}✗ No internet connection detected.${NC}"
        exit 1
    fi
    echo -e "\r  ${GREEN}✓ Internet connected.       ${NC}"

    echo -n -e "  ${YELLOW}⏳${NC} Checking storage space..."
    FREE_SPACE=$(df -m $HOME | awk 'NR==2 {print $4}')
    if [ "$FREE_SPACE" -lt 3000 ]; then
        echo -e "\r  ${RED}✗ Insufficient space. Need 3GB, have ${FREE_SPACE}MB.${NC}"
        exit 1
    fi
    echo -e "\r  ${GREEN}✓ Sufficient space (${FREE_SPACE}MB free).${NC}"

    MAX_CORES=$(nproc 2>/dev/null || echo "4")
    echo -n -e "  ${YELLOW}❓ How many cores to use for building? [1-${MAX_CORES}, Default: ${MAX_CORES}]: ${NC}"
    read USER_CORES
    if [[ "$USER_CORES" =~ ^[0-9]+$ ]] && [ "$USER_CORES" -le "$MAX_CORES" ] && [ "$USER_CORES" -gt 0 ]; then
        CPU_CORES=$USER_CORES
    else
        CPU_CORES=$MAX_CORES
    fi
    echo -e "  ${GREEN}✓ Using ${WHITE}${CPU_CORES}${NC} cores for compilation."
}

step_update() {
    update_progress
    echo -e "${PURPLE}[*] Updating package repositories...${NC}"
    (yes | pkg update -y >> "$LOG_FILE" 2>&1 && yes | pkg upgrade -y >> "$LOG_FILE" 2>&1) &
    spinner $! "Updating System"
}

step_dependencies() {
    update_progress
    echo -e "${PURPLE}[*] Installing required packages...${NC}"
    local deps=(
        x11-repo termux-x11-nightly openbox xterm wget unzip git clang make ninja 
        pkg-config python glib libpixman libtasn1 libusb libgcrypt zlib sdl2 
        libx11 xorgproto openssl libglvnd libepoxy liblzo bzip2
    )
    for pkg in "${deps[@]}"; do 
        install_pkg "$pkg"
    done
    
    (pip install distlib >> "$LOG_FILE" 2>&1) &
    spinner $! "Installing Python Distlib"
}

step_clone() {
    update_progress
    echo -e "${PURPLE}[*] Fetching QEMU Source Code...${NC}"
    if [ ! -d "$REPO_DIR" ]; then
        (git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git "$REPO_DIR" >> "$LOG_FILE" 2>&1) &
        spinner $! "Cloning devos50/qemu-ios"
    else
        echo -e "  ${GREEN}✓ Source directory already exists. Skipping clone.${NC}"
    fi
}

step_configure() {
    update_progress
    echo -e "${PURPLE}[*] Applying Termux/Android Patches...${NC}"
    cd "$REPO_DIR"

    git checkout block/file-posix.c util/oslib-posix.c 2>/dev/null

    sed -i 's/syscall(SYS_gettid)/gettid()/g' util/oslib-posix.c
    
    sed -i '1i #include <errno.h>\n#define copy_file_range(...) (errno = 38, -1)' block/file-posix.c
    sed -i '1i #define get_sysfs_str_val(...) (-1)\n#define get_sysfs_long_val(...) (-1)' block/file-posix.c
    sed -i '1i #define pr_manager_execute(...) (-1)' block/file-posix.c
    sed -i 's/pr_manager_execute/pr_manager_execute_stub/g' block/file-posix.c
    
    echo -e "  ${GREEN}✓ Patches applied successfully.${NC}"

    mkdir -p build && cd build
    (
        ../configure \
        --enable-sdl --disable-cocoa --disable-opengl \
        --target-list=arm-softmmu --disable-capstone \
        --disable-slirp --disable-werror --enable-pie \
        --extra-cflags="-I$PREFIX/include -I$PREFIX/include/X11" \
        --extra-ldflags="-L$PREFIX/lib -lX11" >> "$LOG_FILE" 2>&1
    ) &
    spinner $! "Configuring Build Environment"
}

step_build() {
    update_progress
    echo -e "${PURPLE}[*] Compiling QEMU-iOS (This will take a while)...${NC}"
    cd "$REPO_DIR/build"
    (make -j${CPU_CORES} >> "$LOG_FILE" 2>&1) &
    spinner $! "Building Source Code"
    
    if [ ! -f "arm-softmmu/qemu-system-arm" ]; then
        echo -e "  ${RED}✗ Compilation failed. Executable not generated.${NC}"
        cleanup
    fi
}

step_files() {
    update_progress
    echo -e "${PURPLE}[*] Acquiring iPod Touch 2G Firmware...${NC}"
    mkdir -p "$WORKSPACE/roms"
    cd "$WORKSPACE"

    (wget -q -c "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4" -O roms/bootrom_240_4 >> "$LOG_FILE" 2>&1) &
    spinner $! "Downloading BootROM"

    (wget -q -c "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin" -O roms/nor_n72ap.bin >> "$LOG_FILE" 2>&1) &
    spinner $! "Downloading NOR"

    if [ ! -d "$WORKSPACE/nand" ]; then
        (wget -q -c "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip" -O nand_n72ap.zip >> "$LOG_FILE" 2>&1) &
        spinner $! "Downloading NAND Zip"
        
        (unzip -o -q nand_n72ap.zip -d "$WORKSPACE/" && rm nand_n72ap.zip >> "$LOG_FILE" 2>&1) &
        spinner $! "Extracting NAND Filesystem"
    else
        echo -e "  ${GREEN}✓ NAND directory already exists. Skipping extraction.${NC}"
    fi
}

step_launchers() {
    update_progress
    echo -e "${PURPLE}[*] Generating Start Scripts...${NC}"
    
    cat > "$HOME/start-ios.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "openbox" 2>/dev/null

echo "[*] Waking up Termux-X11..."
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
termux-x11 :0 -ac &
sleep 2

export DISPLAY=:0
openbox-session &
sleep 1

echo "[*] Launching QEMU-iOS..."
xterm -fa 'Monospace' -fs 10 -geometry 80x24 -title "QEMU-iOS Console" -e "~/qemu-ios/build/arm-softmmu/qemu-system-arm -M iPod-Touch,bootrom=~/ios-workspace/roms/bootrom_240_4,nand=~/ios-workspace/nand,nor=~/ios-workspace/roms/nor_n72ap.bin -serial mon:stdio -cpu max -m 512M; echo 'Emulator Closed. Press Enter to exit.'; read" &
EOF
    chmod +x "$HOME/start-ios.sh"
    echo -e "  ${GREEN}✓ Launcher created at ~/start-ios.sh${NC}"
}

step_done() {
    update_progress
    echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
    echo -e "${WHITE}Everything is set up in: ${CYAN}${WORKSPACE}${NC}"
    echo -e "${WHITE}A full log was saved to: ${GRAY}${LOG_FILE}${NC}\n"
    echo -e "${YELLOW}To launch the emulator, run:${NC}"
    echo -e "  ${BOLD}bash ~/start-ios.sh${NC}\n"
}

main() {
    initialize_log
    show_banner
    step_preflight
    step_update
    step_dependencies
    step_clone
    step_configure
    step_build
    step_files
    step_launchers
    step_done
}

main
