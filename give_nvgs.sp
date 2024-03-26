
#include <sdktools>

public void OnPluginStart()
{
	HookEvent("player_spawn", player_spawn);
}

void Frame_GiveNightvision(int serial)
{
	int client = GetClientFromSerial(serial);
	if (client) GivePlayerItem(client, "item_nvgs");
}

Action player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int serial = GetClientSerial(GetClientOfUserId(event.GetInt("userid")));
	RequestFrame(Frame_GiveNightvision, serial);
}
