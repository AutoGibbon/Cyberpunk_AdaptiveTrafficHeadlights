local Theme = {}

local pushColorCount = 0
local pushColorCountInternal = 0
local pushStyleCount = 0
local pushStyleCountInternal = 0

-- Semantic Color Variables
Theme.Colors = {
    -- Core Brand (warm accent colors)
    primary = { 0.8, 0.6, 0.2, 1.0 },       -- #CC9933 - warm gold
    primaryLight = { 0.9, 0.7, 0.3, 1.0 },  -- #E6B34D - lighter gold
    primaryDark = { 0.6, 0.45, 0.15, 1.0 }, -- #997326 - darker gold

    -- Backgrounds (based on #24292e)
    background = { 0.141, 0.161, 0.180, 1.0 },      -- #24292e - main background
    backgroundChild = { 0.118, 0.137, 0.153, 1.0 }, -- #1E2326 - darker child windows
    backgroundPopup = { 0.165, 0.188, 0.212, 1.0 }, -- #2A3036 - popup background
    frame = { 0.188, 0.212, 0.235, 1.0 },           -- #30363D - frame background
    frameHovered = { 0.220, 0.247, 0.275, 1.0 },    -- #383F47 - frame hovered
    frameActive = { 0.255, 0.286, 0.318, 1.0 },     -- #414951 - frame active

    -- Interactive Elements
    button = { 0.188, 0.212, 0.235, 1.0 },        -- #30363D - same as frame
    buttonHovered = { 0.220, 0.247, 0.275, 1.0 }, -- #383F47 - same as frame hovered
    buttonActive = { 0.8, 0.6, 0.2, 1.0 },        -- #CC9933 - primary color

    -- Tabs (following ImGui convention: dark active, light inactive)
    tabUnfocused = { 0.188, 0.212, 0.235, 1.0 },       -- #30363D
    tabUnfocusedActive = { 0.188, 0.212, 0.235, 1.0 }, -- #30363D
    tabHovered = { 0.255, 0.286, 0.318, 1.0 },         -- #414951
    tabActive = { 0.255, 0.286, 0.318, 1.0 },          -- #414951

    -- Text
    text = { 0.925, 0.925, 0.925, 1.0 },     -- #ECECEC - light text
    textDark = { 0.6, 0.6, 0.6, 1.0 },       -- #999999 - muted text
    textDisabled = { 0.4, 0.4, 0.4, 1.0 },   -- #666666 - disabled text
    textSelectedBg = { 0.8, 0.6, 0.2, 0.3 }, -- #CC99334D - primary with alpha

    -- Borders & Lines
    border = { 0.255, 0.286, 0.318, 1.0 },    -- #414951 - subtle borders
    separator = { 0.188, 0.212, 0.235, 1.0 }, -- #30363D - separators

    -- Headers (for CollapsingHeader)
    header = { 0.188, 0.212, 0.235, 1.0 },        -- #30363D - same as frame
    headerHovered = { 0.220, 0.247, 0.275, 1.0 }, -- #383F47 - same as frame hovered
    headerActive = { 0.8, 0.6, 0.2, 1.0 },        -- #CC9933 - primary

    -- Sliders & Interactive
    sliderGrab = { 0.6, 0.45, 0.15, 1.0 },     -- #997326 - primary dark
    sliderGrabActive = { 0.9, 0.7, 0.3, 1.0 }, -- #E6B34D - primary light
    checkMark = { 0.8, 0.6, 0.2, 1.0 },        -- #CC9933 - primary

    -- Scrollbars
    scrollbarBg = { 0.118, 0.137, 0.153, 1.0 },    -- #1E2326 - child background
    scrollbarGrab = { 0.255, 0.286, 0.318, 1.0 },  -- #414951 - subtle grab
    scrollbarGrabHovered = { 0.8, 0.6, 0.2, 1.0 }, -- #CC9933 - primary on hover
    scrollbarGrabActive = { 0.9, 0.7, 0.3, 1.0 },  -- #E6B34D - primary light

    -- Title Bar
    titleBg = { 0.118, 0.137, 0.153, 1.0 },          -- #1E2326 - dark title
    titleBgActive = { 0.255, 0.286, 0.318, 1.0 },    -- #414951 - primary active
    titleBgCollapsed = { 0.118, 0.137, 0.153, 1.0 }, -- #1E2326 - same as inactive

    -- Resize Grip
    resizeGrip = { 0.8, 0.6, 0.2, 1.0 },         -- #CC9933 - primary
    resizeGripHovered = { 0.9, 0.7, 0.3, 1.0 },  -- #E6B34D - primary light
    resizeGripActive = { 0.6, 0.45, 0.15, 1.0 }, -- #997326 - primary dark

    -- Accent Colors (cooler tones that complement the warm primary)
    accentBlue = { 0.4, 0.6, 0.8, 1.0 },        -- #6699CC - cool blue
    accentBlueHovered = { 0.5, 0.7, 0.9, 1.0 }, -- #80B3E6 - lighter blue
    accentTeal = { 0.3, 0.6, 0.6, 1.0 },        -- #4D9999 - teal
    accentTealHovered = { 0.4, 0.7, 0.7, 1.0 }, -- #66B3B3 - lighter teal

    accentRed = { 0.8, 0.25, 0.2, 1.0 },        -- #CC4033
    accentRedHovered = { 0.9, 0.35, 0.3, 1.0 }, -- #E6594D
    accentRedActive = { 0.7, 0.15, 0.1, 1.0 },  -- #B32619
    accentRedText = { 0.95, 0.95, 0.95, 1.0 },  -- #F2F2F2
}

-- Apply complete theme, must call removeTheme before exiting ImGui scope.
function Theme.ApplyTheme()
    -- Window
    SetColor(ImGuiCol.WindowBg, Theme.Colors.background)
    SetColor(ImGuiCol.ChildBg, Theme.Colors.backgroundChild)
    SetColor(ImGuiCol.PopupBg, Theme.Colors.backgroundPopup)

    -- Title Bar
    SetColor(ImGuiCol.TitleBg, Theme.Colors.titleBg)
    SetColor(ImGuiCol.TitleBgActive, Theme.Colors.titleBgActive)
    SetColor(ImGuiCol.TitleBgCollapsed, Theme.Colors.titleBgCollapsed)

    -- Frames
    SetColor(ImGuiCol.FrameBg, Theme.Colors.frame)
    SetColor(ImGuiCol.FrameBgHovered, Theme.Colors.frameHovered)
    SetColor(ImGuiCol.FrameBgActive, Theme.Colors.frameActive)

    -- Buttons
    SetColor(ImGuiCol.Button, Theme.Colors.button)
    SetColor(ImGuiCol.ButtonHovered, Theme.Colors.buttonHovered)
    SetColor(ImGuiCol.ButtonActive, Theme.Colors.buttonActive)

    -- Tabs (following ImGui convention: dark active, light inactive)
    SetColor(ImGuiCol.Tab, Theme.Colors.tabUnfocused)
    SetColor(ImGuiCol.TabHovered, Theme.Colors.tabHovered)
    SetColor(ImGuiCol.TabActive, Theme.Colors.tabActive)
    SetColor(ImGuiCol.TabUnfocused, Theme.Colors.tabUnfocused)
    SetColor(ImGuiCol.TabUnfocusedActive, Theme.Colors.tabUnfocusedActive)

    -- Headers (for CollapsingHeader)
    SetColor(ImGuiCol.Header, Theme.Colors.header)
    SetColor(ImGuiCol.HeaderHovered, Theme.Colors.headerHovered)
    SetColor(ImGuiCol.HeaderActive, Theme.Colors.headerActive)

    -- Sliders & Interactive
    SetColor(ImGuiCol.SliderGrab, Theme.Colors.sliderGrab)
    SetColor(ImGuiCol.SliderGrabActive, Theme.Colors.sliderGrabActive)
    SetColor(ImGuiCol.CheckMark, Theme.Colors.checkMark)

    -- Scrollbars
    SetColor(ImGuiCol.ScrollbarBg, Theme.Colors.scrollbarBg)
    SetColor(ImGuiCol.ScrollbarGrab, Theme.Colors.scrollbarGrab)
    SetColor(ImGuiCol.ScrollbarGrabHovered, Theme.Colors.scrollbarGrabHovered)
    SetColor(ImGuiCol.ScrollbarGrabActive, Theme.Colors.scrollbarGrabActive)

    -- Text
    SetColor(ImGuiCol.Text, Theme.Colors.text)
    SetColor(ImGuiCol.TextDisabled, Theme.Colors.textDisabled)
    SetColor(ImGuiCol.TextSelectedBg, Theme.Colors.textSelectedBg)

    -- Borders & Separators
    SetColor(ImGuiCol.Border, Theme.Colors.border)
    SetColor(ImGuiCol.BorderShadow, { 0, 0, 0, 0 })
    SetColor(ImGuiCol.Separator, Theme.Colors.separator)
    SetColor(ImGuiCol.SeparatorHovered, Theme.Colors.primary)
    SetColor(ImGuiCol.SeparatorActive, Theme.Colors.primaryLight)

    -- Resize Grip
    SetColor(ImGuiCol.ResizeGrip, Theme.Colors.resizeGrip)
    SetColor(ImGuiCol.ResizeGripHovered, Theme.Colors.resizeGripHovered)
    SetColor(ImGuiCol.ResizeGripActive, Theme.Colors.resizeGripActive)

    -- Alpha
    --SetStyleVar(ImGuiStyleVar.Alpha, 1.0)

    --Remove all rounding. gibbon likes boxes
    SetStyleVar(ImGuiStyleVar.TabRounding, 0)
    SetStyleVar(ImGuiStyleVar.GrabRounding, 0)
    SetStyleVar(ImGuiStyleVar.ChildRounding, 0)
    SetStyleVar(ImGuiStyleVar.FrameRounding, 0)
    SetStyleVar(ImGuiStyleVar.PopupRounding, 0)
    SetStyleVar(ImGuiStyleVar.WindowRounding, 0)
    SetStyleVar(ImGuiStyleVar.ScrollbarRounding, 0)
end

function Theme.PushDanger()
    Theme.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)
    Theme.PushStyleColor(ImGuiCol.Button, Theme.Colors.accentRed)
    Theme.PushStyleColor(ImGuiCol.ButtonHovered, Theme.Colors.accentRed)
    Theme.PushStyleColor(ImGuiCol.ButtonActive, Theme.Colors.accentRed)
    Theme.PushStyleColor(ImGuiCol.Text, Theme.Colors.accentRedText)
end

function Theme.PopDanger()
    Theme.PopStyleColor(4)
    Theme.PopStyleVar(1)
end

-- Internal wrapper for 'permanent' style changes
function SetColor(colorId, color)
    pushColorCountInternal = pushColorCountInternal + 1
    ImGui.PushStyleColor(colorId, color[1], color[2], color[3], color[4])
end

-- shared wrapper for temporary changes
function Theme.PushStyleColor(colorId, color)
    pushColorCount = pushColorCount + 1
    ImGui.PushStyleColor(colorId, color[1], color[2], color[3], color[4])
end

function Theme.PopStyleColor(count)
    ImGui.PopStyleColor(count)
end

-- Internal wrapper for 'permanent' style variable changes
function SetStyleVar(idx, val, valY)
    pushStyleCountInternal = pushStyleCountInternal + 1

    if valY == nil then
        ImGui.PushStyleVar(idx, val)
    else
        ImGui.PushStyleVar(idx, val, valY)
    end
end

-- Shared wrapper for temporary style variable changes
function Theme.PushStyleVar(idx, val, valY)
    pushStyleCount = pushStyleCount + 1

    if valY == nil then
        ImGui.PushStyleVar(idx, val)
    else
        ImGui.PushStyleVar(idx, val, valY)
    end
end

function Theme.PopStyleVar(count)
    ImGui.PopStyleVar(count)
end

-- remove all styles and colors added by this theme
function Theme.RemoveThemeAndVars()
    if pushColorCount > 0 then
        ImGui.PopStyleColor(pushColorCount)
        pushColorCount = 0
    end
    if pushColorCountInternal > 0 then
        ImGui.PopStyleColor(pushColorCountInternal)
        pushColorCountInternal = 0
    end
    if pushStyleCount > 0 then
        ImGui.PopStyleVar(pushStyleCount)
        pushStyleCount = 0
    end
    if pushStyleCountInternal > 0 then
        ImGui.PopStyleVar(pushStyleCountInternal)
        pushStyleCountInternal = 0
    end
end

--revert to baseline theme, keeping the internal theme stack intact
function Theme.PopVars()
    if pushColorCount > 0 then
        ImGui.PopStyleColor(pushColorCount)
        pushColorCount = 0
    end
    if pushStyleCount > 0 then
        ImGui.PopStyleVar(pushStyleCount)
        pushStyleCount = 0
    end
end

return Theme
