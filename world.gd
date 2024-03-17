extends Node

signal sens_changed(sens_value)
signal color_changed(color)
signal game_paused(paused)
signal username_changed(username)

@onready var main_menu = $"CanvasLayer/Main Menu"
@onready var address_entry = $"CanvasLayer/Main Menu/MarginContainer/VBoxContainer/AddressEntry"
@onready var HUD = $CanvasLayer/HUD
@onready var health_bar = $"CanvasLayer/HUD/Health Bar"
@onready var ammo_label = $"CanvasLayer/HUD/Ammo Label"
@onready var pause_menu = $"CanvasLayer/Pause Menu"
@onready var settings_menu = $"CanvasLayer/Settings Menu"
@onready var address_label = $"CanvasLayer/HUD/Address Label"
@onready var color_menu = $"CanvasLayer/Color Menu"
@onready var scoreboard = $CanvasLayer/HUD/Scoreboard
@onready var username_entry = $"CanvasLayer/Main Menu/MarginContainer/VBoxContainer/UsernameEntry"
@onready var hitmarker = $CanvasLayer/HUD/Hitmarker
@onready var username_label = $"CanvasLayer/HUD/Username Label"


const Player = preload("res://player.tscn")
var PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

var paused = false
var in_game = false
var is_host = false

var peer_ids = []

var username = ""

func _ready():
	#find_available_port()
	
	main_menu.show()
	HUD.hide()
	pause_menu.hide()
	settings_menu.hide()
	color_menu.hide()
	
func _unhandled_input(event):
	if in_game:
		if Input.is_action_pressed("quit"):
			paused = !paused
			pause_game()
	else:
		HUD.hide()
		pause_menu.hide()

func _process(delta):
	#username_changed.emit(username)
	pass

func _on_host_button_pressed():
	is_host = true
	main_menu.hide()
	HUD.show()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	var unique_id = multiplayer.get_unique_id()
	
	if username_entry.text == "":
		username = str(unique_id)
	else:
		username = username_entry.text
	
	username_label.text = "Username: " + username
	
	add_player(unique_id)
	
	upnp_setup()
	
	in_game = true

func _on_join_button_pressed():
	main_menu.hide()
	HUD.show()
	var address = ""
	if address_entry.text == "1234":
		address = "104.33.64.173"
	else:
		address = address_entry.text
	
	
	enet_peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = enet_peer
	address_label.text = ""
	in_game = true

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	peer_ids.append(peer_id)
	
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)
		player.ammo_changed.connect(update_ammo_label)
		player.hitmarker.connect(show_hitmarker)
	if is_host:
		update_scoreboard(peer_id)

@rpc("call_local")
func update_scoreboard(peer_id):
	var playerLabel = Label.new()
	playerLabel.name = str(peer_id)
	playerLabel.text = str(peer_id) + ": "
	playerLabel.add_theme_font_size_override("font", 40)
	scoreboard.add_child(playerLabel)

@rpc("call_local")
func remove_scoreboard(peer_id):
	var score = scoreboard.get_node_or_null(str(peer_id))
	if score:
		score.queue_free()

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		remove_scoreboard.rpc(peer_id)
		player.queue_free()

func update_health_bar(health_value):
	health_bar.value = health_value

func update_ammo_label(ammo_value):
	ammo_label.text = "Ammo: " + str(ammo_value)

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
		node.ammo_changed.connect(update_ammo_label)
		node.hitmarker.connect(show_hitmarker)
		
	update_scoreboard.rpc(node.name)
	if username_entry.text == "":
		username = node.name
		print(node.name)
	else:
		username = username_entry.text
	username_label.text = "Username: " + username

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP DISCOVER FAILED! ERROR %s" % discover_result)
	
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), "UPNP INVALID GATEWAY!")
	
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP PORT MAPPING FAILED! ERROR %s" % map_result)
	
	print("SUCCESS! JOIN ADDRESS: %s" % upnp.query_external_address())
	address_label.text = upnp.query_external_address()

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
		game_paused.emit(true)
	else:
		pause_menu.hide()
		HUD.show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		game_paused.emit(false)


func find_available_port():
		while PORT < 9999:
			var upnp = UPNP.new()
			var map_result = upnp.add_port_mapping(PORT)
			if map_result == UPNP.UPNP_RESULT_SUCCESS:
				return
			else:
				PORT += 1
				print(PORT)

func show_hitmarker():
	hitmarker.show()
	await get_tree().create_timer(0.1).timeout
	hitmarker.hide()

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


func _on_back_button_pressed():
	color_menu.hide()
	settings_menu.show()


func _on_color_picker_color_changed(color):
	color_changed.emit(color)


func _on_change_color_pressed():
	settings_menu.hide()
	color_menu.show()
