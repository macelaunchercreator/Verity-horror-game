extends Node3D
# DEATH - Godot 4.3 port. Everything is built in code so only a few files are needed.

var player: CharacterBody3D
var cam: Camera3D
var flash: SpotLight3D
var yaw := 0.0
var pitch := 0.0
var sens := 1.5
var move_vec := Vector2.ZERO
var stick_id := -1
var look_id := -1
var stick_origin := Vector2.ZERO
var started := false
var won := false
var term_ok := false
var vault_open := false
var has_key := false
var door_open := false
var kp_open := false
var sprint := false
var stamina := 1.0
var buf := ""
var items: Array = []
var lamps: Array = []
var door: StaticBody3D
var vault_door: StaticBody3D
var key_node: Node3D
var key_light: OmniLight3D
var term_node: MeshInstance3D
var term_label: Label3D
var term_led: MeshInstance3D
var door_led: MeshInstance3D
var wall_mat: StandardMaterial3D
var metal_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var haz_mat: StandardMaterial3D
var vp := Vector2(1280, 720)

var ui: CanvasLayer
var title_ui: ColorRect
var death_grp: Control
var verity_lbl: Label
var menu_box: VBoxContainer
var bs_btn: Button
var bt_btn: Button
var settings_ui: ColorRect
var sv_lbl: Label
var hud: Control
var hud_buttons: Array = []
var stick_base: Panel
var knob: Panel
var use_btn: Button
var sprint_btn: Button
var light_btn: Button
var stam_bar: ColorRect
var toast_lbl: Label
var inv_lbl: Label
var kp_ui: ColorRect
var disp: Label
var win_ui: ColorRect


func _ready() -> void:
	randomize()
	vp = get_viewport().get_visible_rect().size
	make_env()
	make_materials()
	build_level()
	build_monster()
	make_player()
	items = [
		{"node": term_node, "r": 2.8, "msg": "PASSWORD", "active": term_active, "run": open_kp},
		{"node": key_node, "r": 2.6, "msg": "PICK UP", "active": key_active, "run": take_key},
		{"node": door, "r": 3.4, "msg": "USE", "active": door_active, "run": use_door},
	]
	build_ui()
	play_title()


# ---------- world ----------
func make_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.2, 0.26)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.025)
	env.fog_density = 0.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func mat(col: Color, rough: float, metal: float, noisy: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if noisy:
		var n := FastNoiseLite.new()
		n.frequency = 0.03
		var g := Gradient.new()
		g.set_color(0, Color(0.45, 0.45, 0.45))
		g.set_color(1, Color.WHITE)
		var t := NoiseTexture2D.new()
		t.noise = n
		t.color_ramp = g
		t.width = 256
		t.height = 256
		t.seamless = true
		m.albedo_texture = t
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.5
	return m


func make_materials() -> void:
	floor_mat = mat(Color(0.35, 0.35, 0.33), 0.9, 0.0, true)
	wall_mat = mat(Color(0.3, 0.29, 0.27), 0.85, 0.0, true)
	metal_mat = mat(Color(0.35, 0.22, 0.14), 0.5, 0.7, true)
	haz_mat = mat(Color(0.8, 0.65, 0.0), 0.7, 0.0, true)


func box(pos: Vector3, size: Vector3, m: Material, solid := true) -> StaticBody3D:
	var b := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	b.add_child(mi)
	if solid:
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		c.shape = s
		c.name = "col"
		b.add_child(c)
	b.position = pos
	add_child(b)
	return b


func wall(x: float, z: float, w: float, d: float) -> StaticBody3D:
	return box(Vector3(x, 2.5, z), Vector3(w, 5, d), wall_mat)


func pb(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func led(pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.07
	sph.height = 0.14
	var lm := StandardMaterial3D.new()
	lm.albedo_color = col
	lm.emission_enabled = true
	lm.emission = col
	mi.mesh = sph
	mi.material_override = lm
	mi.position = pos
	add_child(mi)
	return mi


func set_led(n: MeshInstance3D, col: Color) -> void:
	var lm := n.material_override as StandardMaterial3D
	lm.albedo_color = col
	lm.emission = col


func add_light(col: Color, energy: float, rng: float, pos: Vector3, flicker := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	add_child(l)
	if flicker:
		lamps.append({"l": l, "b": energy})
	return l


func make_key() -> Node3D:
	var k := Node3D.new()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1, 0.8, 0.2)
	gm.metallic = 1.0
	gm.roughness = 0.3
	gm.emission_enabled = true
	gm.emission = Color(0.5, 0.35, 0.0)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.08
	tm.outer_radius = 0.16
	ring.mesh = tm
	ring.material_override = gm
	ring.rotation_degrees.x = 90
	ring.position = Vector3(0, 0.3, 0)
	k.add_child(ring)
	pb(k, Vector3(0.07, 0.5, 0.05), Vector3(0, 0, 0), gm)
	pb(k, Vector3(0.2, 0.07, 0.05), Vector3(0.1, -0.2, 0), gm)
	pb(k, Vector3(0.14, 0.07, 0.05), Vector3(0.08, -0.08, 0), gm)
	k.scale = Vector3.ONE * 1.4
	return k


func build_level() -> void:
	box(Vector3(0, -0.1, -12), Vector3(44, 0.2, 54), floor_mat)
	box(Vector3(0, 5.1, -12), Vector3(44, 0.2, 54), wall_mat, false)
	# hall
	wall(-4, -1, 0.4, 14)
	wall(-4, -21, 0.4, 18)
	wall(4, -1, 0.4, 14)
	wall(4, -21, 0.4, 18)
	wall(0, 6, 8.4, 0.4)
	wall(-2.75, -30, 2.5, 0.4)
	wall(2.75, -30, 2.5, 0.4)
	box(Vector3(0, 4.5, -30), Vector3(3, 1, 0.4), haz_mat, false)
	door = box(Vector3(0, 2, -30), Vector3(3, 4, 0.4), metal_mat)
	door_led = led(Vector3(0, 4.85, -29.7), Color(1, 0, 0))
	# left room (password + vault)
	wall(-14, -10, 0.4, 12)
	wall(-9, -4, 10, 0.4)
	wall(-9, -16, 10, 0.4)
	wall(-10, -14, 0.3, 4)
	vault_door = box(Vector3(-12, 2, -12), Vector3(4, 4, 0.3), metal_mat)
	box(Vector3(-12, 4.5, -12), Vector3(4, 1, 0.3), metal_mat, false)
	box(Vector3(-12, 0.5, -14.5), Vector3(0.8, 1, 0.8), metal_mat)
	key_node = make_key()
	key_node.position = Vector3(-12, 1.6, -14.5)
	add_child(key_node)
	key_light = add_light(Color(1, 0.8, 0.35), 0.8, 6, Vector3(-12, 2, -14.5), false)
	# terminal on the wall
	var dk := mat(Color(0.08, 0.08, 0.08), 0.6, 0.6, false)
	pb(self, Vector3(1.8, 1.3, 0.2), Vector3(-8, 1.45, -4.3), dk)
	pb(self, Vector3(1.2, 0.25, 0.3), Vector3(-8, 0.7, -4.45), dk)
	for i in 6:
		var c := Color(1, 0.2, 0.2) if i % 3 == 0 else Color(0.2, 0.4, 1)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = c
		bm.emission_enabled = true
		bm.emission = c
		pb(self, Vector3(0.1, 0.05, 0.12), Vector3(-8.4 + i * 0.16, 0.84, -4.5), bm)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.01, 0.06, 0.03)
	sm.emission_enabled = true
	sm.emission = Color(0.0, 0.08, 0.03)
	term_node = pb(self, Vector3(1.5, 0.95, 0.08), Vector3(-8, 1.55, -4.43), sm)
	term_label = Label3D.new()
	term_label.text = "TAP TO ENTER\nPASSWORD"
	term_label.font_size = 44
	term_label.pixel_size = 0.004
	term_label.modulate = Color(0.2, 1.0, 0.4)
	term_label.rotation_degrees.y = 180
	term_label.position = Vector3(0, 0, -0.05)
	term_node.add_child(term_label)
	term_led = led(Vector3(-7.4, 2.0, -4.5), Color(1, 0, 0))
	add_light(Color(0.2, 1, 0.4), 0.6, 5, Vector3(-8, 1.6, -5.4), false)
	# hall decor
	for p in [Vector2(-3.4, -6), Vector2(3.4, -6), Vector2(-3.4, -14), Vector2(3.4, -14), Vector2(-3.4, -22), Vector2(3.4, -22)]:
		box(Vector3(p.x, 2.5, p.y), Vector3(0.7, 5, 0.7), metal_mat)
	box(Vector3(2.5, 0.6, -18), Vector3(1.2, 1.2, 1.2), metal_mat)
	box(Vector3(-2.6, 0.6, -25), Vector3(1.4, 1.2, 1.4), metal_mat)
	box(Vector3(-2.4, 3, -26), Vector3(1.6, 0.1, 6), metal_mat, false)
	for i in 5:
		pb(self, Vector3(0.04, 2.5, 0.04), Vector3(-1.5 + i * 0.8, 3.7, -9 - i * 3), metal_mat)
	var pipe := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.18
	cm.height = 36
	pipe.mesh = cm
	pipe.material_override = metal_mat
	pipe.rotation_degrees.x = 90
	pipe.position = Vector3(3.4, 4.5, -12)
	add_child(pipe)
	# right room: walls + glass
	wall(14, -10, 0.4, 12)
	wall(9, -4, 10, 0.4)
	wall(9, -16, 10, 0.4)
	var gl := StandardMaterial3D.new()
	gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gl.albedo_color = Color(0.5, 0.7, 0.6, 0.2)
	box(Vector3(9, 2, -15.7), Vector3(6, 4, 0.1), gl, false)
	# lights
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1, 0.92, 0.7)
	for z in [-4, -12, -20, -27]:
		add_light(Color(1, 0.85, 0.63), 1.1, 14, Vector3(0, 4.6, z))
		pb(self, Vector3(1, 0.1, 0.3), Vector3(0, 4.9, z), lamp_mat)
	add_light(Color(1, 0.13, 0), 1.4, 12, Vector3(9, 3.5, -10))
	add_light(Color(1, 0.6, 0), 0.8, 10, Vector3(12, 3, -14))


func build_monster() -> void:
	var mon := Node3D.new()
	mon.position = Vector3(11, 0, -10)
	mon.rotation_degrees.y = -90
	add_child(mon)
	var skin := mat(Color(0.55, 0.42, 0.24), 0.95, 0.0, false)
	var rib := mat(Color(0.3, 0.2, 0.1), 1.0, 0.0, false)
	var blk := StandardMaterial3D.new()
	blk.albedo_color = Color.BLACK
	blk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pb(mon, Vector3(0.6, 0.9, 0.32), Vector3(0, 2.5, 0), skin)
	pb(mon, Vector3(0.5, 0.35, 0.3), Vector3(0, 1.95, 0), skin)
	for i in 5:
		pb(mon, Vector3(0.5, 0.035, 0.02), Vector3(0, 2.2 + i * 0.14, 0.17), rib)
	var neck := pb(mon, Vector3(0.12, 0.55, 0.12), Vector3(-0.22, 3.07, 0), skin)
	neck.rotation.z = 1.06
	var hg := Node3D.new()
	hg.position = Vector3(-0.45, 3.2, 0.04)
	hg.rotation.z = 1.0
	mon.add_child(hg)
	pb(hg, Vector3(0.5, 0.6, 0.5), Vector3.ZERO, skin)
	pb(hg, Vector3(0.12, 0.14, 0.05), Vector3(-0.12, 0.08, 0.26), blk)
	pb(hg, Vector3(0.12, 0.14, 0.05), Vector3(0.12, 0.08, 0.26), blk)
	pb(hg, Vector3(0.38, 0.1, 0.05), Vector3(0, -0.14, 0.26), blk)
	pb(mon, Vector3(0.16, 1.8, 0.16), Vector3(-0.2, 0.9, 0), skin)
	pb(mon, Vector3(0.16, 1.8, 0.16), Vector3(0.2, 0.9, 0), skin)
	pb(mon, Vector3(0.24, 0.08, 0.42), Vector3(-0.2, 0.04, 0.1), skin)
	pb(mon, Vector3(0.24, 0.08, 0.42), Vector3(0.2, 0.04, 0.1), skin)
	pb(mon, Vector3(0.11, 1.8, 0.11), Vector3(0.4, 2.05, 0), skin)
	pb(mon, Vector3(0.14, 0.22, 0.1), Vector3(0.4, 0.95, 0), skin)
	pb(mon, Vector3(0.11, 0.9, 0.11), Vector3(-0.4, 2.5, 0), skin)
	pb(mon, Vector3(0.2, 0.9, 0.2), Vector3(-0.42, 1.6, 0), skin)
	pb(mon, Vector3(0.14, 0.22, 0.1), Vector3(-0.42, 1.04, 0), skin)
	# the password clue, etched on the right forearm
	var hand := Label3D.new()
	hand.text = "VERITY"
	hand.font_size = 40
	hand.pixel_size = 0.005
	hand.shaded = true
	hand.modulate = Color(0.25, 0.03, 0.0)
	hand.rotation_degrees.z = 90
	hand.position = Vector3(-0.42, 1.6, 0.105)
	mon.add_child(hand)
	# solid so you can't walk through it
	var sb := StaticBody3D.new()
	sb.position = Vector3(11, 1.8, -10)
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(0.8, 3.6, 0.9)
	cs.shape = shp
	sb.add_child(cs)
	add_child(sb)


func make_player() -> void:
	player = CharacterBody3D.new()
	var c := CollisionShape3D.new()
	var s := CapsuleShape3D.new()
	s.radius = 0.35
	s.height = 1.7
	c.shape = s
	c.position.y = 0.85
	player.add_child(c)
	player.position = Vector3(0, 0.05, 4)
	add_child(player)
	cam = Camera3D.new()
	cam.position.y = 1.6
	cam.fov = 75
	cam.far = 70
	player.add_child(cam)
	flash = SpotLight3D.new()
	flash.light_energy = 4.0
	flash.spot_range = 26
	flash.spot_angle = 30
	flash.shadow_enabled = true
	cam.add_child(flash)


# ---------- interactions ----------
func term_active() -> bool:
	return not term_ok

func key_active() -> bool:
	return vault_open and not has_key

func door_active() -> bool:
	return not door_open


func near() -> Dictionary:
	var best: Dictionary = {}
	var bd := 99.0
	for it in items:
		if not it["active"].call():
			continue
		var p: Vector3 = (it["node"] as Node3D).global_position
		var d := Vector2(player.position.x - p.x, player.position.z - p.z).length()
		if d < it["r"] and d < bd:
			best = it
			bd = d
	return best


func open_kp() -> void:
	kp_open = true
	buf = ""
	disp.text = "_"
	kp_ui.visible = true


func take_key() -> void:
	has_key = true
	key_node.visible = false
	key_light.visible = false
	inv_lbl.text = "KEY: MASTER KEY"
	toast("Master key acquired")


func use_door() -> void:
	if not has_key:
		toast("LOCKED. It needs the master key.")
		return
	door_open = true
	set_led(door_led, Color(0, 1, 0.3))
	slide_up(door, 3.0)
	await get_tree().create_timer(3.0).timeout
	won = true
	win_ui.visible = true


func slide_up(n: Node3D, t: float) -> void:
	var col := n.get_node_or_null("col") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)
	create_tween().tween_property(n, "position:y", n.position.y + 5.0, t)


func press_key(ch: String) -> void:
	if buf.length() < 10:
		buf += ch
		disp.text = buf


func key_del() -> void:
	buf = buf.substr(0, buf.length() - 1)
	disp.text = buf if buf != "" else "_"


func key_close() -> void:
	kp_ui.visible = false
	kp_open = false


func key_enter() -> void:
	if buf == "VERITY":
		term_ok = true
		vault_open = true
		set_led(term_led, Color(0, 1, 0.3))
		term_label.text = "ACCESS\nGRANTED"
		key_close()
		slide_up(vault_door, 2.0)
		toast("Vault unlocked")
	else:
		buf = ""
		disp.text = "ACCESS DENIED"
		await get_tree().create_timer(0.9).timeout
		if buf == "":
			disp.text = "_"


func toast(t: String) -> void:
	toast_lbl.text = t
	toast_lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.5)


# ---------- ui ----------
func lbl(parent: Node, txt: String, size: int, col: Color, pos: Vector2, w: float) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(w, size * 1.3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func btn(parent: Node, txt: String, size: Vector2, pos: Vector2, fs: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = size
	b.size = size
	b.position = pos
	b.add_theme_font_size_override("font_size", fs)
	parent.add_child(b)
	return b


func circle(size: float, alpha: float) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, alpha)
	sb.set_corner_radius_all(int(size / 2))
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func fullscreen(col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.size = vp
	ui.add_child(c)
	return c


func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	float v = smoothstep(0.3, 0.95, length(UV - vec2(0.5)) * 1.3);
	float g = fract(sin(dot(UV * vec2(1280.0, 720.0) + vec2(TIME * 60.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(mix(vec3(g), vec3(0.0), v), max(v * 0.8, 0.06));
}"""
	var post := ColorRect.new()
	post.size = vp
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = sh
	post.material = pm
	ui.add_child(post)
	# --- HUD ---
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	ui.add_child(hud)
	stick_base = circle(120, 0.08)
	stick_base.visible = false
	hud.add_child(stick_base)
	knob = circle(40, 0.5)
	stick_base.add_child(knob)
	use_btn = btn(hud, "USE", Vector2(100, 70), Vector2(vp.x - 130, vp.y - 100), 18)
	sprint_btn = btn(hud, "SPRINT", Vector2(100, 70), Vector2(vp.x - 240, vp.y - 100), 16)
	light_btn = btn(hud, "LIGHT", Vector2(100, 70), Vector2(vp.x - 185, vp.y - 185), 16)
	hud_buttons = [use_btn, sprint_btn, light_btn]
	for hbtn in hud_buttons:
		hbtn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbtn.focus_mode = Control.FOCUS_NONE
	var sbg := ColorRect.new()
	sbg.color = Color(1, 1, 1, 0.15)
	sbg.size = Vector2(140, 8)
	sbg.position = Vector2(vp.x / 2 - 70, vp.y - 24)
	sbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(sbg)
	stam_bar = ColorRect.new()
	stam_bar.color = Color(0.8, 0.8, 0.8)
	stam_bar.size = Vector2(140, 8)
	stam_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sbg.add_child(stam_bar)
	toast_lbl = lbl(hud, "", 24, Color(0.9, 0.2, 0.2), Vector2(0, vp.y * 0.14), vp.x)
	toast_lbl.modulate.a = 0.0
	inv_lbl = lbl(hud, "", 18, Color(0.8, 0.8, 0.8), Vector2(10, 10), 300)
	# --- keypad ---
	kp_ui = fullscreen(Color(0, 0, 0, 0.93))
	kp_ui.visible = false
	var vb := VBoxContainer.new()
	vb.position = Vector2(vp.x / 2 - 380, vp.y / 2 - 230)
	vb.size = Vector2(760, 460)
	vb.add_theme_constant_override("separation", 8)
	kp_ui.add_child(vb)
	disp = Label.new()
	disp.text = "_"
	disp.add_theme_font_size_override("font_size", 44)
	disp.add_theme_color_override("font_color", Color(0.2, 1, 0.4))
	disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(disp)
	for row in ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]:
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 6)
		vb.add_child(hb)
		for ch in row:
			var kb := Button.new()
			kb.text = ch
			kb.custom_minimum_size = Vector2(66, 62)
			kb.add_theme_font_size_override("font_size", 28)
			kb.pressed.connect(press_key.bind(ch))
			hb.add_child(kb)
	var hb2 := HBoxContainer.new()
	hb2.alignment = BoxContainer.ALIGNMENT_CENTER
	hb2.add_theme_constant_override("separation", 10)
	vb.add_child(hb2)
	for pair in [["DEL", key_del], ["ENTER", key_enter], ["CLOSE", key_close]]:
		var kb2 := Button.new()
		kb2.text = pair[0]
		kb2.custom_minimum_size = Vector2(150, 62)
		kb2.add_theme_font_size_override("font_size", 26)
		kb2.pressed.connect(pair[1])
		hb2.add_child(kb2)
	# --- win ---
	win_ui = fullscreen(Color.BLACK)
	win_ui.visible = false
	lbl(win_ui, "YOU ESCAPED", 90, Color(0.8, 0, 0), Vector2(0, vp.y * 0.3), vp.x)
	var again := btn(win_ui, "PLAY AGAIN", Vector2(260, 70), Vector2(vp.x / 2 - 130, vp.y * 0.65), 26)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	# --- settings ---
	settings_ui = fullscreen(Color.BLACK)
	settings_ui.visible = false
	var sv := VBoxContainer.new()
	sv.position = Vector2(vp.x / 2 - 260, vp.y / 2 - 200)
	sv.size = Vector2(520, 400)
	sv.add_theme_constant_override("separation", 14)
	settings_ui.add_child(sv)
	sv_lbl = Label.new()
	sv_lbl.text = "Touch look sensitivity: 1.5"
	sv_lbl.add_theme_font_size_override("font_size", 24)
	sv.add_child(sv_lbl)
	var sl := HSlider.new()
	sl.min_value = 0.1
	sl.max_value = 5.0
	sl.step = 0.1
	sl.value = 1.5
	sl.custom_minimum_size = Vector2(520, 50)
	sl.value_changed.connect(on_sens)
	sv.add_child(sl)
	var ql := Label.new()
	ql.text = "Graphics quality"
	ql.add_theme_font_size_override("font_size", 24)
	sv.add_child(ql)
	var qh := HBoxContainer.new()
	qh.add_theme_constant_override("separation", 8)
	sv.add_child(qh)
	var names := ["Low", "Medium", "High", "Ultra"]
	for i in 4:
		var qb := Button.new()
		qb.text = names[i]
		qb.custom_minimum_size = Vector2(120, 60)
		qb.add_theme_font_size_override("font_size", 22)
		qb.pressed.connect(set_quality.bind(i))
		qh.add_child(qb)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 64)
	back.add_theme_font_size_override("font_size", 28)
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = Color.WHITE
	for st in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(st, wsb)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		back.add_theme_color_override(cn, Color.BLACK)
	back.pressed.connect(func(): settings_ui.visible = false)
	sv.add_child(back)
	# --- title (on top) ---
	title_ui = fullscreen(Color.BLACK)
	death_grp = Control.new()
	death_grp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_grp.modulate.a = 0.0
	title_ui.add_child(death_grp)
	var dl := lbl(death_grp, "DEATH", 180, Color(0.75, 0.02, 0.02), Vector2(0, vp.y * 0.12), vp.x)
	dl.add_theme_color_override("font_outline_color", Color(0.3, 0, 0))
	dl.add_theme_constant_override("outline_size", 6)
	for dx in [0.36, 0.5, 0.63]:
		var dr := ColorRect.new()
		dr.color = Color(0.54, 0.01, 0.01)
		dr.size = Vector2(8, 0)
		dr.position = Vector2(vp.x * dx, vp.y * 0.12 + 200)
		dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		death_grp.add_child(dr)
		var dt := create_tween().set_loops()
		dt.tween_interval(randf() * 2.0)
		dt.tween_property(dr, "size:y", 90.0 + randf() * 60.0, 3.0)
		dt.tween_property(dr, "size:y", 0.0, 0.01)
	verity_lbl = lbl(title_ui, "VERITY", 150, Color(0.8, 0.8, 0.8), Vector2(0, vp.y * 0.14), vp.x)
	verity_lbl.modulate.a = 0.0
	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(vp.x - 270, vp.y - 180)
	menu_box.add_theme_constant_override("separation", 14)
	menu_box.modulate.a = 0.0
	title_ui.add_child(menu_box)
	bs_btn = Button.new()
	bs_btn.text = "START"
	bs_btn.custom_minimum_size = Vector2(220, 64)
	bs_btn.add_theme_font_size_override("font_size", 26)
	bs_btn.disabled = true
	bs_btn.pressed.connect(on_start)
	menu_box.add_child(bs_btn)
	bt_btn = Button.new()
	bt_btn.text = "SETTINGS"
	bt_btn.custom_minimum_size = Vector2(220, 64)
	bt_btn.add_theme_font_size_override("font_size", 26)
	bt_btn.disabled = true
	bt_btn.pressed.connect(func(): settings_ui.visible = true)
	menu_box.add_child(bt_btn)
	ui.move_child(settings_ui, ui.get_child_count() - 1)


func play_title() -> void:
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(death_grp, "modulate:a", 1.0, 2.5)
	tw.tween_interval(2.0)
	tw.tween_property(death_grp, "modulate:a", 0.0, 1.5)
	tw.tween_interval(1.0)
	tw.tween_property(verity_lbl, "modulate:a", 1.0, 2.5)
	tw.tween_interval(1.0)
	tw.tween_property(menu_box, "modulate:a", 1.0, 2.0)
	tw.tween_callback(enable_menu)


func enable_menu() -> void:
	bs_btn.disabled = false
	bt_btn.disabled = false


func on_start() -> void:
	started = true
	title_ui.visible = false
	hud.visible = true


func on_use() -> void:
	var n := near()
	if not n.is_empty():
		n["run"].call()


func on_sens(v: float) -> void:
	sens = v
	sv_lbl.text = "Touch look sensitivity: %.1f" % v


func set_quality(i: int) -> void:
	get_viewport().scaling_3d_scale = [0.6, 0.75, 0.9, 1.0][i]
	get_viewport().msaa_3d = Viewport.MSAA_2X if i >= 2 else Viewport.MSAA_DISABLED
	flash.shadow_enabled = i >= 2


# ---------- input + loop ----------
func hud_tap(pos: Vector2) -> bool:
	if use_btn.get_global_rect().has_point(pos):
		on_use()
		return true
	if sprint_btn.get_global_rect().has_point(pos):
		set_sprint(not sprint)
		return true
	if light_btn.get_global_rect().has_point(pos):
		flash.visible = not flash.visible
		light_btn.modulate = Color.WHITE if flash.visible else Color(0.5, 0.5, 0.5)
		return true
	return false


func set_sprint(on: bool) -> void:
	sprint = on
	sprint_btn.modulate = Color(1, 0.6, 0.3) if on else Color.WHITE


func over_ui(pos: Vector2) -> bool:
	for b in hud_buttons:
		if (b as Button).get_global_rect().has_point(pos):
			return true
	return false


func _input(e: InputEvent) -> void:
	if not started or kp_open or won or settings_ui.visible:
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			if hud_tap(t.position):
				return
			if t.position.x < vp.x * 0.5:
				if stick_id == -1:
					stick_id = t.index
					stick_origin = t.position
					stick_base.position = t.position - stick_base.size / 2
					stick_base.visible = true
					knob.position = (stick_base.size - knob.size) / 2
			elif look_id == -1:
				look_id = t.index
		else:
			if t.index == stick_id:
				stick_id = -1
				move_vec = Vector2.ZERO
				stick_base.visible = false
			elif t.index == look_id:
				look_id = -1
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == stick_id:
			var off := (d.position - stick_origin).limit_length(50.0)
			move_vec = off / 50.0
			knob.position = (stick_base.size - knob.size) / 2 + off
		elif d.index == look_id:
			yaw -= d.relative.x * 0.003 * sens
			pitch = clampf(pitch - d.relative.y * 0.003 * sens, -1.4, 1.4)
			player.rotation.y = yaw
			cam.rotation.x = pitch


func _process(delta: float) -> void:
	for l in lamps:
		var light: OmniLight3D = l["l"]
		if randf() < 0.015:
			light.light_energy = randf() * 0.3
		else:
			light.light_energy = lerpf(light.light_energy, l["b"], 0.2)
	if not started:
		return
	var n := near()
	if n.is_empty():
		use_btn.text = "USE"
		use_btn.modulate = Color.WHITE
	else:
		use_btn.text = n["msg"]
		use_btn.modulate = Color(1, 0.4, 0.4)
	key_node.rotation.y += delta * 1.5
	key_node.position.y = 1.6 + sin(Time.get_ticks_msec() / 400.0) * 0.08
	stam_bar.size.x = 140.0 * stamina


func _physics_process(delta: float) -> void:
	if not started or kp_open or won:
		return
	var mv := move_vec
	if stick_id == -1:
		mv = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var moving := mv.length() > 0.05
	var sp := 2.8
	if sprint and moving and stamina > 0.0:
		sp = 5.0
		stamina = maxf(0.0, stamina - 0.25 * delta)
		if stamina <= 0.0:
			set_sprint(false)
	else:
		stamina = minf(1.0, stamina + 0.15 * delta)
	var dir := player.global_transform.basis * Vector3(mv.x, 0, mv.y)
	player.velocity.x = dir.x * sp
	player.velocity.z = dir.z * sp
	if player.is_on_floor():
		player.velocity.y = -0.1
	else:
		player.velocity.y -= 20.0 * delta
	player.move_and_slide()
