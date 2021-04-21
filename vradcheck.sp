#include "sourcemod"
#define SNAME		"[VRAD Cheker] "
#define PATH_MAPS	"maps/"

//(LUMP POS * INT SIZE * INTS IN LUMP HEADER) + 2 INT HEADER
#define LUMP_LIGHTING		136 	//(8 * 4 * 4) + 8
#define LUMP_LIGHTING_HDR	856 	//(53 * 4 * 4) + 8

#define DEBUG	0

public Plugin myinfo = 
{
	name = "VRAD Checker",
	author = "GAMMA CASE",
	description = "Checks VRAD light parameter used as map compile option.",
	version = "0.0.1",
	url = "https://steamcommunity.com/id/_GAMMACASE_/"
}

char g_sPaths[][PLATFORM_MAX_PATH] = {"vradcheck_hdr.txt", 
									"vradcheck_ldr.txt", 
									"vradcheck_both.txt", 
									"vradcheck_other.txt"};

enum VRADParam
{
	VRAD_HDR = 0,
	VRAD_LDR = 1,
	VRAD_BOTH,
	VRAD_Other,
	VRAD_LAST
}

public void OnPluginStart()
{
	RegAdminCmd("sm_vradcheck", SM_VRADCheck, ADMFLAG_ROOT, "Starts VRAD check.");
}

public Action SM_VRADCheck(int client, int args)
{
	DirectoryListing dir = OpenDirectory(PATH_MAPS, true);
	
	if(!dir)
	{
		ReplyToCommand(client, SNAME..."Folder \"%s\" was not found.", PATH_MAPS);
		return Plugin_Handled;
	}
	
	char file[PLATFORM_MAX_PATH], path[PLATFORM_MAX_PATH];
	FileType type;
	File map;
	bool ldr, hdr;
	
	StringMap maps = new StringMap();
	
	while(dir.GetNext(file, sizeof(file), type))
	{
		if(type != FileType_File)
			continue;
		
		if(StrEqual(file[FindCharInString(file, '.', true) + 1], "bsp", false))
		{
			Format(path, sizeof(path), PATH_MAPS..."%s", file);
			map = OpenFile(path, "rb", true);
			
			if(!map)
			{
				ReplyToCommand(client, SNAME..."Can't open \"%s\" for reading.", path);
				continue;
			}
			
			ldr = ProcessBSPLightLumps(map, LUMP_LIGHTING + 4) > 0;
			hdr = ProcessBSPLightLumps(map, LUMP_LIGHTING_HDR + 4) > 0;
			
			if(ldr && hdr)
				maps.SetValue(file, VRAD_BOTH);
			else if(hdr)
				maps.SetValue(file, VRAD_HDR);
			else if(ldr)
				maps.SetValue(file, VRAD_LDR);
			else
			{
				ReplyToCommand(client, SNAME..."Found map without light(?), or can't detect VRAD param. (Map: \"%s\")", file)
				maps.SetValue(file, VRAD_Other);
			}
			
			delete map;
		}
	}
	
	OutputMaps(client, maps)
	
	delete maps;
	delete dir;
	
	return Plugin_Handled;
}

int ProcessBSPLightLumps(File map, int pos)
{
	if(!map.Seek(pos, SEEK_SET))
		return 0;
	
	int data;
	if(!map.ReadInt32(data))
		return 0;
	
	return data;
}

void OutputMaps(int client, StringMap maps)
{
	StringMapSnapshot snap = maps.Snapshot();
	
	File outfiles[VRAD_LAST];
	
	for(int i = 0; i < view_as<int>(VRAD_LAST); i++)
	{
		outfiles[i] = OpenFile(g_sPaths[i], "w", true);
		if(!outfiles[i])
		{
			ReplyToCommand(client, SNAME..."Can't create/open output file \"%s\" for writing.", g_sPaths[i]);
			return;
		}
	}
	
	char map[PLATFORM_MAX_PATH];
	int count[VRAD_LAST];
	VRADParam type;
	
	for(int i = 0; i < snap.Length; i++)
	{
		snap.GetKey(i, map, sizeof(map))
		maps.GetValue(map, type);
		
		outfiles[type].WriteLine(map);
		count[type]++;
	}
	
	ReplyToCommand(client, SNAME..."All maps have been successfully written to each specific file.\n"...
		"Total maps: HDR: %i, LDR: %i, BOTH: %i, Other: %i", count[VRAD_HDR], count[VRAD_LDR], count[VRAD_BOTH], count[VRAD_Other]);
	
	for(int i = 0; i < view_as<int>(VRAD_LAST); i++)
		delete outfiles[i];
}