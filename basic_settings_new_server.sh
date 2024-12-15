#!/bin/sh

$SSH_PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPpuuycNjXmHysGn58gMQuUKP5MoWwr2FjUwXgyX5oP sven@stegemann.de'
$USERNAME='sven'

set -o xtrace

if [ ! -f "/etc/debian_version" ]; then
   printf 'This script was written for debian servers. It may not work on other distributions.'
fi

as_user()
{
    su $USERNAME -c \'$1\'
}

apt update
apt upgrade --assume-yes
apt install --assume-yes zsh sudo neovim
useradd $USERNAME --create-home --shell /bin/zsh --groups sudo

# Sudo without password for everyone in group 'sudo'
sed -i /%sudo/s/'ALL)'/'ALL) NOPASSPW:'/g /etc/sudoers

as_user("mkdir ~/.config ~/.ssh")
as_user("echo $SSH_PUBKEY > ~/.ssh/authorized_keys")
as_user("echo 'export EDITOR=nvim' >> ~/.config/environment")
as_user("echo 'export VISUAL=nvim' >> ~/.config/environment")
as_user("echo 'source ~/.config/environment' >> ~/.zshrc")

printf "You can now login per SSH as $USERNAME."
