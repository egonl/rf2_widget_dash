local baseDir = "/WIDGETS/Rf2Dashboard/"
chdir(baseDir)

local tool = nil
local widgetOptions = loadScript(baseDir .. "widget-options.lua", "cd")()

local function create(zone, options)
    tool = assert(loadScript(baseDir .. "dashboard.lua", "cd"))(baseDir)
    return tool.create(zone, options)
end

local function update(widget, options)
    return tool.update(widget, options)
end

local function refresh(widget)
    return tool.refresh(widget)
end

local function background(widget)
    return tool.background(widget)
end

return {
    name = "RF2 Dashboard",
    options = widgetOptions.options,
    translate = widgetOptions.translate,
    create = create,
    update = update,
    refresh = refresh,
    background = background,
    useLvgl = true
}
