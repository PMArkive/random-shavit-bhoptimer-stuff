// Add this to your ezscroll style config:
//    "ezscroll" "1"

#include <sourcemod>
#include <sdktools_trace>
#include <shavit/core>

#pragma semicolon 1
#pragma newdecls required

int              gI_PreviousGroundEntity[MAXPLAYERS + 1];
int              gI_PreviousOldButtons[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name        = "ez-scroll",
    author      = "rumour",
    description = "",
    version     = SOURCEMOD_VERSION,
    url         = ""

};

stock bool TRFilter_NoPlayers(int entity, int mask, any data)
{
    return !(1 <= entity <= MaxClients);
}

stock float GetDistanceToGround(int client)
{
    float start[3];
    GetEntPropVector(client, Prop_Data, "m_vecOrigin", start);
    float end[3];

    float mins[3], maxs[3];
    GetEntPropVector(client, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(client, Prop_Send, "m_vecMaxs", maxs);

    end = start;
    end[2] -= 2.0;
    TR_TraceHullFilter(start, end, mins, maxs, MASK_ALL, TRFilter_NoPlayers, client);

    if (TR_DidHit())
    {
        TR_GetEndPosition(end);
        return start[2] - end[2];
    }

    return 0.0;
}

//public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style, int mouse[2])
{
    if (!Shavit_GetStyleSettingBool(style, "ezscroll"))
    {
        return Plugin_Continue;
    }

    int m_hGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
    int m_OldButtons    = GetEntProp(client, Prop_Data, "m_nOldButtons");

    if (gI_PreviousGroundEntity[client] == -1 && m_hGroundEntity != -1 && m_OldButtons & IN_JUMP && !(gI_PreviousOldButtons[client] & IN_JUMP))    // && GetDistanceToGround() > 0.0 for 2 ticks only on elevated landings
    {
        SetEntProp(client, Prop_Data, "m_nOldButtons", (m_OldButtons &= ~IN_JUMP));

        buttons |= IN_JUMP;
    }

    gI_PreviousGroundEntity[client] = m_hGroundEntity;
    gI_PreviousOldButtons[client]   = m_OldButtons;
    return Plugin_Changed;
}
