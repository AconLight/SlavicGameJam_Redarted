class_name CabinZoomTarget
extends Marker2D

## Nieruchomy cel dla kamery: gdzie stanąć i jak mocno przybliżyć.
## Nie mówi nic o tempie — czasy najazdu i powrotu należą do aktywności,
## bo dwie aktywności mogą dzielić tę samą pinezkę i jechać do niej
## z różną szybkością.

## Siła przybliżenia. 1.0 to widok normalny, więcej to bliżej.
@export_range(0.5, 6.0, 0.05) var zoom := 1.35
