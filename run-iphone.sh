#!/bin/bash

# Quick launcher for MakeReady iPhone app
# Usage: ./run-iphone.sh [device-name]

cd iphone && ./run-simulator.sh "$@"
