#!/bin/bash
yum install -y nginx
systemctl start nginx
curl ${image_url} > /usr/share/nginx/html/${image_name}.jpg
