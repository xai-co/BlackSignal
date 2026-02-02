local _, BS = ...;
BS.Colors = {};

local C = BS.Colors

-- Brand
C.Brand = {
    primary = {127/255, 63/255, 191/255, 1},
    hover   = {51/255, 153/255, 255/255, 1},
}

-- Button
C.Button = {
    normal          = {26/255, 26/255, 26/255, 1},
    active          = {26/255, 26/255, 26/255, 1},
    navNormal       = {127/255, 63/255, 191/255, 0.8},
    borderNormal    = {0, 0, 0, 1},
    borderHover     = { 150/255, 85/255, 225/255, 1 },
    navBorderNormal = {0, 0, 0, 1},
}

-- EditBox
C.EditBox = {
    background =    {26/255, 26/255, 26/255, 1},
    border     =    {0, 0, 0, 1},
    borderFocused = { 185/255, 100/255, 255/255, 1 },
}

-- CheckButton
C.CheckButton = {
    boxBorder = {0, 0, 0, 1},
    boxBg     = {0.12, 0.12, 0.12, 1},
    mark      = { 185/255, 100/255, 255/255, 1 },
}

--ColorPicker
C.ColorPicker = {
    border = { 0, 0, 0, 1 },
}

-- Text
C.Text = {
    normal      = { 185/255, 100/255, 255/255, 1 },
    white       = { 1, 1, 1, 1 },
}

-- Background
C.Backdrop = {
    background = {15/255, 15/255, 15/255, 0.85},
    border     = {0, 0, 0, 1},
}

C.Movers = {
    active = {15/255, 15/255, 15/255, 0.5},
    hover  = {26/255, 26/255, 26/255, 1},
}