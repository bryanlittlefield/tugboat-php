#!/bin/bash

sleep 4 #This helps the output shopw after the other service logs finsih on startup
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
echo "STEP 1 of 1: Git Repository..."
echo "================================================"

cd /var/www/html
if [ -d ".git" ]; then
    echo "Git Repository Already Exists in /var/www/html"
else
    # No Git Repo Found
    echo "----------------------------------------"
    echo "Github Repo: $GITHUB_REPO_URL"
    echo "Github Repo User: $GITHUB_USER"
    echo "----------------------------------------"

    if [ "$GITHUB_USER" ]; then
        echo "Starting Cloning Process ......"
    	if [ "$GITHUB_USER_PASS" ]; then
            echo "Cloning Private Repo.."
            git clone "https://$GITHUB_USER:$GITHUB_USER_PASS@github.com/$GITHUB_USER/$GITHUB_REPO_URL" .
        else
            echo "Cloning Public Repo.."
            git clone "https://github.com/$GITHUB_USER/$GITHUB_REPO_URL" .
        fi
    else
        echo "No Github credentials were passed. Pulling welcome page.."
        curl -O http://165.227.28.53/introduction.txt && mv introduction.txt index.php
    fi

fi

###########################
#Update User Passwords
###########################
echo ""
echo ""
echo "================================================"
echo "STEP 2 of 3: Updating Passwords"
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
echo "STEP 3 of 3: Starting up the SSH Service        "
echo "================================================"
service ssh start
service ssh restart
echo "================================================"
echo ""
echo ""


echo "================================================"
echo " SETUP COMPLETE!                                "
echo "================================================"
exec apache2-foreground
