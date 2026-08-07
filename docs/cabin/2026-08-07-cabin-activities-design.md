# Kabina tira: aktywności i kamera

Data: 2026-08-07 · Branch: `cabin` · Autor: Cyngiel

## Kontekst

Gra: POV kierowcy tira, nieskończona droga, sztuczna perspektywa zbieżna. Im dłużej gracz robi rzeczy w kabinie zamiast patrzeć na drogę, tym więcej punktów — ale tir przyspiesza i grozi fotoradar.

Podział pracy w zespole:

| Kto | Co |
| --- | --- |
| Melin | sztuczna perspektywa, nieskończona droga, fotoradar |
| Adaś | zmiana prędkości i wskazówka prędkościomierza (mały klocek wstawiany do kabiny) |
| Cyngiel | wnętrze kabiny, aktywności, kamera — ten dokument |

## Zakres

W zakresie:

- scena wnętrza kabiny na zastępczej grafice
- dwa rodzaje klocków stawianych myszką w edytorze: punkt zoomu i aktywność
- **jedna aktywność na start: radio** (szukanie stacji z muzyką). CB i ukulele dojdą później tym samym klockiem
- kamera jadąca w stronę aktywności i wracająca do spoczynku
- kontroler trzymania, mierzący czas i ogłaszający sygnały
- blokada klikania, dopóki kamera nie wróci na miejsce; czasy najazdu i powrotu ustawiane osobno dla każdej aktywności
- tymczasowy napis diagnostyczny

Poza zakresem, świadomie:

- **chill i punktacja** — dotyczą trzech osób naraz, więc powstaną jako osobny, globalny mechanizm poza kabiną
- droga, perspektywa, prędkość, fotoradar
- docelowa grafika i dźwięk, w tym muzyka stacji radiowych
- mini-gry wewnątrz aktywności
- klawiatura numeryczna CB i odtwarzanie kwestii — odłożone, nierozstrzygnięte czy fizyczna czy rysowana

## Decyzje i ich powody

**Aktywność to „przytrzymaj i czekaj".** Bez mini-gier. Aktywności różnią się grafiką i miejscem, nie sposobem obsługi. Gdy któraś ma kiedyś dostać własną mechanikę, będzie to nowa warstwa, nie przebudowa tej.

**Punkt zoomu i aktywność to osobne klocki.** Rozdzielenie „gdzie patrzy kamera" od „w co klikam" daje trzy rzeczy: dwie aktywności mogą dzielić jeden punkt (radio i CB stoją obok siebie), aktywność może nie mieć punktu i wtedy kamera zostaje, a punkty da się dostrajać bez ruszania aktywności.

**Spoczynek to zwykły punkt zoomu.** Kamera po najeździe na radio fizycznie jest przy radiu i nie pamięta, skąd wyruszyła. Osobna pinezka „dom" sprawia, że powrót to ta sama operacja co dojazd — zero specjalnych przypadków w kodzie, a domyślne kadrowanie kabiny zmienia się przesunięciem krzyżyka.

**Klocki stawiamy myszką, nie opisujemy w plikach `.tres`.** Konfiguracja w zasobach byłaby spójna z `actor_pipeline`, ale wymagałaby wpisywania współrzędnych z palca. Rozstawianie przedmiotów w kabinie to praca na oko i musi być widoczna w edytorze. Spójność z `actor_pipeline` jest zresztą pozorna — tamten obsługuje aktorów generowanych z Aseprite'a, który na tej maszynie nie działa.

**Aktywności rejestrują się same.** Klocek dopisuje się do grupy `cabin_activity`, a kontroler zbiera grupę przy starcie. Dzięki temu dodanie aktywności nie wymaga podłączania niczego w kodzie ani w innym węźle.

**Brak pola `points_per_second` na aktywności.** Tempo punktów będzie potrzebne dopiero razem z chillem. Puste pole bez odbiorcy to pułapka — ktoś je wypełni i będzie się zastanawiał, czemu nic z tego nie wynika. Dodanie później to jedna linijka.

## Architektura

```
scenes/cabin.tscn
└── Cabin (Node2D)
    ├── Interior (Node2D)
    │   ├── CabinShell (Sprite2D)      jedna grafika całego wnętrza,
    │   │                              z przezroczystą dziurą na szybę
    │   └── SpeedometerSlot (Marker2D) miejsce na klocek Adasia
    ├── ZoomTargets (Node2D)
    │   ├── NeutralFocus  (CabinZoomTarget, zoom 1.0)
    │   └── RadioFocus    (CabinZoomTarget)
    ├── Activities (Node2D)
    │   └── Radio    (CabinActivity → RadioFocus)
    ├── CabinCamera (Camera2D)
    ├── ActivityController (Node)
    └── DebugOverlay (CanvasLayer)
        └── StatusLabel
```

Skrypty w `scripts/cabin/`, po jednym na komponent. Oba klocki mają własne pliki scen, gotowe do przeciągania:

```
scenes/cabin/cabin_zoom_target.tscn
scenes/cabin/cabin_activity.tscn
```

## Komponenty

### CabinZoomTarget — `cabin_zoom_target.gd`

Rozszerza `Marker2D`. Nieruchoma pinezka: „kamero, przyjedź tutaj i przybliż o tyle". Nie zawiera logiki.

| Pole w inspektorze | Domyślnie | Znaczenie |
| --- | --- | --- |
| `zoom` | `1.35` | siła przybliżenia; `1.0` to widok normalny |

Pinezka **nie zna tempa**. Czasy najazdu i powrotu należą do aktywności, bo dwie aktywności mogą wskazywać tę samą pinezkę i jechać do niej z różną szybkością.

Zależności: brak.

### CabinActivity — `cabin_activity.gd`

Rozszerza `Area2D`, w środku `Sprite2D` z obrazkiem przedmiotu i `CollisionShape2D` wyznaczający obszar klikalny. W `_ready` dopisuje się do grupy `cabin_activity`.

| Pole w inspektorze | Domyślnie | Znaczenie |
| --- | --- | --- |
| `activity_id` | — | identyfikator, np. `radio`; trafia do sygnałów |
| `zoom_target_path` | — | wskazany myszką krzyżyk; puste = kamera nie najeżdża i zostaje w spoczynku |
| `approach_seconds` | `3.0` | ile trwa najazd kamery na tę aktywność |
| `return_seconds` | `1.8` | ile trwa powrót i jak długo klikanie jest zablokowane |

Wystawia sygnał `press_requested(activity)`, gdy na obszarze wciśnięto lewy przycisk myszy. Sama nie decyduje, czy aktywność ruszy — to należy do kontrolera.

Zależności: opcjonalnie jeden `CabinZoomTarget`.

### CabinActivityController — `cabin_activity_controller.gd`

Rozszerza `Node`. Jedyne miejsce z logiką stanu. Nie ma pozycji ani grafiki.

Ma trzy stany: bezczynność, trwająca aktywność, powrót kamery. Odpowiada za pilnowanie, że naraz trwa najwyżej jedna aktywność; mierzenie czasu trzymania; wskazywanie kamerze aktualnego celu; ogłaszanie sygnałów.

| Pole w inspektorze | Znaczenie |
| --- | --- |
| `neutral_target_path` | pinezka spoczynku |
| `debug_log` | czy wypisywać zdarzenia do konsoli |

```gdscript
signal activity_started(activity_id: StringName)
signal activity_ended(activity_id: StringName, held_seconds: float)
signal return_started(return_seconds: float)
signal return_finished()

func current_target() -> CabinZoomTarget   # cel dla kamery, nigdy null
func active_id() -> StringName             # pusty StringName gdy nic nie trwa
func held_seconds() -> float
func active_approach_seconds() -> float
func is_returning() -> bool
func return_progress() -> float            # 0.0 … 1.0
func accepts_input() -> bool
```

Puszczenie przycisku wykrywa odpytywaniem w `_process`, nie zdarzeniem na obszarze. Dzięki temu zjechanie myszką z radia w trakcie trzymania **nie** przerywa aktywności — liczy się dopiero puszczenie lewego przycisku, gdziekolwiek na ekranie. To wybaczające zachowanie jest zamierzone.

**Dopóki kamera nie wróci na miejsce, nie da się kliknąć niczego.** Po puszczeniu aktywności kontroler wchodzi w stan powrotu na `return_seconds` tej aktywności i odrzuca wszystkie kliknięcia. Ten sam zegar napędza ruch kamery, więc blokada i obraz nie mogą się rozjechać. Nowa aktywność nie ruszy też, dopóki trwa poprzednia.

Zależności: grupa `cabin_activity`, jeden `CabinZoomTarget` jako spoczynek.

### CabinCamera — `cabin_camera.gd`

Rozszerza `Camera2D`. Jedzie do celu wskazanego przez kontroler, przejazdem na czas — nie ściganiem celu z klatki na klatkę.

**Najazd jest jednostajny**: kamera pokonuje drogę równo od pierwszej do ostatniej klatki, przez `approach_seconds` aktywności. Pierwsze podejście używało wygładzania wykładniczego, ale ono z definicji rusza szybko i pełznie na końcu — przy powolnym „ruchu głową" wyglądało to na zryw i zostało odrzucone.

**Powrót wyhamowuje na końcu** (`smoothstep`) i trwa `return_seconds`. Napędza go zegar kontrolera, ten sam, który trzyma blokadę klikania — dzięki temu obraz i blokada kończą się co do klatki razem.

Zależności: `CabinActivityController`, wskazany raz w scenie.

### Pułapka: powiązania między węzłami muszą być typu `NodePath`

Pole zadeklarowane wprost jako typ węzła:

```gdscript
@export var controller: CabinActivityController   # NIE DZIAŁA u nas
```

Sama linijka `controller = NodePath("../ActivityController")` nie wystarczy — pole wczytuje się jako `null`. Godot wymaga, żeby węzeł deklarował takie właściwości znacznikiem na swojej linii:

```
[node name="CabinCamera" type="Camera2D" parent="." node_paths=PackedStringArray("controller")]
```

Bez tego znacznika przypisanie jest po cichu ignorowane. Zwykłe pola (liczby, teksty) działają normalnie, dlatego objaw jest mylący: logika chodzi, a kamera stoi. Edytor dopisuje `node_paths` sam; pisząc scenę tekstem trzeba o nim pamiętać.

Zamiast tego:

```gdscript
@export_node_path("Node") var controller_path: NodePath
var controller: CabinActivityController

func _ready() -> void:
	controller = get_node_or_null(controller_path) as CabinActivityController
```

W inspektorze nadal jest przycisk do wskazania węzła myszką, więc sposób pracy się nie zmienia. Wszystkie powiązania w kabinie są zrobione tak — `NodePath` jest odporniejszy przy ręcznym pisaniu scen, bo nie wymaga pamiętania o `node_paths`.

### Drżenie kabiny — w `cabin_camera.gd`

Kabina nigdy nie stoi. Kamera dostaje pionowe wychylenie przez `offset`, nie przez `position`, więc podskakiwanie w ogóle nie miesza się z najazdem na aktywność — to dwa niezależne tory.

Kształt drgania to złożenie dwóch fal o niewspółmiernych częstotliwościach; pojedyncza sinusoida czyta się jak metronom. Amplitudą steruje wolniejszy iloczyn dwóch kolejnych fal podniesiony do kwadratu, przez co kabina przez większość czasu buja delikatnie, a mocno tylko chwilami, w nieregularnych odstępach.

| Pole na `CabinCamera` | Domyślnie | Znaczenie |
| --- | --- | --- |
| `bump_amplitude_min` | `2.0` | wychylenie na gładkiej drodze; `0` wyłącza całość |
| `bump_amplitude_max` | `14.0` | wychylenie w szczycie wyboja |
| `bump_frequency` | `2.2` | podskoków na sekundę |
| `swell_period` | `11.0` | co ile mniej więcej sekund robi się wyboiście |

Wychylenie jest dzielone przez `zoom`, więc przy przybliżeniu na aktywność kabina trzęsie się tak samo mocno na ekranie, a nie trzy razy bardziej.

**Grafika kabiny musi być większa niż ekran.** Przy wychyleniu kamera wyjeżdża poza obrazek i widać jego krawędź. `CabinShell` jest przeskalowany o `1.0222`, co daje 12 pikseli zapasu w pionie. Reguła przy zmianie amplitudy: potrzebny zapas to `1.45 × bump_amplitude_max`, a skala to `(1080 + 2 × zapas) / 1080`.

### CabinSteeringWheel — `cabin_steering_wheel.gd`

Kierownica rysowana kodem: pierścień, szprychy, piasta i kolorowy znacznik na godzinie dwunastej. Kołysze się delikatnie lewo-prawo tym samym złożeniem dwóch fal. Znacznik i szprychy są konieczne — sam okrąg przy obrocie wygląda na nieruchomy.

Skrypt jest `@tool`, więc kierownica rysuje się też w edytorze i da się ją ustawić myszką. Kołysanie jest wyłączone przy edycji.

Atrapa na czas jamu. Gdy będzie grafika, wstawia się `Sprite2D` w to samo miejsce — a skrypt kołysania działa na dowolnym `Node2D`, więc sam ruch da się przenieść bez zmian.

### DebugOverlay — `cabin_debug_overlay.gd`

`CanvasLayer` z etykietą, więc nie jeździ z kamerą. Pokazuje aktualną aktywność i czas trzymania, np. `radio — 3.2 s`, a w czasie powrotu informuje, że klikanie jest zablokowane. Narzędzie na czas budowy — wyłączane przełącznikiem `visible`, do skasowania gdy przestanie być potrzebne.

Zależności: `CabinActivityController`.

## Przepływ

1. Gracz wciska lewy przycisk nad radiem. `CabinActivity` ogłasza `press_requested`.
2. Kontroler sprawdza, czy nic nie trwa. Zapamiętuje aktywność, zeruje licznik, ogłasza `activity_started("radio")`.
3. W kolejnych klatkach licznik rośnie, a kamera jednostajnie jedzie ku `RadioFocus` przez `approach_seconds`.
4. Gracz puszcza przycisk. Kontroler ogłasza `activity_ended("radio", 3.2)`, potem `return_started(0.45)` i przestaje przyjmować kliknięcia.
5. Kamera wraca do `NeutralFocus`, wyhamowując na końcu. Po `return_seconds` leci `return_finished()` i klikanie znów działa.

## Jak dodać nową aktywność

Bez pisania kodu:

1. Przeciągnij `cabin_zoom_target.tscn` do `ZoomTargets`, nazwij np. `CbRadioFocus` i ustaw krzyżyk tam, gdzie kamera ma zajrzeć. Podkręć `zoom`.
2. Przeciągnij `cabin_activity.tscn` do `Activities`, nazwij `CbRadio`.
3. Wstaw obrazek przedmiotu i dopasuj obszar klikalny.
4. Wpisz `activity_id` = `cb_radio`.
5. Wskaż `CbRadioFocus` w polu `zoom_target_path`.
6. Ustaw `approach_seconds` i `return_seconds` — tempo należy do aktywności, nie do pinezki.

Uruchom i sprawdź. Aktywność sama się zarejestruje.

## Granica z resztą zespołu

Cała nasza powierzchnia styku to dwa sygnały kontrolera: `activity_started(activity_id)` i `activity_ended(activity_id, held_seconds)`. Gdy powstanie globalny mechanizm chillu, podłączy się pod nie i po naszej stronie nic się nie zmieni.

Dla Adasia zostawiamy `SpeedometerSlot` — pusty krzyżyk w `Interior`, w który wstawi swój klocek.

**Szyba to dziura, nie obiekt.** Grafika kabiny ma w miejscu szyby przezroczystość, więc droga Melina rysuje się **pod** kabiną, a kabina leży na wierzchu jak maska. Nie ma węzła `Windshield` i nie ma czego włączać ani wyłączać — wystarczy, że jego warstwa ma niższy `z_index` albo stoi wyżej w drzewie. Dopóki drogi nie ma, przez dziurę widać tło projektu i tak ma być.

## Weryfikacja

W projekcie nie ma frameworka testowego i nie będziemy go stawiać na jam. Sprawdzamy tak:

- `run_project` na `res://scenes/cabin.tscn`, potem `get_debug_output` — konsola nie może zawierać błędów
- przy `debug_log` włączonym kontroler wypisuje start i koniec z czasem; sprawdzamy, że czas zgadza się z długością trzymania i że jednoczesne kliknięcie dwóch przedmiotów uruchamia tylko jeden
- zjechanie myszką poza przedmiot w trakcie trzymania nie przerywa aktywności
- płynność dojazdu i powrotu kamery ocenia Piotr wzrokowo

## Ryzyka

**Klikanie przy przesuniętej kamerze.** Obszary klikalne żyją w przestrzeni świata, więc Godot przelicza pozycję myszy przez przekształcenie kamery — trafianie w przedmioty działa też przy przybliżeniu. Warto to sprawdzić od razu przy pierwszej aktywności, bo błąd tutaj podważa całą resztę.

**Jedna kamera na scenę.** Godot pozwala mieć aktywną tylko jedną `Camera2D`. Gdy Melin będzie skręcał kabinę z drogą, muszą uzgodnić, która kamera rządzi. Nasza jest w scenie kabiny, więc przy zagnieżdżaniu trzeba na to zwrócić uwagę.

## Uwaga o języku

Dokument jest po polsku, a starsze `docs/actor_pipeline/*` są po angielsku. Do zmiany, jeśli zespół woli spójność.
