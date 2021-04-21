#include "sourcemod"
#include "sdkhooks"
#include "sdktools"

#define SNAME "[spritefix] "

public Plugin myinfo = 
{
	name = "Sprite Fix",
	author = "GAMMA CASE",
	description = "Removes sprites that has no actual material.",
	version = "1.0.0",
	url = "https://steamcommunity.com/id/_GAMMACASE_/"
};

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "env_sprite"))
		RequestFrame(EntCreate_PostFrame, EntIndexToEntRef(entity));
}

public void EntCreate_PostFrame(int ref)
{
	int ent = EntRefToEntIndex(ref);
	
	if(IsValidEntity(ent))
	{
		char spritemat[PLATFORM_MAX_PATH], buff[PLATFORM_MAX_PATH];
		
		GetEntPropString(ent, Prop_Data, "m_ModelName", spritemat, sizeof(spritemat));
		int sep = FindCharInString(spritemat, '/');
		if (sep == -1)
			sep = FindCharInString(spritemat, '\\');
		
		if (sep != -1)
		{
			buff = spritemat;
			buff[sep] = '\0';
			if(!StrEqual("materials", buff, false))
				Format(spritemat, sizeof(spritemat), "materials/%s", spritemat);
		}
		else
			Format(spritemat, sizeof(spritemat), "materials/%s", spritemat);
		
		if(!FileExists(spritemat, true))
		{
			RemoveEntity(ent);
			LogMessage(SNAME..."Found env_sprite (%i) with bad material (%s), removing...", ent, spritemat);
		}
	}
}
