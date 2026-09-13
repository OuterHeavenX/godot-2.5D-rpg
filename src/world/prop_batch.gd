class_name PropBatch
extends RefCounted
## Collects scenery into MultiMesh draws.
##
## A wilderness full of individual MeshInstance3D nodes costs one draw
## call per rock. Grouping every copy of a mesh into one MultiMesh keeps
## the browser's frame budget intact when a region has thousands of props.
##
##   var batch := PropBatch.new()
##   batch.add("rock", rock_mesh, Transform3D(...))
##   batch.build(self)

var _batches := {} # key -> {"mesh": Mesh, "xforms": Array}

## Queue one copy of `mesh` at `xform`. Everything sharing a key must
## share a mesh.
func add(key: String, mesh: Mesh, xform: Transform3D) -> void:
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "xforms": []}
	(_batches[key]["xforms"] as Array).append(xform)

## How many copies are queued under a key.
func count(key: String) -> int:
	if not _batches.has(key):
		return 0
	return (_batches[key]["xforms"] as Array).size()

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
