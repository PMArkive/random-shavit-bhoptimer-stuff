#include <convar_class>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = 
{
	name = "[shavit] Blacklist",
	author = "Haze",
	description = "",
	version = SHAVIT_VERSION,
	url = ""
}

// cvars
Convar gCV_SpecialString = null;
Convar gCV_ChangeStyle = null;
Convar gCV_OpenStyle = null;
//---------

// Blacklist
bool gB_Late = false;
bool gB_IsSay[MAXPLAYERS+1] = {false, ...};
int gI_PlayerAuth[MAXPLAYERS+1] = {0, ...};
bool gB_InBlackList[MAXPLAYERS+1];
int gI_Immunity[MAXPLAYERS+1];
int gI_BlacklistedStyle = -1;
char g_sSpecialString[128];
//----------------

// database handle
Database gH_SQL = null;
bool gB_MySQL = false;
char gS_MySQLPrefix[32];
//-----------------

// chat settings
chatstrings_t gS_ChatStrings;
stylestrings_t gS_StyleStrings[STYLE_LIMIT];
//---------------

//native void Shavit_AddInBlacklist(int client, const char[] log);
//native bool Shavit_IsBlacklisted(int client);

//MarkNativeAsOptional("Shavit_AddInBlacklist");
//MarkNativeAsOptional("Shavit_IsBlacklisted");

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Shavit_AddInBlacklist", Native_AddInBlacklist);
	CreateNative("Shavit_IsBlacklisted", Native_IsBlacklisted);
	
	RegPluginLibrary("shavit-blacklist");
	
	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{	
	// Command
	RegAdminCmd("sm_blacklist", Command_Blacklist, ADMFLAG_CHEATS, "Blacklist Menu.");
	
	gCV_SpecialString = new Convar("shavit_blacklist_string", "blacklist", "Special string value to use in shavit-styles.cfg");
	gCV_ChangeStyle = new Convar("shavit_blacklist_changestyle", "1", "Changing the player style to blacklisted style when adding a player to the Timer blacklist.", 0, true, 0.0, true, 1.0);
	gCV_OpenStyle = new Convar("shavit_blacklist_openstyle", "0", "Blacklisted style is open to all users.", 0, true, 0.0, true, 1.0);
	
	gCV_SpecialString.AddChangeHook(ConVar_OnSpecialStringChanged);
	gCV_SpecialString.GetString(g_sSpecialString, sizeof(g_sSpecialString));
	
	Convar.AutoExecConfig();
	
	AddCommandListener(Player_Say, "say"); 
	
	SQL_DBConnect();
	
	if(gB_Late)
	{
		Shavit_OnChatConfigLoaded();
		Shavit_OnStyleConfigLoaded(-1);
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
				OnClientPostAdminCheck(i);
			}
		}
		gB_Late = false;
	}
}

public void ConVar_OnSpecialStringChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sSpecialString, sizeof(g_sSpecialString));
}

public void OnMapStart()
{
	SaveOldLogs();
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

public void Shavit_OnStyleConfigLoaded(int styles)
{
	if(styles == -1)
	{
		styles = Shavit_GetStyleCount();
	}

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStrings(i, sSpecialString, gS_StyleStrings[i].sSpecialString, sizeof(stylestrings_t::sSpecialString));
		if(StrContains(gS_StyleStrings[i].sSpecialString, g_sSpecialString) != -1)
		{
			gI_BlacklistedStyle = i;
			break;
		}
	}
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	if(!gB_InBlackList[client] && !gCV_OpenStyle.BoolValue)
	{
		if(StrContains(gS_StyleStrings[newstyle].sSpecialString, g_sSpecialString) != -1)
		{
			Shavit_PrintToChat(client, "You are not in the blacklist of the timer!");
			
			DataPack hPack = new DataPack();
			hPack.WriteCell(client);
			hPack.WriteCell(newstyle == oldstyle ? 0 : oldstyle);
			
			CreateTimer(0.1, Timer_Change, hPack, TIMER_DATA_HNDL_CLOSE);
		}
	}
}

public Action Timer_Change(Handle hTimer, DataPack data)
{
	data.Reset();
	int client = data.ReadCell();
	int oldstyle = data.ReadCell();
	Shavit_ChangeClientStyle(client, oldstyle);
}

public void OnClientPostAdminCheck(int client)
{
	LoadFromDatabase(client);
}

public void OnClientPutInServer(int client)
{
	if(!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}
	
	int iSteamID = GetSteamAccountID(client);
	
	if(iSteamID == 0)
	{
		return;
	}

	char sName[32+1];
	GetClientName(client, sName, sizeof(sName));
	ReplaceString(sName, sizeof(sName), "#", "?"); // to avoid this: https://user-images.githubusercontent.com/3672466/28637962-0d324952-724c-11e7-8b27-15ff021f0a59.png

	int iLength = ((strlen(sName) * 2) + 1);
	char[] sEscapedName = new char[iLength];
	gH_SQL.Escape(sName, sEscapedName, iLength);
	
	char sQuery[512];

	if(gB_MySQL)
	{
		FormatEx(sQuery, sizeof(sQuery),
			"INSERT INTO %sblacklist (auth, name) VALUES (%d, '%s') ON DUPLICATE KEY UPDATE name = '%s';",
			gS_MySQLPrefix, iSteamID, sEscapedName, sEscapedName);
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery),
			"REPLACE INTO %sblacklist (auth, name) VALUES (%d, '%s');",
			gS_MySQLPrefix, iSteamID, sEscapedName);
	}

	gH_SQL.Query(SQL_InsertUser_Callback, sQuery, GetClientSerial(client));
}

public void SQL_InsertUser_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	
	if(results == null)
	{
		if(client == 0)
		{
			LogError("Timer error! Failed to insert a disconnected player's data to the table. Reason: %s", error);
		}
		else
		{
			LogError("Timer error! Failed to insert \"%N\"'s data to the table. Reason: %s", client, error);
		}

		return;
	}

}

void SaveOldLogs()
{
	char sDate[64];
	FormatTime(sDate, sizeof(sDate), "%y%m%d", GetTime() - (60 * 60 * 24)); // Save logs from day before to new file
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/todayblacklist_%s.txt", sDate);
	
	if(!FileExists(sPath))
	{
		return;
	}
	
	char sNewPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sNewPath, sizeof(sNewPath), "logs/blacklist.txt");
	
	File hOld = OpenFile(sPath, "r");
	File hNew = OpenFile(sNewPath, "a");

	if(hOld == null)
	{
		LogError("Couldn't open '%s'", sPath);
		return;
	}

	if(hNew == null)
	{
		LogError("Couldn't open '%s'", sNewPath);
		return;
	}

	char sDateFormatted[64];
	FormatTime(sDateFormatted, sizeof(sDateFormatted), "%y-%m-%d", GetTime() - (60 * 60 * 24));
	WriteFileLine(hNew, "\n***** ------------ Logs from %s ------------ *****", sDateFormatted);
	
	char sLine[256];
	while(!IsEndOfFile(hOld))
	{
		if(ReadFileLine(hOld, sLine, sizeof(sLine)))
		{
			ReplaceString(sLine, sizeof(sLine), "\n", "");
			WriteFileLine(hNew, sLine);
		}
	}
	
	delete hOld;
	delete hNew;
	DeleteFile(sPath);
}

stock bool BlackListLog(int client, const char[] log, any ...)
{
	char buffer[1024];
	VFormat(buffer, sizeof(buffer), log, 3);
	
	Handle myHandle = GetMyHandle();
	char sPlugin[PLATFORM_MAX_PATH];
	GetPluginFilename(myHandle, sPlugin, PLATFORM_MAX_PATH);
	
	char sPlayer[128];
	GetClientAuthId(client, AuthId_Steam2, sPlayer, sizeof(sPlayer));
	Format(sPlayer, sizeof(sPlayer), "%N<%s>", client, sPlayer);
	
	char sTime[64];
	FormatTime(sTime, sizeof(sTime), "%X", GetTime());
	Format(buffer, 1024, "[%s] %s: %s %s", sPlugin, sTime, sPlayer, buffer);
	PrintToServer(buffer);
	
	char sDate[64];
	FormatTime(sDate, sizeof(sDate), "%y%m%d", GetTime());
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/todayblacklist_%s.txt", sDate);
	File hFile = OpenFile(sPath, "a");
	if(hFile != null)
	{
		WriteFileLine(hFile, buffer);
		delete hFile;
		return true;
	}
	else
	{
		LogError("Couldn't open timer log file.");
		return false;
	}
}

public Action Command_Blacklist(int client, int args)
{
	//if(client == 0)
	//{
	//	ReplyToCommand(client, "[SM] This command can only be used in-game.");
	//	return Plugin_Handled;
	//}
	if(!args)
	{
		BlacklistMenu(client);
		return Plugin_Handled;	
	}
	else
	{
		char sQuery[128];
		char sArg[256];
		char expInfo[3][64];
		
		if(GetCmdArgString(sArg, sizeof(sArg)))
		{
			//PrintToChat(client, "Args: %i, sArg: %s", args, sArg);
			if((StrContains(sArg, "STEAM_0:0:") != -1) || (StrContains(sArg, "STEAM_0:1:") != -1))
			{
				ExplodeString(sArg, ":", expInfo, sizeof(expInfo), sizeof(expInfo[]));
				FormatEx(expInfo[0], sizeof(expInfo[]), "STEAM_0:%s:", expInfo[1]);
				ReplaceString(sArg, sizeof(sArg), expInfo[0], "");
				FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM %sblacklist WHERE auth = %d", gS_MySQLPrefix, StringToInt(sArg) * 2 + StringToInt(expInfo[1]));
			}
			else if(StrContains(sArg, "[U:1:") != -1)
			{
				ReplaceString(sArg, sizeof(sArg), "[U:1:", "");
				ReplaceString(sArg, sizeof(sArg), "]", "");
				FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM %sblacklist WHERE auth = %s", gS_MySQLPrefix, sArg);
			}
			else
			{
				FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM %sblacklist WHERE name LIKE \"%s\"", gS_MySQLPrefix, sArg);
			}
		}
		else
		{
			FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM %sblacklist", gS_MySQLPrefix);
		}
		
		DataPack hPack = new DataPack();
		hPack.WriteCell(client);
		hPack.WriteCell(0);
		gH_SQL.Query(BlackList_Callback, sQuery, hPack);
	}
	return Plugin_Handled;	
}

void BlacklistMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Blacklist, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	menu.SetTitle("[shavit] Blacklist");
	
	menu.AddItem("players", "Players");
	if(CheckCommandAccess(client, "blacklist_immunity", ADMFLAG_RCON))
		menu.AddItem("immunity", "Players Immunity");
	menu.AddItem("blacklisted", "Blacklisted Players");
	
	menu.Pagination = MENU_NO_PAGINATION;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Blacklist(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sQuery[256];
		char sInfo[16];
		menu.GetItem(param2, sInfo, 16);

		if(StrEqual(sInfo, "players"))
		{
			FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM %sblacklist", gS_MySQLPrefix);
		}
		else if(StrEqual(sInfo, "immunity"))
		{
			FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM %sblacklist", gS_MySQLPrefix);
		}
		else if(StrEqual(sInfo, "blacklisted"))
		{
			FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM %sblacklist WHERE blacklisted = 1", gS_MySQLPrefix);
		}
		
		DataPack hPack = new DataPack();
		hPack.WriteCell(param1);
		hPack.WriteCell(StrEqual(sInfo, "immunity") ? 1 : 0);
		gH_SQL.Query(BlackList_Callback, sQuery, hPack);
		
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void BlackList_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int client = data.ReadCell();
	int QueryStyle = data.ReadCell();
	delete data;	
	
	if(results == null)
	{
		LogError(error);
		Shavit_PrintToChat(client, "Error opening blacklist, try again!");
		return;
	}
	
	if(results.RowCount == 0)
	{
		BlacklistMenu(client);
		Shavit_PrintToChat(client, "No player was added to the blacklist!");
		return;
	}
	
	char sAuth[32];
	char sName[32+1];
	int iBlacklisted;
	int iImmunity;
	char info[512];
	char display[128];
	
	Handle menu = CreateMenu(Menu_BlackList);
	if(QueryStyle == 0)
	{
		SetMenuTitle(menu, "Black List Menu | Management |");

		while(results.FetchRow())
		{
			results.FetchString(0, sAuth, sizeof(sAuth));
			results.FetchString(1, sName, sizeof(sName));
			iBlacklisted = results.FetchInt(2);
			iImmunity = results.FetchInt(3);
			
			if(gI_Immunity[client] >= iImmunity)
			{
				FormatEx(info, sizeof(info), "%d%%%s%%%s%%%d", QueryStyle, sAuth, sName, iBlacklisted);
				FormatEx(display, sizeof(display), "[U:1:%s] - %s (%s)", sAuth, sName, iBlacklisted == 1 ? "X" : " ");
				AddMenuItem(menu, info, display);
			}
		}
	}
	else
	{
		SetMenuTitle(menu, "Black List Menu | Immunity |");
		
		while(results.FetchRow())
		{
			results.FetchString(0, sAuth, sizeof(sAuth));
			results.FetchString(1, sName, sizeof(sName));
			iImmunity = results.FetchInt(3);
			FormatEx(info, sizeof(info), "%d%%%s%%%s%%%d", QueryStyle, sAuth, sName, iImmunity);
			FormatEx(display, sizeof(display), "[U:1:%s] - %s (%d)", sAuth, sName, iImmunity);
			AddMenuItem(menu, info, display);
		}
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int Menu_BlackList(Menu menu, MenuAction action, int client, int args)
{
	if (action == MenuAction_Select)
	{
		char info[512];
		GetMenuItem(menu, args, info, sizeof(info));

		char expInfo[4][64];
		ExplodeString(info, "\%", expInfo, sizeof(expInfo), sizeof(expInfo[]));

		int iTemp = StringToInt(expInfo[3]);
		int QueryStyle = StringToInt(expInfo[0]);

		if(QueryStyle == 0)
		{
			char sQuery[128];
			FormatEx(sQuery, sizeof(sQuery), "UPDATE %sblacklist SET blacklisted = %d WHERE auth = %s;", gS_MySQLPrefix, iTemp =! iTemp, expInfo[1]);

			gH_SQL.Query(SQL_UpdateBlackList_Callback, sQuery);
			
			if(iTemp == 1)
			{
				Shavit_PrintToChat(client, "%s%s [U:1:%s] %shas been added to blacklist!", gS_ChatStrings.sVariable, expInfo[2], expInfo[1], gS_ChatStrings.sText);
				BlackListLog(client, "added %s [U:1:%s] to blacklist.", expInfo[2], expInfo[1]);
			}
			else
			{
				Shavit_PrintToChat(client, "%s%s [U:1:%s] %shas been removed from blacklist!", gS_ChatStrings.sVariable, expInfo[2], expInfo[1], gS_ChatStrings.sText);
				BlackListLog(client, "removed %s [U:1:%s] from blacklist.", expInfo[2], expInfo[1]);
			}

			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
					LoadFromDatabase(i);
			}
			
			BlacklistMenu(client);
		}
		else
		{
			Shavit_PrintToChat(client, "Enter a number");
			gB_IsSay[client] = true;
			gI_PlayerAuth[client] = StringToInt(expInfo[1]);
			BlacklistMenu(client);
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(args == MenuCancel_ExitBack)
			BlacklistMenu(client);
	}
	else if (action == MenuAction_End)
		delete menu;
}

public Action Player_Say(int client, const char[] command, int args)
{
	if(gB_IsSay[client])
	{
		char text[64];
		GetCmdArg(1, text, sizeof(text));
		
		bool valid = true;
		for (int i = 0; i < strlen(text); i++)
		{
			if (!IsCharNumeric(text[i]))
			{
				Shavit_PrintToChat(client, "This isn't the valid number.");
				gB_IsSay[client] = false;
				valid = false;
				break;
			}
		}
		if(valid)
		{
			gB_IsSay[client] = false;
			char sQuery[128];
			int Immunity = StringToInt(text);
			FormatEx(sQuery, sizeof(sQuery), "UPDATE %sblacklist SET immunity = %d WHERE auth = %d;", gS_MySQLPrefix, Immunity, gI_PlayerAuth[client]);
			gH_SQL.Query(SQL_UpdateBlackList_Callback, sQuery);
			
			Shavit_PrintToChat(client, "Immunity has been changed to %s%d%s!", gS_ChatStrings.sVariable, Immunity, gS_ChatStrings.sText);
			
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
					LoadFromDatabase(i);
			}
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void SQL_UpdateBlackList_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! BlackList' data table updation failed. Reason: %s", error);
		return;
	}
}

void LoadFromDatabase(int client)
{
	if(IsFakeClient(client) || !IsClientInGame(client))
	{
		return;
	}

	int iSteamID = GetSteamAccountID(client);

	if(iSteamID == 0)
	{
		return;
	}

	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT blacklisted, immunity FROM %sblacklist WHERE auth = %d;", gS_MySQLPrefix, iSteamID);

	gH_SQL.Query(SQL_GetBL_Callback, sQuery, GetClientSerial(client), DBPrio_Low);
}

public void SQL_GetBL_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (Blacklist cache update) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	while(results.FetchRow())
	{
		gB_InBlackList[client] = view_as<bool>(results.FetchInt(0));
		gI_Immunity[client] = results.FetchInt(1);
	}
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, sizeof(gS_MySQLPrefix));
	gH_SQL = GetTimerDatabaseHandle();
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	// support unicode names
	if(!gH_SQL.SetCharset("utf8mb4"))
	{
		gH_SQL.SetCharset("utf8");
	}

	char sQuery[512];
	
	if(gB_MySQL)
	{
		FormatEx(sQuery, sizeof(sQuery),
			"CREATE TABLE IF NOT EXISTS `%sblacklist` (`auth` INT NOT NULL, `name` VARCHAR(32) COLLATE 'utf8mb4_general_ci', `blacklisted` BOOLEAN DEFAULT 0, `immunity` TINYINT DEFAULT 0, PRIMARY KEY (`auth`)) ENGINE=INNODB;",
			gS_MySQLPrefix);
	}
	else
	{
		FormatEx(sQuery, sizeof(sQuery),
			"CREATE TABLE IF NOT EXISTS `%sblacklist` (`auth` INT NOT NULL, `name` VARCHAR(32), `blacklisted` BOOLEAN DEFAULT 0, `immunity` TINYINT DEFAULT 0, PRIMARY KEY (`auth`));",
			gS_MySQLPrefix);
	}

	gH_SQL.Query(SQL_CreateBlackListTable_Callback, sQuery);
}

public void SQL_CreateBlackListTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer error! BlackList' data table creation failed. Reason: %s", error);

		return;
	}
}

public Action Shavit_OnFinishPre(int client, timer_snapshot_t snapshot)
{
	if(gB_InBlackList[client])
	{
		if(StrContains(gS_StyleStrings[Shavit_GetBhopStyle(client)].sSpecialString, g_sSpecialString) != -1)
			return Plugin_Continue;
		
		char sTime[32];
		FormatSeconds(Shavit_GetClientTime(client), sTime, sizeof(sTime), true);
		
		Shavit_PrintToChat(client, "You have finished in %s%s%s, but that time doesn't count because you are in timer blacklist!", gS_ChatStrings.sVariable, sTime, gS_ChatStrings.sText);
		
		Shavit_StopTimer(client);
		return Plugin_Handled;

	}
	
	return Plugin_Continue;
}

public int Native_AddInBlacklist(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	
	if(!IsClientConnected(client))
		return;
	
	if(gB_InBlackList[client])
		return;
	
	int iSteamID = GetSteamAccountID(client);
	
	if(iSteamID == 0)
		return;
	
	static int iWritten = 0; // useless?

	char sBuffer[300];
	FormatNativeString(0, 2, 3, 300, iWritten, sBuffer);
	
	DataPack hPack = new DataPack();
	hPack.WriteCell(client);
	hPack.WriteString(sBuffer);
	
	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), "UPDATE %sblacklist SET blacklisted = 1 WHERE auth = %d;", gS_MySQLPrefix, iSteamID);
	gH_SQL.Query(SQL_AddInBlacklistCallback, sQuery, hPack);
}

public void SQL_AddInBlacklistCallback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if(results != null)
	{
		char message[128];
		
		data.Reset();
		int client = data.ReadCell();
		data.ReadString(message, sizeof(message));
		delete data;
		
		LoadFromDatabase(client);
		ChangePlayerStyle(client);
		Shavit_PrintToChat(client, message);
	}
	else
	{
		LogError(error);
		return;
	}
}

public int Native_IsBlacklisted(Handle handler, int numParams)
{
	return gB_InBlackList[GetNativeCell(1)];
}

void ChangePlayerStyle(int client)
{
	if(IsPlayerAlive(client) && gCV_ChangeStyle.BoolValue && gI_BlacklistedStyle != -1)
	{
		Shavit_RestartTimer(client, Shavit_GetClientTrack(client));
		Shavit_ChangeClientStyle(client, gI_BlacklistedStyle);
	}
}