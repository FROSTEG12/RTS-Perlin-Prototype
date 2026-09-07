class_name NetworkSession
extends Node

signal status_changed(message: String)
signal host_started
signal connected_to_host
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal join_failed
signal host_disconnected

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 4

enum Mode { OFFLINE, HOST, CLIENT }

var mode := Mode.OFFLINE


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_host(port: int = DEFAULT_PORT) -> Error:
	stop()
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, MAX_PLAYERS)
	if result != OK:
		status_changed.emit("Не удалось открыть UDP-порт %d: %s" % [port, error_string(result)])
		return result
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	status_changed.emit("Матч создан · UDP %d" % port)
	host_started.emit()
	return OK


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
	return mode == Mode.HOST


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	status_changed.emit("Подключено · ID %d" % multiplayer.get_unique_id())
	connected_to_host.emit()


func _on_connection_failed() -> void:
	status_changed.emit("Не удалось подключиться")
	stop()
	join_failed.emit()


func _on_server_disconnected() -> void:
	status_changed.emit("Хост отключился")
	stop()
	host_disconnected.emit()
