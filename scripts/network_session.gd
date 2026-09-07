class_name NetworkSession
extends Node

signal status_changed(message: String)
signal connected_to_host
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal join_failed
signal host_disconnected

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 4

enum Mode { OFFLINE, CLIENT }

var mode := Mode.OFFLINE
var server_pid := -1
var launching := false
var lifetime_listener: TCPServer
var lifetime_connection: StreamPeerTCP


func _ready() -> void:
	get_node("/root/MatchNetwork").match_ended.connect(_on_match_ended)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_host(port: int = DEFAULT_PORT, seed_value: int = -1) -> Error:
	stop()
	var probe := ENetMultiplayerPeer.new()
	var result := probe.create_server(port, MAX_PLAYERS)
	if result != OK:
		status_changed.emit("Не удалось открыть UDP-порт %d: %s" % [port, error_string(result)])
		return result
	probe.close()
	launching = true
	mode = Mode.CLIENT
	status_changed.emit("Запуск отдельного сервера…")
	lifetime_listener = TCPServer.new()
	result = lifetime_listener.listen(0, "127.0.0.1")
	if result != OK:
		stop()
		return result
	if seed_value < 0:
		seed_value = get_parent().world_seed
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", ProjectSettings.globalize_path("user://server.log"),
		"--script", "res://scripts/server_entry.gd", "--", "--port=%d" % port,
		"--seed=%d" % seed_value,
		"--owner-port=%d" % lifetime_listener.get_local_port()])
	server_pid = OS.create_process(OS.get_executable_path(), args, false)
	if server_pid <= 0:
		stop()
		status_changed.emit("Не удалось запустить процесс сервера")
		join_failed.emit()
		return ERR_CANT_CREATE
	var launched_pid := server_pid
	var deadline := Time.get_ticks_msec() + 45000
	var marker := "user://dedicated-%d.ready" % launched_pid
	while launching and server_pid == launched_pid and OS.is_process_running(launched_pid) and Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(marker):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))
			launching = false
			var peer := ENetMultiplayerPeer.new()
			result = peer.create_client("127.0.0.1", port)
			if result == OK:
				multiplayer.multiplayer_peer = peer
				status_changed.emit("Сервер запущен · подключение…")
				return OK
			break
		await get_tree().create_timer(0.1).timeout
	if server_pid != launched_pid:
		return ERR_SKIP
	stop()
	status_changed.emit("Не удалось запустить сервер")
	join_failed.emit()
	return ERR_CANT_CREATE


func join_host(address: String, port: int = DEFAULT_PORT) -> Error:
	stop()
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		clean_address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(clean_address, port)
	if result != OK:
		status_changed.emit("Не удалось начать подключение: %s" % error_string(result))
		return result
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	status_changed.emit("Подключение к %s:%d…" % [clean_address, port])
	return OK


func stop() -> void:
	# Closing the local lifetime connection also works when the game process crashes.
	if lifetime_connection != null:
		lifetime_connection.disconnect_from_host()
		lifetime_connection = null
	if lifetime_listener != null:
		lifetime_listener.stop()
		lifetime_listener = null
	launching = false
	server_pid = -1
	var bridge := get_node_or_null("/root/MatchNetwork")
	if bridge != null:
		bridge.loaded = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE


func is_online() -> bool:
	return mode != Mode.OFFLINE


func has_connection() -> bool:
	return (
		is_online()
		and multiplayer.multiplayer_peer != null
		and multiplayer.multiplayer_peer.get_connection_status()
		== MultiplayerPeer.CONNECTION_CONNECTED
	)


func is_host() -> bool:
	# Every graphical instance is a client; authority lives in server_entry.gd.
	return false


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null:
		peer.get_peer(1).set_timeout(32, 60000, 120000)
	status_changed.emit("Подключено · ID %d" % multiplayer.get_unique_id())
	connected_to_host.emit()


func _on_connection_failed() -> void:
	status_changed.emit("Не удалось подключиться")
	stop()
	join_failed.emit()


func _on_server_disconnected() -> void:
	stop()
	host_disconnected.emit()
	status_changed.emit("Соединение с сервером завершено")


func _on_match_ended(reason: String) -> void:
	stop()
	host_disconnected.emit()
	status_changed.emit(reason)


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	if lifetime_listener != null and lifetime_listener.is_connection_available():
		lifetime_connection = lifetime_listener.take_connection()
		lifetime_listener.stop()
		lifetime_listener = null
