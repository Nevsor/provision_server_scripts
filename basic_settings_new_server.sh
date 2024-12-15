#!/bin/bash

# ========== CONFIGURATION ============

SSH_PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPpuuycNjXmHysGn58gMQuUKP5MoWwr2FjUwXgyX5oP sven@stegemann.de'
MY_USER='sven'

echo
echo Settings:
echo SSH_PUBKEY=$SSH_PUBKEY
echo MY_USER=$MY_USER
echo

# ============= CHECKS ================

if [ ! -f "/etc/debian_version" ]; then
   echo 'This script was written for debian servers. It may not work on other distributions.'
   exit 1
fi

if [ "$EUID" -ne 0 ]
  then echo "This script needs to be run as root."
  exit 1
fi

# ========= HELPER FUNCTIONS ==========

as_user() {
  { set +x; } 2>/dev/null
  su $MY_USER -c "$1"
}

as_user_and_root() {
  { set +x; } 2>/dev/null
  as_user "$1"
  eval "$1"
}

awk_inplace() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: awk_inplace <file> <awk_script>"
    exit 1
  fi

  awk "$2" "$1" > "$1.tmpfile" && mv "$1.tmpfile" "$1"
}

# ========== MAIN SCRIPT ==============

set -x

apt update
apt upgrade --assume-yes
apt install --assume-yes zsh sudo neovim git
groupadd ssh_users
useradd $MY_USER --create-home --shell /bin/zsh --groups sudo,ssh_users || usermod -aG sudo,ssh_users $MY_USER --shell /bin/zsh

# Sudo without password for everyone in group 'sudo'
awk_inplace /etc/sudoers '
  /%sudo/ && !/PASSWD/ { sub("ALL)", "ALL) NOPASSWD:") }
  { print }
'

# Set SSH config
awk_inplace /etc/ssh/sshd_config '
  { sub(/^#? ?PermitRootLogin.*$/, "PermitRootLogin no") }
  { sub(/^#? ?PermitEmptyPasswords.*$/, "PermitEmptyPasswords no") }
  { sub(/^#? ?X11Forwarding.*$/, "X11Forwarding no") }
  { sub(/^#? ?AllowGroups.*$/, "AllowGroups ssh_users") }
  {print}
'

grep AllowGroups /etc/ssh/sshd_config || echo 'AllowGroups ssh_users' >> /etc/ssh/sshd_config

as_user_and_root 'mkdir ~/.config'
as_user 'mkdir ~/.ssh'

as_user "grep $SSH_PUBKEY ~/.ssh/authorized_keys || echo $SSH_PUBKEY > ~/.ssh/authorized_keys"
as_user_and_root "grep 'export EDITOR=nvim' ~/.config/environment || echo 'export EDITOR=nvim' >> ~/.config/environment"
as_user_and_root "grep 'export VISUAL=nvim' ~/.config/environment || echo 'export VISUAL=nvim' >> ~/.config/environment"
as_user_and_root "grep 'source ~/.config/environment' ~/.zshrc || echo 'source ~/.config/environment' >> ~/.zshrc"

chsh -s /bin/zsh

set +x
echo '+ curl -sS https://starship.rs/install.sh | sh'
curl -sS https://starship.rs/install.sh | sh
echo + as_user_and_root \""echo 'eval \"\$(starship init zsh)\"' >> ~/.zshrc"\"
as_user_and_root "echo 'eval \"\$(starship init zsh)\"' >> ~/.zshrc"
set -x
as_user_and_root 'touch ~/.config/starship.toml && grep add_newline ~/.config/starship.toml || sed -i "1i add_newline = false" ~/.config/starship.toml'

systemctl restart sshd

set +x

printf "\nYou can now login via SSH as $MY_USER.\n"
printf "Reboot the server if necessary.\n"
