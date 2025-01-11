extends Resource
class_name Event

@export_category("General")
@export var categorie: String = "Event"
@export var title: String
@export_multiline var description: String
@export var background: Texture2D

@export_category("Choises")
@export var choises: Array[EventChoise]
