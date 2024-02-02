#include <clientprefs>

Cookie gH_Fov = null;

public void OnPluginStart()
{
	gH_Fov = new Cookie("fovhax", "cock & balls", CookieAccess_Protected);
	RegConsoleCmd("sm_fov", Command_Fov, "cock & balls");
}

public Action Command_Fov(int client, int argc)
{
	if (argc > 0)
	{
		char arg[12];
		GetCmdArg(1, arg, sizeof(arg));
		gH_Fov.Set(client, arg);
	}
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client)
{
	char buf[12];
	gH_Fov.Get(client, buf, sizeof(buf));
	int fov = StringToInt(buf);
	fov = fov < 1 ? 90 : fov;
	SetEntProp(client, Prop_Send, "m_iFOV", fov);
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
	return Plugin_Continue;
}
