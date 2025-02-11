
#define DO_STRIPPER_SHIT 0

#pragma newdecls required
#pragma semicolon 1

#include <sdktools>

public Plugin myinfo =
{
	name = "kz_bhop_genkai balance fixes",
	author = "rtldg",
	description = "The mapper made the map impossible for some reason?? Just add some small fixes.",
	version = "6.9.42",
	url = "https://github.com/PMArkive/random-shavit-bhoptimer-stuff"
}

#define CRATEMODEL "models/props_junk/wood_crate001a.mdl"
#define MAXCRATES 1000
float gF_CratePos[MAXCRATES][3];
int gI_CrateEnt[MAXCRATES];
bool gB_CrateIsNearby[MAXCRATES];
int gI_MaxCrate;

public void OnPluginEnd()
{
	for (int crate = 0; crate < gI_MaxCrate; ++crate)
	{
		//RemoveEntity(crate);
		AcceptEntityInput(gI_CrateEnt[crate], "Kill");
	}
}

public void OnMapStart()
{
	gI_MaxCrate = 0;

	char mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));

	if (!StrEqual(mapname, "kz_bhop_genkai", false))
		return;
	PrintToServer("we're on kz_bhop_genkai!");

	PrecacheModel(CRATEMODEL);

#if DO_STRIPPER_SHIT
	int spawnpoint = CreateEntityByName("info_player_terrorist");
	DispatchSpawn(spawnpoint);
	float spawnpoint_pos[3] = { -8320.0, 10752.0, 1413.0 };
	TeleportEntity(spawnpoint, spawnpoint_pos);
#endif

	char fixes_path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, fixes_path, sizeof(fixes_path), "data/kz_bhop_genkai_fixes.txt");
	File f = OpenFile(fixes_path, "r");

	char line[128];
	for (int i = 0; f.ReadLine(line, sizeof(line)); ++i)
	{
		TrimString(line);
		if (line[0] == '\0') break;
		char splits[3][30]; // lol
		ExplodeString(line, " ", splits, 3, 30, false);
		gF_CratePos[i][0] = StringToFloat(splits[0]);
		gF_CratePos[i][1] = StringToFloat(splits[1]);
		gF_CratePos[i][2] = StringToFloat(splits[2]);
		gI_MaxCrate += 1;
	}

	PrintToServer("gI_MaxCrate = %d", gI_MaxCrate);

	CreateTimer(0.5, Timer_CheckDistances, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

#if DO_STRIPPER_SHIT
public void OnEntityCreated(int entity, const char[] classname)
{
	if (gI_MaxCrate)
	{
		if (StrEqual(classname, "ambient_generic") || StrEqual(classname, "env_soundscape") || StrEqual(classname, "info_player_counterterrorist"))
			AcceptEntityInput(entity, "Kill");
	}
}
#endif

Action Timer_CheckDistances(Handle timer)
{
	bool empty_nearby[MAXCRATES];
	gB_CrateIsNearby = empty_nearby;

	for (int client = 1, maxc = MaxClients; client <= maxc; ++client)
	{
		if (!IsClientInGame(client)) continue;
		float player_pos[3];
		GetClientAbsOrigin(client, player_pos);

		for (int crate = 0; crate < gI_MaxCrate; ++crate)
		{
			float dist = GetVectorDistance(player_pos, gF_CratePos[crate], false);
			//PrintToConsole(client, "dist = %f", dist);
			if (dist <= 3123.0)
				gB_CrateIsNearby[crate] = true;
		}
	}

	for (int crate = 0; crate < gI_MaxCrate; ++crate)
	{
		if (gB_CrateIsNearby[crate])
		{
			if (!gI_CrateEnt[crate])
			{
				int ent = CreateEntityByName("prop_dynamic_override");
				DispatchKeyValue(ent, "Solid", "6");
				SetEntityModel(ent, CRATEMODEL);
				DispatchSpawn(ent);
				TeleportEntity(ent, gF_CratePos[crate]);
				gI_CrateEnt[crate] = ent;
				PrintToServer("created %d!", gI_CrateEnt[crate]);
			}
		}
		else
		{
			if (gI_CrateEnt[crate])
			{
				PrintToServer("removing %d!", gI_CrateEnt[crate]);
				//AcceptEntityInput(gI_CrateEnt[crate], "Kill");
				RemoveEntity(gI_CrateEnt[crate]);
				gI_CrateEnt[crate] = 0;
			}
		}
	}

	PrintToServer("entity count = %d", GetEntityCount());

	return Plugin_Continue;
}
