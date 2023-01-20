from __future__ import with_statement
from path import path

import es
import popuplib
import playerlib
import re
import langlib
import gamethread
import vecmath
import services
import effectlib
import cfglib
import cmdlib
import random
import usermsg
import string
import keyvalues
import cPickle
import weaponlib
import os
import spe
import time
import datetime
from operator import itemgetter
from math import sqrt
from time import strftime
from spe.tools.player import SPEPlayer
import threading
import psyco
psyco.full()

#hostip = es.ServerVar('hostip')
#if hostip != "1438558512":
#   es.unload("timer")

RE_COLORS = re.compile('\\\\x07([a-fA-F0-9]{6})')


nospam = dict()
nospam2 = dict()
nospam3 = dict()
nospam4 = dict()
wait_time = 3
wait_time2 = 1
wait_time3 = 1
wait_time4 = 1
wait_time5 = 1
 
# Globals
userDict = {}	
dict_teleport = {}
tele_dict = {}
started    = []
startedb   = []
effects    = []
steamprofile = []
mapDicts   = {}
bonusDicts = {}
acDicts    = {}
mapscore   = {}
points     = {}
names      = {}
sortedranks= []
pointschanged = True
playtime   = {}
timers     = {}
players    = {}
speeddict  = {}
speeddictb = {}
styles = {}
strafes = { }
maps = { }
steamids = { }
swac = { }
playerList = None
currentMap = es.ServerVar('eventscripts_currentmap')

TOP_TIME = 0
TOP_TIME_W = 0
TOP_TIME_SW = 0
TOP_TIME_B = 0
TOP_TIME_BW = 0
TOP_TIME_BSW = 0
strafescounter = 0

 
info = es.AddonInfo()
info.author      = "h!gh voltage"
info.name        = "Bhop Timer"
info.basename    = "bhoptimer"
info.version     = "5.0beta"
es.ServerVar('bhop_timer', info.version).makepublic()

text = lambda identifier, options = {}, lang = "en" : "No strings.ini found in ../addons/eventscripts/%(basename)s/%(basename)s.py" % {"basename" : info.basename}

dictPath = os.path.join( es.getAddonPath( info.basename ), "data/data.db" )
if os.path.isfile(dictPath):
    fileStream = open(dictPath, 'r')
    mapDicts   = cPickle.load(fileStream)
    fileStream.close()

bonusPath = os.path.join( es.getAddonPath( info.basename ), "data/bonusdata.db" )
if os.path.isfile(bonusPath):
    fileStream = open(bonusPath, 'r')
    bonusDicts   = cPickle.load(fileStream)
    fileStream.close()
 
scorePath = os.path.join( es.getAddonPath( info.basename ), "data/mapscore.db" )
if os.path.isfile(scorePath):
    fileStream = open(scorePath, 'r')
    mapscore   = cPickle.load(fileStream)
    fileStream.close()
 
pointsPath = os.path.join( es.getAddonPath( info.basename ), "data/points.db" )
if os.path.isfile(pointsPath):
    fileStream = open(pointsPath, 'r')
    points   = cPickle.load(fileStream)
    fileStream.close()

acPath = os.path.join( es.getAddonPath( info.basename ), "data/acdata.db" )
if os.path.isfile(acPath):
    fileStream = open(acPath, 'r')
    acDicts   = cPickle.load(fileStream)
    fileStream.close()

playtimePath = os.path.join( es.getAddonPath( info.basename ), "data/playtime.db" )
if os.path.isfile(playtimePath):
    fileStream = open(playtimePath, 'r')
    playtime   = cPickle.load(fileStream)
    fileStream.close()

langPath = os.path.join(es.getAddonPath(info.basename), "translations/strings.ini")
if os.path.isfile(langPath):
    text = langlib.Strings(langPath)
	
top1_sounds_path = path(__file__).dirname().joinpath('config/top1_sounds.txt')
top2_sounds_path = path(__file__).dirname().joinpath('config/top2_sounds.txt')
   
if services.isRegistered('auth'):
    auth_service = services.use('auth')
    auth_service.registerCapability('climbtimer', auth_service.ADMIN)
    isAuthed = lambda x: auth_service.isUseridAuthorized(x, 'climbtimer')
else:
    isAuthed = lambda x: False
   
def load():
    es.load('bhoptimer/modules')
    if str(currentMap):
        es_map_start({'mapname':str(currentMap)})
    cmdlib.registerServerCommand('stoptimer', stoptimer, "Stop timer")

    cmdlib.registerSayCommand('!stats', statscommandnew, "stats command")
    cmdlib.registerSayCommand('!tpto', teleportcommand, "teleport command")
    cmdlib.registerSayCommand('!bring', bringcommand, "teleport command")
    cmdlib.registerSayCommand('!top', topcommand, "top ranks command")
    cmdlib.registerSayCommand('!topw', topcommandw, "top ranks command")
    cmdlib.registerSayCommand('!topsw', topcommandsw, "top ranks command")
    cmdlib.registerSayCommand('!points', pointscommand, "points command")
    cmdlib.registerSayCommand('!timer', admincommand, "timer admin command")
    cmdlib.registerSayCommand('!styles', stylescommand, "change your jumpstyle")
    cmdlib.registerSayCommand('!style', stylescommand, "change your jumpstyle")
    cmdlib.registerSayCommand('!timeradmin', admincommand, "timer admin command")
    cmdlib.registerSayCommand('!stop', stopcommand, "stop timer command")
    cmdlib.registerSayCommand('!maplist', maplistcommand, "maplist command")
    cmdlib.registerSayCommand('!mapsdone', mapsdonecommand, "mapsdone command")
    cmdlib.registerSayCommand('!mapsleft', mapsdonecommand, "mapsleft command")
    cmdlib.registerSayCommand('!bonuslist', bonuslistcommand, "bonuslist command")
    cmdlib.registerSayCommand('!bonusdone', mapsdonecommandb, "bonusdone command")
    cmdlib.registerSayCommand('!bonusleft',mapsdonecommandb, "bonusleft command")
    cmdlib.registerSayCommand('!admincommands', admincommands, "timer admin commands list")
    cmdlib.registerSayCommand('!delete', deletecommand, "delete a map from database; !delete <mapname>")
    cmdlib.registerSayCommand('!setmappoints', setmappointscommand, "set map points command")
    cmdlib.registerSayCommand('!playtime', playtimecommand, "total play times")
    cmdlib.registerSayCommand('!rr', restartcommand, "teleport to start")
    cmdlib.registerSayCommand('!w', restartcommandw, "teleport to start")
    cmdlib.registerSayCommand('!sw', restartcommandsw, "teleport to start")
    cmdlib.registerSayCommand('!r', restartcommand, "teleport to start")
    cmdlib.registerSayCommand('!restart', restartcommand, "teleport to start")
    cmdlib.registerSayCommand('!n', restartcommandn, "teleport to start")
    cmdlib.registerSayCommand('!b', brestartcommand, "teleport to bonus start")
    cmdlib.registerSayCommand('!br', brestartcommand, "teleport to bonus start")
    cmdlib.registerSayCommand('!rb', brestartcommand, "teleport to bonus start")
    cmdlib.registerSayCommand('!brr', brestartcommand, "teleport to bonus start")
    cmdlib.registerSayCommand('!rrb', brestartcommand, "teleport to bonus start")
    cmdlib.registerSayCommand('!bstart', brestartcommand, "teleport to bonus start")
    cmdlib.registerSayCommand('!startb', brestartcommand, "teleport to bonus start")
    cmdlib.registerSayCommand('!savedb', savedbcommand, "saves the database")
    cmdlib.registerSayCommand('!cp', cpmenu, "checkpointmenu")
    cmdlib.registerSayCommand('!nc', noclipCommand, "noclip for admins")
    cmdlib.registerSayCommand('!reset', resetcommand, 'remove player from database')
    cmdlib.registerSayCommand('!time', timecommand, 'player record')
	
    for uid in es.getUseridList():
        sid = es.getplayersteamid(uid)
        timers[uid] = time.time()
        if uid not in styles:
            styles[uid] = {}
            styles[uid]['normal'] = 1
            styles[uid]['sideways'] = 0
            styles[uid]['wonly'] = 0
    for user in es.getUseridList():
        steamid = es.getplayersteamid(user)
        dict_add_player(user, steamid)
		
    global TOP_TIME, TOP_TIME_W, TOP_TIME_SW, TOP_TIME_B, TOP_TIME_BW, TOP_TIME_BSW
    TOP_TIME = 0
    TOP_TIME_W = 0
    TOP_TIME_SW = 0
    TOP_TIME_B = 0
    TOP_TIME_BW = 0
    TOP_TIME_BSW = 0
    mapName = str(currentMap)
    if mapName in mapDicts:
        for steamid in mapDicts[mapName]:
            if 'time' in mapDicts[mapName][steamid]:
                (_pos, _len) = mk_sortDictIndex(mapName, steamid)
                if _pos == 1:
                    TOP_TIME = mapDicts[mapName][steamid]['time']
 
            if 'wonly' in mapDicts[mapName][steamid]:
                if 'timew' in mapDicts[mapName][steamid]['wonly']:
                    (_pos, _len) = mk_sortDictIndexw(mapName, steamid)
                    if _pos == 1:
                        TOP_TIME_W = mapDicts[mapName][steamid]['wonly']['timew']
 
            if 'sideways' in mapDicts[mapName][steamid]:
                if 'timesw' in mapDicts[mapName][steamid]['sideways']:
                    (_pos, _len) = mk_sortDictIndexsw(mapName, steamid)
                    if _pos == 1:
                        TOP_TIME_SW = mapDicts[mapName][steamid]['sideways']['timesw']
 
    if mapName in bonusDicts:
        for steamid in bonusDicts[mapName]:
            if 'timeb' in bonusDicts[mapName][steamid]:
                (_pos, _len) = mk_sortDictIndexb(mapName, steamid)
                if _pos == 1:
                    TOP_TIME_B = bonusDicts[mapName][steamid]['timeb']
					
            if 'wonly' in bonusDicts[mapName][steamid]:
                if 'timebw' in bonusDicts[mapName][steamid]['wonly']:
                    (_pos, _len) = mk_sortDictIndexbw(mapName, steamid)
                    if _pos == 1:
                        TOP_TIME_BW = bonusDicts[mapName][steamid]['wonly']['timebw']
						
            if 'sideways' in bonusDicts[mapName][steamid]:
                if 'timebsw' in bonusDicts[mapName][steamid]['sideways']:
                    (_pos, _len) = mk_sortDictIndexbsw(mapName, steamid)
                    if _pos == 1:
                        TOP_TIME_BSW = bonusDicts[mapName][steamid]['sideways']['timebsw']

    for x in es.getUseridList():
        cpid = es.getplayersteamid(x)
        if cpid not in userDict:
            userDict[cpid] = {}
            userDict[cpid]['checkpoints'] = {}
            userDict[cpid]['checkpoints']['1st'] = 0, 0, 0
            userDict[cpid]['checkpoints']['2nd'] = 0, 0, 0

       
def unload():
    es.unload('bhoptimer/modules')
    r_rebuildpoints()
    savedatabase()
    del started[:]
    players.clear() 
    strafes.clear()
    fileStream = open(dictPath, 'w')
    cPickle.dump(mapDicts, fileStream)
    fileStream.close()
    fileStream = open(bonusPath, 'w')
    cPickle.dump(bonusDicts, fileStream)
    fileStream.close()
    fileStream = open(acPath, 'w')
    cPickle.dump(acDicts, fileStream)
    fileStream.close()
    fileStream = open(scorePath, 'w')
    cPickle.dump(mapscore, fileStream)
    fileStream.close()
    fileStream = open(pointsPath, 'w')
    cPickle.dump(points, fileStream)
    fileStream.close()
    fileStream = open(playtimePath, 'w')
    cPickle.dump(playtime, fileStream)
    fileStream.close()
    gamethread.cancelDelayed('climbtime_checkloop')
    gamethread.cancelDelayed('hud_loop')
    
    gamethread.cancelDelayed('climbtime_bonusloop')
    gamethread.cancelDelayed('climbtime_acloop')

    if playerList:
        playerList.delete()
    cmdlib.unregisterServerCommand('stoptimer')
    cmdlib.unregisterSayCommand('!stats')
    cmdlib.unregisterSayCommand('!top')
    cmdlib.unregisterSayCommand('!points')
    cmdlib.unregisterSayCommand('!timer')
    cmdlib.unregisterSayCommand('!timeradmin')
    cmdlib.unregisterSayCommand('!stop')
    cmdlib.unregisterSayCommand('!maplist')
    cmdlib.unregisterSayCommand('!mapsdone')
    cmdlib.unregisterSayCommand('!mapsleft')
    cmdlib.unregisterSayCommand('!bonuslist')
    cmdlib.unregisterSayCommand('!bonusdone')
    cmdlib.unregisterSayCommand('!tpto')
    cmdlib.unregisterSayCommand('!bonusleft')
    cmdlib.unregisterSayCommand('!admincommands')
    cmdlib.unregisterSayCommand('!delete')
    cmdlib.unregisterSayCommand('!setmappoints')
    cmdlib.unregisterSayCommand('!playtime')
    cmdlib.unregisterSayCommand('!rr')
    cmdlib.unregisterSayCommand('!r')
    cmdlib.unregisterSayCommand('!restart')
    cmdlib.unregisterSayCommand('!br')
    cmdlib.unregisterSayCommand('!rb')
    cmdlib.unregisterSayCommand('!b')
    cmdlib.unregisterSayCommand('!rrb')
    cmdlib.unregisterSayCommand('!brr')
    cmdlib.unregisterSayCommand('!bstart')
    cmdlib.unregisterSayCommand('!startb')
    cmdlib.unregisterSayCommand('!rate')
    cmdlib.unregisterSayCommand('!savedb')
    cmdlib.unregisterSayCommand('!cp')
    cmdlib.unregisterSayCommand('!nc')
    cmdlib.unregisterSayCommand('!tpto')
    cmdlib.unregisterSayCommand('!bring')
    cmdlib.unregisterSayCommand('!styles')
    cmdlib.unregisterSayCommand('!style')
    cmdlib.unregisterSayCommand('!w')
    cmdlib.unregisterSayCommand('!sw')
    cmdlib.unregisterSayCommand('!n')
    cmdlib.unregisterSayCommand('!topw')
    cmdlib.unregisterSayCommand('!topsw')
    cmdlib.unregisterSayCommand('!reset')
    cmdlib.unregisterSayCommand('!time')
	
    for user in es.getUseridList():
        steamid = es.getplayersteamid(user)
        dict_del_player(user, steamid)


    timers.clear()
    styles.clear()
    nospam.clear()
    userDict.clear()
		
    conf_menu.delete()
	
	
def noclipCommand(userid, args):
    steamid = es.getplayersteamid(userid)
    if steamid in noclipAuth():
        if steamid in started:
            started.remove(steamid)
        if steamid in startedb:
            startedb.remove(steamid)
        player = playerlib.getPlayer(userid)
        if str(currentMap) in mapDicts:
            if 'startpos' in mapDicts[str(currentMap)]:
                (lowerVertex, upperVertex) = mapDicts[str(currentMap)]['startpos']
                if vecmath.isbetweenRect(es.getplayerlocation(userid), lowerVertex, upperVertex):
                    tell(userid, "cant in start zone")
                else:
                    if player.noclip == 0:
                        player.noclip = 1
                    else:
                        player.noclip = 0
            else:
                if player.noclip == 0:
                    player.noclip = 1
                else:
                    player.noclip = 0
    else:
        tell(userid, 'admin command only')
	
def noclipAuth():
    addonpath = es.getAddonPath("bhoptimer").replace("\\", "/")
    userfile = open(addonpath + '/config/noclip.txt', 'rb')
    userdata = userfile.read()
    userfile.close()
    return userdata.split('\r\n')
	
def statscommandnew(userid, args):
    mapName = str(currentMap)
    if not args:
        target = userid
    else:
        target = es.getuserid(args)
    if not target and not str(args).startswith('STEAM_'):
        tell(userid, "could not find", {'target':args})
        return None
    name = es.getplayername(target)
    steamid = es.getplayersteamid(target)

    if args and str(args).startswith('STEAM_'):
        steamid = str(args)
        name = r_getname(args)
		
    steamids[userid] = steamid
    if steamid in playtime:
        lastconnect = playtime[steamid]['last']
    else:
        lastconnect = "?"
    sortedList = r_ranksorted()
    sortedListw = r_wranksorted()
    sortedListsw = r_swranksorted()
    _pos = 0
    _len = 0
    _swpos = 0
    _swlen = 0
    _wpos = 0
    _wlen = 0
    _posb = 0
    _lenb = 0
    _posbw = 0
    _lenbw = 0
    _posbsw = 0
    _lenbsw = 0
    N_RANK = 0
    SW_RANK = 0
    W_RANK = 0
    N_POINTS = 0
    SW_POINTS = 0
    W_POINTS = 0
    N_TIME = '-'
    SW_TIME = '-'
    W_TIME = '-'
    N_POS = '-'
    SW_POS = '-'
    W_POS = '-'
    B_TIME = '-'
    B_RANK = '-'
    BW_TIME = '-'
    BW_RANK = '-'
    BSW_TIME = '-'
    BSW_RANK = '-'
    md = 0
    mdsw = 0
    mdw = 0
    bd = 0
    bdw = 0
    bdsw = 0
    bl = 0
    blw = 0
    blsw = 0
    ml = 0
    mlw = 0
    mlsw = 0
    totalmaps = 0
    mcp = 0
    mcpw = 0
    mcpsw = 0
    mlp = 0
    mlpw = 0
    mlpsw = 0
    procent = "%"

    for map in sorted(mapDicts):
        if map not in mapscore:
            mapscore[map] = 0.0
        totalmaps += 1

    if mapName in mapDicts:
        (_pos, _len) = mk_sortDictIndex(mapName, steamid)
        (_swpos, _swlen) = mk_sortDictIndexsw(mapName, steamid)
        (_wpos, _wlen) = mk_sortDictIndexw(mapName, steamid)
		
    if mapName in bonusDicts:
        if steamid in bonusDicts[mapName]:
            if 'timeb' in bonusDicts[mapName][steamid]:
                (_posb, _lenb) = mk_sortDictIndexb(mapName, steamid)
                B_TIME = formatTime5(bonusDicts[mapName][steamid]['timeb'])
                B_RANK = '#' + str(_posb)
				
            if 'wonly' in bonusDicts[mapName][steamid]:
                if 'timebw' in bonusDicts[mapName][steamid]['wonly']:
                    (_posbw, _lenbw) = mk_sortDictIndexbw(mapName, steamid)
                    BW_TIME = formatTime5(bonusDicts[mapName][steamid]['wonly']['timebw'])
                    BW_RANK = '#' + str(_posbw)
					
            if 'sideways' in bonusDicts[mapName][steamid]:
                if 'timebsw' in bonusDicts[mapName][steamid]['sideways']:
                    (_posbw, _lenbw) = mk_sortDictIndexbsw(mapName, steamid)
                    BSW_TIME = formatTime5(bonusDicts[mapName][steamid]['sideways']['timebsw'])
                    BSW_RANK = '#' + str(_posbsw)
		
    if steamid in points:
        if 'normal' in points[steamid]:
            N_RANK = str(1 + sortedList.index((steamid, points[steamid]['normal'])))
            N_POINTS = points[steamid]['normal']
            
        if 'sideways' in points[steamid]:
            SW_RANK = str(1 + sortedListsw.index((steamid, points[steamid]['sideways'])))
            SW_POINTS = points[steamid]['sideways']
            
        if 'wonly' in points[steamid]:
            W_RANK = str(1 + sortedListw.index((steamid, points[steamid]['wonly'])))
            W_POINTS = points[steamid]['wonly']

			
    if steamid in mapDicts[mapName]:
        if 'time' in mapDicts[mapName][steamid]:
            N_TIME = formatTime5(mapDicts[mapName][steamid]['time'])
            N_POS = '#' + str(_pos)
            
        if 'sideways' in mapDicts[mapName][steamid]:
            if 'timesw' in mapDicts[mapName][steamid]['sideways']:
                SW_TIME = formatTime5(mapDicts[mapName][steamid]['sideways']['timesw'])
                SW_POS = '#' + str(_swpos)
                
            
        if 'wonly' in mapDicts[mapName][steamid]:
            if 'timew' in mapDicts[mapName][steamid]['wonly']:
                W_TIME = formatTime5(mapDicts[mapName][steamid]['wonly']['timew'])
                W_POS = '#' + str(_wpos)
				
    for map in mapDicts:
        if steamid in mapDicts[map]:
            if 'time' in mapDicts[map][steamid]:
                md += 1
                mcp = 100 * md / totalmaps
            if 'time' not in mapDicts[map][steamid]:
                ml += 1
				
        if steamid in mapDicts[map]:
            if 'sideways' in mapDicts[map][steamid]:
                if 'timesw' in mapDicts[map][steamid]['sideways']:
                    mdsw += 1
                    mcpsw = 100 * mdsw / totalmaps
            if 'sideways' not in mapDicts[map][steamid]:
                    mlsw += 1

        if steamid in mapDicts[map]:
            if 'wonly' in mapDicts[map][steamid]:
                if 'timew' in mapDicts[map][steamid]['wonly']:
                    mdw += 1
                    mcpw = 100 * mdw / totalmaps
            if 'wonly' not in mapDicts[map][steamid]:
                mlw += 1
					
        if steamid not in mapDicts[map]:
            ml += 1
            mlw += 1
            mlsw += 1
			
    for map in bonusDicts:
        if steamid in bonusDicts[map]:
            if 'timeb' in bonusDicts[map][steamid]:
                bd += 1
            if 'timeb' not in bonusDicts[map][steamid]:
                bl += 1
				
        if steamid in bonusDicts[map]:
            if 'sideways' in bonusDicts[map][steamid]:
                if 'timebsw' in bonusDicts[map][steamid]['sideways']:
                    bdsw += 1
            if 'sideways' not in bonusDicts[map][steamid]:
                    blsw += 1
					
        if steamid in bonusDicts[map]:
            if 'wonly' in bonusDicts[map][steamid]:
                if 'timebw' in bonusDicts[map][steamid]['wonly']:
                    bdw += 1
            if 'wonly' not in bonusDicts[map][steamid]:
                blw += 1
				
        if steamid not in mapDicts[map]:
            bl += 1
            blw += 1
            blsw += 1

    total_time = '?'
    if steamid in playtime:
        total_time = formatTime6(playtime[steamid]['total'])
			
    steamprofile.append(steamid)
		
    statsmenu = popuplib.create('statsmenuyo2')
    statsmenu.addline('%s' %name)
    statsmenu.addline('Last online: %s' % (lastconnect))
    statsmenu.addline(' ')
    statsmenu.addline('[Normal] / [W] / [SW]')
    statsmenu.addline(' ')
    statsmenu.addline('->1. Overall Points Ranking:')
    statsmenu.addline('[%s/%s] / [%s/%s] / [%s/%s]' % (N_RANK, str(len(sortedList)), W_RANK, str(len(sortedListw)), SW_RANK, str(len(sortedListsw))))
    statsmenu.addline(' ')
    statsmenu.addline('->2. Points:')
    statsmenu.addline('[%s] / [%s] / [%s]' % (N_POINTS, W_POINTS, SW_POINTS))
    statsmenu.addline(' ')
    if mapName in bonusDicts:
        statsmenu.addline('->3. Current Map Ranking:')
        statsmenu.addline('N: %s - %s\nW: %s - %s\nSW: %s - %s\nBonus N: %s - %s\nBonus W: %s - %s\nBonus SW: %s - %s' % (N_POS, N_TIME, W_POS, W_TIME, SW_POS, SW_TIME, B_RANK, B_TIME, BW_RANK, BW_TIME, BSW_RANK, BSW_TIME))
        statsmenu.addline(' ')
    else:
        statsmenu.addline('->3. Current Map Ranking:')
        statsmenu.addline('N: %s - %s\nW: %s - %s\nSW: %s - %s' % (N_POS, N_TIME, W_POS, W_TIME, SW_POS, SW_TIME))
        statsmenu.addline(' ')
    statsmenu.addline('->4. Maps Done/Left')
    statsmenu.addline('[%s/%s] / [%s/%s] / [%s/%s]' % (md, ml, mdw, mlw, mdsw, mlsw))
    statsmenu.addline('Progress: %s%s / %s%s / %s%s' % (mcp, procent, mcpw, procent, mcpsw, procent))
    statsmenu.addline(' ')
    statsmenu.addline('->5. Bonus Done/Left')
    statsmenu.addline('[%s/%s] / [%s/%s] / [%s/%s]' % (bd, bl, bdw, blw, bdsw, blsw))
    statsmenu.addline(' ')
    statsmenu.addline('->6. Total time played (HH:MM:SS):')
    statsmenu.addline('%s' %total_time)
    statsmenu.addline(' ')
    statsmenu.addline('->9. Steam Profile')
    statsmenu.addline('0. Close')
    statsmenu.send(userid)
	
    statsmenu.menuselect = statsmenuSelect
	
def statsmenuSelect(userid, choice, popupid):
    if choice == 1:
        es.server.queuecmd('es_sexec %s "say !top"' % userid)
		
    if choice == 2:
        es.server.queuecmd('es_sexec %s "say !top"' % userid)
		
    if choice == 3:
        es.server.queuecmd('es_sexec %s "say !wr"' % userid)
		
    if choice == 4:
        mapsdonecommand(userid, steamids[userid])
		
    if choice == 5:
        mapsdonecommandb(userid, steamids[userid])
		
    if choice == 6:
        es.server.queuecmd('es_sexec %s "say !playtime"' % userid)
		
    if choice == 9:
        openProfile(userid, getSteamid(steamids[userid]))
	
	
def getSteamid(steamid):
    steamid = steamid[8:]
    y, z = map(int, steamid.split(':'))
    return z * 2 + y + 76561197960265728
	

		
def openProfile(userid, communityID):
    if communityID != None:
        gamethread.delayed(1, usermsg.motd, (userid, 2, ' ', 'http://steamcommunity.com/profiles/%s' % communityID))
			

def cpmenu(userid, choice):
    mapName = str(currentMap)
    cp = popuplib.create('checkpoints')
    cp.addline('Check-Point Menu')
    cp.addline(' ')
    cp.addline('->1. Save 1st Checkpoint')
    cp.addline('->2. Teleport to 1st Checkpoint')
    cp.addline(' ')
    cp.addline('->3. Save 2nd Checkpoint')
    cp.addline('->4. Teleport to 2nd Checkpoint')
    cp.addline(' ')
    cp.addline('Keep in mind, that teleporting stops your timer.')
    cp.addline(' ')
    cp.addline('0. Close')
     
    cp.menuselect = cpSelect
    cp.send(userid)
	
def cpSelect(userid, choice, popupid):
    global userDict
    steamid = es.getplayersteamid(userid)
    cpid = es.getplayersteamid(userid)
    lowerVertex, upperVertex = mapDicts[str(currentMap)]["startpos"]
    lowerVertexe, upperVertexe = mapDicts[str(currentMap)]["endpos"]
    if choice == 1:
        if (vecmath.isbetweenRect(es.getplayerlocation(userid), lowerVertex, upperVertex)) or (vecmath.isbetweenRect(es.getplayerlocation(userid), lowerVertexe, upperVertexe)):
            tell(userid, "checkpoint cant save in zone")
        else:
            if es.getplayerprop(userid, "CCSPlayer.baseclass.localdata.m_hGroundEntity") != -1:
                userDict[cpid]['checkpoints']['1st'] = es.getplayerlocation(userid)
                tell(userid, "checkpoint saved first")
                popuplib.send('checkpoints', userid)

            else:
                tell(userid, "checkpoint must be on ground")
                popuplib.send('checkpoints', userid)

    elif choice == 2:
        if userDict[cpid]['checkpoints']['1st'] != (0, 0, 0):
            if cpid in started:
                started.remove(cpid)
                tell(userid, 'stop timer')
            if cpid in startedb:
                startedb.remove(cpid)
                tell(userid, 'stop timer')
            if userid in players: del players[userid]
            location = userDict[cpid]['checkpoints']['1st']
            es.server.queuecmd('es_setpos %s %s %s %s' % (userid, location[0], location[1], location[2]))
            popuplib.send('checkpoints', userid)

        else:
            tell(userid, "checkpoint no location saved first")
            popuplib.send('checkpoints', userid)

    elif choice == 3:
        if (vecmath.isbetweenRect(es.getplayerlocation(userid), lowerVertex, upperVertex)) or (vecmath.isbetweenRect(es.getplayerlocation(userid), lowerVertexe, upperVertexe)):
            tell(userid, "checkpoint cant save in zone")
        else:
            if es.getplayerprop(userid, "CCSPlayer.baseclass.localdata.m_hGroundEntity") != -1:
                userDict[cpid]['checkpoints']['2nd'] = es.getplayerlocation(userid)
                tell(userid, "checkpoint saved second")
                popuplib.send('checkpoints', userid)

            else:
                tell(userid, "checkpoint must be on ground")
                popuplib.send('checkpoints', userid)

    elif choice == 4:
        if userDict[cpid]['checkpoints']['2nd'] != (0, 0, 0):
            if cpid in started:
                started.remove(cpid)
                tell(userid, 'stop timer')
            if cpid in startedb:
                startedb.remove(cpid)
                tell(userid, 'stop timer')
            if userid in players: del players[userid]
            location = userDict[cpid]['checkpoints']['2nd']
            es.server.queuecmd('es_setpos %s %s %s %s' % (userid, location[0], location[1], location[2]))
            popuplib.send('checkpoints', userid)

        else:
            tell(userid, "checkpoint no location saved second")
            popuplib.send('checkpoints', userid)

    elif choice in (5, 6, 7, 8):
        popuplib.send('checkpoints', userid)
    elif choice == 9:
        popuplib.send('user_menu', userid)

			
			
def teleportcommand(userid, choice):
    global tele_dict
    user = int(userid)
    target_list = popuplib.easymenu("target_list", "_popup_choice", target_list_select)
    target_list.settitle("Select a Player:")
    target_lista = playerlib.getUseridList("#alive")
    target_lista.sort(key=es.getplayername)
    for player in target_lista:
        if userid != player:
            target_list.addoption(player, es.getplayername(player))
    target_list.send(userid)
                

		
def confirm_teleport(userid, choice, popupname):
    uid = int(userid)
    sid = es.getplayersteamid(uid)
    (lowerVertex, upperVertex) = mapDicts[str(currentMap)]['endpos']
    if choice == 1:
        origin = es.getplayerlocation(userid)
        for player, player2 in tele_dict.items():
            pssid = es.getplayersteamid(player)
            if pssid in started:
                started.remove(pssid)
            if pssid in startedb:
                startedb.remove(pssid)
            if player2 != userid or not es.exists('userid', player):
                continue
                del tele_dict[player]
                if (vecmath.isbetweenRect(es.getplayerlocation(player2), lowerVertex, upperVertex)):
                    es.tell(player, "\x07FFFFFFThe target is in endzone. Can't teleport.")
                else:
                    es.server.queuecmd('es_xsetpos %s %s %s %s'% ((player,) + origin))

            else:
                if pssid in started:
                    started.remove(pssid)
                if pssid in startedb:
                    startedb.remove(pssid)
                del tele_dict[player]
                if (vecmath.isbetweenRect(es.getplayerlocation(player2), lowerVertex, upperVertex)):
                    es.tell(player, "\x07FFFFFFThe target is in endzone. Can't teleport.")
                else:
                    es.server.queuecmd('es_xsetpos %s %s %s %s'% ((player,) + origin))
       
    for player, player2 in tele_dict.items():
        if choice != 1:
            tell(player, "declined", {'target':es.getplayername(player2)})
		
def isDead(userid):
    return es.getplayerprop(userid, 'CBasePlayer.pl.deadflag')

def target_list_select(userid, choice, popupid):

        # Target left the server or is now dead?
    if not es.exists('userid', choice) or isDead(choice):
        return
       
    tele_dict[userid] = choice
    conf_menu.send(choice)
    for player, player2 in tele_dict.items():
        tell(player2, "teleport request", {'target':es.getplayername(player)})
	
conf_menu = popuplib.create('conf_menu')
conf_menu.addline("Accept teleport?")
conf_menu.addline(" ")
conf_menu.addline('->1. Yes')
conf_menu.addline('->2. No')
conf_menu.menuselect = confirm_teleport


				   
def bring_list_select(userid, choice, popupid):
    user = int(userid)
    user2 = int(choice)
    es.server.queuecmd('es_setpos %s %s %s %s'%(user2, es.getplayerlocation(user)[0], es.getplayerlocation(user)[1], es.getplayerlocation(user)[2]))
    es.setplayerprop(user, 'CBaseEntity.m_CollisionGroup', 2)
    es.setplayerprop(user2, 'CBaseEntity.m_CollisionGroup', 2)
    gamethread.delayed(3, es.setplayerprop, (user, 'CBaseEntity.m_CollisionGroup', 5))
    gamethread.delayed(3, es.setplayerprop, (user2, 'CBaseEntity.m_CollisionGroup', 5))
    popuplib.delete('target_list')
 
 
		

		
def bringAuth():
    addonpath = es.getAddonPath("bhoptimer").replace("\\", "/")
    userfile = open(addonpath + '/config/bring.txt', 'rb')
    userdata = userfile.read()
    userfile.close()
    return userdata.split('\r\n')
		
def bringcommand(userid, choice):
    steamid = es.getplayersteamid(userid)
    if steamid in bringAuth():
        player = playerlib.getPlayer(userid)
        global dict_teleport
        user = int(userid)
        bring_list = popuplib.construct('bring_list', 'players', '#alive', bring_list_select)
        bring_list.settitle("Select a Player:")
        popuplib.send('bring_list', userid)
    else:
        tell(userid, 'admin command only')

def dict_add_player(user, steamid):
    global dict_teleport
    if user not in dict_teleport:
        dict_teleport[user] = {}
        dict_teleport[user]["spot"] = 0
		
def dict_del_player(user, steamid):
    if user in dict_teleport:
        del dict_teleport[user]

 
def stoptimer(args):
    userid = int(args[0])
    if userid in started:
        started.remove(userid)
        tell(userid, 'stop timer')
    if userid in startedb:
        startedb.remove(userid)
        tell(userid, 'stop timer')
    if userid in players:
        del players[userid]
   
def round_end(event_var):
    es_map_start({"mapname":str(currentMap)})
   
def savedatabase():
    fileStream = open(dictPath, 'w')
    cPickle.dump(mapDicts, fileStream)
    fileStream.close()
    fileStream = open(bonusPath, 'w')
    cPickle.dump(bonusDicts, fileStream)
    fileStream.close()
    fileStream = open(acPath, 'w')
    cPickle.dump(acDicts, fileStream)
    fileStream.close()
    fileStream = open(scorePath, 'w')
    cPickle.dump(mapscore, fileStream)
    fileStream.close()
    fileStream = open(pointsPath, 'w')
    cPickle.dump(points, fileStream)
    fileStream.close()
    fileStream = open(playtimePath, 'w')
    cPickle.dump(playtime, fileStream)
    fileStream.close()
	
def download():
    addonpath = es.getAddonPath('bhoptimer').replace('\\', '/')
    userfile = open(addonpath + '/config/downloads.txt', 'rb')
    userdata = userfile.read()
    userfile.close()
    for a in userdata.split('\n'):
        es.stringtable('downloadables', a)

def es_map_start(event_var):
    userDict.clear()
    ignoreradio = es.ServerVar('sv_ignoregrenaderadio')
    ignoreradio.set('1')
    global TOP_TIME, TOP_TIME_W, TOP_TIME_SW, TOP_TIME_B, TOP_TIME_BW, TOP_TIME_BSW
    TOP_TIME = 0
    TOP_TIME_W = 0
    TOP_TIME_SW = 0
    TOP_TIME_B = 0
    TOP_TIME_BW = 0
    TOP_TIME_BSW = 0
    for x in userDict:
        userDict[x]['checkpoints']['1st'] = 0, 0, 0
        userDict[x]['checkpoints']['2nd'] = 0, 0, 0
    del started[:]
    players.clear()
    nospam.clear()
    styles.clear()
    strafes.clear()
    savedatabase()
    download()
    r_rebuildpoints()
   
    mapName = str(currentMap)
    if mapName not in mapscore:
        mapscore[mapName] = 0.0
    if not event_var['mapname'] in mapDicts:
        mapDicts[event_var['mapname']] = {}
		

    for steamid in mapDicts[mapName]:
        if 'time' in mapDicts[mapName][steamid]:
            (_pos, _len) = mk_sortDictIndex(mapName, steamid)
            if _pos == 1:
                TOP_TIME = mapDicts[mapName][steamid]['time']
        if 'wonly' in mapDicts[mapName][steamid]:
            if 'timew' in mapDicts[mapName][steamid]['wonly']:
                (_pos, _len) = mk_sortDictIndexw(mapName, steamid)
                if _pos == 1:
                    TOP_TIME_W = mapDicts[mapName][steamid]['wonly']['timew']
        if 'sideways' in mapDicts[mapName][steamid]:
            if 'timesw' in mapDicts[mapName][steamid]['sideways']:
                (_pos, _len) = mk_sortDictIndexsw(mapName, steamid)
                if _pos == 1:
                    TOP_TIME_SW = mapDicts[mapName][steamid]['sideways']['timesw']
    if mapName in bonusDicts:
        for steamid in bonusDicts[mapName]:
            if 'timeb' in bonusDicts[mapName][steamid]:
                (_pos, _len) = mk_sortDictIndexb(mapName, steamid)
                if _pos == 1:
                    TOP_TIME_B = bonusDicts[mapName][steamid]['timeb']
            if 'wonly' in bonusDicts[mapName][steamid]:
                if 'timebw' in bonusDicts[mapName][steamid]['wonly']:
                    (_pos, _len) = mk_sortDictIndexbw(mapName, steamid)
                    if _pos == 1:
                        TOP_TIME_BW = bonusDicts[mapName][steamid]['wonly']['timebw']
            if 'sideways' in bonusDicts[mapName][steamid]:
                if 'timebsw' in bonusDicts[mapName][steamid]['sideways']:
                    (_pos, _len) = mk_sortDictIndexbsw(mapName, steamid)
                    if _pos == 1:
                        TOP_TIME_BSW = bonusDicts[mapName][steamid]['sideways']['timebsw']
        pointschanged = True

    gamethread.cancelDelayed('climbtime_checkloop')
    gamethread.cancelDelayed('hudloop')
    
    gamethread.cancelDelayed('effect_loop1')
    gamethread.cancelDelayed('effect_loop2')
    if event_var['mapname'] in mapDicts:
        if "endpos" not in mapDicts[event_var['mapname']]:
            return
        if "startpos" not in mapDicts[event_var['mapname']]:
            return
        gamethread.delayedname(0.1, 'climbtime_checkloop', checkLoop)

        hudLoop()
        effectloop1()
    gamethread.cancelDelayed('climbtime_bonusloop')
    if event_var['mapname'] in bonusDicts:
        if "endposb" not in bonusDicts[event_var['mapname']]:
            return
        if "startposb" not in bonusDicts[event_var['mapname']]:
            return
        gamethread.delayedname(0.1, 'climbtime_bonusloop', bonusLoop)
        hudLoop()
        effectloop2()
    gamethread.cancelDelayed('climbtime_acloop')
    gamethread.delayedname(0.1, 'climbtime_acloop', acLoop)


    es.stringtable('downloadables','sound/bot/area_clear.wav')
	
def restartcommand(userid, args):
    es.tell(userid, '')
    steamid = es.getplayersteamid(userid)

    mapName = str(currentMap)
        
    if mapName not in mapDicts:
        return None
    if mapName in mapDicts:
        if "startpos" in mapDicts[mapName]:
		
            (x1, y1, z1) = mapDicts[mapName]['startpos'][0]
            (x2, y2, z2) = mapDicts[mapName]['startpos'][1]
            loc1 = (x1 + x2) / 2
            loc2 = (y1 + y2) / 2
            loc3 = z1 + 10
            if steamid in started:
                started.remove(steamid)
        
            if steamid in startedb:
                startedb.remove(steamid)
          
            resetvel(userid)
            es.server.queuecmd('es_setpos %s %s %s %s' % (userid, loc1, loc2, loc3))
        else:
            es.tell(userid, "#multi", "This map doesn't have a timer setup yet.")
		
def restartcommandn(userid, args):
    es.tell(userid, '')
    steamid = es.getplayersteamid(userid)

    mapName = str(currentMap)
        
    styles[userid]['sideways'] = 0
    styles[userid]['normal'] = 1
    styles[userid]['wonly'] = 0
    if mapName not in mapDicts:
        return None
    if mapName in mapDicts:
        if "startpos" in mapDicts[mapName]:
		
            (x1, y1, z1) = mapDicts[mapName]['startpos'][0]
            (x2, y2, z2) = mapDicts[mapName]['startpos'][1]
            loc1 = (x1 + x2) / 2
            loc2 = (y1 + y2) / 2
            loc3 = z1 + 10
            if steamid in started:
                started.remove(steamid)
        
            if steamid in startedb:
                startedb.remove(steamid)
          
            resetvel(userid)
            es.server.queuecmd('es_setpos %s %s %s %s' % (userid, loc1, loc2, loc3))
        else:
            es.tell(userid, "#multi", "This map doesn't have a timer setup yet.")

		
def restartcommandw(userid, args):
    es.tell(userid, '')
    steamid = es.getplayersteamid(userid)

    mapName = str(currentMap)
        
    styles[userid]['sideways'] = 0
    styles[userid]['normal'] = 0
    styles[userid]['wonly'] = 1
    if mapName not in mapDicts:
        return None
    if mapName in mapDicts:
        if "startpos" in mapDicts[mapName]:
		
            (x1, y1, z1) = mapDicts[mapName]['startpos'][0]
            (x2, y2, z2) = mapDicts[mapName]['startpos'][1]
            loc1 = (x1 + x2) / 2
            loc2 = (y1 + y2) / 2
            loc3 = z1 + 10
            if steamid in started:
                started.remove(steamid)
        
            if steamid in startedb:
                startedb.remove(steamid)
          
            resetvel(userid)
            es.server.queuecmd('es_setpos %s %s %s %s' % (userid, loc1, loc2, loc3))
        else:
            es.tell(userid, "#multi", "This map doesn't have a timer setup yet.")

		
def restartcommandsw(userid, args):
    es.tell(userid, '')
    steamid = es.getplayersteamid(userid)

    mapName = str(currentMap)
        
    styles[userid]['sideways'] = 1
    styles[userid]['normal'] = 0
    styles[userid]['wonly'] = 0
    if mapName not in mapDicts:
        return None
    if mapName in mapDicts:
        if "startpos" in mapDicts[mapName]:
		
            (x1, y1, z1) = mapDicts[mapName]['startpos'][0]
            (x2, y2, z2) = mapDicts[mapName]['startpos'][1]
            loc1 = (x1 + x2) / 2
            loc2 = (y1 + y2) / 2
            loc3 = z1 + 10
            if steamid in started:
                started.remove(steamid)
        
            if steamid in startedb:
                startedb.remove(steamid)
          
            resetvel(userid)
            es.server.queuecmd('es_setpos %s %s %s %s' % (userid, loc1, loc2, loc3))
        else:
            es.tell(userid, "#multi", "This map doesn't have a timer setup yet.")

def brestartcommand(userid, args):
    es.tell(userid, "")
    mapName = str(currentMap)
    if mapName in bonusDicts:
        x1,y1,z1 = bonusDicts[mapName]['startposb'][0]
        x2,y2,z2 = bonusDicts[mapName]['startposb'][1]
        loc1 = (x1+x2)/2
        loc2 = (y1+y2)/2
        loc3 = z1+10
        if userid in started: started.remove(userid)
        if userid in startedb: startedb.remove(userid)
        es.server.queuecmd('es_setpos %s %s %s %s' % (userid, loc1, loc2, loc3))
    else:
        tell(userid, "map has no bonus")

def player_activate(ev):
    global userDict
    userid = int(ev['userid'])
    steamid = es.getplayersteamid(userid)
    cpid = es.getplayersteamid(userid)
    if cpid not in userDict:
        userDict[cpid] = {}
        userDict[cpid]['checkpoints'] = {}
        userDict[cpid]['checkpoints']['1st'] = 0, 0, 0
        userDict[cpid]['checkpoints']['2nd'] = 0, 0, 0

    if userid not in styles:
        styles[userid] = { }
        styles[userid]['normal'] = 1
        styles[userid]['sideways'] = 0
        styles[userid]['wonly'] = 0
    user = int(ev['userid'])
    steamid = es.getplayersteamid(userid)
    dict_add_player(user, steamid)
    timers[userid] = time.time()
    if steamid not in playtime:
        playtime[steamid] = {}
        playtime[steamid]['name'] = es.getplayername(userid)
        playtime[steamid]['total'] = 0
        playtime[steamid]['last'] = 0
    playtime[steamid]['name'] = es.getplayername(userid)


    gamethread.delayed(3, message, (userid))
    activated = popuplib.create('welcome message')
    activated.addline('Welcome, %s!' % es.getplayername(userid))
    activated.addline(' ')
    activated.addline('Bhop-Timer with Jump-Styles (v1.0.2)')
    activated.addline('Version released: 08.08.2013, 18:01')
    activated.addline(' ')
    activated.addline('Type !styles to change your JumpStyle.')
    activated.addline(' ')
    activated.addline('->1. Made by Nairda')
    activated.addline(' ')
    activated.addline('Special thanks to h!gh voltage')
    activated.addline("0. Close")
    activated.send(userid)
    activated.menuselect = activatedmenu
	
	
	
def activatedmenu(userid, choice, popupid):
    if choice == 1:
        usermsg.motd(userid, 2, 'Nairda Steam', 'http://steamcommunity.com/profiles/76561198060660222')      
	


def message(userid):
    tell(userid, "welcome message")
		

def player_disconnect(event_var):
    user = int(event_var['userid'])
    steamid = event_var['networkid']
    userid = int(event_var['userid'])
    steamid = event_var['networkid']
    lastconnect = str(strftime("%a, %d %b %Y %H:%M:%S"))
	
    if steamid in playtime:
        playtime[steamid]['last'] = lastconnect
        if userid in timers:
            elapsed = time.time() - timers[userid]
            playtime[steamid]['total'] += elapsed
            del timers[userid]
			
    if userDict.has_key(steamid):
        del userDict[steamid]
			
    if steamid in started:
        started.remove(steamid)
    if steamid in startedb:
        startedb.remove(steamid)
    if userid in players:
        del players[userid]
    if speeddict.has_key(steamid):
        del speeddict[steamid]
    if speeddictb.has_key(steamid):
        del speeddictb[steamid]
    if userid in strafes:
        del strafes[userid]
		
    global userDict
    cpid = es.getplayersteamid(userid)
    if cpid in userDict:
        userDict.remove(steamid)
        del userDict[steamid]
		
def getRank(steamid):
    sortedList = r_ranksorted()
    if steamid in points:
        if 'normal' in points[steamid]:
            return int(1 + sortedList.index((steamid, points[steamid]['normal'])))
    return 0

def sortedplaytime():
    psort = {}
    for sid in playtime:
        psort[sid] = playtime[sid]["total"]
    return sorted(psort.items(), key=itemgetter(1), reverse=True)

def deletecommand(userid, args):
    steamid = es.getplayersteamid(userid)
    if isAuthed(userid) or steamid == 'STEAM_0:0:50197247':
        if not args:
            es.tell(userid, '!delete <mapname>')
        else:
            map = str(args)
            if map in mapDicts:
                del mapDicts[map]
                if map in bonusDicts:
                    del bonusDicts[map]
                es.tell(userid, 'map deleted')
            else:
                es.tell(userid, 'map not found')
    else:
        tell(userid, 'admin command only')
			
def resetcommand(userid, args):
    steamid = es.getplayersteamid(userid)
    if isAuthed(userid) or steamid == 'STEAM_0:0:50197247':
        if not args:
            return es.tell(userid, '!reset <steamid>')
        
        steamid = str(args)
        if steamid.startswith('STEAM_'):
            for map in mapDicts:
                if steamid in mapDicts[map]:
                    del mapDicts[map][steamid]
                    continue
            for bmap in bonusDicts:
                if steamid in bonusDicts[bmap]:
                    del bonusDicts[bmap][steamid]
                    continue
            if steamid in points:
                del points[steamid]
            
            es.tell(userid, 'You have deleted %s from the database.' % steamid)
        else:
            es.tell(userid, 'Enter a valid steamid.')
    else:
        tell(userid, 'admin command only')
			

def setmappointscommand(userid, args):
    steamid = es.getplayersteamid(userid)
    if isAuthed(userid) or steamid == 'STEAM_0:0:50197247':
        if not args:
            es.tell(userid, 'Corrent command: !setmappoints <map> <points>')
        if args[0] not in mapDicts:
            es.tell(userid, 'You need to setup the map first.')
            return
        try:
            mapscore[args[0]] = float(args[1])
            es.msg('%s: %s Points' %(args[0], args[1]))
            pointschanged = True
        except ValueError:
            es.tell(userid, 'Please enter a correct amount of points (numbers only).')
    else:
        tell(userid, 'admin command only')

def player_jump(event_var):
    userid = int(event_var['userid'])
    steamid = es.getplayersteamid(event_var['userid'])
    if userid not in players: return
    players[userid][1] += 1
    if (steamid in started) or (steamid in startedb):
        if userid in styles:
            if styles[userid]['sideways'] == 1:
                if userid not in swac:
                    swac[userid] = { }
                    swac[userid]['jumps'] = 0
                    swac[userid]['strafes'] = 0
                
                swac[userid]['jumps'] += 1
                if swac[userid]['jumps'] >= 3:
                    if swac[userid]['strafes'] == 0:
                        resetvel(userid)
                    
                    swac[userid]['jumps'] = 0
                    swac[userid]['strafes'] = 0
 
def player_death(event_var):
    cpid = es.getplayersteamid(event_var['userid'])
    if userDict[cpid]['checkpoints']['1st'] != (0, 0, 0) or userDict[cpid]['checkpoints']['2nd'] != (0, 0, 0):
        userDict[cpid] = {}
        userDict[cpid]['checkpoints'] = {}
        userDict[cpid]['checkpoints']['1st'] = 0, 0, 0
        userDict[cpid]['checkpoints']['2nd'] = 0, 0, 0
    userid = int(event_var["userid"])
    steamid = es.getplayersteamid(userid)
    if steamid in started:
        started.remove(steamid)
    if steamid in startedb:
        startedb.remove(steamid)
    if userid in players:
        del players[userid]


def playtimecommand(userid, args):
    if not args:
        playtimem = popuplib.easymenu('ptime', None, choicehandler)
        playtimem.settitle("Top 100 Playtimes (HH:MM:SS)")
        sortedlist = sortedplaytime()
        if sortedlist:
            lx = 0
            for top in sortedlist:
                lx += 1
                playtimem.addoption(top[0], "#%s %s: %s" %(lx, r_getname(top[0]), formatTime6(playtime[top[0]]['total'])))
                if lx > 100:
                    break
                    continue
        else:
            playtimem.addoption(None, '[No playtimes recorded]')
        playtimem.unsend(userid)
        playtimem.send(userid)
    else:
        target = es.getuserid(args)
        if not target:
            tell(userid, "could not find", {'target':args})
            return
        steamid = es.getplayersteamid(target)
        name = es.getplayername(target)
        tell(userid, "playtime", {'name':name, 'timeplayed':formatTime3(playtime[steamid]['total'])})

def timecommand(userid, args):
    if userid not in maps:
        mapName = str(currentMap)
    else:
        mapName = maps[userid]
    if not args:
        target = userid
    else:
        target = es.getuserid(args)
    if not target and not str(args).startswith('STEAM_'):
        tell(userid, "could not find", {'target':args})
        return None
    name = es.getplayername(target)
    steamid = es.getplayersteamid(target)

    if args and str(args).startswith('STEAM_'):
        steamid = str(args)
        name = r_getname(args)
		
    steamids[userid] = steamid
		
    N_TIME = '-'
    N_POS = '-'
    N_JUMPS = '-'
    N_DATE = '-'
    N_STRAFES = '-'
    SW_TIME = '-'
    SW_POS = '-'
    SW_JUMPS = '-'
    SW_DATE = '-'
    SW_STRAFES = '-'
    W_TIME = '-'
    W_POS = '-'
    W_JUMPS = '-'
    W_DATE = '-'
    W_STRAFES = '-'
    B_TIME = '-'
    B_POS = '-'
    B_JUMPS = '-'
    B_DATE = '-'
	
    if mapName in bonusDicts:
        if steamid in bonusDicts[mapName]:
            (_posb, _lenb) = mk_sortDictIndexb(mapName, steamid)
            B_RANK = _posb
			
            if 'timeb' in bonusDicts[mapName][steamid]:
                B_TIME = formatTime5(bonusDicts[mapName][steamid]['timeb'])
                B_POS = '#' + str(_posb)
                B_JUMPS = bonusDicts[mapName][steamid]['jumpsb']
	
    if mapName in mapDicts:
        (_pos, _len) = mk_sortDictIndex(mapName, steamid)
        (_swpos, _swlen) = mk_sortDictIndexsw(mapName, steamid)
        (_wpos, _wlen) = mk_sortDictIndexw(mapName, steamid)
		
    if steamid in mapDicts[mapName]:
        if 'time' in mapDicts[mapName][steamid]:
            N_TIME = formatTime5(mapDicts[mapName][steamid]['time'])
            N_POS = '#' + str(_pos)
            N_JUMPS = mapDicts[mapName][steamid]['jumps']
            if 'date' in mapDicts[mapName][steamid]:
                N_DATE = mapDicts[mapName][steamid]['date']
            else:
                N_DATE = "-"	
            if 'strafes' in mapDicts[mapName][steamid]:
                N_STRAFES = mapDicts[mapName][steamid]['strafes']
            else:
                N_STRAFES = "-"	

        if 'sideways' in mapDicts[mapName][steamid]:
            if 'timesw' in mapDicts[mapName][steamid]['sideways']:
                SW_TIME = formatTime5(mapDicts[mapName][steamid]['sideways']['timesw'])
                SW_POS = '#' + str(_swpos)
                SW_JUMPS = mapDicts[mapName][steamid]['sideways']['jumpssw']
                if 'datesw' in mapDicts[mapName][steamid]['sideways']:
                    SW_DATE = mapDicts[mapName][steamid]['sideways']['datesw']
                else:
                    SW_DATE = "-"
                if 'strafessw' in mapDicts[mapName][steamid]['sideways']:
                    SW_STRAFES = mapDicts[mapName][steamid]['sideways']['strafessw']
                else:
                    SW_STRAFES = "-"

				
        if 'wonly' in mapDicts[mapName][steamid]:
            if 'timew' in mapDicts[mapName][steamid]['wonly']:
                W_TIME = formatTime5(mapDicts[mapName][steamid]['wonly']['timew'])
                W_POS = '#' + str(_wpos)
                W_JUMPS = mapDicts[mapName][steamid]['wonly']['jumpsw']
                if 'datew' in mapDicts[mapName][steamid]['wonly']:
                    W_DATE = mapDicts[mapName][steamid]['wonly']['datew']
                else:
                    W_DATE = "-"	
                if 'strafesw' in mapDicts[mapName][steamid]['wonly']:
                    W_STRAFES = mapDicts[mapName][steamid]['wonly']['strafesw']
                else:
                    W_STRAFES = "-"	
				


    timemenu = popuplib.create('timemenum')
    timemenu.addline('Record details of player %s for map %s' %(name, mapName))
    timemenu.addline(' ')
    timemenu.addline('Normal:')
    timemenu.addline('  Rank: %s' %N_POS)
    timemenu.addline('  Time: %s' %N_TIME)
    timemenu.addline('  Jumps: %s' %(N_JUMPS))
    timemenu.addline('  Strafes: %s' %(N_STRAFES))
    timemenu.addline('  Date of record: %s' %(N_DATE))
    timemenu.addline(' ')
    timemenu.addline('SideWays:')
    timemenu.addline('  Rank: %s' %SW_POS)
    timemenu.addline('  Time: %s' %SW_TIME)
    timemenu.addline('  Jumps: %s' %(SW_JUMPS))
    timemenu.addline('  Strafes: %s' %(SW_STRAFES))
    timemenu.addline('  Date of record: %s' %(SW_DATE))
    timemenu.addline(' ')
    timemenu.addline('W-Only:')
    timemenu.addline('  Rank: %s' %W_POS)
    timemenu.addline('  Time: %s' %W_TIME)
    timemenu.addline('  Jumps: %s' %(W_JUMPS))
    timemenu.addline('  Strafes: %s' %(W_STRAFES))
    timemenu.addline('  Date of record: %s' %(W_DATE))
    timemenu.addline(' ')
    if mapName in bonusDicts:
        timemenu.addline('Bonus:')
        timemenu.addline('  Rank: %s' %B_POS)
        timemenu.addline('  Time: %s' %B_TIME)
    else:
        timemenu.addline('Bonus:')
        timemenu.addline('  No Bonus timer on map')
    timemenu.addline(' ')
    timemenu.addline('->8. Player Statistics')
    timemenu.addline('->9. Steam Profile')
    timemenu.addline('0. Close')
    timemenu.menuselect = timecommandSelect
    timemenu.unsend(userid)
    timemenu.send(userid)
    maps[userid] = str(currentMap)

def timecommandSelect(userid, choice, popupid):
    if choice == 8:
        statscommandnew(userid, steamids[userid])

    if choice == 9:
        openProfile(userid, getSteamid(steamids[userid]))

def topcommand(userid, args):
    topRanks = popuplib.easymenu('topranks', None, choicehandler)
    topRanks.settitle("Top 100 Players by points")
    sortedList = r_ranksorted()
    if sortedList:
        lx = 0
        for top in sortedList:
            topRanks.addoption(top[0], "#%s %s - %s Points" % (lx+1, r_getname(top[0]), points[top[0]]['normal']))
            if lx >= 100: break
            lx += 1
    else:
        topRanks.addoption(None, '[No Ranking yet.]', None)
    topRanks.unsend(userid)
    topRanks.send(userid)
	
def topcommandsw(userid, args):
    topRankssw = popuplib.easymenu('topranks', None, choicehandler)
    topRankssw.settitle("Top 100 Players by points (Sideways)")
    sortedList = r_swranksorted()
    if sortedList:
        lx = 0
        for top in sortedList:
            topRankssw.addoption(top[0], "#%s %s - %s Points" % (lx+1, r_getname(top[0]), points[top[0]]['sideways']))
            if lx >= 100: break
            lx += 1
    else:
        topRankssw.addoption(None, '[No Ranking yet.]', None)
    topRankssw.unsend(userid)
    topRankssw.send(userid)
	
def topcommandw(userid, args):
    topRanksw = popuplib.easymenu('topranks', None, choicehandler)
    topRanksw.settitle("Top 100 Players by points (W-Only)")
    sortedList = r_wranksorted()
    if sortedList:
        lx = 0
        for top in sortedList:
            topRanksw.addoption(top[0], "#%s %s - %s Points" % (lx+1, r_getname(top[0]), points[top[0]]['wonly']))
            if lx >= 100: break
            lx += 1
    else:
        topRanksw.addoption(None, '[No Ranking yet.]', None)
    topRanksw.unsend(userid)
    topRanksw.send(userid)
	
def r_wranksorted():
    wrank = {}
    for sid in points:
        if 'wonly' in points[sid]:
            wrank[sid] = points[sid]['wonly']
    return sorted(wrank.items(), key=itemgetter(1), reverse=True)
	
def pointscommand(userid, args):
    if not args:
        mapName = str(currentMap)
    else:
        mapName = str(args)
    if mapName not in mapDicts:
        tell(userid, "could not find map", {'map':str(mapName)})
    else:
        tell(userid, "points for map", {'map':str(mapName), 'mappoints':mapscore[mapName]})
	
def savedbcommand(userid, args):
    steamid = es.getplayersteamid(userid)
    if isAuthed(userid) or steamid == 'STEAM_0:0:50197247':
        savedatabase()
        es.tell(userid, '#multi', "Database saved.")
    else:
        tell(userid, 'admin command only')

def admincommand(userid, args):
    steamid = es.getplayersteamid(userid)
    if isAuthed(userid) or steamid == 'STEAM_0:0:50197247':
        adminPopup.send(userid)
        es.tell(userid, 'Type !admincommands to view a full list of admin commands.')
    else:
        tell(userid, 'admin command only')

def stylescommand(userid, args):
    stylemenu = popuplib.create('styles_menu')
    stylemenu.addline("                Choose your JumpStyle                 ")
    stylemenu.addline(' ')
    if styles[userid]['normal'] == 1:
        stylemenu.addline('1. Normal')
    else:
        stylemenu.addline('->1. Normal')
    if styles[userid]['sideways'] == 1:
        stylemenu.addline('2. SideWays')
    else:
        stylemenu.addline('->2. SideWays')
    if styles[userid]['wonly'] == 1:
        stylemenu.addline('3. W-Only')
    else:
        stylemenu.addline('->3. W-Only')
    stylemenu.addline(' ')
    stylemenu.addline("Changing your style resets the timer! ")
    stylemenu.addline(' ')
    stylemenu.addline('0. Close (No change)')
    stylemenu.unsend(userid)
    stylemenu.send(userid)
    stylemenu.delete()
    stylemenu.menuselect = styleSelect
	
def styleSelect(userid, choice, popupid):
    steamid = es.getplayersteamid(userid)
    mapName = str(currentMap)
    (x1, y1, z1) = mapDicts[mapName]['startpos'][0]
    (x2, y2, z2) = mapDicts[mapName]['startpos'][1]
    loc1 = (x1 + x2) / 2
    loc2 = (y1 + y2) / 2
    loc3 = z1 + 10
    
    if choice == 1:
        if styles[userid]['normal'] == 0:
            styles[userid]['sideways'] = 0
            styles[userid]['normal'] = 1
            styles[userid]['wonly'] = 0
            tell(userid, "style change normal")
            es.server.queuecmd('es_setpos %s %s %s %s' % (userid, loc1, loc2, loc3))
                
    elif choice == 2:
        if styles[userid]['sideways'] == 0:
            styles[userid]['sideways'] = 1
            styles[userid]['normal'] = 0
            styles[userid]['wonly'] = 0
            tell(userid, "style change sideways")
            es.server.queuecmd('es_setpos %s %s %s %s' % (userid, loc1, loc2, loc3))
                
            
    elif choice == 3:
        if styles[userid]['wonly'] == 0:
            styles[userid]['wonly'] = 1
            styles[userid]['normal'] = 0
            styles[userid]['sideways'] = 0
            tell(userid, "style change w-only")
            es.server.queuecmd('es_setpos %s %s %s %s' % (userid, loc1, loc2, loc3))
                
    if choice in (1, 2, 3):
        stylescommand(userid, None)
	
def stoptimer(args):
    userid = int(args[0])
    steamid = es.getplayersteamid(userid)
    if steamid in started:
        started.remove(steamid)
    
    if steamid in startedb:
        startedb.remove(steamid)
    
    if userid in players:
        del players[userid]
    
		
def stopcommand(userid, args):
    es.tell(userid, '#multi', '')
    steamid = es.getplayersteamid(userid)
    if steamid not in started:
        return tell(userid, "timer not running")
    else:
        started.remove(steamid)
        tell(userid, 'stop timer')
    if steamid in startedb:
        startedb.remove(steamid)
        tell(userid, 'stop timer')
        
    if userid in players:
        del players[userid]
            
        

		
def timerstop(userid):
    steamid = es.getplayersteamid(userid)
    if steamid in started:
        started.remove(steamid)
    
    if steamid in startedb:
        startedb.remove(steamid)

		

def admincommands(userid, args):
    if isAuthed(userid):
        admin = popuplib.create('admin_commands')
        admin.addline('Bhop-Timer Admin Commands')
        admin.addline(' ')
        admin.addline('!timer')
        admin.addline('!setmappoints')
        admin.addline('!delete mapname - remove map from all databases')
        admin.unsend(userid)
        admin.send(userid)
        admin.delete()
    else:
        tell(userid, 'admin command only')
		
def mapsdonecommandb(userid, args):
    es.tell(userid, "#multi", "\x07FFFFFFType \x07FF0000!mapsdone \x07FFFFFFor \x07FF0000!mapsleft \x07FFFFFFto check the maps' main progress.")
    mapName = str(currentMap)
    if not args:
        target = userid
    else:
        target = es.getuserid(args)
    if not target and not str(args).startswith('STEAM_'):
        tell(userid, "could not find", {'target':args})
        return None
    name = es.getplayername(target)
    steamid = es.getplayersteamid(target)

    if args and str(args).startswith('STEAM_'):
        steamid = str(args)
        name = r_getname(args)

		
    steamids[userid] = steamid
    mapsdonemenu = popuplib.create('mapsmenu')
    mapsdonemenu.addline('Bonus Completion Summary for player %s' % name)
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline('->1. Bonus done Normal')
    mapsdonemenu.addline('->2. Bonus left Normal')
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline('->3. Bonus done SideWays')
    mapsdonemenu.addline('->4. Bonus left SideWays')
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline('->5. Bonus done W-Only')
    mapsdonemenu.addline('->6. Bonus left W-Only')
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline("0. Close")
    mapsdonemenu.unsend(userid)
    mapsdonemenu.send(userid)
    mapsdonemenu.delete()
    mapsdonemenu.menuselect = mapsdonemenuSelectb

def mapsdonecommand(userid, args):
    es.tell(userid, "#multi", "\x07FFFFFFType \x07FF0000!bonusdone \x07FFFFFFor \x07FF0000!bonusleft \x07FFFFFFto check the maps' bonus progress.")
    mapName = str(currentMap)
    if not args:
        target = userid
    else:
        target = es.getuserid(args)
    if not target and not str(args).startswith('STEAM_'):
        tell(userid, "could not find", {'target':args})
        return None
    name = es.getplayername(target)
    steamid = es.getplayersteamid(target)

    if args and str(args).startswith('STEAM_'):
        steamid = str(args)
        name = r_getname(args)
		
    md = 0
    mdsw = 0
    mdw = 0
    ml = 0
    mlw = 0
    mlsw = 0
    totalmaps = 0
    mcp = 0
    mcpw = 0
    mcpsw = 0
    procent = "%"
	
    for map in sorted(mapDicts):
        if map not in mapscore:
            mapscore[map] = 0.0
        totalmaps += 1
	
    for map in mapDicts:
        if steamid in mapDicts[map]:
            if 'time' in mapDicts[map][steamid]:
                md += 1
                mcp = 100 * md / totalmaps
            if 'time' not in mapDicts[map][steamid]:
                ml += 1
				
        if steamid in mapDicts[map]:
            if 'sideways' in mapDicts[map][steamid]:
                if 'timesw' in mapDicts[map][steamid]['sideways']:
                    mdsw += 1
                    mcpsw = 100 * mdsw / totalmaps
            if 'sideways' not in mapDicts[map][steamid]:
                mlsw += 1

        if steamid in mapDicts[map]:
            if 'wonly' in mapDicts[map][steamid]:
                if 'timew' in mapDicts[map][steamid]['wonly']:
                    mdw += 1
                    mcpw = 100 * mdw / totalmaps
            if 'wonly' not in mapDicts[map][steamid]:
                mlw += 1
					
        if steamid not in mapDicts[map]:
            ml += 1
            mlw += 1
            mlsw += 1
		
    steamids[userid] = steamid
    mapsdonemenu = popuplib.create('mapsmenu')
    mapsdonemenu.addline('Maps Completion Summary for player %s' % name)
    mapsdonemenu.addline('Total maps: %s' % str(totalmaps))
    mapsdonemenu.addline('Normal / W-Only / SW')
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline('Maps completed:')
    mapsdonemenu.addline('Amount: %s / %s / %s' % (md, mdw, mdsw))
    mapsdonemenu.addline('Progress: %s%s / %s%s / %s%s' % (mcp, procent, mcpw, procent, mcpsw, procent))
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline('Maps not completed:')
    mapsdonemenu.addline('%s / %s / %s' % (ml, mlw, mlsw))
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline('->1. Maps done Normal')
    mapsdonemenu.addline('->2. Maps left Normal')
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline('->3. Maps done SideWays')
    mapsdonemenu.addline('->4. Maps left SideWays')
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline('->5. Maps done W-Only')
    mapsdonemenu.addline('->6. Maps left W-Only')
    mapsdonemenu.addline(' ')
    mapsdonemenu.addline("0. Close")
    mapsdonemenu.unsend(userid)
    mapsdonemenu.send(userid)
    mapsdonemenu.delete()
    mapsdonemenu.menuselect = mapsdonemenuSelect
	
def mapsdonemenuSelectb(userid, choice, popupid):
    steamid = steamids[userid]
    name = r_getname(steamid)
    if choice == 1:
        bonusdone = popuplib.easymenu('bonusdonem', None, mapsdonehandler)
        bonusdone.settitle('Maps Completed\nStyle: Normal        ')
        lx = 0
        for map in sorted(bonusDicts):
            if steamid in bonusDicts[map]:
                if 'timeb' in bonusDicts[map][steamid]:
                    (_pos, _len) = mk_sortDictIndexb(map, steamid)
                    bonusdone.addoption(map, '%s - #%s %s' % (str(map), _pos, formatTime5(bonusDicts[map][steamid]['timeb'])))
                    lx += 1
                
        if lx == 0:
            mapsdone.addoption(None, '[ No maps done ]')
        
        bonusdone.settitle('Player %s has finished %s bonuses\nStyle: Normal        ' % (name, str(lx)))
        bonusdone.unsend(userid)
        bonusdone.send(userid)
		
    if choice == 2:
        bonusleft = popuplib.easymenu('bonusleftm', None, mapsdonehandler)
        bonusleft.settitle('Bonuses left \nStyle: Normal        ')
        lx = 0
        for map in sorted(bonusDicts):
            if steamid in bonusDicts[map]:
                if 'timeb' not in bonusDicts[map][steamid]:
                    bonusleft.addoption(map, '%s - %s pts' %(str(map), mapscore[map]))
                    lx += 1
            if steamid not in bonusDicts[map]:
                bonusleft.addoption(map, '%s - %s pts' %(str(map), mapscore[map]))
                lx += 1
        
        if lx == 0:
            bonusleft.addoption(None, '[ All maps completed !]')
        
        bonusleft.settitle('Player %s has %s bonuses left \nStyle: Normal        ' % (name, str(lx)))
        bonusleft.unsend(userid)
        bonusleft.send(userid)
		
    if choice == 3:
        bonusdonesw = popuplib.easymenu('mapsdonebmsw', None, mapsdonehandler)
        bonusdonesw.settitle('Bonuses Completed\nStyle: SideWays        ')
        lx = 0
        for map in sorted(bonusDicts):
            if steamid in bonusDicts[map]:
                if 'sideways' in bonusDicts[map][steamid]:
                    if 'timebsw' in bonusDicts[map][steamid]['sideways']:
                        (_pos, _len) = mk_sortDictIndexbsw(map, steamid)
                        bonusdonesw.addoption(map, '%s - #%s %s' % (str(map), _pos, formatTime5(bonusDicts[map][steamid]['sideways']['timebsw'])))
                        lx += 1
     
        if lx == 0:
            bonusdonesw.addoption(None, '[ No maps done ]')
        
        bonusdonesw.settitle('Player %s has finished %s bonuses\nStyle: SideWays        ' % (name, str(lx)))
        bonusdonesw.unsend(userid)
        bonusdonesw.send(userid)
		
    if choice == 4:
        bonusleftsw = popuplib.easymenu('bonussleftmsw', None, mapsdonehandler)
        bonusleftsw.settitle('Bonus left\nStyle: SideWays        ')
        lx = 0
        for map in sorted(bonusDicts):
            if steamid in bonusDicts[map]:
                if 'sideways' not in bonusDicts[map][steamid]:
                    bonusleftsw.addoption(map, '%s - %s pts' % (str(map), mapscore[map]*1.5))
                    lx += 1
                
            if steamid not in mapDicts[map]:
                bonusleftsw.addoption(map, '%s - %s pts' % (str(map), mapscore[map]*1.5))
                lx += 1
        
        if lx == 0:
            bonusleftsw.addoption(None, '[ All maps completed !]')
        
        bonusleftsw.settitle('Player %s has %s bonuses left\nStyle: SideWays        ' % (name, str(lx)))
        bonusleftsw.unsend(userid)
        bonusleftsw.send(userid)
		
    if choice == 5:
        bonusdonew = popuplib.easymenu('mapsdonemw', None, mapsdonehandler)
        bonusdonew.settitle('Bonuses Completed\nStyle: W-Only        ')
        lx = 0
        for map in sorted(bonusDicts):
            if steamid in bonusDicts[map]:
                if 'wonly' in bonusDicts[map][steamid]:
                    if 'timebw' in bonusDicts[map][steamid]['wonly']:
                        (_pos, _len) = mk_sortDictIndexbw(map, steamid)
                        bonusdonew.addoption(map, '%s - #%s %s' % (str(map), _pos, formatTime5(bonusDicts[map][steamid]['wonly']['timebw'])))
                        lx += 1
       
        if lx == 0:
            bonusdonew.addoption(None, '[ No maps done ]')
        
        bonusdonew.settitle('Player %s has finished %s bonuses\nStyle: W-Only        ' % (name, str(lx)))
        bonusdonew.unsend(userid)
        bonusdonew.send(userid)
		
    if choice == 6:
        bonusleftsw = popuplib.easymenu('bonussleftmsw', None, mapsdonehandler)
        bonusleftsw.settitle('Bonus left\nStyle: W-Only        ')
        lx = 0
        for map in sorted(bonusDicts):
            if steamid in bonusDicts[map]:
                if 'wonly' not in bonusDicts[map][steamid]:
                    bonusleftsw.addoption(map, '%s - %s pts' % (str(map), mapscore[map]*1.5))
                    lx += 1
                
            if steamid not in mapDicts[map]:
                bonusleftsw.addoption(map, '%s - %s pts' % (str(map), mapscore[map]*1.5))
                lx += 1
        
        if lx == 0:
            bonusleftsw.addoption(None, '[ All maps completed !]')
        
        bonusleftsw.settitle('Player %s has %s bonuses left\nStyle: W-Only        ' % (name, str(lx)))
        bonusleftsw.unsend(userid)
        bonusleftsw.send(userid)
	
def mapsdonemenuSelect(userid, choice, popupid):
    steamid = steamids[userid]
    name = r_getname(steamid)
    if choice == 1:
        mapsdone = popuplib.easymenu('mapsdonem', None, mapsdonehandler)
        mapsdone.settitle('Maps Completed\nStyle: Normal        ')
        lx = 0
        for map in sorted(mapDicts):
            if steamid in mapDicts[map]:
                if 'time' in mapDicts[map][steamid]:
                    (_pos, _len) = mk_sortDictIndex(map, steamid)
                    mapsdone.addoption(map, '%s - #%s %s' % (str(map), _pos, formatTime5(mapDicts[map][steamid]['time'])))
                    lx += 1
                
        if lx == 0:
            mapsdone.addoption(None, '[ No maps done ]')
        
        mapsdone.settitle('Player %s has finished %s maps\nStyle: Normal        ' % (name, str(lx)))
        mapsdone.unsend(userid)
        mapsdone.send(userid)
		
    if choice == 2:
        mapsleft = popuplib.easymenu('mapsleftm', None, mapsdonehandler)
        mapsleft.settitle('Maps left \nStyle: Normal        ')
        lx = 0
        for map in sorted(mapDicts):
            if steamid in mapDicts[map]:
                if 'time' not in mapDicts[map][steamid]:
                    mapsleft.addoption(map, '%s - %s pts' %(str(map), mapscore[map]))
                    lx += 1
            if steamid not in mapDicts[map]:
                mapsleft.addoption(map, '%s - %s pts' %(str(map), mapscore[map]))
                lx += 1
        
        if lx == 0:
            mapsleft.addoption(None, '[ All maps completed !]')
        
        mapsleft.settitle('Player %s has %s maps left \nStyle: Normal        ' % (name, str(lx)))
        mapsleft.unsend(userid)
        mapsleft.send(userid)

		
    if choice == 3:
        mapsdonesw = popuplib.easymenu('mapsdonemsw', None, mapsdonehandler)
        mapsdonesw.settitle('Maps Completed\nStyle: SideWays        ')
        lx = 0
        for map in sorted(mapDicts):
            if steamid in mapDicts[map]:
                if 'sideways' in mapDicts[map][steamid]:
                    if 'timesw' in mapDicts[map][steamid]['sideways']:
                        (_pos, _len) = mk_sortDictIndexsw(map, steamid)
                        mapsdonesw.addoption(map, '%s - #%s %s' % (str(map), _pos, formatTime5(mapDicts[map][steamid]['sideways']['timesw'])))
                        lx += 1
     
        if lx == 0:
            mapsdonesw.addoption(None, '[ No maps done ]')
        
        mapsdonesw.settitle('Player %s has finished %s maps\nStyle: SideWays        ' % (name, str(lx)))
        mapsdonesw.unsend(userid)
        mapsdonesw.send(userid)
		
    if choice == 4:
        mapsleftsw = popuplib.easymenu('mapsleftmsw', None, mapsdonehandler)
        mapsleftsw.settitle('Maps left\nStyle: SideWays        ')
        lx = 0
        for map in sorted(mapDicts):
            if steamid in mapDicts[map]:
                if 'sideways' not in mapDicts[map][steamid]:
                    mapsleftsw.addoption(map, '%s - %s pts' % (str(map), mapscore[map]*1.5))
                    lx += 1
                
            if steamid not in mapDicts[map]:
                mapsleftsw.addoption(map, '%s - %s pts' % (str(map), mapscore[map]*1.5))
                lx += 1
        
        if lx == 0:
            mapsleftsw.addoption(None, '[ All maps completed !]')
        
        mapsleftsw.settitle('Player %s has %s maps left\nStyle: SideWays        ' % (name, str(lx)))
        mapsleftsw.unsend(userid)
        mapsleftsw.send(userid)
		
    if choice == 5:
        mapsdonew = popuplib.easymenu('mapsdonemw', None, mapsdonehandler)
        mapsdonew.settitle('Maps Completed\nStyle: W-Only        ')
        lx = 0
        for map in sorted(mapDicts):
            if steamid in mapDicts[map]:
                if 'wonly' in mapDicts[map][steamid]:
                    if 'timew' in mapDicts[map][steamid]['wonly']:
                        (_pos, _len) = mk_sortDictIndexw(map, steamid)
                        mapsdonew.addoption(map, '%s - #%s %s' % (str(map), _pos, formatTime5(mapDicts[map][steamid]['wonly']['timew'])))
                        lx += 1
       
        if lx == 0:
            mapsdonew.addoption(None, '[ No maps done ]')
        
        mapsdonew.settitle('Player %s has finished %s maps\nStyle: W-Only        ' % (name, str(lx)))
        mapsdonew.unsend(userid)
        mapsdonew.send(userid)
		
    if choice == 6:
        mapsleftw = popuplib.easymenu('mapsleftmw', None, mapsdonehandler)
        mapsleftw.settitle('Maps left\nStyle: W-Only        ')
        lx = 0
        for map in sorted(mapDicts):
            if steamid in mapDicts[map]:
                if 'wonly' not in mapDicts[map][steamid]:
                    mapsleftw.addoption(map, '%s - %s pts' % (str(map), mapscore[map]*1.5))
                    lx += 1
                
            if steamid not in mapDicts[map]:
                mapsleftw.addoption(map, '%s - %s pts' % (str(map), mapscore[map]*1.5))
                lx += 1
        
        if lx == 0:
            mapsleftw.addoption(None, '[ All maps completed !]')
        
        mapsleftw.settitle('Player %s has %s maps left\nStyle: W-Only        ' % (name, str(lx)))
        mapsleftw.unsend(userid)
        mapsleftw.send(userid)
		

def maplistcommand(userid, args):
    steamid = es.getplayersteamid(userid)
    maplist = popuplib.easymenu('maplists', None, mapsdonehandler)
    maplist.settitle('Map List')
    lx = 0
    for map in sorted(mapDicts):
        if map not in mapscore:
            mapscore[map] = 0.0
        maplist.addoption(map, '%s - %s' %(map, mapscore[map]))
        lx += 1
    allpoints = 0
    totalpointsn = 0
    totalpointssw = 0
    totalpointsw = 0
    totalpoints = 0
    for maps in mapscore:
        allpoints += mapscore[maps]
        totalpointsn += mapscore[maps] + 20
        totalpointssw += (mapscore[maps]*1.5) + 20
        totalpointsw += (mapscore[maps]*1.5) + 20
        totalpoints = totalpointsn + totalpointssw + totalpointsw
    maplist.settitle('%s Maps worth %s Points\nMaximum reachable points (Normal): %s\nMaximum reachable points (SideWays): %s\nMaximum reachable points (W-Only): %s\nMaximum reachable points (Total): %s'%(str(lx), allpoints, totalpointsn, totalpointssw, totalpointsw, totalpoints))
    maplist.unsend(userid)
    maplist.send(userid)

def bonuslistcommand(userid, args):
    steamid = es.getplayersteamid(userid)
    bonuslist = popuplib.easymenu('bonuslists', None, mapsdonehandler)
    bonuslist.settitle('Map Bonus Available:')
    lx = 0
    for map in sorted(bonusDicts):
        bonuslist.addoption(map, '%s' %map)
        lx += 1
    bonuslist.settitle('%s Map Bonus Available:'%str(lx))
    bonuslist.unsend(userid)
    bonuslist.send(userid)

def choicehandler(userid, choice, popupname):
    statscommandnew(userid, choice)


def mapsdoneplayerhandler(userid, choice, popupid):
    es.server.queuecmd('es_sexec %s "say !nominate %s"' %(userid, choice))
    popuplib.send('mapsdone', userid)

 
def hudhint(userid, text):
    es.usermsg("create", "_hint_text", "HintText")
    es.usermsg("write",  "string", "_hint_text", str(text))
    es.usermsg("send",   "_hint_text", userid)
    es.usermsg("delete", "_hint_text")

def getSpectargetByIndex(index):
    for userid in filter(lambda temp: not es.getplayerprop(temp, "CCSPlayer.baseclass.pl.deadflag"), es.getUseridList()):
        if es.getplayerhandle(userid) == index:
            return userid
    return -1

def effectloop1():
    model="materials/sprites/failtime1.vmt"
    halo="materials/sprites/halo01.vmt"
    x1,y1,z1 = mapDicts[str(currentMap)]["startpos"][0]
    x2,y2,z2 = mapDicts[str(currentMap)]["startpos"][1]
    slinea1 = x1,y1,z1+10
    slinea2 = x2,y1,z1+10
    effectlib.drawLine(slinea1, slinea2, model, halo, width=2, endwidth=1, red=255, green=255, blue=255, seconds=1)

    slineb1 = x2,y1,z1+10
    slineb2 = x2,y2,z1+10
    effectlib.drawLine(slineb1, slineb2, model, halo, width=2, endwidth=1, red=255, green=255, blue=255, seconds=1)

    slinec1 = x2,y2,z1+10
    slinec2 = x1,y2,z1+10
    effectlib.drawLine(slinec1, slinec2, model, halo, width=2, endwidth=1, red=255, green=255, blue=255, seconds=1)

    slined1 = x1,y2,z1+10
    slined2 = x1,y1,z1+10
    effectlib.drawLine(slined1, slined2, model, halo, width=2, endwidth=1, red=255, green=255, blue=255, seconds=1)

    model="materials/sprites/failtime1.vmt"
    halo="materials/sprites/halo01.vmt"
    x1,y1,z1 = mapDicts[str(currentMap)]["endpos"][0]
    x2,y2,z2 = mapDicts[str(currentMap)]["endpos"][1]
    slinea1 = x1,y1,z1+10
    slinea2 = x2,y1,z1+10
    effectlib.drawLine(slinea1, slinea2, model, halo, width=2, endwidth=1, red=255, green=0, blue=0, seconds=1)

    slineb1 = x2,y1,z1+10
    slineb2 = x2,y2,z1+10
    effectlib.drawLine(slineb1, slineb2, model, halo, width=2, endwidth=1, red=255, green=0, blue=0, seconds=1)

    slinec1 = x2,y2,z1+10
    slinec2 = x1,y2,z1+10
    effectlib.drawLine(slinec1, slinec2, model, halo, width=2, endwidth=1, red=255, green=0, blue=0, seconds=1)

    slined1 = x1,y2,z1+10
    slined2 = x1,y1,z1+10
    effectlib.drawLine(slined1, slined2, model, halo, width=2, endwidth=1, red=255, green=0, blue=0, seconds=1)
    gamethread.delayedname(0.5, 'effect_loop1', effectloop1)

def effectloop2():
    model="materials/sprites/failtime1.vmt"
    halo="materials/sprites/halo01.vmt"
    x1,y1,z1 = bonusDicts[str(currentMap)]["startposb"][0]
    x2,y2,z2 = bonusDicts[str(currentMap)]["startposb"][1]
    slinea1 = x1,y1,z1+10
    slinea2 = x2,y1,z1+10
    effectlib.drawLine(slinea1, slinea2, model, halo, width=2, endwidth=1, red=255, green=255, blue=255, seconds=1)

    slineb1 = x2,y1,z1+10
    slineb2 = x2,y2,z1+10
    effectlib.drawLine(slineb1, slineb2, model, halo, width=2, endwidth=1, red=255, green=255, blue=255, seconds=1)

    slinec1 = x2,y2,z1+10
    slinec2 = x1,y2,z1+10
    effectlib.drawLine(slinec1, slinec2, model, halo, width=2, endwidth=1, red=255, green=255, blue=255, seconds=1)

    slined1 = x1,y2,z1+10
    slined2 = x1,y1,z1+10
    effectlib.drawLine(slined1, slined2, model, halo, width=2, endwidth=1, red=255, green=255, blue=255, seconds=1)

    x1,y1,z1 = bonusDicts[str(currentMap)]["endposb"][0]
    x2,y2,z2 = bonusDicts[str(currentMap)]["endposb"][1]
    slinea1 = x1,y1,z1+10
    slinea2 = x2,y1,z1+10
    effectlib.drawLine(slinea1, slinea2, model, halo, width=2, endwidth=1, red=255, green=0, blue=0, seconds=1)

    slineb1 = x2,y1,z1+10
    slineb2 = x2,y2,z1+10
    effectlib.drawLine(slineb1, slineb2, model, halo, width=2, endwidth=1, red=255, green=0, blue=0, seconds=1)

    slinec1 = x2,y2,z1+10
    slinec2 = x1,y2,z1+10
    effectlib.drawLine(slinec1, slinec2, model, halo, width=2, endwidth=1, red=255, green=0, blue=0, seconds=1)

    slined1 = x1,y2,z1+10
    slined2 = x1,y1,z1+10
    effectlib.drawLine(slined1, slined2, model, halo, width=2, endwidth=1, red=255, green=0, blue=0, seconds=1)
    gamethread.delayedname(1, 'effect_loop2', effectloop2)

def acLoop():
    for player in es.getUseridList():
        steamid = es.getplayersteamid(player)
        if (steamid in started) and (int(es.getplayerteam(player)) > 1):
            lowerVertex, upperVertex = mapDicts[str(currentMap)]["startpos"]
            if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                x1 = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[0]')
                y1 = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[1]')
                z1 = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[2]')
                speed = round((x1*x1 + y1*y1 + z1*z1)**0.5, 2)
                x = es.getplayerprop(player, "CBasePlayer.localdata.m_vecVelocity[0]") * -1
                y = es.getplayerprop(player, "CBasePlayer.localdata.m_vecVelocity[1]") * -1
                z = es.getplayerprop(player, "CBasePlayer.localdata.m_vecVelocity[2]") * -1


            if str(currentMap) in acDicts:
                acloc1, acloc2 = acDicts[str(currentMap)]["anticheat"]
                if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                    started.remove(steamid)
                    tell(player, "stop timer cheating")
					
            if str(currentMap) in acDicts:
                if 'anticheat2' not in acDicts[str(currentMap)]:
                    continue
                else:
                    acloc1, acloc2 = acDicts[str(currentMap)]["anticheat2"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                        started.remove(steamid)
                        tell(player, "stop timer cheating")
					
            if str(currentMap) in acDicts:
                if 'anticheat3' not in acDicts[str(currentMap)]:
                    continue
                else:
                    acloc1, acloc2 = acDicts[str(currentMap)]["anticheat3"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                        started.remove(steamid)
                        tell(player, "stop timer cheating")
					
            if str(currentMap) in acDicts:
                if 'anticheat4' not in acDicts[str(currentMap)]:
                    continue
                else:
                    acloc1, acloc2 = acDicts[str(currentMap)]["anticheat4"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                        started.remove(steamid)
                        tell(player, "stop timer cheating")
					
            if str(currentMap) in acDicts:
                if 'anticheat5' not in acDicts[str(currentMap)]:
                    continue
                else:
                    acloc1, acloc2 = acDicts[str(currentMap)]["anticheat5"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                        started.remove(steamid)
                        tell(player, "stop timer cheating")

        if (steamid in startedb) and (int(es.getplayerteam(player)) > 1):
            lowerVertex, upperVertex = bonusDicts[str(currentMap)]["startposb"]
            if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                x1 = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[0]')
                y1 = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[1]')
                z1 = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[2]')
                speed = round((x1*x1 + y1*y1 + z1*z1)**0.5, 2)
                x = es.getplayerprop(player, "CBasePlayer.localdata.m_vecVelocity[0]") * -1
                y = es.getplayerprop(player, "CBasePlayer.localdata.m_vecVelocity[1]") * -1
                z = es.getplayerprop(player, "CBasePlayer.localdata.m_vecVelocity[2]") * -1


            if str(currentMap) in acDicts:
                acloc1, acloc2 = acDicts[str(currentMap)]["anticheat"]
                if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                    startedb.remove(steamid)
                    tell(player, "stop timer cheating")
					
            if str(currentMap) in acDicts:
                if 'anticheat2' not in acDicts[str(currentMap)]:
                    continue
                else:
                    acloc1, acloc2 = acDicts[str(currentMap)]["anticheat2"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                        startedb.remove(steamid)
                        tell(player, "stop timer cheating")
					
            if str(currentMap) in acDicts:
                if 'anticheat3' not in acDicts[str(currentMap)]:
                    continue
                else:
                    acloc1, acloc2 = acDicts[str(currentMap)]["anticheat3"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                        startedb.remove(steamid)
                        tell(player, "stop timer cheating")
					
            if str(currentMap) in acDicts:
                if 'anticheat4' not in acDicts[str(currentMap)]:
                    continue
                else:
                    acloc1, acloc2 = acDicts[str(currentMap)]["anticheat4"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                        startedb.remove(steamid)
                        tell(player, "stop timer cheating")
					
            if str(currentMap) in acDicts:
                if 'anticheat5' not in acDicts[str(currentMap)]:
                    continue
                else:
                    acloc1, acloc2 = acDicts[str(currentMap)]["anticheat5"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), acloc1, acloc2):
                        startedb.remove(steamid)
                        tell(player, "stop timer cheating")

    gamethread.delayedname(0.05, 'climbtime_acloop', acLoop)
	
	
def getSpecTarget(index):
    for userid in filter(lambda temp: not es.getplayerprop(temp, 'CCSPlayer.baseclass.pl.deadflag'), es.getUseridList()):
        if es.getplayerhandle(userid) == index:
            return userid
            continue
    return -1
	
def hudLoop():
    for player in es.getUseridList():
        steamid = es.getplayersteamid(player)
        if es.getplayerprop(player, 'CCSPlayer.baseclass.pl.deadflag'):
            if int(es.getplayerprop(player, 'CCSPlayer.baseclass.m_iObserverMode')) in (1, 3, 4):
                uid = getSpecTarget(es.getplayerprop(player, 'CBasePlayer.m_hObserverTarget'))
                if uid == -1: continue
                ssid = es.getplayersteamid(uid)
                if uid not in players: continue  
                
                targetname = es.getplayername(uid)
                timeUsed = time.time() - players[uid][0]
                timeLeft = formatTime5(timeUsed)
                if ssid in started:
                    (lowerVertex, upperVertex) = mapDicts[str(currentMap)]['startpos']
                    if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                        if styles[uid]['normal'] == 1:
                            hudhint(player, tell(player, 'spec timer start zone', {
                                'name': targetname,
                                'stylestart': "Style: Normal" }, False))
                            continue
                        if styles[uid]['sideways'] == 1:
                            hudhint(player, tell(player, 'spec timer start zone', {
                                'name': targetname,
                                'stylestart': "Style: SideWays" }, False))
                            continue
                        if styles[uid]['wonly'] == 1:
                            hudhint(player, tell(player, 'spec timer start zone', {
                                'name': targetname,
                                'stylestart': "Style: W-Only" }, False))
                            continue
                    elif styles[uid]['normal'] == 1:
                        style = 'Style: Normal\n '
                    
                    if styles[uid]['sideways'] == 1:
                        style = 'Style: SideWays\n '
                    
                    if styles[uid]['wonly'] == 1:
                        style = 'Style: W-Only\n '
                    
                    if styles[uid]['normal'] == 1:
                        if TOP_TIME != 0:
                            toptime = TOP_TIME - timeUsed
                            sign = '-'
                            if TOP_TIME < timeUsed:
                                toptime = timeUsed - TOP_TIME
                                sign = '+'
                            ftoptime = formatTime5(toptime)
                        else:
                            ftoptime = ''
                            sign = ''
                        if ssid in mapDicts[str(currentMap)]:
                            if 'time' in mapDicts[str(currentMap)][ssid]:
                                playerbest = formatTime5(mapDicts[str(currentMap)][ssid]['time'])
                            else:
                                playerbest = '-'
                        else:
                            playerbest = '-'
                    
                    if styles[uid]['sideways'] == 1:
                        if TOP_TIME_SW != 0:
                            toptime = TOP_TIME_SW - timeUsed
                            sign = '-'
                            if TOP_TIME_SW < timeUsed:
                                toptime = timeUsed - TOP_TIME_SW
                                sign = '+'
                            ftoptime = formatTime5(toptime)
                        else:
                            ftoptime = ''
                            sign = ''
                        if ssid in mapDicts[str(currentMap)]:
                            if 'sideways' in mapDicts[str(currentMap)][ssid]:
                                if 'timesw' in mapDicts[str(currentMap)][ssid]['sideways']:
                                    playerbest = formatTime5(mapDicts[str(currentMap)][ssid]['sideways']['timesw'])
                                else:
                                    playerbest = '-'
                            else:
                                playerbest = '-'
                        else:
                            playerbest = '-'
                    
                    if styles[uid]['wonly'] == 1:
                        if TOP_TIME_W != 0:
                            toptime = TOP_TIME_W - timeUsed
                            sign = '-'
                            if TOP_TIME_W < timeUsed:
                                toptime = timeUsed - TOP_TIME_W
                                sign = '+'
                            ftoptime = formatTime5(toptime)
                        else:
                            ftoptime = ''
                            sign = ''
                        if ssid in mapDicts[str(currentMap)]:
                            if 'wonly' in mapDicts[str(currentMap)][ssid]:
                                if 'timew' in mapDicts[str(currentMap)][ssid]['wonly']:
                                    playerbest = formatTime5(mapDicts[str(currentMap)][ssid]['wonly']['timew'])
                                else:
                                    playerbest = '-'
                            else:
                                playerbest = '-'
                        else:
                            playerbest = '-'
							
                    if ssid in strafes:
                        strafescounter = strafes[ssid]['count']
                    else:
                        strafescounter = 0
                    
                    hudhint(player, tell(player, 'spec timer', {
                        'name': targetname,
                        'best': playerbest,
                        'playerstyle': style,
                        'time': timeLeft,
                        'sign': sign,
                        'first': ftoptime,
                        'jumps': players[uid][1],
                        'strafes': strafescounter,
                        'vel': getSpeed(uid) }, False))
                    continue
					
                if ssid in startedb:
                    (lowerVertex, upperVertex) = bonusDicts[str(currentMap)]['startposb']
                    if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                        if styles[uid]['normal'] == 1:
                            hudhint(player, tell(player, 'spec bonus start zone', {
                                'name': targetname,
                                'stylestart': "Style: Normal" }, False))
                            continue
                        if styles[uid]['sideways'] == 1:
                            hudhint(player, tell(player, 'spec bonus start zone', {
                                'name': targetname,
                                'stylestart': "Style: SideWays" }, False))
                            continue
                        if styles[uid]['wonly'] == 1:
                            hudhint(player, tell(player, 'spec bonus start zone', {
                                'name': targetname,
                                'stylestart': "Style: W-Only" }, False))
                            continue
                    elif styles[uid]['normal'] == 1:
                        style = 'Style: Normal\n '
                    
                    if styles[uid]['sideways'] == 1:
                        style = 'Style: SideWays\n '
                    
                    if styles[uid]['wonly'] == 1:
                        style = 'Style: W-Only\n '
                    
                    if styles[uid]['normal'] == 1:
                        if TOP_TIME_B != 0:
                            toptime = TOP_TIME_B - timeUsed
                            sign = '-'
                            if TOP_TIME_B < timeUsed:
                                toptime = timeUsed - TOP_TIME_B
                                sign = '+'
                            ftoptime = formatTime5(toptime)
                        else:
                            ftoptime = ''
                            sign = ''
                        if ssid in bonusDicts[str(currentMap)]:
                            if 'timeb' in bonusDicts[str(currentMap)][ssid]:
                                playerbest = formatTime5(bonusDicts[str(currentMap)][ssid]['timeb'])
                            else:
                                playerbest = '-'
                        else:
                            playerbest = '-'
                    
                    if styles[uid]['sideways'] == 1:
                        if TOP_TIME_BSW != 0:
                            toptime = TOP_TIME_BSW - timeUsed
                            sign = '-'
                            if TOP_TIME_BSW < timeUsed:
                                toptime = timeUsed - TOP_TIME_BSW
                                sign = '+'
                            ftoptime = formatTime5(toptime)
                        else:
                            ftoptime = ''
                            sign = ''
                        if ssid in bonusDicts[str(currentMap)]:
                            if 'sideways' in bonusDicts[str(currentMap)][ssid]:
                                if 'timebsw' in bonusDicts[str(currentMap)][ssid]['sideways']:
                                    playerbest = formatTime5(bonusDicts[str(currentMap)][ssid]['sideways']['timebsw'])
                                else:
                                    playerbest = '-'
                            else:
                                playerbest = '-'
                        else:
                            playerbest = '-'
                    
                    if styles[uid]['wonly'] == 1:
                        if TOP_TIME_BW != 0:
                            toptime = TOP_TIME_BW - timeUsed
                            sign = '-'
                            if TOP_TIME_BW < timeUsed:
                                toptime = timeUsed - TOP_TIME_BW
                                sign = '+'
                            ftoptime = formatTime5(toptime)
                        else:
                            ftoptime = ''
                            sign = ''
                        if ssid in bonusDicts[str(currentMap)]:
                            if 'wonly' in bonusDicts[str(currentMap)][ssid]:
                                if 'timebw' in bonusDicts[str(currentMap)][ssid]['wonly']:
                                    playerbest = formatTime5(bonusDicts[str(currentMap)][ssid]['wonly']['timebw'])
                                else:
                                    playerbest = '-'
                            else:
                                playerbest = '-'
                        else:
                            playerbest = '-'
							
                    if ssid in strafes:
                        strafescounter = strafes[ssid]['count']
                    else:
                        strafescounter = 0
                    
                    hudhint(player, tell(player, 'spec timer', {
                        'name': targetname,
                        'best': playerbest,
                        'playerstyle': style,
                        'time': timeLeft,
                        'sign': sign,
                        'first': ftoptime,
                        'jumps': players[uid][1],
                        'strafes': strafescounter,
                        'vel': getSpeed(uid) }, False))
                    continue

        if steamid not in started and steamid not in startedb:
            playertag = SPEPlayer(player)
            playertag.set_clantag("INACTIVE")
            hudhint(player, tell(player, 'timer with speed', {
                'vel': getSpeed(player) }, False))
            continue
        
        if player not in players:
            continue
        
        playerid = es.getplayersteamid(player)
        timeUsed = time.time() - players[player][0]
        timeLeft = formatTime5(timeUsed)
        playertag = SPEPlayer(player)
        if steamid in started:
            (lowerVertex, upperVertex) = mapDicts[str(currentMap)]['startpos']
            if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                playertag.set_clantag("START ZONE")
                if styles[player]['normal'] == 1:
                    hudhint(player, tell(player, 'timer start zone', {
                        'stylestart': "Style: Normal" }, False))
                    continue
                if styles[player]['sideways'] == 1:
                    hudhint(player, tell(player, 'timer start zone', {
                        'stylestart': "Style: SideWays" }, False))
                    continue
                if styles[player]['wonly'] == 1:
                    hudhint(player, tell(player, 'timer start zone', {
                        'stylestart': "Style: W-Only" }, False))
                    continue
            elif styles[player]['normal'] == 1:
                noprespeed = 'Style: Normal\n '
                playertag.set_clantag("N %s" % formatTime2(timeUsed))
                
            if styles[player]['sideways'] == 1:
                noprespeed = 'Style: SideWays\n '
                playertag.set_clantag("SW %s" % formatTime2(timeUsed))
                
            if styles[player]['wonly'] == 1:
                noprespeed = 'Style: W-Only\n '
                playertag.set_clantag("W %s" % formatTime2(timeUsed))
                
            
            if styles[player]['normal'] == 1:
                if TOP_TIME != 0:
                    toptime = TOP_TIME - timeUsed
                    sign = '-'
                    if TOP_TIME < timeUsed:
                        toptime = timeUsed - TOP_TIME
                        sign = '+'
                    ftoptime = formatTime5(toptime)
                else:
                    ftoptime = ' '
                    sign = ' '
                if playerid in mapDicts[str(currentMap)]:
                    if 'time' in mapDicts[str(currentMap)][playerid]:
                        playerbest = formatTime5(mapDicts[str(currentMap)][playerid]['time'])
                    else:
                        playerbest = '-'
                else:
                    playerbest = '-'
            
            if styles[player]['sideways'] == 1:
                if TOP_TIME_SW != 0:
                    toptime = TOP_TIME_SW - timeUsed
                    sign = '-'
                    if TOP_TIME_SW < timeUsed:
                        toptime = timeUsed - TOP_TIME_SW
                        sign = '+'
                    ftoptime = formatTime5(toptime)
                else:
                    ftoptime = ' '
                    sign = ' '
                if playerid in mapDicts[str(currentMap)]:
                    if 'sideways' in mapDicts[str(currentMap)][playerid]:
                        if 'timesw' in mapDicts[str(currentMap)][playerid]['sideways']:
                            playerbest = formatTime5(mapDicts[str(currentMap)][playerid]['sideways']['timesw'])
                        else:
                            playerbest = '-'
                    else:
                        playerbest = '-'
                else:
                    playerbest = '-'
            
            if styles[player]['wonly'] == 1:
                if TOP_TIME_W != 0:
                    toptime = TOP_TIME_W - timeUsed
                    sign = '-'
                    if TOP_TIME_W < timeUsed:
                        toptime = timeUsed - TOP_TIME_W
                        sign = '+'
                    ftoptime = formatTime5(toptime)
                else:
                    ftoptime = ' '
                    sign = ' '
                if playerid in mapDicts[str(currentMap)]:
                    if 'wonly' in mapDicts[str(currentMap)][playerid]:
                        if 'timew' in mapDicts[str(currentMap)][playerid]['wonly']:
                            playerbest = formatTime5(mapDicts[str(currentMap)][playerid]['wonly']['timew'])
                        else:
                            playerbest = '-'
                    else:
                        playerbest = '-'
                else:
                    playerbest = '-'
            if steamid in strafes:
                strafescounter = strafes[steamid]['count']
            else:
                strafescounter = 0
				
            hudhint(player, tell(player, 'timer with jump counter', {
                'playerstyle': noprespeed,
                'time': timeLeft,
                'sign': sign,
                'first': ftoptime,
                'best': playerbest,
                'jumps': players[player][1],
                'strafes': strafescounter,
                'vel': getSpeed(player) }, False))
            continue
        if steamid in startedb:
            (lowerVertex, upperVertex) = bonusDicts[str(currentMap)]['startposb']
            if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                playertag.set_clantag("BONUS START")
                if styles[player]['normal'] == 1:
                    hudhint(player, tell(player, 'bonus timer start zone', {
                        'stylestart': "Style: Normal" }, False))
                    continue
                if styles[player]['sideways'] == 1:
                    hudhint(player, tell(player, 'bonus timer start zone', {
                        'stylestart': "Style: SideWays" }, False))
                    continue
                if styles[player]['wonly'] == 1:
                    hudhint(player, tell(player, 'bonus timer start zone', {
                        'stylestart': "Style: W-Only" }, False))
                    continue
            elif styles[player]['normal'] == 1:
                noprespeed = 'Style: Normal\n '
                playertag.set_clantag("BN %s" % formatTime2(timeUsed))
                
            if styles[player]['sideways'] == 1:
                noprespeed = 'Style: SideWays\n '
                playertag.set_clantag("BSW %s" % formatTime2(timeUsed))
                
            if styles[player]['wonly'] == 1:
                noprespeed = 'Style: W-Only\n '
                playertag.set_clantag("BW %s" % formatTime2(timeUsed))
				
            if styles[player]['normal'] == 1:
                if TOP_TIME_B != 0:
                    toptime = TOP_TIME_B - timeUsed
                    sign = '-'
                    if TOP_TIME_B < timeUsed:
                        toptime = timeUsed - TOP_TIME_B
                        sign = '+'
                    ftoptime = formatTime5(toptime)
                else:
                    ftoptime = ' '
                    sign = ' '
                if playerid in bonusDicts[str(currentMap)]:
                    if 'timeb' in bonusDicts[str(currentMap)][playerid]:
                        playerbestb = formatTime5(bonusDicts[str(currentMap)][playerid]['timeb'])
                    else:
                        playerbestb = '-'
                else:
                    playerbestb = '-'
					
            if styles[player]['wonly'] == 1:
                if TOP_TIME_BW != 0:
                    toptime = TOP_TIME_BW - timeUsed
                    sign = '-'
                    if TOP_TIME_BW < timeUsed:
                        toptime = timeUsed - TOP_TIME_BW
                        sign = '+'
                    ftoptime = formatTime5(toptime)
                else:
                    ftoptime = ' '
                    sign = ' '
                if playerid in bonusDicts[str(currentMap)]:
                    if 'wonly' in bonusDicts[str(currentMap)][playerid]:
                        if 'timebw' in bonusDicts[str(currentMap)][playerid]['wonly']:
                            playerbestb = formatTime5(bonusDicts[str(currentMap)][playerid]['wonly']['timebw'])
                        else:
                            playerbestb = '-'
                    else:
                        playerbestb = '-'
                else:
                    playerbestb = '-'
					
            if styles[player]['sideways'] == 1:
                if TOP_TIME_BSW != 0:
                    toptime = TOP_TIME_BSW - timeUsed
                    sign = '-'
                    if TOP_TIME_BSW < timeUsed:
                        toptime = timeUsed - TOP_TIME_BSW
                        sign = '+'
                    ftoptime = formatTime5(toptime)
                else:
                    ftoptime = ' '
                    sign = ' '
                if playerid in bonusDicts[str(currentMap)]:
                    if 'sideways' in bonusDicts[str(currentMap)][playerid]:
                        if 'timebsw' in bonusDicts[str(currentMap)][playerid]['sideways']:
                            playerbestb = formatTime5(bonusDicts[str(currentMap)][playerid]['sideways']['timebsw'])
                        else:
                            playerbestb = '-'
                    else:
                        playerbestb = '-'
                else:
                    playerbestb = '-'
					

            if steamid in strafes:
                strafescounter = strafes[steamid]['count']
            else:
                strafescounter = 0
            hudhint(player, tell(player, 'bonus timer with jump counter', {
                'nopre': noprespeed,
                'time': timeLeft,
                'sign': sign,
                'best': playerbestb,
                'first': ftoptime,
                'jumps': players[player][1],
                'strafes': strafescounter,
                'vel': getSpeed(player) }, False))
            continue

    gamethread.delayedname(0.05, 'hud_loop', hudLoop)
	
lol = 1
def checkLoop():
    global TOP_TIME, TOP_TIME_W, TOP_TIME_SW, TOP_TIME_B, TOP_TIME_BW, TOP_TIME_BSW
    try:
        for player in es.getUseridList():
            steamid = es.getplayersteamid(player)
            ssteamid = es.getplayersteamid(player)
            if (steamid in started):
                if ssteamid in startedb: startedb.remove(ssteamid)
                es.server.queuecmd('es_fire %s !self addoutput "gravity 1"' % player)
                lowerVertex, upperVertex = mapDicts[str(currentMap)]["endpos"]
                if steamid not in strafes:
                    strafes[steamid] = {
                        'on': 0,
                        'count': 0 }
                
                if es.getplayerprop(player, 'CCSPlayer.baseclass.localdata.m_hGroundEntity') != -1:
                    strafes[steamid]['on'] = 0
                else:
                    strafes[steamid]['on'] = 1
                if player not in players:
                    continue
                timeTaken = time.time() - players[player][0]
                if steamid not in speeddict:
                    speeddict[steamid] = {'speedadded':0, 'numberofspeeds':0, 'maxspeed':0}
                speeddict[steamid]["numberofspeeds"] = speeddict[steamid]["numberofspeeds"] + 1
                x = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[0]')
                y = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[1]')
                z = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[2]')
                total_speed = sqrt(y ** 2 + x ** 2 + z ** 2)
                speeddict[steamid]["speedadded"] = speeddict[steamid]["speedadded"] + total_speed
                if total_speed > speeddict[steamid]["maxspeed"]: speeddict[steamid]["maxspeed"] = total_speed
                if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                    overwrite = 0
                    improve = 0
                    double_check = 0
                    if steamid not in mapDicts[str(currentMap)]:
                        mapDicts[str(currentMap)][steamid] = {}
                        if styles[player]['normal'] == 1:
                            mapDicts[str(currentMap)][steamid] = {'time':timeTaken, 'name':es.getplayername(player), 'jumps':players[player][1], 'date': strftime('%x %X'), 'strafes': strafes[steamid]['count']}
                            overwrite = 2
                            r_addpoints(str(currentMap), steamid)
                            tell(player, 'got points normal', {'points':mapscore[str(currentMap)], 'map':str(currentMap)})
                            (_pos, _len) = mk_sortDictIndex(str(currentMap), steamid)
                            if _pos > 2:
                                double_check = 1
                                tell(player, 'finished normal private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                        if styles[player]['wonly'] == 1:
                            mapDicts[str(currentMap)][steamid]['wonly'] = {'timew':timeTaken, 'namew':es.getplayername(player), 'jumpsw':players[player][1], 'datew': strftime('%x %X'), 'strafesw': strafes[steamid]['count']}
                            overwrite = 2
                            (_pos, _len) = mk_sortDictIndexw(str(currentMap), steamid)
                            r_addwpoints(str(currentMap), steamid)
                            tell(player, 'got points w-only', {'points':mapscore[str(currentMap)] * 1.5, 'map':str(currentMap)})
                            if _pos > 2:
                                double_check = 1
                                es.tell(player, '#multi', 'finished w only private')
                        if styles[player]['sideways'] == 1:
                            mapDicts[str(currentMap)][steamid]['sideways'] = {'timesw':timeTaken, 'namesw':es.getplayername(player), 'jumpssw':players[player][1], 'datesw': strftime('%x %X'), 'strafessw': strafes[steamid]['count']}
                            overwrite = 2
                            (_pos, _len) = mk_sortDictIndexw(str(currentMap), steamid)
                            r_addswpoints(str(currentMap), steamid)
                            tell(player, 'got points sideways', {'points':mapscore[str(currentMap)] * 1.5, 'map':str(currentMap)})
                            if _pos > 2:
                                double_check = 1
                                es.tell(player, '#multi', 'finished sideways private')
                    else:
                        if styles[player]['normal'] == 1:
                            if 'time' in mapDicts[str(currentMap)][steamid]:
                                if mapDicts[str(currentMap)][steamid]['time'] > timeTaken:
                                    improve = formatTime5(mapDicts[str(currentMap)][steamid]['time'] - timeTaken)
                                    mapDicts[str(currentMap)][steamid]['time']  = timeTaken
                                    mapDicts[str(currentMap)][steamid]['jumps'] = players[player][1]
                                    mapDicts[str(currentMap)][steamid]['name']  = es.getplayername(player)
                                    mapDicts[str(currentMap)][steamid]['date'] = strftime('%x %X')
                                    mapDicts[str(currentMap)][steamid]['strafes'] = strafes[steamid]['count']
                                    overwrite = 1
                                else:
                                    tell(player, 'finished normal private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                                    tell(player, 'no new record')
                            else:
                                mapDicts[str(currentMap)][steamid]['time']  = timeTaken
                                mapDicts[str(currentMap)][steamid]['jumps'] = players[player][1]
                                mapDicts[str(currentMap)][steamid]['name']  = es.getplayername(player)
                                mapDicts[str(currentMap)][steamid]['date'] = strftime('%x %X')
                                mapDicts[str(currentMap)][steamid]['strafes'] = strafes[steamid]['count']
                                overwrite = 2
                                r_addpoints(str(currentMap), steamid)
                                tell(player, 'got points normal', {'points':mapscore[str(currentMap)], 'map':str(currentMap)})
                                (_pos, _len) = mk_sortDictIndex(str(currentMap), steamid)
                                if _pos > 2:
                                    double_check = 1
                                    tell(player, 'finished normal private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
									
                        if styles[player]['wonly'] == 1:
                            if 'wonly' in mapDicts[str(currentMap)][steamid]:
                                if mapDicts[str(currentMap)][steamid]['wonly']['timew'] > timeTaken:
                                    improve = formatTime5(mapDicts[str(currentMap)][steamid]['wonly']['timew'] - timeTaken)
                                    mapDicts[str(currentMap)][steamid]['wonly']['timew']  = timeTaken
                                    mapDicts[str(currentMap)][steamid]['wonly']['jumpsw'] = players[player][1]
                                    mapDicts[str(currentMap)][steamid]['wonly']['namew']  = es.getplayername(player)
                                    mapDicts[str(currentMap)][steamid]['wonly']['datew'] = strftime('%x %X')
                                    mapDicts[str(currentMap)][steamid]['wonly']['strafesw'] = strafes[steamid]['count']
                                    overwrite = 1
                                else:
                                    tell(player, 'finished w-only private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                                    tell(player, 'no new record')
                            else:
                                mapDicts[str(currentMap)][steamid]['wonly'] = {'timew':timeTaken, 'namew':es.getplayername(player), 'jumpsw':players[player][1], 'datew': strftime('%x %X'), 'strafesw': strafes[steamid]['count']}
                                overwrite = 2
                                r_addwpoints(str(currentMap), steamid)
                                tell(player, 'got points w-only', {'points':mapscore[str(currentMap)] * 1.5, 'map':str(currentMap)})
                                (_pos, _len) = mk_sortDictIndexw(str(currentMap), steamid)
                                if _pos > 2:
                                    double_check = 1
                                    tell(player, 'finished w-only private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})

                        if styles[player]['sideways'] == 1:
                            if 'sideways' in mapDicts[str(currentMap)][steamid]:
                                if mapDicts[str(currentMap)][steamid]['sideways']['timesw'] > timeTaken:
                                    improve = formatTime5(mapDicts[str(currentMap)][steamid]['sideways']['timesw'] - timeTaken)
                                    mapDicts[str(currentMap)][steamid]['sideways']['timesw']  = timeTaken
                                    mapDicts[str(currentMap)][steamid]['sideways']['jumpssw'] = players[player][1]
                                    mapDicts[str(currentMap)][steamid]['sideways']['namesw']  = es.getplayername(player)
                                    mapDicts[str(currentMap)][steamid]['sideways']['datesw'] = strftime('%x %X')
                                    mapDicts[str(currentMap)][steamid]['sideways']['strafessw'] = strafes[steamid]['count']
                                    overwrite = 1
                                else:
                                    tell(player, 'finished sideways private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                                    tell(player, 'no new record')
                            else:
                                mapDicts[str(currentMap)][steamid]['sideways'] = {'timesw':timeTaken, 'namesw':es.getplayername(player), 'jumpssw':players[player][1], 'datesw': strftime('%x %X'), 'strafessw': strafes[steamid]['count']}
                                overwrite = 2
                                r_addwpoints(str(currentMap), steamid)
                                tell(player, 'got points sideways', {'points':mapscore[str(currentMap)] * 1.5, 'map':str(currentMap)})
                                (_pos, _len) = mk_sortDictIndexw(str(currentMap), steamid)
                                if _pos > 2:
                                    double_check = 1
                                    tell(player, 'finished sideways private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})

										
										
                    if overwrite:
                        if styles[player]['normal'] == 1:
                            (_pos, _len) = mk_sortDictIndex(str(currentMap), steamid)
                            if _pos == 1:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top1 time normal')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTaken)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                                    TOP_TIME = timeTaken
                            elif _pos == 2:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds2))
                                    tell(uid, 'new top2 time normal')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTaken)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos == 3:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds2))
                                    tell(uid, 'new top3 time normal')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTaken)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos > 3:
                                if double_check == 0:
                                    tell(player, 'finished normal private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            if overwrite == 1 and improve: tell(player, 'new record', {'imp':improve})
							
                        if styles[player]['wonly'] == 1:
                            (_pos, _len) = mk_sortDictIndexw(str(currentMap), steamid)
                            if _pos == 1:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top1 time w-only')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTaken)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                                    TOP_TIME_W = timeTaken
                            elif _pos == 2:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds2))
                                    tell(uid, 'new top2 time w-only')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTaken)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos == 3:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds2))
                                    tell(uid, 'new top3 time w-only')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTaken)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos > 3:
                                if double_check == 0:
                                    tell(player, 'finished w-only private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            if overwrite == 1 and improve: tell(player, "new w record", {'imp':improve})
							
                        if styles[player]['sideways'] == 1:
                            (_pos, _len) = mk_sortDictIndexsw(str(currentMap), steamid)
                            if _pos == 1:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top1 time sideways')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTaken)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                                    TOP_TIME_SW = timeTaken
                            elif _pos == 2:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds2))
                                    tell(uid, 'new top2 time sideways')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTaken)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos == 3:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds2))
                                    tell(uid, 'new top3 time sideways')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTaken)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos > 3:
                                if double_check == 0:
                                    tell(player, 'finished sideways private', {'time':formatTime5(timeTaken), 'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            if overwrite == 1 and improve: tell(player, "new sideways record", {'imp':improve})
							
                    started.remove(ssteamid)
                    del speeddict[steamid]
                    del strafes[steamid]
                else:
                    lowerVertex, upperVertex = mapDicts[str(currentMap)]["startpos"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                        if getSpeed(player) > 290:
                            resetvel(player)
                            now = time.time()
                            if now - nospam.get(player, 0) >= 5:
                                nospam[player] = now
                                tell(player, 'anti prespeed')
                        playernc = playerlib.getPlayer(player)
                        if playernc.noclip == 1:
                            playernc.noclip = 0
                        players[player] = [time.time(), 0]
                        del speeddict[steamid]
                        del strafes[steamid]
									
            elif (int(es.getplayerteam(player)) > 1):

                c_player = playerlib.getPlayer(player)
                if (c_player.attributes["isdead"] == 0):
                    lowerVertex, upperVertex = mapDicts[str(currentMap)]["startpos"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                        if getSpeed(player) > 290:
                            resetvel(player)
                            now = time.time()
                            if now - nospam.get(player, 0) >= 5:
                                nospam[player] = now
                                tell(player, 'anti prespeed')
                        tokens = {}
                        tokens['name'] = es.getplayername(player)
                        started.append(ssteamid)
                        players[player] = [time.time(), 0]

                        if player in startedb: startedb.remove(player)
						
    except KeyError:
        pass


    gamethread.delayedname(0.1, 'climbtime_checkloop', checkLoop)

lol = 1
def bonusLoop():
    if lol == 1:
        for player in es.getUseridList():
            ssteamid = es.getplayersteamid(player)
            if (ssteamid in startedb) and (int(es.getplayerteam(player)) > 1):
                if ssteamid in started: started.remove(ssteamid)
                es.server.queuecmd('es_fire %s !self addoutput "gravity 1"' % player)
                lowerVertex, upperVertex = bonusDicts[str(currentMap)]["endposb"]
                timeTakenb = time.time() - players[player][0]
                steamid   = es.getplayersteamid(player)
                if steamid not in strafes:
                    strafes[steamid] = {
                        'on': 0,
                        'count': 0 }
                if es.getplayerprop(player, 'CCSPlayer.baseclass.localdata.m_hGroundEntity') != -1:
                    strafes[steamid]['on'] = 0
                else:
                    strafes[steamid]['on'] = 1
                if steamid not in speeddictb:
                    speeddictb[steamid] = {'speedaddedb':0, 'numberofspeedsb':0, 'maxspeedb':0}
                speeddictb[steamid]["numberofspeedsb"] = speeddictb[steamid]["numberofspeedsb"] + 1
                x = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[0]')
                y = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[1]')
                z = es.getplayerprop(player,'CBasePlayer.localdata.m_vecVelocity[2]')
                total_speed = sqrt(y ** 2 + x ** 2 + z ** 2)
                speeddictb[steamid]["speedaddedb"] = speeddictb[steamid]["speedaddedb"] + total_speed
                if total_speed > speeddictb[steamid]["maxspeedb"]: speeddictb[steamid]["maxspeedb"] = total_speed
                if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                    overwrite = 0
                    improve = 0
                    double_check = 0
                    if steamid not in bonusDicts[str(currentMap)]:
                        bonusDicts[str(currentMap)][steamid] = {}
                        if styles[player]['normal'] == 1:
                            bonusDicts[str(currentMap)][steamid] = {
                                'timeb': timeTakenb,
                                'nameb': es.getplayername(player),
                                'jumpsb': players[player][1],
                                'strafesb': strafes[steamid]['count'],
                                'dateb': strftime('%x %X') }
                            overwrite = 2
                            (_pos, _len) = mk_sortDictIndexb(str(currentMap), steamid)
                            if _pos > 2:
                                double_check = 1
                                tell(player, 'finished bonus private', {
                                    'time': formatTime(timeTakenb),
                                    'jumps': players[player][1],
                                    'strafes': strafes[steamid]['count'] })
									
                        if styles[player]['wonly'] == 1:
                            bonusDicts[str(currentMap)][steamid]['wonly'] = {
                                'timebw': timeTakenb,
                                'namebw': es.getplayername(player),
                                'jumpsbw': players[player][1],
                                'strafesbw': strafes[steamid]['count'],
                                'datebw': strftime('%x %X') }
                            overwrite = 2
                            (_pos, _len) = mk_sortDictIndexbw(str(currentMap), steamid)
                            if _pos > 2:
                                double_check = 1
                                tell(player, 'finished bonus private wonly', {
                                    'time': formatTime(timeTakenb),
                                    'jumps': players[player][1],
                                    'strafes': strafes[steamid]['count'] })
									
                        if styles[player]['sideways'] == 1:
                            bonusDicts[str(currentMap)][steamid]['sideways'] = {
                                'timebsw': timeTakenb,
                                'namebsw': es.getplayername(player),
                                'jumpsbsw': players[player][1],
                                'strafesbsw': strafes[steamid]['count'],
                                'datebsw': strftime('%x %X') }
                            overwrite = 2
                            (_pos, _len) = mk_sortDictIndexbsw(str(currentMap), steamid)
                            if _pos > 2:
                                double_check = 1
                                tell(player, 'finished bonus private sideways', {
                                    'time': formatTime(timeTakenb),
                                    'jumps': players[player][1],
                                    'strafes': strafes[steamid]['count'] })
                    else:
                        if styles[player]['normal'] == 1:
                            if 'timeb' in bonusDicts[str(currentMap)][steamid]:
                                if bonusDicts[str(currentMap)][steamid]['timeb'] > timeTakenb:
                                    improve = formatTime5(bonusDicts[str(currentMap)][steamid]['timeb'] - timeTakenb)
                                    bonusDicts[str(currentMap)][steamid]['timeb']  = timeTakenb
                                    bonusDicts[str(currentMap)][steamid]['jumpsb'] = players[player][1]
                                    bonusDicts[str(currentMap)][steamid]['strafesb'] = strafes[steamid]['count']
                                    bonusDicts[str(currentMap)][steamid]['nameb']  = es.getplayername(player)
                                    overwrite = 1
                                else:
                                    tell(player, 'finished bonus private', {
                                        'time': formatTime(timeTakenb),
                                        'jumps': players[player][1],
                                        'strafes': strafes[steamid]['count'] })
                                    tell(player, 'no new record')
                            else:
                                bonusDicts[str(currentMap)][steamid]['timeb']  = timeTakenb
                                bonusDicts[str(currentMap)][steamid]['jumpsb'] = players[player][1]
                                bonusDicts[str(currentMap)][steamid]['strafesb'] = strafes[steamid]['count']
                                bonusDicts[str(currentMap)][steamid]['nameb']  = es.getplayername(player)
                                overwrite = 2
                                (_pos, _len) = mk_sortDictIndexb(str(currentMap), steamid)
                                if _pos > 2:
                                    double_check = 1
                                    tell(player, 'finished bonus private', {
                                        'time': formatTime(timeTakenb),
                                        'jumps': players[player][1],
                                        'strafes': strafes[steamid]['count'] })
										
                        if styles[player]['wonly'] == 1:
                            if 'wonly' in bonusDicts[str(currentMap)][steamid]:
                                if bonusDicts[str(currentMap)][steamid]['wonly']['timebw'] > timeTakenb:
                                    improve = formatTime5(bonusDicts[str(currentMap)][steamid]['wonly']['timebw'] - timeTakenb)
                                    bonusDicts[str(currentMap)][steamid]['wonly']['timebw']  = timeTakenb
                                    bonusDicts[str(currentMap)][steamid]['wonly']['jumpsbw'] = players[player][1]
                                    bonusDicts[str(currentMap)][steamid]['wonly']['strafesbw'] = strafes[steamid]['count']
                                    bonusDicts[str(currentMap)][steamid]['wonly']['namebw']  = es.getplayername(player)
                                    overwrite = 1
                                else:
                                    tell(player, 'finished bonus private wonly', {
                                        'time': formatTime(timeTakenb),
                                        'jumps': players[player][1],
                                        'strafes': strafes[steamid]['count'] })
                                    tell(player, 'no new record')
                            else:
                                bonusDicts[str(currentMap)][steamid]['wonly'] = {'timebw':timeTakenb, 'namebw':es.getplayername(player), 'jumpsbw':players[player][1], 'datebw': strftime('%x %X'), 'strafesbw': strafes[steamid]['count']}
                                overwrite = 2
                                (_pos, _len) = mk_sortDictIndexbw(str(currentMap), steamid)
                                if _pos > 2:
                                    double_check = 1
                                    tell(player, 'finished bonus private wonly', {
                                        'time': formatTime(timeTakenb),
                                        'jumps': players[player][1],
                                        'strafes': strafes[steamid]['count'] })
										
                        if styles[player]['sideways'] == 1:
                            if 'sideways' in bonusDicts[str(currentMap)][steamid]:
                                if bonusDicts[str(currentMap)][steamid]['sideways']['timebsw'] > timeTakenb:
                                    improve = formatTime5(bonusDicts[str(currentMap)][steamid]['sideways']['timebsw'] - timeTakenb)
                                    bonusDicts[str(currentMap)][steamid]['sideways']['timebsw']  = timeTakenb
                                    bonusDicts[str(currentMap)][steamid]['sideways']['jumpsbsw'] = players[player][1]
                                    bonusDicts[str(currentMap)][steamid]['sideways']['strafesbsw'] = strafes[steamid]['count']
                                    bonusDicts[str(currentMap)][steamid]['sideways']['namebsw']  = es.getplayername(player)
                                    overwrite = 1
                                else:
                                    tell(player, 'finished bonus private sideways', {
                                        'time': formatTime(timeTakenb),
                                        'jumps': players[player][1],
                                        'strafes': strafes[steamid]['count'] })
                                    tell(player, 'no new record')
                            else:
                                bonusDicts[str(currentMap)][steamid]['sideways'] = {'timebsw':timeTakenb, 'namebsw':es.getplayername(player), 'jumpsbsw':players[player][1], 'datebsw': strftime('%x %X'), 'strafesbsw': strafes[steamid]['count']}
                                overwrite = 2
                                (_pos, _len) = mk_sortDictIndexbsw(str(currentMap), steamid)
                                if _pos > 2:
                                    double_check = 1
                                    tell(player, 'finished bonus private sideways', {
                                        'time': formatTime(timeTakenb),
                                        'jumps': players[player][1],
                                        'strafes': strafes[steamid]['count'] })
									
                    if overwrite:
                        if styles[player]['normal'] == 1:
                            (_pos, _len) = mk_sortDictIndexb(str(currentMap), steamid)
                            if _pos == 1:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top1 time bonus')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTakenb)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                                TOP_TIME_B = timeTakenb
                            elif _pos == 2:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds2))
                                    tell(uid, 'new top2 time bonus')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTakenb)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos == 3:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds2))
                                    tell(uid, 'new top3 time bonus')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTakenb)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos > 3:
                                if double_check == 0:
                                    tell(player, 'finished bonus private', {
                                        'time': formatTime(timeTakenb),
                                        'jumps': players[player][1],
                                        'strafes': strafes[steamid]['count'] })
                            if overwrite == 1 and improve: 
                                iloscczasu2 = formatTime5(timeTakenb)
                                iloscskokow2 = players[player][1]
                                tell(player, "new bonus record", {'imp':improve})
								
                        if styles[player]['wonly'] == 1:
                            (_pos, _len) = mk_sortDictIndexbw(str(currentMap), steamid)
                            if _pos == 1:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top1 time bonus w-only')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTakenb)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                                TOP_TIME_BW = timeTakenb
                            elif _pos == 2:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top2 time bonus w-only')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTakenb)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos == 3:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top3 time bonus w-only')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTakenb)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos > 3:
                                if double_check == 0:
                                    tell(player, 'finished bonus private wonly', {
                                        'time': formatTime(timeTakenb),
                                        'jumps': players[player][1],
                                        'strafes': strafes[steamid]['count'] })
                            if overwrite == 1 and improve: 
                                iloscczasu2 = formatTime5(timeTakenb)
                                iloscskokow2 = players[player][1]
                                tell(player, "new bonus record w", {'imp':improve})
								
                        if styles[player]['sideways'] == 1:
                            (_pos, _len) = mk_sortDictIndexbsw(str(currentMap), steamid)
                            if _pos == 1:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top1 time bonus sideways')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTakenb)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                                TOP_TIME_BSW = timeTakenb
                            elif _pos == 2:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top2 time bonus sideways')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTakenb)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos == 3:
                                for uid in es.getUseridList():
                                    es.cexec_all('play', '%s.wav'%random.choice(sounds1))
                                    tell(uid, 'new top3 time bonus sideways')
                                    tell(uid, 'finished top part1', {'name':es.getplayername(player), 'time':formatTime5(timeTakenb)})
                                    tell(uid, 'finished top part2', {'jumps':players[player][1], 'strafes': strafes[steamid]['count']})
                            elif _pos > 3:
                                if double_check == 0:
                                    tell(player, 'finished bonus private sideways', {
                                        'time': formatTime(timeTakenb),
                                        'jumps': players[player][1],
                                        'strafes': strafes[steamid]['count'] })
                            if overwrite == 1 and improve: 
                                iloscczasu2 = formatTime5(timeTakenb)
                                iloscskokow2 = players[player][1]
                                tell(player, "new bonus record sw", {'imp':improve})
								
                    startedb.remove(steamid)
                    del speeddictb[steamid]
                    del strafes[steamid]
                else:
                    lowerVertex, upperVertex = bonusDicts[str(currentMap)]["startposb"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):
                        if getSpeed(player) > 290:
                            resetvel(player)
                            now = time.time()
                            if now - nospam.get(player, 0) >= 5:
                                nospam[player] = now
                                tell(player, 'anti prespeed')
                        playernc = playerlib.getPlayer(player)
                        if playernc.noclip == 1:
                            playernc.noclip = 0
                        players[player] = [time.time(), 0]
                        del speeddictb[steamid]
                        del strafes[steamid]
            elif (int(es.getplayerteam(player)) > 1):
                c_player = playerlib.getPlayer(player)
                if (c_player.attributes["isdead"] == 0):
                    lowerVertex, upperVertex = bonusDicts[str(currentMap)]["startposb"]
                    if vecmath.isbetweenRect(es.getplayerlocation(player), lowerVertex, upperVertex):

                        tokens = {}
                        tokens['nameb'] = es.getplayername(player)
                        startedb.append(ssteamid)

                        if ssteamid in started: started.remove(ssteamid)
                        players[player] = [time.time(), 0]
						
        gamethread.delayedname(0.1, 'climbtime_bonusloop', bonusLoop)

		
def prepareMsg(msg):
    return RE_COLORS.sub('\x07\\1', msg)
           
def tell(userid, message, options = {}, tellMessage = True):
    message = text(message, options, playerlib.getPlayer(userid).get("lang"))
    if tellMessage:
        es.tell(userid, prepareMsg(message))
    else:
        return message
		
def formatTime4(_seconds):
    ft = str(datetime.timedelta(seconds=_seconds))
    return ft
 
def formatTime3(seconds):
    hours, minutes   = divmod(seconds, 3600)
    minutes, seconds = divmod(minutes, 60)
    return "%s hours %02i minutes %02i seconds" % (int(hours), minutes, seconds)
 
def formatTime6(seconds):
    hours, minutes   = divmod(seconds, 3600)
    minutes, seconds = divmod(minutes, 60)
    return "%s:%02i:%02i" % (int(hours), minutes, seconds)
       
def formatTime2(_seconds):
    ft = str(datetime.timedelta(seconds=_seconds))
    if int(ft[0]) <= 0:
        return ft[2:7]
    else:
        x = ft.find(':')
        if x > -1:
            hlen = len(ft[0:x])
            return ft[0:((7 + hlen) -1)]
        else:
            x = ft.find('.')
            if x > -1:
                return ft[0:x]
            else:
                return ft[0:7] # if all else fails..
 
def formatTime(_seconds):
    ft = str(datetime.timedelta(seconds=_seconds))
    if int(ft[0]) <= 0:
        ms = ft.find('.')
        if ms < 0:
            return "%s.000" % ft[2:11]
        else:
            return ft[2:11]
    else:
        x = ft.find(':')
        if x > -1:
            hlen = len(ft[0:x])
            ms = ft.find('.')
            if ms < 0:
                return "%s.000" % ft[0:((11 + hlen) -1)]
            else:
                return ft[0:((11 + hlen) -1)]
        else:
            x = ft.find('.')
            if x > -1:
                ms = ft.find('.')
                if ms < 0:
                    return "%s.000" % ft[0:(x + 4)]
                else:
                    return ft[0:(x + 4)]
            else:
                ms = ft.find('.')
                if ms < 0:
                    return "%s.000" % ft[0:11]
                else:
                    return ft[0:11] # if all else fails..
 
def formatTime5(_seconds):
    ft = str(datetime.timedelta(seconds=_seconds))
    if int(ft[0]) <= 0:
        ms = ft.find('.')
        if ms < 0:
            return "%s.000" % ft[2:11]
        else:
            return ft[2:11]
    else:
        x = ft.find(':')
        if x > -1:
            hlen = len(ft[0:x])
            ms = ft.find('.')
            if ms < 0:
                return "%s.000" % ft[0:((11 + hlen) -1)]
            else:
                return ft[0:((11 + hlen) -1)]
        else:
            x = ft.find('.')
            if x > -1:
                ms = ft.find('.')
                if ms < 0:
                    return "%s.000" % ft[0:(x + 4)]
                else:
                    return ft[0:(x + 4)]
            else:
                ms = ft.find('.')
                if ms < 0:
                    return "%s.000" % ft[0:11]
                else:
                    return ft[0:11] # if all else fails..
   
def effectLoop(userid, start, red = 0, green = 255, blue = 0):
    effectlib.drawBox(start, es.getplayerlocation(userid), red=red, green=green, blue=blue, seconds=0.1)
    gamethread.delayedname(0.01, 'climbtimer_effects', effectLoop, (userid, start, red, green, blue) )
	
def acPopupMenuselect(userid, choice, popupid):
    mapName = str(currentMap)
    if choice == 1:
        if mapName not in acDicts:
            acDicts[mapName] = {}
        if "anticheat" not in acDicts[mapName]:
            acDicts[mapName]['anticheat'] = [ (0,0,0), (0,0,0) ]
        if userid not in effects:
            effects.append(userid)
            es.tell(userid, '#multi', 'You added/moved the first corner of the FIRST anti-cheat location.')
            start = list(es.getplayerlocation(userid))
            start[2] -= 5
            acDicts[mapName]["anticheat"][0] = start
            effectLoop(userid, start)
        else:
            effects.remove(userid)
            gamethread.cancelDelayed('climbtimer_effects')
            es.tell(userid, '#multi', 'You added/moved the second corner of the FIRST anti-cheat location.')
            acDicts[mapName]["anticheat"][1] = list(es.getplayerlocation(userid))
            acDicts[mapName]["anticheat"][1][2] -= 5
            gamethread.delayedname(0.05, 'climbtime_acloop', acLoop)
        acPopup.send(userid)
		
    elif choice == 2:
        if mapName not in acDicts:
            acDicts[mapName] = {}
        if "anticheat2" not in acDicts[mapName]:
            acDicts[mapName]['anticheat2'] = [ (0,0,0), (0,0,0) ]
        if userid not in effects:
            effects.append(userid)
            es.tell(userid, '#multi', 'You added/moved the first corner of the SECOND anti-cheat location.')
            start = list(es.getplayerlocation(userid))
            start[2] -= 5
            acDicts[mapName]["anticheat2"][0] = start
            effectLoop(userid, start)
        else:
            effects.remove(userid)
            gamethread.cancelDelayed('climbtimer_effects')
            es.tell(userid, '#multi', 'You added/moved the second corner of the SECOND anti-cheat location.')
            acDicts[mapName]["anticheat2"][1] = list(es.getplayerlocation(userid))
            acDicts[mapName]["anticheat2"][1][2] -= 5
            gamethread.delayedname(0.05, 'climbtime_acloop', acLoop)
        acPopup.send(userid)
		
    elif choice == 3:
        if mapName not in acDicts:
            acDicts[mapName] = {}
        if "anticheat3" not in acDicts[mapName]:
            acDicts[mapName]['anticheat3'] = [ (0,0,0), (0,0,0) ]
        if userid not in effects:
            effects.append(userid)
            es.tell(userid, '#multi', 'You added/moved the first corner of THIRD the anti-cheat location.')
            start = list(es.getplayerlocation(userid))
            start[2] -= 5
            acDicts[mapName]["anticheat3"][0] = start
            effectLoop(userid, start)
        else:
            effects.remove(userid)
            gamethread.cancelDelayed('climbtimer_effects')
            es.tell(userid, '#multi', 'You added/moved the second corner of the THIRD anti-cheat location.')
            acDicts[mapName]["anticheat3"][1] = list(es.getplayerlocation(userid))
            acDicts[mapName]["anticheat3"][1][2] -= 5
            gamethread.delayedname(0.05, 'climbtime_acloop', acLoop)
        acPopup.send(userid)
		
    elif choice == 4:
        if mapName not in acDicts:
            acDicts[mapName] = {}
        if "anticheat4" not in acDicts[mapName]:
            acDicts[mapName]['anticheat4'] = [ (0,0,0), (0,0,0) ]
        if userid not in effects:
            effects.append(userid)
            es.tell(userid, '#multi', 'You added/moved the first corner of the FOURTH anti-cheat location.')
            start = list(es.getplayerlocation(userid))
            start[2] -= 5
            acDicts[mapName]["anticheat4"][0] = start
            effectLoop(userid, start)
        else:
            effects.remove(userid)
            gamethread.cancelDelayed('climbtimer_effects')
            es.tell(userid, '#multi', 'You added/moved the second corner of the FOURTH anti-cheat location.')
            acDicts[mapName]["anticheat4"][1] = list(es.getplayerlocation(userid))
            acDicts[mapName]["anticheat4"][1][2] -= 5
            gamethread.delayedname(0.05, 'climbtime_acloop', acLoop)
        acPopup.send(userid)
		
    elif choice == 5:
        if mapName not in acDicts:
            acDicts[mapName] = {}
        if "anticheat5" not in acDicts[mapName]:
            acDicts[mapName]['anticheat5'] = [ (0,0,0), (0,0,0) ]
        if userid not in effects:
            effects.append(userid)
            es.tell(userid, '#multi', 'You added/moved the first corner of the FIFTH anti-cheat location.')
            start = list(es.getplayerlocation(userid))
            start[2] -= 5
            acDicts[mapName]["anticheat5"][0] = start
            effectLoop(userid, start)
        else:
            effects.remove(userid)
            gamethread.cancelDelayed('climbtimer_effects')
            es.tell(userid, '#multi', 'You added/moved the second corner of the FIFTH anti-cheat location.')
            acDicts[mapName]["anticheat5"][1] = list(es.getplayerlocation(userid))
            acDicts[mapName]["anticheat5"][1][2] -= 5
            gamethread.delayedname(0.05, 'climbtime_acloop', acLoop)
        acPopup.send(userid)
		
    elif choice == 9:
        adminPopup.send(userid)
		
def adminDeleteRecords(userid, choice, popupid):
    mapName = str(currentMap)
    if choice == 1:
        if mapName in mapDicts:
            popuplib.close("climbtimer_admin", userid)
            global playerList
            playerList = popuplib.easymenu("climbtimer_playerlist", None, playerPopupMenuselectn)
            playerList.settitle("Delete Normal records on map %s\n%s" % (mapName, "-" * 30))
            sortedList = mk_sortDict(mapName)
            if sortedList:
                lx = 0
                for top in sortedList:
                    playerList.addoption('%s' % str(top[0]), "%s. %s -%s" % (lx + 1, mapDicts[mapName][top[0]]["name"], formatTime5(mapDicts[mapName][top[0]]["time"])))
                    lx += 1
            else:
                playerList.setdescription("[No places recorded]")
            playerList.send(userid)
        else:
            es.tell(userid, "This map has not been setup yet.")
            delrec.send(userid)
			
    elif choice == 2:
        if mapName in mapDicts:
            popuplib.close("climbtimer_admin", userid)
            global playerList
            playerList = popuplib.easymenu("climbtimer_playerlist", None, playerPopupMenuselectw)
            playerList.settitle("Delete W-Only records on map %s\n%s" % (mapName, "-" * 30))
            sortedList = mk_sortDictw(mapName)
            if sortedList:
                lx = 0
                for top in sortedList:
                    playerList.addoption('%s' % str(top[0]), "%s. %s -%s" % (lx + 1, mapDicts[mapName][top[0]]['wonly']["namew"], formatTime5(mapDicts[mapName][top[0]]['wonly']["timew"])))
                    lx += 1
            else:
                playerList.setdescription("[No places recorded]")
            playerList.send(userid)
        else:
            es.tell(userid, "This map has not been setup yet.")
            delrec.send(userid)
			
    elif choice == 3:
        if mapName in mapDicts:
            popuplib.close("climbtimer_admin", userid)
            global playerList
            playerList = popuplib.easymenu("climbtimer_playerlist", None, playerPopupMenuselectsw)
            playerList.settitle("Delete Sideways records on map %s\n%s" % (mapName, "-" * 30))
            sortedList = mk_sortDictsw(mapName)
            if sortedList:
                lx = 0
                for top in sortedList:
                    playerList.addoption('%s' % str(top[0]), "%s. %s -%s" % (lx + 1, mapDicts[mapName][top[0]]['sideways']["namesw"], formatTime5(mapDicts[mapName][top[0]]['sideways']["timesw"])))
                    lx += 1
            else:
                playerList.setdescription("[No places recorded]")
            playerList.send(userid)
        else:
            es.tell(userid, "This map has not been setup yet.")
            delrec.send(userid)
			
    elif choice == 4:
        if mapName in bonusDicts:
            popuplib.close("climbtimer_admin", userid)
            global bplayerList
            bplayerList = popuplib.easymenu("climbtimer_bplayerlist", None, bonusplayerPopupMenuselect)
            bplayerList.settitle("[Bonus Timer DB : %s]\n%s" % (mapName, "-" * 30))
            sortedList = mk_sortDictb(mapName)
            if sortedList:
                lx = 0
                for top in sortedList:
                    bplayerList.addoption('%s' % str(top[0]), "%s. %s -%s" % (lx + 1, bonusDicts[mapName][top[0]]["nameb"], formatTime5(bonusDicts[mapName][top[0]]["timeb"])))
                    lx += 1
            else:
                bplayerList.setdescription("[No places recorded]")
            bplayerList.send(userid)
        else:
            es.tell(userid, "#multi", "There is no bonus setup for this map.")
            delrec.send(userid)
			
    elif choice == 5:
        if mapName in mapDicts:
            popuplib.close("climbtimer_admin", userid)
            global bplayerList
            bplayerList = popuplib.easymenu("climbtimer_bplayerlist", None, playerPopupMenuselectbw)
            bplayerList.settitle("Delete W-Only records on map %s\n%s" % (mapName, "-" * 30))
            sortedList = mk_sortDictbw(mapName)
            if sortedList:
                lx = 0
                for top in sortedList:
                    bplayerList.addoption('%s' % str(top[0]), "%s. %s -%s" % (lx + 1, bonusDicts[mapName][top[0]]['wonly']["namebw"], formatTime5(bonusDicts[mapName][top[0]]['wonly']["timebw"])))
                    lx += 1
            else:
                bplayerList.setdescription("[No places recorded]")
            bplayerList.send(userid)
        else:
            es.tell(userid, "This map has not been setup yet.")
            delrec.send(userid)
			
    elif choice == 6:
        if mapName in mapDicts:
            popuplib.close("climbtimer_admin", userid)
            global bplayerList
            bplayerList = popuplib.easymenu("climbtimer_bplayerlist", None, playerPopupMenuselectbsw)
            bplayerList.settitle("Delete SideWays records on map %s\n%s" % (mapName, "-" * 30))
            sortedList = mk_sortDictbsw(mapName)
            if sortedList:
                lx = 0
                for top in sortedList:
                    bplayerList.addoption('%s' % str(top[0]), "%s. %s -%s" % (lx + 1, bonusDicts[mapName][top[0]]['sideways']["namebsw"], formatTime5(bonusDicts[mapName][top[0]]['sideways']["timebsw"])))
                    lx += 1
            else:
                bplayerList.setdescription("[No places recorded]")
            bplayerList.send(userid)
        else:
            es.tell(userid, "This map has not been setup yet.")
            delrec.send(userid)
			
    elif choice == 9:
        adminPopup.send(userid)
   
def adminPopupMenuselect(userid, choice, popupid):
    mapName = str(currentMap)
    if choice == 1:
        if mapName not in mapDicts:
            mapDicts[mapName] = {}
        if "startpos" not in mapDicts[mapName]:
            mapDicts[mapName]['startpos'] = [ (0,0,0), (0,0,0) ]
        if userid not in effects:
            effects.append(userid)
            es.tell(userid, 'First corner of start box selected.')
            start = list(es.getplayerlocation(userid))
            start[2] -= 5
            mapDicts[mapName]["startpos"][0] = start
            effectLoop(userid, start)
        else:
            effects.remove(userid)
            gamethread.cancelDelayed('climbtimer_effects')
            es.tell(userid, 'You have selected the area of your start zone.')
            mapDicts[mapName]["startpos"][1] = list(es.getplayerlocation(userid))
            mapDicts[mapName]["startpos"][1][2] -= 5
            if "endpos" in mapDicts[mapName]:
                gamethread.delayedname(0.01, 'climbtime_checkloop', checkLoop)
                hudLoop()
        adminPopup.send(userid)
           
    elif choice == 2:
        if mapName not in mapDicts:
            mapDicts[mapName] = {}
        if "endpos" not in mapDicts[mapName]:
            mapDicts[mapName]['endpos'] = [ (0,0,0), (0,0,0) ]
        if userid not in effects:
            effects.append(userid)
            es.tell(userid, "#multi", 'First corner of end box selected.')
            start = list(es.getplayerlocation(userid))
            start[2] -= 5
            mapDicts[mapName]["endpos"][0] = start
            effectLoop(userid, start, 255, 0)
        else:
            effects.remove(userid)
            gamethread.cancelDelayed('climbtimer_effects')
            es.tell(userid, "#multi", 'You have selected the area of your end zone.')
            mapDicts[mapName]["endpos"][1] = list(es.getplayerlocation(userid))
            mapDicts[mapName]["endpos"][1][2] -= 5
            if "startpos" in mapDicts[mapName]:
                gamethread.delayedname(0.1, 'climbtime_checkloop', checkLoop)
                hudLoop()
        adminPopup.send(userid)
           
    elif choice == 3:
        if mapName in mapDicts:
            del mapDicts[mapName]
            gamethread.cancelDelayed('climbtime_checkloop')
        es.tell(userid, "You have removed the map start/end positions and all times.")
       
    elif choice == 4:
        delrec.send(userid)
		


    elif choice == 5:
        if mapName not in bonusDicts:
            bonusDicts[mapName] = {}
        if "startposb" not in bonusDicts[mapName]:
            bonusDicts[mapName]['startposb'] = [ (0,0,0), (0,0,0) ]
        if userid not in effects:
            effects.append(userid)
            es.tell(userid, "#multi", 'First corner of bonus start area selected.')
            start = list(es.getplayerlocation(userid))
            start[2] -= 5
            bonusDicts[mapName]["startposb"][0] = start
            effectLoop(userid, start)
        else:
            effects.remove(userid)
            gamethread.cancelDelayed('climbtimer_effects')
            es.tell(userid, "#multi", 'You have selected the area of your bonus start zone.')
            bonusDicts[mapName]["startposb"][1] = list(es.getplayerlocation(userid))
            bonusDicts[mapName]["startposb"][1][2] -= 5
            if "endposb" in bonusDicts[mapName]:
                gamethread.delayedname(0.1, 'climbtime_bonusloop', bonusLoop)
                hudLoop()
        adminPopup.send(userid)
           
    elif choice == 6:
        if mapName not in bonusDicts:
            bonusDicts[mapName] = {}
        if "endposb" not in bonusDicts[mapName]:
            bonusDicts[mapName]['endposb'] = [ (0,0,0), (0,0,0) ]
        if userid not in effects:
            effects.append(userid)
            es.tell(userid, "#multi", 'First corner of bonus end area selected.')
            start = list(es.getplayerlocation(userid))
            start[2] -= 5
            bonusDicts[mapName]["endposb"][0] = start
            effectLoop(userid, start, 255, 0)
        else:
            effects.remove(userid)
            gamethread.cancelDelayed('climbtimer_effects')
            es.tell(userid, "#multi", 'You have selected the area of your bonus end zone.')
            bonusDicts[mapName]["endposb"][1] = list(es.getplayerlocation(userid))
            bonusDicts[mapName]["endposb"][1][2] -= 5
            if "startposb" in bonusDicts[mapName]:
                gamethread.delayedname(0.1, 'climbtime_bonusloop', bonusLoop)
                hudLoop()
        adminPopup.send(userid)

    elif choice == 7:
        if mapName in bonusDicts:
            del bonusDicts[mapName]
            gamethread.cancelDelayed('climbtime_bonusloop')
        es.tell(userid, "You have removed the map bonus start/end positions and all times.")
		
    elif choice ==8:
        acPopup.send(userid)
       

 
def playerPopupMenuselectn(userid, choice, popupid):
    mapName = str(currentMap)
    steamid = es.getplayersteamid(userid)
    if mapDicts[mapName]:
        if mapDicts[mapName][str(choice)]:
            if 'time' in mapDicts[mapName][str(choice)]:
                tokens = {}
                tokens['steamid'] = str(choice)
                tokens['name'] = mapDicts[mapName][str(choice)]['name']
                del mapDicts[mapName][str(choice)]['time']
                es.tell(userid, '#multi', "You have removed player %s from normal records." % tokens['name'])
                if playerList:
                    playerList.send(userid)
            else:
                if "STEAM" in str(choice):
                    es.tell(userid, '#multi', "Failed to remove the player.")
                    if playerList:
                        playerList.send(userid)
        else:
            es.tell(userid, '#multi', "There are no normal records for this map.")
			
def playerPopupMenuselectw(userid, choice, popupid):
    mapName = str(currentMap)
    steamid = es.getplayersteamid(userid)
    if mapDicts[mapName]:
        if mapDicts[mapName][str(choice)]:
            if 'timew' in mapDicts[mapName][str(choice)]['wonly']:
                tokens = {}
                tokens['steamid'] = str(choice)
                tokens['name'] = mapDicts[mapName][str(choice)]['wonly']['namew']
                del mapDicts[mapName][str(choice)]['wonly']
                es.tell(userid, '#multi', "You have removed player %s from w-only records." % tokens['name'])
                if playerList:
                    playerList.send(userid)
            else:
                if "STEAM" in str(choice):
                    es.tell(userid, '#multi', "Failed to remove the player.")
                    if playerList:
                        playerList.send(userid)
                else:
                    es.tell(userid, '#multi', "Player not found or was already deleted.")
        else:
            es.tell(userid, '#multi', "There are no w-only records for this map.")
			
def playerPopupMenuselectbw(userid, choice, popupid):
    mapName = str(currentMap)
    steamid = es.getplayersteamid(userid)
    if bonusDicts[mapName]:
        if bonusDicts[mapName][str(choice)]:
            if 'timebw' in bonusDicts[mapName][str(choice)]['wonly']:
                tokens = {}
                tokens['steamid'] = str(choice)
                tokens['name'] = bonusDicts[mapName][str(choice)]['wonly']['namebw']
                del bonusDicts[mapName][str(choice)]['wonly']
                es.tell(userid, '#multi', "You have removed player %s from w-only bonus records." % tokens['name'])
                if bplayerList:
                    bplayerList.send(userid)
            else:
                if "STEAM" in str(choice):
                    es.tell(userid, '#multi', "Failed to remove the player.")
                    if bplayerList:
                        bplayerList.send(userid)
                else:
                    es.tell(userid, '#multi', "Player not found or was already deleted.")
        else:
            es.tell(userid, '#multi', "There are no bonus w-only records for this map.")
			
def playerPopupMenuselectbsw(userid, choice, popupid):
    mapName = str(currentMap)
    steamid = es.getplayersteamid(userid)
    if bonusDicts[mapName]:
        if bonusDicts[mapName][str(choice)]:
            if 'timebsw' in bonusDicts[mapName][str(choice)]['sideways']:
                tokens = {}
                tokens['steamid'] = str(choice)
                tokens['name'] = bonusDicts[mapName][str(choice)]['sideways']['namebsw']
                del bonusDicts[mapName][str(choice)]['sideways']
                es.tell(userid, '#multi', "You have removed player %s from sideways bonus records." % tokens['name'])
                if bplayerList:
                    bplayerList.send(userid)
            else:
                if "STEAM" in str(choice):
                    es.tell(userid, '#multi', "Failed to remove the player.")
                    if bplayerList:
                        bplayerList.send(userid)
                else:
                    es.tell(userid, '#multi', "Player not found or was already deleted.")
        else:
            es.tell(userid, '#multi', "There are no bonus sideways records for this map.")
			
def playerPopupMenuselectsw(userid, choice, popupid):
    mapName = str(currentMap)
    steamid = es.getplayersteamid(userid)
    if mapDicts[mapName]:
        if mapDicts[mapName][str(choice)]:
            if 'timesw' in mapDicts[mapName][str(choice)]['sideways']:
                tokens = {}
                tokens['steamid'] = str(choice)
                tokens['name'] = mapDicts[mapName][str(choice)]['sideways']['namesw']
                del mapDicts[mapName][str(choice)]['sideways']
                es.tell(userid, '#multi', "You have removed player %s from sideways records." % tokens['name'])
                if playerList:
                    playerList.send(userid)
            else:
                if "STEAM" in str(choice):
                    es.tell(userid, '#multi', "Failed to remove the player.")
                    if playerList:
                        playerList.send(userid)
                else:
                    es.tell(userid, '#multi', "Player not found or was already deleted.")
        else:
            es.tell(userid, '#multi', "There are no sideways records for this map.")

def bonusplayerPopupMenuselect(userid, choice, popupid):
    mapName = str(currentMap)
    if bonusDicts[mapName]:
        if bonusDicts[mapName][str(choice)]:
            if 'timeb' in bonusDicts[mapName][str(choice)]:
                tokens = {}
                tokens['steamid'] = str(choice)
                tokens['name'] = bonusDicts[mapName][str(choice)]['nameb']
                del bonusDicts[mapName][str(choice)]['timeb']
                es.tell(userid, '#multi', "You have removed player %s from bonus normal records." % tokens['name'])
                if bplayerList:
                    bplayerList.send(userid)
            else:
                if "STEAM" in str(choice):
                    es.tell(userid, '#multi', "Failed to remove the player.")
                    if bplayerList:
                        bplayerList.send(userid)
        else:
            es.tell(userid, '#multi', "There are no bonus normal records for this map.")
                   
def scoresetplayer(player):
    steamid = es.getplayersteamid(player)
    score = 0
	
    if steamid in points:
        if 'normal' in points[steamid]:
            sortedList = r_ranksorted()
            score = int(1 + sortedList.index((steamid, points[steamid]['normal'])))
    else:
        score = 0

    scoreset(player, score)
	
def scoreset(userid, score):
    es.server.queuecmd('es_delayed 0.2 score set %s %d' % (userid, score))
	
def player_spawn(ev):
    uid = int(ev['userid'])
    sid = es.getplayersteamid(uid)
    cpid = int(ev['userid'])
    player = playerlib.getPlayer(cpid)
    team = es.getplayerteam(uid)
    if sid in started:
        started.remove(sid)
    if sid in startedb:
        startedb.remove(sid)


    if sid in started:
        started.remove(sid)
        
    if sid in startedb:
        startedb.remove(sid)
		
    if team > 1:
        es.setplayerprop(uid, 'CBaseEntity.m_CollisionGroup', 2)
        scoresetplayer(uid)
        es.setplayerprop(ev['userid'], "CBasePlayer.m_iHealth", 1337)
					
    if sid in points:
        if 'normal' in points[sid]:
            player.set('cash', points[sid]['normal'])
            sortedList = r_ranksorted()
            rank = int(1 + sortedList.index((sid, points[sid]['normal'])))
            if rank < 126:
                player.set('armor', rank)
				
		
def player_hurt(ev):
    es.setplayerprop(ev['userid'], "CBasePlayer.m_iHealth", 1337)
	

def mk_sortDictIndex(map_name, steamid):
    rsort = {}
    found_sid = 0
    for k in mapDicts[map_name].keys():
        if (not str(k) == "startpos") and (not str(k) == "endpos"):
            if "time" in mapDicts[map_name][k]:
                rsort[k] = mapDicts[map_name][k]["time"]
            if (str(k) == steamid):
                found_sid = 1
    if (found_sid == 0):
        return 0, 0
    sortedList = sorted(rsort.items(), key=itemgetter(1))
    lx = 1
    for top in sortedList:
        if (str(top[0]) == steamid):
            return lx, (len(mapDicts[map_name].keys()) - 2)
        lx += 1
    return 0, 0

def mk_sortDictIndexb(map_name, steamid):
    rsort = {}
    found_sid = 0
    for k in bonusDicts[map_name].keys():
        if (not str(k) == "startposb") and (not str(k) == "endposb"):
            if "timeb" in bonusDicts[map_name][k]:
                rsort[k] = bonusDicts[map_name][k]["timeb"]
            if (str(k) == steamid):
                found_sid = 1
    if (found_sid == 0):
        return 0, 0
    sortedList = sorted(rsort.items(), key=itemgetter(1))
    lx = 1
    for top in sortedList:
        if (str(top[0]) == steamid):
            return lx, (len(mapDicts[map_name].keys()) - 2)
        lx += 1
    return 0, 0
	
def mk_sortDictIndexbw(map_name, steamid):
    rsort = {}
    found_sid = 0
    for k in bonusDicts[map_name].keys():
        if (not str(k) == "startposb") and (not str(k) == "endposb"):
            if "wonly" in bonusDicts[map_name][k]:
                if "timebw" in bonusDicts[map_name][k]['wonly']:
                    rsort[k] = bonusDicts[map_name][k]['wonly']["timebw"]
            if (str(k) == steamid):
                found_sid = 1
    if (found_sid == 0):
        return 0, 0
    sortedList = sorted(rsort.items(), key=itemgetter(1))
    lx = 1
    for top in sortedList:
        if (str(top[0]) == steamid):
            return lx, (len(bonusDicts[map_name].keys()) - 2)
        lx += 1
    return 0, 0
	
def mk_sortDictIndexbsw(map_name, steamid):
    rsort = {}
    found_sid = 0
    for k in bonusDicts[map_name].keys():
        if (not str(k) == "startposb") and (not str(k) == "endposb"):
            if "sideways" in bonusDicts[map_name][k]:
                if "timebsw" in bonusDicts[map_name][k]['sideways']:
                    rsort[k] = bonusDicts[map_name][k]['sideways']["timebsw"]
            if (str(k) == steamid):
                found_sid = 1
    if (found_sid == 0):
        return 0, 0
    sortedList = sorted(rsort.items(), key=itemgetter(1))
    lx = 1
    for top in sortedList:
        if (str(top[0]) == steamid):
            return lx, (len(bonusDicts[map_name].keys()) - 2)
        lx += 1
    return 0, 0
	
def mk_sortDictIndexsw(map_name, steamid):
    rsort = {}
    found_sid = 0
    for k in mapDicts[map_name].keys():
        if (not str(k) == "startpos") and (not str(k) == "endpos"):
            if "sideways" in mapDicts[map_name][k]:
                if "timesw" in mapDicts[map_name][k]['sideways']:
                    rsort[k] = mapDicts[map_name][k]['sideways']["timesw"]
            if (str(k) == steamid):
                found_sid = 1
    if (found_sid == 0):
        return 0, 0
    sortedList = sorted(rsort.items(), key=itemgetter(1))
    lx = 1
    for top in sortedList:
        if (str(top[0]) == steamid):
            return lx, (len(mapDicts[map_name].keys()) - 2)
        lx += 1
    return 0, 0
	
def mk_sortDictIndexw(map_name, steamid):
    rsort = {}
    found_sid = 0
    for k in mapDicts[map_name].keys():
        if (not str(k) == "startpos") and (not str(k) == "endpos"):
            if "wonly" in mapDicts[map_name][k]:
                if "timew" in mapDicts[map_name][k]['wonly']:
                    rsort[k] = mapDicts[map_name][k]['wonly']["timew"]
            if (str(k) == steamid):
                found_sid = 1
    if (found_sid == 0):
        return 0, 0
    sortedList = sorted(rsort.items(), key=itemgetter(1))
    lx = 1
    for top in sortedList:
        if (str(top[0]) == steamid):
            return lx, (len(mapDicts[map_name].keys()) - 2)
        lx += 1
    return 0, 0
	
def mk_sortDict(map_name):
    rsort = {}
    for k in mapDicts[map_name].keys():
        if (not str(k) == "startpos") and (not str(k) == "endpos"):
            if "time" in mapDicts[map_name][k]:
                rsort[k] = mapDicts[map_name][k]["time"]
    return sorted(rsort.items(), key=itemgetter(1))
	
def mk_sortDictw(map_name):
    rsort = {}
    for k in mapDicts[map_name].keys():
        if (not str(k) == "startpos") and (not str(k) == "endpos"):
            if "wonly" in mapDicts[map_name][k]:
                if "timew" in mapDicts[map_name][k]['wonly']:
                    rsort[k] = mapDicts[map_name][k]['wonly']["timew"]
    return sorted(rsort.items(), key=itemgetter(1))
	
def mk_sortDictsw(map_name):
    rsort = {}
    for k in mapDicts[map_name].keys():
        if (not str(k) == "startpos") and (not str(k) == "endpos"):
            if "sideways" in mapDicts[map_name][k]:
                if "timesw" in mapDicts[map_name][k]['sideways']:
                    rsort[k] = mapDicts[map_name][k]['sideways']["timesw"]
    return sorted(rsort.items(), key=itemgetter(1))

def mk_sortDictb(map_name):
    rsort = {}
    for k in bonusDicts[map_name].keys():
        if (not str(k) == "startposb") and (not str(k) == "endposb"):
            if "timeb" in bonusDicts[map_name][k]:
                rsort[k] = bonusDicts[map_name][k]["timeb"]
    return sorted(rsort.items(), key=itemgetter(1))
	
def mk_sortDictbw(map_name):
    rsort = {}
    for k in bonusDicts[map_name].keys():
        if (not str(k) == "startposb") and (not str(k) == "endposb"):
            if "wonly" in bonusDicts[map_name][k]:
                if "timebw" in bonusDicts[map_name][k]['wonly']:
                    rsort[k] = bonusDicts[map_name][k]['wonly']["timebw"]
    return sorted(rsort.items(), key=itemgetter(1))
	
def mk_sortDictbsw(map_name):
    rsort = {}
    for k in bonusDicts[map_name].keys():
        if (not str(k) == "startposb") and (not str(k) == "endposb"):
            if "sideways" in bonusDicts[map_name][k]:
                if "timebsw" in bonusDicts[map_name][k]['sideways']:
                    rsort[k] = bonusDicts[map_name][k]['sideways']["timebsw"]
    return sorted(rsort.items(), key=itemgetter(1))
	
	

def mapsdonehandler(userid, choice, popupname):
    es.server.queuecmd('es_sexec %s "say !nominate %s"' %(userid, choice))
	
def r_rebuildpoints():
    points.clear()
    for map in mapDicts:
        for player in mapDicts[map]:
            if 'time' in mapDicts[map][player]:
                r_addpoints(map, player)
            if 'sideways' in mapDicts[map][player]:
                if 'timesw' in mapDicts[map][player]['sideways']:
                    r_addswpoints(map, player)
            if 'wonly' in mapDicts[map][player]:
                if 'timew' in mapDicts[map][player]['wonly']:
                    r_addwpoints(map, player)
    r_buildnamesdb()
	
def r_ranksorted():
    nrank = {}
    for sid in points:
        if 'normal' in points[sid]:
            nrank[sid] = points[sid]['normal']
    return sorted(nrank.items(), key=itemgetter(1), reverse=True)
	
	
def r_wranksorted():
    wrank = {}
    for sid in points:
        if 'wonly' in points[sid]:
            wrank[sid] = points[sid]['wonly']
    return sorted(wrank.items(), key=itemgetter(1), reverse=True)
	
def r_swranksorted():
    swrank = {}
    for sid in points:
        if 'sideways' in points[sid]:
            swrank[sid] = points[sid]['sideways']
    return sorted(swrank.items(), key=itemgetter(1), reverse=True)
	
       
def r_buildnamesdb():
    for steamid in playtime:
        names[steamid] = playtime[steamid]['name']
        continue
    for map in mapDicts:
        for steamid in mapDicts[map]:
            if 'name' not in mapDicts[map][steamid]:
                if steamid not in names:
                    if 'sideways' in mapDicts[map][steamid]:
                        names[steamid] = mapDicts[map][steamid]['sideways']['namesw']
                    elif 'wonly' in mapDicts[map][steamid]:
                        names[steamid] = mapDicts[map][steamid]['wonly']['namew']    
            else:						
                names[steamid] = mapDicts[map][steamid]['name']
                continue					

def r_getname(steamid):
    steamid = str(steamid)
    if steamid in names:
        return names[steamid]
    for map in mapDicts:
        if steamid in mapDicts[map]:
            if 'name' not in mapDicts[map][steamid]:
                if 'sideways' in mapDicts[map][steamid]:
                    names[steamid] = mapDicts[map][steamid]['sideways']['namesw']
                    return mapDicts[map][steamid]['sideways']['namesw']
                elif 'wonly' in mapDicts[map][steamid]:
                    names[steamid] = mapDicts[map][steamid]['wonly']['namew']
                    return mapDicts[map][steamid]['wonly']['namew']
            else:
                names[steamid] = mapDicts[map][steamid]['name']
                return mapDicts[map][steamid]['name']
    return "unknown"
 
def r_addpoints(map, steamid):
    (_pos, _len) = mk_sortDictIndex(map, steamid)
    if map not in mapscore:
        mapscore[map] = 0.0
    if steamid not in points:
        points[steamid] = {}
        points[steamid]['normal'] = mapscore[map]
        if _pos == 1:
            points[steamid]['normal'] += 20.0
        elif _pos == 2:
            points[steamid]['normal'] += 18.0
        elif _pos == 3:
            points[steamid]['normal'] += 16.0
        elif _pos == 4:
            points[steamid]['normal'] += 14.0
        elif _pos == 5:
            points[steamid]['normal'] += 12.0
        elif _pos == 6:
            points[steamid]['normal'] += 10.0
        elif _pos == 7:
            points[steamid]['normal'] += 8.0
        elif _pos == 8:
            points[steamid]['normal'] += 6.0
        elif _pos == 9:
            points[steamid]['normal'] += 4.0
        elif _pos == 10:
            points[steamid]['normal'] += 2.0

    else:
        points[steamid]['normal'] += mapscore[map]
        if _pos == 1:
            points[steamid]['normal'] += 20.0
        elif _pos == 2:
            points[steamid]['normal'] += 18.0
        elif _pos == 3:
            points[steamid]['normal'] += 16.0
        elif _pos == 4:
            points[steamid]['normal'] += 14.0
        elif _pos == 5:
            points[steamid]['normal'] += 12.0
        elif _pos == 6:
            points[steamid]['normal'] += 10.0
        elif _pos == 7:
            points[steamid]['normal'] += 8.0
        elif _pos == 8:
            points[steamid]['normal'] += 6.0
        elif _pos == 9:
            points[steamid]['normal'] += 4.0
        elif _pos == 10:
            points[steamid]['normal'] += 2.0

				
def r_addswpoints(map, steamid):
    (_pos, _len) = mk_sortDictIndexsw(map, steamid)
    if map not in mapscore:
        mapscore[map] = 0.0
    if steamid not in points:
        points[steamid] = {}
        points[steamid]['normal'] = (mapscore[map] * 1.5)
        points[steamid]['sideways'] = (mapscore[map] * 1.5)
        if _pos == 1:
            points[steamid]['sideways'] += 20.0
            points[steamid]['normal'] += 20.0
        elif _pos == 2:
            points[steamid]['sideways'] += 18.0
            points[steamid]['normal'] += 18.0
        elif _pos == 3:
            points[steamid]['sideways'] += 16.0
            points[steamid]['normal'] += 16.0
        elif _pos == 4:
            points[steamid]['sideways'] += 14.0
            points[steamid]['normal'] += 14.0
        elif _pos == 5:
            points[steamid]['sideways'] += 12.0
            points[steamid]['normal'] += 12.0
        elif _pos == 6:
            points[steamid]['sideways'] += 10.0
            points[steamid]['normal'] += 10.0
        elif _pos == 7:
            points[steamid]['sideways'] += 8.0
            points[steamid]['normal'] += 8.0
        elif _pos == 8:
            points[steamid]['sideways'] += 6.0
            points[steamid]['normal'] += 6.0
        elif _pos == 9:
            points[steamid]['sideways'] += 4.0
            points[steamid]['normal'] += 4.0
        elif _pos == 10:
            points[steamid]['sideways'] += 2.0
            points[steamid]['normal'] += 2.0
    else:
        if 'normal' not in points[steamid]:
            points[steamid]['normal'] = (mapscore[map] * 1.5)
        else: points[steamid]['normal'] += (mapscore[map] * 1.5)
 
        if 'sideways' not in points[steamid]:
            points[steamid]['sideways'] = (mapscore[map] * 1.5)
            if _pos == 1:
                points[steamid]['sideways'] += 20.0
                points[steamid]['normal'] += 20.0
            elif _pos == 2:
                points[steamid]['sideways'] += 18.0
                points[steamid]['normal'] += 18.0
            elif _pos == 3:
                points[steamid]['sideways'] += 16.0
                points[steamid]['normal'] += 16.0
            elif _pos == 4:
                points[steamid]['sideways'] += 14.0
                points[steamid]['normal'] += 14.0
            elif _pos == 5:
                points[steamid]['sideways'] += 12.0
                points[steamid]['normal'] += 12.0
            elif _pos == 6:
                points[steamid]['sideways'] += 10.0
                points[steamid]['normal'] += 10.0
            elif _pos == 7:
                points[steamid]['sideways'] += 8.0
                points[steamid]['normal'] += 8.0
            elif _pos == 8:
                points[steamid]['sideways'] += 6.0
                points[steamid]['normal'] += 6.0
            elif _pos == 9:
                points[steamid]['sideways'] += 4.0
                points[steamid]['normal'] += 4.0
            elif _pos == 10:
                points[steamid]['sideways'] += 2.0
                points[steamid]['normal'] += 2.0
        else:
            points[steamid]['sideways'] += (mapscore[map] * 1.5)
            if _pos == 1:
                points[steamid]['sideways'] += 20.0
                points[steamid]['normal'] += 20.0
            elif _pos == 2:
                points[steamid]['sideways'] += 18.0
                points[steamid]['normal'] += 18.0
            elif _pos == 3:
                points[steamid]['sideways'] += 16.0
                points[steamid]['normal'] += 16.0
            elif _pos == 4:
                points[steamid]['sideways'] += 14.0
                points[steamid]['normal'] += 14.0
            elif _pos == 5:
                points[steamid]['sideways'] += 12.0
                points[steamid]['normal'] += 12.0
            elif _pos == 6:
                points[steamid]['sideways'] += 10.0
                points[steamid]['normal'] += 10.0
            elif _pos == 7:
                points[steamid]['sideways'] += 8.0
                points[steamid]['normal'] += 8.0
            elif _pos == 8:
                points[steamid]['sideways'] += 6.0
                points[steamid]['normal'] += 6.0
            elif _pos == 9:
                points[steamid]['sideways'] += 4.0
                points[steamid]['normal'] += 4.0
            elif _pos == 10:
                points[steamid]['sideways'] += 2.0
                points[steamid]['normal'] += 2.0

def r_addwpoints(map, steamid):
    (_pos, _len) = mk_sortDictIndexw(map, steamid)
    if map not in mapscore:
        mapscore[map] = 0.0
    if steamid not in points:
        points[steamid] = {}
        points[steamid]['normal'] = (mapscore[map] * 1.5)
        points[steamid]['wonly'] = (mapscore[map] * 1.5)
        if _pos == 1:
            points[steamid]['wonly'] += 20.0
            points[steamid]['normal'] += 20.0
        elif _pos == 2:
            points[steamid]['wonly'] += 18.0
            points[steamid]['normal'] += 18.0
        elif _pos == 3:
            points[steamid]['wonly'] += 16.0
            points[steamid]['normal'] += 16.0
        elif _pos == 4:
            points[steamid]['wonly'] += 14.0
            points[steamid]['normal'] += 14.0
        elif _pos == 5:
            points[steamid]['wonly'] += 12.0
            points[steamid]['normal'] += 12.0
        elif _pos == 6:
            points[steamid]['wonly'] += 10.0
            points[steamid]['normal'] += 10.0
        elif _pos == 7:
            points[steamid]['wonly'] += 8.0
            points[steamid]['normal'] += 8.0
        elif _pos == 8:
            points[steamid]['wonly'] += 6.0
            points[steamid]['normal'] += 6.0
        elif _pos == 9:
            points[steamid]['wonly'] += 4.0
            points[steamid]['normal'] += 4.0
        elif _pos == 10:
            points[steamid]['wonly'] += 2.0
            points[steamid]['normal'] += 2.0
    else:
        if 'normal' not in points[steamid]:
            points[steamid]['normal'] = (mapscore[map] * 1.5)
        else: points[steamid]['normal'] += (mapscore[map] * 1.5)
 
        if 'wonly' not in points[steamid]:
            points[steamid]['wonly'] = (mapscore[map] * 1.5)
            if _pos == 1:
                points[steamid]['wonly'] += 20.0
                points[steamid]['normal'] += 20.0
            elif _pos == 2:
                points[steamid]['wonly'] += 18.0
                points[steamid]['normal'] += 18.0
            elif _pos == 3:
                points[steamid]['wonly'] += 16.0
                points[steamid]['normal'] += 16.0
            elif _pos == 4:
                points[steamid]['wonly'] += 14.0
                points[steamid]['normal'] += 14.0
            elif _pos == 5:
                points[steamid]['wonly'] += 12.0
                points[steamid]['normal'] += 12.0
            elif _pos == 6:
                points[steamid]['wonly'] += 10.0
                points[steamid]['normal'] += 10.0
            elif _pos == 7:
                points[steamid]['wonly'] += 8.0
                points[steamid]['normal'] += 8.0
            elif _pos == 8:
                points[steamid]['wonly'] += 6.0
                points[steamid]['normal'] += 6.0
            elif _pos == 9:
                points[steamid]['wonly'] += 4.0
                points[steamid]['normal'] += 4.0
            elif _pos == 10:
                points[steamid]['wonly'] += 2.0
                points[steamid]['normal'] += 2.0
        else:
            points[steamid]['wonly'] += (mapscore[map] * 1.5)
            if _pos == 1:
                points[steamid]['wonly'] += 20.0
                points[steamid]['normal'] += 20.0
            elif _pos == 2:
                points[steamid]['wonly'] += 18.0
                points[steamid]['normal'] += 18.0
            elif _pos == 3:
                points[steamid]['wonly'] += 16.0
                points[steamid]['normal'] += 16.0
            elif _pos == 4:
                points[steamid]['wonly'] += 14.0
                points[steamid]['normal'] += 14.0
            elif _pos == 5:
                points[steamid]['wonly'] += 12.0
                points[steamid]['normal'] += 12.0
            elif _pos == 6:
                points[steamid]['wonly'] += 10.0
                points[steamid]['normal'] += 10.0
            elif _pos == 7:
                points[steamid]['wonly'] += 8.0
                points[steamid]['normal'] += 8.0
            elif _pos == 8:
                points[steamid]['wonly'] += 6.0
                points[steamid]['normal'] += 6.0
            elif _pos == 9:
                points[steamid]['wonly'] += 4.0
                points[steamid]['normal'] += 4.0
            elif _pos == 10:
                points[steamid]['wonly'] += 2.0
                points[steamid]['normal'] += 2.0

				
def sm2es_keyPress(ev):
    uid = int(ev['userid'])
    command = ev["command"]
    status = ev["status"]
    steamid = es.getplayersteamid(uid)
    player = playerlib.getPlayer(uid)
    if (steamid not in started) and (steamid not in startedb):
        return None
		
    if steamid in strafes:
        if strafes[steamid]['on'] == 1:
            if command == 'IN_MOVELEFT' and status == '1':
                strafes[steamid]['count'] += 1
            elif command == 'IN_MOVERIGHT' and status == '1':
                strafes[steamid]['count'] += 1
            elif command == 'IN_FORWARD' and status == '1':
                strafes[steamid]['count'] += 1
            elif command == 'IN_BACK' and status == '1':
                strafes[steamid]['count'] += 1
				
    
    if uid in styles:
        if styles[uid]['normal'] == 1:
            return None
        
    else:
        styles[uid] = { }
        styles[uid]['normal'] = 1
        styles[uid]['sideways'] = 0
        styles[uid]['wonly'] = 0
    if command == 'IN_MOVELEFT':
        if status == '1':
            if styles[uid]['sideways'] == 1:
                player.freeze(1)
                resetvel(uid)
            
            if styles[uid]['wonly'] == 1:
                player.freeze(1)
                resetvel(uid)
            
        else:
            player.freeze(0)
    
    if command == 'IN_MOVERIGHT':
        if status == '1':
            if styles[uid]['sideways'] == 1:
                player.freeze(1)
                resetvel(uid)
            
            if styles[uid]['wonly'] == 1:
                player.freeze(1)
                resetvel(uid)
            
        else:
            player.freeze(0)
    
    if command == 'IN_BACK':
        if status == '1':
            if styles[uid]['wonly'] == 1:
                player.freeze(1)
                resetvel(uid)
            if styles[uid]['sideways'] == 1:
                if uid not in swac:
                    swac[uid] = { }
                    swac[uid]['jumps'] = 0
                    swac[uid]['strafes'] = 0
                
                swac[uid]['strafes'] += 1
            
        else:
            player.freeze(0)
			
def getSound1():
    if top1_sounds_path.isfile():
        with top1_sounds_path.open() as f:
            return filter(None, (line.strip() for line in f.readlines()))
    top1_sounds_path.open('a').close()
    return list()
 
sounds1 = getSound1()
 
def getSound2():
    if top2_sounds_path.isfile():
        with top2_sounds_path.open() as f:
            return filter(None, (line.strip() for line in f.readlines()))
    top2_sounds_path.open('a').close()
    return list()
 
sounds2 = getSound2()

def getSpeed(player):
    x1 = es.getplayerprop(player, 'CBasePlayer.localdata.m_vecVelocity[0]')
    y1 = es.getplayerprop(player, 'CBasePlayer.localdata.m_vecVelocity[1]')
    z1 = es.getplayerprop(player, 'CBasePlayer.localdata.m_vecVelocity[2]')
    return round((x1*x1 + y1*y1 + z1*z1)**0.5, 2)
 
def resetvel(player):
    x = es.getplayerprop(player, "CBasePlayer.localdata.m_vecVelocity[0]") * -1
    y = es.getplayerprop(player, "CBasePlayer.localdata.m_vecVelocity[1]") * -1
    z = es.getplayerprop(player, "CBasePlayer.localdata.m_vecVelocity[2]") * -1
    es.setplayerprop(player, "CBasePlayer.localdata.m_vecBaseVelocity", es.createvectorstring(x, y, z))
	
es.ServerVar('bhop_timer', 2).makepublic()
                                       
adminPopup = popuplib.create("climbtimer_admin")
adminPopup.addline("Bhop-Timer Admin Menu")
adminPopup.addline(" ")
adminPopup.addline("->1. Add/Move the start position")
adminPopup.addline("->2. Add/Move the finish position")
adminPopup.addline("->3. Delete map positions and times")
adminPopup.addline(" ")
adminPopup.addline("->4. Manage current Map Records")
adminPopup.addline(" ")
adminPopup.addline("->5. Add/Move the bonus start position")
adminPopup.addline("->6. Add/Move the bonus end position")
adminPopup.addline("->7. Delete bonus positions and times")
adminPopup.addline(" ")
adminPopup.addline("->8. Manage Anti-Cheat Zones")
adminPopup.addline(" ")
adminPopup.addline("0. Close")
adminPopup.menuselectfb = adminPopupMenuselect

delrec = popuplib.create("climbtimer_delete")
delrec.addline("Delete records from current map (%s)" %currentMap)
delrec.addline(" ")
delrec.addline("->1. Normal")
delrec.addline("->2. W-Only")
delrec.addline("->3. Sideways")
delrec.addline("->4. Bonus Normal")
delrec.addline("->5. Bonus W-Only")
delrec.addline("->6. Bonus Sideways")
delrec.addline(" ")
delrec.addline("->9. Back")
delrec.addline("0. Close")
delrec.menuselectfb = adminDeleteRecords

acPopup = popuplib.create("climbtimer_ac")
acPopup.addline("Anti Cheat Zones")
acPopup.addline(" ")
acPopup.addline("->1. Add/Move 1st anti-cheat position")
acPopup.addline("->2. Add/Move 2nd anti-cheat position")
acPopup.addline("->3. Add/Move 3rd anti-cheat position")
acPopup.addline("->4. Add/Move 4th anti-cheat position")
acPopup.addline("->5. Add/Move 5th anti-cheat position")
acPopup.addline(" ")
acPopup.addline("->9. Back")
acPopup.addline("0. Close")
acPopup.menuselectfb = acPopupMenuselect