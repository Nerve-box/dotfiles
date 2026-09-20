#!/bin/bash

if ! command -v git &> /dev/null; then
    apt-get update -qq
    apt-get install build-essential -y -qq
fi
