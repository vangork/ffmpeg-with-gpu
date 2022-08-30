#!/bin/bash

#ROOT_DIR=$(readlink -f $(dirname $0))

DOCKER_BUILDKIT=1 docker build -o output .
