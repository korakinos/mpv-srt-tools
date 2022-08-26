# mpv-srt-tools

Small set of tools to generate SRT subtitles for videos:
 * mpv-timecode-to-srt.lua: Lua script for mpv that allows to mark timecodes in a playing video and write a template SRT file using keybindings in mpv.
 * merge-subtitles.py: Python script to merge the generated template SRT file with a plaintext file of subtitles.
 * run-mpv.sh: convenience shell script to run mpv with the lua script and the merged subtitles (if present) loaded.

The Lua mpv script is heavily based on https://github.com/pvpscript/mpv-video-splice/ .
Apart from the added functionality to generate SRT files, the time format was changed slightly (one more decimal digit of precision) and the video editing component was taken out, so that it cannot be triggered by accident.


## MPV Lua script
The Lua script provides the ability to create video slices by grabbing two timestamps, e.g.:
	
	-> Slice 1 :  00:10:34.250  ->  00:15:00.000
	-> Slice 2 :  00:23:00.840  ->  00:24:10.000
	...
	-> Slice n :  01:44:22.470  ->  01:56:00.000

**Note:** This script prevents the mpv player from closing when the video ends, so that the slices don't get lost. Keep this in mind if there's the option `keep-open=no` in the current config file.

**Note:** This script will also silence the terminal, so the script messages can be seen more clearly.


### Usage and key bindings of the mpv Lua script

Run as `mpv --scripts=<path-to-script/mpv-timecodes-to-srt.lua <video file>` from the command line. (It will try to load the file 'subtitles.srt' and will output a warning message if a version of this file hasn't been generated yet. This warning can safely be ignored.)

The script provides the following keyboard shortcuts.

#### Alt + T (Grab timestamp)
In the video screen, press `Alt + T` to grab the first timestamp and then press `Alt + T` again to get the second timestamp. This process will generate a time range, which represents a video slice. Repeat this process to create more slices.

#### Alt + P (Print slices)
To see all the slices made, press `Alt + P`. All of the slices will appear in the terminal in order of creation, with their corresponding timestamps. Incomplete slices will show up as `Slice N in progress`, where N is the slice number.

#### Alt + R (Reset unfinished slice)
To reset an incomplete slice, press `Alt + R`. If the first part of a slice was created at the wrong time, this will reset the current slice.

#### Alt + D (Delete slice)
To delete a whole slice, start the slice deletion mode by pressing `Alt + D`. When in this mode, it's possible to press `Alt + NUM`, where `NUM` is any number between 0 inclusive and 9 inclusive. For each `Alt + NUM` pressed, a number will be concatenated to make the final number referring to the slice to be removed, then press `Alt + D` again to stop the slicing deletion mode and delete the slice corresponding to the formed number.

Example 1: Deleting slice number 3
* `Alt + D`	# Start slice deletion mode
* `Alt + 3`	# Concatenate number 3
* `Alt + D`	# Exit slice deletion mode

Example 2: Deleting slice number 76
* `Alt + D`	# Start slice deletion mode
* `Alt + 7`	# Concatenate number 7
* `Alt + 6`	# Concatenate number 6
* `Alt + D`	# Exit slice deletion mode

**Note:** If these key combinations conflict with others on your system, you can change them by modifying the last lines of `mpv-timecodes-to-srt.lua`. (Mac users might want to change "`Alt`" to "`Meta`".)

#### Alt + W (Write SRT template file)

Pressing `Alt + W` writes the stored timecodes out to an SRT file "subtitles-template.srt", sorted by the start of each timecode pair. (Any preexisting file of that name is backed up by renaming, e.g. "`subtitles-template-backup-2022-08-24T20:52:23.srt`".) The file will look something like this:

```srt
1
00:00:00,367 --> 00:00:00,600
{}

2
00:00:00,933 --> 00:00:01,800
{}

3
00:00:03,533 --> 00:00:03,767
{}
```

The braces ("{}") are placeholders for the actual subtitles.

### Log Level

Everytime a timestamp is grabbed, a text will appear on the screen showing the selected time.

When `Alt + P` is pressed, besides showing the slices in the terminal, it will also show on the screen the total number of cuts (or slices) that were made.

**Note:** Every message that appears on the terminal has the **log level of 'info'**.


## Python script for merging your subtitles into the SRT template 

Prepare your subtitles as a plaintext file named "subtitles.txt", with each subtitle as a separate paragraph, ordered by their intended appearance in the video:

```txt
This is the first subtitle.

This is the <i>second</i> one, which will be associated with the <i>second</i> time code.

And so on.
```
Naturally, the number of paragraphs in the txt file should be equal to the number of subtitles in the srt file.
 
Place `subtitles.txt` in the same directory as the python script as well as `subtitles-template.srt`, then invoke the python script from the command line: `python3 merge-subtitles.py`.

The merged subtitle file will be written to "subtitles.srt". Any preexisting file of that name will be backed up by renaming it with a timecode (e.g. "`subtitles-backup-2022-08-24T20:52:23.srt`").


## Installation

To install the mpv Lua script, simply add it to your script folder, located at `$HOME/.config/mpv/scripts`

When the mpv player gets started up, the script will be executed and will be ready to use.


## Things which could be improved

 - Warning messages when number of slices and subtitles don't match.
 - Somehow allow for empty lines within subtitles. (Right now empty lines are always parsed as separators *between* subtitles.)
