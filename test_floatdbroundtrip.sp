
#include <shavit/core>
#include <profiler>

bool gB_Late;
Database gH_SQL;
int gI_Driver;
char gS_SQLPrefix[32];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;
	return APLRes_Success;
}

stock int strcopy_stock(char[] dest, int destLen, const char[] source)
{
	if (destLen-- < 1) return 0;
	int i = 0;
	for (; i < destLen; i++)
	{
		if ('\0' == (dest[i] = source[i]))
			return i;
	}
	dest[i + 1] = 0;
	return i;
}
#define FIND_PROP(%1) if (!%1) %1 = FindDataMapInfo(entity, "%1"); PrintToServer("%d", %1)
#define GET_INT(%1) FIND_PROP(%1); return GetEntData(entity, %1)
#define GET_ENT(%1) FIND_PROP(%1); return GetEntDataEnt2(entity, %1)
#define SET_INT(%1) FIND_PROP(%1); SetEntData(entity, %1, value, 4, true)
#define SET_ENT(%1) FIND_PROP(%1); SetEntDataEnt2(entity, %1, other, true)

#define FUNCY(%1,%2) \
static int %1; \
stock int Get%2(int entity) { GET_ENT(%1); }

FUNCY(m_hActiveWeapon,ActiveWeapon)

public void OnPluginStart()
{
	char asdf[] = "joq293niousanvunasw9834hj89q234jnasduvina u2352 342 34234 2398 urj89awjf uahu34 ij289 02 ";
	char jkl[100];

	Profiler profiler = new Profiler();
	
	int eflagsOffset = FindDataMapInfo(1, "m_iEFlags");
	
	profiler.Start();
	for (int i = 0; i < 100000; i++)
	{
		GetEntProp(1, Prop_Data, "m_iEFlags");
		//strcopy_stock(jkl, sizeof(jkl), asdf);
	}
	profiler.Stop();
	float stocktime = profiler.Time;
	
	profiler.Start();
	for (int i = 0; i < 100000; i++)
	{
		GetEntData(1, eflagsOffset);
		//strcopy(jkl, sizeof(jkl), asdf);
	}
	profiler.Stop();
	float nativetime = profiler.Time;

	//PrintToServer("active weapon = %d", GetActiveWeapon(1));
	PropFieldType type = view_as<PropFieldType>(0);
	int num_bits = 0;
	int off = FindDataMapInfo(1, "m_iName", type, num_bits);
	PrintToServer("%d %d %d", type, num_bits, off);
#if 0
	int m_hGroundEntity;
	#define FIND_PROP(%1) if (!%1) %1 = FindDataMapInfo(0, "%1")
	#define GET_ENT(%1) \
		FIND_PROP(%1); \
		int test = GetEntDataEnt2(1, %1);
	GET_ENT(m_hGroundEntity);
	PrintToServer("%d", test);
#endif
	PrintToServer("stock = %.7f | native = %.7f", stocktime, nativetime);
	
	PrintToServer("%d %d", FindDataMapInfo(1, "m_vecBaseVelocity"), FindDataMapInfo(0, "m_vecBaseVelocity"));
	PrintToServer("%d %d", GetEntPropEnt(1, Prop_Send, "m_hObserverTarget"), GetEntDataEnt2(1, FindDataMapInfo(1, "m_hObserverTarget")));
	
	if (gB_Late)
	{
		Shavit_OnDatabaseLoaded();
	}
}

public void Shavit_OnDatabaseLoaded()
{
	GetTimerSQLPrefix(gS_SQLPrefix, sizeof(gS_SQLPrefix));
	gH_SQL = Shavit_GetDatabase(gI_Driver);

	char query[1024];
	FormatEx(query, sizeof(query),
		"SELECT FORMAT(points, 9) FROM users WHERE auth = 5555;",
		"test"
	);

	QueryLog(gH_SQL, SQL_MYQUERY, query, 0, DBPrio_High);
	
	FormatEx(query, sizeof(query),
		"SELECT FORMAT(time, 9), exact_time_int FROM playertimes WHERE exact_time_int != 0 LIMIT 10;",
		"test"
	);
	QueryLog(gH_SQL, SQL_Moreres, query, 0, DBPrio_High);
}

public void SQL_Moreres(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("SQL query failed. Reason: %s", error);
		return;
	}
	
	while (results.FetchRow())
	{
		float fsql = results.FetchFloat(0);
		float fint = view_as<float>(results.FetchInt(1));
		char buf[32]; results.FetchString(0, buf, sizeof(buf));
#if 1
		PrintToServer("%d | %012.9f (0x%X) | %012.9f (0x%X) | ",
			fsql == fint,
			fsql, fsql,
			fint, fint,
			0
		);
#else
		float fstr = StringToFloat(buf);
		PrintToServer("%d | %012.9f (0x%X) | %012.9f (0x%X)",
			fsql == fstr,
			fsql, fsql,
			fstr, fstr,
			0
		);
#endif
	}
}

public void SQL_MYQUERY(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("SQL query failed. Reason: %s", error);
		return;
	}

	if (!results.FetchRow())
	{
		LogError("SQL query had no results...");
		return;
	}

	float reprfloat = results.FetchFloat(0);
	char reprstr[20]; results.FetchString(0, reprstr, sizeof(reprstr));
	
	// f = 0.123123101 (0x3DFC27F7) s = '0.123123102' | asdf = 0.123123101 (0x3DFC27F7)
	float asdf = 0.1231231;
	PrintToServer("f = %.9f (0x%X) s = '%s' | asdf = %.9f (0x%X)", reprfloat, reprfloat, reprstr, asdf, asdf);
}
