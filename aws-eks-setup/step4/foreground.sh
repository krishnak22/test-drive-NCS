#!/bin/bash

echo "⏳ Getting temporary AWS credentials. Please wait..."

# Wait until credentials are ready
while [ ! -f /root/temp_creds_ready ]; do
  sleep 2
done

# Source the credentials
echo "🔑 Sourcing credentials..."
source /root/temp_creds.sh
echo "✅ Credentials exported successfully!"

