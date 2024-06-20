
// TODO: THE FUCKING ADMIN MENU THING! WHICH CATEGORY WOULD IT GO TO?
//#include <adminmenu>

#include <shavit>
#include <convar_class>

public Plugin myinfo =
{
	name = "shavitzz-impossible-style",
	author = "rtldg",
	description = "(clients need the Generic admin flag to toggle things)",
	version = "1.0",
	url = "https://github.com/PMArkive/random-shavit-bhoptimer-stuff/blob/main/shavitzz-impossible-style.sp"
}

Database gH_DB = null;
bool gB_DBInitialized = false;
int gI_MapQueries = -1;
bool gB_HasMenuOpened[MAXPLAYERS+1];
char gS_Map[PLATFORM_MAX_PATH];
char gS_VariableStringColor[16];
char gS_TextStringColor[16];
bool gB_MapStart = false;
//int gI_MenuPositions[MAXPLAYERS+1]; // TODO: Save instead of using gB_HasMenuOpened?
Convar gCV_ShowStyleSettingOptions = null;
Convar gCV_ShowOnlyTheseStyles = null;
ArrayList gH_ShowOnlyTheseStyles = null;
bool gB_SpawnedOnce[MAXPLAYERS+1];

enum struct CurrentMapState
{
	bool requires_auto;
	bool requires_easybhop;
	bool requires_uncappedvel;
	bool style[STYLE_LIMIT];
}

CurrentMapState gA_State;

public void OnPluginStart()
{
	RegConsoleCmd("sm_impossible_style", Command_ImpossibleStyle, "TODO: description");
	RegConsoleCmd("sm_impossible_map", Command_ImpossibleStyle, "TODO: description");
	RegConsoleCmd("sm_impossible", Command_ImpossibleStyle, "TODO: description");

	if (null == (gH_DB = SQLite_UseDatabase("shavitzz-impossible-style", "", 0)))
		SetFailState("Failed to open shavitzz-impossible-style sqlite database");

	SQL_CreateTables();

	gCV_ShowStyleSettingOptions = new Convar("shavitzz_impossible_style_settings", "1", "Show the autobhop/easybhop/uncapped-vel things at the top of the menu.", 0, true, 0.0, true, 1.0);
	gCV_ShowOnlyTheseStyles = new Convar("shavitzz_impossible_style_only", "", "Show only these styles in the menu.\n(Style names are compared in a case-insensitive way and spaces are trimmed from the ends)\nExamples:\n shavitzz_impossible_style_only \"scroll,_strafe,400 velocity\"\n shavitzz_impossible_style_only \"low gravity, scroll\"\n");
	Convar.AutoExecConfig();

	HookEvent("player_spawn", player_spawn);
}

public void OnMapStart()
{
	gB_MapStart = true;
	Shavit_GetChatStrings(sMessageVariable, gS_VariableStringColor, sizeof(gS_VariableStringColor));
	Shavit_GetChatStrings(sMessageText, gS_TextStringColor, sizeof(gS_TextStringColor));
	CurrentMapState temp;
	gA_State = temp;
	gI_MapQueries = 0;
	myGetLowercaseMapName(gS_Map);

	if (gB_DBInitialized)
	{
		SQL_QueryCurrentMapState();
	}

	delete gH_ShowOnlyTheseStyles;
}

public void OnMapEnd()
{
	gB_MapStart = false;
	gI_MapQueries = 0;
}

public void OnConfigsExecuted()
{
	char buf[512];
	gCV_ShowOnlyTheseStyles.GetString(buf, sizeof(buf));

	if (buf[0] != '\0')
	{
		char exploded[50][50];
		int count = ExplodeString(buf, ",", exploded, sizeof(exploded), sizeof(exploded[]), false);
		if (!count) return;

		gH_ShowOnlyTheseStyles = new ArrayList(1);

		for (int i = 0; i < count; i++)
		{
			TrimString(exploded[i]);
			PrintToServer("'%s'", exploded[i]);
		}

		for (int style = 0, styles = Shavit_GetStyleCount(); style < styles; style++)
		{
			char stylename[64];
			Shavit_GetStyleStrings(style, sStyleName, stylename, sizeof(stylename));

			for (int i = 0; i < count; i++)
			{
				if (0 == strcmp(stylename, exploded[i], false))
				{
					gH_ShowOnlyTheseStyles.Push(style);
					PrintToServer("pushed %d", style);
					break;
				}
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	gB_HasMenuOpened[client] = false;
	gB_SpawnedOnce[client] = false;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	if (gB_SpawnedOnce[client] && oldstyle != newstyle && (gA_State.style[newstyle] || isStyleSettingsImpossible(newstyle)))
	{
		for (int i = 0; i < 6; i++)
		{
			char stylename[64];
			Shavit_GetStyleStrings(newstyle, sStyleName, stylename, sizeof(stylename));
			Shavit_PrintToChat(client, "Map is %simpossible%s on this style (%s%s%s)!", gS_VariableStringColor, gS_TextStringColor, gS_VariableStringColor, stylename, gS_TextStringColor);
		}
	}
}

public void player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!gB_SpawnedOnce[client] && !IsFakeClient(client) && GetClientTeam(client) > 1 && IsPlayerAlive(client))
	{
		gB_SpawnedOnce[client] = true;
		Shavit_OnStyleChanged(client, -1, Shavit_GetBhopStyle(client), -1, false);
	}
}

Action Command_ImpossibleStyle(int client, int args)
{
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	if (gI_MapQueries != 2 || !gB_DBInitialized)
	{
		ReplyToCommand(client, "Map queries haven't finished (or failed, even!) so you can't look!");
		return Plugin_Handled;
	}

	OpenTheMenu(client, 0);
	return Plugin_Handled;
}

bool isStyleSettingsImpossible(int style)
{
	stylesettings_t settings;
	Shavit_GetStyleSettings(style, settings);
	return !settings.iEnabled ||
		(!settings.bAutobhop && gA_State.requires_auto) ||
		(!settings.bEasybhop && gA_State.requires_easybhop) ||
		(settings.fVelocityLimit != 0.0 && settings.fVelocityLimit < 400.0 && gA_State.requires_uncappedvel);
}

void OpenTheMenu(int client, int position)
{
	int flags = GetAdminFlag(GetUserAdmin(client), Admin_Generic) ? 0 : ITEMDRAW_DISABLED;

	Menu menu = new Menu(MenuHandler_ImpossibleStyle);
	menu.SetTitle("Map Impossibilities\n ");

	char display[256];

	if (gCV_ShowStyleSettingOptions.BoolValue)
	{
		FormatEx(display, sizeof(display), "[%s] Requires autobhop", gA_State.requires_auto ? "+" : "-");
		menu.AddItem("requires_auto", display, flags);
		FormatEx(display, sizeof(display), "[%s] Requires easybhop", gA_State.requires_easybhop ? "+" : "-");
		menu.AddItem("requires_easybhop", display, flags);
		FormatEx(display, sizeof(display), "[%s] Requires no velocity cap\n ", gA_State.requires_uncappedvel ? "+" : "-");
		menu.AddItem("requires_uncappedvel", display, flags);
	}

	if (!gH_ShowOnlyTheseStyles)
	{
		int tempstyle = Shavit_GetBhopStyle(client);
		Shavit_GetStyleStrings(tempstyle, sStyleName, display, sizeof(display));
		Format(display, sizeof(display), "[%s] Current style: %s\n ", gA_State.style[tempstyle] ? "+" : "-", display);
		char numstr[8];
		IntToString(tempstyle, numstr, sizeof(numstr));
		menu.AddItem(numstr, display, flags | (isStyleSettingsImpossible(tempstyle) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT));
	}

	for (int i = 0, styles = gH_ShowOnlyTheseStyles ? gH_ShowOnlyTheseStyles.Length : Shavit_GetStyleCount(); i < styles; i++)
	{
		int style = gH_ShowOnlyTheseStyles ? gH_ShowOnlyTheseStyles.Get(i) : i;
		char name[64], info[8];
		Shavit_GetStyleStrings(style, sStyleName, name, sizeof(name));
		FormatEx(display, sizeof(display), "[%s] %s", gA_State.style[style] ? "+" : "-", name);
		IntToString(style, info, sizeof(info));
		bool disabled = isStyleSettingsImpossible(style);
		menu.AddItem(info, display, flags | (disabled ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT));
	}

	menu.ExitButton = true;
	menu.DisplayAt(client, position, MENU_TIME_FOREVER);
	gB_HasMenuOpened[client] = true;
}

int MenuHandler_ImpossibleStyle(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		int client = param1;
		int item = param2;
		char info[32];
		menu.GetItem(item, info, sizeof(info));
		int style = StringToInt(info); // ignore if not int info...

		if (StrEqual(info, "requires_auto"))
		{
			gA_State.requires_auto = !gA_State.requires_auto;
		}
		else if (StrEqual(info, "requires_easybhop"))
		{
			gA_State.requires_easybhop = !gA_State.requires_easybhop;
		}
		else if (StrEqual(info, "requires_uncappedvel"))
		{
			gA_State.requires_uncappedvel = !gA_State.requires_uncappedvel;
		}
		else if (info[0] <= '9' && info[0] >= '0')
		{
			gA_State.style[style] = !gA_State.style[style];
		}
		else
		{
			return 0;
		}

		char query[512];
		if (info[0] <= '9' && info[0] >= '0')
		{
			if (gA_State.style[style])
			{
				FormatEx(query, sizeof(query), "INSERT INTO impossible_style VALUES(%d, '%s');", style, gS_Map);
			}
			else
			{
				FormatEx(query, sizeof(query), "DELETE FROM impossible_style WHERE style = %d AND map = '%s'", style, gS_Map);
			}
		}
		else
		{
			FormatEx(query, sizeof(query), "INSERT INTO impossible_settings VALUES('%s', %d, %d, %d) ON CONFLICT(map) DO UPDATE SET requires_auto=%d, requires_easybhop=%d, requires_uncappedvel=%d;", gS_Map, gA_State.requires_auto, gA_State.requires_easybhop, gA_State.requires_uncappedvel, gA_State.requires_auto, gA_State.requires_easybhop, gA_State.requires_uncappedvel);
		}
		gH_DB.Query(SQLCallback_UpdateCurrentMapState, query);

		OpenTheMenu(client, GetMenuSelectionPosition());
		for (int i = 1; i <= MaxClients; i++)
		{
			if (client != i && IsClientInGame(i) && gB_HasMenuOpened[i])
			{
				CancelClientMenu(i);
				OpenTheMenu(i, 0);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		int client = param1;
		//int reason = param2;
		gB_HasMenuOpened[client] = false;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void SQLCallback_UpdateCurrentMapState(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null || error[0] != '\0')
	{
		LogError("query failed. fuck it... (%s) Error: %s", gS_Map, error);
		return;
	}
}



void SQL_QueryCurrentMapState()
{
	char query[512];
	FormatEx(query, sizeof(query), "SELECT requires_auto, requires_easybhop, requires_uncappedvel FROM impossible_settings WHERE map = '%s'", gS_Map);
	gH_DB.Query(SQLCallback_QueryCurrentMapState1, query);
	FormatEx(query, sizeof(query), "SELECT style FROM impossible_style WHERE map = '%s'", gS_Map);
	gH_DB.Query(SQLCallback_QueryCurrentMapState2, query);
}

void SQLCallback_QueryCurrentMapState1(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null || error[0] != '\0')
	{
		LogError("Failed to query requires_auto, requires_easybhop, and requires_uncappedvel for map (%s). Error: %s", gS_Map, error);
		return;
	}

	gI_MapQueries += 1;

	if (results.FetchRow())
	{
		gA_State.requires_auto = !!results.FetchInt(0);
		gA_State.requires_easybhop = !!results.FetchInt(1);
		gA_State.requires_uncappedvel = !!results.FetchInt(2);
	}

	YellAtUsers();
}

void SQLCallback_QueryCurrentMapState2(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null || error[0] != '\0')
	{
		LogError("Failed to query impossible styles for map (%s). Error: %s", gS_Map, error);
		return;
	}

	gI_MapQueries += 1;

	while (results.FetchRow())
	{
		gA_State.style[results.FetchInt(0)] = true;
	}

	YellAtUsers();
}

void YellAtUsers()
{
	if (gI_MapQueries != 2)
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) > 1 && IsPlayerAlive(i))
		{
			gB_SpawnedOnce[i] = true;
			Shavit_OnStyleChanged(i, -1, Shavit_GetBhopStyle(i), -1, false);
		}
	}
}


char gS_TableQueries[][] = {
	"CREATE TABLE IF NOT EXISTS impossible_settings(map TEXT PRIMARY KEY, requires_auto INT NOT NULL, requires_easybhop INT NOT NULL, requires_uncappedvel INT NOT NULL);",
	"CREATE TABLE IF NOT EXISTS impossible_style(style INT NOT NULL, map TEXT NOT NULL);",
	"CREATE INDEX IF NOT EXISTS impossible_style_map ON impossible_style(map);",
};

void SQL_CreateTables()
{
	Transaction trans = new Transaction();
	for (int i = 0; i < sizeof(gS_TableQueries); i++)
		trans.AddQuery(gS_TableQueries[i]);
	gH_DB.Execute(trans, Trans_DbInitSuccess, Trans_DbInitFailure);
}

void Trans_DbInitSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	gB_DBInitialized = true;
	if (gB_MapStart)
		SQL_QueryCurrentMapState();
}

void Trans_DbInitFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	SetFailState("Failed to initialize database. Failed with query\n%s\n%s", error, failIndex < 0 ? "unknown query" : gS_TableQueries[failIndex]);
}




stock void myLowercaseString(char[] str)
{
	int i, x;
	while ((x = str[i]) != 0)
	{
		if ('A' <= x <= 'Z')
			str[i] += ('a' - 'A');
		++i;
	}
}
// GetMapDisplayName ends up opening every single fucking file to verify it's valid.
// I don't care about that. I just want the stupid fucking mapname string.
// Also this lowercases the string.
stock void myLessStupidGetMapDisplayName(const char[] map, char[] displayName, int maxlen)
{
	char temp[PLATFORM_MAX_PATH];
	char temp2[PLATFORM_MAX_PATH];

	strcopy(temp, sizeof(temp), map);
	ReplaceString(temp, sizeof(temp), "\\", "/", true);

	int slashpos = FindCharInString(temp, '/', true);
	strcopy(temp2, sizeof(temp2), temp[slashpos+1]);

	int ugcpos = StrContains(temp2, ".ugc", true);

	if (ugcpos != -1)
	{
		temp2[ugcpos] = 0;
	}

	myLowercaseString(temp2);
	strcopy(displayName, maxlen, temp2);
}
stock void myGetLowercaseMapName(char sMap[PLATFORM_MAX_PATH])
{
	GetCurrentMap(sMap, sizeof(sMap));
	myLessStupidGetMapDisplayName(sMap, sMap, sizeof(sMap));
}
