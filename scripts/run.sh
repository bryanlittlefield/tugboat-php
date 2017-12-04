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
echo "|   ****** Version 2.1.0 - George the Valiant ******     |"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo ""
echo ""
sleep 1

###########################
#GIT REPO OR WELCOME PAGE
###########################
echo "================================================"
echo "STEP 1 of 5: Git Repository..."
echo "================================================"

cd /var/www/html
if [ -d ".git" ]; then
    echo "Git Repository Already Exists in /var/www/html"
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
        if [ -n "$(ls -A /var/www/html)" ]
            then
                echo "Directory contains files or directories, Pull in the Welcome Page"
            else
                echo "Directory Empty, Pull in the Welcome Page"
                curl -O http://165.227.28.53/introduction.txt && mv introduction.txt index.php
        fi
    fi
fi

###########################
#Update User Passwords
###########################
echo ""
echo ""
echo "================================================"
echo "STEP 2 of 5: Updating Passwords"
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

###########################
#Starting up SSH
###########################
echo "================================================"
echo "STEP 3 of 5: Starting up the SSH Service        "
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
echo "STEP 4 of 5: Apache Configurations"
echo "==========================================================="
if [ $INCLUDE_HTPASSWD = true ]; then
    echo "Setup htpasswd.."
    htpasswd -b -c /etc/apache2/.htpasswd $HTPASSWD_USER $HTPASSWD_PASS
    sed -i '16i\\t\tAuthType Basic' /etc/apache2/sites-available/default.conf
    sed -i '17i\\t\tAuthName "Restricted Content"' /etc/apache2/sites-available/default.conf
    sed -i '18i\\t\tAuthUserFile /etc/apache2/.htpasswd' /etc/apache2/sites-available/default.conf
    sed -i '19i\\t\tRequire valid-user' /etc/apache2/sites-available/default.conf

    sed -i '16i\\t\tAuthType Basic' /etc/apache2/sites-available/default-ssl.conf
    sed -i '17i\\t\tAuthName "Restricted Content"' /etc/apache2/sites-available/default-ssl.conf
    sed -i '18i\\t\tAuthUserFile /etc/apache2/.htpasswd' /etc/apache2/sites-available/default-ssl.conf
    sed -i '19i\\t\tRequire valid-user' /etc/apache2/sites-available/default-ssl.conf

    echo "htpasswd setup successfully"
    echo ""
    echo "----------------------------------------"
    echo "htpasswd Login Credentials"
    echo "----------------"
    echo "user: $HTPASSWD_USER"
    echo "pass: $HTPASSWD_PASS"
    echo "----------------------------------------"
fi
echo "================================================"
echo ""
echo ""

###########################
#Custom Files and Scripts
###########################
echo "==========================================================="
echo "STEP 5 of 5: Custom Files and Scripts"
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

echo "================================================"
echo " SETUP COMPLETE!                                "
echo "================================================"
exec apache2-foreground
