class_name PropBatch
extends RefCounted
## Collects scenery into MultiMesh draws.
##
## A wilderness full of individual MeshInstance3D nodes costs one draw
## call per rock. Grouping every copy of a mesh into one MultiMesh keeps
## the browser's frame budget intact when a region has thousands of props.
##
## Batches are split into square chunks of ground. One batch spanning a
## whole region would draw every one of its copies whenever any corner of
## it was on screen — the renderer culls a MultiMesh as a single lump —
## so a 240m road would draw all ten thousand of its trees at once.
##
##   var batch := PropBatch.new()
##   batch.add("rock", rock_mesh, Transform3D(...))
##   batch.build(self)

## Side of one chunk of ground, in metres.
const CHUNK := 48.0

var _batches := {} # key -> {"mesh": Mesh, "xforms": Array}

## Queue one copy of `mesh` at `xform`. Everything sharing a key must
## share a mesh.
func add(key: String, mesh: Mesh, xform: Transform3D) -> void:
	var chunk_key := "%s@%d_%d" % [key,
		int(floor(xform.origin.x / CHUNK)), int(floor(xform.origin.z / CHUNK))]
	if not _batches.has(chunk_key):
		_batches[chunk_key] = {"mesh": mesh, "xforms": []}
	(_batches[chunk_key]["xforms"] as Array).append(xform)

## How many copies are queued under a key, across every chunk.
func count(key: String) -> int:
	var total := 0
	for k in _batches:
		if String(k).begins_with(key + "@"):
			total += (_batches[k]["xforms"] as Array).size()
	return total

## Turn every queued batch into a MultiMeshInstance3D under `parent`.
func build(parent: Node3D) -> void:
	for key in _batches:
		var entry: Dictionary = _batches[key]
		var xforms: Array = entry["xforms"]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry["mesh"] as Mesh
		mm.instance_count = xforms.size()
		for i in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batch_%s" % String(key)
		mmi.multimesh = mm
		parent.add_child(mmi)
	_batches.clear()
