
// TODO: THE FUCKING ADMIN MENU THING! WHICH CATEGORY WOULD IT GO TO?
//#include <adminmenu>

#include <shavit>

public Plugin myinfo =
{
	name = "shavitzz-impossible-style",
	author = "rtldg",
	description = "(clients need the Generic admin flag to toggle things)",
	version = "1.0",
	url = "https://github.com/rtldg/shavitzz-impossible-style"
}

Database gH_DB = null;
bool gB_DBInitialized = false;
int gI_MapQueries = -1;
bool gB_HasMenuOpened[MAXPLAYERS+1];
char gS_Map[PLATFORM_MAX_PATH];
bool gB_Late = false;
char gS_WarningStringColor[16];
char gS_TextStringColor[16];

enum struct CurrentMapState
{
	bool requires_auto;
	bool requires_easybhop;
	bool requires_uncappedvel;
	bool style[STYLE_LIMIT];
}

CurrentMapState gA_State;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_impossible_style", Command_ImpossibleStyle, "TODO: description");

	if (null == (gH_DB = SQLite_UseDatabase("shavitzz-impossible-style", "", 0)))
		SetFailState("Failed to open shavitzz-impossible-style sqlite database");

	SQL_CreateTables();

	if (gB_Late)
	{
		OnMapStart();
	}
}

public void OnMapStart()
{
	Shavit_GetChatStrings(sMessageVariable, gS_WarningStringColor, sizeof(gS_WarningStringColor));
	Shavit_GetChatStrings(sMessageText, gS_TextStringColor, sizeof(gS_TextStringColor));
	CurrentMapState temp;
	gA_State = temp;
	gI_MapQueries = 0;
	SQL_QueryCurrentMapState();
	myGetLowercaseMapName(gS_Map);
}

public void OnClientPutInServer(int client)
{
	gB_HasMenuOpened[client] = false;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	if (oldstyle != newstyle && (gA_State.style[newstyle] || isStyleSettingsImpossible(newstyle)))
	{
		for (int i = 0; i < 6; i++)
		{
			Shavit_PrintToChat(client, "Map is %simpossible%s on this style!", gS_WarningStringColor, gS_TextStringColor);
		}
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
		(settings.fVelocityLimit != 0.0 && settings.fVelocityLimit < 1000.0 && gA_State.requires_uncappedvel);
}

void OpenTheMenu(int client, int position)
{
	int flags = GetAdminFlag(GetUserAdmin(client), Admin_Generic) ? 0 : ITEMDRAW_DISABLED;

	Menu menu = new Menu(MenuHandler_ImpossibleStyle);
	menu.SetTitle("Map Impossibilities");

	char display[256];
	FormatEx(display, sizeof(display), "[%s] Requires autobhop", gA_State.requires_auto ? "+" : "-");
	menu.AddItem("requires_auto", display);
	FormatEx(display, sizeof(display), "[%s] Requires easybhop", gA_State.requires_easybhop ? "+" : "-");
	menu.AddItem("requires_easybhop", display);
	FormatEx(display, sizeof(display), "[%s] Requires no velocity cap\n ", gA_State.requires_uncappedvel ? "+" : "-");
	menu.AddItem("requires_uncappedvel", display);

	int tempstyle = Shavit_GetBhopStyle(client);
	Shavit_GetStyleStrings(tempstyle, sStyleName, display, sizeof(display));
	Format(display, sizeof(display), "[%s] Current style: %s\n ", gA_State.style[tempstyle] ? "+" : "-", display);
	char numstr[8];
	IntToString(tempstyle, numstr, sizeof(numstr));
	menu.AddItem(numstr, display, flags | (isStyleSettingsImpossible(tempstyle) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT));

	for (int i = 0, styles = Shavit_GetStyleCount(); i < styles; i++)
	{
		char name[64], info[8];
		Shavit_GetStyleStrings(i, sStyleName, name, sizeof(name));
		FormatEx(display, sizeof(display), "[%s] %s", gA_State.style[i] ? "+" : "-", name);
		IntToString(i, info, sizeof(info));
		bool disabled = isStyleSettingsImpossible(i);
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
		int reason = param2;
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
		LogError("query failed. fuck it... Error: %s", error);
		return;
	}
}



void SQL_QueryCurrentMapState()
{
	if (!gB_DBInitialized)
		return;

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
		LogError("Failed to query requires_auto, requires_easybhop, and requires_uncappedvel for map. Error: %s", error);
		return;
	}

	gI_MapQueries += 1;

	if (results.FetchRow())
	{
		gA_State.requires_auto = !!results.FetchInt(0);
		gA_State.requires_easybhop = !!results.FetchInt(1);
		gA_State.requires_uncappedvel = !!results.FetchInt(2);
	}
}

void SQLCallback_QueryCurrentMapState2(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null || error[0] != '\0')
	{
		LogError("Failed to query impossible styles for map. Error: %s", error);
		return;
	}

	gI_MapQueries += 1;

	while (results.FetchRow())
	{
		gA_State.style[results.FetchInt(0)] = true;
	}
}



char gS_TableQueries[][] = {
	"CREATE TABLE IF NOT EXISTS impossible_settings(map TEXT PRIMARY KEY, requires_auto INT NOT NULL, requires_easybhop INT NOT NULL, requires_uncappedvel INT NOT NULL);",
	"CREATE TABLE IF NOT EXISTS impossible_style(style INT NOT NULL, map TEXT NOT NULL);",
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
	if (gI_MapQueries == 0)
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