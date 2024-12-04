_M.DropdownClass = _M.DropdownClass or class()

local DropdownClass = _M.DropdownClass

-- object gui helpers
function DropdownClass:make_box(panel)
	local panel_w, panel_h = panel:size()
	local align = "grow"
	panel:rect({
		color = Color("0A0A0A"),
		halign = align,
		valign = align,
		w = panel_w,
		h = panel_h,
	})
	panel:rect({
		color = Color("3C3C3C"),
		halign = align,
		valign = align,
		x = 1,
		y = 1,
		w = panel_w - 2,
		h = panel_h - 2,
	})
	panel:rect({
		color = Color("0A0A0A"),
		halign = align,
		valign = align,
		x = 3,
		y = 3,
		w = panel_w - 6,
		h = panel_h - 6,
	})
end

function DropdownClass:make_pretty_text(text_obj)
	local _, _, w, h = text_obj:text_rect()
	w, h = w + 2, h + 2

	text_obj:set_size(w, h)
	text_obj:set_position(math.round(text_obj:x()), math.round(text_obj:y()))

	return w, h
end

function DropdownClass:parse_color_tags(text_obj)
	local text, colors = StringUtils:parse_color_string_utf8(text_obj:text())
	text_obj:set_text(text)
	self:make_pretty_text(text_obj)

	if not colors then
		return
	end

	for i = 1, #colors do
		local c = colors[i]
		text_obj:set_range_color(c.i - 1, c.j, c.color)
	end
end

function DropdownClass:do_text_fix()
	-- ghetto retarded fix
	-- text elements that are outside of their parent panels
	-- [...] are not visible when initialized, updating them fixes it ¯\_(ツ)_/¯
	self._panel:move(-1, 0)
	self._panel:move(1, 0)
end

-- animation/feedback stuff
function DropdownClass:animate_ui(total_t, callback)
	local t = 0
	local const_frames = 0
	local count_frames = const_frames + 1
	while t < total_t do
		coroutine.yield()
		t = t + TimerManager:main():delta_time()
		if count_frames >= const_frames then
			callback(t / total_t, t)
			count_frames = 0
		end
		count_frames = count_frames + 1
	end

	callback(1, total_t)
end

function DropdownClass:unhighlight_element()
	if not alive(self.current_highlight) then
		return
	end

	local rect_item = self.current_highlight
	rect_item:stop()
	rect_item:animate(function(o)
		self:animate_ui(5, function(p)
			o:set_alpha(math.lerp(o:alpha(), 0, p))
		end)
		o:set_alpha(0)
		o:parent():remove(o)
	end)

	self.current_highlight = nil
end

function DropdownClass:highlight_element(panel, size, style)
	self:unhighlight_element()
	if alive(self.current_highlight) then
		return
	end

	size = size or {}
	style = style or {}

	local rect_item = panel:rect({
		x = size.x or 0,
		y = size.y or 0,
		w = panel:w() - (size.w or 0),
		h = panel:h() - (size.h or 0),
		layer = size.layer or 100,
		color = style.color,
		alpha = 0,
	})
	rect_item:stop()
	rect_item:animate(function(o)
		self:animate_ui(0.1, function(p)
			o:set_alpha(math.lerp(o:alpha(), style.alpha or 0.2, p))
		end)
	end)

	self.current_highlight = rect_item
end

function DropdownClass:do_over_scroll(panel, amount, target)
	panel:stop()
	panel:animate(function(o)
		self:animate_ui(0.1, function(p)
			o:set_y(math.lerp(o:y(), target + amount, p))
			self:check_element_hover()
		end)

		panel:animate(function(o)
			self:animate_ui(0.1, function(p)
				o:set_y(math.lerp(o:y(), target, p))
				self:check_element_hover()
			end)
		end)
	end)
end

function DropdownClass:do_scroll(panel, target, amount)
	if panel:parent():h() >= panel:h() then
		return target
	end

	if (target + amount) > 0 then
		if target == 0 then
			self:do_over_scroll(panel, amount, target)
			return target
		end

		target = 0
		amount = 0
	end

	if ((target + panel:h()) + amount) < panel:parent():h() then
		if target + panel:h() == panel:parent():h() then
			self:do_over_scroll(panel, amount, target)
			return target
		end

		amount = panel:parent():h() - (target + panel:h())
	end

	target = target + amount
	panel:stop()
	panel:animate(function(o)
		self:animate_ui(0.1, function(p)
			o:set_y(math.lerp(o:y(), target, p))
			self:check_element_hover()
		end)
	end)

	return target
end

-- Setup
function DropdownClass:init()
	self._ws = Overlay:newgui():create_screen_workspace()
	self._panel = self._ws:panel():panel({ layer = 1151 })

	self.menu_mouse_id = managers.mouse_pointer:get_id()

	self.font = {
		path = "fonts/font_univers_530_bold",
		sizes = { small = 18, medium = 24 },
	}

	self.active = false
	self.height_data = { button = 38 }
end

function DropdownClass:is_active()
	return self.active
end

function DropdownClass:show()
	if self:is_active() then
		return
	end

	managers.menu._input_enabled = false
	for _, menu in ipairs(managers.menu._open_menus) do
		menu.input._controller:disable()
	end

	if not self._controller then
		self._ws:connect_keyboard(Input:keyboard())
		self._controller = managers.controller:create_controller("dropdown_controller", nil, false)
		self._controller:add_trigger("cancel", callback(self, self, "keyboard_cancel"))
		managers.mouse_pointer:use_mouse({
			mouse_move = callback(self, self, "mouse_move"),
			mouse_press = callback(self, self, "mouse_press"),
			id = self.menu_mouse_id,
		})
	end
	self._controller:enable()

	self.active = true
end

function DropdownClass:hide()
	if not self:is_active() then
		return
	end

	self:close_active_dropdown_menu()

	if self._controller then
		self._ws:disconnect_keyboard()
		managers.mouse_pointer:remove_mouse(self.menu_mouse_id)

		self._controller:destroy()
		self._controller = nil
	end

	managers.menu._input_enabled = true
	for _, menu in ipairs(managers.menu._open_menus) do
		menu.input._controller:enable()
	end

	self.active = false
end

function DropdownClass:destroy()
	if not alive(self._panel) then
		return
	end

	self:hide()

	self._panel:parent():clear()

	self._ws:gui():destroy_workspace(self._ws)
end

-- Menu definition
function DropdownClass:close_active_dropdown_menu()
	if not self.active_dropdown then
		return
	end

	local dropdown_panel = self.active_dropdown.panel
	dropdown_panel:stop()
	dropdown_panel:animate(function(o)
		self:animate_ui(0.5, function(p)
			o:set_alpha(math.lerp(o:alpha(), 0, p))
			o:set_h(math.lerp(o:h(), 8, p))
			self:do_text_fix()
		end)

		o:set_alpha(0)
		o:set_h(8)

		self._panel:remove(dropdown_panel)
	end)

	self.active_dropdown = nil
end

function DropdownClass:open_dropdown_menu(panel, data)
	self:show()
	self:close_active_dropdown_menu()

	local max_rows = 35
	local target_h1 = 32 + max_rows * (self.height_data["button"] + 2)
	local actual_x = self._panel:x() > panel:world_x() and self._panel:x() or panel:world_x()
	local dropdown_panel = self._panel:panel({
		y = panel:world_bottom(),
		x = actual_x,
		w = panel:w(),
		h = target_h1,
		layer = 1,
		alpha = 0,
	})
	self:make_box(dropdown_panel)

	local offset = 0

	if (dropdown_panel:y() + target_h1) > self._panel:h() then
		for i = max_rows, 1, -1 do
			local target_h2 = (i * (self.height_data["button"] + 2)) + offset

			if (dropdown_panel:y() + target_h2) <= self._panel:h() then
				max_rows = i - 1
				break
			end
		end
	end

	local target_h = (offset + 4)
		+ (math.min(max_rows, table.size(data.items or {})) * (self.height_data["button"] + 2))
	dropdown_panel:set_h(target_h)

	local item_panel = dropdown_panel:panel({ y = offset + 4 })

	local scroll_panel = item_panel:panel({ halign = "grow", h = 2000 })
	local column_panel = scroll_panel:panel({ alpha = 1, halign = "grow", x = 4, w = panel:w() - 8 })

	local total_h = 0
	local y_offset = 2
	local dropdown_items = {}
	for index, item_data in pairs(data.items or {}) do
		local add_amount = self.height_data["button"]

		local button_panel = column_panel:panel()
		button_panel:set_y(total_h + y_offset)
		button_panel:set_h(add_amount)

		local data = {
			parent = button_panel,
			height = add_amount,
			item_data = item_data,
			index = index,
		}

		dropdown_items[index] = callback(self, self, "create_dropdown_button", data)()

		total_h = total_h + add_amount + y_offset
	end

	column_panel:set_h(total_h)
	scroll_panel:set_h(total_h)

	dropdown_panel:set_h(8)

	dropdown_panel:stop()
	dropdown_panel:animate(function(o)
		self:animate_ui(0.25, function(p)
			o:set_h(math.lerp(o:h(), target_h + 4, p))
			o:set_alpha(math.lerp(o:alpha(), 1, p))
			self:do_text_fix()
		end)

		o:set_h(target_h + 4)
		o:set_alpha(1)
	end)

	dropdown_panel:key_press(callback(self, self, "key_press"))

	self.active_dropdown = {
		raw = data,
		panel = dropdown_panel,
		scroll_panel = scroll_panel,
		items = dropdown_items,
		target_y = 0,
	}
end

function DropdownClass:create_dropdown_button(data)
	local item_panel = data.parent:panel({ h = data.height, layer = 1 })

	local button_panel = item_panel:panel()

	local bitmap = {
		right = function()
			return 0
		end,
	}
	if data.item_data.bitmap then
		bitmap = button_panel:bitmap({
			texture = data.item_data.bitmap.texture,
			texture_rect = data.item_data.bitmap.texture_rect,
			layer = 1,
			halign = "center",
			valign = "center",
			x = 4,
			w = data.height - 4,
			h = data.height - 4,
		})
		bitmap:set_center_y(button_panel:center_y())
	end

	local value_text = button_panel:text({
		text = tostring(data.item_data.text),
		font = self.font.path,
		font_size = self.font.sizes.medium,
		layer = 2,
		x = bitmap:right() + 4,
	})
	self:parse_color_tags(value_text)
	value_text:set_center_y(button_panel:center_y())

	local index_text = button_panel:text({
		text = tostring(data.index),
		font = self.font.path,
		font_size = self.font.sizes.small,
		alpha = 0.75,
		layer = 2,
	})
	self:make_pretty_text(index_text)
	index_text:set_right(button_panel:right() - 4)
	index_text:set_center_y(value_text:center_y())

	return { panel = button_panel, index = tonumber(data.index) }
end

-- Keyboard input
function DropdownClass:keyboard_cancel()
	if not self:is_active() then
		return
	end

	self:hide()
end

local btn_list = {}
for i = 1, 9 do
	btn_list[Idstring(tostring(i)):key()] = i
	btn_list[Idstring("num " .. tostring(i)):key()] = i
end

function DropdownClass:key_press(_, key)
	if managers.hud and managers.hud:showing_stats_screen() then
		return
	end

	local active_dropdown = self.active_dropdown
	if not active_dropdown then
		return
	end

	local index = btn_list[key:key()]
	if type(index) == "number" and active_dropdown.items[index] then
		self:on_button_click(active_dropdown.items[index])
	end
end

-- Mouse input
function DropdownClass:is_mouse_in_panel(panel)
	if not panel or not alive(panel) then
		return false
	end

	return panel:inside(self.menu_mouse_x, self.menu_mouse_y)
end

function DropdownClass:check_element_hover()
	local active_dropdown = self.active_dropdown
	if not active_dropdown then
		return
	end

	if not self:is_mouse_in_panel(active_dropdown.panel) then
		if self.current_hover then
			self:unhighlight_element()
			self.current_hover = nil
			return
		end
		return
	end

	if self.current_hover then
		if not self:is_mouse_in_panel(self.current_hover.panel) then
			self:unhighlight_element()
			self.current_hover = nil
		end
		return
	end

	if not next(active_dropdown.items) then
		return
	end

	for _, item in pairs(active_dropdown.items) do
		if self:is_mouse_in_panel(item.panel) then
			self.current_hover = { panel = item.panel }
			self:highlight_element(item.panel)
			break
		end
	end
end

function DropdownClass:mouse_move(_, x, y)
	self.menu_mouse_x, self.menu_mouse_y = x, y

	if not self.active_dropdown then --?
		return
	end

	self:check_element_hover()
end

function DropdownClass:on_left_click()
	local dropdown = self.active_dropdown
	if not self:is_mouse_in_panel(dropdown.panel) then
		self:hide()
		return
	end

	for _, item in pairs(dropdown.items) do
		if self:is_mouse_in_panel(item.panel) then
			self:on_button_click(item)
			break
		end
	end
end

function DropdownClass:on_button_click(item)
	local raw_dropdown = tablex.get(self, "active_dropdown", "raw")
	if not raw_dropdown then
		return
	end

	local raw_item = raw_dropdown.items[item.index]

	local func = tablex.get(raw_item, "callback") or raw_dropdown.callback
	local args = tablex.get(raw_item, "args")
	if type(func) == "string" then
		if type(self[func]) == "function" then
			self[func](self, args)
		end
	end

	if type(func) == "function" then
		func(args)
	end

	self:hide()
end

local ids_left_click = Idstring("0")
local ids_wheel_up = Idstring("mouse wheel up")
local ids_wheel_down = Idstring("mouse wheel down")
function DropdownClass:mouse_press(_, button, x, y)
	self.menu_mouse_x, self.menu_mouse_y = x, y

	local dropdown = self.active_dropdown
	if not dropdown then
		return
	end

	if button == ids_left_click then
		self:on_left_click()
		return
	end

	if button == ids_wheel_up then
		if self:is_mouse_in_panel(dropdown.panel) then
			dropdown.target_y = self:do_scroll(dropdown.scroll_panel, dropdown.target_y, 28)
			return
		end

		return
	end

	if button == ids_wheel_down then
		if self:is_mouse_in_panel(dropdown.panel) then
			dropdown.target_y = self:do_scroll(dropdown.scroll_panel, dropdown.target_y, -28)
			return
		end

		return
	end
end

local module = ... or D:module("loadout_dropdowns")

-- Hooks
if RequiredScript == "lib/states/ingamewaitingforplayers" then
	local IngameWaitingForPlayersState = module:hook_class("IngameWaitingForPlayersState")
	module:post_hook(IngameWaitingForPlayersState, "at_enter", function()
		if rawget(_M, "KitMenuDropdown") then
			return
		end

		rawset(_M, "KitMenuDropdown", DropdownClass:new())
	end)

	module:post_hook(IngameWaitingForPlayersState, "at_exit", function()
		local KitMenuDropdown = rawget(_M, "KitMenuDropdown")
		if not KitMenuDropdown then
			return
		end

		KitMenuDropdown:destroy()
		KitMenuDropdown = nil
	end)
end

if RequiredScript == "lib/managers/menu/menunodekitgui" then
	local handlers = {
		["weapon"] = function(id)
			local item_tweak = tweak_data.weapon[id] or tweak_data.weapon["beretta92"]
			local texture, texture_rect = tweak_data.hud_icons:get_icon_data(item_tweak.hud_icon)

			return { name_id = item_tweak.name_id, texture = texture, texture_rect = texture_rect }
		end,
		["equipment"] = function(id)
			local equipment_id = tweak_data.upgrades.definitions[id].equipment_id
			local item_tweak = tweak_data.equipments.specials[equipment_id] or tweak_data.equipments[equipment_id]
			local texture, texture_rect = tweak_data.hud_icons:get_icon_data(item_tweak.icon)

			return { name_id = item_tweak.text_id, texture = texture, texture_rect = texture_rect }
		end,
		["crew_bonus"] = function(id)
			local item_tweak = tweak_data.upgrades.definitions[id]
			local texture, texture_rect = tweak_data.hud_icons:get_icon_data(item_tweak.icon)

			return { name_id = item_tweak.name_id, texture = texture, texture_rect = texture_rect }
		end,
	}

	local KitMenuDropdown
	module:post_hook(module:hook_class("MenuNodeKitGui"), "_create_menu_item", function(self, row_item)
		if row_item.type ~= "kitslot" or table.size(row_item.item._options) <= 1 then
			return
		end

		KitMenuDropdown = KitMenuDropdown or rawget(_M, "KitMenuDropdown")
		if not KitMenuDropdown then
			return
		end

		local item = row_item.item

		item:set_parameter("item_confirm_callback", function()
			local item_category = item:parameters().category

			-- build up dropdown items
			local item_list = {}
			for index, item_value in pairs(item._options) do
				local data = handlers[item_category](item_value)

				table.insert(item_list, {
					text = managers.localization:text(data.name_id),
					bitmap = { texture = data.texture, texture_rect = data.texture_rect },
					args = index,
				})
			end

			local base = row_item.choice_panel
			local panel_x = row_item.arrow_left:world_x()
			local padding = 10 * tweak_data.scale.align_line_padding_multiplier
			KitMenuDropdown:open_dropdown_menu(
				KitMenuDropdown._panel:panel({
					y = base:world_y(),
					x = panel_x - padding,
					w = base:world_right() - panel_x + padding,
					h = base:h(),
					layer = 10000,
				}),
				{
					items = item_list,
					callback = function(index)
						-- MenuItemKitSlot does not have a :trigger() method, we have to reduce wanted index by 1 and call :next()
						item._current_index = index - 1
						item:next()
						self:_reload_kitslot_item(item)
					end,
				}
			)

			return true
		end)
	end)
end

if RequiredScript == "lib/managers/menumanager" then
	local KitMenuDropdown
	module:hook(module:hook_class("MenuManager"), "toggle_menu_state", function(self)
		KitMenuDropdown = KitMenuDropdown or rawget(_M, "KitMenuDropdown")
		if KitMenuDropdown and KitMenuDropdown:is_active() then -- prevent pausing when closing the active dropdown with escape
			return
		end

		module:call_orig(MenuManager, "toggle_menu_state", self)
	end)
end
