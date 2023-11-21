#!/bin/bash
yum install -y nginx
systemctl start nginx
mkdir /usr/share/nginx/html/${image_name}
curl ${image_url} > /usr/share/nginx/html/${image_name}/${image_name}.jpg