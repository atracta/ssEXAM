# This script creates a user with root permissions, installs Apache, MySQL, PHP, and Laravel, and configures Apache to serve Laravel if needed.
# It takes one argument, which is the node type (master or slave).
# If the script is not run with root permissions, it will exit with an error message.
# If the node type is master, it will create a user with root permissions, install Apache, MySQL, PHP, and Laravel, and configure Apache to serve Laravel.
# If the node type is slave, it will print a message and exit.
#!/bin/bash
NODE_TYPE=$1
# Ensure the script is run with root permissions
if [ "$EUID" -ne 0 ]; then
  echo “Please run as root or with sudo.”
  exit
fi
# Common Process and Softwares
apt-get update
# Give user root permissions for master
if [ "$NODE_TYPE" == "master" ]; then
    # create user
    echo "######### Create Master User ##########"
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
    sudo systemctl enable apache2
    sudo systemctl restart apache2
    # Clone Laravel and install its dependenciesp
    sudo apt install php libapache2-mod-php php-xml php-curl php-mbstring php-xmlrpc php-soap php-gd php-xml php-cli php-zip php-bcmath php-tokenizer php-json php-pear
    sudo apt install php-cli php-mysql mysql-server curl -y
    cd ~
    curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
    HASH=`curl -sS https://composer.github.io/installer.sig`
    echo $HASH
    php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
    echo "mysql-server mysql-server/root_password password rootpass" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password rootpass" | debconf-set-selections
    php -v
    sudo git clone https://github.com/laravel/laravel.git /var/www/laravel
    cd /var/www/laravel
    sudo a2enmod rewrite
    systemctl restart apache2
    sudo chown  -R www-data:www-data /var/www/laravel
    sudo composer install --ignore-platform-req=ext-curl
    sudo -u master cp .env.example /var/www/laravel/.env
    # sudo -u master php artisan key:generate
    # sudo -u master php artisan migrate
    # sudo -u master php artisan db:seed
fi