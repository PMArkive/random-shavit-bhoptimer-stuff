#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <shavit>


Address g_iPatchAddress;
int g_iPatchRestore[100];
int g_iPatchRestoreBytes;

bool g_bUnlockMovement[MAXPLAYERS + 1] = { true, ... };

// cookies
Handle gH_NoslideCookie = null;

bool gB_EnabledPlayers[MAXPLAYERS+1];
int gI_GroundTicks[MAXPLAYERS+1];
bool gB_ActivateNoSlide[MAXPLAYERS+1] = {false, ...};

enum
{
	String_NotFound = -1,
	String_Found_Start = 0,
	String_Found_Other
};

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "CS:GO Movement Unlocker",
	author = "Peace-Maker",
	description = "Removes max speed limitation from players on the ground. Feels like CS:S.",
	version = PLUGIN_VERSION,
	url = "http://www.wcfan.de/"
}

public void OnPluginStart()
{
	gH_NoslideCookie = RegClientCookie("noslide_enabled", "Noslide settings", CookieAccess_Protected);


	AutoExecConfig();

	RegConsoleCmd("sm_noslide", Command_Noslide, "Toggles noslide.");
	// Load the gamedata file.
	Handle hGameConf = LoadGameConfigFile("csgo_movement_unlocker.games");
	if(hGameConf == null)
		SetFailState("Can't find csgo_movement_unlocker.games.txt gamedata.");

	// Get the address near our patch area inside CGameMovement::WalkMove
	Address iAddr = GameConfGetAddress(hGameConf, "WalkMoveMaxSpeed");
	if(iAddr == Address_Null)
	{
		CloseHandle(hGameConf);
		SetFailState("Can't find WalkMoveMaxSpeed address.");
	}

	// Get the offset from the start of the signature to the start of our patch area.
	int iCapOffset = GameConfGetOffset(hGameConf, "CappingOffset");
	if(iCapOffset == -1)
	{
		CloseHandle(hGameConf);
		SetFailState("Can't find CappingOffset in gamedata.");
	}

	// Move right in front of the instructions we want to NOP.
	iAddr += view_as<Address>(iCapOffset);
	g_iPatchAddress = iAddr;

	// Get how many bytes we want to NOP.
	g_iPatchRestoreBytes = GameConfGetOffset(hGameConf, "PatchBytes");

	delete hGameConf;

	if(g_iPatchRestoreBytes == -1)
	{
		delete hGameConf;
		SetFailState("Can't find PatchBytes in gamedata.");
	}


	//PrintToServer("CGameMovement::WalkMove VectorScale(wishvel, mv->m_flMaxSpeed/wishspeed, wishvel); ... at address %x", g_iPatchAddress);

	for(int i = 0; i < g_iPatchRestoreBytes; ++i)
	{
		// Save the current instructions, so we can restore them on unload.
		g_iPatchRestore[i] = LoadFromAddress(iAddr, NumberType_Int8);

		// NOP
		StoreToAddress(iAddr, 0x90, NumberType_Int8);

		iAddr++;
	}
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsClientInGame(i) && AreClientCookiesCached(i))
		{
			OnClientPutInServer(i);
			OnClientCookiesCached(i);
		}
	}
}

public void OnPluginEnd()
{
	// Restore the original instructions, if we patched them.
	UnpatchGame();
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	g_bUnlockMovement[client] = true;

	if(!AreClientCookiesCached(client))
		gB_EnabledPlayers[client] = false;

	SDKHook(client, SDKHook_PreThinkPost, Hook_PreThinkPost);
	SDKHook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
}

public void OnClientCookiesCached(int client)
{
	char[] sSetting = new char[8];
	GetClientCookie(client, gH_NoslideCookie, sSetting, 8);

	if(strlen(sSetting) == 0)
	{
		SetClientCookie(client, gH_NoslideCookie, "0");
		gB_EnabledPlayers[client] = false;
	}

	else
		gB_EnabledPlayers[client] = view_as<bool>(StringToInt(sSetting));

}

public void Hook_PreThinkPost(int client)
{
	if(g_bUnlockMovement[client] == false)
	{
		UnpatchGame();
	}
	else if(gB_ActivateNoSlide[client])
	{
		UnpatchGame();
	}

}

public void Hook_PostThinkPost(int client)
{
	if(g_bUnlockMovement[client] == false)
	{
		RepatchGame();
	}
	else if(gB_ActivateNoSlide[client] == false)
	{
		RepatchGame();
	}

}

stock void Command_MovementUnlocker(int client, int args)
{
	g_bUnlockMovement[client] = !g_bUnlockMovement[client];
	ReplyToCommand(client, "[SM] Movement Unlocker now %s", g_bUnlockMovement[client] ? "Enabled" : "Disabled");
	
}

void RepatchGame() // movement unlocker on
{
	if(g_iPatchAddress != Address_Null)
	{
		for(int i = 0; i < g_iPatchRestoreBytes; ++i)
		{
			StoreToAddress(g_iPatchAddress + view_as<Address>(i), 0x90, NumberType_Int8);
		}
	}
}

void UnpatchGame() // movement unlocker off
{
	if(g_iPatchAddress != Address_Null)
	{
		for(int i = 0; i < g_iPatchRestoreBytes; ++i)
		{
			StoreToAddress(g_iPatchAddress + view_as<Address>(i), g_iPatchRestore[i], NumberType_Int8);
		}
	}
}

public Action Command_Noslide(int client, int args)
{
	gB_EnabledPlayers[client] = !gB_EnabledPlayers[client];

	char[] message = new char[32];
	FormatEx(message, 32, "Noslide is now %s.", (gB_EnabledPlayers[client])? "enabled":"disabled");

	Shavit_PrintToChat(client, "%s", message);

	return Plugin_Handled;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle)
{
	char sSpecial[128];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sSpecial, 128);

	gI_Style[client] = newstyle;
	gF_TimeScale[client] = 1.0;

	if(StrContains(sSpecial, "TAS", false) != String_NotFound)
	{
		gB_TAS[client] = true;
	}
	else
	{
		gB_TAS[client] = false;
	}
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style, any stylesettings[STYLESETTINGS_SIZE], int mouse[2])
{
	if(!stylesettings[bEasybhop])
	{
		gB_ActivateNoSlide[client] = false;
		g_bUnlockMovement[client] = false;
		return Plugin_Continue;
	}
	else
	{
		g_bUnlockMovement[client] = true;
	}

	if(!IsPlayerAlive(client)) // is player dead
		return Plugin_Continue;

	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1) // not on the ground
	{
		gI_GroundTicks[client] = 0;
		gB_ActivateNoSlide[client] = false;
		return Plugin_Continue;
	}

	if(!gB_EnabledPlayers[client] || (buttons & IN_JUMP) == IN_JUMP)// if disabled or if holding jump don't activate noslide
	{
		gB_ActivateNoSlide[client] = false;
		return Plugin_Continue;
	}

	if(++gI_GroundTicks[client] == 3 )
	{
		gB_ActivateNoSlide[client] = true;
	}
	else
	{
		gB_ActivateNoSlide[client] = false;
	}


	return Plugin_Continue;
}