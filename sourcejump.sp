#include <sourcemod>
#include <ripext>

#define REMOTE_SERVER "https://sj.shav.it"

#pragma dynamic 0x2000000
#pragma newdecls required
#pragma semicolon 1

forward void Shavit_OnWorldRecord(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldwr, float oldtime, float perfs);
forward void OnTimerFinished_Post(int client, float Time, int Type, int Style, bool tas, bool NewTime, int OldPosition, int NewPosition);
forward void FuckItHops_OnWorldRecord(int client, int style, float time, int jumps, int strafes, float sync, int track);

enum
{
	TimerVersion_Unknown,
	TimerVersion_shavit,
	TimerVersion_bTimes2_0,
	TimerVersion_bTimes1_8_3,
	TimerVersion_FuckItHops,
	TimerVersion_END
}

int gI_TimerVersion = TimerVersion_Unknown;
char gS_TimerVersion[][] =
{
	"Unknown Timer",
	"shavit",
	"bTimes 2.0",
	"bTimes 1.8.3",
	"FuckItHops Timer"
};

char gS_TimerNatives[][] =
{
	"<none>",
	"Shavit_ChangeClientStyle", // shavit
	"Timer_GetZoneCount", // btimes 2.0
	"Timer_IsPointInsideZone", // btimes 1.8
	"tTimer_GetTimerState" // fuckithops
};

int gI_DebuggingLog = 0;
ConVar gCV_ExtendedDebugging = null;
HTTPClient gH_Client = null;
int gI_Tickrate = 0;
Database gH_Database = null;
char gS_MySQLPrefix[32];
char gS_PasswordHash[64];
Handle gH_bTimesTimer = null;
ConVar gCV_PublicIP = null;
char gS_AuthKey[64];
ConVar gCV_Authentication = null;

// SteamIDs which can fetch records from the server
int gI_SteamIDWhitelist[] =
{
	8784568, // Tony Montana
	204506329 // shavit
};

public Plugin myinfo = 
{
	name = "SourceJump Database",
	author = "shavit",
	description = "Provides SourceJump with a database of bhop world records.",
	version = "1.1",
	url = "https://github.com/shavitush/SourceJump"
}

public void OnAllPluginsLoaded()
{
	for(int i = 1; i < TimerVersion_END; i++)
	{
		if(GetFeatureStatus(FeatureType_Native, gS_TimerNatives[i]) != FeatureStatus_Unknown)
		{
			gI_TimerVersion = i;
			PrintToServer("[SourceJump] Detected timer plugin %s based on native %s", gS_TimerVersion[i], gS_TimerNatives[i]);
			
			break;
		}
	}

	char sError[255];
	strcopy(gS_MySQLPrefix, 32, "");

	switch(gI_TimerVersion)
	{
		case TimerVersion_Unknown: SetFailState("Supported timer plugin was not found.");

		case TimerVersion_shavit:
		{
			gH_Database = GetTimerDatabaseHandle();
			GetTimerSQLPrefix(gS_MySQLPrefix, 32);
		}

		case TimerVersion_bTimes2_0, TimerVersion_bTimes1_8_3:
		{
			if((gH_Database = SQL_Connect("timer", true, sError, 255)) == null)
			{
				SetFailState("SourceJump plugin startup failed. Reason: %s", sError);
			}
		}

		case TimerVersion_FuckItHops:
		{
			if((gH_Database = SQL_Connect("TimerDB65", true, sError, 255)) == null)
			{
				SetFailState("SourceJump plugin startup failed. Reason: %s", sError);
			}
		}
	}

	gH_Client = new HTTPClient(REMOTE_SERVER);
	gH_Client.Get("password", Callback_OnGetPassword);
}

public void OnPluginStart()
{
	RegConsoleCmd("sj_get_all_wrs", Command_GetAllWRs, "Fetches WRs to SourceJump.");

	gCV_ExtendedDebugging = CreateConVar("sourcejump_extended_debugging", "0", "Use extensive debugging messages?", FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	gCV_PublicIP = CreateConVar("sourcejump_public_ip", "127.0.0.1", "Input the IP:PORT of the game server here. It will be used to identify the game server.");
	gCV_Authentication = CreateConVar("sourcejump_private_key", "", "Fill in your SourceJump API access key here. This key can be used to submit records to the database using your server key - abuse will lead to removal.");

	AutoExecConfig();

	SourceJump_DebugLog("SourceJump database plugin loaded.");
}

public void OnMapStart()
{
	gH_bTimesTimer = null;
	gI_Tickrate = RoundToZero(1.0 / GetTickInterval());
}

public Action Command_GetAllWRs(int client, int args)
{
	int iSteamID = GetSteamAccountID(client);
	bool bAllowed = false;

	for(int i = 0; i < sizeof(gI_SteamIDWhitelist); i++)
	{
		if(iSteamID == gI_SteamIDWhitelist[i])
		{
			bAllowed = true;

			break;
		}
	}

	if(!bAllowed)
	{
		ReplyToCommand(client, "[SourceJump] You are not permitted to fetch the world records list.");

		return Plugin_Handled;
	}

	SendListOfRecords();
	ReplyToCommand(client, "[SourceJump] Preparing list of records...");

	return Plugin_Handled;
}

public void Shavit_OnWorldRecord(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldwr, float oldtime, float perfs)
{
	if(style != 0 || track != 0 || gI_TimerVersion != TimerVersion_shavit)
	{
		return;
	}

	char sMap[64];
	GetCurrentMap(sMap, 64);
	GetMapDisplayName(sMap, sMap, 64);

	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam3, sSteamID, 32);

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);

	char sDate[32];
	FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", GetTime());

	SendCurrentWR(sMap, sSteamID, sName, sDate, time, sync, strafes, jumps);
}

public void FuckItHops_OnWorldRecord(int client, int style, float time, int jumps, int strafes, float sync, int track)
{
	if(style != 0 || track != 0 || gI_TimerVersion != TimerVersion_FuckItHops)
	{
		return;
	}

	char sMap[64];
	GetCurrentMap(sMap, 64);
	GetMapDisplayName(sMap, sMap, 64);

	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam3, sSteamID, 32);

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);

	char sDate[32];
	FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", GetTime());

	SendCurrentWR(sMap, sSteamID, sName, sDate, time, sync, strafes, jumps);
}

public void OnTimerFinished_Post(int client, float Time, int Type, int Style, bool tas, bool NewTime, int OldPosition, int NewPosition)
{
	if(Style != 0 || Type != 0 || (gI_TimerVersion != TimerVersion_bTimes1_8_3 && gI_TimerVersion != TimerVersion_bTimes2_0))
	{
		return;
	}

	int iRank = 0;

	switch(gI_TimerVersion)
	{
		case TimerVersion_bTimes2_0:
		{
			if(tas)
			{
				SourceJump_DebugLog("OnTimerFinished_Post: TAS detected, invalidated submission.");

				return;
			}

			iRank = NewPosition;

			SourceJump_DebugLog("OnTimerFinished_Post: %d -> %d.", OldPosition, NewPosition);
		}

		// nonsense. dumb ass decided it's a good idea to add a new parameter IN BETWEEN the fucking signature of the forward?!??!?!??
		case TimerVersion_bTimes1_8_3:
		{
			iRank = OldPosition;

			SourceJump_DebugLog("OnTimerFinished_Post: %d -> %d.", view_as<int>(NewTime), OldPosition);
		}
	}

	if(iRank != 1)
	{
		return;
	}

	// OBVIOUSLY THERE IS NO FUCKING STRAFES/SYNC IN THE FUCKING FORWARD SO WE NEED TO QUERY FOR IT
	// FUCK YOU TOO BLACKY
	char sMap[64];
	GetCurrentMap(sMap, 64);
	GetMapDisplayName(sMap, sMap, 64);

	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam3, sSteamID, 32);

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);

	char sDate[32];
	FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", GetTime());

	DataPack hPack = new DataPack();
	hPack.WriteString(sMap);
	hPack.WriteString(sSteamID);
	hPack.WriteString(sName);
	hPack.WriteString(sDate);

	delete gH_bTimesTimer;
	gH_bTimesTimer = CreateTimer(3.0, Timer_bTimesCallback, hPack, TIMER_FLAG_NO_MAPCHANGE);

	SourceJump_DebugLog("OnTimerFinished_Post: Preparing record by %N on %s (%f) for submission to database.", client, sMap, Time);
}

public Action Timer_bTimesCallback(Handle timer, any data)
{
	DataPack hPack = view_as<DataPack>(data);
	hPack.Reset();

	char sMap[64];
	hPack.ReadString(sMap, 64);

	char sQuery[512];

	if(gI_TimerVersion == TimerVersion_bTimes1_8_3)
	{
		FormatEx(sQuery, 512,
			"SELECT m.MapName, u.SteamID AS steamid, u.User, a.Time, a.Sync, a.Strafes, a.Jumps, a.Timestamp FROM times a " ...
			"JOIN (SELECT MIN(Time) time, MapID, Style, Type FROM times GROUP by MapID, Style, Type) b " ...
			"JOIN (SELECT MapID, MapName FROM maps) m " ...
			"JOIN players u ON a.Time = b.Time AND a.PlayerID = u.PlayerID AND a.MapID = b.MapID AND b.MapID = m.MapID AND a.Style = b.Style AND a.Type = b.Type " ...
			"WHERE a.Style = 0 AND a.Type = 0 AND m.MapName = '%s' " ...
			"LIMIT 1;", sMap);
	}

	else if(gI_TimerVersion == TimerVersion_bTimes2_0)
	{
		FormatEx(sQuery, 512,
			"SELECT m.MapName, u.SteamID AS steamid, u.User, a.Time, a.Sync, a.Strafes, a.Jumps, a.Timestamp FROM times a " ...
			"JOIN (SELECT MIN(Time) time, MapID, Style, Type, tas FROM times GROUP by MapID, Style, Type, tas) b " ...
			"JOIN (SELECT MapID, MapName FROM maps) m " ...
			"JOIN players u ON a.Time = b.Time AND a.PlayerID = u.PlayerID AND a.MapID = b.MapID AND b.MapID = m.MapID AND a.Style = b.Style AND a.Type = b.Type AND a.tas = b.tas " ...
			"WHERE a.Style = 0 AND a.Type = 0 AND a.tas = 0 AND m.MapName = '%s' " ...
			"LIMIT 1;", sMap);
	}

	gH_Database.Query(SQL_GetCurrentWR_Callback, sQuery, data, DBPrio_Low);

	gH_bTimesTimer = null;

	return Plugin_Stop;
}

public void SQL_GetCurrentWR_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack hPack = view_as<DataPack>(data);
	hPack.Reset();

	char sMap[64];
	hPack.ReadString(sMap, 64);

	char sSteamID[32];
	hPack.ReadString(sSteamID, 32);

	char sName[MAX_NAME_LENGTH];
	hPack.ReadString(sName, MAX_NAME_LENGTH);

	char sDate[32];
	hPack.ReadString(sDate, 32);

	delete hPack;

	if(results == null)
	{
		LogError("[SourceJump] bTimes error - query for GetCurrentWR failed (%s). Error: %s", sMap, error);

		return;
	}

	if(!results.FetchRow())
	{
		LogError("[SourceJump] bTimes error - could not fetch world record for map %s.", sMap);

		return;
	}

	float fTime = results.FetchFloat(3);
	float fSync = results.FetchFloat(4);
	int iStrafes = results.FetchInt(5);
	int iJumps = results.FetchInt(6);

	SendCurrentWR(sMap, sSteamID, sName, sDate, fTime, fSync, iStrafes, iJumps);
}

public void Callback_SendNewWR(HTTPResponse response, any value)
{
	if(response.Status != HTTPStatus_Created || response.Data == null)
	{
		LogError("[SourceJump] Could not send WR to the SJ database. Response status: %d | Data: %d", response.Status, response.Data);

		return;
	}

	SourceJump_DebugLog("Callback_SendNewWR: Successfully submitted record to SJ database.");
}

void SendCurrentWR(char[] sMap, char[] sSteamID, char[] sName, char[] sDate, float time, float sync, int strafes, int jumps)
{
	if(!IsPasswordFetched())
	{
		LogError("[SourceJump] Attempted to submit world record without initial server check. Record data: %s | %s | %s | %s | %f | %f | %d | %d",
			sMap, sSteamID, sName, sDate, time, sync, strafes, jumps);

		return;
	}

	SourceJump_DebugLog("SendCurrentWR: Submitting record to SJ database. Record data: %s | %s | %s | %s | %f | %f | %d | %d",
			sMap, sSteamID, sName, sDate, time, sync, strafes, jumps);

	JSONObject hJSON = new JSONObject();
	AddServerToJson(hJSON);
	hJSON.SetString("map", sMap);
	hJSON.SetString("steamid", sSteamID);
	hJSON.SetString("name", sName);
	hJSON.SetFloat("time", time);
	hJSON.SetFloat("sync", sync);
	hJSON.SetInt("strafes", strafes);
	hJSON.SetInt("jumps", jumps);
	hJSON.SetString("date", sDate);
	hJSON.SetInt("tickrate", gI_Tickrate);
	hJSON.SetNull("replayfile");

	char sPath[PLATFORM_MAX_PATH];

	switch(gI_TimerVersion)
	{
		case TimerVersion_shavit:
		{
			BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "data/replaybot/0/%s.replay", sMap);
		}

		case TimerVersion_bTimes1_8_3:
		{
			BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "data/btimes/%s_0_0.rec", sMap);
		}

		case TimerVersion_bTimes2_0:
		{
			BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "data/btimes/%s_0_0_0.txt", sMap);
		}

		case TimerVersion_FuckItHops:
		{
			// format: no header. read 6 cells at once. x/y/z yaw/pitch buttons. until eof
			char sSteamIDCopy[32];
			strcopy(sSteamIDCopy, 32, sSteamID);
			ReplaceString(sSteamIDCopy, 32, "[U:1:", "");
			ReplaceString(sSteamIDCopy, 32, "]", "");

			BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "data/tTimer/%s/0-0-%d.rec", sMap, StringToInt(sSteamIDCopy));
		}
	}

	if(FileExists(sPath))
	{
		File fFile = OpenFile(sPath, "rb");

		if(fFile != null && fFile.Seek(0, SEEK_END))
		{
			int iSize = (fFile.Position + 1);
			fFile.Seek(0, SEEK_SET);

			char[] sFileContents = new char[iSize + 1];
			fFile.ReadString(sFileContents, (iSize + 1), iSize);
			delete fFile;

			char[] sFileContentsEncoded = new char[iSize * 2];
			Crypt_Base64Encode(sFileContents, sFileContentsEncoded, (iSize * 2), iSize);

			hJSON.SetString("replayfile", sFileContentsEncoded);
		}
	}

	gH_Client.Post("send_new_wr.php", hJSON, Callback_SendNewWR);
	delete hJSON;
}

void AddServerToJson(JSONObject data)
{
	// Read from configs but remove it instantly from cvar memory so sm_cvar won't see the original value.
	if(strlen(gS_AuthKey) == 0)
	{
		gCV_Authentication.GetString(gS_AuthKey, 64);
	}

	gCV_Authentication.SetString("");

	char sPublicIP[32];
	gCV_PublicIP.GetString(sPublicIP, 32);

	char sHostname[128];
	FindConVar("hostname").GetString(sHostname, 128);

	data.SetString("public_ip", sPublicIP);
	data.SetString("private_key", gS_AuthKey);
	data.SetString("hostname", sHostname);
	data.SetString("timer_plugin", gS_TimerVersion[gI_TimerVersion]);
}

bool IsPasswordFetched()
{
	return (strlen(gS_PasswordHash) > 20);
}

public void Callback_OnGetPassword(HTTPResponse response, any value)
{
	if(response.Status != HTTPStatus_OK || response.Data == null)
	{
		LogError("[SourceJump] Could not get password from remote server. Response status: %d | Data: %d", response.Status, response.Data);

		return;
	}

	view_as<JSONObject>(response.Data).GetString("password", gS_PasswordHash, 64);

	if(!IsPasswordFetched())
	{
		return;
	}

	SourceJump_DebugLog("Callback_OnGetPassword: Obtained checksum from remote server: %s", gS_PasswordHash);

	JSONObject hContact = new JSONObject();
	AddServerToJson(hContact);
	gH_Client.Post("first_install_check.php", hContact, Callback_OnContact);
	delete hContact;
}

public void Callback_OnContact(HTTPResponse response, any value)
{
	if(response.Status != HTTPStatus_Created || response.Data == null)
	{
		LogError("[SourceJump] Failed contacting SJ server for initial contact. Response status: %d | Data: %d", response.Status, response.Data);

		return;
	}

	char sBuffer[255];
	view_as<JSON>(response.Data).ToString(sBuffer, 255);

	bool bWhitelisted = view_as<JSONObject>(response.Data).GetBool("whitelisted");

	if(!bWhitelisted)
	{
		SourceJump_Log("Server is not whitelisted. Contact a database admin.");

		return;
	}

	bool bSendRecordList = view_as<JSONObject>(response.Data).GetBool("send_list");

	if(bSendRecordList)
	{
		SourceJump_DebugLog("Callback_OnContact: Sending list of records to SJ server!");
		SendListOfRecords();
	}

	else
	{
		SourceJump_DebugLog("Callback_OnContact: Server does not want a list of records from us.");
	}
}

void SendListOfRecords()
{
	char sQuery[1024];

	switch(gI_TimerVersion)
	{
		case TimerVersion_shavit:
		{
			FormatEx(sQuery, 1024,
				"SELECT a.map, u.auth AS steamid, u.name, a.time, a.sync, a.strafes, a.jumps, a.date FROM %splayertimes a " ...
				"JOIN (SELECT MIN(time) time, map, style, track FROM %splayertimes GROUP by map, style, track) b " ...
				"JOIN %susers u ON a.time = b.time AND a.auth = u.auth AND a.map = b.map AND a.style = b.style AND a.track = b.track " ...
				"WHERE a.style = 0 AND a.track = 0 " ...
				"ORDER BY a.date DESC;", gS_MySQLPrefix, gS_MySQLPrefix, gS_MySQLPrefix);
		}

		case TimerVersion_bTimes2_0:
		{
			strcopy(sQuery, 1024,
				"SELECT m.MapName, u.SteamID AS steamid, u.User, a.Time, a.Sync, a.Strafes, a.Jumps, a.Timestamp FROM times a " ...
				"JOIN (SELECT MIN(Time) time, MapID, Style, Type, tas FROM times GROUP by MapID, Style, Type, tas) b " ...
				"JOIN (SELECT MapID, MapName FROM maps) m " ...
				"JOIN players u ON a.Time = b.Time AND a.PlayerID = u.PlayerID AND a.MapID = b.MapID AND b.MapID = m.MapID AND a.Style = b.Style AND a.Type = b.Type AND a.tas = b.tas " ...
				"WHERE a.Style = 0 AND a.Type = 0 AND a.tas = 0 " ...
				"ORDER BY a.Timestamp DESC;");
		}

		case TimerVersion_bTimes1_8_3:
		{
			strcopy(sQuery, 1024,
				"SELECT m.MapName, u.SteamID AS steamid, u.User, a.Time, a.Sync, a.Strafes, a.Jumps, a.Timestamp FROM times a " ...
				"JOIN (SELECT MIN(Time) time, MapID, Style, Type FROM times GROUP by MapID, Style, Type) b " ...
				"JOIN (SELECT MapID, MapName FROM maps) m " ...
				"JOIN players u ON a.Time = b.Time AND a.PlayerID = u.PlayerID AND a.MapID = b.MapID AND b.MapID = m.MapID AND a.Style = b.Style AND a.Type = b.Type " ...
				"WHERE a.Style = 0 AND a.Type = 0 " ...
				"ORDER BY a.Timestamp DESC;");
		}

		case TimerVersion_FuckItHops:
		{
			strcopy(sQuery, 1024,
				"SELECT a.MapName, a.SteamID AS steamid, a.Name, a.Time, a.Sync, a.Strafes, a.Jumps, a.Date FROM timelist a " ...
				"JOIN (SELECT MIN(Time) Time, MapName FROM timelist WHERE Type = 0 AND Style = 0 GROUP by MapName, Style, Type) b " ...
				"ON a.Time = b.Time AND a.MapName = b.MapName " ...
				"WHERE a.Type = 0 AND a.Style = 0 " ...
				"ORDER BY Date DESC;");
		}
	}

	gH_Database.Query(SQL_GetList_Callback, sQuery, 0, DBPrio_Low);
}

void SteamID2To3(const char[] steam2, char[] buffer, int maxlen)
{
	strcopy(buffer, maxlen, steam2);
	ReplaceString(buffer, 32, "STEAM_0:", "");
	ReplaceString(buffer, 32, "STEAM_1:", "");

	char sExploded[2][16];
	ExplodeString(buffer, ":", sExploded, 2, 16, false);

	int iPrefix = StringToInt(sExploded[0]);
	int iSteamID = StringToInt(sExploded[1]);

	FormatEx(buffer, maxlen, "[U:1:%d]", ((iSteamID * 2) + iPrefix));
}

JSONObject GetTimeJsonFromResult(DBResultSet results)
{
	char sMap[64];
	results.FetchString(0, sMap, 64);

	char sSteamID[32];
	results.FetchString(1, sSteamID, 32);

	switch(gI_TimerVersion)
	{
		case TimerVersion_shavit, TimerVersion_FuckItHops:
		{
			if(StrContains(sSteamID, "[U:1:", false) == -1)
			{
				Format(sSteamID, 32, "[U:1:%s]", sSteamID);
			}
		}

		case TimerVersion_bTimes1_8_3, TimerVersion_bTimes2_0:
		{
			SteamID2To3(sSteamID, sSteamID, 32);
		}
	}

	char sName[MAX_NAME_LENGTH];
	results.FetchString(2, sName, MAX_NAME_LENGTH);

	char sDate[32];
	FormatTime(sDate, 32, "%Y-%m-%d %H:%M:%S", results.FetchInt(7));

	JSONObject hJSON = new JSONObject();
	hJSON.SetString("map", sMap);
	hJSON.SetString("steamid", sSteamID);
	hJSON.SetString("name", sName);
	hJSON.SetFloat("time", results.FetchFloat(3));
	hJSON.SetFloat("sync", results.FetchFloat(4));
	hJSON.SetInt("strafes", results.FetchInt(5));
	hJSON.SetInt("jumps", results.FetchInt(6));
	hJSON.SetString("date", sDate);
	hJSON.SetInt("tickrate", gI_Tickrate);

	return hJSON;
}

public void SQL_GetList_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null || results.RowCount == 0 || !IsPasswordFetched())
	{
		SourceJump_DebugLog("SQL_GetList_Callback: No results from record selection query.");

		return;
	}

	SourceJump_DebugLog("SQL_GetList_Callback: Collected %d records, preparing to send them over to SJ database.", results.RowCount);

	JSONArray hArray = new JSONArray();

	while(results.FetchRow())
	{
		JSONObject hJSON = GetTimeJsonFromResult(results);
		hArray.Push(hJSON);
		delete hJSON;
	}

	JSONObject hRecordsList = new JSONObject();
	AddServerToJson(hRecordsList);
	hRecordsList.Set("records", hArray);
	gH_Client.Post("send_records_list.php", hRecordsList, Callback_OnRecordsList, results.RowCount);

	delete hArray;
	delete hRecordsList;
}

public void Callback_OnRecordsList(HTTPResponse response, any value)
{
	if(response.Status != HTTPStatus_Created || response.Data == null)
	{
		LogError("[SourceJump] Could not submit list of world records to SJ remote server. Response status: %d | Data: %d", response.Status, response.Data);
		
		return;
	}

	SourceJump_DebugLog("Callback_OnRecordsList: Successfully submitted %d records to SJ database!", value);
}

// stocks from shavit.inc
// connects synchronously to the bhoptimer database
// calls errors if needed
Database GetTimerDatabaseHandle()
{
	Database db = null;
	char sError[255];

	if(SQL_CheckConfig("shavit"))
	{
		if((db = SQL_Connect("shavit", true, sError, 255)) == null)
		{
			SetFailState("SourceJump plugin startup failed. Reason: %s", sError);
		}
	}

	else
	{
		db = SQLite_UseDatabase("shavit", sError, 255);
	}

	return db;
}

// retrieves the table prefix defined in configs/shavit-prefix.txt
void GetTimerSQLPrefix(char[] buffer, int maxlen)
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, PLATFORM_MAX_PATH, "configs/shavit-prefix.txt");

	File fFile = OpenFile(sFile, "r");

	if(fFile == null)
	{
		SetFailState("Cannot open \"configs/shavit-prefix.txt\". Make sure this file exists and that the server has read permissions to it.");
	}
	
	char sLine[PLATFORM_MAX_PATH * 2];

	if(fFile.ReadLine(sLine, PLATFORM_MAX_PATH * 2))
	{
		TrimString(sLine);
		strcopy(buffer, maxlen, sLine);
	}

	delete fFile;
}

// from smlib
/*
 * Encodes a string or binary data into Base64
 *
 * @param sString		The input string or binary data to be encoded.
 * @param sResult		The storage buffer for the Base64-encoded result.
 * @param len			The maximum length of the storage buffer, in characters/bytes.
 * @param sourcelen 	(optional): The number of characters or length in bytes to be read from the input source.
 *						This is not needed for a text string, but is important for binary data since there is no end-of-line character.
 * @return				The length of the written Base64 string, in bytes.
 */
int Crypt_Base64Encode(const char[] sString, char[] sResult, int len, int sourcelen = 0)
{
	char base64_sTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	int base64_cFillChar = '=';

	int nLength;
	int resPos;

	if(sourcelen > 0)
	{
		nLength = sourcelen;
	}

	else
	{
		nLength = strlen(sString);
	}

	for(int nPos = 0; nPos < nLength; nPos++)
	{
		int cCode;

		cCode = (sString[nPos] >> 2) & 0x3f;
		resPos += FormatEx(sResult[resPos], len - resPos, "%c", base64_sTable[cCode]);
		cCode = (sString[nPos] << 4) & 0x3f;

		if(++nPos < nLength)
		{
			cCode |= (sString[nPos] >> 4) & 0x0f;
		}

		resPos += FormatEx(sResult[resPos], len - resPos, "%c", base64_sTable[cCode]);

		if(nPos < nLength)
		{
			cCode = (sString[nPos] << 2) & 0x3f;

			if(++nPos < nLength)
			{
				cCode |= (sString[nPos] >> 6) & 0x03;
			}

			resPos += FormatEx(sResult[resPos], len - resPos, "%c", base64_sTable[cCode]);
		}

		else
		{
			nPos++;
			resPos += FormatEx(sResult[resPos], len - resPos, "%c", base64_cFillChar);
		}

		if(nPos < nLength)
		{
			cCode = sString[nPos] & 0x3f;
			resPos += FormatEx(sResult[resPos], len - resPos, "%c", base64_sTable[cCode]);
		}

		else
		{
			resPos += FormatEx(sResult[resPos], len - resPos, "%c", base64_cFillChar);
		}
	}

	return resPos;
}

void SourceJump_DebugLog(const char[] format, any ...)
{
	if(!gCV_ExtendedDebugging.BoolValue)
	{
		return;
	}

	char sBuffer[300];
	VFormat(sBuffer, 300, format, 2);
	LogMessage("[SourceJump] %d | %s", ++gI_DebuggingLog, sBuffer);
}

void SourceJump_Log(const char[] format, any ...)
{
	char sBuffer[300];
	VFormat(sBuffer, 300, format, 2);
	LogMessage("[SourceJump] %d | %s", ++gI_DebuggingLog, sBuffer);
}
