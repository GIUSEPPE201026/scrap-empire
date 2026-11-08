extends RefCounted
## Original, resolution-independent service symbols. Text remains beside every icon.
static var _textures: Dictionary = {}
const SHAPES = {
	"skateboard": '<path d="m3 18 22-7q8-2 5 3L8 23q-7 2-5-5Zm4 5v4m17-10v5"/><circle cx="8" cy="27" r="2"/><circle cx="24" cy="23" r="2"/>',
	"dirtbike": '<circle cx="7" cy="24" r="6"/><circle cx="26" cy="24" r="5"/><path d="m7 24 6-12 7 12H7Zm6-12h9l4 12M10 9h8m2-6h5l-3 9M4 15h7"/>',
	"yard_wall": '<path d="M3 29V5h26v24M3 8h26M7 8v21m6-21v21m6-21v21m6-21v21M1 29h30"/>',
	"yard_canopy": '<path d="m2 10 14-6 14 6-14 5-14-5Zm3 2v16m22-16v16M16 15v13M12 19h8m-4-4v4"/>',
	"yard_platform": '<path d="m2 12 16-6 12 7-16 6-12-7Zm0 0v7l12 7 16-6v-7M14 19v7M6 14l15-6m-8 10 14-6"/>',
	"hands": '<path d="M7 27 3 17q0-4 3-1l3 4V7q2-4 4 0v9V4q2-3 4 0v12V6q2-3 4 0v10V9q3-3 4 1v12l-5 7H9Z"/>',
	"screwdriver": '<path d="m5 28 13-13m-3-5 6-6q3-2 6 1t0 5l-6 7-6-7ZM3 30l4-2-2-2-2 4Z"/>',
	"hammer": '<path d="m7 29 13-19m-9-3 5-5 13 9-4 6-14-10Z"/>',
	"crowbar": '<path d="m7 29 12-19q6-10 10-5l-5 7m-17 17-3-4 4-4"/>',
	"cutters": '<path d="m6 28 10-15L26 3M26 28 16 13 6 3M6 3l1 8 9 2 9-2 1-8"/><circle cx="16" cy="13" r="2"/>',
	"metal": '<path d="m4 12 17-7 7 5-17 7-7-5Zm0 0v8l7 6 17-8v-8M11 17v9"/>',
	"plastic": '<path d="M13 3h6v5l4 5v14H9V13l4-5V3Zm-4 13h14M9 24h14M13 6h6"/>',
	"electronics": '<rect x="5" y="5" width="22" height="22" rx="2"/><rect x="11" y="11" width="10" height="10"/><path d="M14 5v6m4-6v6m-4 10v6m4-6v6M5 14h6m-6 4h6m10-4h6m-6 4h6"/>',
	"rubber": '<circle cx="16" cy="16" r="12"/><circle cx="16" cy="16" r="6"/><path d="m6 8 4 2m12 12 4 2M5 17h5m12-2h5M15 4v6m2 12v6"/>',
	"glass": '<path d="m16 3 11 9-4 16H8L4 13 16 3Zm0 0 3 12-8 5 12 8m-4-13 8-3M11 20 4 13"/>',
	"copper": '<path d="M7 24q-5-5 0-10l11-9q6-4 10 1t-2 9L14 25q-6 5-10 0m6-4 12-10q3-3 0-4L9 17q-3 3 1 4Z"/>',
	"wheel": '<circle cx="16" cy="16" r="13"/><circle cx="16" cy="16" r="8"/><circle cx="16" cy="16" r="2"/><path d="m16 8 0 6m2 2h6m-8 2v6m-8-8h6"/>',
	"battery": '<path d="M6 8h20v20H6V8Zm4-4h4v4m4-4h4v4M10 15h5m-3-3v6m7-3h4"/>',
	"engine": '<path d="M6 11h5V7h11v5h5v13H8v-6H4v-6h2m8-10h6M4 20v5m18-10h7v7"/>',
	"panel": '<path d="M4 5h24v22H4V5Zm5 0v22m14-22v22M4 12h24M4 20h24"/>',
	"suspension": '<path d="M16 2v5l-7 3 14 4-14 4 14 4-7 3v5"/>',
	"radio": '<rect x="3" y="9" width="26" height="20" rx="3"/><path d="M7 9 25 2M6 14h20M6 18h9m-9 4h9m-9 4h9"/><circle cx="23" cy="23" r="3"/>',
	"bench": '<path d="M5 27V5m22 22V5M5 8h22M5 13h22M2 20h28M7 20v10m18-10v10"/>',
	"repair": '<path d="M5 10h22v18H5V10Zm7 0V5h8v5m-4 5v9m-4-5h8"/>',
	"handcart": '<path d="M3 10h23l-4 13H9L5 6H1m7 17h18"/><circle cx="10" cy="27" r="3"/><circle cx="23" cy="27" r="3"/>',
	"paint": '<path d="m5 21 16-16 7 7-16 16H5v-7Zm14-14 7 7M5 24l3 4M4 5q6 4 0 8Q0 9 4 5Z"/>',
	"eye": '<path d="M2 16q14-21 28 0Q16 37 2 16Z"/><circle cx="16" cy="16" r="5"/>',
	"scan": '<path d="M4 12V4h8m8 0h8v8m0 8v8h-8m-8 0H4v-8M8 16h16M16 8v16"/>',
	"install": '<path d="M4 24v5h24v-5M16 3v19m-7-7 7 7 7-7"/>',
	"bag": '<rect x="7" y="10" width="18" height="18" rx="4"/><path d="M12 10V7a4 4 0 0 1 8 0v3M11 20h10M12 25h8"/>',
	"sell": '<path d="M4 9h24M16 4v23M9 28h14M8 9l-5 11h10L8 9Zm16 0-5 11h10L24 9Z"/>',
	"garage": '<path d="m3 12 13-9 13 9v17H3V12Zm5 17V14h16v15M8 19h16M8 24h16"/>',
	"craft": '<path d="m5 27 13-13M20 5l7 7-5 5-7-7 5-5ZM5 5l6 6M4 4l4 1 3 6-2 2-5-5V4Zm15 16 8 8"/>',
	"box": '<path d="m3 9 13-6 13 6v15l-13 6-13-6V9Zm0 0 13 6 13-6M16 15v15M9 6l14 6"/>',
	"press": '<path d="M4 4h24M7 4v24m18-24v24M3 28h26M12 5v9h8V5M10 14h12v4H10zM11 23h10v5H11z"/>',
	"map": '<path d="m3 7 9-4 8 4 9-4v23l-9 4-8-4-9 4V7Zm9-4v23m8-19v23"/>',
	"book": '<path d="M5 4h19v24H5a3 3 0 0 1 0-6h19M8 4v18M12 9h8m-8 5h6"/>',
	"coin": '<circle cx="16" cy="16" r="12"/><path d="m12 10 8 0 3 6-4 6h-7l-3-6 3-6Z"/>',
	"play": '<path d="m10 5 16 11-16 11V5Z"/>',
	"settings": '<path d="M5 8h22M5 16h22M5 24h22"/><circle cx="12" cy="8" r="3" fill="#152630"/><circle cx="21" cy="16" r="3" fill="#152630"/><circle cx="10" cy="24" r="3" fill="#152630"/>',
	"close": '<path d="m8 8 16 16M24 8 8 24"/>',
	"route": '<path d="m4 14 24-10-10 24-3-11-11-3Z"/>',
	"check": '<path d="m5 16 7 7L27 8"/>',
	"clock": '<circle cx="16" cy="16" r="12"/><path d="M16 8v9l6 3"/>',
	"person": '<circle cx="16" cy="9" r="5"/><path d="M5 29v-4a11 11 0 0 1 22 0v4"/>',
	"land": '<path d="m2 27 10-19 7 12 4-7 7 14H2Zm10-19 2-5 4 8"/>',
	"light": '<path d="M11 23h10m-9 4h8M10 19a10 10 0 1 1 12 0l-1 4H11l-1-4ZM16 1v2M2 12h2m24 0h2"/>',
	"scooter": '<circle cx="7" cy="26" r="3"/><circle cx="26" cy="26" r="3"/><path d="M7 26h13l6-4-5-17h-6M21 10h5"/>',
	"truck": '<path d="M3 8h16v16H3V8Zm16 6h6l4 7v3H19V14Z"/><circle cx="8" cy="25" r="4"/><circle cx="24" cy="25" r="4"/>',
}

static func icon(key: String, pixels: int=32) -> Texture2D:
	var cache_key: String=key+str(pixels)
	if not _textures.has(cache_key):
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="'+str(pixels)+'" height="'+str(pixels)+'" viewBox="0 0 32 32"><g fill="none" stroke="#e7eceb" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'+SHAPES.get(key,SHAPES.box)+'</g></svg>'
		var image = Image.new()
		if image.load_svg_from_string(svg) != OK:
			return null
		_textures[cache_key] = ImageTexture.create_from_image(image)
	return _textures[cache_key]

static func identity(title: String) -> Array:
	if title.contains("CLIENTI"):
		return ["Cliente","person","#bba9ed"]
	if title.contains("PLANIMETRIA"):
		return ["Espansioni","land","#d6c48a"]
	if title.contains("LIBRO"):
		return ["Collezione","book","#bba9ed"]
	if title.contains("ALBUM"):
		return ["Curiosità","book","#bba9ed"]
	if title.contains("SCARICO SATELLITE"):
		return ["Scarico","box","#84d7bd"]
	if title=="BILANCIA / MATERIALI":
		return ["Materiali","sell","#efc374"]
	for entry in [["ATTREZZATURA PERSONALE","Attrezzi","bag","#84d7bd"],["BILANCIA","Bilancia","sell","#efc374"],["PARCO MEZZI","Garage","garage","#ecab78"],["COSTRUZION","Officina","craft","#9ac5ef"],["ASSEMBLAGGIO","Assemblaggio","clock","#9ac5ef"],["COMPONENTI","Componenti","box","#84d7bd"],["RECUPERO","Recupero","craft","#84d7bd"],["CASSONE","Cassone","truck","#ecab78"],["PRESSA","Pressa","press","#edba6d"],["DIARIO","Diario","book","#bba9ed"],["SPEDIZIONI","Forniture","box","#9ac5ef"],["CLIENTI","Cliente","person","#bba9ed"],["LOTTO","Espansioni","land","#d6c48a"]]:
		if title.contains(entry[0]):
			return entry.slice(1)
	return [title.capitalize(),"box","#84d7bd"]

static func compact(button: Button) -> void:
	var original: String = button.text
	var labels = {
		"CHIUDI PLANIMETRIA":"Chiudi", "CHIUDI ALBUM":"Chiudi", "TORNA AL RECUPERO":"Chiudi", "TRASFERISCI TUTTA LA SACCA":"Deposita", "ALLESTISCI E APRI IL LOTTO":"Apri lotto",
		"APRI DIARIO · STORIA / PROGETTI / MAPPA":"Apri diario", "ESCI DAL MONITOR · ESC":"Chiudi · Esc", "ESCI DAL MONITOR  ·  ESC":"Chiudi · Esc", "AVVICINATI AL MONITOR E PREMI E":"Premi E", "AVVICINATI E PREMI E":"Premi E",
		"TORNA ALLA BILANCIA":"Bilancia", "CODA DI PRODUZIONE E TRAMOGGIA":"Produzione", "ACCETTA RICHIESTA":"Accetta", "ANNULLA · i pezzi diventano materiali nelle rispettive scorte":"Annulla…",
		"TORNA AL LAVORO":"Chiudi", "CHIUDI ATTREZZATURA":"Chiudi", "ESCI DAL GARAGE":"Chiudi",
		"DEPOSITA LA SACCA":"Deposita", "VENDI SOLO GLI AVANZI":"Vendi avanzi", "VENDI TUTTE LE SCORTE LIBERE…":"Vendi tutto…",
		"MATERIALI / SINGOLE UNITÀ":"Materiali", "COMPONENTI / MAGAZZINO":"Componenti",
		"NUOVA SPEDIZIONE · RINNOVA I RECUPERI":"Nuova spedizione",
		"METTI IN ASSEMBLAGGIO":"Assembla", "COSTRUISCI · USA LE SCORTE":"Costruisci", "TROVA REQUISITI":"Trova risorse",
		"PRODOTTI DA VENDERE":"Prodotti", "ATTREZZATURA COSTRUITA →":"Oggetti pronti",
		"CARICA LA SACCA NEL CASSONE":"Carica sacca", "SCARICA MATERIALI E COMPONENTI NEL DEPOSITO":"Scarica deposito",
		"DEPOSITA LA SACCA NEL MAGAZZINO":"Deposita sacca", "SCARICA IL CASSONE QUI":"Scarica cassone",
		"RIPONI NELL'ATTREZZATURA":"Riponi", "CARICA MATERIALI DALLA SACCA":"Carica sacca", "SCARICA NEL DEPOSITO":"Scarica deposito",
		"TRAINA A PIEDI · E PER LASCIARE":"Traina", "ANNULLA · RESTITUISCI MATERIALI E COMPONENTI":"Annulla e rimborsa",
		"ANNULLA I LOTTI IN ATTESA · RESTITUISCI I MATERIALI":"Annulla coda", "ALIMENTAZIONE AUTOMATICA DAL DEPOSITO":"Attiva tramoggia", "SPEGNI TRAMOGGIA":"Spegni tramoggia",
		"INDICA UN RECUPERO SUL NAVIGATORE":"Trova componenti", "INDICA IL BANCO COSTRUZIONE":"Trova officina", "RINUNCIA ALL’INCARICO · MATERIALI CONSERVATI":"Rinuncia",
		"SEGUI IL PROSSIMO PASSO":"Segui obiettivo", "ALBUM DELLE CURIOSITÀ":"Curiosità", "MOSTRA IL MONDO":"Mondo", "MOSTRA IL CENTRO":"Centro",
		"DIARIO [J] · OBIETTIVI / PROGETTI / MAPPA":"Diario [J]", "MONOPATTINO · EQUIPAGGIA / TOGLI":"Monopattino [4]",
		"MONOPATTINO · ACQUISTALO AL CHIOSCO MEZZI":"Monopattino · bloccato",
	}
	if labels.has(original):
		button.tooltip_text = original
		button.text = labels[original]
	for prefix in ["OTTIENI RICONOSCIMENTO","POSIZIONA ","RIPARA ","ASSEMBLAGGIO ·"]:
		if original.to_upper().begins_with(prefix):
			button.tooltip_text=original
			button.text="Riscatta" if prefix=="OTTIENI RICONOSCIMENTO" else original.get_slice(" · ",0).capitalize()
	var lower: String = original.to_lower()
	var symbol: String = ""
	for pair in [["chiudi","close"],["torna al lavoro","close"],["deposita","bag"],["carica","box"],["vendi","coin"],["consegna","coin"],["costruisci","craft"],["assembl","craft"],["indica","route"],["trova","route"],["segui","route"],["diario","book"],["monopattino","scooter"],["tramoggia","press"],["impostazioni","settings"],["equipaggia","check"],["nuova spedizione","land"]]:
		if lower.contains(pair[0]):
			symbol=pair[1]
			break
	if not symbol.is_empty():
		button.icon=icon(symbol)
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",22)
		button.add_theme_constant_override("h_separation",10)

static func visual_action(button: Button) -> void:
	if button.get_meta("keep_label",false): return
	var caption: String=button.text
	if caption.is_empty() and button.has_meta("action_label"): caption=str(button.get_meta("action_label"))
	var actions={"Chiudi":"close","Deposita":"bag","Deposita sacca":"bag","Vendi avanzi":"sell","Vendi tutto…":"coin","Materiali":"metal","Componenti":"engine","Nuova spedizione":"land","Trova risorse":"route","Costruisci":"craft","Assembla":"craft","Installa":"install","Carica sacca":"box","Scarica deposito":"install","Riponi":"bag","Traina":"handcart","Annulla coda":"close","Attiva tramoggia":"play","Spegni tramoggia":"close","Insegna e colori":"paint","COSTRUZIONI":"craft"}
	var badge: String=""
	for entry in [["SCANNER","scan","F"],["LAMPADA","light","L"],["FARI","light","L"],["LIBRO","book",caption.get_slice(" · ",1)],["VISUALE","eye","V"],["FRENO [P]","wheel","P"]]:
		if caption.begins_with(entry[0]):
			actions[caption]=entry[1]
			badge=entry[2]
	if not actions.has(caption): return
	button.set_meta("action_label",caption)
	if button.tooltip_text.is_empty(): button.tooltip_text=caption
	button.text=badge
	if badge.is_empty(): button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.icon=icon(actions[caption])
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",32)
	button.custom_minimum_size=Vector2(64,52)

static func item_key(caption: String) -> String:
	var lower: String=caption.to_lower()
	for pair in [["metall","metal"],["allumin","metal"],["plasti","plastic"],["elettron","electronics"],["gomma","rubber"],["vetro","glass"],["rame","copper"],["ruota","wheel"],["pannell","panel"],["batter","battery"],["motore","engine"],["sospens","suspension"],["sponde","truck"],["idraulic","press"],["telaio da trasporto","bag"],["carrello","handcart"],["faro","light"],["lampad","light"],["radio","radio"],["compressore","engine"],["panca","bench"],["cassetta","repair"],["kit","repair"],["porco","crowbar"],["cesoie","cutters"],["sacca","bag"],["saldo","coin"],["deposito","box"],["scorte","box"],["carico","truck"],["pronti","box"],["coda","clock"],["lavori","clock"],["scopert","book"],["famiglia","book"]]:
		if lower.contains(pair[0]): return pair[1]
	return "box"
