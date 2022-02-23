#include <sourcemod>
#include <shavit>

#define MAX_IMPOSSIBLE 30
//#define DEBUG

#pragma semicolon 1

int CASH_ImpossibleMovements[MAXPLAYERS + 1];
int CASH_NotificationCount[MAXPLAYERS + 1];

int CASH_PerfectOnground[MAXPLAYERS + 1];
int CASH_LastMovement[MAXPLAYERS + 1];

char PLUGIN_LOGFILE[PLATFORM_MAX_PATH];


ConVar Cvar_Bans_Enabled;
ConVar Cvar_Bans_Amount;
ConVar Cvar_Bans_Length;
ConVar Cvar_Bans_ServerURL;
ConVar Cvar_EnableAntiStrafe;

Handle g_hTimer;

EngineVersion gEV_Game;

public Plugin myinfo = {
	name = "[shavit] CASH",
	description = "cam anti-strafe-hack",
	author = "cam",
	version = "2001-0.3",
	url = "www.strafeodyssey.com"
};

public void OnPluginStart(){
	gEV_Game = GetEngineVersion();
	Cvar_Bans_Enabled 	= CreateConVar("timer_cash_bans_enabled", "0", "Enables or disables automatic bans", _, true, 0.0, true, 1.0);
	Cvar_Bans_Amount	= CreateConVar("timer_cash_bans_amount", "10", "If bans are enabled, determines how many CASH notifications before automatic ban (during one map)", _, true, 5.0, true, 30.0);
	Cvar_Bans_Length	= CreateConVar("timer_cash_bans_length", "0", "If bans are enabled, determines how long automatic bans should be (in minutes)", _, true, 0.0, false);

	Cvar_Bans_ServerURL = CreateConVar("timer_cash_bans_url", "", "Set the link to display in the kick message");

	Cvar_EnableAntiStrafe = CreateConVar("timer_cash_enable_antistrafe", "1", "READ CAREFULLY - With this enabled, it will block out many more cheats. HOWEVER. It will also detect people using +strafe. Use at own risk.");

	AutoExecConfig(true, "cash", "timer");

	BuildPath(Path_SM, PLUGIN_LOGFILE, PLATFORM_MAX_PATH, "logs/shavit-CASH.txt");
}

public void OnMapStart(){
	for(int client = 1; client <= MaxClients; client++){
		if(IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client)){
			CASH_ImpossibleMovements[client] = 0;
			CASH_NotificationCount[client] = 0;
		}
	}

	g_hTimer = CreateTimer(10.0, CASH_TimerCheck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd(){
	for(int client = 1; client <= MaxClients; client++){
		if(IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client)){
			CASH_ImpossibleMovements[client] = 0;
			CASH_NotificationCount[client] = 0;
		}
	}

	if(g_hTimer != INVALID_HANDLE)
	KillTimer(g_hTimer);
}

public void OnClientPutInServer(int client){
	CASH_ImpossibleMovements[client] = 0;
	CASH_NotificationCount[client] = 0;
}

public Action CASH_TimerCheck(Handle timer, any data){
	for(int client = 1; client <= MaxClients; client++){
		if(IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client)){
			if(CASH_ImpossibleMovements[client] > MAX_IMPOSSIBLE)
			CASH_SuspectPlayer(client);
		}
	}

	return Plugin_Handled;
}

void CASH_SuspectPlayer(int client){
	if((!IsClientConnected(client)) || (!IsClientInGame(client)))
	return;

	char sSpecial[128];
	int style = Shavit_GetBhopStyle(client);
	Shavit_GetStyleStrings(style, sSpecialString, sSpecial, 128);
	if(StrContains(sSpecial, "cash_bypass", false) != -1)
	return;

	char Log_Message[256];
	char clientIP[64];

	GetClientIP(client, clientIP, sizeof(clientIP));

	FormatEx(Log_Message, sizeof(Log_Message), "[CASH] Player %L [%s] made over 30 impossible movements in 10s! (impossible: %i)\n",
		client,
		clientIP,
		CASH_ImpossibleMovements[client]);

	LogToFile(PLUGIN_LOGFILE, Log_Message);

	for(int adminclient = 1; adminclient <= MaxClients; adminclient++){
		if(IsClientInGame(adminclient) && GetAdminFlag(GetUserAdmin(adminclient), Admin_Root, Access_Effective)){
			PrintToChat(client, "[CASH] Player %N has set off CASH. Check console.", client);

			PrintToConsole(client, Log_Message);
		}
	}

	CASH_ImpossibleMovements[client] = 0;
	CASH_NotificationCount[client]++;

	DoAutomaticBans();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon){
	char sSpecial[128];
	int style = Shavit_GetBhopStyle(client);
	Shavit_GetStyleStrings(style, sSpecialString, sSpecial, 128);
	if(StrContains(sSpecial, "cash_bypass", false) != -1)
	return;
	if(client != 0 && IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && !IsFakeClient(client)){

		if(Cvar_EnableAntiStrafe.BoolValue){
			if(RoundFloat(vel[0]) % 25 != 0.0)
			CASH_ImpossibleMovements[client]++;
			if(RoundFloat(vel[1]) % 25 != 0.0)
			CASH_ImpossibleMovements[client]++;
		}

		if(gEV_Game == Engine_CSS){
			if(vel[1] > 0)
			vel[1] = 400.0;
			else if(vel[1] < 0)
			vel[1] = -400.0;

			if(vel[0] > 0)
			vel[0] = 400.0;
			else if(vel[0] < 0)
			vel[0] = -400.0;
		}
		else if(gEV_Game == Engine_CSGO){
			if(vel[1] > 0)
			vel[1] = 450.0;
			else if(vel[1] < 0)
			vel[1] = -450.0;

			if(vel[0] > 0)
			vel[0] = 450.0;
			else if(vel[0] < 0)
			vel[0] = -450.0;
		}
		else{
			SetFailState("This plugin is for CSGO/CSS only.");
		}


		if(vel[1] < 0)
		{
			if(CASH_LastMovement[client] == IN_MOVELEFT){
				CASH_PerfectOnground[client]++;
			}
			else
			{
				CASH_PerfectOnground[client] = 0;
			}

			CASH_LastMovement[client] = IN_MOVERIGHT;
		}
		if(vel[1] > 0)
		{
			if(CASH_LastMovement[client] == IN_MOVERIGHT){
				CASH_PerfectOnground[client]++;
			}
			else
			{
				CASH_PerfectOnground[client] = 0;
			}

			CASH_LastMovement[client] = IN_MOVELEFT;
		}
	}
}

void DoAutomaticBans(){
	char cSteamID[32];
	char server_website[64];

	if(Cvar_Bans_Enabled.BoolValue || Cvar_Bans_Enabled.IntValue > 0 || Cvar_Bans_Enabled.FloatValue > 0.0){
		Cvar_Bans_ServerURL.GetString(server_website, sizeof(server_website));
		for(int client = 1; client <= MaxClients; client++){
			if(IsClientConnected(client) && IsClientInGame(client) && CASH_NotificationCount[client] > 0){
				if(CASH_NotificationCount[client] > Cvar_Bans_Amount.IntValue || CASH_NotificationCount[client] > Cvar_Bans_Amount.FloatValue){
					GetClientAuthId(client, AuthId_Steam2, cSteamID, sizeof(cSteamID));

					ServerCommand("sm_addban %d %s [CASH] Automated ban", Cvar_Bans_Length.IntValue, cSteamID);

					KickClient(client, "[CASH] Automated ban, check %s for more info.", server_website);
				}
			}
		}
	}
}
