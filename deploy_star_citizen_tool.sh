#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Constants
APP_NAME="StarCitizenIntel"
APP_DIR="/var/www/$APP_NAME"
PYTHON_VERSION="python3.10"
VENV_DIR="$APP_DIR/venv"
DB_NAME="StarCitizenIntel"
DB_USER="flask_user"
DB_PASSWORD="!3592Wolf"
NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"
NGINX_LINK="/etc/nginx/sites-enabled/$APP_NAME"

# Update and install dependencies
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y $PYTHON_VERSION python3-pip python3-venv mysql-server nginx certbot python3-certbot-nginx git

# Set up MySQL database
echo "Setting up MySQL database..."
sudo mysql -u root -p <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Clone the application
echo "Cloning application repository..."
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR
git clone https://github.com/Cronos011/intel-tool.git $APP_DIR

# Set up Python virtual environment
echo "Setting up Python virtual environment..."
cd $APP_DIR
$PYTHON_VERSION -m venv $VENV_DIR
source $VENV_DIR/bin/activate
pip install -r requirements.txt

# Configure Gunicorn
echo "Configuring Gunicorn..."
cat <<EOF | sudo tee /etc/systemd/system/$APP_NAME.service
[Unit]
Description=Gunicorn instance to serve $APP_NAME
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind unix:$APP_DIR/$APP_NAME.sock app:app

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl start $APP_NAME
sudo systemctl enable $APP_NAME

# Configure Nginx
echo "Configuring Nginx..."
cat <<EOF | sudo tee $NGINX_CONF
server {
    listen 80;
    server_name gwrecon.com;

    location / {
        include proxy_params;
        proxy_pass http://unix:$APP_DIR/$APP_NAME.sock;
    }
}
EOF

sudo ln -s $NGINX_CONF $NGINX_LINK
sudo nginx -t
sudo systemctl restart nginx

# Set up SSL with Certbot
echo "Setting up SSL with Certbot..."
sudo certbot --nginx -d gwrecon.com

# Finalize
echo "Deployment complete! Visit http://gwrecon.com to view the application."
