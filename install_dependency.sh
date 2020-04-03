#!/bin/bash
set -eu
echo "Pod install"
pod install
echo "delete old files"
rm -f ./ClashXR/Resources/Country.mmdb
rm -rf ./ClashXR/Resources/dashboard
rm -f GeoLite2-Country.*
echo "install mmdb"
wget https://static.clash.to/GeoIP2/GeoIP2-Country.mmdb
mv GeoIP2-Country.mmdb ./ClashXR/Resources/Country.mmdb
echo "install dashboard"
cd ClashXR/Resources
git clone -b gh-pages https://github.com/Dreamacro/clash-dashboard.git dashboard
cd ..
python3 build_clash.py
