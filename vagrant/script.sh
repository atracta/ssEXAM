
#!/bin/bash

handle_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo."
    exit 1
fi

configure_dns() {
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    service networking restart
}
# Configure DNS
configure_dns
NODE_TYPE=$1
# Common Process and Software
apt-get update
if [ "$NODE_TYPE" == "master" ]; then
    echo "######### Create Master User ##########"
    adduser master --disabled-password --gecos ""
    handle_error "Failed to add master user."
    echo "master:password" | chpasswd
    usermod -aG sudo master
    echo "master ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/master
    chmod 0440 /etc/sudoers.d/master
    echo "master user has been granted sudo privileges without a password prompt."
    # Install apache
    apt-get update && apt-get upgrade -y
    apt-get install -y apache2 software-properties-common
    handle_error "Failed to install apache."
    systemctl enable apache2 && systemctl restart apache2
    # Install PHP and dependencies
    apt-get install -y php libapache2-mod-php php-xml php-curl php-mbstring php-xmlrpc php-soap php-gd php-xml php-cli php-zip php-bcmath php-tokenizer php-json php-pear php-cli php-mysql mysql-server curl git
    handle_error "Failed to install PHP and its dependencies."
    sudo mysql --user=root <<_EOF_
    ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY 'password';
    CREATE DATABASE laravel;
    FLUSH PRIVILEGES;
_EOF_
    handle_error "Failed to setup MySQL."
    # Install composer
    curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
    HASH=$(curl -sS https://composer.github.io/installer.sig)
    if [ "$(php -r "echo hash_file('SHA384', '/tmp/composer-setup.php');")" != "$HASH" ]; then
        echo "Composer installer is corrupt."
        exit 1
    else
        echo "Composer installer is verified."
    fi
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
    # Clone Laravel and install its dependencies
    git clone https://github.com/laravel/laravel.git /var/www/laravel
    handle_error "Failed to clone Laravel."
    sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/' /var/www/laravel/.env
    sed -i 's/^DB_HOST=.*/DB_HOST=127.0.0.1/' /var/www/laravel/.env
    sed -i 's/^DB_PORT=.*/DB_PORT=3306/' /var/www/laravel/.env
    sed -i 's/^DB_DATABASE=.*/DB_DATABASE=laravel/' /var/www/laravel/.env
    sed -i 's/^DB_USERNAME=.*/DB_USERNAME=root/' /var/www/laravel/.env
    sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=password/' /var/www/laravel/.env
    # Set Laravel storage permissions
    sudo chmod -R 775 /var/www/laravel/storage
    sudo chown -R www-data:www-data /var/www/laravel/storage
    sudo a2enmod rewrite && systemctl restart apache2
    sudo chown -R www-data:www-data /var/www/laravel
    # Install Laravel dependencies
    pushd /var/www/laravel
    sudo composer install --ignore-platform-req=ext-curl
    cp .env.example .env
    sudo php artisan key:generate
    sudo php artisan migrate
    php artisan db:seed
    popd
   # Set Up Apache VirtualHost for Laravel
    cat <<EOL > /etc/apache2/sites-available/laravel.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/laravel/public
    <Directory /var/www/laravel/public>
        AllowOverride All
        Order allow,deny
        allow from all
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL
    # Enable the Laravel site and restart Apache
    a2ensite laravel.conf
    sudo systemctl restart apache2
    # Output the IP Address
    IP_ADDRESS=$(ip a | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
    echo "You can access your Laravel application at: http://$IP_ADDRESS"
    # Optionally set up a friendly URL (requires manual step on the host machine)
    echo "For a friendly URL, add the following entry to your host's /etc/hosts (or equivalent):"
    echo "$IP_ADDRESS   laravel.local"
fi
