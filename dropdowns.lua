DropdownClass = DropdownClass or class()
function DropdownClass:init()
	self._ws = managers.gui_data and managers.gui_data:create_fullscreen_workspace()
		or Overlay:newgui():create_screen_workspace()
	self._panel = self._ws:panel():panel({
		layer = 1151,
	})

	self.menu_mouse_id = managers.mouse_pointer:get_id()
	self.font = {
		path = "fonts/font_univers_530_bold",
		sizes = {
			tiny = 14,
			small = 20,
			medium = 24,
			large = 32,
			huge = 36,
		},
	}
	self.colors = {
		primary = Color("1E90FF"),
		secondary = Color("D3D3D3"),
		background = Color("000000"),
		error = Color("FF7F7F"),
		warning = Color("FFFF00"),
	}

	self.height_data = {
		["weapon"] = 32,
		["equipment"] = 32,
		["crew_bonus"] = 32,
	}
end

function DropdownClass:rgb255(...)
	local items = { ... }
	local num = #items
	if num == 4 then
		return Color(items[1] / 255, items[2] / 255, items[3] / 255, items[4] / 255)
	end

	if num == 3 then
		return Color(items[1] / 255, items[2] / 255, items[3] / 255)
	end

	return Color.white
end

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

function DropdownClass:update_text_rect(text)
	local _, _, w, h = text:text_rect()
	text:set_w(w)
	text:set_h(h)

	return w, h
end

function DropdownClass:make_box(panel, with_grow)
	local panel_w, panel_h = panel:size()
	local grow = with_grow and "grow" or nil
	local alpha = self._transparency and 0.4 or 1
	panel:rect({
		halign = grow,
		valign = grow,
		w = panel_w,
		h = panel_h,
		x = 0,
		y = 0,
		alpha = alpha,
		color = self:rgb255(10, 10, 10),
	})
	panel:rect({
		halign = grow,
		valign = grow,
		w = panel_w - 2,
		h = panel_h - 2,
		x = 1,
		y = 1,
		alpha = alpha,
		color = self:rgb255(60, 60, 60),
	})
	panel:rect({
		halign = grow,
		valign = grow,
		w = panel_w - 6,
		h = panel_h - 6,
		x = 3,
		y = 3,
		alpha = alpha,
		color = self:rgb255(10, 10, 10),
	})
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
		color = style.color or self.colors.secondary,
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

function DropdownClass:do_text_fix()
	-- ghetto retarded fix
	-- text elements that are outside of their parent panels
	-- [...] are not visible when initialized, updating them fixes it ¯\_(ツ)_/¯
	self._panel:move(-1, 0)
	self._panel:move(1, 0)
end

function DropdownClass:is_open()
	return self._enabled
end

function DropdownClass:open()
	if self:is_open() then
		return
	end

	managers.menu._input_enabled = false
	for _, menu in ipairs(managers.menu._open_menus) do
		menu.input._controller:disable()
	end

	if not self._controller then
		self._controller = managers.controller:create_controller("dropdown_controller", nil, false)
		self._controller:add_trigger("cancel", callback(self, self, "keyboard_cancel"))
		managers.mouse_pointer:use_mouse({
			mouse_move = callback(self, self, "mouse_move"),
			mouse_press = callback(self, self, "mouse_press"),
			id = self.menu_mouse_id,
		})
	end
	self._controller:enable()

	self._enabled = true
end

function DropdownClass:close()
	if not self:is_open() then
		return
	end

	self:close_dropdown_menu()

	if managers.gui_data then
		managers.gui_data:layout_fullscreen_workspace(managers.mouse_pointer._ws)
	end

	if self._controller then
		managers.mouse_pointer:remove_mouse(self.menu_mouse_id)

		self._controller:destroy()
		self._controller = nil
	end

	managers.menu._input_enabled = true
	for _, menu in ipairs(managers.menu._open_menus) do
		menu.input._controller:enable()
	end

	self._enabled = false
end

function DropdownClass:destroy()
	if not alive(self._panel) then
		return
	end

	self:close()

	self._panel:parent():clear()

	if managers.gui_data then
		managers.gui_data:destroy_workspace(self._ws)
		return
	end

	self._ws:gui():destroy_workspace(self._ws)
end

function DropdownClass:close_dropdown_menu()
	if not self.active_dropdown then
		return
	end

	local meta = self.active_dropdown
	local dropdown_panel = meta.panel
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

	local unfold_indicator = meta.unfold_indicator
	if unfold_indicator then
		unfold_indicator:stop()
		unfold_indicator:animate(function(o)
			self:animate_ui(0.5, function(p)
				o:set_alpha(math.lerp(o:alpha(), 0.5, p))
			end)
			o:set_alpha(0.5)
		end)
	end

	self.active_dropdown = nil
end

function DropdownClass:open_dropdown_menu(item)
	self:open()
	self:close_dropdown_menu()

	local panel = item.panel
	local raw_item = item.table_ptr

	local max_rows = 35
	local target_h1 = max_rows * (20 + 2)
	local actual_x = self._panel:x() > panel:world_x() and self._panel:x() or panel:world_x()
	local dropdown_panel = self._panel:panel({
		y = panel:world_bottom(),
		x = actual_x,
		w = panel:w(),
		h = target_h1,
		layer = 1,
		alpha = 0,
	})
	self:make_box(dropdown_panel, true)

	if (dropdown_panel:y() + target_h1) > self._panel:h() then
		for i = max_rows, 1, -1 do
			local target_h2 = i * (20 + 2)

			if (dropdown_panel:y() + target_h2) <= self._panel:h() then
				max_rows = i - 1
				break
			end
		end
	end

	local target_h = (
		math.min(max_rows, table.size(raw_item.items)) * ((self.height_data[raw_item.type] or panel:h()) + 2)
	)
	dropdown_panel:set_h(target_h)

	-- the only purpose of this is giving the scroll panel a 4px offset
	local item_panel = dropdown_panel:panel({ y = 4 })

	local scroll_panel = item_panel:panel({ halign = "grow", h = 2000 })
	local column_panel = scroll_panel:panel({
		alpha = 1,
		halign = "grow",
		x = 4,
		w = panel:w() - 8,
	})

	local total_h = 0
	local y_offset = 2
	local dropdown_items = {}
	for index, item_data in pairs(raw_item.items or {}) do
		local add_amount = self.height_data[raw_item.type] or panel:h()

		local button_panel = column_panel:panel()
		button_panel:set_y(total_h + y_offset)
		button_panel:set_h(add_amount)

		local data = {
			parent = button_panel,
			height = add_amount,
			item_data = item_data,
			index = index,
		}

		local funcs = {
			["weapon"] = "create_weapon_button",
			["equipment"] = "create_equipment_button",
			["crew_bonus"] = "create_crew_bonus_button",
		}

		if type(self[funcs[raw_item.type]]) == "function" then
			dropdown_items[index] = callback(self, self, funcs[raw_item.type], data)()
		end

		total_h = total_h + add_amount + y_offset
	end

	column_panel:set_h(total_h)
	scroll_panel:set_h(total_h)

	dropdown_panel:set_h(8)
	dropdown_panel:stop()
	dropdown_panel:animate(function(o)
		self:animate_ui(0.25, function(p)
			o:set_h(math.lerp(o:h(), target_h + 10, p))
			o:set_alpha(math.lerp(o:alpha(), 1, p))
			self:do_text_fix()
		end)

		o:set_h(target_h + 10)
		o:set_alpha(1)
	end)

	--* panel, scroll_panel, table of items, id, target_y
	self.active_dropdown = {
		parent = item,
		panel = dropdown_panel,
		scroll_panel = scroll_panel,
		items = dropdown_items,
		target_y = 0,
	}

	-- if raw_item.type ~= "dropdown_select" then
	-- 	return
	-- end

	-- local index = self._config_state:get_value(raw_item.id)
	-- if not index then
	-- 	return
	-- end

	-- self.active_dropdown.target_y = self:do_feature_scroll(
	-- 	scroll_panel,
	-- 	self.active_dropdown.target_y,
	-- 	-(self.height_data["dropdown_item"] + 2) * (index - 1)
	-- )
end

function DropdownClass:create_weapon_button(data)
	local item_panel = data.parent:panel({
		h = data.height,
		layer = 1,
	})

	local id = tostring(data.item_data)
	local tdata = tweak_data.weapon[id] or tweak_data.weapon["beretta92"]

	local icon, texture_rect = tweak_data.hud_icons:get_icon_data(tdata.hud_icon)
	local weapon_icon = item_panel:bitmap({
		texture = icon,
		texture_rect = texture_rect,
		layer = 2,
		x = 4,
		y = 0,
		w = 32,
		h = 32,
	})

	local value_text = item_panel:text({
		text = managers.localization:text(tdata.name_id),
		font = self.font.path,
		font_size = self.font.sizes.small,
		alpha = 1,
		layer = 2,
		x = weapon_icon:right() + 4,
	})
	self:update_text_rect(value_text)
	value_text:set_center_y(weapon_icon:center_y())

	local index_text = item_panel:text({
		text = tostring(data.index),
		font = self.font.path,
		font_size = self.font.sizes.tiny,
		color = self.colors.secondary,
		alpha = 0.75,
		layer = 2,
	})
	self:update_text_rect(index_text)
	index_text:set_right(item_panel:right() - 4)
	index_text:set_bottom(value_text:bottom())

	return { panel = item_panel, index = tonumber(data.index) }
end

function DropdownClass:create_equipment_button(data)
	local item_panel = data.parent:panel({
		h = data.height,
		layer = 1,
	})

	local id = tostring(data.item_data)
	local equipment_id = tweak_data.upgrades.definitions[id].equipment_id
	local tdata = tweak_data.equipments.specials[equipment_id] or tweak_data.equipments[equipment_id]

	local icon, texture_rect = tweak_data.hud_icons:get_icon_data(tdata.icon)
	local weapon_icon = item_panel:bitmap({
		texture = icon,
		texture_rect = texture_rect,
		layer = 2,
		x = 4,
		y = 0,
		w = 32,
		h = 32,
	})

	local value_text = item_panel:text({
		text = managers.localization:text(tdata.text_id),
		font = self.font.path,
		font_size = self.font.sizes.small,
		alpha = 1,
		layer = 2,
		x = weapon_icon:right() + 4,
	})
	self:update_text_rect(value_text)
	value_text:set_center_y(weapon_icon:center_y())

	local index_text = item_panel:text({
		text = tostring(data.index),
		font = self.font.path,
		font_size = self.font.sizes.tiny,
		color = self.colors.secondary,
		alpha = 0.75,
		layer = 2,
	})
	self:update_text_rect(index_text)
	index_text:set_right(item_panel:right() - 4)
	index_text:set_bottom(value_text:bottom())

	return { panel = item_panel, index = tonumber(data.index) }
end

function DropdownClass:create_crew_bonus_button(data)
	local item_panel = data.parent:panel({
		h = data.height,
		layer = 1,
	})

	local id = tostring(data.item_data)
	local definition = tweak_data.upgrades.definitions[id]

	local icon, texture_rect = tweak_data.hud_icons:get_icon_data(definition.icon)
	local weapon_icon = item_panel:bitmap({
		texture = icon,
		texture_rect = texture_rect,
		layer = 2,
		x = 4,
		y = 0,
		w = 32,
		h = 32,
	})

	local value_text = item_panel:text({
		text = managers.localization:text(definition.name_id),
		font = self.font.path,
		font_size = self.font.sizes.small,
		alpha = 1,
		layer = 2,
		x = weapon_icon:right() + 4,
	})
	self:update_text_rect(value_text)
	value_text:set_center_y(weapon_icon:center_y())

	local index_text = item_panel:text({
		text = tostring(data.index),
		font = self.font.path,
		font_size = self.font.sizes.tiny,
		color = self.colors.secondary,
		alpha = 0.75,
		layer = 2,
	})
	self:update_text_rect(index_text)
	index_text:set_right(item_panel:right() - 4)
	index_text:set_bottom(value_text:bottom())

	return { panel = item_panel, index = tonumber(data.index) }
end

function DropdownClass:is_mouse_in_panel(panel)
	if not alive(panel) then
		return false
	end

	return panel:inside(self.menu_mouse_x, self.menu_mouse_y)
end

function DropdownClass:check_dropdown_hover()
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
			return
		end
	end
end

function DropdownClass:mouse_move(_, x, y)
	self.menu_mouse_x, self.menu_mouse_y = x, y

	if not self.active_dropdown then --?
		return
	end

	self:check_dropdown_hover()
end

function DropdownClass:do_over_scroll(panel, amount, target)
	panel:stop()
	panel:animate(function(o)
		self:animate_ui(0.1, function(p)
			o:set_y(math.lerp(o:y(), target + amount, p))
		end)

		panel:animate(function(o)
			self:animate_ui(0.1, function(p)
				o:set_y(math.lerp(o:y(), target, p))
			end)
		end)
	end)
end

function DropdownClass:do_feature_scroll(panel, target, amount)
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
			self:check_feature_hover()
		end)
	end)

	return target
end

function DropdownClass:check_dropdown_click()
	local active_dropdown = self.active_dropdown
	if not self:is_mouse_in_panel(active_dropdown.panel) then
		self:close()
		return
	end

	for _, item in pairs(active_dropdown.items) do
		if self:is_mouse_in_panel(item.panel) then
			self:activate_dropdown_select_button(item)
			return
		end
	end
end

function DropdownClass:activate_dropdown_select_button(item)
	local active_dropdown = self.active_dropdown
	if not active_dropdown then
		return
	end

	local raw_parent = active_dropdown.parent.table_ptr
	raw_parent.node._current_index = tonumber(item.index) - 1
	raw_parent.node:next()
	raw_parent.kit:_reload_kitslot_item(raw_parent.node)

	self:close()
end

function DropdownClass:mouse_press(_, button, x, y)
	self.menu_mouse_x, self.menu_mouse_y = x, y

	if button == Idstring("0") then --LEFT CLICK
		if self.active_dropdown then
			self:check_dropdown_click()
			return
		end
	elseif button == Idstring("mouse wheel up") then
		if self.active_dropdown then
			local active_panel = self.active_dropdown
			if self:is_mouse_in_panel(active_panel.panel) then
				active_panel.target_y = self:do_feature_scroll(active_panel.scroll_panel, active_panel.target_y, 28)
				return
			end

			return
		end
	elseif button == Idstring("mouse wheel down") then
		if self.active_dropdown then
			local active_panel = self.active_dropdown
			if self:is_mouse_in_panel(active_panel.panel) then
				active_panel.target_y = self:do_feature_scroll(active_panel.scroll_panel, active_panel.target_y, -28)
				return
			end
			return
		end
	end
end

function DropdownClass:keyboard_cancel()
	if not self:is_open() then
		return
	end

	self:close()
end

if RequiredScript == "lib/states/ingamewaitingforplayers" then
	local IngameWaitingForPlayersState = module:hook_class("IngameWaitingForPlayersState")
	module:post_hook(IngameWaitingForPlayersState, "at_enter", function()
		if not rawget(_G, "DropDown") then
			rawset(_G, "DropDown", DropdownClass:new())
		end
	end)

	module:post_hook(IngameWaitingForPlayersState, "at_exit", function()
		if rawget(_G, "DropDown") then
			DropDown:destroy()
			_G.DropDown = nil
		end
	end)
end

if RequiredScript == "lib/managers/menu/menunodekitgui" then
	local MenuNodeKitGui = module:hook_class("MenuNodeKitGui")
	local DropDown
	module:post_hook(MenuNodeKitGui, "_create_menu_item", function(self, row_item)
		DropDown = DropDown or rawget(_G, "DropDown")

		if row_item.type ~= "kitslot" then
			return
		end

		local item = row_item.item

		item:set_parameter("item_confirm_callback", function()
			local base = row_item.choice_panel

			local panel_x = row_item.arrow_left:world_x()
			local padding = 10 * tweak_data.scale.align_line_padding_multiplier

			local item_type = item:parameters().category
			local panel = DropDown._panel:panel({
				y = base:world_y(),
				x = panel_x - padding,
				w = base:world_right() - panel_x + padding,
				h = base:h(),
				layer = 10000,
			})

			DropDown:open_dropdown_menu({
				panel = panel,
				table_ptr = {
					type = item_type,
					kit = self,
					node = item,
					items = item._options,
				},
			})
			return true
		end)
	end)
end

if RequiredScript == "lib/managers/menumanager" then
	local MenuManager = module:hook_class("MenuManager")
	local DropDown
	module:hook(MenuManager, "toggle_menu_state", function(self)
		DropDown = DropDown or rawget(_G, "DropDown")
		if DropDown and DropDown:is_open() then
			return
		end

		module:call_orig(MenuManager, "toggle_menu_state", self)
	end)
end
