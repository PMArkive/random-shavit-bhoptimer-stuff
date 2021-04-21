#include "sourcemod"

#define SNAME "[skyboxfix] "

public Plugin myinfo =
{
	name = "Skybox Fix",
	author = "GAMMA CASE",
	description = "Replaces missing skybox with valid one.",
	version = "1.0.0",
	url = "https://steamcommunity.com/id/_GAMMACASE_/"
};

ConVar gSvSkyname;

public void OnPluginStart()
{
	gSvSkyname = FindConVar("sv_skyname");
	if(!gSvSkyname)
		SetFailState("Failed to find \"sv_skyname\" cvar.");
}

public void OnMapStart()
{
	char buff[PLATFORM_MAX_PATH], buff2[PLATFORM_MAX_PATH];
	gSvSkyname.GetString(buff, sizeof(buff));
	
	Format(buff2, sizeof(buff2), "materials/skybox/%sbk.vmt", buff);
	
	if(!FileExists(buff2, true))
	{
		GetCurrentMap(buff2, sizeof(buff2));
		LogMessage("\"%s\" is using invalid skybox \"%s\", replacing...", buff2, buff);
		gSvSkyname.SetString("dustblank");
	}
}
