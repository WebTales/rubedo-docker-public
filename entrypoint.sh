#!/bin/bash
set -e
DEPLOYED=false
if [ "${DEPLOYED}" = "false" ]; then
    if [ -d /var/www/html/rubedo ]; then
        cd /var/www/html/rubedo
        if [ "${VERSION}" != "**None**" ]; then
            git checkout $VERSION
            git pull
        else
            git pull
        fi
    else
        mkdir -p /var/www/html/rubedo
        if [ "${EXTENSIONS_REQUIRES}" = "**None**" ]; then
            unset EXTENSIONS_REQUIRES
        fi
        if [ "${EXTENSIONS_REPOSITORIES}" = "**None**" ]; then
            unset EXTENSIONS_REPOSITORIES
        fi        
        if [ "${VERSION}" != "**None**" ]; then
            git clone -b "$VERSION" https://github.com/WebTales/rubedo.git /var/www/html/rubedo
        else
            git clone -b 3.2.x https://github.com/WebTales/rubedo.git /var/www/html/rubedo
        fi
    fi
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/var/www/html/rubedo
    if [ "${EXTENSIONS_REQUIRES}" ] && [ "${EXTENSIONS_REPOSITORIES}" ]; then
        python /generate-composer-extension.py > /var/www/html/rubedo/composer.extensions.json
    fi
    cd /var/www/html/rubedo/
    php composer.phar config -g github-oauth.github.com "$GITHUB_APIKEY"
    ./rubedo.sh

    sed -i 's#DEPLOYED=false#DEPLOYED=true#g' /entrypoint.sh
fi

mongod --fork --storageEngine wiredTiger --dbpath /var/lib/mongo --logpath /var/log/mongodb.log --directoryperdb
./usr/share/elasticsearch/bin/elasticsearch -d
/usr/sbin/httpd -k start

exec "$@"
