-- This script is a modification of https://github.com/Parranoh/mpv-notify-send/blob/master/notify-send.lua and inspired by https://github.com/mpv-notify/mpv-notify/blob/master/notify.lua
-- This suits my needs and it was leveraged by LLMs to explain certain things like notify send and to fix issues with common HTML entities cuz i have a massive skill issue
-- mpv script: notify with extracted embedded cover or folder cover
local utils = require "mp.utils"

-- filenames to search in directory
local cover_filenames = { "cover.png", "cover.jpg", "cover.jpeg",
    "folder.jpg", "folder.png", "folder.jpeg",
    "AlbumArtwork.png", "AlbumArtwork.jpg", "AlbumArtwork.jpeg" }

    -- send desktop notification
    local function notify(summary, body, options)
    local option_args = {}
    for key, value in pairs(options or {}) do
        table.insert(option_args, string.format("--%s=%s", key, value))
        end
        return mp.command_native({
            "run", "notify-send",
            summary, body,
            unpack(option_args)
        })
        end

        -- unescape common HTML entities from Pango escape
        local function unescape_pango_entities(str)
        return str:gsub("&#(%d+);", function(code)
        return string.char(tonumber(code))
        end)
        end

        -- wrapper to notify media with cover image hint and app icon
        local function notify_media(title, origin, thumbnail)
        local opts = {
            urgency = "low",
            ["app-name"] = "MPV Music",
            icon = "org.gnome.Music-symbolic"
        }
        if thumbnail then
            opts["hint"] = "string:image-path:" .. thumbnail
            end
            -- unescape for cleaner look
            title = unescape_pango_entities(title)
            origin = unescape_pango_entities(origin)
            return notify(title, origin, opts)
            end

            -- check if file exists
            local function file_exists(path)
            local info = utils.file_info(path)
            return info ~= nil
            end

            -- search for cover file in directory
            local function find_cover(dir)
            if dir:sub(1,1) ~= "/" then
                dir = utils.join_path(utils.getcwd(), dir)
                end
                for _, fname in ipairs(cover_filenames) do
                    local path = utils.join_path(dir, fname)
                    if file_exists(path) then
                        return path
                        end
                        end
                        return nil
                        end

                        -- generate md5 hash from path
                        local function hash_path(path)
                        local r = utils.subprocess({ args = { "sh", "-c", string.format("echo -n '%s' | md5sum", path) } })
                        return r.status == 0 and r.stdout:match("^(%w+)") or "unknown"
                        end

                        -- extract embedded cover using ffmpeg, cache in ~/.cache/mpv_covers
                        local function extract_embedded_cover(filepath)
                        local home = os.getenv("HOME") or "."
                        local cache_dir = utils.join_path(home, ".cache/mpv_covers")
                        utils.subprocess({ args = { "mkdir", "-p", cache_dir } })

                        local base = hash_path(filepath)
                        local out_path = utils.join_path(cache_dir, base .. ".jpg")

                        if not file_exists(out_path) then
                            utils.subprocess({
                                args = {
                                    "ffmpeg", "-hide_banner", "-loglevel", "error",
                                    "-i", filepath,
                                    "-an",
                                    "-vcodec", "copy",
                                    "-f", "image2",
                                    out_path
                                }
                            })
                            end
                            return file_exists(out_path) and out_path or nil
                            end

                            -- capitalize snake case strings
                            local function first_upper(str)
                            return (string.gsub(string.gsub(str, "^%l", string.upper), "_%l", string.upper))
                            end

                            -- main notification function
                            local function notify_current_media()
                            local filepath = mp.get_property_native("path")
                            local dir, file = utils.split_path(filepath)

                            -- try embedded cover first, fallback to folder cover
                            local thumbnail = extract_embedded_cover(filepath) or find_cover(dir)

                            -- prepare title and origin text
                            local title = mp.get_property_native("media-title") or file
                            local origin = dir
                            local metadata = mp.get_property_native("metadata")
                            if metadata then
                                local function tag(name)
                                return metadata[string.upper(name)] or metadata[first_upper(name)] or metadata[name]
                                end
                                title = tag("title") or title
                                origin = tag("artist_credit") or tag("artist") or origin
                                local album = tag("album")
                                if album then origin = string.format("%s — %s", origin, album) end
                                    local year = tag("original_year") or tag("year")
                                    if year then origin = string.format("%s (%s)", origin, year) end
                                        end

                                        notify_media(title, origin, thumbnail)
                                        end

                                        mp.register_event("file-loaded", notify_current_media)
