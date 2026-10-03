#!/bin/sh
# increases build number consistently in all targets

cd "$SRCROOT"

# change value of BUILD_NUMBER to current date in yyyymmddhhmm
sed -i -e "/CURRENT_PROJECT_VERSION =/ s/= .*/= $(date +"%Y%m%d%H%M")/" Config.xcconfig

# Delete tmp file
rm Config.xcconfig-e

