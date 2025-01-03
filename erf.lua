local erf = {}

-----------------------
---- Element Class ----
-----------------------

---@alias parts table<number, Element> -- A list of elements that are contained by another element
---@alias part_behavior fun(this: Element, elements: parts, idx: integer):Element -- What changes an element makes to the elements inside of it
---@alias behavior fun(this: Element, dt: number) -- A function that happens to an element every frame
---@alias render_behavior fun(this: Element):nil

---@class Element
---@field x number
---@field y number
---@field width number
---@field height number
---@field behavior behavior
---@field parts parts
---@field part_behavior part_behavior
---@field render_behavior render_behavior
erf.Element = {}
erf.Element.__index = erf.Element

---@class config
---@field width number?
---@field height number?
---@field x number?
---@field y number?
---@field behavior behavior?
---@field parts parts?
---@field part_behavior part_behavior?
---@field render_behavior render_behavior?

---@param options config
---@return Element
function erf.Element:new(options)
    return setmetatable({
        x = options.x or 0,
        y = options.y or 0,
        width = options.width or 0,
        height = options.height or 0,
        behavior = options.behavior or function() end,
        parts = options.parts or {},
        part_behavior = options.part_behavior or function(_, elements, idx) return elements[idx] end,
        render_behavior = options.render_behavior or function() end,
    }, self)
end

---@param self Element
---@param shouldRecurse boolean? -- Whether the individual parts' behaviors should also be triggered, true by default
---@return nil
function erf.Element:applyPartBehavior(shouldRecurse)
    shouldRecurse = not (shouldRecurse == false)
    for i = 1, #self.parts do
        self.parts[i] = self.part_behavior(self, self.parts, i)
        if shouldRecurse then
            self.parts[i]:applyPartBehavior(shouldRecurse)
        end
    end
end

---@param dt number
---@param shouldRecurse? boolean -- Whether the individual parts should also be updated, true by default
---@return nil
function erf.Element:update(dt, shouldRecurse)
    shouldRecurse = not (shouldRecurse == false)
    self.behavior(self, dt)
    if shouldRecurse then
        for i = 1, #self.parts do
            self.parts[i]:update(dt, shouldRecurse)
        end
    end
end

---@return nil
function erf.Element:render()
    for i = 1, #self.parts do
        self.parts[i]:render_behavior()
        self.parts[i]:render()
    end
end

---@param self Element
---@return Element
function erf.Element:copy()
    local copiedparts = {}

    for i = 1, #self.parts do
        copiedparts[i] = self.parts[i]:copy()
    end


    return erf.Element:new({
        x = self.x,
        y = self.y,
        width = self.width,
        height = self.height,
        behavior = self.behavior,
        parts = copiedparts,
        part_behavior = self.part_behavior,
        render_behavior = self.render_behavior
    })
end

---@param self Element
---@param minY number
---@param maxY number
---@param alignment verticalAlignment
function erf.Element:alignY(minY, maxY, alignment)
    if alignment == 'top' then
        self.y = minY
    elseif alignment == 'bottom' then
        self.y = maxY - self.height
    elseif alignment == 'center' then
        self.y = (minY + maxY)/2 - self.height/2
    end
end

---@param self Element
---@param minX number
---@param maxX number
---@param alignment horizontalAlignment
function erf.Element:alignX(minX, maxX, alignment)
    if alignment == 'left' then
        self.x = minX
    elseif alignment == 'right' then
        self.x = maxX - self.width
    elseif alignment == 'center' then
        self.x = (minX + maxX)/2 - self.width/2
    end
end

--------------------
---- Containers ----
--------------------

erf.Containers = {}

---@alias verticalAlignment 'none'|'center'|'top'|'bottom'
---@alias horizontalAlignment 'none'|'center'|'right'|'left'

erf.Containers.Row = {}

---@param spacing number
---@param alignment verticalAlignment
---@return part_behavior
function erf.Containers.Row.getPartBehavior(spacing, alignment)
    return function(this, elements, idx)
        local curElement = elements[idx]:copy()
        local twidth = (idx - 1) * spacing
        for i = 1, idx - 1 do
            twidth = twidth + elements[i].width
        end
        curElement.x = twidth
        curElement:alignY(this.y, this.y + this.height, alignment)
        return curElement
    end
end

---@class row_config
---@field parts parts
---@field spacing number
---@field x number?
---@field y number?
---@field alignment verticalAlignment?
---@field height number?
---@field render_behavior (render_behavior)?

---@param options row_config
---@return Element
function erf.Containers.Row.new(options)
    local twidth = #options.parts * options.spacing
    local theight = 0
    for i = 1, #options.parts do
        twidth = twidth + options.parts[i].width
        theight = options.height or math.max(theight, options.parts[i].height)
    end
    return erf.Element:new({
        x = options.x,
        y = options.y,
        width = twidth,
        height = theight,
        parts = options.parts,
        part_behavior = erf.Containers.Row.getPartBehavior(options.spacing, options.alignment or 'none'),
        render_behavior = options.render_behavior
    })
end

erf.Containers.Column = {}

---@param spacing number
---@param alignment horizontalAlignment
---@return part_behavior
function erf.Containers.Column.getPartBehavior(spacing, alignment)
    return function(this, elements, idx)
        local curElement = elements[idx]:copy()
        local theight = (idx - 1) * spacing
        for i = 1, idx - 1 do
            theight = theight + elements[i].height
        end
        curElement.y = theight
        curElement:alignX(this.x, this.x + this.width, alignment)
        return curElement
    end
end

---@class column_config
---@field parts parts
---@field spacing number
---@field x number?
---@field y number?
---@field alignment horizontalAlignment?
---@field height number?
---@field render_behavior (render_behavior)?

---@param options column_config
---@return Element
function erf.Containers.Column.new(options)
    local twidth = #options.parts * options.spacing
    local theight = 0
    for i = 1, #options.parts do
        twidth = twidth + options.parts[i].width
        theight = options.height or math.max(theight, options.parts[i].height)
    end
    return erf.Element:new({
        x = options.x,
        y = options.y,
        width = twidth,
        height = theight,
        parts = options.parts,
        part_behavior = erf.Containers.Column.getPartBehavior(options.spacing, options.alignment or 'none'),
        render_behavior = options.render_behavior
    })
end

erf.Containers.Field = {}

---@param shouldSnap? boolean -- Whether the Field should always snap to the screen size, true by default
---@param shouldRetrigger? boolean -- Whether the Field should constantly retrigger its part behavior function to adapt to the screen size, true by default
---@return behavior
function erf.Containers.Field.getBehavior(shouldSnap, shouldRetrigger)
    return function(this, dt)
        if shouldSnap ~= false then
            local newWidth = love.graphics.getWidth()
            local newHeight = love.graphics.getHeight()
            if this.width ~= newWidth or this.height ~= newHeight then
                this.width = newWidth
                this.height = newHeight
                if shouldRetrigger ~= false then
                    this:applyPartBehavior()
                end
            end
        end
    end
end

---@param Xalignment horizontalAlignment
---@param Yalignment verticalAlignment
---@return part_behavior
function erf.Containers.Field.getPartBehavior(Xalignment, Yalignment)
    return function(this, elements, idx)
        local curElement = elements[idx]:copy()

        curElement:alignX(this.x, this.x + this.width, Xalignment)
        curElement:alignY(this.y, this.y + this.height, Yalignment)

        return curElement
    end
end

---@class field
---@field parts parts
---@field Xalignment horizontalAlignment?
---@field Yalignment verticalAlignment?
---@field shouldSnap boolean? -- Whether the Field should always snap to the screen size, true by default
---@field shouldRetrigger boolean? -- Whether the Field should constantly retrigger its part behavior function to adapt to the screen size, true by default
---@field x number?
---@field y number?
---@field width number?
---@field height number?
---@field render_behavior (render_behavior)?

---@param options field
---@return Element
function erf.Containers.Field.new(options)
    return erf.Element:new({
        width = options.width or love.graphics.getWidth(),
        height = options.height or love.graphics.getHeight(),
        x = options.x,
        y = options.y,
        behavior = erf.Containers.Field.getBehavior(options.shouldSnap, options.shouldRetrigger),
        parts = options.parts,
        part_behavior = erf.Containers.Field.getPartBehavior(options.Xalignment or 'none', options.Yalignment or 'none'),
        render_behavior = options.render_behavior
    })
end

-----------------
---- Padding ----
-----------------

erf.Paddings = {}

---@return part_behavior
function erf.Paddings.getPartBehavior()
    return function(this, elements, idx)
        local curElement = elements[idx]:copy()
        curElement.x = this.width
        curElement.y = this.height
        return curElement
    end
end

---@return Element
function erf.Paddings.new(parts, Xamnt, Yamnt)
    return erf.Element:new({
        x = 0,
        y = 0,
        width = Xamnt,
        height = Yamnt,
        parts = parts,
        part_behavior = erf.Paddingtons.Padding.getPartBehavior()
    })
end

------------------------
---- Bounding Boxes ----
------------------------

erf.Bounds = {}

---@param pointX number
---@param pointY number
---@param boxX number
---@param boxY number
---@param boxWidth number
---@param boxHeight number
function erf.Bounds.isInBox(pointX, pointY, boxX, boxY, boxWidth, boxHeight)
    return ((pointX >= boxX) and (pointX <= (boxX + boxWidth))) and ((pointY >= boxY) and (pointY <= (boxY + boxHeight)))
end

-----------------
---- Buttons ----
-----------------

erf.Buttons = {}

erf.Buttons.Button = {}

---@param func behavior
---@return behavior
function erf.Buttons.Button.getBehavior(func)
    return function(this, dt)
        if love.mouse.isDown(1) and erf.Bounds.isInBox(love.mouse.getX(), love.mouse.getY(), this.x, this.y, this.width, this.height) then
            func(this, dt)
        end
    end
end

---@class button_config
---@field func fun():nil
---@field width number
---@field height number
---@field x number?
---@field y number?
---@field render_behavior render_behavior?

---@param options
function erf.Buttons.Button.new(options)
    return erf.Element:new({
        width = options.width,
        height = options.height,
        x = options.x,
        y = options.y,
        behavior = erf.Buttons.Button.getBehavior(options.func),
        render_behavior = options.render_behavior
    })
end

erf.Buttons.Slider = {}

---@param slider Element
---@param sliderAngle number -- The angle of the slider (IN DEGREES NOT RADIANS)
---@return number, number
function erf.Buttons.Slider.getEndPos(slider, sliderAngle)
    local x = slider.width*math.sin(math.rad(sliderAngle))
    local y = slider.width*math.cos(math.rad(sliderAngle))
    return x, y
end

---@param func fun(this:Element, dt:number, x?:number) -- The parameter 'x' is the current value of the slider, this is just a behavior with an extra parameter.
---@param sliderAngle number -- The angle of the slider (IN DEGREES NOT RADIANS)
---@return behavior
function erf.Buttons.Slider.getBehavior(func, sliderAngle)
    return function(this, dt)
        local dx, dy = this.x - love.mouse.getX, this.y - love.mouse.getY
        local c = math.sqrt(dx^2 + dy^2)
        local alpha = math.rad(sliderAngle) - math.atan2(dy, dx)
        local x = c*math.cos(alpha)
        local o = c*math.sin(alpha)

        if o <= this.height and love.mouse.isDown(1) then
            func(this, dt, x)
        end
        func(this, dt, nil)
    end
end

---@class slider_config
---@field func behavior -- The angle of the slider (IN DEGREES NOT RADIANS)
---@field sliderAngle number -- The angle of the slider (IN DEGREES NOT RADIANS)
---@field width number
---@field height number
---@field x number?
---@field y number?
---@field render_behavior render_behavior?

---@param options slider_config
function erf.Buttons.Slider.new(options)
    return erf.Element:new({
        width = options.width,
        height = options.height,
        x = options.x,
        y = options.y,
        behavior = erf.Buttons.Slider.getBehavior(options.func, options.sliderAngle),
        render_behavior = options.render_behavior
    })
end

return erf