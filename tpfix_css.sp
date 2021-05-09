#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "TPFix",
	author = "rio",
	description = "Ensure all teleport destinations are a minimum distance off the ground so players dont get stopped",
	version = "1.0.2",
	url = ""
};

#define BOTTOM_PAD 2.0
#define TOP_PAD	   0.01

bool g_bLate;
ArrayList teleportTargets;
ArrayList fixedEntities;

char currentmap[64];

float MINS[3] = { -16.0, -16.0, -BOTTOM_PAD };
float MAXS[3] = {  16.0,  16.0,  TOP_PAD };
float HEIGHT = 62.0; // height of the player's bounding box while uncrouched

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
   g_bLate = late;
   return APLRes_Success;
}

public void OnPluginStart()
{
	teleportTargets = new ArrayList(64);
	fixedEntities = new ArrayList();

	if (g_bLate)
	{
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, "trigger_teleport")) != -1) CheckTeleport(entity);
	}
}

public void OnMapStart()
{
	teleportTargets.Clear();
	fixedEntities.Clear();

	GetCurrentMap(currentmap, sizeof(currentmap));
}

public void OnTeleportCreated_Delayed(int entity)
{
	if (IsValidEntity(entity)) CheckTeleport(entity);
}

public void OnEntityCreated_Delayed(int entity)
{
	if (IsValidEntity(entity))
	{
		char name[64];
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
		if (teleportTargets.FindString(name) != -1)	CheckDestination(entity);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	// delay entity checking so datamaps can be initialized
	if (StrEqual(classname, "trigger_teleport")) RequestFrame(OnTeleportCreated_Delayed, entity);
	RequestFrame(OnEntityCreated_Delayed, entity);
}

public bool PlayerFilter(int entity, int mask)
{
	return !(0 < entity <= MaxClients);
}

void CheckTeleport(int teleportEnt)
{
	char target[64], landmark[64];
	if (GetEntPropString(teleportEnt, Prop_Data, "m_target", target, sizeof(target)) == 0) return;
	if (target[0] == '\0') return;

	// ignore landmarked teleporters
	if (GetEntPropString(teleportEnt, Prop_Data, "m_iLandmark", landmark, sizeof(landmark)) != 0) return;

	char target2[64];
	for (int targetEnt = 1; targetEnt <= 2048; targetEnt++)
	{
		if (!IsValidEntity(targetEnt)) continue;
		if (GetEntPropString(targetEnt, Prop_Data, "m_iName", target2, sizeof(target2)) == 0) continue;
		if (target2[0] == '\0') continue;
		if (StrEqual(target2, target)) CheckDestination(targetEnt);
	}

	// store the teleport target name so we can check entities that haven't loaded at this point when they do load
	teleportTargets.PushString(target);
}

void CheckDestination(int targetEnt)
{
	int ref = EntIndexToEntRef(targetEnt);
	if (fixedEntities.FindValue(ref) != -1) return;
	fixedEntities.Push(ref);

	// if a teleporter is the target of another teleporter, the mapper probably messed up
	// there isn't an easy way to know if it really was a mistake though, so just dont move it
	char classname[128];
	GetEntPropString(targetEnt, Prop_Data, "m_iClassname", classname, sizeof(classname));
	if (StrEqual(classname, "trigger_teleport")) return;

	char name[64];
	GetEntPropString(targetEnt, Prop_Data, "m_iName", name, sizeof(name));

	if (StrEqual(currentmap, "bhop_kz_ethereal", false) && StrEqual(name, "room", false)) return; // ???
	if (StrEqual(currentmap, "surf_asrown", false) && StrEqual(name, "part2", false)) return; // ???

	float origin[3], to[3], end[3];

	GetEntPropVector(targetEnt, Prop_Send, "m_vecOrigin", origin);

	origin[2] = origin[2] + HEIGHT/2;
	float bottom, top;

	to[0] = origin[0];
	to[1] = origin[1];
	to[2] = origin[2] - HEIGHT/2 - 10;

	TR_TraceHullFilter(origin, to, MINS, MAXS, MASK_PLAYERSOLID_BRUSHONLY, PlayerFilter);

	if (TR_DidHit())
	{
		TR_GetEndPosition(end);
		if (origin[2] - end[2] < HEIGHT/2) bottom = HEIGHT/2 - (origin[2] - end[2]);
	}

	to[0] = origin[0];
	to[1] = origin[1];
	to[2] = origin[2] + HEIGHT/2 + 10;

	TR_TraceHullFilter(origin, to, MINS, MAXS, MASK_PLAYERSOLID_BRUSHONLY, PlayerFilter);

	if (TR_DidHit())
	{
		TR_GetEndPosition(end);
		if (end[2] - origin[2] < HEIGHT/2) top = HEIGHT/2 - (end[2] - origin[2]);
	}

	origin[2] = origin[2] - HEIGHT/2;

	if (top > 0.0 && bottom > 0.0)
	{
		//PrintToServer("[TPFix] Cannot fix teleport destination \"%s\" (%u)", name, ref);
		return;
	}
	else if (top > 0.0)
	{
		//PrintToServer("[TPFix] Adjusting teleport destination \"%s\" (%u) DOWN by %.2f", name, ref, top);
		origin[2] = origin[2] - top;
		TeleportEntity(targetEnt, origin, NULL_VECTOR, NULL_VECTOR);
	}
	else if (bottom > 0.0)
	{
		//PrintToServer("[TPFix] Adjusting teleport destination \"%s\" (%u) UP by %.2f", name, ref, bottom);
		origin[2] = origin[2] + bottom;
		TeleportEntity(targetEnt, origin, NULL_VECTOR, NULL_VECTOR);
	}
}