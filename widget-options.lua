local t = {
    options = {
        { "showTotalVoltage", BOOL,  0 },       -- 0 = Show as average Lipo cell level, 1 = show the total voltage (voltage as is)
        { "textColor",        COLOR, WHITE },
    },

    translate = function(name)
        local translations = {
            showTotalVoltage = "Show Total Voltage",
            textColor = "Text Color",
        }
        return translations[name]
    end
}

return t
