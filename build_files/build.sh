#!/bin/bash

set -ouex pipefail

# Skip weak dependencies such as Niri's GNOME portal recommendation.
dnf5 -y --setopt=install_weak_deps=False install \
    niri noctalia greetd greetd-selinux \
    alacritty \
    pipewire pipewire-pulseaudio wireplumber \
    xdg-desktop-portal xdg-desktop-portal-gtk tmux

# Use Terra for this install transaction and verify RPM signatures.
dnf5 -y --setopt=install_weak_deps=False \
    --repofrompath 'terra-greeter,https://repos.fyralabs.com/terra$releasever' \
    --setopt='terra-greeter.gpgkey=https://repos.fyralabs.com/terra$releasever/key.asc' \
    --setopt=terra-greeter.gpgcheck=True \
    --setopt=terra-greeter.priority=110 \
    install noctalia-greeter
test -x /usr/bin/noctalia-greeter-session

# Apply image defaults after the packages have installed their configuration.
cp -avf /ctx/system_files/. /

# Use Fedora's packaged Niri configuration as the system default.
install -d /etc/niri
niri_config=/etc/niri/config.kdl
cp /usr/share/doc/niri/default-config.kdl "$niri_config"
niri validate --config "$niri_config"

systemctl --global enable noctalia-niri.service
systemctl enable greetd.service
systemctl set-default graphical.target

for package in gdm gnome-shell gnome-session mutter xdg-desktop-portal-gnome fuzzel swaylock tuigreet waybar; do
    if rpm -q "$package"; then
        echo "Unexpected desktop package in image: $package" >&2
        exit 1
    fi
done

systemctl enable podman.socket
