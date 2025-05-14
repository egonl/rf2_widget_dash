local app_name = "rf2_dashboard"
local baseDir = "/WIDGETS/rf2_dashboard/"
local inSimu = string.sub(select(2,getVersion()), -4) == "simu"
local build_ui_fancy = nil
local img_box = nil
local timerNumber = 1
local err_img = bitmap.open(baseDir.."img/no_connection_wr.png")
local wgt = {}

local function log(fmt, ...)
    print(string.format("[%s] "..fmt, app_name, ...))
    return
end

local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

local function isFileExist(file_name)
    log("is_file_exist()")
    local hFile = io.open(file_name, "r")
    if hFile == nil then
        log("file not exist - %s", file_name)
        return false
    end
    io.close(hFile)
    log("file exist - %s", file_name)
    return true
end

local function buildBlackboxHorz(parentBox, wgt, myBatt, fPercent, getPercentColor)
    local percent = fPercent(wgt)
    local r = 30
    local fill_color = myBatt.bar_color or GREEN
    local fill_color= (getPercentColor~=nil) and getPercentColor(wgt, percent) or GREEN
    local tw = 4
    local th = 4

    local box = parentBox:box({x=myBatt.x, y=myBatt.y})
    box:rectangle({x=0, y=0, w=myBatt.w, h=myBatt.h, color=myBatt.bg_color, filled=true, rounded=6, thickness=8})
    box:rectangle({x=0, y=0, w=myBatt.w, h=myBatt.h, color=WHITE, filled=false, thickness=myBatt.fence_thickness or 3, rounded=8})
    box:rectangle({x=5, y=5,
        -- w=0, h=myBatt.h,
        filled=true, rounded=4,
        size =function() return math.floor(fPercent(wgt) / 100 * myBatt.w)-10, myBatt.h-10 end,
        color=function() return getPercentColor(wgt, percent) or GREEN end,
    })

    return box
end

local function formatTime(wgt, t1)
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
      if wgt.options.use_days == 0 then
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

build_ui_fancy = function(wgt)
    if (wgt == nil) then log("refresh(nil)") return end
    if (wgt.options == nil) then log("refresh(wgt.options=nil)") return end
    local txtColor = wgt.options.textColor
    local titleGreyColor = LIGHTGREY
    local dx = 20

    lvgl.clear()

    -- global
    lvgl.rectangle({x=0, y=0, w=LCD_W, h=LCD_H, color=lcd.RGB(0x111111), filled=true})
    local pMain = lvgl.box({x=0, y=0})

    -- time
    pMain:build({
        {type="box", x=20, y=10, children={
            {type="label", text=function() return wgt.values.timer_str end, x=0, y=0, font=FS.FONT_38 ,color=txtColor},
        }}
    })

    -- rpm
    pMain:build({{type="box", x=20, y=160,
        children={
            {type="label", text="RPM",  x=0, y=0, font=FS.FONT_6, color=titleGreyColor},
            {type="label", text=function() return wgt.values.rpm_str end, x=0, y=10, font=FS.FONT_16 ,color=txtColor},
        }
    }})

    -- voltage
    local bVolt = pMain:box({x=20, y=72})
    buildBlackboxHorz(bVolt, wgt,
        {x=0, y=17,w=200,h=50,segments_w=20, color=WHITE, bg_color=GREY, cath_w=10, cath_h=30, segments_h=20, cath=false},
        function(wgt) return wgt.values.cell_percent end,
        function(wgt) return wgt.values.cellColor end
    )
    bVolt:label({text=function() return string.format("%.02fv", wgt.values.volt, wgt.values.cell_percent) end , x=50, y=21, font=FS.FONT_16 ,color=txtColor})

    -- current
    local bCurr = pMain:box({x=150, y=160})
    bCurr:label({text="Max Current",  x=0, y=0, font=FS.FONT_6, color=titleGreyColor})
    bCurr:label({text=function() return wgt.values.curr_str end, x=0, y=12, font=FS.FONT_16 ,color=txtColor})

    -- image
    local isizew=150
    local isizeh=120
    local bImageArea = pMain:box({x=310, y=20})
    bImageArea:rectangle({x=0, y=0, w=isizew, h=isizeh, thickness=4, rounded=15, filled=false, color=WHITE})
    local bImg = bImageArea:box({})
    img_box = bImg

    -- craft name
    local bCraftName = pMain:box({x=310, y=142})
    bCraftName:rectangle({x=0, y=20, w=isizew, h=25, filled=true, rounded=8, color=DARKGREY, opacity=200})
    bCraftName:label({text=function() return wgt.values.craft_name end,  x=10, y=22, font=FS.FONT_8, color=txtColor})

    -- no connection
    local bNoConn = lvgl.box({x=310, y=20, visible=function() return wgt.is_connected==false end})
    bNoConn:rectangle({x=5, y=5, w=isizew-10, h=isizeh-10, rounded=15, filled=true, color=BLACK, opacity=250})
    -- bNoConn:label({x=22, y=90, text=function() return wgt.not_connected_error end , font=FS.FONT_8, color=WHITE})
    bNoConn:image({x=30, y=15, w=90, h=90, file=baseDir.."img/no_connection_wr.png"})

end

local function updateCraftName(wgt)
    wgt.values.craft_name = string.gsub(model.getInfo().name, "^>", "")
end

local function updateTimeCount(wgt)
    local t1 = model.getTimer(timerNumber - 1)
    local time_str, isNegative = formatTime(wgt, t1)
    wgt.values.timer_str = time_str
end

local function updateRpm(wgt)
    local Hspd = getValue("Hspd")
    if inSimu then Hspd = 1800 end
    wgt.values.rpm = Hspd
    wgt.values.rpm_str = string.format("%s",Hspd)
end

local function updateCell(wgt)
    local vbat = getValue("Vbat")
    local vcel = getValue("Vcel")

    if inSimu then
        vbat = 22.2
        vcel = 3.66
    end

    local batPercent = math.tointeger((vcel / vbat) * 100) or 0

    -- log("vbat: %s, vcel: %s, BatPercent: %s", vbat, vcel, batPercent)

    wgt.values.vbat = vbat
    wgt.values.vcel = vcel
    wgt.values.cell_percent = batPercent
    wgt.values.volt = (wgt.options.showTotalVoltage == 1) and vbat or vcel
    wgt.values.cellColor = (vcel < 3.7) and RED or lcd.RGB(0x00963A) --GREEN
end

local function updateCurr(wgt)
    local curr = getValue("Curr")
    
    if curr > wgt.values.curr then
        wgt.values.curr = curr
    end

    wgt.values.curr_str = string.format("%.2fA", wgt.values.curr)
end

local function updateTemperature(wgt)
    local tempTop = wgt.options.tempTop

    wgt.values.EscT = getValue("EscT")
    wgt.values.EscT_max = getValue("EscT+")
    -- wgt.values.EscT = getValue("GSpd")
    -- wgt.values.EscT_max = getValue("GSpd+")
    if rf2.runningInSimulator then
        wgt.values.EscT = 60
        wgt.values.EscT_max = 75
    end
    wgt.values.EscT_str = string.format("%d°c", wgt.values.EscT)
    wgt.values.EscT_max_str = string.format("+%d°c", wgt.values.EscT_max)

    wgt.values.EscT_percent = math.min(100, math.floor(100 * (wgt.values.EscT / tempTop)))
    wgt.values.EscT_max_percent = math.min(100, math.floor(100 * (wgt.values.EscT_max / tempTop)))
end


local function updateImage(wgt)
    local newCraftName = wgt.values.craft_name
    if newCraftName == wgt.values.img_craft_name_for_image then
        return
    end

    local imageName = baseDir.."/img/"..newCraftName..".png"

    if isFileExist(imageName) == false then
        imageName = "/IMAGES/".. model.getInfo().bitmap

        if imageName == "" or isFileExist(imageName) ==false then
            imageName = baseDir.."img/rf2_logo.png"
        end
    end

    if imageName ~= wgt.values.img_last_name then
        log("updateImage - model changed, %s --> %s", wgt.values.img_last_name, imageName)

        -- image replacment
        local isizew=150
        local isizeh=100

        img_box:clear()
        img_box:image({file=imageName, x=0, y=0, w=isizew, h=isizeh, fill=false})

        wgt.values.img_last_name = imageName
        wgt.values.img_craft_name_for_image = newCraftName
    end
end

local function resetWidgetValues(wgt)
    wgt.values = {
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

local function refreshUI(wgt)
    updateCraftName(wgt)
    updateTimeCount(wgt)
    updateRpm(wgt)
    updateCell(wgt)
    updateCurr(wgt)
    -- updateTemperature(wgt)
    updateImage(wgt)
end

---------------------------------------------------------------------------------------

local function update(wgt, options)
    if (wgt == nil) then return end
    wgt.options = options
    -- wgt.not_connected_error = "Not connected"
    resetWidgetValues(wgt)
    build_ui_fancy(wgt)
    return wgt
end

local function create(zone, options)
    wgt.zone = zone
    wgt.options = options
    resetWidgetValues(wgt)
    return update(wgt, options)
end

local function background(wgt)
end

local function refresh(wgt, event, touchState)
    if (wgt == nil) then return end

    wgt.is_connected = getRSSI() > 0
    -- wgt.not_connected_error = "Not connected"

    if wgt.is_connected == false then
        resetWidgetValues(wgt)
        return
    end

    refreshUI(wgt)
end

return {create=create, update=update, background=background, refresh=refresh}