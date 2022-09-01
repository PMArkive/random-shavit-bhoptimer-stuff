#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <shavit>

#define PLUGIN_VERSION "1.3"

#pragma newdecls required
#pragma semicolon 1

bool gB_Jumped[MAXPLAYERS+1];
bool gB_OnGround[MAXPLAYERS+1];
int gI_LandedAt[MAXPLAYERS+1];

bool g_bLate = false;
bool g_bShavit = false;

chatstrings_t gS_ChatStrings;

public Plugin myinfo =
{
	name = "[shavit] !perf",
	author = "shavit, Saenger.ItsWar, Uronic",
	description = "Plays a sound whenever you land a perfect jump.",
	version = PLUGIN_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("player_jump", Player_Jump);

	if(g_bLate)
	{
		Shavit_OnChatConfigLoaded();
	}

	g_bShavit = LibraryExists("shavit");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "shavit"))
	{
		g_bShavit = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "shavit"))
	{
		g_bShavit = false;
	}
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessagePrefix, gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix));
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
	Shavit_GetChatStrings(sMessageVariable2, gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2));
	Shavit_GetChatStrings(sMessageStyle, gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
}

public void OnMapStart()
{
	PrecacheSound("buttons/lightswitch2.wav", true);
}


public void Player_Jump(Event event, const char[] name, bool dontBroadcast)
{
	gB_Jumped[GetClientOfUserId(GetEventInt(event, "userid"))] = true;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(g_bShavit)
	{
		if(!IsPlayerAlive(client) || IsFakeClient(client) || !IsScroll(client))
		{
			return Plugin_Continue;
		}
	}

	else
	{
		if(!IsPlayerAlive(client) || IsFakeClient(client))
		{
			return Plugin_Continue;
		}
	}

	MoveType mtMoveType = GetEntityMoveType(client);
	bool bInWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2);

	int iTicks = GetGameTickCount();
	bool bOnGround = ((GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1) && mtMoveType == MOVETYPE_WALK && !bInWater);

	if(bOnGround && !gB_OnGround[client])
	{
		gI_LandedAt[client] = iTicks;
	}

	else if(!bOnGround && gB_OnGround[client] && gB_Jumped[client] && iTicks - gI_LandedAt[client] <= 1)
	{
		int[] iClients = new int[MaxClients];
		int iCount = 0;

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && GetObservingPlayer(i) == client)
			{
				iClients[iCount++] = i;
			}
		}

		if(iCount > 0)
		{
			EmitSound(iClients, iCount, "buttons/lightswitch2.wav");
			for (int i = 0; i < iCount; i++)
			{
				if(g_bShavit)
				{
					Shavit_StopChatSound();
					Shavit_PrintToChat(iClients[i], "%s Perfect Jump.", gS_ChatStrings.sPrefix);
				}
				
				else
				{
					PrintToChat(iClients[i], "\x01[\x06Perf\x01] Perfect Jump.");
				}
			}
		}
	}

	gB_OnGround[client] = bOnGround;
	gB_Jumped[client] = false;

	return Plugin_Continue;
}

int GetObservingPlayer(int client)
{
	int target = client;

	if(IsClientObserver(client))
	{
		int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if(iObserverMode >= 3 && iObserverMode <= 5)
		{
			int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if(IsValidClient(iTarget, true))
			{
				target = iTarget;
			}
		}
	}

	return target;
}

bool IsScroll(int client)
{
	if(Shavit_GetStyleSettingInt(Shavit_GetBhopStyle(client), "autobhop") == 0)
	{
		return true;
	}
	else
	{
		return false;
	}
}