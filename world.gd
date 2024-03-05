extends Node

signal sens_changed(sens_value)

@onready var main_menu = $"CanvasLayer/Main Menu"
@onready var address_entry = $"CanvasLayer/Main Menu/MarginContainer/VBoxContainer/AddressEntry"
@onready var HUD = $CanvasLayer/HUD
@onready var health_bar = $"CanvasLayer/HUD/Health Bar"
@onready var pause_menu = $"CanvasLayer/Pause Menu"
@onready var settings_menu = $"CanvasLayer/Settings Menu"


const Player = preload("res://player.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

var paused = false
var in_game = false

func _unhandled_input(event):
	if in_game:
		if Input.is_action_pressed("quit"):
			paused = !paused
			pause_game()
	else:
		HUD.hide()
		pause_menu.hide()

func _on_host_button_pressed():
	main_menu.hide()
	HUD.show()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	
	#upnp_setup()

func _on_join_button_pressed():
	main_menu.hide()
	HUD.show()
	
	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	
	add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)
		player.pause.connect(pause_game)
	in_game = true

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func update_health_bar(health_value):
	health_bar.value = health_value

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
	


func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP DISCOVER FAILED! ERROR %s" % discover_result)
	
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), "UPNP INVALID GATEWAY!")
	
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP PORT MAPPING FAILED! ERROR %s" % map_result)
	
	print("SUCCESS! JOIN ADDRESS: %s" % upnp.query_external_address())

func _on_check_box_toggled(toggled_on):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func pause_game():
	if paused == true:
		HUD.hide()
		pause_menu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		pause_menu.hide()
		HUD.show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_quit_button_pressed():
	get_tree().quit()


func _on_settings_button_pressed():
	pause_menu.hide()
	settings_menu.show()


func _on_close_button_pressed():
	settings_menu.hide()
	pause_menu.show()


func _on_h_slider_value_changed(value):
	sens_changed.emit(value)

func _on_resume_button_pressed():
	paused = !paused
	pause_game()
