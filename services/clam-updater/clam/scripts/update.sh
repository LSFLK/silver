// TODO, need to remove this file once we have a proper clamav update server.
SERVER="http://<IP>:8800"
DEST="/var/lib/clamav"

echo "Downloading signatures from $SERVER..."

wget -O $DEST/main.cld $SERVER/main.cld
wget -O $DEST/daily.cld $SERVER/daily.cld  
wget -O $DEST/bytecode.cvd $SERVER/bytecode.cvd

echo "Download complete at $(date)"