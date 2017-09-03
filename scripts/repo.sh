#!/bin/sh

if [ -z "$GITHUB_USER" ]; then
        git clone https://github.com/$GITHUB_USER/$GITHUB_REPO .
	if [ -z "$GITHUB_USER_PASS" ]; then
        git clone https://$GITHUB_USER:$GITHUB_USER_PASS@github.com/$GITHUB_USER/$GITHUB_REPO .
    else
        git clone https://github.com/$GITHUB_USER/$GITHUB_REPO .
    fi
fi
