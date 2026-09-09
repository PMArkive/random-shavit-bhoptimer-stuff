#include <sourcemod>
#include <sdktools>
#include <shavit/core>
#include <shavit/replay-file>
#include <shavit/replay-playback>
#include <shavit/replay-stocks.sp>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name        = "shavit-customreplay",
	author      = "normalamron",
	description = "",
	version     = "",
	url         = ""
};

char gS_ReplayFolder[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	RegConsoleCmd("sm_creplay", Command_CustomReplays, "Custom replay menu");
	RegConsoleCmd("sm_creplays", Command_CustomReplays, "Custom replay menu");
	RegConsoleCmd("sm_customreplay", Command_CustomReplays, "Custom replay menu");
	RegConsoleCmd("sm_customreplays", Command_CustomReplays, "Custom replay menu");
}

public void Shavit_OnReplaysLoaded()
{
	if (!Shavit_GetReplayFolderPath_Stock(gS_ReplayFolder))
	{
		SetFailState("Could not load the replay bots' configuration file. Make sure it exists (addons/sourcemod/configs/shavit-replay.cfg) and follows the proper syntax!");
	}

	char sCustomFolder[PLATFORM_MAX_PATH];
	FormatEx(sCustomFolder, sizeof(sCustomFolder), "%s/custom", gS_ReplayFolder);

	if (!DirExists(sCustomFolder) && !CreateDirectory(sCustomFolder, 511))
	{
		SetFailState("Failed to create replay folder (%s). Make sure you have file permissions", sCustomFolder);
	}
}

void GetCustomReplayFolder(char sBuffer[PLATFORM_MAX_PATH])
{
	if (gS_ReplayFolder[0] == '\0')
	{
		Shavit_GetReplayFolderPath_Stock(gS_ReplayFolder);
	}

	FormatEx(sBuffer, PLATFORM_MAX_PATH, "%s/custom", gS_ReplayFolder);
}

stock void CleanMapName(const char[] input, char[] output, int maxlen)
{
	strcopy(output, maxlen, input);

	int slashIndex = -1;
	for (int i = 0; output[i] != '\0'; i++)
	{
		if (output[i] == '/' || output[i] == '\\')
		{
			slashIndex = i;
		}
	}

	if (slashIndex != -1)
	{
		strcopy(output, maxlen, output[slashIndex + 1]);
	}

	int len = strlen(output);
	if (len > 4 && StrEqual(output[len - 4], ".bsp", false))
	{
		output[len - 4] = '\0';
	}

	for (int i = 0; output[i] != '\0'; i++)
	{
		output[i] = CharToLower(output[i]);
	}
}

public Action Command_CustomReplays(int client, int args)
{
	if (client != 0)
	{
		OpenCustomReplayMenu(client);
	}
	return Plugin_Handled;
}

void OpenCustomReplayMenu(int client)
{
	char sCustomFolder[PLATFORM_MAX_PATH];
	GetCustomReplayFolder(sCustomFolder);

	DirectoryListing dir = OpenDirectory(sCustomFolder);
	if (dir == null)
	{
		Shavit_PrintToChat(client, "Failed to read custom replay folder: %s", sCustomFolder);
		return;
	}

	ArrayList aFileList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	char sFileName[PLATFORM_MAX_PATH];
	FileType type;

	while (dir.GetNext(sFileName, sizeof(sFileName), type))
	{
		if (type != FileType_File)
		{
			continue;
		}

		int len = strlen(sFileName);
		if (len < 7)
		{
			continue;
		}

		if (StrEqual(sFileName[len - 7], ".replay", false) || StrEqual(sFileName[len - 4], ".rec", false))
		{
			aFileList.PushString(sFileName);
		}
	}
	delete dir;

	aFileList.Sort(Sort_Ascending, Sort_String);

	Menu menu = new Menu(MenuHandler_CustomReplayList);
	menu.SetTitle("Custom Replay Menu");

	int fileCount = aFileList.Length;
	if (fileCount == 0)
	{
		menu.AddItem("", "No .replay files found in the folder.", ITEMDRAW_DISABLED);
	}
	else
	{
		char sFullPath[PLATFORM_MAX_PATH];
		char sDisplay[256];
		char sFormattedTime[32];

		for (int i = 0; i < fileCount; i++)
		{
			aFileList.GetString(i, sFileName, sizeof(sFileName));
			FormatEx(sFullPath, sizeof(sFullPath), "%s/%s", sCustomFolder, sFileName);

			replay_header_t header;
			File fFile = ReadReplayHeader(sFullPath, header);
			if (fFile != null)
			{
				delete fFile;
				FormatSeconds(header.fTime, sFormattedTime, sizeof(sFormattedTime), true);

				FormatEx(sDisplay, sizeof(sDisplay), "[%s] %s (%s)", header.sMap, sFileName, sFormattedTime);
			}
			else
			{
				FormatEx(sDisplay, sizeof(sDisplay), "%s (Header Not Found)", sFileName);
			}

			menu.AddItem(sFileName, sDisplay);
		}
	}

	delete aFileList;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_CustomReplayList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		int client = param1;
		char sFileName[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sFileName, sizeof(sFileName));

		OpenReplayDetailMenu(client, sFileName);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenReplayDetailMenu(int client, const char[] sFileName)
{
	char sCustomFolder[PLATFORM_MAX_PATH];
	GetCustomReplayFolder(sCustomFolder);

	char sFullPath[PLATFORM_MAX_PATH];
	FormatEx(sFullPath, sizeof(sFullPath), "%s/%s", sCustomFolder, sFileName);

	replay_header_t header;
	File fFile = ReadReplayHeader(sFullPath, header);
	if (fFile == null)
	{
		Shavit_PrintToChat(client, "Header not found.");
		return;
	}
	delete fFile;

	char sStyleBuffer[64];
	if (header.iStyle >= 0 && header.iStyle < Shavit_GetStyleCount())
	{
		Shavit_GetStyleStrings(header.iStyle, sStyleName, sStyleBuffer, sizeof(sStyleBuffer));
	}
	else
	{
		FormatEx(sStyleBuffer, sizeof(sStyleBuffer), "Style #%d", header.iStyle);
	}

	char sTrackName[32];
	if (header.iTrack == Track_Main)
	{
		strcopy(sTrackName, sizeof(sTrackName), "Main Track");
	}
	else
	{
		FormatEx(sTrackName, sizeof(sTrackName), "Bonus Track #%d", header.iTrack);
	}

	char sFormattedTime[32];
	FormatSeconds(header.fTime, sFormattedTime, sizeof(sFormattedTime), true);

	char sPlayer[64];
	if (header.iSteamID != 0)
	{
		FormatEx(sPlayer, sizeof(sPlayer), "[U:1:%u]", header.iSteamID);
	}
	else
	{
		strcopy(sPlayer, sizeof(sPlayer), "Unknown");
	}

	char sCurrentMap[PLATFORM_MAX_PATH];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));

	char sCleanCurrent[PLATFORM_MAX_PATH];
	char sCleanReplay[PLATFORM_MAX_PATH];
	CleanMapName(sCurrentMap, sCleanCurrent, sizeof(sCleanCurrent));
	CleanMapName(header.sMap, sCleanReplay, sizeof(sCleanReplay));

	bool bMapMatches = StrEqual(sCleanCurrent, sCleanReplay, false);

	Menu detailMenu = new Menu(MenuHandler_ReplayDetail);

	char sTitle[512];
	FormatEx(sTitle, sizeof(sTitle),
		"Replay Details\n" ...
		"File Name: %s\n" ...
		"Replay Map: %s\n" ...
		"Style: %s\n" ...
		"Track: %s\n" ...
		"Time: %s\n" ...
		"Player: %s\n" ...
		"Tickrate: %.1f\n",
		sFileName,
		header.sMap,
		sStyleBuffer,
		sTrackName,
		sFormattedTime,
		sPlayer,
		(header.fTickrate > 0.0) ? header.fTickrate : (1.0 / GetTickInterval())
	);
	detailMenu.SetTitle(sTitle);

	if (bMapMatches)
	{
		detailMenu.AddItem(sFileName, "Play Replay", ITEMDRAW_DEFAULT);
	}
	else
	{
		char sDisabledText[128];
		FormatEx(sDisabledText, sizeof(sDisabledText), "Play Replay (Only on %s)", sCleanReplay);
		detailMenu.AddItem(sFileName, sDisabledText, ITEMDRAW_DISABLED);
	}

	detailMenu.ExitBackButton = true;
	detailMenu.ExitButton = true;
	detailMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ReplayDetail(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		int client = param1;
		char sInfo[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if (param2 == 0)
		{
			char sCustomFolder[PLATFORM_MAX_PATH];
			GetCustomReplayFolder(sCustomFolder);

			char sFullPath[PLATFORM_MAX_PATH];
			FormatEx(sFullPath, sizeof(sFullPath), "%s/%s", sCustomFolder, sInfo);

			replay_header_t header;
			File fFile = ReadReplayHeader(sFullPath, header);
			if (fFile != null)
			{
				delete fFile;

				char sCurrentMap[PLATFORM_MAX_PATH];
				GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));

				char sCleanCurrent[PLATFORM_MAX_PATH];
				char sCleanReplay[PLATFORM_MAX_PATH];
				CleanMapName(sCurrentMap, sCleanCurrent, sizeof(sCleanCurrent));
				CleanMapName(header.sMap, sCleanReplay, sizeof(sCleanReplay));

				if (!StrEqual(sCleanCurrent, sCleanReplay, false))
				{
					Shavit_PrintToChat(client, "This replay can only be played on %s! (Current map: %s)", header.sMap, sCleanCurrent);
					return 0;
				}

				int bot = Shavit_StartReplayFromFile(header.iStyle, header.iTrack, -1.0, client, -1, Replay_Automatic, true, sFullPath);
				if (bot > 0)
				{
					Shavit_PrintToChat(client, "Successfully started custom replay '%s'!", sInfo);
				}
				else
				{
					Shavit_PrintToChat(client, "Replay could not be played. Replay bot could not be created (bot limit may have been reached).");
				}
			}
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenCustomReplayMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}