local brightness_filter_active = false
local brightness_filter_name = "@lyrics_dim"
local manual_override = false

-- Update brightness filter based on subtitle visibility (only if manual override is off)
function update_dim_based_on_subs(name, value)
if manual_override then
    return
    end
    local subs_on = mp.get_property_native("sub-visibility")
    if subs_on and not brightness_filter_active then
        -- Use the lavfi filter for proper dimming
        mp.commandv("vf", "add", brightness_filter_name..":lavfi=[eq=brightness=-0.2]")
        brightness_filter_active = true
        mp.osd_message("Dimming")
        elseif not subs_on and brightness_filter_active then
            mp.commandv("vf", "remove", brightness_filter_name)
            brightness_filter_active = false
            mp.osd_message("Undimming")
            end
            end

            -- Observe subtitle visibility changes
            mp.observe_property("sub-visibility", "bool", update_dim_based_on_subs)

            -- Toggle manual override:
            -- When ON, restores full brightness regardless of subtitle state.
            -- When OFF, if subs are on, dims the video.
            function toggle_manual_override()
            if manual_override then
                manual_override = false
                local subs_on = mp.get_property_native("sub-visibility")
                if subs_on and not brightness_filter_active then
                    mp.commandv("vf", "add", brightness_filter_name..":lavfi=[eq=brightness=-0.2]")
                    brightness_filter_active = true
                    mp.osd_message("Manual override off: Dim activated")
                    else
                        mp.osd_message("Manual override off")
                        end
                        else
                            manual_override = true
                            if brightness_filter_active then
                                mp.commandv("vf", "remove", brightness_filter_name)
                                brightness_filter_active = false
                                end
                                mp.osd_message("Manual override on: Brightness restored")
                                end
                                end

                                -- Toggle subtitles with V key.
                                -- The auto-dimming is handled by the observer.
                                function toggle_subtitles()
                                mp.commandv("cycle", "sub-visibility")
                                end

                                -- Clear ALL video filters (DO NOT TOUCH)
                                function clear_filters()
                                mp.command("vf clr")
                                brightness_filter_active = false
                                manual_override = false
                                mp.osd_message("Filters cleared")
                                end

                                -- Key bindings
                                mp.add_key_binding("Shift+v", "toggle-manual-override", toggle_manual_override)
                                mp.add_key_binding("V", "toggle-subtitles", toggle_subtitles)
                                mp.add_key_binding("C", "clear-filters", clear_filters)
