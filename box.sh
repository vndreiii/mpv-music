#!/bin/bash
# This script will automatically do all the steps a user would do, it's meant to be ran in a distrobox, and to be hooked to install.sh
set -e

# Ensure script is running on Arch
if ! grep -qi "arch" /etc/os-release; then
  echo "❌ This script is for Arch Linux only!"
  exit 1
fi

# Ensure yay is installed
if ! command -v yay &>/dev/null; then
  echo "📦 yay not found. Installing yay..."
  sudo pacman -S --needed git base-devel --noconfirm

  if [[ -d yay ]]; then
    echo "🧹 Removing leftover yay folder..."
    rm -rf yay
  fi

  git clone https://aur.archlinux.org/yay.git
  cd yay && makepkg -si --noconfirm
  cd .. && rm -rf yay
else
  echo "✅ yay is already installed, skipping install."
fi


echo "🎵 Installing mpv and plugins..."

# List of packages to install
packages=(
  mpv
  mpv-autosub-git
  mpv-autosubsync-git
  mpv-mpris
  mpv-thumbfast-git
  adwaita-fonts
)

# Loop through each package and check if it's already installed
for package in "${packages[@]}"; do
  if ! pacman -Qs "$package" > /dev/null; then
    echo "📦 Installing $package..."
    yay -S --noconfirm "$package"
  else
    echo "✅ $package is already installed, skipping."
  fi
done

echo "🎵 All required packages are installed or already up to date."


# Step 1: Get umpv
echo "📥 Installing umpv..."
sudo wget -O /usr/local/bin/umpv https://raw.githubusercontent.com/mpv-player/mpv/refs/heads/master/TOOLS/umpv
sudo chmod +x /usr/local/bin/umpv

# Patch "append-play" to play instantly
echo "🔧 Patching umpv to play songs instantly..."
sudo sed -i 's/append-play//' /usr/local/bin/umpv

# Step 2: Install uosc
echo "📟️ Installing uosc..."
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tomasklaen/uosc/HEAD/installers/unix.sh)"

# Enable top bar
UOSC_CONF="$HOME/.config/mpv/script-opts/uosc.conf"
mkdir -p "$(dirname "$UOSC_CONF")"
if [ -f "$UOSC_CONF" ]; then
  sed -i 's/^top_bar=.*/top_bar=always/' "$UOSC_CONF"
else
  echo "top_bar=always" > "$UOSC_CONF"
fi

# Enable input.conf tabbing for full ui
wget -O ~/.config/mpv/input.conf https://raw.githubusercontent.com/vndreiii/mpv-music/refs/heads/main/input.conf

# Step 3: Get and enhance mpv.conf
echo "🗳️ Setting up mpv.conf..."
MPV_CONF="$HOME/.config/mpv/mpv.conf"
mkdir -p "$(dirname "$MPV_CONF")"
wget -O "$MPV_CONF" https://raw.githubusercontent.com/mpv-player/mpv/refs/heads/master/etc/mpv.conf

# Define your config blocks (or don't idk)
video_block="geometry=650x650 # You can specify the size of the player in pixels
autofit-larger=90%x90%
keep-open=yes
force-window=yes
profile=high-quality
video-sync=display-resample
gpu-api=vulkan
hr-seek-framedrop=no
hwdec=auto-copy # If you have issues check out https://mpv.io/manual/master/#options-hwdec for more info.
vo=gpu-next"

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

# Append all blocks at the end of the file
{
    echo -e "\n# Video Settings"
    echo -e "$video_block"
    echo -e "\n# Audio Settings"
    echo -e "$audio_block"
    echo -e "\n# Other Settings"
    echo -e "$other_block"
} >> "$MPV_CONF"

echo "✅ MPV configuration setup complete!"


# Step 4: autoload.lua script
echo "📂 Installing autoload.lua..."
mkdir -p ~/.config/mpv/scripts
wget -O ~/.config/mpv/scripts/autoload.lua https://raw.githubusercontent.com/mpv-player/mpv/refs/heads/master/TOOLS/lua/autoload.lua

# Create autoload.conf
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

# Step 5: mpv-lrc lyrics
echo "🎤 Setting up mpv-lrc..."
wget -O ~/.config/mpv/scripts/lrc.lua https://raw.githubusercontent.com/guidocella/mpv-lrc/refs/heads/main/lrc.lua
wget -O ~/.config/mpv/script-opts/lrc.conf https://raw.githubusercontent.com/guidocella/mpv-lrc/refs/heads/main/script-opts/lrc.conf

# Final touches
echo "🎉 Downloading lyrics toggle overlay + notifications..."
wget -O ~/.config/mpv/scripts/lyrics-toggle.lua https://raw.githubusercontent.com/vndreiii/mpv-music/refs/heads/main/scripts/lyrics-toggle.lua
wget -O ~/.config/mpv/scripts/notify_cover.lua https://raw.githubusercontent.com/vndreiii/mpv-music/refs/heads/main/scripts/notify_cover.lua

echo -e "\n✨ All done, outside, please?"
