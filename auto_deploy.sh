#!/bin/bash

# Created by Victor Pinheiro 13/09/2022
# Version 1.0 - It works but under supervisionteset1
# inspired on this blog https://www.iankumu.com/blog/how-to-deploy-laravel-on-apache-server/
# Automate install / challenge repo and configs for the DNX challenge

# Assumes this file has executable permissions
# Assumes it was executed with sudo
# Assumes it have apt package manager installed and updated
# Assumes it got run with sudo
# It will install php7.4 and use the


#TODOS:
# Error handling
# Verifications of packages/folders installed
# automate some prompts like y and enter
# Change the config files to be less hard coded


# Config variables
GIT_REPO="https://github.com/DNXLabs/ChallengeDevOps"
REPO="ChallengeDevOps"
DB="ChallengeDevOps1"

#Update apt repo
echo "Update apt repo"
sudo apt-get update
echo "#########################################################"

#Install curl to download composer with php from the machine
echo "Installing curl"
sudo apt-get install curl -y
echo "#########################################################"

#Install git -- no need config because all public REPO
echo "Installing git"
sudo apt-get install git -y
echo "#########################################################"

# Install apache
echo "Installing Apache"
sudo apt-get install apache2 -y
echo "#########################################################"

# Install MYSQL
echo "Installing MYSQL"
sudo apt-get install mysql-server -y
sudo systemctl start mysql.service
sudo systemctl enable mysql
echo "#########################################################"

# Install PHP 7.4
echo "Installing PHP7.4"
sudo add-apt-repository ppa:ondrej/php
sudo apt update && sudo apt upgrade
sudo apt-get install libapache2-mod-php7.4 php7.4 php7.4-common php7.4-xml php7.4-curl php7.4-mysql php7.4-fpm php7.4-gd php7.4-opcache php7.4-mbstring php7.4-tokenizer php7.4-json php7.4-bcmath php7.4-zip unzip -y
	php -v -y
echo "#########################################################"


# Install composer
echo "Installing Composer"
sudo curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
echo "#########################################################"

# Install mysql secure using root password
# Prompt pwd for root mysql
echo " "
read -p "Please type the password for root mysql (type again when prompt):" PASS
 
# sudo mysql_secure_installation
# Use manual secure installation
# https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script
echo "#########################################################"
sudo mysql -e "CREATE DATABASE $DB;"
echo "DATABASE $DB created"
echo "Please use same password you created above"
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$PASS';"
sudo mysql_secure_installation <<EOF
y
0
N
y
y
y
y
EOF

echo "MYSQL configured"
echo "#########################################################"

# Change config php.ini to 0 and remove ;
echo "Changing PHP7.4"

CONFIG_FILE="/etc/php/7.4/apache2/php.ini"
TARGET_KEY="cgi.fix_pathinfo"
REPLACEMENT_VALUE=0

# https://stackoverflow.com/questions/59838/how-do-i-check-if-a-directory-exists-in-a-bash-shell-script
if [! -f $CONFIG_FILE]
then 
    echo "Could not locate $CONFIG_FILE"
    echo "Please verify if php 7.4 and apache lib for it were corrected installed"
    exit 1
fi

sudo sed -i "/;$TARGET_KEY=/d" $CONFIG_FILE
sudo echo "$TARGET_KEY=$REPLACEMENT_VALUE"  >> $CONFIG_FILE

echo "#########################################################"
# ADD CONFIG TO APACHE
# Assumes apache was installed with success, no error handles
FILE="/etc/apache2/sites-available/laravel.conf"

# https://stackoverflow.com/questions/2953081/how-can-i-write-a-heredoc-to-a-file-in-bash-script
sudo cat > $FILE <<- EOM
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName localhost
    DocumentRoot /var/www/html/laravel/$REPO/public

    <Directory /var/www/html/laravel/$REPO>
    Options Indexes MultiViews
    AllowOverride None
    Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOM

if [! -f $FILE]
then 
    echo "Could not create $FILE"
    echo "Please verify permissions and Apache site-available folder"
    exit 2
else
    echo "$FILE created "
    echo "#########################################################"
fi

# Add config to apache
echo "Config APACHE"
sudo a2enmod rewrite
sudo a2ensite laravel.conf
sudo a2dissite 000-default.conf

# Restart apache
sudo systemctl restart apache2

# INSTALL AND DEPLOY LARAVEL
echo "#########################################################"
echo "Start cloning git"
sudo mkdir "/var/www/html/laravel"
cd "/var/www/html/laravel"
sudo git clone $GIT_REPO
cd "$REPO"

# best practice to install the dependencies
sudo composer install --ignore-platform-reqs --no-plugins --no-scripts
cd "/var/www/html/laravel/$REPO"


# Could copy and use sed/sid commands but this way is simpler and more elegant if you know all the values
sudo cat << EOM > /var/www/html/laravel/$REPO/.env
APP_NAME=Laravel
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_LOG_LEVEL=error
APP_URL=http://localhost

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=$DB
DB_USERNAME="root"
DB_PASSWORD="$PASS"

BROADCAST_DRIVER=log
CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_DRIVER=sync

# Set the allowed domains for CORS.
# Separate each one by a comma.
# Remove or comment to allow all origins.
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:4200
EOM

echo "######################################################################"



# application set up
echo "Generating key, authentication and "
sudo php artisan key:generate
sudo php artisan jwt:generate
sudo php artisan migrate

#Changing permissions for apache to serve
echo "Changing permissions for apache security"
sudo chown -R :www-data /var/www/html/laravel/$REPO
sudo chmod -R 775 /var/www/html/laravel/$REPO
sudo chmod -R 775 /var/www/html/laravel/$REPO/storage
sudo chmod -R 775 /var/www/html/laravel/$REPO/bootstrap/cache

#reload the Apache service
sudo systemctl restart apache2
sudo service apache2 status

echo "Done, please check if it is correct served on port 80 of the public ip :)"