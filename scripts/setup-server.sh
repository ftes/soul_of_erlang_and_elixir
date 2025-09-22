#!/bin/sh
apt update

# already installed on ubuntu
# apt install ufw snapd -y

snap install --classic certbot
source /etc/profile # or new shell
certbot certonly --standalone --non-interactive --agree-tos --domains dcon-elixir.ftes.de

ufw --force enable
ufw allow ssh
ufw allow http
ufw allow https

curl -fsSO https://elixir-lang.org/install.sh
sh install.sh elixir@1.18.4 otp@28.1

echo 'export PATH=$HOME/.elixir-install/installs/otp/28.1/bin:$PATH' >> /etc/profile
echo 'export PATH=$HOME/.elixir-install/installs/elixir/1.18.4-otp-27/bin:$PATH' >> /etc/profile
echo "export MIX_ENV=prod" >> /etc/profile
source ~/.bashrc

git clone https://github.com/ftes/soul_of_erlang_and_elixir.git app
cd app
mix local.hex --force
mix deps.get
mix compile
echo "export SECRET_KEY_BASE=`mix phx.gen.secret`" >> ~/.bashrc
source ~/.bashrc
mix assets.deploy
mix release
_build/prod/rel/my_system/bin/my_system daemon
