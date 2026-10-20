#!/bin/sh
mkdir -p image
docker run --privileged -it --rm -v ./configs/:/configs -v ./image:/output builder make BOARD=licheervnano image
