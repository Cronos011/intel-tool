#!/bin/bash
set -e

APP_NAME="StarCitizenIntel"
APP_DIR="/var/www/$APP_NAME"
DB_NAME="StarCitizenIntel"
DB_USER="flask_user"
DB_PASSWORD="!3592Wolf"

# Install dependencies
sudo apt update && sudo apt install -y python3 python3-pip python3-venv mysql-server nginx

# Set up MySQL
sudo mysql -u root -p <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Clone repository
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR
git clone https://github.com/Cronos011/intel-tool.git $APP_DIR

# Set up Python environment
cd $APP_DIR
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configure Gunicorn
sudo tee /etc/systemd/system/$APP_NAME.service > /dev/null <<EOF
[Unit]
Description=Gunicorn instance to serve $APP_NAME
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 3 --bind unix:$APP_DIR/$APP_NAME.sock app:app

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl start $APP_NAME
sudo systemctl enable $APP_NAME

# Configure Nginx
sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null <<EOF
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        include proxy_params;
        proxy_pass http://unix:$APP_DIR/$APP_NAME.sock;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled
sudo nginx -t
sudo systemctl restart nginx
