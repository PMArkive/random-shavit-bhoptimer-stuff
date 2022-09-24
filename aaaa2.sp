#include <sourcemod>
#include <console>

public void OnPluginStart()
{
	PrintToServer("test");
}

public Action OnClientSayCommand(int client, const char[] command, const char[] argText)
{
	// == 0 means the string starts with these
	if
	(
		StrContains(argText, "!fov") == 0
		||
		StrContains(argText, "/fov") == 0
	)
	{
		char strfov[512];
		strcopy(strfov, sizeof(strfov), argText);
		ReplaceString(strfov, sizeof(strfov), "!fov ", "");
		ReplaceString(strfov, sizeof(strfov), "/fov ", "");

		PrintToServer("strfov %s",strfov);
		int ifov = StringToInt(strfov);

		SetFov(client, ifov);
		PrintToServer("ifov %i",ifov);
	}
	return Plugin_Continue;
}

void SetFov(int client, int ifov)
{
	PrintToServer("test");
	SetEntProp(client, Prop_Send, "m_iFOV", ifov);
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", ifov);
}
