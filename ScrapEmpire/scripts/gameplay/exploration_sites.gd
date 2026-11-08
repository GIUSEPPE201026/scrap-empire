extends RefCounted

static func build(root: Node3D) -> void:
	var art=preload("res://scripts/gameplay/scrapyard_art.gd").new()
	var scenery=Node3D.new()
	scenery.name="ExplorationArt"
	root.add_child(scenery)
	var sites: Array=GameState.logistics_def.outposts.duplicate(true)
	sites.append({"id":"yard_crate","name":"Recuperi sigillati","position":[26,0,-32]})
	for site in sites:
		var base=Vector3(site.position[0],0,site.position[2])
		base.y=preload("res://scripts/gameplay/desert_world.gd").height_at(base)
		for index in 2:
			var crate=StaticBody3D.new()
			crate.set_script(preload("res://scripts/gameplay/salvage_assembly.gd"))
			crate.definition_id="sealed_crate"
			crate.entity_id="cache_%s_%d" % [site.id,index]
			crate.position=base+Vector3(index*4,0,0)
			crate.position.y=preload("res://scripts/gameplay/desert_world.gd").height_at(crate.position)
			root.add_child(crate)
		if DisplayServer.get_name()!="headless":
			art.sign_text(scenery,site.name.to_upper()+"\nLEVA · CESOIE · CACCIAVITE",base+Vector3(0,3,3),38,true)
			for i in 7:
				var point=base+Vector3(-5+i*2,0,-5-float(i%3)*2)
				point.y=preload("res://scripts/gameplay/desert_world.gd").height_at(point)
				art.barrel(scenery,point,[art.RUST,art.STEEL,art.MINT][i%3])
