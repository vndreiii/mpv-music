#!/bin/bash
# This script will automatically do all the steps a user would do, it's meant to be ran in a distrobox, and to be hooked to install.sh
set -e

# --- Configuration ---
NC='\033[0m' # No Color
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'

# --- Helper Functions ---
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
prompt() { read -p "$(echo -e "${YELLOW}👉 $1${NC}")" "$2"; }

# --- Ensure script is running on Arch ---
if ! grep -qi "arch" /etc/os-release; then
  error "This script is for Arch Linux only!"
  exit 1
fi
success "Running on Arch Linux."

# --- Ensure core utilities are installed ---
info "Checking for essential utilities (git, base-devel, pciutils)..."
if ! sudo pacman -S --needed git base-devel pciutils --noconfirm; then
    error "Failed to install essential utilities. Please check your internet connection and pacman configuration."
    exit 1
fi
success "Essential utilities are installed."


# --- Ensure yay is installed ---
if ! command -v yay &>/dev/null; then
  info "📦 yay not found. Installing yay..."
  if [[ -d yay ]]; then
    info "🧹 Removing leftover yay folder..."
    rm -rf yay
  fi
  if git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay; then
    success "yay installed successfully."
  else
    error "Failed to install yay. Please check the output above for errors."
    exit 1
  fi
else
  success "yay is already installed, skipping install."
fi


info "🎵 Installing mpv and plugins..."

# List of packages to install
packages=(
  mpv
  mpv-mpris
  mpv-thumbfast-git
  adwaita-fonts # For default subtitle font
)

# Loop through each package and install if missing
install_failed=false
for package in "${packages[@]}"; do
  if ! pacman -Qs "$package" > /dev/null; then
    info "📦 Installing $package..."
    if ! yay -S --noconfirm "$package"; then
        warn "Failed to install $package. Continuing..."
        install_failed=true
    else
        success "$package installed."
    fi
  else
    success "$package is already installed, skipping."
  fi
done

if $install_failed; then
    warn "Some packages failed to install. mpv might not function as expected."
fi

success "🎵 mpv package installation phase complete."


# --- GPU Detection and Configuration ---
info "🔍 Detecting GPUs..."
gpu_list=$(lspci -vmm -nn | awk '
BEGIN { RS=""; FS="\n"; idx=0 }
/Class:.*VGA compatible controller|3D controller|Display controller/ {
  vendor="Unknown Vendor"
  device="Unknown Device"
  ven_id=""
  dev_id=""
  for (i = 1; i <= NF; i++) {
    if ($i ~ /^Vendor:/) { vendor = substr($i, 9); }
    if ($i ~ /^Device:/) { device = substr($i, 9); }
    if ($i ~ /^SVendor:/) { svendor = substr($i, 10); } # Sometimes more descriptive
    if ($i ~ /^SDevice:/) { sdevice = substr($i, 10); } # Sometimes more descriptive
    if ($i ~ /\[[0-9a-f]{4}:[0-9a-f]{4}\]/) {
        match($i, /\[([0-9a-f]{4}):([0-9a-f]{4})\]/)
        ven_id=substr($i, RSTART+1, 4)
        dev_id=substr($i, RSTART+6, 4)
    }
  }
  # Prefer SDevice/SVendor if they look more specific
  if (svendor != vendor && length(svendor)>0) vendor = svendor;
  if (sdevice != device && length(sdevice)>0) device = sdevice;
  # Format: "Vendor Name Device Name [vendor_id:device_id]"
  print vendor " " device " [" ven_id ":" dev_id "]"
}')

# Convert gpu_list string into a bash array
mapfile -t gpus <<< "$gpu_list"
num_gpus=${#gpus[@]}

use_gpu_accel=false # Default to software rendering

if [[ $num_gpus -eq 0 ]]; then
  warn "No GPUs detected by lspci. Falling back to software rendering for mpv."
  use_gpu_accel=false
elif [[ $num_gpus -eq 1 ]]; then
  info "Detected 1 GPU:"
  echo -e "   ${GREEN}${gpus[0]}${NC}"
  prompt "Enable hardware acceleration (vo=gpu-next, hwdec, vulkan)? Highly recommended if drivers are installed. [Y/n] " use_accel_reply
  # Default to Yes if user just presses Enter
  if [[ "$use_accel_reply" =~ ^[Yy]$ ]] || [[ -z "$use_accel_reply" ]]; then
    use_gpu_accel=true
    success "Hardware acceleration enabled."
  else
    warn "Hardware acceleration disabled."
    use_gpu_accel=false
  fi
else
  info "Detected multiple GPUs:"
  for i in "${!gpus[@]}"; do
    echo -e "   ${GREEN}$((i+1))) ${gpus[$i]}${NC}"
  done
  # In most desktop scenarios, mpv uses the primary GPU set by the system/compositor.
  # The relevant choice is *whether* to enable GPU features, not *which* GPU within mpv.conf here.
  prompt "Enable hardware acceleration (vo=gpu-next, hwdec, vulkan)? This will typically use your primary GPU. Highly recommended if drivers are installed. [Y/n] " use_accel_reply
   # Default to Yes if user just presses Enter
  if [[ "$use_accel_reply" =~ ^[Yy]$ ]] || [[ -z "$use_accel_reply" ]]; then
    use_gpu_accel=true
    success "Hardware acceleration enabled."
  else
    warn "Hardware acceleration disabled."
    use_gpu_accel=false
  fi
fi

# --- Define mpv.conf Blocks based on GPU choice ---
video_block_base="geometry=650x650 # You can specify the size of the player in pixels
autofit-larger=90%x90%
keep-open=yes
force-window=yes
profile=high-quality
video-sync=display-resample
hr-seek-framedrop=no"

video_block_gpu_opts="gpu-api=vulkan
hwdec=auto-copy # If you have issues check out https://mpv.io/manual/master/#options-hwdec for more info.
vo=gpu-next"

video_block="" # Initialize

if $use_gpu_accel; then
    info "Configuring mpv for Hardware Acceleration."
    video_block="${video_block_base}\n${video_block_gpu_opts}"
else
    info "Configuring mpv for Software Rendering."
    video_block="${video_block_base}"
fi

audio_block="volume=84 # Or whatever you want the default volume to be
volume-max=200 # Maximum volume to display and to let use access
save-position-on-quit=yes # Or do not save it so it will always play the song from the start
audio-channels=auto"

other_block="sub-font=\"Adwaita Sans\" # Specify the font used for the player you can check all fonts with fc-list.
sub-ass-override=yes
sub-bold=yes # Whether to make font bold or not
sub-font-size=64 # Font size
sub-align-x=center
sub-align-y=center
sub-justify=left
sub-border-size=0.2  # Border size of the outlines
sub-blur=20 # Overall blur of the outlines
sub-shadow-offset=8 # Shadow distance (also gets affected by the outlines blur)
sub-shadow-color=\"#000118\" # Shadow color
osd-bar=no"

# --- Step 1: Get umpv ---
info "📥 Installing umpv..."
if sudo wget -q -O /usr/local/bin/umpv https://raw.githubusercontent.com/mpv-player/mpv/refs/heads/master/TOOLS/umpv && \
   sudo chmod +x /usr/local/bin/umpv; then
    success "umpv downloaded and made executable."
else
    error "Failed to download or set permissions for umpv."
fi

# Patch "append-play" to play instantly
info "🔧 Patching umpv to play songs instantly..."
if sudo sed -i 's/append-play//' /usr/local/bin/umpv; then
    success "umpv patched."
else
    warn "Failed to patch umpv. It might not play instantly but queue up next."
fi

# --- Step 2: Install uosc ---
info "📟️ Installing uosc..."
if bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/unix.sh)"; then
    success "uosc installed."
else
    error "Failed to install uosc."
    # exit 1
fi

# Enable top bar in uosc.conf
UOSC_CONF="$HOME/.config/mpv/script-opts/uosc.conf"
info "🔧 Configuring uosc top bar..."
mkdir -p "$(dirname "$UOSC_CONF")"
if [ -f "$UOSC_CONF" ]; then
  # If file exists, try to replace the line or append if not found
  if grep -q '^top_bar=' "$UOSC_CONF"; then
      sed -i 's/^top_bar=.*/top_bar=always/' "$UOSC_CONF"
      success "uosc.conf updated: top_bar set to always."
  else
      echo "top_bar=always" >> "$UOSC_CONF"
      success "uosc.conf updated: top_bar=always added."
  fi
else
  echo "top_bar=always" > "$UOSC_CONF"
  success "uosc.conf created with top_bar=always."
fi

# Enable input.conf tabbing for full ui
info "⌨️ Downloading input.conf for uosc tabbing..."
mkdir -p ~/.config/mpv
if wget -q -O ~/.config/mpv/input.conf https://raw.githubusercontent.com/vndreiii/mpv-music/refs/heads/main/input.conf; then
    success "input.conf downloaded."
else
    warn "Failed to download input.conf. UI tabbing might not work."
fi

# --- Step 3: Get and enhance mpv.conf ---
info "🗳️ Setting up mpv.conf..."
MPV_CONF="$HOME/.config/mpv/mpv.conf"
mkdir -p "$(dirname "$MPV_CONF")"

# Get the base mpv.conf FIRST
if ! wget -q -O "$MPV_CONF" https://raw.githubusercontent.com/mpv-player/mpv/refs/heads/master/etc/mpv.conf; then
    warn "Failed to download base mpv.conf. Creating an empty one."
    touch "$MPV_CONF"
fi

# Append all blocks at the end of the file
{
  echo -e "\n# --- Custom Video Settings ---"
  echo -e "$video_block"
  echo -e "\n# --- Custom Audio Settings ---"
  echo -e "$audio_block"
  echo -e "\n# --- Custom Other Settings (Subs/OSD) ---"
  echo -e "$other_block"
} >> "$MPV_CONF"

success "MPV configuration setup complete! (${MPV_CONF})"


# --- Step 4: autoload.lua script ---
info "📂 Installing autoload.lua..."
mkdir -p ~/.config/mpv/scripts
if ! wget -q -O ~/.config/mpv/scripts/autoload.lua https://raw.githubusercontent.com/mpv-player/mpv/refs/heads/master/TOOLS/lua/autoload.lua; then
    error "Failed to download autoload.lua script."
    # exit 1
else
    success "autoload.lua installed."
fi

# Create autoload.conf
info "🔧 Configuring autoload.conf..."
mkdir -p ~/.config/mpv/script-opts
cat > ~/.config/mpv/script-opts/autoload.conf <<EOF
disabled=no
images=no
videos=no
audio=yes
ignore_hidden=yes
same_type=no
directory_mode=recursive
ignore_patterns=^~,^bak-,%.bak$
EOF
success "autoload.conf created."

# --- Step 5: mpv-lrc lyrics ---
info "🎤 Setting up mpv-lrc..."
if ! wget -q -O ~/.config/mpv/scripts/lrc.lua https://raw.githubusercontent.com/guidocella/mpv-lrc/refs/heads/main/lrc.lua; then
    error "Failed to download lrc.lua."
else
    success "lrc.lua installed."
fi

if ! wget -q -O ~/.config/mpv/script-opts/lrc.conf https://raw.githubusercontent.com/guidocella/mpv-lrc/refs/heads/main/script-opts/lrc.conf; then
    error "Failed to download lrc.conf."
else
    success "lrc.conf installed."
fi

# --- Final touches ---
info "🎉 Downloading lyrics toggle overlay + notifications..."
if ! wget -q -O ~/.config/mpv/scripts/lyrics-toggle.lua https://raw.githubusercontent.com/vndreiii/mpv-music/refs/heads/main/scripts/lyrics-toggle.lua; then
    warn "Failed to download lyrics-toggle.lua."
else
    success "lyrics-toggle.lua installed."
fi

if ! wget -q -O ~/.config/mpv/scripts/notify_cover.lua https://raw.githubusercontent.com/vndreiii/mpv-music/refs/heads/main/scripts/notify_cover.lua; then
    warn "Failed to download notify_cover.lua."
else
    success "notify_cover.lua installed."
fi

echo -e "\n✨ ${GREEN}All done! mpv should be configured.${NC}"
echo -e "   GPU Hardware Acceleration: $(if $use_gpu_accel; then echo "${GREEN}Enabled${NC}"; else echo "${YELLOW}Disabled${NC}"; fi)"
echo -e "   Final steps..."
