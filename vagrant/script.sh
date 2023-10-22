#!/bin/bash
NODE_TYPE=$1
# Ensure the script is run with root permissions
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit
fi
# Common Process and Softwares
apt-get update
# Give user root permissions for master
if [ "$NODE_TYPE" == "master" ]; then
    # create user
    adduser master --disabled-password --gecos ""
    echo "master:password" | chpasswd
    # add root permissions
    sudo usermod -aG sudo master
    echo "master ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/master
    sudo chmod 0440 /etc/sudoers.d/master
    echo "master user has been granted sudo privileges without a password prompt."
    # install apache
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get install -y apache2 software-properties-common

    sudo systemctl enable 
    sudo systemctl restart apache2
    # Clone Laravel and install its dependencies
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update
    sudo apt install php7.4 libapache2-mod-php php-mbstring php-cli php-bcmath php-json php-xml php-zip php-pdo php-common php-tokenizer php-mysql mysql-server

    echo "mysql-server mysql-server/root_password password rootpass" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password rootpass" | debconf-set-selections
    php -v
    sudo git clone https://github.com/laravel/laravel.git /var/www/laravel
    cd /var/www/laravel
    sudo -u master composer install
    sudo -u master cp .env.example .env
    sudo -u master php artisan key:generate
    sudo -u master php artisan migrate
    sudo -u master php artisan db:seed
    # Configure Apache to serve Laravel if needed
    # Install MySQL server and secure it
elif [ "$NODE_TYPE" == "slave" ]; then
   echo "thank you"
fi