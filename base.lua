local module = DMod:new("loadout_dropdowns", {
	name = "Loadout dropdowns",
	description = "Allows you to open a dropdown gui out of your kit selection menu nodes",
	author = "_atom",
	version = "1.1",
	dependencies = { "[drop_in_menu]" },
})

module:hook_post_require("lib/states/ingamewaitingforplayers", "dropdowns")
module:hook_post_require("lib/managers/menu/menunodekitgui", "dropdowns")
module:hook_post_require("lib/managers/menumanager", "dropdowns")

return module
