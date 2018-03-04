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
echo "|   ****** Version $TUGBOAT_VERSION - Emily the Vigorous ******     |"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo ""
echo ""
sleep 1

###########################
#GIT REPO OR WELCOME PAGE
###########################
echo "================================================"
echo "STEP 1 of 7: Git Repository..."
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
echo "STEP 2 of 7: Updating Passwords"
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
echo "STEP 3 of 7: Starting up the SSH Service        "
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
echo "STEP 4 of 7: Apache Configurations"
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
    if [ $WHITELIST_IP  ]; then
        sed -i '20i\\t\tAllow from '${WHITELIST_IP} /etc/apache2/sites-available/default.conf
        sed -i '21i\\t\tsatisfy any' /etc/apache2/sites-available/default.conf
    else
        sed -i '20i\\t\tAllow from all' /etc/apache2/sites-available/default.conf
    fi

    #SSL CONFIG
    sed -i '16i\\t\tAuthType Basic' /etc/apache2/sites-available/default-ssl.conf
    sed -i '17i\\t\tAuthName "Restricted Content"' /etc/apache2/sites-available/default-ssl.conf
    sed -i '18i\\t\tAuthUserFile /etc/apache2/.htpasswd' /etc/apache2/sites-available/default-ssl.conf
    sed -i '19i\\t\tRequire valid-user' /etc/apache2/sites-available/default-ssl.conf
    if [ $WHITELIST_IP ]; then
        sed -i '20i\\t\tAllow from '${WHITELIST_IP} /etc/apache2/sites-available/default-ssl.conf
        sed -i '21i\\t\tsatisfy any' /etc/apache2/sites-available/default-ssl.conf
    else
        sed -i '20i\\t\tAllow from all' /etc/apache2/sites-available/default-ssl.conf
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
    if [ $WHITELIST_IP ]; then
        echo "Whitelist IP:${WHITELIST_IP} found..."

        echo "----------------------------------------"
        echo "!!Allow Incoming Secure Connections from only ${WHITELIST_IP}!!"
        echo "----------------------------------------"
        #Non-Secure
        sed -i '16i\\t\tAllow from '${WHITELIST_IP} /etc/apache2/sites-available/default.conf
        #Secure
        sed -i '16i\\t\tAllow from '${WHITELIST_IP} /etc/apache2/sites-available/default-ssl.conf
    else
        echo "Whitelist IP Not Set In .env file..."
        echo "----------------------------------------"
        echo "!!Allow All Incoming Connections!!"
        echo "----------------------------------------"
        #Non-Secure
        sed -i '16i\\t\tAllow from all' /etc/apache2/sites-available/default.conf
        #Secure
        sed -i '16i\\t\tAllow from all' /etc/apache2/sites-available/default-ssl.conf
    fi
fi
echo "================================================"
echo ""
echo ""

###########################
#Custom Files and Scripts
###########################
echo "==========================================================="
echo "STEP 5 of 7: Custom Files and Scripts"
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
echo "STEP 6 of 7: Set Permissions"
echo "==========================================================="
    mkdir -p $DOCUMENT_ROOT
    chown -R dev:dev $DOCUMENT_ROOT
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
echo "STEP 7 of 7: Install and Configure Webmin"
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


echo "================================================"
echo " SETUP COMPLETE!                                "
echo "================================================"
exec apache2-foreground
