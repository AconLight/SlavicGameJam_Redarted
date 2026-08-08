class_name Leaderboard
extends RefCounted

## Lista najlepszych wyników, do odczytu z ekranu startowego.
##
## Trzymana w osobnym pliku niż pojedynczy rekord z HighScore.gd. Tamten
## zapisuje cały swój plik od zera przy każdym nowym rekordzie, więc lista
## w tym samym pliku zostałaby wymazana.
##
## Same funkcje statyczne — nie ma tu żadnego stanu, więc nie ma po co
## wstawiać tego jako węzeł do scen.

## Plik siedzi w projekcie, nie w user:// — user:// wskazuje katalog danych
## aplikacji w systemie, czyli poza folderem repozytorium. Tu wyniki jadą
## razem z projektem i widać je w historii.
##
## Cena: res:// jest tylko do czytania w wyeksportowanej grze. Przy odpalaniu
## z edytora zapis działa, a na jam tyle wystarcza.
const PATH := "res://resources/data/leaderboard.json"
const MAX_ENTRIES := 10

## Wynik przejazdu, który właśnie się skończył. -1 = jeszcze nikt nie jechał
## od włączenia gry.
##
## Statyczna, bo musi przeżyć zmianę scen — węzły giną razem ze sceną, a wynik
## jest potrzebny dopiero na ekranie po koniec gry. Nie leci do pliku, bo to
## stan jednego uruchomienia, nie zapis.
static var last_score := -1


## Wyniki od najwyższego. Pusta lista, gdy nikt jeszcze nie jechał.
static func load_scores() -> Array[int]:
	var scores: Array[int] = []
	if not FileAccess.file_exists(PATH):
		return scores

	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return scores
	var text := file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("scores"):
		return scores

	for value in (data as Dictionary)["scores"]:
		scores.append(int(value))
	scores.sort()
	scores.reverse()
	return scores


static func add_score(score: int) -> void:
	if score <= 0:
		return

	var scores := load_scores()
	# Ten sam wynik jest zgłaszany co sekundę, dopóki chill leży na zerze.
	# Bez tego lista zapełniłaby się kopiami jednego przejazdu.
	if scores.has(score):
		return

	scores.append(score)
	scores.sort()
	scores.reverse()
	if scores.size() > MAX_ENTRIES:
		scores.resize(MAX_ENTRIES)
	_save(scores)


static func _save(scores: Array[int]) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"scores": scores}, "\t"))
	file.close()
