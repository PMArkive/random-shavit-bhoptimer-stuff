#pragma semicolon 1 
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.0"


ConVar g_cvGravity;
ConVar g_cvMaxVelocity;
new Handle:Hud;



float playerPrevPos[MAXPLAYERS + 1][3];
float playerPrevVel[MAXPLAYERS + 1][3];
float playerRampEnergy[MAXPLAYERS + 1];
float playerRampStartEnergy[MAXPLAYERS + 1];
float playerRampPostStartEnergy[MAXPLAYERS + 1];
bool playerPrevOnRamp[MAXPLAYERS + 1];
bool playerPrevOnRamp2[MAXPLAYERS + 1];





public Plugin:myinfo = 
{ 
	name = "Ramp testing", 
	author = "not_a_zombie", 
	description = "", 
	version = PLUGIN_VERSION, 
	url = "" 
} 

public OnPluginStart()
{
	PrintToChatAll("plugin start");
	Hud = CreateHudSynchronizer();
	g_cvGravity = FindConVar("sv_gravity");
	g_cvMaxVelocity = FindConVar("sv_maxvelocity");
}

public OnMapStart()
{

}
public Action OnPlayerRunCmd(int client)
{
	if(IsClientObserver(client)){
		if(EntRefToEntIndex(GetEntPropEnt(client,Prop_Send,"m_hObserverTarget",0)) > 0){
			PrintEnergyLossTo(EntRefToEntIndex(GetEntPropEnt(client,Prop_Send,"m_hObserverTarget",0)),client);
		}
	}else{
		PrintEnergyLoss(client);
	}
	return Plugin_Continue;
}
public void PrintEnergyLossTo(int client, int clientMessage){
	if(playerPrevOnRamp2[client]){
		SetHudTextParams(0.2, 0.4, 0.9, 255, 255, 255, 255, 0,0,0,0);
		ShowSyncHudText(clientMessage, Hud, "Ramp Entry: %f\nRamp Loss: %f", playerRampStartEnergy[client]-playerRampPostStartEnergy[client], playerRampPostStartEnergy[client]-playerRampEnergy[client]);
	}
}
public void PrintEnergyLoss(int client){
	float pos[3];
	float vel[3];
	float playerMins[3];
	float playerMaxs[3];
	float playerTarget[3];
	float onRamp = false;
	GetClientAbsOrigin(client, pos);
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vel);  
	StartGravity(client,vel);
	ScaleVector(vel, GetTickInterval());
    GetClientMins(client, playerMins);
    GetClientMaxs(client, playerMaxs);
    AddVectors(pos, vel, playerTarget);
	TR_TraceHullFilter(pos, playerTarget, playerMins, playerMaxs, MASK_SOLID_BRUSHONLY,PlayerFilter);
	float nrm[3];
	if (TR_DidHit())
	{
		TR_GetPlaneNormal(null, nrm);
		
	
		if(nrm[2] < 0.7){
			onRamp = true;
		}
	}
	
	
	playerRampEnergy[client] = GetEnergy(client);
	//they're about to get on the ramp
	if(!playerPrevOnRamp[client] && onRamp){
		playerRampStartEnergy[client] = playerRampEnergy[client];
	}
	//they just got on the ramp, post-velocity change
	if(!playerPrevOnRamp2[client] && playerPrevOnRamp[client]){		
		playerRampPostStartEnergy[client] = playerRampEnergy[client];
		//PrintToChatAll("%f %f",playerRampStartEnergy[client],playerRampPostStartEnergy[client]);
	}	
	if(playerPrevOnRamp[client]){
		SetHudTextParams(0.2, 0.4, 0.9, 255, 255, 255, 255, 0,0,0,0);
		ShowSyncHudText(client, Hud, "Ramp Entry: %f\nRamp Loss: %f", playerRampStartEnergy[client]-playerRampPostStartEnergy[client], playerRampPostStartEnergy[client]-playerRampEnergy[client]);
		
	}
	playerPrevPos[client] = pos;
	playerPrevVel[client] = vel;
	playerPrevOnRamp2[client] = playerPrevOnRamp[client];
	playerPrevOnRamp[client] = onRamp;
}

//lifted from rio's rngfix, thx
public bool PlayerFilter(int entity, int mask)
{
	return !(1 <= entity <= MaxClients);
}
void StartGravity(int client, float velocity[3])
{
	float localGravity = GetEntPropFloat(client, Prop_Data, "m_flGravity");
	if (localGravity == 0.0) localGravity = 1.0;

	velocity[2] -= localGravity * g_cvGravity.FloatValue * 0.5 * GetTickInterval() ;

	float baseVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", baseVelocity);
	velocity[2] += baseVelocity[2] * GetTickInterval();

	// baseVelocity[2] would get cleared here but we shouldn't do that since this is just a prediction.

	CheckVelocity(velocity);
}
void CheckVelocity(float velocity[3])
{
	for (int i = 0; i < 3; i++)
	{
		if 		(velocity[i] >  g_cvMaxVelocity.FloatValue) velocity[i] =  g_cvMaxVelocity.FloatValue;
		else if (velocity[i] < -g_cvMaxVelocity.FloatValue) velocity[i] = -g_cvMaxVelocity.FloatValue;
	}
}
//this does not account for teleports or modified gravity
float GetEnergy(int client){
	float playerVelocity[3];
	float playerPosition[3];
	float PlayerfSpeed;
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerVelocity);
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", playerPosition);
	PlayerfSpeed = SquareRoot(playerVelocity[0]*playerVelocity[0] + playerVelocity[1]*playerVelocity[1] + playerVelocity[2]*playerVelocity[2]);
	//the unit of the result is the height at which a player with 0 velocity would have the same energy as the current player
	//this means that the kinetic energy is dependent on gravity
	//PE = mgh
	//KE = 1/2 mv^2
	//1/2 v^2 = gh
	//h = 1/2 v^2/g  # h is the additional height equivalent of the kinetic energy
	return PlayerfSpeed * PlayerfSpeed / g_cvGravity.IntValue / 2 + playerPosition[2];
}