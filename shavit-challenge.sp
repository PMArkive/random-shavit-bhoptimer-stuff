#include <sourcemod>
#include <shavit>
#include <shavit_challenge>

#pragma newdecls required
#pragma semicolon 1

bool gB_Challenge[MAXPLAYERS + 1];
bool gB_Challenge_Abort[MAXPLAYERS + 1];
bool gB_Challenge_Request[MAXPLAYERS + 1];
bool gB_ClientFrozen[MAXPLAYERS + 1];
bool gB_Late = false;
bool gB_Stats = false;

char gS_Challenge_OpponentID[MAXPLAYERS + 1][32];
char gS_SteamID[MAXPLAYERS + 1][32];
char gS_MySQLPrefix[32];

int gI_CountdownTime[MAXPLAYERS + 1];
int gI_Styles = 0;
int gI_ChallengeStyle[MAXPLAYERS + 1];
int gI_Track[MAXPLAYERS + 1];
int gI_ClientTrack[MAXPLAYERS + 1];
int gI_OpponentClientID[MAXPLAYERS + 1];
int gI_TopPlayerCount = 0;
int gI_ChallengeDuration[MAXPLAYERS + 1];
int gI_PlayerRank[MAXPLAYERS + 1];
int gI_PlayerCount = 0;

float gF_PlayerPoints[MAXPLAYERS + 1];
float gF_minTime[MAXPLAYERS + 1] = {0.0, ...};

Handle gH_Timer_Countdown = INVALID_HANDLE;
Handle gH_Timer_Race = INVALID_HANDLE;

Database gH_SQL = null;
ConVar gCV_CountdownTime = null;
ConVar gCV_K = null;
Menu gH_Top100Menu = null;

chatstrings_t gS_ChatStrings;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
stylesettings_t gA_StyleSettings[STYLE_LIMIT];

public Plugin myinfo = 
{
	name = "Shavit Race Mode",
	author = "Evan & emKay",
	description = "Allows players to race each other",
	version = "2.0"
}

public void OnPluginStart()
{
	LoadTranslations("shavit-challenge.phrases");
	LoadTranslations("shavit-common.phrases");

	RegConsoleCmd("sm_challenge", Command_Challenge, "[Challenge] allows you to start a race against others");
	RegConsoleCmd("sm_race", Command_Challenge, "[Challenge] allows you to start a race against others");
	RegConsoleCmd("sm_duel", Command_Challenge, "[Challenge] allows you to start a race against others");
	RegConsoleCmd("sm_wyscig", Command_Challenge, "[Challenge] allows you to start a race against others");
	// RegAdminCmd("sm_challenge", Command_Challenge, ADMFLAG_GENERIC, "[Challenge] allows you to start a race against others");
	// RegAdminCmd("sm_race", Command_Challenge, ADMFLAG_GENERIC, "[Challenge] allows you to start a race against others");
	// RegAdminCmd("sm_duel", Command_Challenge, ADMFLAG_GENERIC, "[Challenge] allows you to start a race against others");
	// RegAdminCmd("sm_wyscig", Command_Challenge, ADMFLAG_GENERIC, "[Challenge] allows you to start a race against others");

	RegConsoleCmd("sm_accept", Command_Accept, "[Challenge] allows you to accept a challenge request");
	RegConsoleCmd("sm_acc", Command_Accept, "[Challenge] allows you to accept a challenge request");

	RegConsoleCmd("sm_surrender", Command_Surrender, "[Challenge] surrender your current challenge");
	RegConsoleCmd("sm_surr", Command_Surrender, "[Challenge] surrender your current challenge");

	RegConsoleCmd("sm_abort", Command_Abort, "[Challenge] abort your current challenge");

	RegConsoleCmd("sm_topchallenge", Command_TopRace, "[Challenge] show top 100 race winners");
	RegConsoleCmd("sm_toprace", Command_TopRace, "[Challenge] show top 100 race winners");
	RegConsoleCmd("sm_topduel", Command_TopRace, "[Challenge] show top 100 race winners");

	RegConsoleCmd("sm_rankchallenge", Command_Rank, "[Challenge] show player rank and points");
	RegConsoleCmd("sm_rankrace", Command_Rank, "[Challenge] show player rank and points");
	RegConsoleCmd("sm_rankduel", Command_Rank, "[Challenge] show player rank and points");

	RegAdminCmd("sm_racetableupdate", Command_RaceUpdate, ADMFLAG_ROOT, "Updates user table to count race wins/losses");
	
	gCV_CountdownTime = CreateConVar("shavit_challenge_countdown_time", "5", "Length of race countdown (in seconds).", 0, true, 0.0);
	gCV_K = CreateConVar("shavit_challenge_k", "300.0", "K constant value", 0, true, 1.0, true, 10000.0);
	
	AutoExecConfig(true, "shavit_challenge");
	
	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
		
		Shavit_OnChatConfigLoaded();
		Shavit_OnStyleConfigLoaded(-1);
	}
	
	SQL_DBConnect();
}

// public void OnMapStart() {
// 	if (gH_Timer_Countdown != INVALID_HANDLE) {
// 		//KillTimer(gH_Timer_Countdown, 1);
// 		gH_Timer_Countdown = INVALID_HANDLE;
// 	}

// 	if (gH_Timer_Race != INVALID_HANDLE) {
// 		//KillTimer(gH_Timer_Race, 1);v
// 		gH_Timer_Race = INVALID_HANDLE;
// 	}
// }

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3]) {
	if(gB_ClientFrozen[client]) {
		vel[0] = 0.0;
		vel[1] = 0.0;

		buttons &= ~IN_FORWARD;
		buttons &= ~IN_MOVELEFT;
		buttons &= ~IN_MOVERIGHT;
		buttons &= ~IN_BACK;
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;

	RegPluginLibrary("shavitchallenge");
	
	CreateNative("Challenge_IsClientFrozen", Native_IsClientFrozen);
	CreateNative("Challenge_IsClientInRace", Native_IsClientInRace);

	return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
	GetClientAuthId(client, AuthId_Steam2, gS_SteamID[client], MAX_NAME_LENGTH, true);
	
	gB_Challenge[client] = false;
	gB_Challenge_Request[client] = false;
}

public void OnClientConnected(int client) {
	gI_PlayerRank[client] = 0;
	gF_PlayerPoints[client] = 0.0;
	gI_OpponentClientID[client] = 0;
	gB_ClientFrozen[client] = false;
}

public void OnClientPostAdminCheck(int client) {
	updateRank(client);
}

public void OnClientDisconnect(int client) {
	if (Challenge_IsClientInRace(client)) {
		int opponent = gI_OpponentClientID[client];
		
		char sName[MAX_NAME_LENGTH];
		char sNameOpponent[MAX_NAME_LENGTH];

		GetClientName(client, sName, MAX_NAME_LENGTH);
		GetClientName(opponent, sNameOpponent, MAX_NAME_LENGTH);

		Shavit_PrintToChatAll("%t", "ChallengeRaceDisconnect", gS_ChatStrings.sVariable2, sNameOpponent, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sName, gS_ChatStrings.sWarning);

		int style = gI_ChallengeStyle[client];

		if (isStyleRanked(style)) {
			UpdateWins(opponent, client);
			// updateRank(client);
			updateRank(opponent);
		}

		gB_Challenge[client] = false;
		gB_Challenge[opponent] = false;
		gB_ClientFrozen[client] = false;
		gB_ClientFrozen[opponent] = false;
		gI_OpponentClientID[client] = 0;
		gI_OpponentClientID[opponent] = 0;
		gI_ChallengeDuration[client] = 0;
		gI_ChallengeDuration[opponent] = 0;
	}
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
	Shavit_GetChatStrings(sMessageVariable2, gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2));
	Shavit_GetChatStrings(sMessageStyle, gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	if(styles == -1)
	{
		styles = Shavit_GetStyleCount();
	}

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleSettings(i, gA_StyleSettings[i]);
		Shavit_GetStyleStrings(i, sStyleName, gS_StyleStrings[i].sStyleName, sizeof(stylestrings_t::sStyleName));
	}

	gI_Styles = styles;
}

public Action Command_Challenge(int client, int args)
{
	if (IsValidClient(client) && !Challenge_IsClientInRace(client) && !gB_Challenge_Request[client])
	{
		if (IsPlayerAlive(client))
		{
			char sPlayerName[MAX_NAME_LENGTH];
			Menu menu = new Menu(ChallengeMenuHandler);
			menu.SetTitle("%T", "ChallengeMenuTitle", client);
			int playerCount = 0;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && IsPlayerAlive(i) && i != client && !IsFakeClient(i))
				{
					GetClientName(i, sPlayerName, MAX_NAME_LENGTH);
					menu.AddItem(sPlayerName, sPlayerName);
					playerCount++;
				}
			}
			
			if (playerCount > 0)
			{
				menu.ExitButton = true;
				menu.Display(client, 30);
			}
			
			else
			{
				Shavit_PrintToChat(client, "%T", "ChallengeNoPlayers", client);
			}
		}
		
		else
		{
			Shavit_PrintToChat(client, "%T", "ChallengeInRace", client);
		}
	}
	
	return Plugin_Handled;
}

public int ChallengeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		char sPlayerName[MAX_NAME_LENGTH];
		char sTargetName[MAX_NAME_LENGTH];
		GetClientName(param1, sPlayerName, MAX_NAME_LENGTH);
		menu.GetItem(param2, sInfo, 16);
		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && i != param1)
			{
				GetClientName(i, sTargetName, MAX_NAME_LENGTH);

				if (StrEqual(sInfo, sTargetName))
				{
					if (!Challenge_IsClientInRace(i) && !gB_Challenge_Request[i]) {
						char sSteamId[32];
						GetClientAuthId(i, AuthId_Steam2, sSteamId, MAX_NAME_LENGTH, true);
						Format(gS_Challenge_OpponentID[param1], 32, sSteamId);
						SelectStyle(param1);		
					} else
					{
						Shavit_PrintToChat(param1, "%T", "ChallengeOpponentInRace", param1, gS_ChatStrings.sVariable2, sTargetName, gS_ChatStrings.sText);
					}
				}
			}
		}
	}
	
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int TopMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		menu.GetItem(param2, sInfo, 32);

		if(gB_Stats && !StrEqual(sInfo, "-1"))
		{
			Shavit_OpenStatsMenu(param1, StringToInt(sInfo));
		}
	}

	return 0;
}

void SelectStyle(int param1) {
	
	Menu menu = new Menu(ChallengeMenuHandler2);
	menu.SetTitle("%T", "ChallengeMenuTitle2", param1);
	
	int[] styles = new int[gI_Styles];
	Shavit_GetOrderedStyles(styles, gI_Styles);

	for(int j = 0; j < gI_Styles; j++) {
		
		int iStyle = styles[j];
		int opponent = gI_OpponentClientID[param1];
		

		char sInfo[8];
		IntToString(iStyle, sInfo, 8);

		if (checkVip(param1, j) && checkVip(opponent, j)) {
			menu.AddItem(sInfo, gS_StyleStrings[iStyle].sStyleName);
		} else {
			menu.AddItem(sInfo, gS_StyleStrings[iStyle].sStyleName, ITEMDRAW_DISABLED);
		}
		
	}
	
	menu.ExitButton = true;
	menu.Display(param1, 30);
}

public bool checkVip(int client, int style) {
	return (CheckCommandAccess(client, "sm_style_override", ADMFLAG_RESERVATION | ADMFLAG_CUSTOM1) && gA_StyleSettings[style].iSpecial == 1) || gA_StyleSettings[style].iSpecial != 1;
}

public int ChallengeMenuHandler2(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		int style = StringToInt(sInfo);
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && IsPlayerAlive(i) && i != param1)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[param1]))
				{
					gI_ChallengeStyle[i] = style;
					gI_ChallengeStyle[param1] = style;
					
					if(Shavit_ZoneExists(Zone_Start, Track_Bonus))
					{
						SelectTrack(param1);
					}
					
					else
					{						
						SelectTime(param1);
					}
				}	
			}	
		}	
	}
	
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void SelectTrack(int param1)
{
	char sInfo[8];
	Menu menu = new Menu(ChallengeMenuHandler3);
	menu.SetTitle("%T", "ChallengeMenuTitle3", param1);

	for(int i = 0; i < TRACKS_SIZE; i++)
	{
		IntToString(i, sInfo, 8);

		char sTrack[32];
		GetTrackName(param1, i, sTrack, 32);

		menu.AddItem(sInfo, sTrack);
	}
	
	menu.ExitButton = true;
	menu.Display(param1, 30);
}

// param1 = client, param2 = value
public int ChallengeMenuHandler3(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{	
		char sInfo[8];
		menu.GetItem(param2, sInfo, 8);
		int gI_TrackSelect = StringToInt(sInfo);
		gI_Track[param1] = gI_TrackSelect;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != param1)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[param1]))
				{
					SelectTime(param1);
				}
			}
		}
	}
	
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

void SelectTime(int param1) {
	Menu menu = new Menu(ChallengeMenuHandler4);
	menu.SetTitle("%T", "ChallengeMenuTitle4", param1);

	char[] sInfo1 = new char[32];
	FormatEx(sInfo1, 32, "1 min");
	char[] sInfo3 = new char[32];
	FormatEx(sInfo3, 32, "3 min");
	char[] sInfo5 = new char[32];
	FormatEx(sInfo5, 32, "5 min");
	char[] sInfo10 = new char[32];
	FormatEx(sInfo10, 32, "10 min");

	menu.AddItem("1", sInfo1);
	menu.AddItem("3", sInfo3);
	menu.AddItem("5", sInfo5);
	menu.AddItem("10", sInfo10);

	menu.ExitButton = true;
	menu.Display(param1, 30);
}

public int ChallengeMenuHandler4(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[32];
		char sTrack[8];
		char sPlayerName[MAX_NAME_LENGTH];
		char sTargetName[MAX_NAME_LENGTH];
		GetClientName(param1, sPlayerName, MAX_NAME_LENGTH);
		menu.GetItem(param2, sInfo, 32);

		if(gI_Track[param1] == 0) {
			sTrack = "Main";
		}
		else if (gI_Track[param1] == 1) {
			sTrack = "Bonus";
		}

		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != param1)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[param1]))
				{
					if (gB_Challenge_Request[i]) {
						Shavit_PrintToChat(i, "%T", "ChallengeOpponentInRace", i, gS_ChatStrings.sVariable2, sTargetName, gS_ChatStrings.sText);
					} else {
						gI_ChallengeDuration[i] = StringToInt(sInfo) * 60;
						gI_ChallengeDuration[param1] = StringToInt(sInfo) * 60;

						GetClientName(i, sTargetName, MAX_NAME_LENGTH);
						GetClientName(param1, sPlayerName, MAX_NAME_LENGTH);
						Shavit_PrintToChat(param1, "%T", "ChallengeRequestSent", param1, gS_ChatStrings.sVariable2, sTargetName);
						Shavit_PrintToChat(i, "%T", "ChallengeRequestReceive", i,
							gS_ChatStrings.sVariable2,
							sPlayerName,
							gS_ChatStrings.sText,
							gS_ChatStrings.sStyle,
							gS_StyleStrings[gI_ChallengeStyle[param1]].sStyleName,
							gS_ChatStrings.sText,
							gS_ChatStrings.sStyle,
							sTrack,
							gS_ChatStrings.sText,
							gS_ChatStrings.sVariable2,
							(gI_ChallengeDuration[i] / 60),
							gS_ChatStrings.sText,
							gS_ChatStrings.sVariable
						);		
						CreateTimer(20.0, Timer_Request, GetClientUserId(param1));
						gB_Challenge_Request[param1] = true;

						char[] sound1 = "play buttons\\bell1";
						ClientCommand(i, sound1);
					}
					
				}
			}
		}
	}
	
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action Command_Accept(int client, int args)
{
	char sSteamId[32];
	char sTrack[8];
	GetClientAuthId(client, AuthId_Steam2, sSteamId, MAX_NAME_LENGTH, true);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && i != client && gB_Challenge_Request[i])
		{
			if (StrEqual(sSteamId, gS_Challenge_OpponentID[i]))
			{
				gI_OpponentClientID[client] = i;
				gI_OpponentClientID[i] = client;
				
				GetClientAuthId(i, AuthId_Steam2, gS_Challenge_OpponentID[client], MAX_NAME_LENGTH, true);
				gB_Challenge_Request[i] = false;
				
				gB_Challenge_Abort[client] = false;
				gB_Challenge_Abort[i] = false;

				Shavit_ChangeClientStyle(client, gI_ChallengeStyle[client]);
				Shavit_ChangeClientStyle(i, gI_ChallengeStyle[i]);
				
				gB_Challenge[client] = true;
				gB_Challenge[i] = true;
				
				// SetEntityMoveType(client, MOVETYPE_NONE);
				// SetEntityMoveType(i, MOVETYPE_NONE);
				
				Shavit_RestartTimer(client, gI_Track[i]);
				Shavit_RestartTimer(i, gI_Track[i]);
				
				gI_ClientTrack[client] = gI_Track[i];
				gI_ClientTrack[i] = gI_Track[i];

				gB_ClientFrozen[client] = true;
				gB_ClientFrozen[i] = true;
				
				gI_CountdownTime[client] = gCV_CountdownTime.IntValue;
				gI_CountdownTime[i] = gCV_CountdownTime.IntValue;
				
				if (gH_Timer_Countdown != INVALID_HANDLE){
					CloseHandle(gH_Timer_Countdown);
					gH_Timer_Countdown = INVALID_HANDLE;
			}

				gH_Timer_Countdown = CreateTimer(1.0, Timer_Countdown, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		
				Shavit_PrintToChat(client, "%T", "ChallengeAccept", client);
				Shavit_PrintToChat(i, "%T", "ChallengeAccept", i);
				
				char sPlayer1[MAX_NAME_LENGTH];
				char sPlayer2[MAX_NAME_LENGTH];

				GetClientName(i, sPlayer1, MAX_NAME_LENGTH);
				GetClientName(client, sPlayer2, MAX_NAME_LENGTH);
				
				if(gI_Track[i] == 0)
				{
					sTrack = "Main";
				}
				else if(gI_Track[i] == 1)
				{
					sTrack = "Bonus";
				}

				Shavit_PrintToChatAll("%t", "ChallengeAnnounce", sPlayer1, sPlayer2, gS_ChatStrings.sStyle, gS_StyleStrings[gI_ChallengeStyle[client]].sStyleName, gS_ChatStrings.sText, gS_ChatStrings.sStyle, sTrack);
				
				// CreateTimer(1.0, CheckChallenge, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				// CreateTimer(1.0, CheckChallenge, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	return Plugin_Handled;
}

public void OnMapEnd() {
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i))
		{
			gB_Challenge[i] = false;
			gB_Challenge_Request[i] = false;
			gI_OpponentClientID[i] = 0;
			gB_ClientFrozen[i] = false;
			gI_ChallengeDuration[i] = 0;

			if (gH_Timer_Countdown != INVALID_HANDLE){
				//KillTimer(gH_Timer_Countdown, 1);
				gH_Timer_Countdown = INVALID_HANDLE;
			}

			if (gH_Timer_Race != INVALID_HANDLE){
				//KillTimer(gH_Timer_Race, 1);
				gH_Timer_Race = INVALID_HANDLE;
			}
		}
	}
}

public Action Command_Surrender(int client, int args) {
	char sSteamIdOpponent[MAX_NAME_LENGTH];
	char sNameOpponent[MAX_NAME_LENGTH];
	char sName[MAX_NAME_LENGTH];
	if(Challenge_IsClientInRace(client))
	{
		GetClientName(client, sName, MAX_NAME_LENGTH);
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i) && i != client)
			{
				GetClientAuthId(i, AuthId_Steam2, sSteamIdOpponent, MAX_NAME_LENGTH, true);
				if(StrEqual(sSteamIdOpponent, gS_Challenge_OpponentID[client]))
				{
					GetClientName(i, sNameOpponent, MAX_NAME_LENGTH);
					gB_Challenge[i] = false;
					gB_Challenge[client] = false;
					
					gB_ClientFrozen[client] = false;
					gB_ClientFrozen[i] = false;

					gI_OpponentClientID[client] = 0;
					gI_OpponentClientID[i] = 0;
					
					gI_ChallengeDuration[client] = 0;
					gI_ChallengeDuration[i] = 0;
					
					int style = gI_ChallengeStyle[client];
					if (isStyleRanked(style)) {
						UpdateWins(i, client);
						updateRank(i);
						updateRank(client);
					}

					Shavit_PrintToChatAll("%t", "ChallengeSurrenderAnnounce", gS_ChatStrings.sVariable2, sNameOpponent, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sName, gS_ChatStrings.sWarning);
					
					i = MaxClients + 1;
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Abort(int client, int args) {
	if (Challenge_IsClientInRace(client)) {
		gB_Challenge_Abort[client] = true;
		int opponent = gI_OpponentClientID[client];

		if (gB_Challenge_Abort[opponent] && IsValidClient(opponent)) {
			char sName[32];
			char sNameOpponent[32];
			GetClientName(client, sName, 32);
			GetClientName(opponent, sNameOpponent, 32);
			
			gB_Challenge[client] = false;
			gB_Challenge[opponent] = false;
			
			Shavit_PrintToChat(client, "%T", "ChallengeAborted", client, gS_ChatStrings.sVariable2, sName, gS_ChatStrings.sText);
			Shavit_PrintToChat(opponent, "%T", "ChallengeAborted", opponent, gS_ChatStrings.sVariable2, sNameOpponent, gS_ChatStrings.sText);
			
			gB_ClientFrozen[client] = false;
			gB_ClientFrozen[opponent] = false;

			gI_OpponentClientID[client] = 0;
			gI_OpponentClientID[opponent] = 0;
			
			gI_ChallengeDuration[client] = 0;
			gI_ChallengeDuration[opponent] = 0;

		} else {
			Shavit_PrintToChat(client, "%T", "ChallengeAbortRequest", client, gS_ChatStrings.sVariable2, gS_ChatStrings.sText);
			Shavit_PrintToChat(opponent, "%T", "ChallengeAbortRequest", opponent, gS_ChatStrings.sVariable2, gS_ChatStrings.sText);
		}
	}
}

public Action Command_Rank(int client, int args) {
	if (gF_PlayerPoints[client] == 0.0) {
		Shavit_PrintToChat(client, "%T", "ChallengeRankInfoUnranked", client);
	} else {
		Shavit_PrintToChat(client, "%T", "ChallengeRankInfo", client,
			gS_ChatStrings.sVariable2,
			gI_PlayerRank[client],
			gS_ChatStrings.sText,
			gS_ChatStrings.sVariable2,
			gI_PlayerCount,
			gS_ChatStrings.sText,
			gS_ChatStrings.sVariable2,
			gF_PlayerPoints[client],
			gS_ChatStrings.sText
		);
	}
	
}

public Action Command_RaceUpdate(int client, int args) {
	char sQuery[128];
	FormatEx(sQuery, 128, "ALTER TABLE `%susers` ADD COLUMN `race_points` FLOAT NOT NULL AFTER `points`;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_UpdateRaceTables, sQuery, 0, DBPrio_High);
}

public void SQL_UpdateRaceTables(Database db, DBResultSet results, const char[] error, DataPack data) {
	if(results == null)
	{
		LogError("Timer (race, update users table) error! Reason: %s", error);

		return;
	}
}

public Action Timer_Countdown(Handle timer, int client) { 
	if (gH_Timer_Race != INVALID_HANDLE){
		CloseHandle(gH_Timer_Race);
		gH_Timer_Race = INVALID_HANDLE;
	}
	
	if (IsValidClient(client) && Challenge_IsClientInRace(client) && !IsFakeClient(client)) {
		int opponent = gI_OpponentClientID[client];
		if (gI_CountdownTime[client] <= 0) {
			gB_ClientFrozen[client] = false;
			gB_ClientFrozen[opponent] = false;
			// SetEntityMoveType(client, MOVETYPE_WALK);
			Shavit_PrintToChat(client, "%T", "ChallengeStarted1", client);
			Shavit_PrintToChat(opponent, "%T", "ChallengeStarted1", opponent);
			Shavit_PrintToChat(client, "%T", "ChallengeStarted2", client, gS_ChatStrings.sVariable);
			Shavit_PrintToChat(opponent, "%T", "ChallengeStarted2", opponent, gS_ChatStrings.sVariable);
			Shavit_PrintToChat(client, "%T", "ChallengeStarted3", client, gS_ChatStrings.sVariable, gS_ChatStrings.sText);
			Shavit_PrintToChat(opponent, "%T", "ChallengeStarted3", opponent, gS_ChatStrings.sVariable, gS_ChatStrings.sText);

			char[] sound2 = "play buttons\\blip2";
			ClientCommand(client, sound2);
			ClientCommand(opponent, sound2);

			if (gH_Timer_Countdown != INVALID_HANDLE){
				CloseHandle(gH_Timer_Countdown);
				gH_Timer_Countdown = INVALID_HANDLE;
			}

			gH_Timer_Race = CreateTimer(1.0, Timer_Race, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		} else if (gI_CountdownTime[client] != 0) {

			char[] sound1 = "play buttons\\blip1";
			ClientCommand(client, sound1);
			ClientCommand(opponent, sound1);

			Shavit_PrintToChat(client, "%T", "ChallengeCountdown", client, gI_CountdownTime[client]--);
			Shavit_PrintToChat(opponent, "%T", "ChallengeCountdown", opponent, gI_CountdownTime[opponent]--);
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_Request(Handle timer, any data) {	
	int client = GetClientOfUserId(data);
	
	if(!Challenge_IsClientInRace(client)  && gB_Challenge_Request[client])
	{
		Shavit_PrintToChat(client, "%T", "ChallengeExpire", client);
		gB_Challenge_Request[client] = false;

		char[] sound1 = "play buttons\\button18";
		ClientCommand(client, sound1);
	}
}

public Action Timer_Race(Handle timer, int client) {
	if (IsValidClient(client) && Challenge_IsClientInRace(client) && !IsFakeClient(client)) {
		char sName[MAX_NAME_LENGTH];
		char sNameOpponent[MAX_NAME_LENGTH];
		GetClientName(client, sName, MAX_NAME_LENGTH);

		int opponent = gI_OpponentClientID[client];

		if (gI_ChallengeDuration[client] == 0) {
			char[] winnerColor = "\x06";
			if (((gF_minTime[client] < gF_minTime[opponent]) && gF_minTime[client] != 0.0) || (gF_minTime[client] != 0.0 && gF_minTime[opponent] == 0.0)) {
				int style = gI_ChallengeStyle[client];
				if (isStyleRanked(style)) {
					UpdateWins(client, opponent);
					updateRank(client);
					updateRank(opponent);
				}

				GetClientName(opponent, sNameOpponent, MAX_NAME_LENGTH);
				Shavit_PrintToChatAll("%t", "ChallengeFinishAnnounce",
					gS_ChatStrings.sVariable2,
					sName,
					gS_ChatStrings.sText,
					gS_ChatStrings.sVariable2,
					sNameOpponent,
					gS_ChatStrings.sText,
					winnerColor,
					gF_minTime[client],
					gS_ChatStrings.sText,
					gS_ChatStrings.sWarning,
					gF_minTime[opponent],
					gS_ChatStrings.sText
				);
			}	
			else if (((gF_minTime[client] > gF_minTime[opponent]) && gF_minTime[opponent] != 0.0) || (gF_minTime[client] == 0.0 && gF_minTime[opponent] != 0.0)) {
				int style = gI_ChallengeStyle[client];
				if (isStyleRanked(style)) {
					UpdateWins(opponent, client);
					updateRank(client);
					updateRank(opponent);
				}

				GetClientName(opponent, sNameOpponent, MAX_NAME_LENGTH);
				Shavit_PrintToChatAll("%t", "ChallengeFinishAnnounce",
					gS_ChatStrings.sVariable2,
					sNameOpponent,
					gS_ChatStrings.sText,
					gS_ChatStrings.sVariable2,
					sName,
					gS_ChatStrings.sText,
					winnerColor,
					gF_minTime[opponent],
					gS_ChatStrings.sText,
					gS_ChatStrings.sWarning,
					gF_minTime[client],
					gS_ChatStrings.sText
				);
			} else if (gF_minTime[client] != 0.0 && gF_minTime[opponent] != 0.0 && gF_minTime[client] != gF_minTime[opponent]) {
				GetClientName(opponent, sNameOpponent, MAX_NAME_LENGTH);
				Shavit_PrintToChatAll("%t", "ChallengeFinishAnnounceTie",
					gS_ChatStrings.sVariable2,
					sNameOpponent,
					gS_ChatStrings.sText,
					gS_ChatStrings.sVariable2,
					sName,
					gS_ChatStrings.sText,
					gS_ChatStrings.sVariable,
					gF_minTime[opponent],
					gS_ChatStrings.sText,
					gS_ChatStrings.sVariable,
					gF_minTime[client],
					gS_ChatStrings.sText
				);
			}

			gB_Challenge[client] = false;
			gB_Challenge[opponent] = false;

			gF_minTime[client] = 0.0;
			gF_minTime[opponent] = 0.0;

			gI_OpponentClientID[client] = 0;
			gI_OpponentClientID[opponent] = 0;

			if (gH_Timer_Race != INVALID_HANDLE){
				CloseHandle(gH_Timer_Race);
				gH_Timer_Race = INVALID_HANDLE;
			}
		} else if (
				gI_ChallengeDuration[client] % 60 == 0 || 
				(gI_ChallengeDuration[client] < 60 && gI_ChallengeDuration[client] % 15 == 0) || 
				gI_ChallengeDuration[client] <= 5
			) {
			if (gI_ChallengeDuration[client] >= 60) {
				Shavit_PrintToChat(client, "%T", "ChallengeTimeLeftMinutes", client, gI_ChallengeDuration[client] / 60);
				Shavit_PrintToChat(opponent, "%T", "ChallengeTimeLeftMinutes", opponent, gI_ChallengeDuration[opponent] / 60);
			} else {
				Shavit_PrintToChat(client, "%T", "ChallengeTimeLeftSeconds", client, gI_ChallengeDuration[client]);
				Shavit_PrintToChat(opponent, "%T", "ChallengeTimeLeftSeconds", opponent, gI_ChallengeDuration[opponent]);
			}
			
		}

		gI_ChallengeDuration[client]--;
		gI_ChallengeDuration[opponent]--;
	}

	return Plugin_Continue;
}

public void Shavit_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track)
{
	if(Challenge_IsClientInRace(client) && track == gI_ClientTrack[client] && style == gI_ChallengeStyle[client] && !Shavit_IsPracticeMode(client)) {
		if (gF_minTime[client] == 0.0 || time < gF_minTime[client]) {
			gF_minTime[client] = time;
		}
	}
}

public bool isStyleRanked(int style) {
	return (style >= 0 && style <= 7) || (style >= 9 && style <= 14);
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	if(Challenge_IsClientInRace(client))
	{	
		char sNameOpponent[MAX_NAME_LENGTH];
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, MAX_NAME_LENGTH);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && i != client)
			{
				if (StrEqual(gS_SteamID[i], gS_Challenge_OpponentID[client]))
				{
					GetClientName(i, sNameOpponent, MAX_NAME_LENGTH);
					if (gF_minTime[client] == 0.0) {
						gB_Challenge[client] = false;
						gB_Challenge[i] = false;
						Shavit_PrintToChatAll("%t", "ChallengeStyleChange", gS_ChatStrings.sVariable2, sNameOpponent, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sName, gS_ChatStrings.sWarning);
						if (isStyleRanked(oldstyle)) {
							UpdateWins(i, client);
							updateRank(i);
							updateRank(client);
						}

						gI_OpponentClientID[client] = 0;
						gI_OpponentClientID[i] = 0;
					}
				}
			}
		}	
	}
}

public void getPlayerRacePoints(int winner, int loser) {
	int iSteamIDwinner = GetSteamAccountID(winner);
	int iSteamIDloser = GetSteamAccountID(loser);

	DataPack serialPack = new DataPack();
	serialPack.WriteCell(winner);
	serialPack.WriteCell(loser);

	char[] sQuery = new char[256];
	FormatEx(sQuery, 256, "SELECT p1.points AS points1, p2.points AS points2 FROM (SELECT points FROM %susers WHERE auth = %d) p1, (SELECT points FROM %susers WHERE auth = %d) p2", gS_MySQLPrefix, iSteamIDwinner, gS_MySQLPrefix, iSteamIDloser);
	gH_SQL.Query(calculateELOPoints, sQuery, serialPack, DBPrio_Low);
}

public void calculateELOPoints(Database db, DBResultSet results, const char[] error, DataPack data) {

	data.Reset();
	int winner = data.ReadCell();
	int loser = data.ReadCell();
	delete data;
	
	if(results == null)
	{
		LogError("ERROR: %s", error);
		return;
	}

	if(results.FetchRow()) {
		float p1Points = results.FetchFloat(0);
		float p2Points = results.FetchFloat(1);

		float p1 = calcProbability(p2Points, p1Points);
		float p2 = calcProbability(p1Points, p2Points);

		float r1 = gCV_K.IntValue * (1.0 - p1);
		float r2 = gCV_K.IntValue * (0.0 - p2);

		updatePlayerRacePoints(winner, loser, r1, r2);
	}
}

public float calcProbability(float points1, float points2) {
	return 1.0/(Pow(10.0, (points1-points2)/400.0)+1.0);
}

public void updatePlayerRacePoints(int winner, int loser, float r1, float r2) {
	int iSteamIDwinner = GetSteamAccountID(winner);
	int iSteamIDloser = GetSteamAccountID(loser);
	
	char sQuery[256];
	FormatEx(sQuery, 256, "UPDATE %susers SET race_points = race_points + IF(auth = %d, GREATEST(%f, 0), GREATEST(%f, 0)) WHERE auth IN(%d, %d);", gS_MySQLPrefix, iSteamIDwinner, r1, r2, iSteamIDwinner, iSteamIDloser);
	gH_SQL.Query(SQL_UpdateWins_Callback, sQuery, 0, DBPrio_High);
}

public void UpdateWins(int winner, int loser)
{
	getPlayerRacePoints(winner, loser);
}

public void updateRank(int client) {
	int iSteamId = GetSteamAccountID(client);

	char[] sQuery = new char[256];
	FormatEx(sQuery, 256, "SELECT COUNT(*) rank, IFNULL(p.race_points, 0) AS race_points, c.count FROM %susers u JOIN(SELECT race_points FROM %susers WHERE auth = %d LIMIT 1) p JOIN (SELECT COUNT(*) count FROM %susers WHERE race_points > 0) c WHERE u.race_points >= p.race_points LIMIT 1", gS_MySQLPrefix, gS_MySQLPrefix, iSteamId, gS_MySQLPrefix);
	gH_SQL.Query(SQL_UpdateRank_Callback, sQuery, client, DBPrio_Low);
}

public void SQL_UpdateRank_Callback(Database db, DBResultSet results, const char[] error, int client) {
	if (results.FetchRow()) {
		gI_PlayerRank[client] = results.FetchInt(0);
		gF_PlayerPoints[client] = results.FetchFloat(1);
		gI_PlayerCount = results.FetchInt(2);
	}
}

public void updateMenu() {
	char[] sQuery = new char[256];
	FormatEx(sQuery, 256, "SELECT auth, name, race_points, (SELECT count(name) FROM %susers where race_points > 0) AS `count` FROM users WHERE race_points > 0 GROUP BY auth ORDER BY race_points DESC LIMIT 100;", gS_MySQLPrefix);
	gH_SQL.Query(SQL_UpdateTopRacers_Callback, sQuery, 0, DBPrio_Low);
}

public void SQL_UpdateWins_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if(results == null)
	{
		LogError("Timer (race, update win count) error! Reason: %s", error);
		return;
	}

	updateMenu();
}

public void SQL_UpdateTopRacers_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("ERROR: %s", error);
		return;
	}

	if(gH_Top100Menu != null)
	{
		delete gH_Top100Menu;
	}

	gH_Top100Menu = new Menu(TopMenuHandler);

	int row = 0;

	while(results.FetchRow())
	{
		char[] sAuthID = new char[32];
		results.FetchString(0, sAuthID, 32);

		char[] sName = new char[MAX_NAME_LENGTH];
		results.FetchString(1, sName, MAX_NAME_LENGTH);

		float fPoints = results.FetchFloat(2);

		gI_TopPlayerCount = results.FetchInt(3);

		char[] sDisplay = new char[96];
		FormatEx(sDisplay, 96, "#%d - %s (%.3f points)", (++row), sName, fPoints);
		gH_Top100Menu.AddItem(sAuthID, sDisplay);
	}

	if(gH_Top100Menu.ItemCount == 0)
	{
		char[] sDisplay = new char[64];
		FormatEx(sDisplay, 64, "No racers found!");
		gH_Top100Menu.AddItem("-1", sDisplay);
	}
}

public Action Command_TopRace(int client, int args) {
	if (gH_Top100Menu == null)
		updateMenu();
	
	gH_Top100Menu.SetTitle("Top 100 racers: (%d)\n ", gI_TopPlayerCount);
	gH_Top100Menu.Display(client, 60);

	return Plugin_Handled;
}

void GetTrackName(int client, int track, char[] output, int size)
{
	if(track < 0 || track >= TRACKS_SIZE)
	{
		FormatEx(output, size, "%T", "Track_Unknown", client);

		return;
	}

	static char sTrack[16];
	FormatEx(sTrack, 16, "Track_%d", track);
	FormatEx(output, size, "%T", sTrack, client);
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle();
}

public int Native_IsClientFrozen(Handle plugin, int numParams)
{
	return gB_ClientFrozen[GetNativeCell(1)];
}

public int Native_IsClientInRace(Handle plugin, int numParams)
{
	return gB_Challenge[GetNativeCell(1)];
}