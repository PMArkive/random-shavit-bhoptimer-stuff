/*
 * Just a quick note. I use the word "size" a lot in this script.
 * What I mean by this, is the avg packet frequency in packet/sec.
 * that's returned by the internal SourceMod native GetClientAvgPackets.
 */
#include <sourcemod>
#pragma semicolon 1
#define PLUGIN_VERSION "1.0.2"
#define ADMIN_FLAG Admin_Generic

// Consider as suspect if current and last packet sizes remain the same within this range
#define MIN_AVG_PACKETS 30.0 // fps_max low boundary
#define MAX_AVG_PACKETS 90.0 // depends on the server's tickrate

// The difference between current and last packet sizes
// Since packet sizes vary, this is used to consider two packet sizes as the same
// if their absolute difference is lower than this value.
#define DIFFERENCE_ACCURACY 3.0

// Per how many seconds should the check for valid packet sizes be called?
#define CHECK_FREQUENCY 1.0 // Default should be 1.0 I guess.

// How many packets that are of the same size need
// to be catched in a row before action is taken?
#define FLAGS_BEFORE_ACTION 10

// Store current and last packet sizes
new Float:g_fAvgPackets[MAXPLAYERS+1];
new Float:g_fLastAvgPackets[MAXPLAYERS+1];

new g_numOfFlaggedPackets[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "Packet Size Checker",
	author = "ici",
	description = "Suspects players who limit their fps to gain bhop advantage in legtt (scroll) style",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/1ci"
};

public OnClientPutInServer(client)
{
	// Reset variables
	g_fLastAvgPackets[client] = 0.0;
	g_numOfFlaggedPackets[client] = 0;
}

public OnMapStart()
{
	// We're going to check for valid packet sizes on every second.
	CreateTimer(CHECK_FREQUENCY, Timer_CheckForValidPacketSizes, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_CheckForValidPacketSizes(Handle:timer)
{
	// Let's loop through all the valid clients
	for (new client = 1; client <= MaxClients; ++client)
	{
		// We don't care if the player is dead or is a bot either.
		if ( !IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client) )
			continue;
		
		// Is the player afk? Let's check this by looking at his velocity.
		// We're doing this because when minimized, the game goes into some hibernating mode I assume
		// and lowers the amount of packets sent to the server or FPS to reduce the impact on the GPU and CPU.
		decl Float:vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		
		if (GetVectorLength(vVel, false) == 0.0)
			continue;
		
		g_fAvgPackets[client] = GetClientAvgPackets(client, NetFlow_Incoming);
		
		// Check if this packet size is within the set boundaries.
		if ( !(MIN_AVG_PACKETS <= g_fAvgPackets[client] <= MAX_AVG_PACKETS) )
			continue;
		
		// Refer to the comment about DIFFERENCE_ACCURACY at the top of the script.
		new Float:fDifferenceBetweenAvgs = FloatAbs( g_fAvgPackets[client] - g_fLastAvgPackets[client] );
		
		if ( fDifferenceBetweenAvgs <= DIFFERENCE_ACCURACY )
			++g_numOfFlaggedPackets[client];
		else
			g_numOfFlaggedPackets[client] = 0;
		
		// Reached the defined limit of consecutive same avg packet sizes. Take action!
		if ( g_numOfFlaggedPackets[client] != 0 && g_numOfFlaggedPackets[client] % FLAGS_BEFORE_ACTION == 0 )
		{
			SayText2Admins("\x01\x0700FF08%N\x07FFFFFF's avg outgoing packet size has been around \x07FFD700%.2f \x07FFFFFFfor \x07FFD700%d \x07FFFFFFtimes (every \x07FFD700%.1f \x07FFFFFFsec/s)", 
				client, g_fAvgPackets[client], g_numOfFlaggedPackets[client], CHECK_FREQUENCY);
		}
		
		g_fLastAvgPackets[client] = g_fAvgPackets[client];
	}
}

// ------------------------------
// A few useful stocks down here.
// ------------------------------
stock bool:isAdmin(client)
{
	new AdminId:admin = GetUserAdmin(client);
	new bool:customFlag = GetAdminFlag(AdminId:admin, AdminFlag:ADMIN_FLAG);
	if (customFlag) return true;
	return false;
}

stock SayText2(to, const String:message[], any:...)
{
	new Handle:hBf = StartMessageOne("SayText2", to);
	if (!hBf) return;
	decl String:buffer[1024];
	VFormat(buffer, sizeof(buffer), message, 3);
	BfWriteByte(hBf, to);
	BfWriteByte(hBf, true);
	BfWriteString(hBf, buffer);
	EndMessage();
}

stock SayText2Admins(const String:message[], any:...)
{
	for (new to = 1; to <= MaxClients; ++to)
	{
		if (!IsClientInGame(to) || IsFakeClient(to) || !isAdmin(to)) continue;
		new Handle:hBf = StartMessageOne("SayText2", to);
		if (!hBf) return;
		decl String:buffer[1024];
		VFormat(buffer, sizeof(buffer), message, 2);
		BfWriteByte(hBf, to);
		BfWriteByte(hBf, true);
		BfWriteString(hBf, buffer);
		EndMessage();
	}
}