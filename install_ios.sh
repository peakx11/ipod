#!/data/data/com.termux/files/usr/bin/bash

TOTAL_STEPS=10
CURRENT_STEP=0
CPU_CORES=4
FAST_MODE=0

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
        tail -n 40 "$LOG_FILE"
    fi
    echo -e "${YELLOW}------------------------${NC}"
    pkill -P $$ 2>/dev/null
    exit 1
}

trap cleanup SIGINT SIGTERM ERR

initialize_log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== QEMU-iOS Build Log ===" > "$LOG_FILE"
    echo "Started at $(date)" >> "$LOG_FILE"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
    ╔════════════════════════════════════════════════════════════╗
    ║                                                            ║
    ║               🍏  QEMU-iOS INSTALLER  🍏                  ║
    ║                                                            ║
    ║                  Powered by Termux-X11                     ║
    ║                                                            ║
    ╚════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo -e "${WHITE}       Builds devos50/qemu-ios for Android${NC}"
    echo ""
}

overall_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))

    if [ "$FAST_MODE" -eq 1 ]; then
        echo "[${CURRENT_STEP}/${TOTAL_STEPS}] $1"
        return
    fi

    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    local bar="${GREEN}"

    for ((i=0; i<filled; i++)); do
        bar+="█"
    done

    bar+="${GRAY}"

    for ((i=0; i<empty; i++)); do
        bar+="░"
    done

    bar+="${NC}"

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  [${CURRENT_STEP}/${TOTAL_STEPS}] ${WHITE}$1${NC}"
    echo -e "  ${bar} ${WHITE}${percent}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    if [ "$FAST_MODE" -eq 1 ]; then
        wait "$pid"
        return $?
    fi

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r  ${YELLOW}⏳${NC} ${message} ${CYAN}${spin:$i:1}${NC}  "
        sleep 0.1
    done

    wait "$pid"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC} ${message}                    \n"
    else
        printf "\r  ${RED}✗${NC} ${message} ${RED}(failed)${NC}     \n"
    fi

    return $exit_code
}

run_cmd() {
    local cmd="$1"
    local message="$2"

    if [ "$FAST_MODE" -eq 1 ]; then
        bash -lc "$cmd" >> "$LOG_FILE" 2>&1
        local code=$?
        if [ $code -ne 0 ]; then
            tail -n 40 "$LOG_FILE"
            exit $code
        fi
        return 0
    fi

    (bash -lc "$cmd" >> "$LOG_FILE" 2>&1) &
    spinner $! "$message"
    local code=$?
    if [ $code -ne 0 ]; then
        tail -n 40 "$LOG_FILE"
        exit $code
    fi
}

install_pkg() {
    local pkg="$1"
    local name="${2:-$pkg}"
    run_cmd "yes | pkg install $pkg -y" "Installing ${name}..."
}

download_file() {
    local url="$1"
    local out="$2"
    local label="$3"

    if [ -f "$out" ]; then
        if [ "$FAST_MODE" -eq 1 ]; then
            echo "[INFO] ${label} already exists"
        else
            echo -e "  ${GREEN}✓${NC} ${label} already exists"
        fi
        return
    fi

    run_cmd "wget -q -c '$url' -O '$out'" "Downloading ${label}..."
}

ask_fast_mode() {
    while true; do
        echo -ne "${CYAN}Do u want to use fast mode? (Y/N): ${NC}"
        read INPUT
        case "$INPUT" in
            Y|y)
                FAST_MODE=1
                break
                ;;
            N|n)
                FAST_MODE=0
                break
                ;;
            *)
                echo -e "${RED}Enter Y or N${NC}"
                ;;
        esac
    done
}

ask_cores() {
    MAX_CORES=$(nproc 2>/dev/null || echo "4")

    if [ "$FAST_MODE" -eq 1 ]; then
        CPU_CORES=$MAX_CORES
        echo "[INFO] Using ${CPU_CORES} cores"
        return
    fi

    echo -e "${PURPLE}[*] Detecting your device...${NC}"
    echo ""
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    echo -e "  ${GREEN}📱${NC} Device: ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  ${GREEN}⚙️${NC}  Available CPU Cores: ${WHITE}${MAX_CORES}${NC}"
    echo ""

    while true; do
        echo -ne "  ${YELLOW}❓ How many cores would you like to use for compiling? [Default: ${MAX_CORES}]: ${NC}"
        read USER_CORES
        if [ -z "$USER_CORES" ]; then
            CPU_CORES=$MAX_CORES
            break
        elif ! [[ "$USER_CORES" =~ ^[0-9]+$ ]]; then
            echo -e "  ${RED}✗ Invalid input. Try again.${NC}"
        elif [ "$USER_CORES" -gt "$MAX_CORES" ]; then
            echo -e "  ${YELLOW}⚠️ Requested ${USER_CORES} cores but only ${MAX_CORES} are available. Using ${MAX_CORES}.${NC}"
            CPU_CORES=$MAX_CORES
            break
        elif [ "$USER_CORES" -le 0 ]; then
            echo -e "  ${RED}✗ Invalid input. Try again.${NC}"
        else
            CPU_CORES=$USER_CORES
            break
        fi
    done

    echo -e "  ${GREEN}✓${NC} Proceeding with ${WHITE}${CPU_CORES}${NC} cores for compilation."
    echo ""
}

step_update() {
    overall_progress "Updating system packages..."
    run_cmd "yes | pkg update -y" "Updating package lists..."
    run_cmd "yes | pkg upgrade -y" "Upgrading installed packages..."
}

step_x11_setup() {
    overall_progress "Setting up X11 environment..."
    install_pkg "x11-repo" "X11 Repository"
    install_pkg "termux-x11-nightly" "Termux-X11 Display Server"
    install_pkg "openbox" "Openbox Window Manager"
    install_pkg "xterm" "Xterm Emulator"
}

step_dependencies() {
    overall_progress "Installing build toolchain and libraries..."
    install_pkg "wget" "Wget"
    install_pkg "unzip" "Unzip"
    install_pkg "git" "Git"
    install_pkg "clang" "Clang Compiler"
    install_pkg "make" "Make Build Tool"
    install_pkg "ninja" "Ninja"
    install_pkg "pkg-config" "Pkg-Config"
    install_pkg "python" "Python 3"
    install_pkg "glib" "GLib Library"
    install_pkg "libpixman" "Pixman Library"
    install_pkg "libtasn1" "LibTASN1"
    install_pkg "libusb" "LibUSB"
    install_pkg "libgcrypt" "LibGcrypt"
    install_pkg "zlib" "Zlib"
    install_pkg "sdl2" "SDL2"
    install_pkg "libx11" "LibX11"
    install_pkg "xorgproto" "XorgProto"
    install_pkg "openssl" "OpenSSL"
    install_pkg "libglvnd" "LibGLVND"
    install_pkg "libepoxy" "LibEpoxy"
    install_pkg "liblzo" "LibLZO"
    install_pkg "bzip2" "Bzip2"
    run_cmd "pip install distlib" "Installing Python package distlib..."
}

step_clone() {
    overall_progress "Fetching QEMU-iOS source..."
    cd "$HOME"

    if [ -d "$REPO_DIR" ]; then
        if [ -f "$REPO_DIR/configure" ] || [ -f "$REPO_DIR/meson.build" ]; then
            if [ "$FAST_MODE" -eq 1 ]; then
                echo "[INFO] Existing QEMU-iOS source found. Skipping clone."
                return
            fi

            echo -e "  ${YELLOW}⚠️ Existing qemu-ios folder detected.${NC}"
            echo -e "  ${CYAN}[1] Use existing source${NC}"
            echo -e "  ${CYAN}[2] Re-clone fresh${NC}"
            echo ""
            while true; do
                echo -ne "  ${YELLOW}Select option [1-2]: ${NC}"
                read CHOICE
                case "$CHOICE" in
                    1)
                        echo -e "  ${GREEN}✓ Using existing source${NC}"
                        return
                        ;;
                    2)
                        rm -rf "$REPO_DIR"
                        break
                        ;;
                    *)
                        echo -e "  ${RED}Invalid option${NC}"
                        ;;
                esac
            done
        else
            rm -rf "$REPO_DIR"
        fi
    fi

    run_cmd "git clone -b ipod_touch_2g https://github.com/devos50/qemu-ios.git '$REPO_DIR'" "Cloning devos50/qemu-ios (ipod_touch_2g branch)..."
}

step_clean_generated() {
    overall_progress "Removing generated build files..."
    cd "$REPO_DIR"
    rm -rf build
    rm -f config.log config.status
}

step_configure() {
    overall_progress "Configuring build environment..."
    cd "$REPO_DIR"

    if [ -d ".git" ]; then
        git checkout -- block/file-posix.c util/oslib-posix.c hw/scsi/scsi-disk.c hw/scsi/scsi-generic.c 2>/dev/null || true
    fi

    sed -i 's/syscall(SYS_gettid)/gettid()/g' util/oslib-posix.c

    cat << 'EOF' > fix_header.h
#ifndef TERMUX_QEMU_IOS_FIX_HEADER_H
#define TERMUX_QEMU_IOS_FIX_HEADER_H

#include <errno.h>
#include <stddef.h>
#include <sys/syscall.h>

static inline int get_sysfs_str_val(void* a, const char* b, char** c) { return -1; }
static inline long get_sysfs_long_val(void* a, const char* b) { return -1; }
static inline int copy_file_range(int a, void* b, int c, void* d, size_t e, unsigned int f) { errno = ENOSYS; return -1; }
static inline int termux_pr_mgr_stub(void* a, ...) { errno = ENOSYS; return -1; }

#define pr_manager_execute termux_pr_mgr_stub

#ifndef SG_ERR_DRIVER_TIMEOUT
#define SG_ERR_DRIVER_TIMEOUT 0
#endif

#ifndef SG_ERR_DRIVER_SENSE
#define SG_ERR_DRIVER_SENSE 0
#endif

#endif
EOF

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
        --extra-cflags='-include $REPO_DIR/fix_header.h -I$PREFIX/include -I$PREFIX/include/X11 -O2 -pipe -fomit-frame-pointer -Wno-implicit-function-declaration -Wno-macro-redefined' \
        --extra-ldflags='-L$PREFIX/lib -lX11'" "Running configure..."
}

step_build() {
    overall_progress "Compiling QEMU-iOS with ${CPU_CORES} cores..."
    cd "$REPO_DIR/build"
    rm -f libblock.fa.p/block_file-posix.c.o

    export NINJA_STATUS="[%f/%t] "

    if [ "$FAST_MODE" -eq 1 ]; then
        echo "[${CURRENT_STEP}/${TOTAL_STEPS}] Building with ${CPU_CORES} cores..."
        make -j"$CPU_CORES" >> "$LOG_FILE" 2>&1
        local code=$?
        if [ $code -ne 0 ]; then
            tail -n 40 "$LOG_FILE"
            exit $code
        fi
        return
    fi

    make -j"$CPU_CORES" 2>&1 | tee -a "$LOG_FILE" | grep --line-buffered -oE '^\[[0-9]+/[0-9]+\]'
    local code=${PIPESTATUS[0]}
    if [ $code -ne 0 ]; then
        tail -n 40 "$LOG_FILE"
        exit $code
    fi
}

step_files() {
    overall_progress "Downloading ROMs and NAND images..."
    mkdir -p "$WORKSPACE/roms"
    cd "$WORKSPACE"

    download_file "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4" "$WORKSPACE/roms/bootrom_240_4" "BootROM"
    download_file "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin" "$WORKSPACE/roms/nor_n72ap.bin" "NOR image"
    download_file "https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip" "$WORKSPACE/nand_n72ap.zip" "NAND zip"

    if [ ! -d "$WORKSPACE/nand" ]; then
        run_cmd "unzip -o -q nand_n72ap.zip -d '$WORKSPACE/' && rm -f nand_n72ap.zip" "Extracting NAND..."
    fi
}

step_launchers() {
    overall_progress "Creating launcher..."
    cat > "$HOME/start-ios.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "openbox" 2>/dev/null
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
termux-x11 :0 -ac &
sleep 2
export DISPLAY=:0
openbox-session &
sleep 1
xterm -fa 'Monospace' -fs 10 -geometry 100x30 -title "QEMU-iOS" -e "~/qemu-ios/build/arm-softmmu/qemu-system-arm -M iPod-Touch,bootrom=~/ios-workspace/roms/bootrom_240_4,nand=~/ios-workspace/nand,nor=~/ios-workspace/roms/nor_n72ap.bin -cpu max -smp ${CPU_CORES} -m 512M -serial mon:stdio" &
EOF
    chmod +x "$HOME/start-ios.sh"
}

show_completion() {
    if [ "$FAST_MODE" -eq 1 ]; then
        echo "Done. Run: bash ~/start-ios.sh"
        return
    fi

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
    echo -e "${WHITE}🚀 TO START THE GUI ENVIRONMENT:${NC}"
    echo -e "   ${GREEN}bash ~/start-ios.sh${NC}"
    echo ""
    echo -e "${WHITE}⚡ Open the Termux-X11 app after running start-ios.sh.${NC}"
    echo ""
}

main() {
    initialize_log
    show_banner

    echo -e "${WHITE}  This script compiles devos50/qemu-ios (ipod_touch_2g branch)${NC}"
    echo -e "${WHITE}  and downloads the required ROMs automatically.${NC}"
    echo ""
    echo -e "${GRAY}  Estimated time: 10-45 minutes depending on CPU speed.${NC}"
    echo ""
    echo -e "${YELLOW}  Press Enter to start installation, or Ctrl+C to cancel...${NC}"
    read

    ask_fast_mode
    if [ "$FAST_MODE" -eq 0 ]; then
        show_banner
    fi
    ask_cores

    step_update
    step_x11_setup
    step_dependencies
    step_clone
    step_clean_generated
    step_configure
    step_build
    step_files
    step_launchers
    show_completion
}

main
