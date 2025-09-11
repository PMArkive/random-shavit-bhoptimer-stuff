
#define DEBUG

#define PLUGIN_NAME           "WR Display"
#define PLUGIN_AUTHOR         "carnifex"
#define PLUGIN_DESCRIPTION    "Displays WR at the top of screen"
#define PLUGIN_VERSION        "1.0"
#define PLUGIN_URL            ""

#include <sourcemod>
#include <sdktools>
#include <shavit>

#pragma semicolon 1

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
}

public Action Shavit_OnFinishMessage(int client, bool &everyone, timer_snapshot_t snapshot, int overwrite, int rank, char[] message, int maxlen)
{
	if(rank == 1)
	{
		char buffer[PLATFORM_MAX_PATH];
		Format(buffer, PLATFORM_MAX_PATH, "%s%s%s", "<img src='url_to_image_here'>", "</img>", message);
		PrintClientFinish(client, buffer);
		PrintToConsole(client, buffer);
	}
	return Plugin_Continue;
}

public void PrintClientFinish(int client, char[] buffer)
{
	Event newevent = CreateEvent("cs_win_panel_round", true);
	newevent.SetString("funfact_token", buffer);
	newevent.FireToClient(client);
	
	CreateTimer(10.0, Timer_ClearScreen, client, 0);
}

public Action Timer_ClearScreen(Handle timer, int client)
{
	ClearClientMessage(client);
}

public void ClearClientMessage(int client)
{
	Event newevent = CreateEvent("cs_win_panel_round", true);
	newevent.SetString("funfact_token", "");
	newevent.FireToClient(client);
}

