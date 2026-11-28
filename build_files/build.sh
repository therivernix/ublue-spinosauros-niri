#!/bin/bash

set -ouex pipefail

# Skip weak dependencies such as Niri's GNOME portal recommendation.
dnf5 -y --setopt=install_weak_deps=False install \
    niri noctalia greetd greetd-selinux \
    alacritty \
    pipewire pipewire-pulseaudio wireplumber \
    xdg-desktop-portal xdg-desktop-portal-gtk flatpak tmux

# Use Terra for this install transaction and verify RPM signatures.
# Expand the release here because DNF leaves it literal in the key override.
terra_url="https://repos.fyralabs.com/terra$(rpm -E '%fedora')"
dnf5 -y --setopt=install_weak_deps=False \
    --repofrompath "terra-greeter,$terra_url" \
    --setopt="terra-greeter.gpgkey=$terra_url/key.asc" \
    --setopt=terra-greeter.gpgcheck=True \
    --setopt=terra-greeter.priority=110 \
    install noctalia-greeter
test -x /usr/bin/noctalia-greeter-session

# Apply image defaults after the packages have installed their configuration.
cp -avf /ctx/system_files/. /

# Drop inherited GNOME Flatpak defaults while retaining other preinstall entries.
for manifest in /usr/share/flatpak/preinstall.d/*.preinstall /etc/flatpak/preinstall.d/*.preinstall; do
    [[ -f "$manifest" ]] || continue
    if grep -qE '^[[:space:]]*\[Flatpak Preinstall org\.gnome\.' "$manifest"; then
        filtered_manifest=$(mktemp)
        awk '
            /^[[:space:]]*\[/ { skip = /^[[:space:]]*\[Flatpak Preinstall org\.gnome\./ }
            !skip
        ' "$manifest" > "$filtered_manifest"
        cat "$filtered_manifest" > "$manifest"
        rm "$filtered_manifest"
    fi
done

# Use Fedora's packaged Niri configuration as the system default.
install -d /etc/niri
niri_config=/etc/niri/config.kdl
cp /usr/share/doc/niri/default-config.kdl "$niri_config"
niri validate --config "$niri_config"

systemctl --global enable noctalia-niri.service
systemctl --global enable remove-gnome-flatpaks.service
systemctl enable remove-gnome-flatpaks.service
systemctl enable greetd.service
systemctl set-default graphical.target

for package in gdm gnome-shell gnome-session mutter xdg-desktop-portal-gnome fuzzel swaylock tuigreet waybar; do
    if rpm -q "$package"; then
        echo "Unexpected desktop package in image: $package" >&2
        exit 1
    fi
done

systemctl enable podman.socket
