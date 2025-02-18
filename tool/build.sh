#!/bin/bash

# Clean previous build files
flutter pub run build_runner clean

# Run build_runner with delete conflicting outputs
flutter pub run build_runner build --delete-conflicting-outputs 