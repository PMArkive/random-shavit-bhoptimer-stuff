public void OnMapStart()
{
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	if (StrContains(map, "escape_room_movement") == 0) {
		ServerCommand("sm plugins unload rngfix");
		ServerCommand("sm plugins unload momsurffix2");
		ServerCommand("sm plugins unload headbugfix");
	}
}