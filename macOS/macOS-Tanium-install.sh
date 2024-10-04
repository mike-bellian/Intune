#!/bin/bash

# Azure Blob Storage settings
AZURE_STORAGE_ACCOUNT="your_account_name"
AZURE_STORAGE_CONTAINER="your_container_name"
AZURE_STORAGE_SAS_TOKEN="your_sas_token"
TANIUM_INTEL_PKG="TaniumClient-7.6.4.2033-x64.pkg"
TANIUM_UNIVERSAL_PKG="TaniumClient-7.6.4.2033-universal.pkg"
TANIUM_INIT="tanium-init.dat"
TANIUM_CLIENT_APP="/Library/Tanium/TaniumClient/TaniumClient"

# Temporary directory
TEMP_DIR="/tmp/tanium-install"

# Check if Tanium Client is already installed
if [ -f "$TANIUM_CLIENT_APP" ]; then
  # Get installed version
  INSTALLED_VERSION=$(defaults read /Library/Tanium/TaniumClient/Info.plist CFBundleVersion)
  
  # Define minimum required version
  MIN_REQUIRED_VERSION="7.6.4.2033"
  
  # Compare versions
  if [ "$(printf '%s\n' "$INSTALLED_VERSION" "$MIN_REQUIRED_VERSION" | sort -V | head -n1)" = "$INSTALLED_VERSION" ]; then
    echo "Tanium Client is already installed with version $INSTALLED_VERSION or higher. Skipping installation."
    exit 0
  fi
fi

# Download files from Azure Blob Storage
echo "Downloading Tanium Client packages and tanium-init.dat..."
mkdir -p "$TEMP_DIR"
curl -s -o "$TEMP_DIR/$TANIUM_INTEL_PKG" \
  "https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$AZURE_STORAGE_CONTAINER/$TANIUM_INTEL_PKG?$AZURE_STORAGE_SAS_TOKEN"
curl -s -o "$TEMP_DIR/$TANIUM_UNIVERSAL_PKG" \
  "https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$AZURE_STORAGE_CONTAINER/$TANIUM_UNIVERSAL_PKG?$AZURE_STORAGE_SAS_TOKEN"
curl -s -o "$TEMP_DIR/$TANIUM_INIT" \
  "https://$AZURE_STORAGE_ACCOUNT.blob.core.windows.net/$AZURE_STORAGE_CONTAINER/$TANIUM_INIT?$AZURE_STORAGE_SAS_TOKEN"

# Check macOS version and architecture
COMMAND_RESULT=$(sw_vers -productVersion)
ARCH=$(uname -m)

# Determine package to install based on macOS version and architecture
case "$COMMAND_RESULT" in
  10.[1-5]*)
    PACKAGE="$TANIUM_INTEL_PKG"
    ;;
  11*|12*|13*|14*)
    if [ "$ARCH" = "arm64" ]; then
      PACKAGE="$TANIUM_UNIVERSAL_PKG"
    else
      PACKAGE="$TANIUM_INTEL_PKG"
    fi
    ;;
  *)
    echo "Unsupported macOS version."
    exit 1
    ;;
esac

# Install Tanium Client
echo "Installing Tanium Client..."
installer -pkg "$TEMP_DIR/$PACKAGE" -target /
if [[ "$?" -eq "0" ]]; then
  echo "Installation successful. Copying tanium-init.dat."
  cp "$TEMP_DIR/$TANIUM_INIT" /Library/Tanium/TaniumClient/
  echo "Starting service."
  launchctl load /Library/LaunchDaemons/com.tanium.taniumclient.plist
else
  echo "Install failed."
  exit 1
fi