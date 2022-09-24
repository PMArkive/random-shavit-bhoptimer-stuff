#include <sourcemod>

ConVar convar;

public void OnPluginStart()
{
    convar = CreateConVar("test_intvalue", "35781985");

    char value[16];
    convar.GetString(value, sizeof(value));

    PrintToServer("IntValue: %d | StringToInt: %d", convar.IntValue, StringToInt(value));
}