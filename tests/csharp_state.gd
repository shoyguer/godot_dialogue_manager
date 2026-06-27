extends Node
## GDScript autoload mirror of CSharpState for editors without the .NET module.
## The C# source remains at CSharpState.cs for Godot .NET builds.


const SOME_CONSTANT: int = 2


enum Things {
	FirstThing,
	SecondThing,
}


@export var ThingsProperty: Things = Things.FirstThing
@export var SomeValue: int = 0


func GetAsyncValue() -> Variant:
	await get_tree().create_timer(0.2).timeout
	return 100


func LongMutation() -> void:
	await get_tree().create_timer(1.0).timeout


func OverloadedMethod(arg: Variant) -> Variant:
	if arg is int:
		return (arg as int) * 2
	if arg is String:
		return (arg as String) + "!"
	return null
