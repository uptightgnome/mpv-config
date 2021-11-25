function sub_seek_two(dir)
    if dir == 1 then
        target = mp.get_property_number("sub-end")
        if target then
            mp.commandv("seek", target-0.03, "absolute+exact")
        end
    else
        target = mp.get_property_number("sub-start")
        if target then
            mp.commandv("seek", target+0.01, "absolute+exact")
        end
    end
end

mp.add_key_binding("b", "sub_seek_right", function() return sub_seek_two(1) end)
mp.add_key_binding("B", "sub_seek_left", function() return sub_seek_two(-1) end)