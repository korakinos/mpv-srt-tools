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

local SCRIPT_NAME = "mpv-timecodes-to-srt"

--------------------------------------------------------------------------------

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
mp.add_key_binding('Alt+r', "reset_current_slice", reset_current_slice)
mp.add_key_binding('Alt+d', "delete_slice", delete_slice)
