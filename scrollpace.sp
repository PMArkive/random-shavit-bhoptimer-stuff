
#include <clientprefs>

#define POINTS_TO_TRACK 35
#define LAST_POINT (POINTS_TO_TRACK-1)

bool gB_On[MAXPLAYERS+1];
bool gB_PlusJump[MAXPLAYERS+1][POINTS_TO_TRACK];
bool gB_WasOnGround[MAXPLAYERS+1][POINTS_TO_TRACK];
int gI_LastTicked[MAXPLAYERS+1];
Handle gH_Sync;
Cookie gH_Cookie;

public void OnPluginStart()
{
	gH_Cookie = new Cookie("scrollpace", "Fuck you", CookieAccess_Private);
	gH_Sync = CreateHudSynchronizer();
	RegConsoleCmd("sm_scrollpace", Command_ScrollPace, "FUCK YOU WHOEVER READS THIS");

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i)) {
			OnClientConnected(i);
			if (AreClientCookiesCached(i)) {
				OnClientCookiesCached(i);
			}
		}
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && gB_On[i]) {
			// blank with short time so it goes away (like if you're reloading the plugin to test... like me...)
			SetHudTextParams(-1.0, 0.15, 0.1, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
			ShowSyncHudText(i, gH_Sync, "\t");
		}
	}
}

public void OnClientConnected(int client)
{
	gB_On[client] = false;
	gI_LastTicked[client] = 0;
}

public void OnClientCookiesCached(int client)
{
	char buf[16];
	gH_Cookie.Get(client, buf, sizeof(buf));
	gB_On[client] = StringToInt(buf) == 1;
}

Action Command_ScrollPace(int client, int argc)
{
	if (!IsClientAuthorized(client))
		return Plugin_Handled;
	gB_On[client] = !gB_On[client];
	gH_Cookie.Set(client, gB_On[client] ? "1" : "0");
	return Plugin_Handled;
}

void ShiftDown(int client)
{
	for (int i = 0; i < LAST_POINT; i++) {
		gB_PlusJump[client][i] = gB_PlusJump[client][i+1];
		gB_WasOnGround[client][i] = gB_WasOnGround[client][i+1];
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsFakeClient(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	int flags = GetEntityFlags(client);
	int oldbuttons = GetEntProp(client, Prop_Data, "m_nOldButtons");

	bool onground = !!(flags & FL_ONGROUND);
	bool plusjump = !!(buttons & IN_JUMP);
	bool oldplusjump = !!(oldbuttons & IN_JUMP);

	if (!(onground || oldplusjump || plusjump)) {
#if 1 // does this even work lol?
		if ((tickcount-gI_LastTicked[client] <= 3)) {
			ShiftDown(client);
			gB_PlusJump[client][LAST_POINT] = false;
			gB_WasOnGround[client][LAST_POINT] = false;
		}
#endif
		return Plugin_Continue;
	}

	ShiftDown(client);

	gB_PlusJump[client][LAST_POINT] = plusjump;
	gB_WasOnGround[client][LAST_POINT] = onground;
	gI_LastTicked[client] = tickcount;

	if (gB_On[client])
		Printer(client);

	return Plugin_Continue;
}

void Printer(int client)
{
	char buf[512];
	for (int i = 0; i < POINTS_TO_TRACK; i++) {
		StrCat(buf, sizeof(buf), gB_PlusJump[client][i] ? "Ｊ" : "　");
	}
	StrCat(buf, sizeof(buf), "\n");
	for (int i = 0; i < POINTS_TO_TRACK; i++) {
		StrCat(buf, sizeof(buf), gB_WasOnGround[client][i] ? "ｇ" : "　");
	}

	SetHudTextParams(-1.0, 0.15, 10.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, gH_Sync, buf);
}

