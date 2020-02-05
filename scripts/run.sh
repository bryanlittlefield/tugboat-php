#!/bin/bash

sleep 4 #This helps the output show after the other service logs finish on startup
echo ""
echo ""
echo " _____   _   _    ____   ____     ___       _      _____ "
echo "|_   _| | | | |  / ___| | __ )   / _ \     / \    |_   _|"
echo "  | |   | | | | | |  _  |  _ \  | | | |   / _ \     | |  "
echo "  | |   | |_| | | |_| | | |_) | | |_| |  / ___ \    | |  "
echo "  |_|    \___/   \____| |____/   \___/  /_/   \_\   |_|  "
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "|   ****** Version $TUGBOAT_VERSION - The Dispatcher ******     |"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo ""
echo ""
sleep 1

###########################
#GIT REPO OR WELCOME PAGE
###########################
echo "================================================"
echo "STEP 1 of 9: Git Repository..."
echo "================================================"

cd $DOCUMENT_ROOT
if [ -d ".git" ]; then
    echo "Git Repository Already Exists in $DOCUMENT_ROOT"
else
    # No Git Repo Found
    echo "----------------------------------------"
    echo "Github Repo: $GITHUB_REPO_NAME"
    echo "Github Repo User: $GITHUB_USER"
    echo "----------------------------------------"

    if [ "$GITHUB_USER" ]; then
        echo "Starting Cloning Process ......"
    	if [ "$GITHUB_USER_PASS" ]; then
            echo "Cloning Private Repo.."
            git clone "https://$GITHUB_USER:$GITHUB_USER_PASS@github.com/$GITHUB_USER/$GITHUB_REPO_NAME" .
        else
            echo "Cloning Public Repo.."
            git clone "https://github.com/$GITHUB_USER/$GITHUB_REPO_NAME" .
        fi
    else
        echo "No Github credentials were passed. Check if the Directory is empty to pull in the welcome page.."
        if [ -n "$(ls -A $DOCUMENT_ROOT)" ]
            then
                echo "Directory contains files or directories."
            else
                echo "Directory Empty"
                # curl -O http://165.227.28.53/introduction.txt && mv introduction.txt index.php
        fi
    fi
fi
echo "================================================"
echo ""
echo ""

###########################
#Update User Passwords
###########################
echo "================================================"
echo "STEP 2 of 9: Updating Passwords"
echo "================================================"
echo "dev:$DEV_USER_PASS" | chpasswd
echo "root:$ROOT_USER_PASS" | chpasswd
echo ""
echo "Passwords have been updated successfully!"
echo ""
echo "----------------------------------------"
echo "Login as root user with $ROOT_USER_PASS"
echo "Login as dev user with $DEV_USER_PASS"
echo "----------------------------------------"
echo ""
echo "You can SSH into this container by using the following command: ssh -p2222 dev@127.0.0.1"
echo ""
echo "SFTP Credentials"
echo "----------------"
echo "host: 127.0.0.1"
echo "port: 2222"
echo "user: root"
echo "passsword: $ROOT_USER_PASS"
echo "host: 127.0.0.1"
echo "port: 2222"
echo "user: dev"
echo "passsword: $DEV_USER_PASS"
echo "================================================"
echo ""
echo ""

###########################
#Starting up SSH
###########################
echo "================================================"
echo "STEP 3 of 9: Starting up the SSH Service        "
echo "================================================"
service ssh start
service ssh restart
echo "================================================"
echo ""
echo ""

###########################
#Reload Apache
###########################
echo "==========================================================="
echo "STEP 4 of 9: Apache Configurations"
echo "==========================================================="
if [ $INCLUDE_HTPASSWD = true ]; then
    echo "Setup htpasswd.."

    #Generate htpasswd
    htpasswd -b -c /etc/apache2/.htpasswd $HTPASSWD_USER $HTPASSWD_PASS

    #Setup Non-Secure Configuration
    sed -i '16i\\t\tAuthType Basic' /etc/apache2/sites-available/default.conf
    sed -i '17i\\t\tAuthName "Restricted Content"' /etc/apache2/sites-available/default.conf
    sed -i '18i\\t\tAuthUserFile /etc/apache2/.htpasswd' /etc/apache2/sites-available/default.conf
    sed -i '19i\\t\tRequire valid-user' /etc/apache2/sites-available/default.conf
    if [ -z $WHITELIST_IP  ]; then
        sed -i '20i\\t\tAllow from all' /etc/apache2/sites-available/default.conf
    else
        sed -i '20i\\t\tAllow from '${WHITELIST_IP} /etc/apache2/sites-available/default.conf
        sed -i '21i\\t\tsatisfy any' /etc/apache2/sites-available/default.conf
    fi

    #SSL CONFIG
    sed -i '16i\\t\tAuthType Basic' /etc/apache2/sites-available/default-ssl.conf
    sed -i '17i\\t\tAuthName "Restricted Content"' /etc/apache2/sites-available/default-ssl.conf
    sed -i '18i\\t\tAuthUserFile /etc/apache2/.htpasswd' /etc/apache2/sites-available/default-ssl.conf
    sed -i '19i\\t\tRequire valid-user' /etc/apache2/sites-available/default-ssl.conf
    if [ -z $WHITELIST_IP ]; then
        sed -i '20i\\t\tAllow from all' /etc/apache2/sites-available/default-ssl.conf
    else
        sed -i '20i\\t\tAllow from '${WHITELIST_IP} /etc/apache2/sites-available/default-ssl.conf
        sed -i '21i\\t\tsatisfy any' /etc/apache2/sites-available/default-ssl.conf
    fi
    echo "htpasswd setup successfully"
    echo ""
    echo "----------------------------------------"
    echo "htpasswd Login Credentials"
    echo "----------------"
    echo "user: $HTPASSWD_USER"
    echo "pass: $HTPASSWD_PASS"
    echo "----------------------------------------"
    echo "Whitelist IP:${WHITELIST_IP} found..."
    echo "----------------------------------------"
    echo "!!Allow Incoming Connections from only ${WHITELIST_IP}!!"
    echo "----------------------------------------"
#If not htpasswd is set skip
else
    echo "Skipping htpasswd..."

    #Check for IPs to Whitelist
    echo "Checking for Whitelist IP..."
    if [ -z $WHITELIST_IP ]; then
        echo "Whitelist IP Not Set In .env file..."
        echo "----------------------------------------"
        echo "!!Allow All Incoming Connections!!"
        echo "----------------------------------------"
        #Non-Secure
        sed -i '16i\\t\tAllow from all' /etc/apache2/sites-available/default.conf
        #Secure
        sed -i '16i\\t\tAllow from all' /etc/apache2/sites-available/default-ssl.conf
    else
        echo "Whitelist IP:${WHITELIST_IP} found..."

        echo "----------------------------------------"
        echo "!!Allow Incoming Secure Connections from only ${WHITELIST_IP}!!"
        echo "----------------------------------------"
        #Non-Secure
        sed -i '16i\\t\tAllow from '${WHITELIST_IP} /etc/apache2/sites-available/default.conf
        #Secure
        sed -i '16i\\t\tAllow from '${WHITELIST_IP} /etc/apache2/sites-available/default-ssl.conf
    fi
fi
echo "================================================"
echo ""
echo ""

###########################
#Custom Files and Scripts
###########################
echo "==========================================================="
echo "STEP 5 of 9: Custom Files and Scripts"
echo "==========================================================="
if [ $BUILD_FILES = true ]; then
    cd /usr/local/bin/build-files
    if [ -f "build.sh" ]; then
        echo "build.sh script found! Running script..."
        echo "==========================================================="
        sh /usr/local/bin/build-files/build.sh
    else
        echo "build.sh script NOT found! Skipping script..."
    fi
else
    echo "BUILD_FILES Environment Variable set to False. Skipping Container Build Scripts..."
fi
echo ""
echo ""

###########################
#Custom Files and Scripts
###########################
echo "==========================================================="
echo "STEP 6 of 9: Set Permissions"
echo "==========================================================="
    mkdir -p $DOCUMENT_ROOT
    if [ $SKIP_PERMISSIONS = true ]; then
        echo "Skipping Permissions Reset on Build.."
    else
        echo "Resetting Permissions in $DOCUMENT_ROOT.."
        echo "-----------"
        echo ""
        find $DOCUMENT_ROOT -type d -exec chmod $DIRECTORY_PERMISSION {} \;
        echo "Directory Permissions: $DIRECTORY_PERMISSION"
        echo ""
        find $DOCUMENT_ROOT -type f -exec chmod $FILE_PERMISSION {} \;
        echo "File Permissions: $FILE_PERMISSION"
    fi
echo ""
echo ""


###########################
#Custom Files and Scripts
###########################
echo "==========================================================="
echo "STEP 7 of 9: Install and Configure Webmin"
echo "==========================================================="
if [ $USE_WEBMIN = true ]; then
    echo "Starting Webmin Installation..."
    rm /etc/apt/apt.conf.d/docker-gzip-indexes
    cd /root
    wget http://www.webmin.com/jcameron-key.asc
    apt-key add jcameron-key.asc
    echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list
    echo "deb http://webmin.mirror.somersettechsolutions.co.uk/repository sarge contrib" >> /etc/apt/sources.list
    apt-get update
    apt-get -y install webmin
    service webmin start
    echo "Webmin Succesfully Installed"
    echo "----------------------------------------a"
    echo "Access URL: my.site.address:10000"
    echo "----------------------------------------"
else
    echo "Skipping Webmin Installation..."
fi
echo ""
echo ""

###########################
# Generate Private Key
###########################
echo "==========================================================="
echo "STEP 8 of 9: Generate SSL CERT"
echo "==========================================================="
echo "Setting up Self-Signed Cert.."
openssl genrsa -des3 -passout pass:xxxx -out server.pass.key 2048 && \
openssl rsa -passin pass:xxxx -in server.pass.key -out $SSL_CERTIFICATE_KEY_FILE && \
rm server.pass.key && \
openssl req -new -key $SSL_CERTIFICATE_KEY_FILE -out /etc/apache2/ssl/server.csr -extensions SAN -reqexts SAN  \
   -subj "/C=US/ST=Washington/L=SEA/O=coolblue/OU=IT Department/CN=$SERVER_NAME" \
   -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:$SERVER_NAME")) && \
openssl x509 -req -days 365 -in /etc/apache2/ssl/server.csr -signkey $SSL_CERTIFICATE_KEY_FILE -out $SSL_CERTIFICATE_FILE
if [ $SSL_CERT_TYPE = "CERTBOT" ]; then

    echo "Run the following Command to Finish the Installation of your LetsEncrypt SSL SHA-2 Cert via CertBot "
    echo "-----------------------------------"
    echo "1) Log into Docker Host and run:"
    echo "docker exec -it ${PROJECT_NAME}_web sh /usr/local/bin/tugboat-cert/certbot.sh && docker kill --signal='USR1' ${PROJECT_NAME}_web"
    echo ""
    echo "2) Confirm your CERT is ready by going to your following domain: $SERVER_NAME and confirming that it is secure"
    echo "-----------------------------------"

    cd /etc/ssl
    echo "Run the following Command to Finish the Installation of your LetsEncrypt SSL SHA-2 Cert via CertBot " >> ssl-tugboat-instructions.txt
    echo "-----------------------------------" >> ssl-tugboat-instructions.txt
    echo "1) Log into Docker Host and run:" >> ssl-tugboat-instructions.txt
    echo "docker exec -it ${PROJECT_NAME}_web sh /usr/local/bin/tugboat-cert/certbot.sh && docker kill --signal='USR1' ${PROJECT_NAME}_web" >> ssl-tugboat-instructions.txt
    echo "" >> ssl-tugboat-instructions.txt
    echo "2) Confirm your CERT is ready by going to your following domain: $SERVER_NAME and confirming that it is secure" >> ssl-tugboat-instructions.txt
    echo "-----------------------------------" >> ssl-tugboat-instructions.txt
fi
echo ""
echo ""

###########################
# XDEBUG
###########################
echo "==============================================================="
echo "STEP 9 of 10: Install XDEBUG"
echo "==============================================================="
if [ $XDEBUG = "TRUE" ]; then
    echo "XDEBUG Set to TRUE in .env file, Installing XDEBUG.."
    pecl install xdebug
    echo "Installation Complete.. Configuring XDEBUG"
    XDEBUG_SO="$(command find '/usr/local/lib/php' -name 'xdebug.so' | command head -n 1)"
    echo "" >> "${PHP_INI_DIR}/php.ini"
    echo "" >> "${PHP_INI_DIR}/php.ini"
    echo ";;;;;;;;;;;;;;;;;" >> "${PHP_INI_DIR}/php.ini"
    echo "; xDebug ;" >> "${PHP_INI_DIR}/php.ini"
    echo ";;;;;;;;;;;;;;;;;" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.remote_enable=1" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.default_enable=1" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.remote_autostart=1" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.remote_host=127.0.0.1" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.remote_port=9000" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.remote_handler=dbgp" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.remote_mode=req" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.var_display_max_children=256" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.var_display_max_data=1024" >> "${PHP_INI_DIR}/php.ini"
    echo "xdebug.var_display_max_depth=5" >> "${PHP_INI_DIR}/php.ini"
    echo "zend_extension=${XDEBUG_SO}" >> "${PHP_INI_DIR}/php.ini"
    echo "XDEBUG Configured and Installed! Use Port 9000 to connect"
else
    echo "Skipping Installation of XDEBUG. YOu can turn this on by changing the XDEBUG env to TRUE in the .env file"
fi
echo ""
echo ""

###########################
# Unset ENV Vars
###########################
echo "==============================================================="
echo "STEP 10 of 10: Unset ENV Vars that contian paswords for security"
echo "==============================================================="
unset HTPASSWD_USER
unset HTPASSWD_PASS
unset ROOT_USER_PASS
unset DEV_USER_PASS
unset MYSQL_ROOT_PASSWORD
unset MYSQL_DATABASE
unset MYSQL_USER
unset MYSQL_PASSWORD
echo ""
echo ""


echo "================================================"
echo " SETUP COMPLETE!                                "
echo "================================================"
exec apache2-foreground