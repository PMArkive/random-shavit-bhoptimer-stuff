// by cherry

#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>

bool g_bClientHideFuncI[MAXPLAYERS +1];

public void OnPluginStart()
{
    RegConsoleCmd("sm_funci", CMD_EntityMenu, "EntityMenu");
}

public Action CMD_EntityMenu(int client, int args )
{
    if(client == 0)
    {
        ReplyToCommand(client, "[SM] This command can only be used in-game.");
        return Plugin_Handled;
    }
    g_bClientHideFuncI[client] = !g_bClientHideFuncI[client];
    ReplyToCommand(client, "[SM] func_illusionary: %s!", g_bClientHideFuncI[client] ? "invisible" : "visible");
    return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if(StrEqual(classname, "func_illusionary"))
    {
        SDKHook(entity, SDKHook_SetTransmit, SetTransmitfunci);
    }
}

public Action SetTransmitfunci(int entity, int client) 
{ 
    if(g_bClientHideFuncI[client]) return Plugin_Handled;
    
    return Plugin_Continue; 
} 
