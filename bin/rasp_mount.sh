#!/bin/bash

target_file=$1
dir=$2
mount -oloop,offset=$((122880*512)) "$target_file" "$dir"
exit $?

