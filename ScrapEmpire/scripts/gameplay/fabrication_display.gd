extends Node3D
var _label: Label3D
var _model: Node3D
var _kind: String = ""
var _elapsed: float = 0.0
var _work_light: OmniLight3D

func _ready() -> void:
	add_to_group("fabrication_display")
	add_to_group("operations_service")
	set_meta("operation","fabrication")
	if DisplayServer.get_name()=="headless":
		return
	var art = preload("res://scripts/gameplay/scrapyard_art.gd").new()
	art.box(self,Vector3(2,0.12,1.3),Vector3(0,1,0),art.STEEL)
	for side in [-1,1]:
		art.box(self,Vector3(0.12,1,1),Vector3(side*0.85,0.5,0),art.GRAPHITE)
	art.box(self,Vector3(1.8,0.9,0.08),Vector3(0,1.55,0.55),Color("#315d59"))
	_label=art.sign_text(self,"ASSEMBLAGGIO\nBANCO LIBERO",Vector3(0,2.2,0),28,true)
	_label.pixel_size=0.003
	_work_light=OmniLight3D.new()
	_work_light.position=Vector3(0,1.8,0)
	_work_light.omni_range=2.5
	_work_light.light_color=art.MINT
	_work_light.light_energy=0
	add_child(_work_light)

func _process(delta: float) -> void:
	if _label==null:
		return
	_elapsed+=delta
	if _elapsed<0.2:
		return
	_elapsed=0
	var jobs: Array = GameState.fabrication.jobs()
	var kind: String = str(jobs[0].kind) if not jobs.is_empty() else ""
	if kind!=_kind:
		_kind=kind
		if is_instance_valid(_model):
			_model.queue_free()
		_model=null
		if not kind.is_empty():
			_model=Node3D.new()
			_model.position=Vector3(0,1.08,0)
			add_child(_model)
			preload("res://scripts/gameplay/product_models.gd").build(_model,kind)
	if jobs.is_empty():
		_label.text="ASSEMBLAGGIO · BANCO LIBERO\nSCEGLI I PRODOTTI AL BANCO COSTRUZIONE"
		_work_light.light_energy=0
	else:
		_label.text="%s\n%.0f%% · %.0f s · %d IN CODA" % [GameState.crafting.definitions()[kind].name.to_upper(),(1.0-float(jobs[0].remaining)/float(jobs[0].duration))*100.0,jobs[0].remaining,jobs.size()-1]
		_work_light.light_energy=0.35+sin(Time.get_ticks_msec()*0.006)*0.15
