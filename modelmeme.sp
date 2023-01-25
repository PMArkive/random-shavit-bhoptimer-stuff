#include <sourcemod>
#include <sdktools>

public Plugin myinfo = {
	name = "Model meme",
	author = "pufftwitt",
	version = "1.0.0",
	description = "Meme models you bitch",
	url = "https://github.com/PMArkive/random-shavit-bhoptimer-stuff"
};

/*
char models_ct[][] = {
	"models/player/ct_urban.mdl",
	"models/player/ct_gsg9.mdl",
	"models/player/ct_sas.mdl",
	"models/player/ct_gign.mdl"
};

char models_t[][] = {
	"models/player/t_phoenix.mdl",
	"models/player/t_leet.mdl",
	"models/player/t_arctic.mdl",
	"models/player/t_guerilla.mdl"
};
*/

ArrayList playermodels;

public OnPluginStart()
{
	// TODO: Add command to list models & and a menu to change model...
	playermodels = new ArrayList(128);
	/*
	models/kemono_friends/silver_fox/silver_fox_player_tpose3.mdl
	models/kemono_friends/ezo_red_fox/ezo_red_fox_player_tpose.mdl
	models/kemono_friends/fennec/fennec_player_tpose.mdl
	models/kemono_friends/gray_wolf/gray_wolf_player_tpose.mdl
	models/kemono_friends/oinari_sama/oinari_sama_player_tpose.mdl
	models/kemono_friends/raccoon/raccoon_player_tpose.mdl
	models/kemono_friends/tibetan_sand_fox/tibetan_sand_fox_player_tpose.mdl
	models/paimon_tpose.mdl
	*/
	if (!loadmodels(playermodels, "configs/modelmeme.txt"))
		SetFailState("[MODELMEME] Failed to load configs/modelmeme.txt");

	HookEvent("player_spawn", EventPlayerSpawn, EventHookMode_Post);
}

bool loadmodels(ArrayList models, char[] filename)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, filename);
	File f = OpenFile(path, "r");
	if (!f) return false;
	char buf[128];
	while (f.ReadLine(buf, sizeof(buf)))
	{
		TrimString(buf);
		if (buf[0] == '#' || (buf[0] == '/' && buf[1] == '/'))
			continue;
		if (!FileExists(buf, true, NULL_STRING))
			continue;
		int len = strlen(buf);
		if (len < 5 || !StrEqual(buf[len-4], ".mdl", false))
			continue;
		models.PushString(buf);
		PrecacheModel(buf, true);
	}
	return true;
}

Action EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (playermodels.Length > 0)
	{
		char buf[128];
		playermodels.GetString(GetRandomInt(0, playermodels.Length-1), buf, sizeof(buf));
		SetEntityModel(GetClientOfUserId(event.GetInt("userid")), buf);
	}
	return Plugin_Continue;
}
