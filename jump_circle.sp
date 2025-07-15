#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MAX_PLAYERS 65
#define SPRITE_BEAM "materials/sprites/laser.vmt"
#define BEAM_LIFE 1.0

bool g_bWasOnGround[MAX_PLAYERS];
bool g_bJumpedLastFrame[MAX_PLAYERS];
bool g_bEnabled[MAXPLAYERS] = {false, ...};

int g_iSprite;

public Plugin myinfo = {
    name = "Jump Circle",
    author = "normalamron",
    description = "",
    version = ""
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_jumpcircle", Command_ToggleJumpCircle);
}

public void OnMapStart()
{
    g_iSprite = PrecacheModel(SPRITE_BEAM, true);
}

public Action Command_ToggleJumpCircle(int client, int args)
{
    if (!IsClientInGame(client))
        return Plugin_Handled;

    g_bEnabled[client] = !g_bEnabled[client];
    PrintToChat(client, "[JumpCircle] %s", g_bEnabled[client] ? "On" : "Off");
    return Plugin_Handled;
}

public Action OnPlayerRunCmd()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || !IsPlayerAlive(client))
            continue;

        bool onGround = (GetEntityFlags(client) & FL_ONGROUND) != 0;
        int buttons = GetClientButtons(client);

        if (g_bWasOnGround[client] && !onGround && !(g_bJumpedLastFrame[client]) && (buttons & IN_JUMP))
        {
            if (!g_bJumpedLastFrame[client] && g_bEnabled[client])
            {
                DrawJumpCircle(client);
                g_bJumpedLastFrame[client] = true;
            }
        }
        else if (onGround)
        {
            g_bJumpedLastFrame[client] = false;
        }

        g_bWasOnGround[client] = onGround;
    }
}

void DrawJumpCircle(int client)
{
    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

    float speedXY = SquareRoot(velocity[0]*velocity[0] + velocity[1]*velocity[1]);
    float speedZ = velocity[2];
    float gravity = 800.0;

    float airtime = 2.0 * FloatAbs(speedZ) / gravity;
    float maxRange = speedXY * (2.0 * airtime);

    float origin[3];
    GetClientAbsOrigin(client, origin);

    int color[4] = {255, 0, 0, 255};
    TE_SetupBeamRingPoint(origin, maxRange-0.1, maxRange, g_iSprite, 0, 0, 0, BEAM_LIFE, 5.0, 0.0, color, 0, 0);    
    TE_SendToClient(client);
}