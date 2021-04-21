#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

#define SOUND_PATH "shavit/perf.wav"

Handle gH_Cookie = null;

bool gB_Jumped[MAXPLAYERS+1];
bool gB_OnGround[MAXPLAYERS+1];
int gI_LandedAt[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[shavit] !perf",
	author = "shavit",
	description = "Plays a sound whenever you land a perfect jump.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public void OnPluginStart()
{
	gH_Cookie = RegClientCookie("shavit_perf", "Perfect jump sound.", CookieAccess_Protected);

	HookEvent("player_jump", Player_Jump);

	RegConsoleCmd("sm_perf", Command_Perf);
	RegConsoleCmd("sm_perfect", Command_Perf);
	RegConsoleCmd("sm_perfectjump", Command_Perf);
	RegConsoleCmd("sm_perfjump", Command_Perf);
}

public void OnMapStart()
{
	AddFileToDownloadsTable("sound/" ... SOUND_PATH);
	PrecacheSound(SOUND_PATH, true);
}

public void Player_Jump(Event event, const char[] name, bool dontBroadcast)
{
	gB_Jumped[GetClientOfUserId(GetEventInt(event, "userid"))] = true;
}

public Action Command_Perf(int client, int args)
{
	bool bEnabled = IsEnabled(client);
	SetClientCookie(client, gH_Cookie, (bEnabled)? "0":"1");

	char sText[chatstrings_t::sText];
	Shavit_GetChatStrings(sMessageText, sText, chatstrings_t::sText);

	char sVariable[chatstrings_t::sVariable];
	Shavit_GetChatStrings(sMessageVariable, sVariable, chatstrings_t::sVariable);

	char sWarning[chatstrings_t::sWarning];
	Shavit_GetChatStrings(sMessageWarning, sWarning, chatstrings_t::sWarning);

	if(bEnabled)
	{
		Shavit_PrintToChat(client, "Perfect jump sound %sdisabled%s.", sWarning, sText);
	}

	else
	{
		Shavit_PrintToChat(client, "Perfect jump sound %senabled%s.", sVariable, sText);
	}

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsPlayerAlive(client) || IsFakeClient(client) || !IsScroll(client))
	{
		return Plugin_Continue;
	}

	MoveType mtMoveType = GetEntityMoveType(client);
	bool bInWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2);

	int iTicks = GetGameTickCount();
	int iMaxTicks = (IsFairScroll(client))? 2:1;
	bool bOnGround = ((GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1) && mtMoveType == MOVETYPE_WALK && !bInWater);

	if(bOnGround && !gB_OnGround[client])
	{
		gI_LandedAt[client] = iTicks;
	}

	// perfect jump
	else if(!bOnGround && gB_OnGround[client] && gB_Jumped[client] && iTicks - gI_LandedAt[client] <= iMaxTicks)
	{
		int[] iClients = new int[MaxClients];
		int iCount = 0;

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && GetObservingPlayer(i) == client && IsEnabled(i))
			{
				iClients[iCount++] = i;
			}
		}

		if(iCount > 0)
		{
			EmitSound(iClients, iCount, SOUND_PATH);
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
	bool bAutoBhop = Shavit_GetStyleSettingBool(Shavit_GetBhopStyle(client), "autobhop");

	return !bAutoBhop;
}

bool IsFairScroll(int client)
{
	char sSpecial[sizeof(stylestrings_t::sSpecialString)];
	Shavit_GetStyleStrings(Shavit_GetBhopStyle(client), sSpecialString, sSpecial, sizeof(sSpecial));

	return (StrContains(sSpecial, "fairscroll", false) != -1);
}

bool IsEnabled(int client)
{
	char sSetting[4];
	GetClientCookie(client, gH_Cookie, sSetting, 4);

	if(strlen(sSetting) == 0)
	{
		SetClientCookie(client, gH_Cookie, "0");

		return false;
	}

	return view_as<bool>(StringToInt(sSetting));
}
