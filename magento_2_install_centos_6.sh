#!/bin/bash
#
## Automatic Magento2 beta with sample data original install on CentOS 6.x
#
# Written by algostore.com (http://www.algostore.com)
#
#
# PURPOSE: This Bash script can be used to take automatic install of your Magento2 beta. Script process:
# - PHP version check
# - MySQL version check
# - presense of composer, if absent - script install it
# - presense of git, if absent - script install it
# - git clone magento2.git
# - change permissions on cloned project
# - change apache user shell & pass
# - configure composer access to github.com if TOKEN provided
# - install & configure Magento2 project with composer using sample data
# - sets always_populate_raw_post_data = -1 in php.ini if PHP version >= 5.6.0
# - nginx.conf.sample configuring for php-fpm+nginx (this part of script could be cutted if it does not needed) 
#
# DISCLAIMER: Make sure that you undestand how the script works. No responsibility accepted in event of accidental data loss.
#
# You can use it for free under gnu gpl v2
# v1.1  2015

TOKEN= #40 symbols, It will be stored in "/var/www/.composer/auth.json" for future use by Composer. If you run script first time - leave it empty.
dbname=magento2       #magento database name will be created
dbuser=magento2       #magento database user will be created
dbpass=123456         #magento database password will be created
dbrootpass=123456     #database root password to making user/password and database for magento installation
#baseurl=$dbname
baseurl=example.com
basepath=/var/www/html/
apachepass=123456     #password that would be set for apache user
################magento_sample_data_credentials################
FIRSTNAME=Darth       #required
LASTNAME=Vader        #required
ADMIN_EMAIL=admin@example.com   #required
ADMIN_USER=admin      #required
ADMIN_PASSWORD=123456   #required
LANG=en_US            #required
CURRENCY=EUR          #required
TZ=Europe/Amsterdam   #required
MSDV=1.0.0-beta       #magento sample data version http://packages.magento.com/#magento/sample-data

function php_version_compare() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"; }
installed_php_ver=`php -v |grep -Eow '^PHP [^ ]+' |gawk '{ print $2 }'`
req_php_ver=5.5.0
if php_version_compare $installed_php_ver $req_php_ver; then
    echo "Current PHP version ($installed_php_ver) is greater or equal than required version ($req_php_ver), continue installation..."
    else
    echo "Current PHP version ($installed_php_ver)  does not satisfy minimum required version ($req_php_ver) Magento2 installation  will fail! So, exit installation..."
    exit
fi
function mysql_version_compare() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"; }
installed_mysql_ver=`mysql -V|awk '{ print $5 }'|awk -F\, '{ print $1 }'`
req_mysql_ver=5.6.0
if mysql_version_compare $installed_mysql_ver $req_mysql_ver; then
    echo "Current MySQL version ($installed_mysql_ver) is greater or equal than required version ($req_mysql_ver), continue installation..."
    else
    echo "Current MySQL version ($installed_mysql_ver)  does not satisfy minimum required version ($req_mysql_ver) Magento2 installation  will fail! So, exit installation..."
    exit
fi

if ! which composer > /dev/null; then
    echo "composer not present, installing it ..."
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
fi
if ! rpm -qa | grep -qw git; then
     echo "git not present, installing it ..."
     yum install git -y
fi
echo "going to $basepath$baseurl & git clone magento2 files..."
cd $basepath && git clone https://github.com/magento/magento2.git "$basepath""$baseurl"
echo "changing permissions to apache & d 700 f 600 $basepath$baseurl"
cd $basepath$baseurl && chown -R apache:apache . && find . -type d -exec chmod 755 {} \; && find . -type f -exec chmod 755 {} \;
echo "changing apache user shell & pass... "
/usr/bin/chsh -s /bin/bash apache && echo "$apachepass" | passwd "apache" --stdin
echo "creating .composer folder in /var/www/"
cd /var/www/ && mkdir .composer && chown -R apache:apache /var/www/.composer
echo "add TOKEN to composer storage"
su - apache -c " composer config --global github-oauth.github.com $TOKEN"
echo "start composer installing in $basepath$baseurl directory"
su - apache -c "cd $basepath$baseurl/ && composer install"
echo "adding minimum-stability beta in  $basepath$baseurl/composer.json"
cd $basepath$baseurl && sed -i '/"type": "project",/a \    "minimum-stability": "beta",' composer.json
echo "composer configuration from repositories.magento composer http://packages.magento.com"
su - apache -c "cd $basepath$baseurl/ && composer config repositories.magento composer http://packages.magento.com"
MSDV1=`curl -sS http://packages.magento.com/#magento/sample-data |grep magento_sample-data-[0-9] |awk '{ print $2 }'|awk -F\.zip '{ print $1 }'|awk -F\magento_sample-data- '{ print $2 }'`
echo "current magento sample data version is $MSDV1"
echo "but set composer require magento/sample-data $MSDV from script presets"
su - apache -c "cd $basepath$baseurl/ && composer require magento/sample-data:$MSDV"

function php_version_compare() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"; }
installed_php_ver=`php -v |grep -Eow '^PHP [^ ]+' |gawk '{ print $2 }'`
req_php_ver=5.6.0
if php_version_compare $installed_php_ver $req_php_ver; then
    echo "Current PHP version ($installed_php_ver) is greater or equal than version ($req_php_ver) So apply special php.ini setting"
    sed -i 's/#always_populate_raw_post_data = -1/always_populate_raw_post_data = -1/g' /etc/php.ini
    service php-fpm restart
    else
    echo "Current PHP version ($installed_php_ver)  seems lower than ($req_php_ver)  So no additional actions required, continue..."
fi
echo "creating db $dbname & user $dbuser"
MYSQL=`which mysql`
P1="CREATE DATABASE IF NOT EXISTS $dbname;"
P2="GRANT ALL ON *.* TO '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
P3="FLUSH PRIVILEGES;"
SQL="${P1}${P2}${P3}"
$MYSQL -uroot -p$dbrootpass -e "$SQL"

su - apache -c "cd $basepath$baseurl &&   php bin/magento setup:install --base-url=http://$baseurl/ \
--backend-frontname=admin --db-host=localhost --db-name=$dbname \
--db-user=$dbuser --db-password=$dbpass \
--admin-firstname=$FIRSTNAME --admin-lastname=$LASTNAME --admin-email=$ADMIN_EMAIL \
--admin-user=$ADMIN_USER --admin-password=$ADMIN_PASSWORD --language=$LANG \
--currency=$CURRENCY --timezone=$TZ --use-sample-data"
echo "changing permissions $basepath$baseurl/app/etc "
chmod 500 $basepath$baseurl/app/etc #For security, remove write permissions from these directories

################additional_nginx.conf.sample_configuring_for_php_fpm################

bp=`echo "$basepath" | sed 's#/#\\\/#g'`
cp $basepath$baseurl/nginx.conf.sample /etc/nginx/conf.d/$baseurl.conf
sed -i 's/# Magento Vars//g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/# set $MAGE_ROOT \/path\/to\/magento\/root;//g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/# set $MAGE_MODE default; # or production or developer//g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/# Example configuration:/ /g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/# upstream fastcgi_backend {/  upstream fastcgi_backend {/g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/#    # use tcp connection//g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/#    # server  127.0.0.1:9000;//g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/#    # or socket/ /g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/#    server   unix:\/var\/run\/php5-fpm.sock;/    server   unix:\/tmp\/php5-fpm.sock;/g' /etc/nginx/conf.d/$baseurl.conf
sed -i '/    server   unix:\/tmp\/php5-fpm.sock;/a \  \}' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/# \}/ /g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/# server {/ server {/g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/#    listen 80;/    listen 80;/g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/#    server_name mage.dev;/    server_name '$baseurl';/g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/#    set $MAGE_ROOT \/var\/www\/magento2;/    set $MAGE_ROOT '$bp$baseurl';/g' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/#    set $MAGE_MODE developer;/    set $MAGE_MODE developer;/g' /etc/nginx/conf.d/$baseurl.conf
#sed -i '/    set $MAGE_MODE developer;/a \  \}' /etc/nginx/conf.d/$baseurl.conf
sed -i 's/#    include \/vagrant\/magento2\/nginx.conf.sample;//g' /etc/nginx/conf.d/$baseurl.conf
echo } >> /etc/nginx/conf.d/$baseurl.conf
service nginx restart
