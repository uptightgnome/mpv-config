local options = {
    fallback = "",
    temp_file = "",
    extract_embedded_art = true
}

mp.options = require "mp.options"
mp.options.read_options(options)

local utils = require "mp.utils"
local last_dir = ""
local legacy = mp.command_native_async == nil

if options.fallback == "" then
    options.fallback = mp.get_property("background", "#000000")
end

local ON_WINDOWS = (package.config:sub(1,1) ~= "/")

if options.temp_file == "" then
    options.temp_file = utils.join_path(ON_WINDOWS and os.getenv("TEMP") or "/tmp/", "mpv_audio_background.jpg")
end

function file_exists(name)
    local f = io.open(name, "rb")
    if f ~= nil then
        local ok, err, code = f:read(1)
        io.close(f)
        return code == nil
    else
        return false
    end
end

function find_executable(name)
    local delim = ON_WINDOWS and ";" or ":"

    local pwd = os.getenv("PWD") or utils.getcwd()
    local path = os.getenv("PATH")

    local env_path = pwd .. delim .. path
    
    if ON_WINDOWS then
        name = name .. ".exe"
    end

    local result, filename
    for path_dir in env_path:gmatch("[^" .. delim .. "]+") do
        filename = utils.join_path(path_dir, name)
        if file_exists(filename) then
            result = filename
            break
        end
    end

    return result
end

local ffmpeg_path = find_executable("ffmpeg")
local convert_path = find_executable("convert")

function dominant_color(file)
    local args = {
        convert_path, file,
        "-format", "%c",
        "-scale", "50x50!",
        "-sharpen", "5x5",
        "-colors", "5",
        "histogram:info:-"
    }
    if not legacy then
        colors = mp.command_native({name = "subprocess", capture_stdout = true, playback_only = false, args = args})
    else
        colors = utils.subprocess({args = args})
    end
    local best = {score=0}
    for score, color in string.gmatch(colors.stdout, "(%d+):.-(#......)") do
        score_n = tonumber(score)
        if score_n > best.score then
            best = {score=score_n, color=color}
        end
    end
    if best.score > 0 then
        mp.set_property("background", best.color)
    else
        mp.set_property("background", options.fallback)
    end
end

mp.observe_property("vid", "number", function(_, vid)
    if vid == nil then return end
    if not is_audio_file() then return end
    local path = mp.get_property("stream-open-filename", "")
    local dir, filename = utils.split_path(path)
    if dir ~= last_dir then
        last_dir = dir
        local coverart = ""
        local tracklist = mp.get_property_native("track-list")
        for _, track in ipairs(tracklist) do
            if track.selected and track.type == "video" then
                coverart = track["external-filename"]
                break
            end
        end
        if (coverart or "") ~= "" then
            dominant_color(coverart)
        elseif path ~= "" and options.extract_embedded_art then
            local ffmpeg = {
                ffmpeg_path, "-y",
                "-loglevel", "8",
                "-i", path,
                "-vframes", "1",
                options.temp_file
            }
            if not legacy then
                mp.command_native({name = "subprocess", capture_stdout = false, playback_only = false, args = ffmpeg})
            else
                utils.subprocess({args = ffmpeg})
            end
            dominant_color(options.temp_file)
        else
            mp.set_property("background", options.fallback)
        end
    end
end)

-- https://github.com/CogentRedTester/mpv-coverart/blob/master/coverart.lua
function is_audio_file()
    if mp.get_property("track-list/0/type") == "audio" then
        return true
    elseif mp.get_property("track-list/0/albumart") == "yes" then
        return true
    end
    return false
end