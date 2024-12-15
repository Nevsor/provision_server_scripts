#!/bin/sh

SSH_PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPpuuycNjXmHysGn58gMQuUKP5MoWwr2FjUwXgyX5oP sven@stegemann.de'
USERNAME='sven'

set -o xtrace

if [ ! -f "/etc/debian_version" ]; then
   echo 'This script was written for debian servers. It may not work on other distributions.'
fi

apt update
apt upgrade --assume-yes
apt install --assume-yes zsh sudo neovim
groupadd ssh_users
useradd $USERNAME --create-home --shell /bin/zsh --groups sudo,ssh_users || usermod -aG sudo,ssh_users $USERNAME --shell /bin/zsh

# Sudo without password for everyone in group 'sudo'
awk '
/%sudo/ && !/PASSWD/ { sub("ALL)", "ALL) NOPASSWD:") }
{ print }
' /etc/sudoers > /etc/sudoers.new
mv /etc/sudoers.new /etc/sudoers

# Set SSH config
awk '
{ sub(/^#? ?PermitRootLogin.*$/, "PermitRootLogin no") }
{ sub(/^#? ?PermitEmptyPasswords.*$/, "PermitEmptyPasswords no") }
{ sub(/^#? ?X11Forwarding.*$/, "X11Forwarding no") }
{ sub(/^#? ?AllowGroups.*$/, "AllowGroups ssh_users") }
{print}
' /etc/ssh/sshd_config > /etc/ssh/sshd_config.new
mv /etc/ssh/sshd_config.new /etc/ssh/sshd_config
grep AllowGroups /etc/ssh/sshd_config || echo 'AllowGroups ssh_users' >> /etc/ssh/sshd_config


su $USERNAME -c "mkdir ~/.config ~/.ssh"
su $USERNAME -c "echo $SSH_PUBKEY > ~/.ssh/authorized_keys"
su $USERNAME -c "echo 'export EDITOR=nvim' >> ~/.config/environment"
su $USERNAME -c "echo 'export VISUAL=nvim' >> ~/.config/environment"
su $USERNAME -c "echo 'source ~/.config/environment' >> ~/.zshrc"

printf "\nYou can now login per SSH as $USERNAME.\n"
