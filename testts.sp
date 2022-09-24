// List of Includes
#include <sourcemod>
#include <shavit>

// The code formatting rules we wish to follow
#pragma semicolon 1;
#pragma newdecls required;

public void OnPluginStart()
{
    RegConsoleCmd("sm_testtime", Command_Timescale, "Modifies the timescale to half the normal timescale");
}


public Action Command_Timescale(int client, int args)
{
    Shavit_SetClientTimescale(client, 0.5);

    return Plugin_Handled;
}