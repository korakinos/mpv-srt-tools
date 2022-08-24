-- -----------------------------------------------------------------------------
--
-- MPV SRT Tool
-- URL: https://github.com/korakinos/mpv-srt-tools
--
-- -----------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Importing the mpv libraries

local mp = require 'mp'
local msg = require 'mp.msg'
local opt = require 'mp.options'

--------------------------------------------------------------------------------
-- Default variables

local SCRIPT_NAME = "mpv-splice"
local default_tmp_location = "~/tmpXXX"
local default_output_location = mp.get_property("working-directory")

--------------------------------------------------------------------------------

local splice_options = {
	tmp_location = os.getenv("MPV_SPLICE_TEMP") and os.getenv("MPV_SPLICE_TEMP") or default_tmp_location,
	output_location = os.getenv("MPV_SPLICE_OUTPUT") and os.getenv("MPV_SPLICE_OUTPUT") or default_output_location
}
opt.read_options(splice_options, SCRIPT_NAME)


local concat_name = "concat.txt"

local ffmpeg = "ffmpeg -hide_banner -loglevel warning"

local times = {}
local start_time = nil
local remove_val = ""

local exit_time = 0

--------------------------------------------------------------------------------

function notify(duration, ...)
	local args = {...}
	local text = ""

	for i, v in ipairs(args) do
		text = text .. tostring(v)
	end

	msg.info(text)
	mp.command(string.format("show-text \"%s\" %d 1",
		text, duration))
end

local function get_time()
	local time_in_secs = mp.get_property_number('time-pos')

	local hours = math.floor(time_in_secs / 3600)
	local mins = math.floor((time_in_secs - hours * 3600) / 60)
	local secs = time_in_secs - hours * 3600 - mins * 60

	local fmt_time = string.format('%02d:%02d:%06.3f', hours, mins, secs)

	return fmt_time
end

function put_time()
	local time = get_time()
	local message = ""

	if not start_time then
		start_time = time
		message = "[START TIMESTAMP]"
	else
		--times[#times+1] = {
		table.insert(times, {
			t_start = start_time,
			t_end = time
		})
		start_time = nil

		message = "[END TIMESTAMP]"
	end

	notify(2000, message, ": ", time)
end

function show_times()
	notify(2000, "Total cuts: ", #times)

	for i, obj in ipairs(times) do
		msg.info("Slice", i, ": ", obj.t_start, " -> ", obj.t_end)
	end
	if start_time then
		notify(2000, "Slice ", #times+1, " in progress.")
	end
end

function write_srt()
	notify(2000, "Writing cut times to SRT file.")

	-- backup an existing output file
	os.rename("subtitles-template.srt", "subtitles-template-backup-" .. os.date("%FT%T") .. ".srt")

	-- copy the times table before sorting, so the global one remains unchanged
	times_sorted = times
	table.sort(times_sorted, function (left, right)
		return left.t_start < right.t_start
	end)

	srt_file = io.open("subtitles-template.srt", "w+")
	for i, obj in ipairs(times_sorted) do
		srt_file:write(i, "\n")
		t_start = string.gsub(obj.t_start, "%.", ",")
		t_end = string.gsub(obj.t_end, "%.", ",")
		srt_file:write(t_start, " --> ", t_end, "\n")
		srt_file:write("{}", "\n")
		srt_file:write("\n")
	end
	srt_file:flush()
end

function reset_current_slice()
	if start_time then
		notify(2000, "Slice ", #times+1, " reseted.")

		start_time = nil
	end
end

function delete_slice()
	if remove_val == "" then
		notify(2000, "Entered slice deletion mode.")

		-- Add shortcut keys to the interval {0..9}.
		for i=0,9,1 do
			mp.add_key_binding("Alt+" .. i, "num_key_" .. i,
				function()
					remove_val = remove_val .. i
					notify(1000, "Slice to remove: "
						.. remove_val)
				end
			)
		end
	else
		-- Remove previously added shortcut keys.
		for i=0,9,1 do
			mp.remove_key_binding("num_key_" .. i)
		end

		remove_num = tonumber(remove_val)
		if #times >= remove_num and remove_num > 0 then
			table.remove(times, remove_num)
			notify(2000, "Removed slice ", remove_num)
		end

		remove_val = ""

		msg.info("Exited slice deletion mode.")
	end
end

function prevent_quit(name)
	if start_time then
		if os.time() - exit_time <= 2 then
			mp.command(name)
		else
			exit_time = os.time()
		end
		notify(3000, "Slice has been marked. Press again to quit")
	else
		mp.command(name)
	end
end

function process_video()
	local alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local rnd_size = 10

	local pieces = {}

	-- Better seed randomization
	math.randomseed(os.time())
	math.random(); math.random(); math.random()

	if times[#times] then
		local tmp_dir = io.popen(string.format("mktemp -d %s",
			splice_options.tmp_location)):read("*l")
		local input_file = mp.get_property("path")
		local ext = string.gmatch(input_file, ".*%.(.*)$")()

		local rnd_str = ""
		for i=1,rnd_size,1 do
			local rnd_index = math.floor(math.random() * #alphabet + 0.5)
			rnd_str = rnd_str .. alphabet:sub(rnd_index, rnd_index)
		end

		local output_file = string.format("%s/%s_%s_cut.%s",
			splice_options.output_location,
			mp.get_property("filename/no-ext"),
			rnd_str, ext)

		local cat_file_name = string.format("%s/%s", tmp_dir, "concat.txt")
		local cat_file_ptr = io.open(cat_file_name, "w")

		notify(2000, "Process started!")

		for i, obj in ipairs(times) do
			local path = string.format("%s/%s_%d.%s",
				tmp_dir, rnd_str, i, ext)
			cat_file_ptr:write(string.format("file '%s'\n", path))
			os.execute(string.format("%s -ss %s -i \"%s\" -to %s " ..
				"-c copy -copyts -avoid_negative_ts make_zero \"%s\"",
				ffmpeg, obj.t_start, input_file, obj.t_end,
				path))
		end

		cat_file_ptr:close()

		cmd = string.format("%s -f concat -safe 0 -i \"%s\" " ..
			"-c copy \"%s\"",
			ffmpeg, cat_file_name, output_file)
		os.execute(cmd)

		notify(10000, "File saved as: ", output_file)
		msg.info("Process ended!")

		os.execute(string.format("rm -rf %s", tmp_dir))
		msg.info("Temporary directory removed!")
	end
end

mp.set_property("keep-open", "yes") -- Prevent mpv from exiting when the video ends
mp.set_property("quiet", "yes") -- Silence terminal.

mp.add_key_binding('q', "quit", function()
	prevent_quit("quit")
end)
mp.add_key_binding('Shift+q', "quit-watch-later", function()
	prevent_quit("quit-watch-later")
end)

mp.add_key_binding('Alt+t', "put_time", put_time)
mp.add_key_binding('Alt+p', "show_times", show_times)
mp.add_key_binding('Alt+w', "write_srt", write_srt)
mp.add_key_binding('Alt+c', "process_video", process_video)
mp.add_key_binding('Alt+r', "reset_current_slice", reset_current_slice)
mp.add_key_binding('Alt+d', "delete_slice", delete_slice)
