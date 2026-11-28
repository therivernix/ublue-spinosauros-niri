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

# Keep Fedora's Niri bindings and use Noctalia for the bar, launcher, and lock.
install -d /etc/niri
niri_config=/etc/niri/config.kdl
sed \
    -e 's/^spawn-at-startup "waybar"$/spawn-at-startup "noctalia"/' \
    -e 's/"Run an Application: fuzzel" { spawn "fuzzel"; }/"Open Noctalia Launcher" { spawn "noctalia" "msg" "panel-toggle" "launcher"; }/' \
    -e 's/"Lock the Screen: swaylock" { spawn "swaylock"; }/"Lock the Screen" { spawn "noctalia" "msg" "session" "lock"; }/' \
    /usr/share/doc/niri/default-config.kdl > "$niri_config"

grep -Fx 'spawn-at-startup "noctalia"' "$niri_config"
grep -F 'spawn "noctalia" "msg" "panel-toggle" "launcher"' "$niri_config"
grep -F 'spawn "noctalia" "msg" "session" "lock"' "$niri_config"
niri --config "$niri_config" validate

systemctl enable greetd.service
systemctl set-default graphical.target

for package in gdm gnome-shell gnome-session mutter xdg-desktop-portal-gnome fuzzel swaylock waybar; do
    if rpm -q "$package"; then
        echo "Unexpected desktop package in image: $package" >&2
        exit 1
    fi
done

systemctl enable podman.socket
