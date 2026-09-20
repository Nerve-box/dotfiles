#!/bin/bash

if ! command -v git &> /dev/null; then
    apt-get update -qq
    apt-get install git -y -qq
fi
