#!/bin/sh

mpv --script=mpv-timecodes-to-srt.lua --sub-file=subtitles.srt "$@"
