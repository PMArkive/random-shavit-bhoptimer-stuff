
#include <sourcemod>
#include <shavit/core>
#include <shavit/checkpoints>

cp_cache_t gA_Cache;
int gI_CacheIdx;

public void OnPluginStart()
{
	RegConsoleCmd("sm_loadcache", Command_Load, "Description");
	RegConsoleCmd("sm_savecache", Command_Save, "Description");
	RegConsoleCmd("sm_printclients", Command_PrintClients, "Description");
}

void DeleteCheckpointCache(cp_cache_t cache)
{
	delete cache.aFrames;
	delete cache.aEvents;
	delete cache.aOutputWaits;
	delete cache.customdata;
}

public Action Command_Load(int client, int args)
{
	bool result = Shavit_LoadCheckpointCache(client, gA_Cache, gI_CacheIdx, sizeof(cp_cache_t));
	PrintToChat(client, "load result = %d", result);
	return Plugin_Handled;
}

public Action Command_Save(int client, int args)
{
	if (args < 2)
	{
		PrintToChat(client, "usage: !savecache target index");
		return Plugin_Handled;
	}

	DeleteCheckpointCache(gA_Cache);

	char arg1[8], arg2[8];
	GetCmdArg(1, arg1, 8);
	GetCmdArg(2, arg2, 8);

	int target = StringToInt(arg1);
	gI_CacheIdx = StringToInt(arg2);

	cp_cache_t emptycache;
	gA_Cache = emptycache;
	Shavit_SaveCheckpointCache(client, target, gA_Cache, gI_CacheIdx, sizeof(cp_cache_t));

	return Plugin_Handled;
}

public Action Command_PrintClients(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			PrintToChat(client, "%d = %N", i, i);
		}
	}

	return Plugin_Handled;
}
