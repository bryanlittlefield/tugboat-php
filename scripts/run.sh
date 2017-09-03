#!/bin/bash

sleep 4 #This helps the output shopw after the other service logs finsih on startup
echo ""
echo ""
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "$Initializing Startup Scripts"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo ""
echo ""

###########################
#GIT REPO
###########################
echo "================================================"
echo "Starting Git Repo Process..."
echo "================================================"
echo "Github Repo: $GITHUB_REPO_URL"
echo "Github Repo User: $GITHUB_USER"
echo "Github Repo Pass: $GITHUB_USER_PASS"

if [ "$GITHUB_USER" ]; then
    echo "Starting Cloning Process ......"
	if [ "$GITHUB_USER_PASS" ]; then
        echo "Identified as a Private Repo"
        git clone "https://$GITHUB_USER:$GITHUB_USER_PASS@github.com/$GITHUB_USER/$GITHUB_REPO_URL"
    else
        echo "Identified as a Public Repo"
        git clone "https://github.com/$GITHUB_USER/$GITHUB_REPO_URL"
    fi
fi

###########################
#Update User Passwords
###########################
echo ""
echo ""
echo "================================================"
echo "Updating Passwords for Root and Dev User"
echo "================================================"
echo "dev:$DEV_USER_PASS" | chpasswd
echo "root:$ROOT_USER_PASS" | chpasswd
echo ""
echo "Passwords have been updated successfully!"
echo "Login as root user with $ROOT_USER_PASS"
echo "Login as dev user with $DEV_USER_PASS"
echo "You can SSH in by using the following command: ssh -p2222 dev@127.0.0.1"
echo "================================================"
echo ""
echo ""

service ssh start
service ssh restart
exec apache2-foreground
