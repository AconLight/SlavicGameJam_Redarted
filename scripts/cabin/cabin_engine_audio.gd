extends AudioStreamPlayer

## Silnik: gra od pierwszej klatki i nie ustaje.
##
## Pętlę ustawiamy w kodzie, na kopii strumienia. W kodzie, bo ustawienie
## z pliku importu nie zawsze się przenosi. Na kopii, żeby nie grzebać we
## współdzielonym zasobie, gdyby ktoś użył tego samego pliku gdzie indziej.
##
## Dodatkowo restart na finished — gdyby pętla i tak nie zadziałała,
## silnik i tak nie zamilknie.


func _ready() -> void:
	if stream == null:
		return

	var looping := stream.duplicate()
	if looping is AudioStreamMP3:
		(looping as AudioStreamMP3).loop = true
	stream = looping

	finished.connect(_on_finished)
	play()


func _on_finished() -> void:
	play()
