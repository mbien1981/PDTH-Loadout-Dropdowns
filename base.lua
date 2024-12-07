local module = DMod:new("loadout_dropdowns", {
	name = "Loadout dropdowns",
	description = "Allows you to open a dropdown gui out of your kit selection menu nodes",
	author = "_atom",
	version = "1.4",
	dependencies = { "[drop_in_menu]" },
	update = { id = "dropdowns", url = "https://raw.githubusercontent.com/mbien1981/dahm-modules/main/version.json" },
})

module:hook_post_require("lib/states/ingamewaitingforplayers", "dropdowns")
module:hook_post_require("lib/managers/menu/menunodekitgui", "dropdowns")
module:hook_post_require("lib/managers/menumanager", "dropdowns")

return module
