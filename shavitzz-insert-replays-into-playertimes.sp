
// edit "SlowScriptTimeout"	to "0" in addons/sourcemod/configs/core.cfg

#include <shavit/core>
#include <shavit/replay-file>
#include <shavit/replay-stocks.sp>

Database gH_SQL = null;
//ArrayList gA_Styles[STYLE_LIMIT];

public void OnPluginStart()
{
}

public void Shavit_OnDatabaseLoaded()
{
	gH_SQL = Shavit_GetDatabase();
	
	char replaybotpath[PLATFORM_MAX_PATH];
	if (!Shavit_GetReplayFolderPath_Stock(replaybotpath)) SetFailState("???");

	for (int style = 0; style < STYLE_LIMIT; style++)
	{
		char path[PLATFORM_MAX_PATH];
		FormatEx(path, sizeof(path), "%s/%d", replaybotpath, style);
		DirectoryListing dir = OpenDirectory(path);
		if (dir)
		{
			//gA_Styles[style] = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
			PrintToServer("Getting replay file names for style %d", style);
			char replayname[PLATFORM_MAX_PATH];
			FileType type;
			while (dir.GetNext(replayname, sizeof(replayname), type))
			{
				Format(replayname, sizeof(replayname), "%s/%s", path, replayname);
				insert_into_database(replayname);
				//gA_Styles[style].PushString(replayname);
			}
			delete dir;
		}
	}
}

void insert_into_database(const char[] replaypath)
{
	replay_header_t header;
	File f = ReadReplayHeader(replaypath, header, 0, 0);

	if (!f)
	{
		LogError("Failed with replay '%s'", replaypath);
		return;
	}

	delete f;

	char query[512];
	FormatEx(query, sizeof(query),
		"INSERT IGNORE INTO users (auth, name, ip, lastlogin) VALUES (%d, '%d', 0, 0);",
		header.iSteamID,
		header.iSteamID);
	gH_SQL.Query(SQLCallback_InsertUser, query, 0, DBPrio_High);
	FormatEx(query, sizeof(query),
		"INSERT INTO playertimes \
		(auth, map,  time, jumps, date, style, strafes, sync, points, track, perfs) VALUES \
		(%d,   '%s', %.9f, 1,     1,    %d,    1,       0,    0,      %d,    0);",
		header.iSteamID,
		header.sMap,
		header.fTime,
		header.iStyle,
		header.iTrack);
	gH_SQL.Query(SQLCallback_InsertTime, query, 0, DBPrio_Normal);
}

void SQLCallback_InsertUser(Database db, DBResultSet results, const char[] error, any data)
{
	if (!results || error[0] != '\0')
		LogError("insert user query error '%s'", error);
}

void SQLCallback_InsertTime(Database db, DBResultSet results, const char[] error, any data)
{
	if (!results || error[0] != '\0')
		LogError("insert TIME query error '%s'", error);
}
