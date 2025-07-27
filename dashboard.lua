local baseDir = ...
local inSimu = string.sub(select(2, getVersion()), -4) == "simu"
local imgBox = nil
local timerNumber = 1
local widget = {}

local function log(fmt, ...)
    local app_name = "RF2 Dashboard"
    print(string.format("[%s] " .. fmt, app_name, ...))
end

local FS = { FONT_38 = XXLSIZE, FONT_16 = DBLSIZE, FONT_12 = MIDSIZE, FONT_8 = 0, FONT_6 = SMLSIZE }

local function fileExists(file_name)
    local hFile = io.open(file_name, "r")
    if hFile == nil then
        return false
    end
    io.close(hFile)
    return true
end

local function buildBlackboxHorz(parentBox, widget, myBatt, fPercent, getPercentColor)
    local percent = fPercent(widget)
    local box = parentBox:box({ x = myBatt.x, y = myBatt.y })
    box:rectangle({ x = 0, y = 0, w = myBatt.w, h = myBatt.h, color = myBatt.bg_color, filled = true, rounded = 6, thickness = 8 })
    box:rectangle({ x = 0, y = 0, w = myBatt.w, h = myBatt.h, color = WHITE, filled = false, thickness = myBatt
    .fence_thickness or 3, rounded = 8 })
    box:rectangle({
        x = 5,
        y = 5,
        filled = true,
        rounded = 4,
        size = function() return math.floor(fPercent(widget) / 100 * myBatt.w) - 10, myBatt.h - 10 end,
        color = function() return getPercentColor(widget, percent) or GREEN end,
    })

    return box
end

local function formatTime(widget, t1)
    local dd_raw = t1.value
    local isNegative = false
    if dd_raw < 0 then
        isNegative = true
        dd_raw = math.abs(dd_raw)
    end

    local dd = math.floor(dd_raw / 86400)
    dd_raw = dd_raw - dd * 86400
    local hh = math.floor(dd_raw / 3600)
    dd_raw = dd_raw - hh * 3600
    local mm = math.floor(dd_raw / 60)
    dd_raw = dd_raw - mm * 60
    local ss = math.floor(dd_raw)

    local time_str
    if dd == 0 and hh == 0 then
        -- less then 1 hour, 59:59
        time_str = string.format("%02d:%02d", mm, ss)
    elseif dd == 0 then
        -- lass then 24 hours, 23:59:59
        time_str = string.format("%02d:%02d:%02d", hh, mm, ss)
    else
        -- more than 24 hours
        if widget.options.use_days == 0 then
            -- 25:59:59
            time_str = string.format("%02d:%02d:%02d", dd * 24 + hh, mm, ss)
        else
            -- 5d 23:59:59
            time_str = string.format("%dd %02d:%02d:%02d", dd, hh, mm, ss)
        end
    end
    if isNegative then
        time_str = '-' .. time_str
    end
    return time_str, isNegative
end

local function buildUi(widget)
    local txtColor = widget.options.textColor
    local titleGreyColor = LIGHTGREY

    lvgl.clear()

    -- global
    lvgl.rectangle({ x = 0, y = 0, w = LCD_W, h = LCD_H, color = lcd.RGB(0x111111), filled = true })
    local pMain = lvgl.box({ x = 0, y = 0 })

    -- time
    pMain:build({
        {
            type = "box",
            x = 20,
            y = 10,
            children = {
                { type = "label", text = function() return widget.values.timer_str end, x = 0, y = 0, font = FS.FONT_38, color = txtColor },
            }
        }
    })

    -- rpm
    pMain:build({ {
        type = "box",
        x = 20,
        y = 160,
        children = {
            { type = "label", text = "RPM",                                    x = 0, y = 0,  font = FS.FONT_6,  color = titleGreyColor },
            { type = "label", text = function() return widget.values.rpm_str end, x = 0, y = 10, font = FS.FONT_16, color = txtColor },
        }
    } })

    -- voltage
    local bVolt = pMain:box({ x = 20, y = 72 })
    buildBlackboxHorz(bVolt, widget,
        { x = 0, y = 17, w = 200, h = 50, segments_w = 20, color = WHITE, bg_color = GREY, cath_w = 10, cath_h = 30, segments_h = 20, cath = false },
        function(widget) return widget.values.cell_percent end,
        function(widget) return widget.values.cellColor end
    )
    bVolt:label({
        text = function() return string.format("%.02fv", widget.values.volt, widget.values.cell_percent) end,
        x = 50,
        y = 21,
        font = FS.FONT_16,
        color = txtColor
    })

    -- current
    local bCurr = pMain:box({ x = 150, y = 160 })
    bCurr:label({ text = "Max Current", x = 0, y = 0, font = FS.FONT_6, color = titleGreyColor })
    bCurr:label({ text = function() return widget.values.curr_str end, x = 0, y = 12, font = FS.FONT_16, color = txtColor })

    -- image
    local isizew = 150
    local isizeh = 120
    local bImageArea = pMain:box({ x = 310, y = 20 })
    bImageArea:rectangle({
        x = 0,
        y = 0,
        w = isizew,
        h = isizeh,
        thickness = 4,
        rounded = 15,
        filled = false,
        color = WHITE
    })
    local bImg = bImageArea:box({})
    imgBox = bImg

    -- craft name
    local bCraftName = pMain:box({ x = 310, y = 142 })
    bCraftName:rectangle({ x = 0, y = 20, w = isizew, h = 25, filled = true, rounded = 8, color = DARKGREY, opacity = 200 })
    bCraftName:label({
        text = function() return widget.values.craft_name end,
        x = 10,
        y = 22,
        font = FS.FONT_8,
        color = txtColor
    })

    -- no connection
    local bNoConn = lvgl.box({ x = 310, y = 20, visible = function() return widget.is_connected == false end })
    bNoConn:rectangle({ x = 5, y = 5, w = isizew - 10, h = isizeh - 10, rounded = 15, filled = true, color = BLACK, opacity = 250 })
    -- bNoConn:label({x=22, y=90, text=function() return widget.not_connected_error end , font=FS.FONT_8, color=WHITE})
    bNoConn:image({ x = 30, y = 15, w = 90, h = 90, file = baseDir .. "img/no-connection.png" })
end

local function updateCraftName(widget)
    widget.values.craft_name = string.gsub(model.getInfo().name, "^>", "")
end

local function updateTimeCount(widget)
    local t1 = model.getTimer(timerNumber - 1)
    local time_str, isNegative = formatTime(widget, t1)
    widget.values.timer_str = time_str
end

local function updateRpm(widget)
    local Hspd = getValue("Hspd")
    if inSimu then Hspd = 1800 end
    widget.values.rpm = Hspd
    widget.values.rpm_str = string.format("%s", Hspd)
end

local function updateCell(widget)
    local vbat = getValue("Vbat")
    local vcel = getValue("Vcel")

    if inSimu then
        vbat = 22.2
        vcel = 3.66
    end

    local batPercent = math.tointeger((vcel / vbat) * 100) or 0
    -- log("vbat: %s, vcel: %s, BatPercent: %s", vbat, vcel, batPercent)
    widget.values.vbat = vbat
    widget.values.vcel = vcel
    widget.values.cell_percent = batPercent
    widget.values.volt = (widget.options.showTotalVoltage == 1) and vbat or vcel
    widget.values.cellColor = (vcel < 3.7) and RED or lcd.RGB(0x00963A) --GREEN
end

local function updateCurr(widget)
    local curr = getValue("Curr")

    if curr > widget.values.curr then
        widget.values.curr = curr
    end

    widget.values.curr_str = string.format("%.2fA", widget.values.curr)
end

--[[
local function updateTemperature(widget)
    local tempTop = widget.options.tempTop

    widget.values.EscT = getValue("EscT")
    widget.values.EscT_max = getValue("EscT+")
    -- widget.values.EscT = getValue("GSpd")
    -- widget.values.EscT_max = getValue("GSpd+")
    if inSimu then
        widget.values.EscT = 60
        widget.values.EscT_max = 75
    end
    widget.values.EscT_str = string.format("%d°c", widget.values.EscT)
    widget.values.EscT_max_str = string.format("+%d°c", widget.values.EscT_max)

    widget.values.EscT_percent = math.min(100, math.floor(100 * (widget.values.EscT / tempTop)))
    widget.values.EscT_max_percent = math.min(100, math.floor(100 * (widget.values.EscT_max / tempTop)))
end
--]]

local function updateImage(widget)
    local newCraftName = widget.values.craft_name
    if newCraftName == widget.values.img_craft_name_for_image then
        return
    end

    local imageName = baseDir .. "/img/" .. newCraftName .. ".png"

    if fileExists(imageName) == false then
        imageName = "/IMAGES/" .. model.getInfo().bitmap

        if imageName == "" or fileExists(imageName) == false then
            imageName = baseDir .. "img/rf2-logo.png"
        end
    end

    if imageName ~= widget.values.img_last_name then
        --log("updateImage - model changed, %s --> %s", widget.values.img_last_name, imageName)

        -- image replacment
        local isizew = 150
        local isizeh = 100

        imgBox:clear()
        imgBox:image({ file = imageName, x = 0, y = 0, w = isizew, h = isizeh, fill = false })

        widget.values.img_last_name = imageName
        widget.values.img_craft_name_for_image = newCraftName
    end
end

local function resetWidgetValues(widget)
    widget.values = {
        craft_name = "Not connected",
        timer_str = "--:--",
        rpm = 0,
        rpm_str = "0",

        vbat = 0,
        vcel = 0,
        cell_percent = 0,
        volt = 0,
        curr = 0,
        curr_str = "0",

        EscT = 0,
        EscT_max = 0,
        EscT_str = "0",
        EscT_max_str = "0",
        EscT_percent = 0,
        EscT_max_percent = 0,

        img_last_name = "---",
        img_craft_name_for_image = "---",
    }
end

local function refreshUI(widget)
    updateCraftName(widget)
    updateTimeCount(widget)
    updateRpm(widget)
    updateCell(widget)
    updateCurr(widget)
    -- updateTemperature(widget)
    updateImage(widget)
end

---------------------------------------------------------------------------------------

local function update(widget, options)
    if (widget == nil) then return end
    widget.options = options
    -- widget.not_connected_error = "Not connected"
    resetWidgetValues(widget)
    buildUi(widget)
    return widget
end

local function create(zone, options)
    widget.zone = zone
    widget.options = options
    resetWidgetValues(widget)
    return update(widget, options)
end

local function background(widget)
end

local function refresh(widget, event, touchState)
    if (widget == nil) then return end

    widget.is_connected = getRSSI() > 0
    -- widget.not_connected_error = "Not connected"

    if widget.is_connected == false then
        resetWidgetValues(widget)
        return
    end

    refreshUI(widget)
end

return { create = create, update = update, background = background, refresh = refresh }
