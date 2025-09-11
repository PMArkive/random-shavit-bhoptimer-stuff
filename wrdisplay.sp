#define PLUGIN_NAME           "WR Display"
#define PLUGIN_AUTHOR         "carnifex, haooy"
#define PLUGIN_DESCRIPTION    "Displays WR at the top of screen"
#define PLUGIN_VERSION        "1.0.1"
#define PLUGIN_URL            ""

#include <sourcemod>
#include <sdktools>
#include <shavit>

#pragma semicolon 1

bool first[MAXPLAYERS+1] = false;
char link[128];
ConVar cv_link;

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
	RegAdminCmd("sm_test_wr", testwr, ADMFLAG_ROOT);
	HookEvent("player_spawn", Event_PlayerSpawn);
	cv_link = CreateConVar("shavit_wr_link_to_panel", "https://www.sourcemod.net/logo.png", "Link to the thing you want to show in wr panel.");
	
	AutoExecConfig(true, "shavit_wr_link");
	
	cv_link.GetString(link, sizeof(link));
}

public void OnClientPostAdminCheck(int client)
{
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		first[client] = true;
	}
}

public Action Event_PlayerSpawn(Event hEvent, const char[] chName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(first[client])
	{
		char buffer[PLATFORM_MAX_PATH];
		Format(buffer, PLATFORM_MAX_PATH, "%s%s%s%s", "<img src='", link, "'>", "</img>");
		PrintClientFinish1(client, buffer);
		first[client] = false;
	}
}

public Action testwr(int client, int args)
{
	char buffer[PLATFORM_MAX_PATH];
	Format(buffer, PLATFORM_MAX_PATH, "%s%s%s%s", "<img src='", link, "'>", "</img>");
	PrintClientFinish(client, buffer);
}

public Action Shavit_OnFinishMessage(int client, bool &everyone, timer_snapshot_t snapshot, int overwrite, int rank, char[] message, int maxlen)
{
	if(rank == 1)
	{
		char buffer[PLATFORM_MAX_PATH];
		Format(buffer, PLATFORM_MAX_PATH, "%s%s%s%s%s", "<img src='", link, "'>", "</img><br><br>", message);
		PrintClientFinish(client, buffer);
		//PrintToConsole(client, buffer);
	}
	return Plugin_Continue;
}

public void PrintClientFinish(int client, char[] buffer)
{
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		Event newevent = CreateEvent("cs_win_panel_round", true);
		newevent.SetString("funfact_token", buffer);
		newevent.FireToClient(client);
		
		CreateTimer(10.0, Timer_ClearScreen, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void PrintClientFinish1(int client, char[] buffer)
{
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		Event newevent = CreateEvent("cs_win_panel_round", true);
		newevent.SetString("funfact_token", buffer);
		newevent.FireToClient(client);
		
		CreateTimer(2.0, Timer_ClearScreen, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ClearScreen(Handle timer, int client)
{
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		ClearClientMessage(client);
	}
}

public void ClearClientMessage(int client)
{
	if(IsValidClient(client) && !IsFakeClient(client))
	{
		Event newevent = CreateEvent("cs_win_panel_round", true);
		newevent.SetString("funfact_token", "");
		newevent.FireToClient(client);
	}
}

