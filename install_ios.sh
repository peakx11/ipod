#!/data/data/com.termux/files/usr/bin/bash

TOTAL_STEPS=10
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
BOLD='\033[1m'

exec </dev/tty >/dev/tty 2>&1

cleanup() {
    echo -e "\n${RED}⚠️ Build Failed.${NC}"
    echo -e "${YELLOW}--- DIAGNOSTIC ERROR ---${NC}"
    if [ -f "$LOG_FILE" ]; then
        tail -n 30 "$LOG_FILE"
    fi
    echo -e "${YELLOW}------------------------${NC}"
    pkill -P $$ 2>/dev/null
    exit 1
}

trap cleanup SIGINT SIGTERM ERR

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
    local show_progress=${4:-0}
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        local progress=""
        if [ "$show_progress" -eq 1 ] && [ -n "$logfile" ] && [ -f "$logfile" ]; then
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
        if [ -n "$logfile" ] && [ -f "$logfile" ]; then
            echo -e "\n${RED}================ ERROR LOG =================${NC}"
            tail -n 30 "$logfile"
            echo -e "${RED}============================================${NC}\n"
        fi
        exit 1
    fi
}

install_pkg() {
    local pkg=$1
    local name=${2:-$pkg}
    local tmplog=$(mktemp)
    (yes | pkg install "$pkg" -y > "$tmplog" 2>&1) &
    spinner $! "Installing ${name}..." "$tmplog" 0
    rm -f "$tmplog"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
    ╔══════════════════════════════════════╗
    ║                                      ║
    ║   🍏  QEMU-iOS INSTALLER v2.1  🍏    ║
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
    else
        CPU_CORES=$USER_CORES
    fi
    echo -e "  ${GREEN}✓${NC} Proceeding with ${WHITE}${CPU_CORES}${NC} cores."
    echo ""
    sleep 1
}

step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating system packages...${NC}"
    echo ""
    local tmplog=$(mktemp)
    (yes | pkg update -y > "$tmplog" 2>&1) &
    spinner $! "Updating package lists..." "$tmplog" 0
    (yes | pkg upgrade -y >> "$tmplog" 2>&1) &
    spinner $! "Upgrading installed packages..." "$tmplog" 0
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
    install_pkg "python-pip" "Python Pip"
    install_pkg "glib" "GLib Library"
    install_pkg "libpixman" "Pixman Library"
    install_pkg "libtasn1" "TASN1 Library"
    install_pkg "libusb" "USB Library"
    install_pkg "libgcrypt" "Gcrypt Library"
    install_pkg "zlib" "Zlib"
    install_pkg "sdl2" "SDL2 Video Library"
    install_pkg "openssl" "OpenSSL (for AES/SHA1)"
    echo -e "  ${YELLOW}⏳${NC} Installing Python dependencies..."
    pip install distlib > /dev/null 2>&1
}

step_clone() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Checking QEMU-iOS Source...${NC}"
    echo ""
    cd ~
    if [ -d "qemu-ios" ]; then
        echo -e "  ${GREEN}✓${NC} Existing qemu-ios directory found. Skipping clone."
        echo ""
    else
        local tmplog=$(mktemp)
        (git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git > "$tmplog" 2>&1) &
        spinner $! "Cloning devos50/qemu-ios (ipod_touch_2g branch)..." "$tmplog" 0
        rm -f "$tmplog"
    fi
}

step_configure() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring Build Environment...${NC}"
    echo ""
    cd ~/qemu-ios

    echo -e "  ${YELLOW}🔧${NC} Applying Termux compatibility patches..."

    git checkout block/file-posix.c util/oslib-posix.c migration/ram.c migration/postcopy-ram.c 2>/dev/null

    sed -i 's/syscall(SYS_gettid)/gettid()/g' util/oslib-posix.c

    cat > fix_header.h << 'EOF'
#ifndef TERMUX_QEMU_IOS_FIX_HEADER_H
#define TERMUX_QEMU_IOS_FIX_HEADER_H

#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <linux/userfaultfd.h>

#ifndef SG_ERR_DRIVER_TIMEOUT
#define SG_ERR_DRIVER_TIMEOUT 0
#endif

#ifndef SG_ERR_DRIVER_SENSE
#define SG_ERR_DRIVER_SENSE 0
#endif

static inline int get_sysfs_str_val(void* a, const char* b, char** c) { return -1; }
static inline long get_sysfs_long_val(void* a, const char* b) { return -1; }
static inline int copy_file_range(int a, void* b, int c, void* d, size_t e, unsigned int f) { errno = ENOSYS; return -1; }

#ifndef UFFD_FEATURE_PAGEFAULT_FLAG_WP
#define UFFD_FEATURE_PAGEFAULT_FLAG_WP 0
#endif

#ifndef _UFFDIO_WRITEPROTECT
#define _UFFDIO_WRITEPROTECT 0
#endif

#ifndef UFFDIO_REGISTER_MODE_WP
#define UFFDIO_REGISTER_MODE_WP 0
#endif

#ifndef UFFD_EVENT_PAGEFAULT
#define UFFD_EVENT_PAGEFAULT 0x12
struct uffd_msg {
    uint8_t event;
    uint8_t reserved1;
    uint16_t reserved2;
    uint32_t reserved3;
    union {
        struct {
            uint64_t flags;
            uint64_t address;
            union {
                uint32_t ptid;
            } feat;
        } pagefault;
        struct {
            uint32_t uffd;
        } fork;
        struct {
            uint64_t from;
            uint64_t to;
            uint64_t len;
        } remap;
        struct {
            uint64_t start;
            uint64_t end;
        } remove;
        struct {
            uint64_t reserved1;
            uint64_t reserved2;
            uint64_t reserved3;
        } reserved;
    } arg;
} __attribute__((packed));
#endif

#endif
EOF

    sed -i '1i #include "fix_header.h"' block/file-posix.c
    sed -i '1i #include "fix_header.h"' migration/ram.c
    sed -i '1i #include "fix_header.h"' migration/postcopy-ram.c

    echo -e "  ${YELLOW}🔨${NC} Creating Linker Stubs..."
    cat > linker_stubs.c << 'EOF'
int uffd_register_memory() { return -1; }
int uffd_change_protection() { return -1; }
int uffd_unregister_memory() { return -1; }
int uffd_read_events() { return -1; }
int pr_manager_execute() { return -1; }
int uffd_query_features() { return -1; }
int uffd_create_fd() { return -1; }
int uffd_close_fd() { return -1; }
int uffd_open() { return -1; }
EOF
    clang -O2 -c linker_stubs.c -o linker_stubs.o
    STUBS_OBJ="$(pwd)/linker_stubs.o"

    echo -e "  ${YELLOW}🧹${NC} Cleaning up previous build files..."
    rm -rf build
    mkdir -p build
    cd build

    (../configure \
       --enable-sdl \
       --disable-cocoa \
       --target-list=arm-softmmu \
       --disable-capstone \
       --disable-slirp \
       --disable-werror \
       --disable-opengl \
       --disable-gtk \
       --disable-vte \
       --enable-pie \
       --extra-cflags="-I$PREFIX/include -O2 -pipe -fomit-frame-pointer -Wno-implicit-function-declaration -Wno-macro-redefined -DSG_ERR_DRIVER_TIMEOUT=0 -DSG_ERR_DRIVER_SENSE=0" \
       --extra-ldflags="-L$PREFIX/lib -lcrypto $STUBS_OBJ" > configure.log 2>&1) &
       
    spinner $! "Configuring build..." "configure.log" 0
}

step_build() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Compiling QEMU-iOS (This takes a while)...${NC}"
    echo ""
    cd ~/qemu-ios/build
    echo -e "  ${GRAY}💡 Tip: Progress will appear in the spinner below.${NC}"

    (make -j${CPU_CORES} > build.log 2>&1) &
    spinner $! "Compiling with ${CPU_CORES} cores..." "build.log" 1

    if [ ! -f "arm-softmmu/qemu-system-arm" ] && [ ! -f "../qemu-system-arm" ]; then
        echo -e "  ${RED}✗${NC} Compilation may have failed. Executable not found."
        exit 1
    fi
}

step_directories_and_files() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Downloading iPod Touch 2G ROMs/Files...${NC}"
    echo ""
    mkdir -p ~/ios-workspace/roms
    local tmplog=$(mktemp)
    (wget -c "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4" -O ~/ios-workspace/roms/bootrom_240_4 > "$tmplog" 2>&1) &
    spinner $! "Downloading BootROM..." "$tmplog" 0
    (wget -c "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin" -O ~/ios-workspace/roms/nor_n72ap.bin > "$tmplog" 2>&1) &
    spinner $! "Downloading NOR image..." "$tmplog" 0
    (wget -c "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip" -O ~/ios-workspace/nand_n72ap.zip > "$tmplog" 2>&1) &
    spinner $! "Downloading NAND zip file..." "$tmplog" 0
    (unzip -o -q ~/ios-workspace/nand_n72ap.zip -d ~/ios-workspace/ && rm ~/ios-workspace/nand_n72ap.zip >> "$tmplog" 2>&1) &
    spinner $! "Extracting NAND file system..." "$tmplog" 0
    rm -f "$tmplog"
}

step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Launchers...${NC}"
    echo ""
    cat > ~/start-ios.sh << 'LAUNCHEREOF'
#!/data/data/com.termux/files/usr/bin/bash

pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "openbox" 2>/dev/null

am start -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
termux-x11 :0 -ac &
sleep 2

export DISPLAY=:0
openbox-session &
sleep 1

cd ~/ios-workspace

xterm -geometry 80x24 -title "QEMU-iOS" -e bash -c '
(
while true; do
    read -rsn1 key
    if [[ $key == $'\''\e'\'' ]]; then
        echo "sendkey home"
    fi
done
) &

"~/qemu-ios/build/arm-softmmu/qemu-system-arm \
-M iPod-Touch,bootrom=roms/bootrom_240_4,nand=nand,nor=roms/nor_n72ap.bin \
-serial mon:stdio \
-cpu max \
-m 2G \
-device usb-mouse \
-device usb-kbd \
-display sdl \
-d unimp; echo 'Process finished. Press Enter to close.'; read" &

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
    echo -e "${GREEN}✅ QEMU-iOS BUILD COMPLETE!${NC}"
    echo -e "${WHITE}Run it with: ${GREEN}bash ~/start-ios.sh${NC}"
}

main() {
    show_banner
    echo -e "${YELLOW}Press Enter to start, or Ctrl+C to cancel...${NC}"
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
