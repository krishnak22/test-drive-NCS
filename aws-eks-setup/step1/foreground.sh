echo "Starting AWS CLI and eksctl installation. Please wait..."
while [ ! -f /opt/install_done ]; do
  sleep 2  # Wait until installation is complete
done
echo "Installation completed successfully!"

