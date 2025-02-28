#!/bin/bash

# Ask the user for the primary owner value
echo "Please enter the primary owner value:"
read primary_owner

# Check if the file exists, if not create it
if [ ! -f file1.env ]; then
  touch file1.env
fi

# Add the primary owner value to the file
echo "PRIMARY_OWNER=$primary_owner" >> file1.env

# Confirm the addition
echo "Primary owner added to file1.env: PRIMARY_OWNER=$primary_owner"

