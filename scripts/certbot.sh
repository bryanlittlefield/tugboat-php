#!/bin/bash
echo "Setting up SSL Cert with Certbot..."
echo "-----------------------------------"
echo "Server Name: ${SERVER_NAME}"
echo "Web Root: $WEB_ROOT"
echo "SSL Email: $SSL_EMAIL"
echo ""
echo "Generating Certificate..."
certbot --webroot certonly --non-interactive --agree-tos --domains $SERVER_NAME --webroot-path $WEB_ROOT --email $SSL_EMAIL
echo ""
echo "Configuring Apache..."
sed -i '57d' /etc/apache2/sites-available/default-ssl.conf
sed -i '48d' /etc/apache2/sites-available/default-ssl.conf
sed -i '47d' /etc/apache2/sites-available/default-ssl.conf
sed -i '47i\\t\tSSLCertificateFile /etc/letsencrypt/live/'${SERVER_NAME}'/cert.pem' /etc/apache2/sites-available/default-ssl.conf
sed -i '48i\\t\tSSLCertificateKeyFile /etc/letsencrypt/live/'${SERVER_NAME}'/privkey.pem' /etc/apache2/sites-available/default-ssl.conf
sed -i '57i\\t\tSSLCertificateChainFile /etc/letsencrypt/live/'${SERVER_NAME}'/chain.pem' /etc/apache2/sites-available/default-ssl.conf
echo ""
echo "Success!!!"
echo "-----------------------------------"
