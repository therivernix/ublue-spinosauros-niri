#!/bin/bash

set -ouex pipefail

# Skip weak dependencies such as Niri's GNOME portal recommendation.
dnf5 -y --setopt=install_weak_deps=False install \
    niri noctalia greetd greetd-selinux tuigreet \
    alacritty \
    pipewire pipewire-pulseaudio wireplumber \
    xdg-desktop-portal xdg-desktop-portal-gtk tmux

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

for package in gdm gnome-shell gnome-session mutter xdg-desktop-portal-gnome fuzzel swaylock waybar; do
    if rpm -q "$package"; then
        echo "Unexpected desktop package in image: $package" >&2
        exit 1
    fi
done

systemctl enable podman.socket
