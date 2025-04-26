#!/bin/bash
set -e

# --- Dependency Check and Installation ---

echo "🔎 Checking for necessary dependencies (distrobox, podman)..."

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for package managers and install dependencies if needed
if command_exists apt; then
  echo "📦 Detected APT package manager (Debian/Ubuntu-based)."
  PACKAGES_TO_INSTALL=""
  if ! command_exists distrobox; then
    PACKAGES_TO_INSTALL+=" distrobox"
  fi
  if ! command_exists podman; then
    PACKAGES_TO_INSTALL+=" podman"
  fi

  if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "🔧 Installing missing dependencies:$PACKAGES_TO_INSTALL..."
    sudo apt update
    sudo apt install -y $PACKAGES_TO_INSTALL
  else
    echo "✅ Dependencies already installed."
  fi
elif command_exists dnf; then
  echo "📦 Detected DNF package manager (Fedora-based)."
  PACKAGES_TO_INSTALL=""
  if ! command_exists distrobox; then
    PACKAGES_TO_INSTALL+=" distrobox"
  fi
  if ! command_exists podman; then
    PACKAGES_TO_INSTALL+=" podman"
  fi

  if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "🔧 Installing missing dependencies:$PACKAGES_TO_INSTALL..."
    sudo dnf install -y $PACKAGES_TO_INSTALL
  else
    echo "✅ Dependencies already installed."
  fi
elif command_exists pacman; then
  echo "📦 Detected Pacman package manager (Arch-based)."
  PACKAGES_TO_INSTALL=""
  # Check if packages are installed using pacman -Q
  if ! pacman -Q distrobox &>/dev/null; then
    PACKAGES_TO_INSTALL+=" distrobox"
  fi
  if ! pacman -Q podman &>/dev/null; then
    PACKAGES_TO_INSTALL+=" podman"
  fi

  if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "🔧 Installing missing dependencies:$PACKAGES_TO_INSTALL..."
    sudo pacman -Syu --noconfirm $PACKAGES_TO_INSTALL
  else
    echo "✅ Dependencies already installed."
  fi
else
  echo "⚠️ Could not detect a supported package manager (apt, dnf, pacman)."
  echo "   Please install 'distrobox' and 'podman' manually from your distro's repo before running this script."
  exit 1
fi

echo "--- Dependency check complete ---"

# 💾 Vars
BOX_NAME="mpv-music"
BOX_HOME="$HOME/Distroboxes/mpv"
SETUP_FILE="box.sh"
SETUP_URL="https://raw.githubusercontent.com/vndreiii/mpv-music/refs/heads/main/$SETUP_FILE"
DESKTOP_DIR="$HOME/.local/share/applications"
TARGET_DESKTOP_NAME="MPV-mpv.desktop"

# 🧼 Make sure setup folder exists
mkdir -p "$BOX_HOME/setup"

# 🌐 Download the setup file from GitHub
echo "🌐 Downloading '$SETUP_FILE' from GitHub..."
curl -fsSL "$SETUP_URL" -o "$BOX_HOME/setup/$SETUP_FILE"

# 🕵️ Check for NVIDIA GPU
USE_NVIDIA_FLAG=""

if command -v nvidia-smi &>/dev/null; then
  echo "💻 NVIDIA GPU detected via nvidia-smi!"
  USE_NVIDIA_FLAG="--nvidia"
elif lspci | grep -i 'nvidia' &>/dev/null; then
  echo "💻 NVIDIA GPU detected via lspci!"
  USE_NVIDIA_FLAG="--nvidia"
else
  echo "✨ No NVIDIA GPU detected, thank god..."
fi

# 📦 Create Distrobox with conditional GPU support
echo "📦 Creating Distrobox '$BOX_NAME'..."
distrobox create \
  --name "$BOX_NAME" \
  --image quay.io/toolbx/arch-toolbox:latest \
  --home "$BOX_HOME" \
  $USE_NVIDIA_FLAG

# 🚀 Run setup inside the Distrobox
echo "🚀 Running setup inside Distrobox..."
distrobox enter "$BOX_NAME" -- bash -c "chmod +x ~/setup/$SETUP_FILE && ~/setup/$SETUP_FILE"

# 🖼 Create desktop file
echo "🛠 Now we're going to modify the desktop file to suit our needs!"
mkdir -p "$DESKTOP_DIR"

cat <<EOF >"$DESKTOP_DIR/$TARGET_DESKTOP_NAME"
[Desktop Entry]
Categories=AudioVideo;Audio;Video;Player;TV;
Comment=Play music with mpv
Exec=/usr/bin/distrobox-enter -n mpv-music -- umpv %U
GenericName=Music Player
Icon=mpv
Keywords=mpv;media;player;video;audio;tv;
MimeType=application/ogg;application/x-ogg;application/mxf;application/sdp;application/smil;application/x-smil;application/streamingmedia;application/x-streamingmedia;application/vnd.rn-realmedia;application/vnd.rn-realmedia-vbr;audio/aac;audio/x-aac;audio/vnd.dolby.heaac.1;audio/vnd.dolby.heaac.2;audio/aiff;audio/x-aiff;audio/m4a;audio/x-m4a;application/x-extension-m4a;audio/mp1;audio/x-mp1;audio/mp2;audio/x-mp2;audio/mp3;audio/x-mp3;audio/mpeg;audio/mpeg2;audio/mpeg3;audio/mpegurl;audio/x-mpegurl;audio/mpg;audio/x-mpg;audio/rn-mpeg;audio/musepack;audio/x-musepack;audio/ogg;audio/scpls;audio/x-scpls;audio/vnd.rn-realaudio;audio/wav;audio/x-pn-wav;audio/x-pn-windows-pcm;audio/x-realaudio;audio/x-pn-realaudio;audio/x-ms-wma;audio/x-pls;audio/x-wav;video/mpeg;video/x-mpeg2;video/x-mpeg3;video/mp4v-es;video/x-m4v;video/mp4;application/x-extension-mp4;video/divx;video/vnd.divx;video/msvideo;video/x-msvideo;video/ogg;video/quicktime;video/vnd.rn-realvideo;video/x-ms-afs;video/x-ms-asf;audio/x-ms-asf;application/vnd.ms-asf;video/x-ms-wmv;video/x-ms-wmx;video/x-ms-wvxvideo;video/x-avi;video/avi;video/x-flic;video/fli;video/x-flc;video/flv;video/x-flv;video/x-theora;video/x-theora+ogg;video/x-matroska;video/mkv;audio/x-matroska;application/x-matroska;video/webm;audio/webm;audio/vorbis;audio/x-vorbis;audio/x-vorbis+ogg;video/x-ogm;video/x-ogm+ogg;application/x-ogm;application/x-ogm-audio;application/x-ogm-video;application/x-shorten;audio/x-shorten;audio/x-ape;audio/x-wavpack;audio/x-tta;audio/AMR;audio/ac3;audio/eac3;audio/amr-wb;video/mp2t;audio/flac;audio/mp4;application/x-mpegurl;video/vnd.mpegurl;application/vnd.apple.mpegurl;audio/x-pn-au;video/3gp;video/3gpp;video/3gpp2;audio/3gpp;audio/3gpp2;video/dv;audio/dv;audio/opus;audio/vnd.dts;audio/vnd.dts.hd;audio/x-adpcm;application/x-cue;audio/m3u;audio/vnd.wave;video/vnd.avi;
Name=MPV Music
NoDisplay=false
Path=
StartupNotify=true
StartupWMClass=mpv
Terminal=false
TerminalOptions=
Type=Application
X-KDE-Protocols=appending,file,ftp,hls,http,https,mms,mpv,rtmp,rtmps,rtmpt,rtmpts,rtp,rtsp,rtsps,sftp,srt,srtp,webdav,webdavs
X-KDE-SubstituteUID=false
X-KDE-Username=
EOF

echo "🎉 All done! You can now launch MPV Music from your apps menu or double click any audio file! (be sure to set it as the default audio player!)"
