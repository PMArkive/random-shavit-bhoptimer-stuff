#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Disable Grenades",
	author = "Nora",
	description = "Disables all grenades (flash, HE, smoke, decoy, molotov) on bhop servers",
	version = "1.0",
	url = ""
};

static const char g_sGrenadeWeapons[][] =
{
	"weapon_flashbang",
	"weapon_hegrenade",
	"weapon_smokegrenade",
	"weapon_decoy",
	"weapon_molotov",
	"weapon_incgrenade"
};

static const char g_sGrenadeProjectiles[][] =
{
	"flashbang_projectile",
	"hegrenade_projectile",
	"smokegrenade_projectile",
	"decoy_projectile",
	"molotov_projectile"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);

	// Strip grenades from all connected players on late load
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			SDKHook(i, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
			StripGrenades(i);
		}
	}

	// Remove existing grenade projectiles from the map
	RemoveGrenadeProjectiles();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}

public void OnMapStart()
{
	RemoveMapGrenades();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	// Remove grenade projectiles as soon as they are created
	for (int i = 0; i < sizeof(g_sGrenadeProjectiles); i++)
	{
		if (StrEqual(classname, g_sGrenadeProjectiles[i]))
		{
			AcceptEntityInput(entity, "Kill");
			return;
		}
	}

	// Remove weapon_* grenade entities placed by the map
	for (int i = 0; i < sizeof(g_sGrenadeWeapons); i++)
	{
		if (StrEqual(classname, g_sGrenadeWeapons[i]))
		{
			AcceptEntityInput(entity, "Kill");
			return;
		}
	}
}

public Action Hook_WeaponCanUse(int client, int weapon)
{
	if (!IsValidEntity(weapon))
		return Plugin_Continue;

	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));

	for (int i = 0; i < sizeof(g_sGrenadeWeapons); i++)
	{
		if (StrEqual(classname, g_sGrenadeWeapons[i]))
		{
			// Block pickup and remove the entity
			AcceptEntityInput(weapon, "Kill");
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		StripGrenades(client);
	}
}

void StripGrenades(int client)
{
	for (int i = 0; i < sizeof(g_sGrenadeWeapons); i++)
	{
		int weapon = -1;
		while ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_GRENADE)) != -1)
		{
			RemovePlayerItem(client, weapon);
			AcceptEntityInput(weapon, "Kill");
		}
	}
}

void RemoveMapGrenades()
{
	for (int i = 0; i < sizeof(g_sGrenadeWeapons); i++)
	{
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, g_sGrenadeWeapons[i])) != -1)
		{
			AcceptEntityInput(entity, "Kill");
		}
	}
}

void RemoveGrenadeProjectiles()
{
	for (int i = 0; i < sizeof(g_sGrenadeProjectiles); i++)
	{
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, g_sGrenadeProjectiles[i])) != -1)
		{
			AcceptEntityInput(entity, "Kill");
		}
	}
}
