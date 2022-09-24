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

Sample g_Sample;		/**< Global singleton for extension's main interface */

SMEXT_LINK(&g_Sample);

#include <isaverestore.h>
#include <variant_t.h>

#define EVENT_FIRE_ALWAYS	-1

class CEventAction
{
public:
	CEventAction(const char *ActionData = NULL);

	string_t m_iTarget; // name of the entity(s) to cause the action in
	string_t m_iTargetInput; // the name of the action to fire
	string_t m_iParameter; // parameter to send, 0 if none
	float m_flDelay; // the number of seconds to wait before firing the action
	int m_nTimesToFire; // The number of times to fire this event, or EVENT_FIRE_ALWAYS.

	int m_iIDStamp;	// unique identifier stamp

	static int s_iNextIDStamp;

	CEventAction *m_pNext;
	/*
	// allocates memory from engine.MPool/g_EntityListPool
	static void *operator new( size_t stAllocateBlock );
	static void *operator new( size_t stAllocateBlock, int nBlockUse, const char *pFileName, int nLine );
	static void operator delete( void *pMem );
	static void operator delete( void *pMem , int nBlockUse, const char *pFileName, int nLine ) { operator delete(pMem); }
	*/
	DECLARE_SIMPLE_DATADESC();

};

class CBaseEntityOutput
{
public:

	~CBaseEntityOutput();

	void ParseEventAction(const char *EventData);
	void AddEventAction(CEventAction *pEventAction);

	int Save(ISave &save);
	int Restore(IRestore &restore, int elementCount);

	int NumberOfElements(void);

	float GetMaxDelay(void);

	fieldtype_t ValueFieldType() { return m_Value.FieldType(); }

	void FireOutput(variant_t Value, CBaseEntity *pActivator, CBaseEntity *pCaller, float fDelay = 0);
	/*
	/// Delete every single action in the action list.
	void DeleteAllElements( void ) ;
	*/
public:
	variant_t m_Value;
	CEventAction *m_ActionList;
	DECLARE_SIMPLE_DATADESC();

	CBaseEntityOutput() {} // this class cannot be created, only it's children

private:
	CBaseEntityOutput(CBaseEntityOutput&); // protect from accidental copying
};

int CBaseEntityOutput::NumberOfElements()
{
	int count = 0;

	if (m_ActionList == NULL)
		return (-1);

	for (CEventAction *ev = m_ActionList; ev != NULL; ev = ev->m_pNext)
		count++;

	return (count);
}

CBaseEntityOutput *GetOutput(int num, const char *sOutput)
{
	//edict_t *pEdict = engine->PEntityOfEntIndex(num);

	CBaseEntity *pEntity = gamehelpers->ReferenceToEntity(gamehelpers->IndexToReference(num));//pEdict->GetUnknown()->GetBaseEntity();

	datamap_t *pMap = gamehelpers->GetDataMap(pEntity);
	if (!pMap)
		return 0;

	typedescription_t *typedesc = gamehelpers->FindInDataMap(pMap, sOutput);

	if (!typedesc)
		return 0;

#if SOURCE_ENGINE < 12
	int dmap = typedesc->fieldOffset[TD_OFFSET_NORMAL];
#else
	int dmap = typedesc->fieldOffset;
#endif

	return (CBaseEntityOutput *)((int)pEntity + (int)dmap);
}

cell_t GetOutputCount(IPluginContext *pContext, const cell_t *params)
{
	char *sOutput;
	pContext->LocalToString(params[2], &sOutput);

	CBaseEntityOutput *pOutput = GetOutput(params[1], sOutput);

	if (!pOutput->m_ActionList)
		return -1;

	return pOutput->NumberOfElements();
}

cell_t GetOutputTarget(IPluginContext *pContext, const cell_t *params)
{
	char *sOutput;
	pContext->LocalToString(params[2], &sOutput);

	CBaseEntityOutput *pOutput = GetOutput(params[1], sOutput);

	if (!pOutput->m_ActionList)
		return false;

	CEventAction *pActionList = pOutput->m_ActionList;
	for (int i = 0; i < params[3]; i++)
		pActionList = pActionList->m_pNext;

	pContext->StringToLocal(params[4], strlen(pActionList->m_iTarget.ToCStr()) + 1, pActionList->m_iTarget.ToCStr());

	return true;
}

cell_t GetOutputTargetInput(IPluginContext *pContext, const cell_t *params)
{
	char *sOutput;
	pContext->LocalToString(params[2], &sOutput);

	CBaseEntityOutput *pOutput = GetOutput(params[1], sOutput);

	if (!pOutput->m_ActionList)
		return false;
	
	CEventAction *pActionList = pOutput->m_ActionList;
	for (int i = 0; i < params[3]; i++)
		pActionList = pActionList->m_pNext;

	pContext->StringToLocal(params[4], strlen(pActionList->m_iTargetInput.ToCStr()) + 1, pActionList->m_iTargetInput.ToCStr());

	return true;
}

cell_t GetOutputParameter(IPluginContext *pContext, const cell_t *params)
{
	char *sOutput;
	pContext->LocalToString(params[2], &sOutput);

	CBaseEntityOutput *pOutput = GetOutput(params[1], sOutput);

	if (!pOutput->m_ActionList)
		return false;

	CEventAction *pActionList = pOutput->m_ActionList;
	for (int i = 0; i < params[3]; i++)
		pActionList = pActionList->m_pNext;

	pContext->StringToLocal(params[4], strlen(pActionList->m_iParameter.ToCStr()) + 1, pActionList->m_iParameter.ToCStr());

	return true;
}

cell_t GetOutputDelay(IPluginContext *pContext, const cell_t *params)
{
	char *sOutput;
	pContext->LocalToString(params[2], &sOutput);

	CBaseEntityOutput *pOutput = GetOutput(params[1], sOutput);

	if (!pOutput->m_ActionList)
		return -1;

	CEventAction *pActionList = pOutput->m_ActionList;
	for (int i = 0; i < params[3]; i++)
		pActionList = pActionList->m_pNext;

	return *(cell_t *)&pActionList->m_flDelay;
}

const sp_nativeinfo_t MyNatives[] =
{
	{ "GetOutputCount", GetOutputCount },
	{ "GetOutputTarget", GetOutputTarget },
	{ "GetOutputTargetInput", GetOutputTargetInput },
	{ "GetOutputParameter", GetOutputParameter },
	{ "GetOutputDelay", GetOutputDelay },
	{ NULL, NULL },
};

void Sample::SDK_OnAllLoaded()
{
	sharesys->AddNatives(myself, MyNatives);
}