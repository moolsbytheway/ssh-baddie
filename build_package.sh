#!/bin/bash

set -e

chmod +x ./build.sh
chmod +x ./create_dmg.sh

./build.sh
./create_dmg.sh