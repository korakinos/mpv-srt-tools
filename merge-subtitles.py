from time import localtime, strftime
import os

paragraphs = []

# parse text paragraphs
with open("subtitles.txt") as text_file:
    paragraph = ""
    for line in text_file:
        if line.isspace():
            # save finished paragraph, if not empty
            if (paragraph and not paragraph.isspace()):
                paragraphs.append(paragraph)
            paragraph = ""
        else:
            # continue assembling paragraph
            paragraph += line

# backup any previously generated file
try:
    os.rename(
        "subtitles.srt",
        "subtitles-backup-" + strftime("%FT%T") + ".srt")
except FileNotFoundError:
    pass

# merge SRT template with text paragraphs, write SRT file
with open("subtitles-template.srt") as template_file,
with open("subtitles.srt", "w") as merged_file:
    srt_data = template_file.read()
    merged_file.write(srt_data.format(*paragraphs))
