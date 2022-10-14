
#define MY_SERVER_NAME "US1"

Database gH_SQL = null;
int gI_LastMessageID = -1;
bool gB_Protobuf = false;
UserMsg gI_SayText2 = INVALID_MESSAGE_ID;

public void OnPluginStart()
{
	gB_Protobuf = (GetUserMessageType() == UM_Protobuf);
	gI_SayText2 = GetUserMessageId("SayText2");

	char error[256];
	if (!(gH_SQL = SQL_Connect("globalchat", true, error, sizeof(error))))
	{
		SetFailState("Failed to connect to db. '%s'", error);
	}

	gH_SQL.Query(Query_CreateTables, "CREATE TABLE IF NOT EXISTS `messages` (`id` INT NOT NULL AUTO_INCREMENT, `server` CHAR(20) NOT NULL, `auth` INT NOT NULL, `msgdatetime` DATETIME NOT NULL, `playername` CHAR(32) NOT NULL, `message` VARCHAR(255) NOT NULL, PRIMARY KEY (`id`), INDEX `serveridx` (`server`));");
}

void Query_CreateTables(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		SetFailState("Failed to create table `messages`. Error = '%s'", error);
	}

	gH_SQL.Query(Query_GetLatest, "SELECT MAX(id) FROM messages;");
}

void Query_GetLatest(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null || !results.FetchRow())
	{
		SetFailState("Failed to get latest message id. Error = '%s'", error);
	}

	gI_LastMessageID = results.FetchInt(0);
	CreateTimer(0.75, Timer_GetMessages, 0, TIMER_REPEAT);
}

void Query_GetMessages(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Failed to get latest messages. Error = '%s'", error);
		return;
	}
	if (!results.FetchRow()) return;

	int numclients = 0;
	int clients[MAXPLAYERS];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (IsClientSourceTV(i) || !IsFakeClient(i)))
			clients[numclients++] = i;
	}
	if (!numclients) return;

	do
	{
		int id = results.FetchInt(0);
		if (id > gI_LastMessageID) gI_LastMessageID = id;
		char server[21];
		results.FetchString(1, server, sizeof(server));
		char playername[33];
		results.FetchString(2, playername, sizeof(playername));
		char message[256];
		results.FetchString(3, message, sizeof(message));
		PrintNerds(clients, numclients, server, playername, message);
	}
	while (results.FetchRow());
}

void PrintNerds(int[] clients, int numclients, const char[] server, const char[] playername, const char[] message)
{
	char buffer[256];
	FormatEx(buffer, (gB_Protobuf ? sizeof(buffer) : 253),
		"%s\x01%s \x0789CFF0%s> \x07FFFFFF%s",
		(gB_Protobuf ? " ":""), // space before message needed show colors in cs:go
		server,
		playername,
		message
	);
	PrintToServer("%s %s> %s", server, playername, message);
	
	Handle saytext2 = StartMessageEx(gI_SayText2, clients, numclients, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

	if (gB_Protobuf)
	{
		Protobuf pbmsg = view_as<Protobuf>(saytext2);
		pbmsg.SetInt("ent_idx", 0);
		pbmsg.SetBool("chat", true);
		pbmsg.SetString("msg_name", buffer);
		// needed to not crash
		for (int i = 0; i < 4; i++)
			pbmsg.AddString("params", "");
	}
	else
	{
		BfWrite bfmsg = view_as<BfWrite>(saytext2);
		bfmsg.WriteByte(0);
		bfmsg.WriteByte(1);
		bfmsg.WriteString(buffer);
	}

	EndMessage();
}

Action Timer_GetMessages(Handle timer)
{
	char query[512];
	FormatEx(query, sizeof(query), "SELECT id, server, playername, message FROM messages WHERE id > %d ;", gI_LastMessageID, MY_SERVER_NAME); // AND server != '%s'
	gH_SQL.Query(Query_GetMessages, query);
	return Plugin_Continue;
}

void Query_InsertMessage(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("failed to insert global chat message... ('%s')", error);
	}
}

public void OnClientSayCommand_Post(int client, const char[] cmd, const char[] unescaped_msg)
{
	if (client == 0 || IsChatTrigger()) return;
	int auth = GetSteamAccountID(client);
	if (auth == 0) return;

	char playername[32 * 2 + 1];
	SanerGetClientName(client, playername);
	gH_SQL.Escape(playername, playername, sizeof(playername));
	char msg[513];
	gH_SQL.Escape(unescaped_msg, msg, sizeof(msg));

	char query[2048];
	FormatEx(query, sizeof(query), "INSERT INTO messages (auth, server, msgdatetime, playername, message) VALUES (%d, '%s', NOW(), '%s', '%s');", auth, MY_SERVER_NAME, playername, msg);
	gH_SQL.Query(Query_InsertMessage, query);
}

// Steam names are `char[32+1];`. Source engine names are `char[32];` (MAX_PLAYER_NAME_LENGTH).
// This means Source engine names can end up with an invalid unicode sequence at the end.
// This will remove the unicode codepoint if necessary.
/*
	Sourcemod 1.11 will strip the invalid codepoint internally (some relevant links below) but it'd still be nice to just retrive the client's `name` convar so we get the full thing or maybe even grab it from whatever SteamGameServer api stuff makes it available if possible.
	https://github.com/alliedmodders/sourcemod/pull/545
	https://github.com/alliedmodders/sourcemod/issues/1315
	https://github.com/alliedmodders/sourcemod/pull/1544
*/
stock void SanerGetClientName(int client, char[] name)
{
	static EngineVersion ev = Engine_Unknown;

	if (ev == Engine_Unknown)
	{
		ev = GetEngineVersion();
	}

	GetClientName(client, name, 32+1);

	// CSGO doesn't have this problem because `MAX_PLAYER_NAME_LENGTH` is 128...
	if (ev == Engine_CSGO)
	{
		return;
	}

	int len = strlen(name);

	if (len == 31)
	{
		for (int i = 0; i < 3; i++)
		{
			static int masks[3] = {0xC0, 0xE0, 0xF0};

			if ((name[len-i-1] & masks[i]) >= masks[i])
			{
				name[len-i-1] = 0;
				return;
			}
		}
	}
}
