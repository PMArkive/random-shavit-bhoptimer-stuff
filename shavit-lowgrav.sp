#include <sourcemod>
#include <sdktools>
#include <shavit>
#include <sdkhooks>
#pragma newdecls required
#pragma semicolon 1
//#include <influx/core>
//#include <influx/stocks_core>


//#define DEBUG_THINK


ConVar g_ConVar_Gravity;
ConVar g_ConVar_GravMult;

float g_flDefaultGravity;
float g_flLowGravGravity;

bool g_bOnLowGrav[MAXPLAYERS + 1];


//public Plugin myinfo =
//{
//	author = INF_AUTHOR,
//	url = INF_URL,
//	name = INF_NAME..." - Style - Low Gravity",
//	description = "",
//	version = INF_VERSION
//};

public void OnPluginStart()
{
	// CONVARS
	if ( (g_ConVar_Gravity = FindConVar( "sv_gravity" )) == null )
	{
		SetFailState("Couldn't find handle for sv_gravity!" );
	}
	
	g_ConVar_Gravity.Flags &= ~(FCVAR_REPLICATED | FCVAR_NOTIFY);
	
	
	g_ConVar_GravMult = CreateConVar( "shavit_style_lowgrav_mult", "0.5", "Gravity multiplier when using low gravity style.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_GravMult.AddChangeHook( E_ConVarChanged_GravMult );
	
	
	g_flDefaultGravity = 800.0;
	g_flLowGravGravity = g_flDefaultGravity * g_ConVar_GravMult.FloatValue;
	
	
	AutoExecConfig( true, "shavit_lowgrav");
	
	
	// CMDS
	//RegConsoleCmd( "sm_lowgravity", Cmd_Style_LowGrav, "Change your style to low gravity." );
	//RegConsoleCmd( "sm_lowgrav", Cmd_Style_LowGrav, "" );
	//RegConsoleCmd( "sm_gravity", Cmd_Style_LowGrav, "" );
	//RegConsoleCmd( "sm_grav", Cmd_Style_LowGrav, "" );
	//RegConsoleCmd( "sm_lowg", Cmd_Style_LowGrav, "" );
	//RegConsoleCmd( "sm_low", Cmd_Style_LowGrav, "" );
	//RegConsoleCmd( "sm_lg", Cmd_Style_LowGrav, "" );
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	char[] sSpecial = new char[128];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sSpecial, 128);

	if(StrContains(sSpecial, "lg", false) != -1)
	{
		g_bOnLowGrav[client] = true;
		UnhookThinks( client );
		
		if ( !Inf_SDKHook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client ) )
		{
			return;
		}
		
		if ( !Inf_SDKHook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client ) )
		{
			UnhookThinks( client );
			return;
		}
		
		Inf_SendConVarValueFloat( client, g_ConVar_Gravity, g_flLowGravGravity );
	}
	else
	{
		UnhookThinks( client );
		
		Inf_SendConVarValueFloat( client, g_ConVar_Gravity, g_flDefaultGravity );
		g_bOnLowGrav[client] = false;
	}

}

public void E_ConVarChanged_GravMult( ConVar convar, const char[] oldValue, const char[] newValue )
{
	g_flLowGravGravity = g_flDefaultGravity * g_ConVar_GravMult.FloatValue;
	
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && g_bOnLowGrav[i] )
		{
			Inf_SendConVarValueFloat( i, g_ConVar_Gravity, g_flLowGravGravity );
		}
	}
}

stock void UnhookThinks( int client )
{
	SDKUnhook( client, SDKHook_PreThinkPost, E_PreThinkPost_Client );
	SDKUnhook( client, SDKHook_PostThinkPost, E_PostThinkPost_Client );
}

public void E_PreThinkPost_Client( int client )
{
#if defined DEBUG_THINK
	PrintToServer( INF_DEBUG_PRE..."PreThinkPost - Low Grav (grav: %.0f | low grav: %.0f)", g_flDefaultGravity, g_flLowGravGravity );
#endif
	
	g_ConVar_Gravity.FloatValue = g_flLowGravGravity;
}

public void E_PostThinkPost_Client( int client )
{
#if defined DEBUG_THINK
	PrintToServer( INF_DEBUG_PRE..."PostThinkPost - Low Grav (grav: %.0f | low grav: %.0f)", g_flDefaultGravity, g_flLowGravGravity );
#endif
	
	g_ConVar_Gravity.FloatValue = g_flDefaultGravity;
}

stock bool Inf_SendConVarValueFloat( int client, Handle convar, float value, const char[] szFormat = "%.0f" )
{
    char szValue[6];
    FormatEx( szValue, sizeof( szValue ), szFormat, value );
    
    if ( !SendConVarValue( client, convar, szValue ) )
    {
        LogError("Couldn't send float convar value (%s)!", szValue );
        return false;
    }
    
    return true;
}

stock bool Inf_SDKHook( int entity, SDKHookType type, SDKHookCB callback )
{
    if ( !SDKHookEx( entity, type, callback ) )
    {
        LogError( "Couldn't hook entity with SDKHook (ent: %i)!", entity );
        return false;
    }
    
    return true;
}