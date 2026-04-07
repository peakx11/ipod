#!/data/data/com.termux/files/usr/bin/bash

LOG_FILE="$HOME/qemu-ios-install.log"
WORKSPACE="$HOME/ios-workspace"
REPO_DIR="$HOME/qemu-ios"

CPU_CORES=4
FAST_MODE=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

print_line() {
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_header() {
    clear
    print_line
    echo -e "${CYAN}        QEMU-iOS TERMUX BUILDER${NC}"
    print_line
}

log() {
    echo "$1" >> "$LOG_FILE"
}

run_cmd() {
    if [ "$FAST_MODE" -eq 1 ]; then
        eval "$1" >> "$LOG_FILE" 2>&1
    else
        eval "$1" >> "$LOG_FILE" 2>&1 &
        pid=$!
        spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        i=0
        while kill -0 $pid 2>/dev/null; do
            i=$(( (i+1) % 10 ))
            printf "\r${YELLOW}${spin:$i:1}${NC} ${2}   "
            sleep 0.1
        done
        wait $pid
        if [ $? -eq 0 ]; then
            printf "\r${GREEN}✓${NC} ${2}            \n"
        else
            echo -e "\n${RED}Build Failed${NC}"
            grep -B 2 -A 2 "error:" "$LOG_FILE" | tail -n 10
            exit 1
        fi
    fi
}

ask_cores() {
    MAX_CORES=$(nproc 2>/dev/null || echo 4)
    while true; do
        echo -ne "${CYAN}Cores [1-${MAX_CORES}] (default ${MAX_CORES}): ${NC}"
        read INPUT < /dev/tty
        if [ -z "$INPUT" ]; then
            CPU_CORES=$MAX_CORES
            break
        elif [[ "$INPUT" =~ ^[0-9]+$ ]] && [ "$INPUT" -ge 1 ] && [ "$INPUT" -le "$MAX_CORES" ]; then
            CPU_CORES=$INPUT
            break
        else
            echo -e "${RED}Invalid input${NC}"
        fi
    done
}

ask_fast_mode() {
    while true; do
        echo -ne "${CYAN}Do u want to use fast mode? (Y/N): ${NC}"
        read INPUT < /dev/tty
        case "$INPUT" in
            Y|y) FAST_MODE=1; break ;;
            N|n) FAST_MODE=0; break ;;
            *) echo -e "${RED}Enter Y or N${NC}" ;;
        esac
    done
}

install_deps() {
    deps=(x11-repo termux-x11-nightly openbox xterm wget unzip git clang make ninja pkg-config python glib libpixman libtasn1 libusb libgcrypt zlib sdl2 libx11 xorgproto openssl libglvnd libepoxy liblzo bzip2)
    for pkg in "${deps[@]}"; do
        run_cmd "yes | pkg install $pkg -y" "Installing $pkg"
    done
    run_cmd "pip install distlib" "Python deps"
}

patch_qemu() {
    cd "$REPO_DIR"

    git checkout block/file-posix.c util/oslib-posix.c 2>/dev/null

    sed -i 's/syscall(SYS_gettid)/gettid()/g' util/oslib-posix.c
    sed -i 's/pr_manager_execute/termux_pr_mgr_stub/g' block/file-posix.c

    cat << 'EOF' > fix_header.h
#include <errno.h>
#include <stddef.h>
#include <sys/syscall.h>
static inline int get_sysfs_str_val(void* a, const char* b, char** c) { return -1; }
static inline long get_sysfs_long_val(void* a, const char* b) { return -1; }
static inline int copy_file_range(int a, void* b, int c, void* d, size_t e, unsigned int f) { errno = ENOSYS; return -1; }
static inline int termux_pr_mgr_stub(void* a, ...) { return -1; }
EOF

    sed -i '1i #include "fix_header.h"' block/file-posix.c
}

configure_build() {
    mkdir -p build
    cd build

    run_cmd "../configure \
    --enable-sdl \
    --disable-cocoa \
    --disable-opengl \
    --target-list=arm-softmmu \
    --disable-capstone \
    --disable-slirp \
    --disable-werror \
    --enable-pie \
    --disable-vhost-user \
    --disable-linux-aio \
    --extra-cflags='-I$PREFIX/include -I$PREFIX/include/X11 -Wno-implicit-function-declaration' \
    --extra-ldflags='-L$PREFIX/lib -lX11'" "Configuring"
}

build_qemu() {
    run_cmd "make -j$CPU_CORES" "Building"
}

download_files() {
    mkdir -p "$WORKSPACE/roms"
    cd "$WORKSPACE"

    run_cmd "wget -q -c https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4 -O roms/bootrom_240_4" "BootROM"
    run_cmd "wget -q -c https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin -O roms/nor_n72ap.bin" "NOR"

    if [ ! -d "$WORKSPACE/nand" ]; then
        run_cmd "wget -q -c https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip -O nand.zip" "NAND"
        run_cmd "unzip -o -q nand.zip -d $WORKSPACE && rm nand.zip" "Extract"
    fi
}

create_launcher() {
cat > "$HOME/start-ios.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill -9 -f termux.x11 2>/dev/null
pkill -9 -f openbox 2>/dev/null
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0
openbox-session &
sleep 1
xterm -e "~/qemu-ios/build/arm-softmmu/qemu-system-arm -M iPod-Touch,bootrom=~/ios-workspace/roms/bootrom_240_4,nand=~/ios-workspace/nand,nor=~/ios-workspace/roms/nor_n72ap.bin -serial mon:stdio -cpu max -m 512M; read" &
EOF
chmod +x "$HOME/start-ios.sh"
}

main() {
    echo "=== LOG ===" > "$LOG_FILE"
    print_header

    ask_cores
    ask_fast_mode

    run_cmd "yes | pkg update -y && yes | pkg upgrade -y" "Updating system"

    install_deps

    if [ ! -d "$REPO_DIR" ]; then
        run_cmd "git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git $REPO_DIR" "Cloning"
    fi

    patch_qemu
    configure_build
    build_qemu
    download_files
    create_launcher

    print_line
    echo -e "${GREEN}DONE -> bash ~/start-ios.sh${NC}"
    print_line
}

main
