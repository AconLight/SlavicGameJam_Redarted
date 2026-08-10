extends Node2D

## Cyferki chillu unoszące się nad czynnościami.
##
## Dwa różne zachowania, bo dwa różne rodzaje czynności:
##
## Czynności trzymane (ukulele, CB, kręcenie radiem) dostają **jedną** liczbę,
## która co sekundę podbija się i pulsuje, a rośnie razem z tym, co uzbierała.
## Nowa cyferka co sekundę nie pokazywałaby przypływu, tylko sypała tym samym
## „+5" w kółko.
##
## Czynności pracujące same (grające radio, żarzący się papieros, zaciągnięcie)
## dostają osobne cyferki, które podlatują i gasną — tak jak dym.
##
## Rysowane wprost w _draw() domyślną czcionką silnika, bez węzłów Label:
## cyferek jest naraz kilka, żyją sekundę i nie muszą nic łapać.
##
## Pokazujemy chill, nie punkty. Score liczy się na końcu przejazdu, po swojemu.

## Kontroler czynności — z niego bierzemy start i koniec trzymania.
@export_node_path("Node") var controller_path: NodePath

## Kamera, o której zoom dzielimy rozmiar cyferek. Puste = cyferki rosną razem
## z najazdem kamery, co przy zbliżeniu trzykrotnym daje napisy na pół ekranu.
@export_node_path("Camera2D") var camera_path: NodePath

## Gdzie stają cyferki danej czynności: identyfikator na ścieżkę węzła.
## Bez wpisu bierzemy sam węzeł czynności.
##
## Ukulele wymaga wpisu, bo w trakcie grania zjeżdża pod ekran — cyferki
## pojechałyby razem z nim.
@export var anchors: Dictionary = {}

@export_group("Trzymanie")

## Ile chillu na sekundę pokazać, gdy czynność nie mówi tego sama. Zwykle
## nieużywane: stawkę bierzemy z pola hold_chill_per_second trzymanej
## czynności, tego samego, które kontroler wstawia do licznika.
@export_range(0, 50, 1) var hold_chill_per_second := 5

## Co ile sekund podbija się liczba przy trzymaniu.
@export_range(0.1, 5.0, 0.1) var hold_tick_seconds := 1.0

@export_group("Wygląd")

## Czcionka cyferek. Puste = wbudowana czcionka silnika, czyli inna niż reszta
## napisów w grze.
@export var font: Font

@export_range(8, 200, 1) var font_size := 44

## Słowo dopisywane za liczbą, żeby było widać, czego dotyczy przypływ.
@export var unit_label := "chill"

## Ile razy mniejsze są cyferki podlatujące same — z grającego radia i z
## papierosa. Liczba trzymania i pożegnalna suma zostają w pełnym rozmiarze,
## bo to one są nagrodą, a te drobne tylko informują, że coś kapie.
@export_range(0.2, 2.0, 0.05) var pop_scale := 0.6

@export var color := Color(0.53, 0.94, 0.62, 1.0)

@export var outline_color := Color(0.05, 0.11, 0.07, 1.0)

@export_range(0, 40, 1) var outline_size := 10

## O ile pikseli cyferka unosi się przez swoje życie.
@export_range(0.0, 400.0, 5.0) var rise_pixels := 90.0

## Jak długo żyje cyferka, która podleciała i gaśnie.
@export_range(0.2, 5.0, 0.05) var life_seconds := 1.1

## Jak mocno cyferka skacze przy podbiciu. 0.4 = na chwilę o 40% większa.
@export_range(0.0, 2.0, 0.05) var pulse_strength := 0.45

## Jak długo trwa skok.
@export_range(0.05, 1.0, 0.01) var pulse_seconds := 0.18

## Ile rośnie liczba trzymania z każdym uzbieranym punktem chillu.
@export_range(0.0, 0.2, 0.005) var growth_per_point := 0.02

## Najwyżej ile razy większa może zrobić się liczba trzymania.
@export_range(1.0, 6.0, 0.1) var max_growth := 2.4

## Ile razy większa robi się cyferka rosnąca przez cały czas trwania czegoś —
## na przykład zaciągnięcia, które trwa tyle, ile jego dźwięk.
@export_range(1.0, 6.0, 0.1) var sustain_growth := 2.2

var _controller: CabinActivityController
var _camera: Camera2D
var _font: Font
var _pops: Array[Dictionary] = []

## Bieżąca liczba trzymania albo pusty słownik.
var _hold: Dictionary = {}
var _to_next_tick := 0.0


func _ready() -> void:
	_font = font if font != null else ThemeDB.fallback_font
	_camera = get_node_or_null(camera_path) as Camera2D
	_controller = get_node_or_null(controller_path) as CabinActivityController
	if _controller == null:
		push_warning("[cyferki] brak kontrolera — liczby przy trzymaniu nie zadziałają")
		return
	_controller.activity_started.connect(_on_activity_started)
	_controller.activity_ended.connect(_on_activity_ended)


func _process(delta: float) -> void:
	var index := _pops.size() - 1
	while index >= 0:
		_pops[index]["age"] += delta
		if _pops[index]["age"] >= _pops[index]["life"]:
			_pops.remove_at(index)
		index -= 1

	if not _hold.is_empty():
		_hold["pulse"] = maxf(_hold["pulse"] - delta / pulse_seconds, 0.0)
		_to_next_tick -= delta
		if _to_next_tick <= 0.0:
			_to_next_tick += hold_tick_seconds
			_hold["value"] += int(_hold["gain"])
			_hold["pulse"] = 1.0

	queue_redraw()


## Cyferka, która podlatuje i gaśnie. Woła to wszystko, co dolewa chillu samo:
## grające radio i żarzący się papieros.
##
## `seconds` większe od zera zadaje własny czas życia, a `grow` zamienia lot
## w rośnięcie na miejscu — do rzeczy, które trwają i mają być widoczne przez
## cały swój czas, jak zaciągnięcie papierosem.
func pop(amount: int, anchor: Node2D, seconds := 0.0, grow := false) -> void:
	if amount == 0 or anchor == null:
		return
	_pops.append({
		"value": amount,
		"anchor": anchor,
		"age": 0.0,
		"life": seconds if seconds > 0.0 else life_seconds,
		"grow": grow,
		# Rozsunięcie w bok, żeby dwie cyferki pod rząd nie nachodziły na siebie.
		# Rosnąca stoi dokładnie na środku swojej grafiki, więc bez rozsunięcia.
		"offset": 0.0 if grow else randf_range(-28.0, 28.0),
	})


func _on_activity_started(activity_id: StringName) -> void:
	var anchor := _anchor_for(activity_id)
	if anchor == null:
		return

	# Stawkę bierzemy z samej czynności, tę samą, którą kontroler wstawił do
	# licznika chillu. Gdyby cyferki miały własną liczbę, pokazywałyby coś
	# innego niż to, co naprawdę wpada.
	var gain := hold_chill_per_second
	var activity := _controller.active_activity()
	if activity != null:
		gain = activity.hold_chill_per_second

	# Czynności, które nic nie dają, nie dostają liczby. Zerknięcie na
	# prędkościomierz wypisywałoby „+0 chill" co sekundę.
	if gain <= 0:
		return

	_hold = {"value": 0, "anchor": anchor, "pulse": 0.0, "gain": gain}
	# Pierwsze tyknięcie od razu, żeby liczba pojawiła się razem z czynnością,
	# a nie po sekundzie patrzenia w nic.
	_to_next_tick = 0.0


func _on_activity_ended(_activity_id: StringName, _held_seconds: float) -> void:
	if _hold.is_empty():
		return
	# Uzbierana suma odlatuje jako zwykła cyferka — koniec czynności ma być
	# widoczny jako podsumowanie, nie jako zniknięcie liczby.
	var total: int = _hold["value"]
	var anchor: Node2D = _hold["anchor"]
	_hold = {}
	if total > 0:
		_pops.append({
			"value": total,
			"anchor": anchor,
			"age": 0.0,
			"life": life_seconds,
			"grow": false,
			"offset": 0.0,
			"farewell": true,
		})


## Węzeł, nad którym stają cyferki danej czynności.
func _anchor_for(activity_id: StringName) -> Node2D:
	if anchors.has(activity_id):
		var pinned := get_node_or_null(anchors[activity_id]) as Node2D
		if pinned != null:
			return pinned
	if _controller == null:
		return null
	return _controller.active_activity()


func _draw() -> void:
	if _font == null:
		return

	# Cyferki mają trzymać stały rozmiar na ekranie, a nie puchnąć razem
	# z najazdem kamery.
	var zoom := 1.0
	if _camera != null:
		zoom = maxf(_camera.zoom.y, 0.01)

	for pop_data in _pops:
		var anchor := pop_data["anchor"] as Node2D
		if anchor == null or not is_instance_valid(anchor):
			continue
		var t: float = clampf(pop_data["age"] / float(pop_data["life"]), 0.0, 1.0)
		var farewell: bool = pop_data.get("farewell", false)
		var growing: bool = pop_data.get("grow", false)

		var lift := 0.0
		var scale := 1.0
		var alpha := 1.0
		if growing:
			# Rośnie w miejscu przez cały czas trwania i gaśnie dopiero na
			# ostatniej ćwiartce, żeby przez większość czasu było ją dobrze widać.
			scale = lerpf(1.0, sustain_growth, t)
			alpha = 1.0 - clampf((t - 0.75) / 0.25, 0.0, 1.0)
		else:
			# Pożegnalna suma odlatuje wyżej i puchnie, zwykła tylko się unosi.
			lift = rise_pixels * (1.6 if farewell else 1.0) * ease(t, 0.4)
			scale = (1.0 + 0.6 * t) if farewell else (1.0 + pulse_strength * (1.0 - minf(t * 4.0, 1.0)))
			alpha = 1.0 - t * t

		if not farewell:
			scale *= pop_scale

		var origin := to_local(anchor.global_position) + Vector2(pop_data["offset"], -lift)
		_draw_number(pop_data["value"], origin, scale / zoom, alpha)

	if _hold.is_empty():
		return
	var hold_anchor := _hold["anchor"] as Node2D
	if hold_anchor == null or not is_instance_valid(hold_anchor):
		return
	var value: int = _hold["value"]
	var grown := minf(1.0 + float(value) * growth_per_point, max_growth)
	var pulse: float = _hold["pulse"]
	# Skok liczony sinusem, więc wchodzi i wraca gładko, bez kanciastego szarpnięcia.
	var scale := grown * (1.0 + pulse_strength * sin(pulse * PI))
	_draw_number(value, to_local(hold_anchor.global_position) + Vector2(0.0, -rise_pixels * 0.35), scale / zoom, 1.0)


func _draw_number(value: int, origin: Vector2, scale: float, alpha: float) -> void:
	var text := "+%d %s" % [value, unit_label]
	var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	# Skalujemy przez przekształcenie, nie przez rozmiar czcionki — inaczej
	# każdy skok kazałby silnikowi przerysować atlas czcionki od nowa.
	draw_set_transform(origin, 0.0, Vector2(scale, scale))
	var baseline := Vector2(-size.x * 0.5, 0.0)
	if outline_size > 0:
		draw_string_outline(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline_size, Color(outline_color, outline_color.a * alpha))
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color, color.a * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
