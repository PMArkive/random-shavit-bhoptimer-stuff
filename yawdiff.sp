#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <shavit>

#define UPDATE_INTERVAL 0.05

chatstrings_t gS_ChatStrings;
bool gB_YawDiff[MAXPLAYERS + 1];
Handle gH_YawTimer[MAXPLAYERS + 1];
Handle gH_HudText[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Yaw Diff",
	author = "normalamron",
	description = "shows the angle between the velocity vector and the eye angle",
	version = "0.1",
	url = "https://github.com/normalamron",
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_yawdiff", Command_YawDiff, "Toggles the yaw difference HUD");
}

public void Shavit_OnChatConfigLoaded()
{
    Shavit_GetChatStringsStruct(gS_ChatStrings);
}

public void OnClientDisconnect(int client)
{
    gB_YawDiff[client] = false;
    if (gH_YawTimer[client] != null)
    {
        CloseHandle(gH_YawTimer[client]);
        gH_YawTimer[client] = null;
    }
    if (gH_HudText[client] != null)
    {
        CloseHandle(gH_HudText[client]);
        gH_HudText[client] = null;
    }
}

public Action Command_YawDiff(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client))
        return Plugin_Handled;

    gB_YawDiff[client] = !gB_YawDiff[client];

    if (gB_YawDiff[client])
    {
        gH_YawTimer[client] = CreateTimer(UPDATE_INTERVAL, Timer_ShowYawDiff, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        gH_HudText[client] = CreateHudSynchronizer();
    }
    else
    {
        if (gH_YawTimer[client] != null)
        {
            CloseHandle(gH_YawTimer[client]);
            gH_YawTimer[client] = null;
        }
        if (gH_HudText[client] != null)
        {
            ClearSyncHud(client, gH_HudText[client]);
        }
    }

    ReplyToCommand(client, "%s %sYaw Diff: %s", gS_ChatStrings.sPrefix, gS_ChatStrings.sText,
        gB_YawDiff[client] ? "\x0700ff00On" : "\x07ff0000Off");

    return Plugin_Handled;
}

public Action Timer_ShowYawDiff(Handle timer, any client)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Continue;

    float vVel[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
    float speed2D = SquareRoot(vVel[0] * vVel[0] + vVel[1] * vVel[1]);

    if (speed2D < 10.0)
        return Plugin_Continue;

    float velocityYaw = RadToDeg(ArcTangent2(vVel[1], vVel[0]));

    float eyeAngles[3];
    GetClientEyeAngles(client, eyeAngles);
    float viewYaw = eyeAngles[1];

    float deltaYaw = -NormalizeAngle(velocityYaw - viewYaw);

    const int maxOffset = 10;
    int barOffset = Clamp(RoundToNearest((deltaYaw / 180.0) * maxOffset), -10, 10);
    int cursorPos = maxOffset + barOffset;

    char sVisual[32] = "";
    for (int i = 0; i < 21; i++)
    {
        sVisual[i] = (i == cursorPos) ? '|' : '-';
    }
    sVisual[21] = '\0';

    char sMessage[128];
    Format(sMessage, sizeof(sMessage), "Yaw Δ: %.1f°\n[%s]", deltaYaw, sVisual);

    int r = RoundToNearest(ClampFloat(FloatAbs(deltaYaw) * 1.5, 0.0, 255.0));
    int g = 255 - r;

    if (gH_HudText[client] != null)
    {
        SetHudTextParams(-1.0, 0.4, UPDATE_INTERVAL + 0.05, r, g, 0, 255, 0, 0.0, 0.0, UPDATE_INTERVAL);
        ShowSyncHudText(client, gH_HudText[client], sMessage);
    }

    return Plugin_Continue;
}

float NormalizeAngle(float angle)
{
    while (angle <= -180.0) angle += 360.0;
    while (angle > 180.0) angle -= 360.0;
    return angle;
}

int Clamp(int val, int min, int max)
{
    if (val < min) return min;
    if (val > max) return max;
    return val;
}

float ClampFloat(float val, float min, float max)
{
    if (val < min) return min;
    if (val > max) return max;
    return val;
}