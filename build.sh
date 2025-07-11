#!/bin/bash

# Build and run NiteLite
echo "Building NiteLite..."

# Build the project
xcodebuild -project NiteLite.xcodeproj -scheme NiteLite -configuration Debug build

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Opening NiteLite..."
    open build/Debug/NiteLite.app
else
    echo "Build failed!"
    exit 1
fi
