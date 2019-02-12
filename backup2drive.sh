#! /usr/bin/env bash -e -x
DATE=`date "+%Y-%m-%d"`
tar --exclude './Applications' \
    --exclude './Google Drive' \
    --exclude './Downloads' \
    --exclude './Library' \
    --exclude './Restore' \
    --exclude './VirtualBox VMs' \
    --exclude './.Trash' \
    --exclude './.cache' \
    --exclude './.m2' \
    --exclude './.vagrant.d' \
    --exclude './.virtualenvs' \
    --exclude './blt' \
    --exclude './data' \
    --exclude './lib' \
    --exclude './sdb' \
    --exclude './tmp' \
    --exclude './git/*/target' \
    --exclude './soma.git/*/target' \
    --exclude './vagrant/*.box' \
    --exclude './pjasper*.tar.gz' \
    -c -v -z -f "./Google Drive/pjasper${DATE}.tar.z" .
