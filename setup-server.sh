#!/bin/sh
apt update
apt install snapd ufw -y
snap install --classic certbot
source ~/.bashrc # or new shell
certbot certonly --standalone --non-interactive --domains dcon-elixir.ftes.de

ufw --force enable
ufw allow ssh
ufw allow http
ufw allow https
