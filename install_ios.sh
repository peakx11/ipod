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
    echo -e "\n\n${RED}⚠️ Build Failed.${NC}"
    echo -e "${YELLOW}--- DIAGNOSTIC ERROR ---${NC}"
    grep -B 3 -A 1 "error:" "$LOG_FILE" | tail -n 10
    echo -e "${YELLOW}------------------------${NC}"
    pkill -P $$ 2>/dev/null
    exit 1
}
trap cleanup SIGINT SIGTERM ERR

initialize_log() {
    echo "=== QEMU-iOS Build Log v3.3 ===" > "$LOG_FILE"
    echo "Started at $(date)" >> "$LOG_FILE"
}

update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    BAR_SIZE=20
    FILLED=$((PERCENT * BAR_SIZE / 100))
    EMPTY=$((BAR_SIZE - FILLED))
    BAR="${GREEN}$(printf '█%.0s' $(seq 1 $FILLED))${GRAY}$(printf '░%.0s' $(seq 1 $EMPTY))${NC}"
    echo -e "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  📊 PROGRESS: ${WHITE}${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    local tick=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        if [ $((tick % 10)) -eq 0 ] && [ -f "$LOG_FILE" ]; then
            progress=$(tail -n 15 "$LOG_FILE" 2>/dev/null | grep -o "\[[0-9]*/[0-9]*\]" | tail -n 1)
        fi
        tick=$((tick + 1))
        printf "\r  ${YELLOW}⏳${NC} ${WHITE}${progress:-....}${NC} ${message} ${CYAN}${spin:$i:1}${NC}   "
        sleep 0.1
    done
    wait $pid
    if [ $? -eq 0 ]; then
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
    echo -e "${CYAN}╔══════════════════════════════════════════════╗"
    echo -e "║      🍏 QEMU-iOS TERMUX BUILDER v3.3 🍏      ║"
    echo -e "╚══════════════════════════════════════════════╝${NC}\n"
}

step_preflight() {
    update_progress
    MAX_CORES=$(nproc 2>/dev/null || echo "4")
    echo -n -e "  ${YELLOW}❓ Cores to use? [1-${MAX_CORES}, Default: ${MAX_CORES}]: ${NC}"
    read USER_CORES
    CPU_CORES=${USER_CORES:-$MAX_CORES}
}

step_update() {
    update_progress
    (yes | pkg update -y >> "$LOG_FILE" 2>&1 && yes | pkg upgrade -y >> "$LOG_FILE" 2>&1) &
    spinner $! "Updating System"
}

step_dependencies() {
    update_progress
    local deps=(x11-repo termux-x11-nightly openbox xterm wget unzip git clang make ninja pkg-config python glib libpixman libtasn1 libusb libgcrypt zlib sdl2 libx11 xorgproto openssl libglvnd libepoxy liblzo bzip2)
    for pkg in "${deps[@]}"; do install_pkg "$pkg"; done
    (pip install distlib >> "$LOG_FILE" 2>&1) &
    spinner $! "Installing Python Distlib"
}

step_clone() {
    update_progress
    if [ ! -d "$REPO_DIR" ]; then
        (git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git "$REPO_DIR" >> "$LOG_FILE" 2>&1) &
        spinner $! "Cloning Source"
    fi
}

step_configure() {
    update_progress
    cd "$REPO_DIR"
    git checkout block/file-posix.c util/oslib-posix.c 2>/dev/null
    
    sed -i 's/syscall(SYS_gettid)/gettid()/g' util/oslib-posix.c
    
    sed -i 's/pr_manager_execute/termux_pr_mgr_stub/g' block/file-posix.c
    
    cat << 'EOF' > fix_header.h
#include <errno.h>
#include <sys/syscall.h>
static inline int get_sysfs_str_val(void* a, const char* b, char** c) { return -1; }
static inline long get_sysfs_long_val(void* a, const char* b) { return -1; }
static inline int copy_file_range(int a, void* b, int c, void* d, size_t e, unsigned int f) { errno = ENOSYS; return -1; }
static inline int termux_pr_mgr_stub(void* a, void* b, void* c, void* d, void* e, void* f) { return -1; }
EOF

    cat fix_header.h block/file-posix.c > block/file-posix.c.new
    mv block/file-posix.c.new block/file-posix.c
    rm fix_header.h
    
    mkdir -p build && cd build
    (
        ../configure \
        --enable-sdl --disable-cocoa --disable-opengl \
        --target-list=arm-softmmu --disable-capstone \
        --disable-slirp --disable-werror --enable-pie \
        --disable-vhost-user \
        --extra-cflags="-I$PREFIX/include -I$PREFIX/include/X11 -Wno-implicit-function-declaration" \
        --extra-ldflags="-L$PREFIX/lib -lX11" >> "$LOG_FILE" 2>&1
    ) &
    spinner $! "Configuring Build"
}

step_build() {
    update_progress
    cd "$REPO_DIR/build"
    rm -rf libblock.fa.p/block_file-posix.c.o
    (make -j${CPU_CORES} >> "$LOG_FILE" 2>&1) &
    spinner $! "Building Source Code"
}

step_files() {
    update_progress
    mkdir -p "$WORKSPACE/roms"
    cd "$WORKSPACE"
    (wget -q -c "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4" -O roms/bootrom_240_4 >> "$LOG_FILE" 2>&1) &
    spinner $! "Downloading BootROM"
    (wget -q -c "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin" -O roms/nor_n72ap.bin >> "$LOG_FILE" 2>&1) &
    spinner $! "Downloading NOR"
    if [ ! -d "$WORKSPACE/nand" ]; then
        (wget -q -c "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip" -O nand_n72ap.zip >> "$LOG_FILE" 2>&1) &
        spinner $! "Downloading NAND"
        (unzip -o -q nand_n72ap.zip -d "$WORKSPACE/" && rm nand_n72ap.zip >> "$LOG_FILE" 2>&1) &
        spinner $! "Extracting NAND"
    fi
}

step_launchers() {
    update_progress
    cat > "$HOME/start-ios.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "openbox" 2>/dev/null
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0
openbox-session &
sleep 1
xterm -fa 'Monospace' -fs 10 -e "~/qemu-ios/build/arm-softmmu/qemu-system-arm -M iPod-Touch,bootrom=~/ios-workspace/roms/bootrom_240_4,nand=~/ios-workspace/nand,nor=~/ios-workspace/roms/nor_n72ap.bin -serial mon:stdio -cpu max -m 512M; read" &
EOF
    chmod +x "$HOME/start-ios.sh"
}

step_done() {
    update_progress
    echo -e "${GREEN}✅ SUCCESS! Run: bash ~/start-ios.sh${NC}"
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
