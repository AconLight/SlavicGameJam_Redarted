# Kabina tira: aktywności i kamera — plan wdrożenia

> **Dla agentów:** WYMAGANY SUB-SKILL: użyj `superpowers:subagent-driven-development` (zalecane) albo `superpowers:executing-plans`, żeby wykonać ten plan zadanie po zadaniu. Kroki mają składnię checkboxów (`- [ ]`).

**Cel:** Wnętrze kabiny tira w POV kierowcy, z jedną aktywnością (radio) uruchamianą przytrzymaniem myszy i kamerą, która subtelnie dryfuje w jej stronę i wraca do spoczynku.

**Architektura:** Dwa rodzaje klocków stawianych myszką w edytorze — nieruchoma pinezka `CabinZoomTarget` mówiąca „kamero, przyjedź tu i przybliż o tyle", oraz `CabinActivity` z obszarem klikalnym, wskazująca swoją pinezkę. Cała logika stanu siedzi w jednym `CabinActivityController`, a kamera tylko dryfuje ku celowi, który on wskazuje. Aktywności rejestrują się same przez grupę `cabin_activity`, więc dołożenie kolejnej nie wymaga dotykania kodu.

**Stack:** Godot 4.7.1, GDScript. Bez dodatkowych bibliotek i bez nowych addonów.

**Spec:** [`docs/cabin/2026-08-07-cabin-activities-design.md`](2026-08-07-cabin-activities-design.md)

> **Stan: wykonane.** Plan zostawiony jako zapis przebiegu. Trzy rzeczy poszły inaczej niż tu napisano, wszystkie opisane w specu:
>
> - Powiązania między węzłami musiały zmienić typ na `NodePath` — pola zadeklarowane jako typ węzła nie przenoszą się przez plik sceny pisany tekstem.
> - Doszła blokada klikania na czas powrotu kamery, a czasy najazdu i powrotu wylądowały na aktywności zamiast na pinezce.
> - Najazd jest jednostajny, nie wygładzany wykładniczo. Wyhamowanie zostało tylko na powrocie.
>
> Aktualny opis komponentów jest w specu, nie tutaj.

## Global Constraints

- Godot 4.7.1, wszystko wewnątrz `~/Documents/GAMEJAM/` — bez instalacji globalnych.
- Branch `cabin`. Commity zwykłe konwencjonalne, jednolinijkowy temat, bez `Co-Authored-By`, bez prefiksów ticketowych.
- Rozdzielczość projektu to domyślne **1152 × 648** — wszystkie współrzędne w tym planie są w tym układzie, środek ekranu to `(576, 324)`.
- **Brak frameworka testowego i nie stawiamy go.** Spec świadomie z niego rezygnuje na czas jamu, więc zamiast cyklu TDD każde zadanie kończy się konkretną weryfikacją przez `run_project` + `get_debug_output` z MCP Godota. Konsola nie może zawierać błędów ani ostrzeżeń z naszych plików. Konsekwencja jest realna: regresje w logice kontrolera wyjdą dopiero przy ręcznym klikaniu — jeśli aktywności urosną ponad kilka, warto wrócić do tematu i dołożyć GUT.
- Weryfikację wzrokową płynności kamery robi Piotr. Nie robimy zrzutów ekranu.
- Grafika jest **zastępcza** — kolorowe wielokąty. Docelowe obrazki wejdą później podmianą, bez zmian w kodzie.
- Skrypty w `scripts/cabin/`, sceny klocków w `scenes/cabin/`, scena główna kabiny w `scenes/cabin.tscn`.
- Nie tworzymy `.uid` ręcznie — Godot dopisze je sam przy pierwszym imporcie. Nowe `.tscn` piszemy bez `uid=` w nagłówku.

---

### Task 1: Szkielet kabiny z zastępczą grafiką

Statyczna scena kabiny: rama okna z przezroczystą dziurą na szybę, deska rozdzielcza, miejsce na prędkościomierz Adasia i nieruchoma kamera na środku. Nic jeszcze nie klika — chodzi o to, żeby było co oglądać i żeby scena wstawała bez błędów.

**Files:**
- Create: `scenes/cabin.tscn`

**Interfaces:**
- Consumes: nic
- Produces: scena `res://scenes/cabin.tscn` z węzłami `Cabin/Interior/CabinShell`, `Cabin/Interior/SpeedometerSlot` (Marker2D), `Cabin/CabinCamera` (Camera2D). Kolejne zadania dokładają rodzeństwo pod `Cabin`.

- [ ] **Krok 1: Utwórz scenę kabiny**

Plik `scenes/cabin.tscn`. Szyba to brak węzła — cztery belki obrysowują prostokątną dziurę od `(140, 60)` do `(1012, 380)`, przez którą widać tło projektu. Docelowa grafika zastąpi `CabinShell` jednym `Sprite2D` z przezroczystością w tym miejscu.

```
[gd_scene format=3]

[node name="Cabin" type="Node2D"]

[node name="Interior" type="Node2D" parent="."]

[node name="CabinShell" type="Node2D" parent="Interior"]

[node name="FrameTop" type="Polygon2D" parent="Interior/CabinShell"]
color = Color(0.13, 0.12, 0.11, 1)
polygon = PackedVector2Array(0, 0, 1152, 0, 1152, 60, 0, 60)

[node name="FrameLeft" type="Polygon2D" parent="Interior/CabinShell"]
color = Color(0.13, 0.12, 0.11, 1)
polygon = PackedVector2Array(0, 60, 140, 60, 140, 380, 0, 380)

[node name="FrameRight" type="Polygon2D" parent="Interior/CabinShell"]
color = Color(0.13, 0.12, 0.11, 1)
polygon = PackedVector2Array(1012, 60, 1152, 60, 1152, 380, 1012, 380)

[node name="Dashboard" type="Polygon2D" parent="Interior/CabinShell"]
color = Color(0.17, 0.15, 0.14, 1)
polygon = PackedVector2Array(0, 380, 1152, 380, 1152, 648, 0, 648)

[node name="SpeedometerSlot" type="Marker2D" parent="Interior"]
position = Vector2(380, 480)

[node name="CabinCamera" type="Camera2D" parent="."]
position = Vector2(576, 324)
```

- [ ] **Krok 2: Uruchom scenę i sprawdź konsolę**

MCP: `run_project` z `projectPath` = katalog repo, `scene` = `res://scenes/cabin.tscn`. Następnie `get_debug_output`.

Oczekiwane: `errors` puste, w `output` tylko baner Godota i informacja o sterowniku. Widać ciemną ramę kabiny z jasnym prostokątem dziury pośrodku-górze.

- [ ] **Krok 3: Zatrzymaj i zacommituj**

MCP: `stop_project`.

```bash
git -C ~/Documents/GAMEJAM/SlavicGameJam_Redarted add scenes/cabin.tscn && git -C ~/Documents/GAMEJAM/SlavicGameJam_Redarted commit -m "feat: add truck cabin scene skeleton with placeholder interior"
```

---

### Task 2: Klocki i kontroler — trzymanie działa

Oba klocki plus dyrygent. Po tym zadaniu przytrzymanie radia wypisuje w konsoli start i koniec z czasem trzymania. Kamera jeszcze się nie rusza.

**Files:**
- Create: `scripts/cabin/cabin_zoom_target.gd`
- Create: `scripts/cabin/cabin_activity.gd`
- Create: `scripts/cabin/cabin_activity_controller.gd`
- Create: `scenes/cabin/cabin_zoom_target.tscn`
- Create: `scenes/cabin/cabin_activity.tscn`
- Modify: `scenes/cabin.tscn` — dołóż `ZoomTargets`, `Activities`, `ActivityController`

**Interfaces:**
- Consumes: `res://scenes/cabin.tscn` z Task 1
- Produces:
  - `class_name CabinZoomTarget extends Marker2D` z polami `zoom: float`, `approach_speed: float`
  - `class_name CabinActivity extends Area2D` ze stałą `GROUP := &"cabin_activity"`, polami `activity_id: StringName`, `zoom_target: CabinZoomTarget`, sygnałem `press_requested(activity: CabinActivity)`
  - `class_name CabinActivityController extends Node` z sygnałami `activity_started(activity_id: StringName)` i `activity_ended(activity_id: StringName, held_seconds: float)`, polami `neutral_target: CabinZoomTarget`, `debug_log: bool`, oraz metodami `current_target() -> CabinZoomTarget`, `active_id() -> StringName`, `held_seconds() -> float`

- [ ] **Krok 1: Napisz klocek punktu zoomu**

`scripts/cabin/cabin_zoom_target.gd` — czysta pinezka, zero logiki.

```gdscript
class_name CabinZoomTarget
extends Marker2D

## Nieruchomy cel dla kamery: dokąd przyjechać i jak mocno przybliżyć.

## Siła przybliżenia. 1.0 to widok normalny, więcej to bliżej.
@export_range(0.5, 4.0, 0.05) var zoom := 1.35

## Jak szybko kamera tu dojeżdża. Mniej znaczy leniwiej.
@export_range(0.2, 12.0, 0.1) var approach_speed := 2.5
```

- [ ] **Krok 2: Napisz klocek aktywności**

`scripts/cabin/cabin_activity.gd`. Sama nie decyduje, czy aktywność ruszy — tylko zgłasza wciśnięcie. Do grupy dopisuje się sama, dzięki czemu dodanie kolejnej aktywności nie wymaga żadnego podłączania.

```gdscript
class_name CabinActivity
extends Area2D

## Przedmiot w kabinie, który da się przytrzymać.

signal press_requested(activity: CabinActivity)

const GROUP := &"cabin_activity"

## Identyfikator trafiający do sygnałów, np. &"radio".
@export var activity_id: StringName = &""

## Pinezka, na którą najedzie kamera. Puste = kamera zostaje w spoczynku.
@export var zoom_target: CabinZoomTarget


func _ready() -> void:
	add_to_group(GROUP)
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	press_requested.emit(self)
```

- [ ] **Krok 3: Napisz kontroler**

`scripts/cabin/cabin_activity_controller.gd`. Dwie rzeczy warte uwagi. Po pierwsze podłączanie idzie przez `call_deferred`, żeby nie zależeć od kolejności węzłów w drzewie — inaczej przestawienie `ActivityController` nad `Activities` cicho urwałoby wszystkie kliknięcia. Po drugie puszczenie przycisku wykrywamy odpytywaniem, nie zdarzeniem na obszarze, więc zjechanie myszką z radia w trakcie trzymania nie przerywa aktywności.

```gdscript
class_name CabinActivityController
extends Node

## Jedyne miejsce z logiką stanu aktywności. Pilnuje, że naraz trwa
## najwyżej jedna, mierzy czas trzymania i ogłasza to na zewnątrz.

signal activity_started(activity_id: StringName)
signal activity_ended(activity_id: StringName, held_seconds: float)

## Pinezka, do której kamera wraca, gdy nic się nie dzieje.
@export var neutral_target: CabinZoomTarget

## Czy wypisywać start i koniec aktywności do konsoli.
@export var debug_log := true

var _active: CabinActivity = null
var _held := 0.0


func _ready() -> void:
	_connect_activities.call_deferred()


func _process(delta: float) -> void:
	if _active == null:
		return
	_held += delta
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end()


## Cel dla kamery. Nigdy nie zwraca null, o ile ustawiono neutral_target.
func current_target() -> CabinZoomTarget:
	if _active != null and _active.zoom_target != null:
		return _active.zoom_target
	return neutral_target


## Identyfikator trwającej aktywności albo pusty StringName.
func active_id() -> StringName:
	return _active.activity_id if _active != null else &""


func held_seconds() -> float:
	return _held


func _connect_activities() -> void:
	for node in get_tree().get_nodes_in_group(CabinActivity.GROUP):
		var activity := node as CabinActivity
		if not activity.press_requested.is_connected(_on_press_requested):
			activity.press_requested.connect(_on_press_requested)


func _on_press_requested(activity: CabinActivity) -> void:
	if _active != null:
		return
	_active = activity
	_held = 0.0
	activity_started.emit(activity.activity_id)
	if debug_log:
		print("[cabin] start: ", activity.activity_id)


func _end() -> void:
	var id := _active.activity_id
	var held := _held
	_active = null
	_held = 0.0
	activity_ended.emit(id, held)
	if debug_log:
		print("[cabin] end: ", id, " held=%.2fs" % held)
```

- [ ] **Krok 4: Utwórz scenę klocka punktu zoomu**

`scenes/cabin/cabin_zoom_target.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/cabin/cabin_zoom_target.gd" id="1_script"]

[node name="CabinZoomTarget" type="Marker2D"]
script = ExtResource("1_script")
```

- [ ] **Krok 5: Utwórz scenę klocka aktywności**

`scenes/cabin/cabin_activity.tscn`. Prostokąt 120 × 70 wyśrodkowany na pozycji węzła, z obszarem klikalnym o tym samym rozmiarze.

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/cabin/cabin_activity.gd" id="1_script"]

[sub_resource type="RectangleShape2D" id="ClickShape"]
size = Vector2(120, 70)

[node name="CabinActivity" type="Area2D"]
script = ExtResource("1_script")
input_pickable = true

[node name="Visual" type="Polygon2D" parent="."]
color = Color(0.35, 0.33, 0.3, 1)
polygon = PackedVector2Array(-60, -35, 60, -35, 60, 35, -60, 35)

[node name="ClickArea" type="CollisionShape2D" parent="."]
shape = SubResource("ClickShape")
```

- [ ] **Krok 6: Wstaw klocki do kabiny**

Przepisz `scenes/cabin.tscn` w całości — dochodzą trzy nowe gałęzie pod `Cabin`. Radio siedzi na desce rozdzielczej po prawej, jego pinezka w tym samym miejscu z przybliżeniem 1.5.

```
[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/cabin/cabin_zoom_target.tscn" id="1_zoom_target"]
[ext_resource type="PackedScene" path="res://scenes/cabin/cabin_activity.tscn" id="2_activity"]
[ext_resource type="Script" path="res://scripts/cabin/cabin_activity_controller.gd" id="3_controller"]

[node name="Cabin" type="Node2D"]

[node name="Interior" type="Node2D" parent="."]

[node name="CabinShell" type="Node2D" parent="Interior"]

[node name="FrameTop" type="Polygon2D" parent="Interior/CabinShell"]
color = Color(0.13, 0.12, 0.11, 1)
polygon = PackedVector2Array(0, 0, 1152, 0, 1152, 60, 0, 60)

[node name="FrameLeft" type="Polygon2D" parent="Interior/CabinShell"]
color = Color(0.13, 0.12, 0.11, 1)
polygon = PackedVector2Array(0, 60, 140, 60, 140, 380, 0, 380)

[node name="FrameRight" type="Polygon2D" parent="Interior/CabinShell"]
color = Color(0.13, 0.12, 0.11, 1)
polygon = PackedVector2Array(1012, 60, 1152, 60, 1152, 380, 1012, 380)

[node name="Dashboard" type="Polygon2D" parent="Interior/CabinShell"]
color = Color(0.17, 0.15, 0.14, 1)
polygon = PackedVector2Array(0, 380, 1152, 380, 1152, 648, 0, 648)

[node name="SpeedometerSlot" type="Marker2D" parent="Interior"]
position = Vector2(380, 480)

[node name="ZoomTargets" type="Node2D" parent="."]

[node name="NeutralFocus" parent="ZoomTargets" instance=ExtResource("1_zoom_target")]
position = Vector2(576, 324)
zoom = 1.0
approach_speed = 2.5

[node name="RadioFocus" parent="ZoomTargets" instance=ExtResource("1_zoom_target")]
position = Vector2(790, 470)
zoom = 1.5
approach_speed = 2.0

[node name="Activities" type="Node2D" parent="."]

[node name="Radio" parent="Activities" instance=ExtResource("2_activity")]
position = Vector2(790, 470)
activity_id = &"radio"
zoom_target = NodePath("../../ZoomTargets/RadioFocus")

[node name="ActivityController" type="Node" parent="."]
script = ExtResource("3_controller")
neutral_target = NodePath("../ZoomTargets/NeutralFocus")
debug_log = true

[node name="CabinCamera" type="Camera2D" parent="."]
position = Vector2(576, 324)
```

- [ ] **Krok 7: Sprawdź trzymanie w konsoli**

MCP: `run_project` na `res://scenes/cabin.tscn`, potem klikanie i `get_debug_output`.

Sprawdź po kolei:
1. Przytrzymaj radio przez mniej więcej dwie sekundy i puść. Konsola: `[cabin] start: radio`, potem `[cabin] end: radio held=2.0xs`. Czas ma się zgadzać z tym, jak długo trzymałeś.
2. Kliknij poza radiem — nic się nie wypisuje.
3. Przytrzymaj radio, **zjedź myszką poza prostokąt nie puszczając przycisku**, dopiero potem puść. Aktywność ma się skończyć dopiero przy puszczeniu — jeden `end`, nie zero.
4. `errors` puste.

- [ ] **Krok 8: Zatrzymaj i zacommituj**

MCP: `stop_project`.

```bash
git -C ~/Documents/GAMEJAM/SlavicGameJam_Redarted add scripts/cabin scenes/cabin scenes/cabin.tscn && git -C ~/Documents/GAMEJAM/SlavicGameJam_Redarted commit -m "feat: add cabin zoom target and activity blocks with hold controller"
```

---

### Task 3: Kamera dryfująca do aktywności

Kamera zaczyna reagować: przy trzymaniu radia płynnie jedzie i przybliża się w jego stronę, po puszczeniu tą samą drogą wraca do spoczynku.

**Files:**
- Create: `scripts/cabin/cabin_camera.gd`
- Modify: `scenes/cabin.tscn` — podepnij skrypt i kontroler pod `CabinCamera`

**Interfaces:**
- Consumes: `CabinActivityController.current_target() -> CabinZoomTarget`, pola `CabinZoomTarget.zoom` i `CabinZoomTarget.approach_speed` z Task 2
- Produces: `CabinCamera` z polem `controller: CabinActivityController`

- [ ] **Krok 1: Napisz kamerę**

`scripts/cabin/cabin_camera.gd`. Wygładzanie wykładnicze zamiast stałego kroku: `1.0 - exp(-speed * delta)` daje ruch, który startuje żwawo i miękko hamuje przy celu, identycznie przy 30 i przy 144 klatkach na sekundę. Zwykłe `lerp` ze stałą wagą przyspieszałoby kamerę na mocniejszym sprzęcie.

```gdscript
extends Camera2D

## Dryfuje ku pinezce wskazanej przez kontroler. Powrót do spoczynku
## używa tej samej ścieżki co dojazd — nie ma osobnego przypadku.

@export var controller: CabinActivityController


func _process(delta: float) -> void:
	if controller == null:
		return
	var target := controller.current_target()
	if target == null:
		return
	var weight := 1.0 - exp(-target.approach_speed * delta)
	global_position = global_position.lerp(target.global_position, weight)
	zoom = zoom.lerp(Vector2.ONE * target.zoom, weight)
```

- [ ] **Krok 2: Podepnij kamerę w scenie**

W `scenes/cabin.tscn` dopisz na końcu listy `ext_resource`:

```
[ext_resource type="Script" path="res://scripts/cabin/cabin_camera.gd" id="4_camera"]
```

i zastąp węzeł `CabinCamera` tym:

```
[node name="CabinCamera" type="Camera2D" parent="."]
position = Vector2(576, 324)
script = ExtResource("4_camera")
controller = NodePath("../ActivityController")
```

- [ ] **Krok 3: Sprawdź zachowanie kamery**

MCP: `run_project`, klikanie, `get_debug_output`.

Sprawdź:
1. Przytrzymaj radio — widok płynnie jedzie w prawo-dół i się przybliża. Bez szarpnięcia na starcie, bez przeskoku na końcu.
2. Puść — widok wraca na środek i oddala się do normalnego.
3. Klikaj radio szybko wiele razy pod rząd — kamera nie zapętla się ani nie zostaje w połowie drogi.
4. **Przytrzymaj radio i nie puszczając kliknij ponownie w przybliżeniu** — trafianie w przedmiot musi działać także przy przesuniętej i przybliżonej kamerze. To jest ryzyko wypisane w specu; jeśli tu coś nie gra, obszary klikalne są liczone w złej przestrzeni i trzeba to naprawić zanim ruszymy dalej.
5. `errors` puste.

- [ ] **Krok 4: Zatrzymaj i zacommituj**

MCP: `stop_project`.

```bash
git -C ~/Documents/GAMEJAM/SlavicGameJam_Redarted add scripts/cabin/cabin_camera.gd scenes/cabin.tscn && git -C ~/Documents/GAMEJAM/SlavicGameJam_Redarted commit -m "feat: drift cabin camera toward active zoom target"
```

---

### Task 4: Napis diagnostyczny

Etykieta w rogu z nazwą trwającej aktywności i czasem trzymania. Narzędzie na czas budowy — `CanvasLayer`, więc nie jeździ z kamerą, i gasi się jednym przełącznikiem `visible`.

**Files:**
- Create: `scripts/cabin/cabin_debug_overlay.gd`
- Modify: `scenes/cabin.tscn` — dołóż `DebugOverlay`

**Interfaces:**
- Consumes: `CabinActivityController.active_id() -> StringName` i `held_seconds() -> float` z Task 2
- Produces: nic — to liść, nikt się pod niego nie podłącza

- [ ] **Krok 1: Napisz nakładkę**

`scripts/cabin/cabin_debug_overlay.gd`:

```gdscript
extends CanvasLayer

## Podgląd stanu aktywności na czas budowy. Do skasowania,
## gdy przestanie być potrzebny.

@export var controller: CabinActivityController

@onready var _label: Label = $StatusLabel


func _process(_delta: float) -> void:
	if controller == null:
		return
	var id := controller.active_id()
	if id == &"":
		_label.text = "—"
	else:
		_label.text = "%s — %.1f s" % [id, controller.held_seconds()]
```

- [ ] **Krok 2: Dołóż nakładkę do sceny**

W `scenes/cabin.tscn` dopisz `ext_resource`:

```
[ext_resource type="Script" path="res://scripts/cabin/cabin_debug_overlay.gd" id="5_debug"]
```

i dopisz na końcu pliku:

```
[node name="DebugOverlay" type="CanvasLayer" parent="."]
script = ExtResource("5_debug")
controller = NodePath("../ActivityController")

[node name="StatusLabel" type="Label" parent="DebugOverlay"]
offset_left = 24.0
offset_top = 20.0
offset_right = 520.0
offset_bottom = 56.0
theme_override_colors/font_color = Color(0.75, 0.95, 0.7, 1)
theme_override_font_sizes/font_size = 20
text = "—"
```

- [ ] **Krok 3: Sprawdź napis**

MCP: `run_project`, klikanie, `get_debug_output`.

Sprawdź:
1. Bez trzymania napis pokazuje `—`.
2. Przy trzymaniu radia napis pokazuje `radio — 1.4 s` i liczba rośnie.
3. Napis **stoi w rogu i nie jeździ z kamerą** przy najeżdżaniu.
4. `errors` puste.

- [ ] **Krok 4: Zatrzymaj i zacommituj**

MCP: `stop_project`.

```bash
git -C ~/Documents/GAMEJAM/SlavicGameJam_Redarted add scripts/cabin/cabin_debug_overlay.gd scenes/cabin.tscn && git -C ~/Documents/GAMEJAM/SlavicGameJam_Redarted commit -m "feat: add cabin debug overlay with activity readout"
```

---

## Po planie

Dodanie kolejnej aktywności nie wymaga już wracania do tego planu ani do kodu — instrukcja jest w specu, w sekcji „Jak dodać nową aktywność". Otwarte tematy do uzgodnienia z zespołem: globalny mechanizm chillu i punktów, klawiatura numeryczna CB, oraz która kamera rządzi po sklejeniu kabiny z drogą Melina.
