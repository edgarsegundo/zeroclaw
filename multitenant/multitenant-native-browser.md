# Build the native browser image no VPS via SSH
cd /opt/zeroclaw
docker build -f Dockerfile.native-browser -t zeroclaw-native-browser:latest --target release .

# Start shared chromedriver
docker run -d --name chromedriver -p 9515:4444 selenium/standalone-chrome:latest

# Update tenant setup to use new image
# Edit setup-tenant.sh line with ZEROCLAW_IMAGE to use zeroclaw-native-browser:latest