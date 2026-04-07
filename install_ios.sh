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
    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  📊 PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

spinner() {
    local pid=$1
    local message=$2
    local logfile=$3
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        local progress=""
        if [ -f "$logfile" ]; then
            progress=$(tail -n 20 "$logfile" 2>/dev/null | grep -o "\[[0-9]*/[0-9]*\]" | tail -n 1)
        fi
        if [ -n "$progress" ]; then
            printf "\r  ${YELLOW}⏳${NC} ${WHITE}${progress}${NC} ${message} ${CYAN}${spin:$i:1}${NC}  "
        else
            printf "\r  ${YELLOW}⏳${NC} ${message} ${CYAN}${spin:$i:1}${NC}  "
        fi
        sleep 0.1
    done
    wait $pid
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC} ${message}                    \n"
    else
        printf "\r  ${RED}✗${NC} ${message} ${RED}(failed)${NC}     \n"
        echo -e "\n${RED}Check $logfile for details.${NC}"
        exit 1
    fi
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
    ║   🍏    QEMU-iOS INSTALLER     🍏    ║
    ║                                      ║
    ║        Optimized for Termux          ║
    ║                                      ║
    ╚══════════════════════════════════════╝
BANNER
    echo -e "${NC}${WHITE}       Builds devos50/qemu-ios for Android${NC}\n"
}


detect_device() {
    MAX_CORES=$(nproc 2>/dev/null || echo "4")
    echo -e "${PURPLE}[*] System: ${WHITE}$(getprop ro.product.model)${NC} | Cores: ${WHITE}${MAX_CORES}${NC}"
    echo -n -e "  ${YELLOW}❓ How many cores for compiling? [Default: ${MAX_CORES}]: ${NC}"
    read USER_CORES
    CPU_CORES=${USER_CORES:-$MAX_CORES}
    echo -e "  ${GREEN}✓${NC} Using ${WHITE}${CPU_CORES}${NC} cores.\n"
}

step_update() {
    update_progress
    local tmplog=$(mktemp)
    (yes | pkg update -y > "$tmplog" 2>&1 && yes | pkg upgrade -y >> "$tmplog" 2>&1) &
    spinner $! "Updating System" "$tmplog"
}

step_dependencies() {
    update_progress
    echo -e "${PURPLE}[*] Installing dependencies...${NC}"
    local deps=(x11-repo termux-x11-nightly openbox xterm git clang make ninja pkg-config python 
               glib libpixman libtasn1 libusb libgcrypt zlib sdl2 libx11 xorgproto openssl 
               libglvnd libepoxy liblzo bzip2)
    for pkg in "${deps[@]}"; do
        install_pkg "$pkg"
    done
    pip install distlib > /dev/null 2>&1
}

step_clone() {
    update_progress
    cd ~
    if [ -d "qemu-ios" ]; then
        echo -e "  ${GREEN}✓${NC} Source already exists."
    else
        local tmplog=$(mktemp)
        (git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git > "$tmplog" 2>&1) &
        spinner $! "Cloning Source" "$tmplog"
    fi
}

step_configure() {
    update_progress
    cd ~/qemu-ios
    echo -e "  ${YELLOW}🔧${NC} Applying Android compatibility patches..."

    git checkout block/file-posix.c util/oslib-posix.c 2>/dev/null

    sed -i 's/syscall(SYS_gettid)/gettid()/g' util/oslib-posix.c

    sed -i 's/#ifdef CONFIG_BLKZONED/#if 0/g' block/file-posix.c
    sed -i 's/#ifdef CONFIG_COPY_FILE_RANGE/#if 0/g' block/file-posix.c
    
    sed -i '1i #define pr_manager_execute(...) (-1)' block/file-posix.c
    sed -i 's/pr_manager_execute/pr_manager_execute_stub/g' block/file-posix.c

    mkdir -p build && cd build
    (../configure \
        --enable-sdl --disable-cocoa --disable-opengl \
        --target-list=arm-softmmu --disable-capstone \
        --disable-slirp --disable-werror --enable-pie \
        --extra-cflags="-I$PREFIX/include -I$PREFIX/include/X11" \
        --extra-ldflags="-L$PREFIX/lib -lX11" > configure.log 2>&1) &
    spinner $! "Configuring Build" "configure.log"
}

step_build() {
    update_progress
    cd ~/qemu-ios/build
    echo -e "  ${GRAY}💡 This may take 10-30 minutes depending on your device.${NC}"
    (make -j${CPU_CORES} > build.log 2>&1) &
    spinner $! "Building QEMU-iOS" "build.log"
}

step_finalize() {
    update_progress
    mkdir -p ~/ios-workspace/roms
    if [ ! -f "~/qemu-ios/build/arm-softmmu/qemu-system-arm" ]; then
       echo -e "  ${GREEN}✓${NC} Executable found!"
    fi
}

step_launchers() {
    update_progress
    cat > ~/start-ios.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "Starting X11 Server..."
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0
openbox-session &
sleep 1
echo "Launching iPod Touch 2G..."
xterm -e "~/qemu-ios/build/arm-softmmu/qemu-system-arm -M iPod-Touch,bootrom=~/ios-workspace/roms/bootrom_240_4,nand=~/ios-workspace/nand,nor=~/ios-workspace/roms/nor_n72ap.bin -cpu max -m 512M"
EOF
    chmod +x ~/start-ios.sh
}

main() {
    show_banner
    detect_device
    step_update
    step_dependencies
    step_clone
    step_configure
    step_build
    step_finalize
    step_launchers
    echo -e "\n${GREEN}✅ SETUP COMPLETE!${NC}"
    echo -e "${WHITE}Run it with: ${CYAN}bash ~/start-ios.sh${NC}"
}

main
