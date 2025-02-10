#!/bin/bash

echo "Getting your temporary credentials. Please wait..."

# Run the background script
bash /test-drive/aws-eks/step4/background.sh &

# Wait for the credentials file to be ready
while [ ! -f /test-drive/aws-eks/step4/temp_creds_ready ]; do
  sleep 2
done

# Display the credentials
echo "Temporary credentials retrieved successfully:"
cat /test-drive/aws-eks/step4/temp_creds.txt

# Export the credentials
echo "Exporting credentials..."
source /test-drive/aws-eks/step4/temp_creds.txt
echo "Credentials exported successfully!"

