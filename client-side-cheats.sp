#include <sourcemod>
#include <cstrike>
#include <clientprefs>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

ConVar sv_cheats;
bool gB_Cheats[MAXPLAYERS + 1];
Handle gH_CheatsCookie;

public Plugin myinfo =
{
	name = "Client-side Cheats",
	author = "Juked",
	description = "Enables client-side cheats.",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_cheats", Command_Cheats, "Enables client side cheats.");

	sv_cheats = FindConVar("sv_cheats");

	gH_CheatsCookie = RegClientCookie("cheats_enabled", "", CookieAccess_Protected);
}

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}

	if (!GetClientCookieBool(client, gH_CheatsCookie, gB_Cheats[client]))
	{
		gB_Cheats[client] = false;
		SetClientCookieBool(client, gH_CheatsCookie, false);
	}

	if (gB_Cheats[client])
	{
		sv_cheats.ReplicateToClient(client, "1");
	}
	else
	{
		sv_cheats.ReplicateToClient(client, "0");
	}
}

public Action Command_Cheats(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	ShowMenu(client);

	return Plugin_Handled;
}

void ShowMenu(int client)
{
	Menu menu = CreateMenu(Menu_Callback);
	menu.SetTitle("Client-side Cheats\n \n");

	char buffer[256];
	Format(buffer, sizeof(buffer), "Cheats: %s", gB_Cheats[client] ? "[ON]" : "[OFF]");
	menu.AddItem("cheats", buffer);

	menu.AddItem("vcollide", "Model Collision");
	menu.AddItem("water", "Water");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Callback(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));

			if (StrEqual(item, "vcollide"))
			{
				PrintToChat(client, "[SM] Usage: 'vcollide_wireframe 1'");
				ShowMenu(client);
			}
			else if (StrEqual(item, "water"))
			{
				PrintToChat(client, "[SM] Usage: 'mat_drawwater 0'");
				ShowMenu(client);
			}
			else if (StrEqual(item, "cheats"))
			{
				gB_Cheats[client] = !gB_Cheats[client];
				SetClientCookieBool(client, gH_CheatsCookie, gB_Cheats[client]);

				if (gB_Cheats[client])
				{
					sv_cheats.ReplicateToClient(client, "1");
					PrintToChat(client, "[SM] Enabled client-side cheats.");
					ShowMenu(client);
				}
				else
				{
					sv_cheats.ReplicateToClient(client, "0");
					PrintToChat(client, "[SM] Disabled client-side cheats.");
					ShowMenu(client);
				}
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

stock bool IsValidClient(int client)
{
	return (0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

stock void SetClientCookieBool(int client, Handle cookie, bool value)
{
	SetClientCookie(client, cookie, value ? "1" : "0");
}

stock bool GetClientCookieBool(int client, Handle cookie, bool& value)
{
	char buffer[8];
	GetClientCookie(client, cookie, buffer, sizeof(buffer));

	if (buffer[0] == '\0')
	{
		return false;
	}

	value = StringToInt(buffer) != 0;
	return true;
}
