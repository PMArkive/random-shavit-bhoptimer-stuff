/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Sample Extension
 * Copyright (C) 2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#include "extension.h"

/**
 * @file extension.cpp
 * @brief Implement extension code here.
 */

TraceRayTrigger g_Sample;		/**< Global singleton for extension's main interface */

//#include "G:\source-sdk-2013-master\sp\src\public\IHandleEntity.h"
//#include "G:\source-sdk-2013-master\sp\src\public\engine\IEngineTrace.h"
//#include "G:\source-sdk-2013-master\sp\src\public\eiface.h"

#include "E:\hl2sdk-csgo\public\IHandleEntity.h"
#include "E:\hl2sdk-csgo\public\engine\IEngineTrace.h"
#include "E:\hl2sdk-csgo\public\eiface.h"

IEngineTrace *enginetrace = NULL;

CBaseEntity* GetEntityFromHandle(IHandleEntity* pBaseEntity)
{
	//unsigned long ulEnt = *(unsigned long*)((DWORD)pBaseEntity);
	//ulEnt &= 0xFFF;
	//CBaseEntity *pEnt = (CBaseEntity*)g_pEntList->GetClientEntity(ulEnt);
	//edict_t *pEdict = engine->PEntityOfEntIndex(ulEnt);
	edict_t *pEdict = gamehelpers->GetHandleEntity(*(CBaseHandle*)pBaseEntity);
	if (pEdict)
		return pEdict->GetUnknown()->GetBaseEntity();
	else
		return 0x0;
}

CBaseEntity *hitent = 0x0;

class CTriggerTraceEnum1 : public IEntityEnumerator
{
public:
	CTriggerTraceEnum1(Ray_t *pRay, int contentsMask) :
		m_ContentsMask(contentsMask), m_pRay(pRay)
	{
	}

	virtual bool EnumEntity(IHandleEntity *pHandleEntity)
	{
		trace_t tr;
		enginetrace->ClipRayToEntity(*m_pRay, m_ContentsMask, pHandleEntity, &tr);

		if (tr.DidHit()) //||tr.fraction < 1.0f)
		{
			hitent = tr.m_pEnt;
			//Msg("hitent = %x\n", hitent);
			return false;
		}

		return true;
	}

private:
	int m_ContentsMask;
	Ray_t *m_pRay;
};

/*void TraceTriggers(const Vector& start, const Vector& end)
{
	Ray_t ray;
	ray.Init(start, end);

	CTriggerTraceEnum1 triggerTraceEnum(&ray, MASK_ALL);
	enginetrace->EnumerateEntities(ray, true, &triggerTraceEnum);
}*/


cell_t TraceTriggers(IPluginContext *pContext, const cell_t *params)
{
	cell_t *addr1, *addr2;

	//pContext->LocalToPhysAddr(params[1], &client);
	cell_t client_index = params[1];
	pContext->LocalToPhysAddr(params[2], &addr1);
	pContext->LocalToPhysAddr(params[3], &addr2);

	Vector source = { sp_ctof(addr1[0]), sp_ctof(addr1[1]), sp_ctof(addr1[2]) };
	Vector dest = { sp_ctof(addr2[0]), sp_ctof(addr2[1]), sp_ctof(addr2[2]) };
	//Msg("%f, %f, %f | %f, %f, %f\n", source.x, source.y, source.z, dest.x, dest.y, dest.z);
	//IGamePlayer *pPlayer = playerhelpers->GetGamePlayer(client_index);

	hitent = 0x0;

	Ray_t ray;
	ray.Init(source, dest);

	CTriggerTraceEnum1 triggerTraceEnum(&ray, MASK_ALL);
	enginetrace->EnumerateEntities(ray, true, &triggerTraceEnum);

	if (hitent)
	{
		//Msg("hitent = %x\n", hitent);
		return gamehelpers->EntityToBCompatRef(hitent);
	}
	else
		return 0x0;
	

	//return sp_ftoc(source[0] + dest[0]);
}

const sp_nativeinfo_t MyNatives[] =
{
	{ "TraceTriggers", TraceTriggers },
	{ NULL, NULL },
};

void TraceRayTrigger::SDK_OnAllLoaded()
{
	CreateInterfaceFn EngineFactory = Sys_GetFactory("engine.dll");
	enginetrace = (IEngineTrace*)EngineFactory(INTERFACEVERSION_ENGINETRACE_SERVER, 0);

	sharesys->AddNatives(myself, MyNatives);
}

SMEXT_LINK(&g_Sample);
