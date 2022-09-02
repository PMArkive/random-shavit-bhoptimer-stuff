#!/usr/bin/python3
import argparse
import time
import os
import sys
import re
import struct
import collections
from pprint import pprint

class Dictlist(dict):
	def __setitem__(self, key, value):
		if key in self:
			self[key].append(value)
		else:
			super(Dictlist, self).__setitem__(key, [value])

class CBSPFile:
	def __init__(self, path):
		self.Path = path
		self.BSPFile = None
		self.BSPHeader = None
		self.BSPLumps = dict()

		if not os.path.isfile(self.Path) or not os.access(self.Path, os.R_OK):
			print("Could not open BSP file ({0})!".format(self.Path))
			sys.exit(1)

		self.BSPFile = open(self.Path, "rb")
		self.BSPHeader = self.ReadBSPHeader()

	def __del__(self):
		if self.BSPFile:
			self.BSPFile.close()

	def GetShort(self):
		return struct.unpack("i", self.BSPFile.read(2))[0]

	def GetInt(self):
		return struct.unpack("i", self.BSPFile.read(4))[0]

	def ReadBSPHeader(self):
		# BSP Header https://developer.valvesoftware.com/wiki/Source_BSP_File_Format#BSP_file_header
		Ident = self.GetInt()
		Version = self.GetInt()

		if(Ident != 1347633750):
			print("Faulty BSP file ({0}) version number ({1})!".format(self.Path, Version), file = sys.stderr)
			sys.exit(1)

		# Lump Headers https://developer.valvesoftware.com/wiki/Source_BSP_File_Format#Lump_structure
		Lumps = dict()
		for i in range(64): #define	HEADER_LUMPS 64
			LumpOffset = self.GetInt()
			LumpLength = self.GetInt()
			LumpVersion = self.GetInt()
			LumpIdent = self.GetInt() # char[4]

			Lump = dict({"fileofs": LumpOffset, "filelen": LumpLength, "version": LumpVersion, "fourCC": LumpIdent})
			Lumps[i] = Lump

		Revision = self.GetInt()

		return dict({"ident": Ident, "version": Version, "lumps": Lumps, "mapRevision": Revision})

	def ReadLump(self, lump):
		if lump < 0 or lump >= 64:
			return None

		if lump in self.BSPLumps:
			return self.BSPLumps[lump]

		Offset = self.BSPHeader["lumps"][lump]["fileofs"]
		Length = self.BSPHeader["lumps"][lump]["filelen"]

		self.BSPFile.seek(Offset, 0)
		self.BSPLumps[lump] = memoryview(self.BSPFile.read(Length))
		return self.BSPLumps[lump]

class CModels:
	dmodel_t = struct.Struct("fff fff fff iii")
	dface_t = struct.Struct("H BB i hhhh BBBB i f ii ii i HH I")
	dedge_t = struct.Struct("HH")
	dvertex_t = struct.Struct("fff")
	dsurfedge_t = struct.Struct("i")
	dplane_t = struct.Struct("fff f i")
	def __init__(self, model_lump):
		self.ModelLump = model_lump
		self.Models = []
		self.NumModels = 0
		self.NumPlanes = 0
		self.NumFaces = 0
		self.NumOrigFaces = 0

	def ParseModels(self):
		if not self.ModelLump:
			return -1

		# Skip model 0 = world
		for Item in self.dmodel_t.iter_unpack(self.ModelLump[self.dmodel_t.size:]):
			Model = dict()
			Model["mins"] = Item[0:3]
			Model["maxs"] = Item[3:6]
			Model["origin"] = Item[6:9]
			Model["headnode"] = Item[9]
			Model["firstface"] = Item[10]
			Model["numfaces"] = Item[11]

			self.Models.append(Model)
			self.NumModels += 1

		del self.ModelLump
		return self.NumModels

	def ParseModelFaces(self, plane_lump, face_lump, orig_face_lump):
		Planes = []
		for Item in self.dplane_t.iter_unpack(plane_lump):
			Plane = dict()
			Plane["normal"] = Item[0:3]
			Plane["dist"] = Item[3]
			Plane["type"] = Item[4]
			Planes.append(Plane)
			self.NumPlanes += 1

		Faces = []
		for Item in self.dface_t.iter_unpack(face_lump):
			Face = dict()
#			Face["planenum"] = Item[0]
#			Face["side"] = Item[1]
#			Face["onNode"] = Item[2]
#			Face["firstedge"] = Item[3]
#			Face["numedges"] = Item[4]
#			Face["texinfo"] = Item[5]
#			Face["dispinfo"] = Item[6]
#			Face["surfaceFogVolumeID"] = Item[7]
#			Face["styles"] = Item[8:12]
#			Face["lightofs"] = Item[12]
#			Face["area"] = Item[13]
#			Face["LightmapTextureMinsInLuxels"] = Item[14:16]
#			Face["LightmapTextureSizeInLuxels"] = Item[16:18]
			Face["origFace"] = Item[18]
#			Face["numPrims"] = Item[19]
#			Face["firstPrimID"] = Item[20]
#			Face["smoothingGroups"] = Item[21]
#
#			Face["_plane"] = Planes[Face["planenum"]]

			Faces.append(Face)
			self.NumFaces += 1
#		del Planes

		OrigFaces = []
		for Item in self.dface_t.iter_unpack(orig_face_lump):
			Face = dict()
			Face["planenum"] = Item[0]
			Face["side"] = Item[1]
			Face["onNode"] = Item[2]
			Face["firstedge"] = Item[3]
			Face["numedges"] = Item[4]
			Face["texinfo"] = Item[5]
			Face["dispinfo"] = Item[6]
			Face["surfaceFogVolumeID"] = Item[7]
			Face["styles"] = Item[8:12]
			Face["lightofs"] = Item[12]
			Face["area"] = Item[13]
			Face["LightmapTextureMinsInLuxels"] = Item[14:16]
			Face["LightmapTextureSizeInLuxels"] = Item[16:18]
			Face["origFace"] = Item[18]
			Face["numPrims"] = Item[19]
			Face["firstPrimID"] = Item[20]
			Face["smoothingGroups"] = Item[21]

			Face["_plane"] = Planes[Face["planenum"]]

			OrigFaces.append(Face)
			self.NumOrigFaces += 1
		del Planes

#		Vertices = []
#		NumVertices = 0
#		for Item in self.dvertex_t.iter_unpack(vertex_lump):
#			Vertices.append(Item[0:3])
#			NumVertices += 1
#
#		del vertex_lump
#
#		SurfEdges = []
#		NumSurfEdges = 0
#		for Item in self.dsurfedge_t.iter_unpack(surf_edge_lump):
#			SurfEdges.append(Item[0])
#			NumSurfEdges += 1
#
#		Edges = []
#		NumEdges = 0
#		for Item in self.dedge_t.iter_unpack(edge_lump):
#			Edge = (Vertices[Item[0]], Vertices[Item[1]])
#			Edges.append(Edge)
#			NumEdges += 1
#
#		for Face in Faces:
#			SurfEdge = Face["firstedge"]
#			FirstEdge = abs(SurfEdge)
#			LastEdge = FirstEdge + Face["numedges"]
#			if SurfEdge > 0:
#				Face["_edges"] = Edges[FirstEdge:LastEdge]
#			else:
#				FaceEdges = Edges[FirstEdge:LastEdge]
#				for Index, FaceEdge in enumerate(FaceEdges):
#					FaceEdges[Index] = (FaceEdge[1], FaceEdge[0])
#				Face["_edges"] = FaceEdges

		for Model in self.Models:
			FirstFace = Model["firstface"]
			LastFace = FirstFace + Model["numfaces"] - 1

			FirstFace = Faces[FirstFace]["origFace"]
			LastFace = Faces[LastFace]["origFace"]

			Model["_faces"] = OrigFaces[FirstFace:LastFace]
		del Faces
		del OrigFaces

		return self.NumFaces

class CEntities:
	reKeyValue = re.compile(r'\"([^\"]+)\"\s+\"([^\"]*)\"')
	def __init__(self, entity_lump):
		self.EntityLump = entity_lump.tobytes().decode("ascii")
		self.Entities = []
		self.NumEntities = 0
		self.NonUniqueHammerIDs = []

	def ParseEntities(self):
		if not self.EntityLump:
			return -1

		HammerIDs = []
		NumEnts = 0
		ValidEnts = 0
		EntityPos = 0
		while True:
			EntityPos = self.EntityLump.find('{', EntityPos)
			if EntityPos == -1:
				break
			EntityPos += 1
			NumEnts += 1

			NumItems = 0
			Entity = Dictlist()
			while self.EntityLump[EntityPos]:
				if self.EntityLump[EntityPos] == '"':
					Match = self.reKeyValue.match(self.EntityLump, EntityPos)
					if not Match:
						EntityPos += 1
						continue

					Key, Value = Match.groups()
					Entity[Key] = Value
					NumItems += 1

					EntityPos = Match.end()
				elif self.EntityLump[EntityPos] == '}' and len(Entity):
					self.Entities.append(Entity)
					ValidEnts += 1
					EntityPos += 1

					if "hammerid" in Entity:
						HammerIDs.extend(Entity["hammerid"])

					break
				else:
					EntityPos += 1

		self.NonUniqueHammerIDs = [k for (k, v) in collections.Counter(HammerIDs).items() if v > 1]

		self.NumEntities = ValidEnts
		del self.EntityLump
		return self.NumEntities

def GenerateStripperMatch(Entity, tabs):
	print("{0}\"classname\" \"{1}\"".format(tabs, Entity["classname"][0]))
	if "targetname" in Entity:
		print("{0}\"targetname\" \"{1}\"".format(tabs, Entity["targetname"][0]))
	if "origin" in Entity:
		print("{0}\"origin\" \"{1}\"".format(tabs, Entity["origin"][0]))
	if "model" in Entity:
		print("{0}\"model\" \"{1}\"".format(tabs, Entity["model"][0]))
	if "hammerid" in Entity:
		print("{0}\"hammerid\" \"{1}\"".format(tabs, Entity["hammerid"][0]))

def GenerateStripperModify(EntityIn, EntityOut):
	print("modify:\n{")
	print("\tmatch:\n\t{")
	GenerateStripperMatch(EntityIn, "\t\t")
	print("\t}")

	Replace = []
	Delete = []
	Insert = []

	for Key, ValuesOut in EntityOut.items():
		if Key in EntityIn:
			ValuesIn = EntityIn[Key]
			ValuesOutLen = len(ValuesOut)
			ValuesInLen = len(ValuesIn)
			# Key is used only once, can be replaced
			if ValuesOutLen == ValuesInLen == 1:
				if ValuesOut[0] != ValuesIn[0]:
					Replace.append((Key, ValuesOut[0]))
			else: # Key has multiple values
				ValuesOutCopy = ValuesOut[:]
				ValuesInCopy = ValuesIn[:]
				ValuesOutCopyLength = ValuesOutLen
				IndexOut = 0

				# Remove equal key-value pairs
				while IndexOut < ValuesOutCopyLength:
					ValueOut = ValuesOutCopy[IndexOut]

					for IndexIn, ValueIn in enumerate(ValuesInCopy):
						if ValueOut == ValueIn:
							del ValuesOutCopy[IndexOut]
							del ValuesInCopy[IndexIn]
							IndexOut -= 1
							ValuesOutCopyLength -= 1
							break

					IndexOut += 1

				# ValuesOutCopy holds the key-value pairs to insert
				for Value in ValuesOutCopy:
					Insert.append((Key, Value))

				# ValuesInCopy holds the key-value pairs to delete
				for Value in ValuesInCopy:
					Delete.append((Key, Value))
		else:
			for Value in ValuesOut:
				Insert.append((Key, Value))

	# Deleted keys
	for Key, Values in EntityIn.items():
		if not Key in EntityOut:
			for Value in Values:
				Delete.append((Key, Value))

	if len(Replace):
		print("\treplace:\n\t{")
		for (Key, Value) in Replace:
			print("\t\t\"{0}\" \"{1}\"".format(Key, Value))
		print("\t}")

	if len(Delete):
		print("\tdelete:\n\t{")
		for (Key, Value) in Delete:
			print("\t\t\"{0}\" \"{1}\"".format(Key, Value))
		print("\t}")

	if len(Insert):
		print("\tinsert:\n\t{")
		for (Key, Value) in Insert:
			print("\t\t\"{0}\" \"{1}\"".format(Key, Value))
		print("\t}")

	print("}")

def GenerateStripperFilter(Entity):
	print("filter:\n{")
	GenerateStripperMatch(Entity, "\t")
	print("}")

def GenerateStripperAdd(Entity):
	print("add:\n{")
	for Key, Value_ in Entity.items():
		for Value in Value_:
			print("\t\"{0}\" \"{1}\"".format(Key, Value))
	print("}")

if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("orig_bsp", metavar="original bsp", help="original bsp file", type=str)
	parser.add_argument("modified_bsp", metavar="modified bsp", help="modified bsp file", type=str)
	args = parser.parse_args()

	TimeStart = time.time()

	# Original BSP
	BSPFile = CBSPFile(args.orig_bsp)
	EntityLump = BSPFile.ReadLump(0)
	OrigEnts = CEntities(EntityLump)
	del EntityLump

	ModelLump = BSPFile.ReadLump(14)
	OrigModels = CModels(ModelLump)
	del ModelLump
	OrigModels.ParseModels()

	FaceLump = BSPFile.ReadLump(7)
	OrigFaceLump = BSPFile.ReadLump(27)
	PlaneLump = BSPFile.ReadLump(1)
	#OrigModels.ParseModelFaces(PlaneLump, FaceLump, OrigFaceLump)
	del FaceLump
	del PlaneLump
	del BSPFile

	# Modified BSP
	BSPFile = CBSPFile(args.modified_bsp)
	EntityLump = BSPFile.ReadLump(0)
	ModifiedEnts = CEntities(EntityLump)
	del EntityLump

	ModelLump = BSPFile.ReadLump(14)
	ModifiedModels = CModels(ModelLump)
	del ModelLump
	ModifiedModels.ParseModels()

	FaceLump = BSPFile.ReadLump(7)
	OrigFaceLump = BSPFile.ReadLump(27)
	PlaneLump = BSPFile.ReadLump(1)
	#ModifiedModels.ParseModelFaces(PlaneLump, FaceLump, OrigFaceLump)
	del FaceLump
	del PlaneLump
	del BSPFile

	OrigEnts.ParseEntities()
	ModifiedEnts.ParseEntities()

	NonUniqueHammerIDs = set(OrigEnts.NonUniqueHammerIDs + ModifiedEnts.NonUniqueHammerIDs)

	print("; Comparing \"{0}\" ({1} entities) with \"{2}\" ({3} entities)".format(
		os.path.basename(args.orig_bsp), OrigEnts.NumEntities, os.path.basename(args.modified_bsp), ModifiedEnts.NumEntities))

	#pprint(ModifiedModels.Models)
	#sys.exit(0)

	# Remove equal entities
	ModifiedEntsLength = ModifiedEnts.NumEntities
	Index = 0
	while Index < ModifiedEntsLength:
		Entity = ModifiedEnts.Entities[Index]

		for Index_, Entity_ in enumerate(OrigEnts.Entities):
			if Entity == Entity_:
				del ModifiedEnts.Entities[Index]
				del OrigEnts.Entities[Index_]
				Index -= 1 # because we deleted the current index
				ModifiedEntsLength -= 1
				break

		Index += 1

	print("; Removed {0} identical entities.".format(ModifiedEnts.NumEntities - ModifiedEntsLength))
	ModifiedEntsLength_ = ModifiedEntsLength

	print("")
	print(";  __  __  ____  _____ _____ ________     __")
	print("; |  \/  |/ __ \|  __ \_   _|  ____\ \   / /")
	print("; | \  / | |  | | |  | || | | |__   \ \_/ /")
	print("; | |\/| | |  | | |  | || | |  __|   \   /")
	print("; | |  | | |__| | |__| || |_| |       | |")
	print("; |_|  |_|\____/|_____/_____|_|       |_|")

	# Find modified entities
	Index = 0
	while Index < ModifiedEntsLength:
		Entity = ModifiedEnts.Entities[Index]

		for Index_, Entity_ in enumerate(OrigEnts.Entities):
			if "hammerid" in Entity and "hammerid" in Entity_ and \
			Entity["hammerid"] == Entity_["hammerid"] and \
			not Entity["hammerid"][0] in NonUniqueHammerIDs:
				GenerateStripperModify(Entity_, Entity)
				del ModifiedEnts.Entities[Index]
				del OrigEnts.Entities[Index_]
				Index -= 1 # because we deleted the current index
				ModifiedEntsLength -= 1
				break
			elif Entity["classname"] == Entity_["classname"]:
				Targetname = None
				if "targetname" in Entity and "targetname" in Entity_:
					Targetname = False
					if Entity["targetname"] == Entity_["targetname"]:
						Targetname = True

				Origin = None
				if "origin" in Entity and "origin" in Entity_:
					Origin = False
					if Entity["origin"] == Entity_["origin"]:
						Origin = True

				Model = None
				if "model" in Entity and "model" in Entity_:
					Model = False
					if Entity["model"] == Entity_["model"]:
						Model = True

				if Targetname and Origin and Model != False:
					GenerateStripperModify(Entity_, Entity)
					del ModifiedEnts.Entities[Index]
					del OrigEnts.Entities[Index_]
					Index -= 1 # because we deleted the current index
					ModifiedEntsLength -= 1
					break

		Index += 1

	print("; Generated {0} modify blocks.".format(ModifiedEntsLength_ - ModifiedEntsLength))
	ModifiedEntsLength_ = ModifiedEntsLength

	# Entities which need to be deleted in the modified map reside in the OrigEnts.Entities list
	# Entities which need to be added to the modified map reside in the ModifiedEnts.Entities list

	print("")
	print(";  ______ _____ _   _______ ______ _____")
	print("; |  ____|_   _| | |__   __|  ____|  __ \\")
	print("; | |__    | | | |    | |  | |__  | |__) |")
	print("; |  __|   | | | |    | |  |  __| |  _  /")
	print("; | |     _| |_| |____| |  | |____| | \ \\")
	print("; |_|    |_____|______|_|  |______|_|  \_\\")

	Filtered = 0
	for Entity in OrigEnts.Entities:
		GenerateStripperFilter(Entity)
		Filtered += 1

	print("; Generated {0} filter blocks.".format(Filtered))

	print("")
	print(";           _____  _____")
	print(";     /\   |  __ \|  __ \\")
	print(";    /  \  | |  | | |  | |")
	print(";   / /\ \ | |  | | |  | |")
	print(";  / ____ \| |__| | |__| |")
	print("; /_/    \_\_____/|_____/")

	Added = 0
	for Entity in ModifiedEnts.Entities:
		#if "model" in Entity and Entity["model"][0] == '*':
		#	ModelIndex = int(Entity["model"][1:])
		#	if ModelIndex >= OrigModels.NumModels:
		#		print("Invalid modelindex ({0})".format(ModelIndex), file = sys.stderr)

		GenerateStripperAdd(Entity)
		Added += 1

	print("; Generated {0} add blocks.".format(Added))
	print("")
	print("; File generated on {0} in {1} seconds.".format(time.strftime("%a, %d %b %Y %H:%M:%S +0000", time.gmtime()), time.time() - TimeStart))