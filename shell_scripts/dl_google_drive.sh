#!/usr/bin/env bash
dl_gdrive ()
{
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1o2_JNyY2W7Ww0oX0SYUY9A5H0l9bns6K' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1o2_JNyY2W7Ww0oX0SYUY9A5H0l9bns6K" -O $1 && rm -rf /tmp/cookies.txt
}