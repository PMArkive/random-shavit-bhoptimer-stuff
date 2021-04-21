#include "sourcemod"
#include "sdktools"
#include "sdkhooks"

#define SNAME "[TriggerGravityFix] "

public Plugin myinfo = 
{
	name = "Trigger_gravity port from CSS",
	author = "GAMMA CASE",
	description = "Makes trigger_gravity to behave like in CSS on CSS maps.",
	version = "1.0.0",
	url = "https://steamcommunity.com/id/_GAMMACASE_/"
};

public void OnMapStart()
{
	char path[PLATFORM_MAX_PATH];
	GetCurrentMap(path, sizeof(path));
	Format(path, sizeof(path), "maps/%s.bsp", path);
	
	if(!FileExists(path))
		return;
	
	File file = OpenFile(path, "rb");
	int ver;
	
	file.Seek(4, SEEK_SET);
	file.ReadInt8(ver);
	
	delete file;
	
	if(ver <= 20)
	{
		int ent = -1;
		while((ent = FindEntityByClassname(ent, "trigger_gravity")) != -1)
		{
			SDKHook(ent, SDKHook_StartTouch, TriggerGravity_StartTouch);
			SDKHook(ent, SDKHook_Touch, TriggerGravity_Touch);
			SDKHook(ent, SDKHook_EndTouch, TriggerGravity_EndTouch);
		}
	}
}

public Action TriggerGravity_StartTouch(int entity, int other)
{
	if(other <= 0 || other > MaxClients || !IsClientInGame(other) || IsFakeClient(other) || !IsValidEntity(entity))
		return Plugin_Continue;
	
	SetEntPropFloat(other, Prop_Data, "m_flGravity", GetEntPropFloat(entity, Prop_Data, "m_flGravity"));
	
	return Plugin_Stop;
}

public Action TriggerGravity_EndTouch(int entity, int other)
{
	return Plugin_Stop;
}

public Action TriggerGravity_Touch(int entity, int other)
{
	return Plugin_Stop;
}

