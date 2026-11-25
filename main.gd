extends Node3D
# DEATH - Godot 4.3. Everything is built in code so only a few files are needed.

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
var crates: Array = []
var hl_crate: Dictionary = {}
var hl_spot: SpotLight3D
var hl_plate: MeshInstance3D
var crate_opened := false
var follower: Node3D
var following := false
var shake := 0.0
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
var dark_mat: StandardMaterial3D
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
var red_rect: ColorRect


func _ready() -> void:
	randomize()
	vp = get_viewport().get_visible_rect().size
	get_viewport().msaa_3d = Viewport.MSAA_2X
	make_env()
	make_materials()
	build_level()
	build_third_room()
	build_monster()
	make_follower()
	make_player()
	setup_items()
	build_ui()
	play_title()


# ---------- materials ----------
func noise_tex(freq: float, normal: bool) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 512
	t.height = 512
	t.seamless = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = 8.0
	else:
		var g := Gradient.new()
		g.set_color(0, Color(0.28, 0.28, 0.28))
		g.set_color(0.5, Color(0.68, 0.68, 0.68))
		g.set_color(1, Color.WHITE)
		t.color_ramp = g
	return t


func mat(col: Color, rough: float, metal: float, noisy: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	if noisy:
		m.albedo_texture = noise_tex(0.035, false)
		m.normal_enabled = true
		m.normal_texture = noise_tex(0.09, true)
		m.normal_scale = 1.6
		m.roughness_texture = noise_tex(0.05, false)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.45
	return m


func skin_mat(col: Color) -> StandardMaterial3D:
	var m := mat(col, 0.72, 0.0, true)
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3.ONE * 3.5
	m.normal_scale = 1.4
	return m


func make_materials() -> void:
	floor_mat = mat(Color(0.32, 0.32, 0.3), 0.78, 0.08, true)
	wall_mat = mat(Color(0.28, 0.27, 0.25), 0.82, 0.05, true)
	metal_mat = mat(Color(0.38, 0.24, 0.15), 0.38, 0.78, true)
	haz_mat = mat(Color(0.85, 0.68, 0.02), 0.55, 0.15, true)
	dark_mat = mat(Color(0.05, 0.05, 0.06), 0.65, 0.35, true)


func make_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.23, 0.29)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.025, 0.025, 0.03)
	env.fog_density = 0.045
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ---------- helpers ----------
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
	var wb := box(Vector3(x, 2.5, z), Vector3(w, 5, d), wall_mat)
	# base trim & ceiling beam for richer architectural depth
	pb(self, Vector3(w + 0.04, 0.22, d + 0.04), Vector3(x, 0.11, z), dark_mat)
	pb(self, Vector3(w + 0.04, 0.25, d + 0.04), Vector3(x, 4.88, z), metal_mat)
	return wb


func pb(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func part(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func mk_sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 12
	return s


func mk_cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	c.radial_segments = 16
	c.rings = 6
	return c


func mk_box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func led(pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.075
	sp.height = 0.15
	var lm := StandardMaterial3D.new()
	lm.albedo_color = col
	lm.emission_enabled = true
	lm.emission = col
	lm.emission_energy_multiplier = 1.6
	mi.mesh = sp
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
	l.omni_attenuation = 1.35
	l.position = pos
	add_child(l)
	if flicker:
		lamps.append({"l": l, "b": energy})
	return l


func pipe(pos: Vector3, length: float, r: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 14
	var mi := part(self, cm, pos, metal_mat)
	mi.rotation_degrees.x = 90


func sign3d(parent: Node3D, txt: String, pos: Vector3, rot_y: float, col: Color, fs: int) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font_size = fs
	l.pixel_size = 0.005
	l.modulate = col
	l.outline_size = 6
	l.outline_modulate = Color(0.05, 0.05, 0.05, 0.9)
	l.position = pos
	l.rotation_degrees.y = rot_y
	parent.add_child(l)
	return l


func add_cone(pos: Vector3) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 1.25
	cm.height = 4.6
	cm.radial_segments = 20
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(1, 0.9, 0.65, 0.04)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	part(self, cm, pos, m)


# Floating blobs removed per request.
func add_dust(_pos: Vector3, _ext: Vector3) -> void:
	pass


func make_key() -> Node3D:
	var k := Node3D.new()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1, 0.82, 0.22)
	gm.metallic = 1.0
	gm.roughness = 0.25
	gm.emission_enabled = true
	gm.emission = Color(0.55, 0.38, 0.02)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.08
	tm.outer_radius = 0.16
	var ring := part(k, tm, Vector3(0, 0.3, 0), gm)
	ring.rotation_degrees.x = 90
	pb(k, Vector3(0.07, 0.5, 0.05), Vector3(0, 0, 0), gm)
	pb(k, Vector3(0.2, 0.07, 0.05), Vector3(0.1, -0.2, 0), gm)
	pb(k, Vector3(0.14, 0.07, 0.05), Vector3(0.08, -0.08, 0), gm)
	k.scale = Vector3.ONE * 1.4
	return k


# ---------- level ----------
func build_level() -> void:
	box(Vector3(0, -0.1, -18), Vector3(44, 0.2, 66), floor_mat)
	box(Vector3(0, 5.1, -18), Vector3(44, 0.2, 66), wall_mat, false)
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
	pb(door, Vector3(2.4, 0.35, 0.46), Vector3(0, -0.7, 0), haz_mat)
	door_led = led(Vector3(0, 4.85, -29.7), Color(1, 0, 0))
	sign3d(door, "MAIN EXIT", Vector3(0, 1.2, 0.22), 0, Color(1, 0.12, 0.12), 40)
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
	key_light = add_light(Color(1, 0.8, 0.35), 0.85, 6, Vector3(-12, 2, -14.5), false)
	# terminal on the wall
	var dk := mat(Color(0.08, 0.08, 0.08), 0.55, 0.65, false)
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
	sm.emission = Color(0.0, 0.09, 0.035)
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
	add_light(Color(0.2, 1, 0.4), 0.65, 5, Vector3(-8, 1.6, -5.4), false)
	# hall decor
	for p in [Vector2(-3.4, -6), Vector2(3.4, -6), Vector2(-3.4, -14), Vector2(3.4, -14), Vector2(-3.4, -22), Vector2(3.4, -22)]:
		box(Vector3(p.x, 2.5, p.y), Vector3(0.7, 5, 0.7), metal_mat)
	for z in range(-2, -30, -4):
		pb(self, Vector3(8, 0.35, 0.35), Vector3(0, 4.75, z), metal_mat)
	for sx in [-1.0, 1.0]:
		pb(self, Vector3(0.12, 0.35, 14), Vector3(sx * 3.78, 0.18, -1), dark_mat)
		pb(self, Vector3(0.12, 0.35, 18), Vector3(sx * 3.78, 0.18, -21), dark_mat)
		pipe(Vector3(sx * 3.6, 3.7, -12), 36, 0.1)
	pipe(Vector3(3.4, 4.5, -12), 36, 0.18)
	box(Vector3(2.5, 0.6, -18), Vector3(1.2, 1.2, 1.2), metal_mat)
	box(Vector3(-2.6, 0.6, -25), Vector3(1.4, 1.2, 1.4), metal_mat)
	box(Vector3(-2.4, 3, -26), Vector3(1.6, 0.1, 6), metal_mat, false)
	for i in 5:
		pb(self, Vector3(0.04, 2.5, 0.04), Vector3(-1.5 + i * 0.8, 3.7, -9 - i * 3), metal_mat)
	sign3d(self, "CONTAINMENT", Vector3(3.78, 3.5, -10), -90, Color(1, 0.15, 0.1), 44)
	sign3d(self, "VAULT", Vector3(-3.78, 3.5, -10), 90, Color(1, 0.7, 0.2), 44)
	# right room: walls + glass
	wall(14, -10, 0.4, 12)
	wall(9, -4, 10, 0.4)
	wall(9, -16, 10, 0.4)
	var gl := StandardMaterial3D.new()
	gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gl.roughness = 0.1
	gl.albedo_color = Color(0.55, 0.78, 0.7, 0.18)
	box(Vector3(9, 2, -15.7), Vector3(6, 4, 0.1), gl, false)
	# lights + subtle light shafts
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1, 0.92, 0.72)
	for z in [-4, -12, -20, -27]:
		add_light(Color(1, 0.85, 0.63), 1.15, 14, Vector3(0, 4.6, z))
		pb(self, Vector3(1.05, 0.12, 0.34), Vector3(0, 4.92, z), dark_mat)
		pb(self, Vector3(0.95, 0.08, 0.26), Vector3(0, 4.88, z), lamp_mat)
		add_cone(Vector3(0, 2.4, z))
	add_light(Color(1, 0.13, 0), 1.45, 12, Vector3(9, 3.5, -10))
	add_light(Color(1, 0.6, 0), 0.85, 10, Vector3(12, 3, -14))


func make_crate(pos: Vector3) -> Dictionary:
	var root := StaticBody3D.new()
	root.position = pos
	add_child(root)
	var cm := mat(Color(0.32, 0.22, 0.13), 0.86, 0.04, true)
	pb(root, Vector3(1.6, 0.1, 1.6), Vector3(0, 0.05, 0), cm)
	pb(root, Vector3(1.6, 1.1, 0.1), Vector3(0, 0.65, 0.75), cm)
	pb(root, Vector3(1.6, 1.1, 0.1), Vector3(0, 0.65, -0.75), cm)
	pb(root, Vector3(0.1, 1.1, 1.4), Vector3(0.75, 0.65, 0), cm)
	pb(root, Vector3(0.1, 1.1, 1.4), Vector3(-0.75, 0.65, 0), cm)
	# cross slat detail
	pb(root, Vector3(1.42, 0.12, 0.12), Vector3(0, 0.65, 0.8), cm)
	pb(root, Vector3(1.42, 0.12, 0.12), Vector3(0, 0.65, -0.8), cm)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pb(root, Vector3(0.15, 1.22, 0.15), Vector3(sx * 0.78, 0.65, sz * 0.78), metal_mat)
	var lid := pb(root, Vector3(1.7, 0.12, 1.7), Vector3(0, 1.26, 0), cm)
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(1.6, 1.3, 1.6)
	cs.shape = shp
	cs.position.y = 0.65
	root.add_child(cs)
	return {"root": root, "lid": lid}


func build_third_room() -> void:
	wall(-5, -30, 2, 0.4)
	wall(5, -30, 2, 0.4)
	wall(-6, -40, 0.4, 20)
	wall(6, -40, 0.4, 20)
	wall(0, -50, 12.4, 0.4)
	add_light(Color(1, 0.8, 0.6), 0.75, 12, Vector3(0, 4.6, -36))
	add_light(Color(1, 0.8, 0.6), 0.65, 12, Vector3(0, 4.6, -44))
	for z in [-38.0, -45.0]:
		for x in [-3.5, 0.0, 3.5]:
			crates.append(make_crate(Vector3(x, 0, z)))
	hl_crate = crates[4]
	var pl := StandardMaterial3D.new()
	pl.albedo_color = Color(1, 0.05, 0.02)
	pl.emission_enabled = true
	pl.emission = Color(1, 0.05, 0.02)
	pl.emission_energy_multiplier = 2.0
	hl_plate = pb(hl_crate["lid"], Vector3(1.0, 0.03, 1.0), Vector3(0, 0.08, 0), pl)
	hl_plate.visible = false
	hl_spot = SpotLight3D.new()
	hl_spot.light_color = Color(1, 0.1, 0.05)
	hl_spot.light_energy = 3.0
	hl_spot.spot_range = 8.0
	hl_spot.spot_angle = 28.0
	hl_spot.position = Vector3(0, 4.7, -45)
	hl_spot.rotation_degrees.x = -90
	hl_spot.visible = false
	add_child(hl_spot)


# ---------- the Verity monster & smiley follower ----------
func attach_smiley_face(parent_head: Node3D, z_pos: float, radius: float) -> void:
	var smile_yellow := StandardMaterial3D.new()
	smile_yellow.albedo_color = Color(1.0, 0.84, 0.08)
	smile_yellow.roughness = 0.45
	smile_yellow.metallic = 0.0
	smile_yellow.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.05, 0.05, 0.05)
	ink.roughness = 0.3
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	# Yellow smiley face disc on the front of the head
	var face_disc := CylinderMesh.new()
	face_disc.top_radius = radius
	face_disc.bottom_radius = radius
	face_disc.height = 0.04
	face_disc.radial_segments = 28
	var fmi := part(parent_head, face_disc, Vector3(0, 0.02, z_pos), smile_yellow)
	fmi.rotation_degrees.x = 90

	# Two eyes
	for ex in [-radius * 0.34, radius * 0.34]:
		part(parent_head, mk_sph(radius * 0.13), Vector3(ex, radius * 0.22, z_pos + 0.025), ink)

	# Curved smile made of angled segments
	var smile_pts := [
		Vector2(-radius * 0.52, -radius * 0.06),
		Vector2(-radius * 0.34, -radius * 0.28),
		Vector2(-radius * 0.12, -radius * 0.38),
		Vector2(radius * 0.12, -radius * 0.38),
		Vector2(radius * 0.34, -radius * 0.28),
		Vector2(radius * 0.52, -radius * 0.06),
	]
	for i in smile_pts.size() - 1:
		var a: Vector2 = smile_pts[i]
		var b: Vector2 = smile_pts[i + 1]
		var mid := (a + b) * 0.5
		var diff := b - a
		var seg := part(parent_head, mk_box(Vector3(diff.length() + 0.025, radius * 0.09, 0.03)), Vector3(mid.x, mid.y, z_pos + 0.025), ink)
		seg.rotation.z = atan2(diff.y, diff.x)
		# Smile end hooks
		if i == 0:
			var hk1 := part(parent_head, mk_box(Vector3(radius * 0.12, radius * 0.07, 0.03)), Vector3(a.x - 0.01, a.y + 0.03, z_pos + 0.025), ink)
			hk1.rotation.z = 0.75
		if i == smile_pts.size() - 2:
			var hk2 := part(parent_head, mk_box(Vector3(radius * 0.12, radius * 0.07, 0.03)), Vector3(b.x + 0.01, b.y + 0.03, z_pos + 0.025), ink)
			hk2.rotation.z = -0.75


func make_verity(smiley_face := false) -> Node3D:
	var m := Node3D.new()
	var skin := skin_mat(Color(0.58, 0.44, 0.26))
	var rib := mat(Color(0.28, 0.19, 0.1), 0.9, 0.0, false)
	var blk := StandardMaterial3D.new()
	blk.albedo_color = Color.BLACK
	blk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blk.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var teeth := StandardMaterial3D.new()
	teeth.albedo_color = Color(0.85, 0.8, 0.65)
	teeth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	teeth.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	# torso pivot for organic breathing/sway animation
	var torso_piv := Node3D.new()
	torso_piv.name = "torso_piv"
	m.add_child(torso_piv)

	var chest := part(torso_piv, mk_cap(0.24, 1.0), Vector3(0, 2.45, 0), skin)
	chest.scale = Vector3(1.0, 1.0, 0.65)
	var belly := part(torso_piv, mk_sph(0.2), Vector3(0, 1.97, 0), skin)
	belly.scale = Vector3(1.1, 0.9, 0.7)
	var pelvis := part(m, mk_sph(0.22), Vector3(0, 1.8, 0), skin)
	pelvis.scale = Vector3(1.0, 0.7, 0.75)
	for i in 6:
		var r := part(torso_piv, mk_cap(0.02, 0.5 - i * 0.02), Vector3(0, 2.1 + i * 0.12, 0.15), rib)
		r.rotation_degrees.z = 90

	# animated legs with hip, knee, and foot pivots
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.17
		var hip := Node3D.new()
		hip.name = "leg_l" if sx < 0 else "leg_r"
		hip.position = Vector3(x, 1.72, 0)
		m.add_child(hip)
		part(hip, mk_cap(0.075, 0.82), Vector3(0, -0.37, 0), skin)

		var knee := Node3D.new()
		knee.name = "knee_l" if sx < 0 else "knee_r"
		knee.position = Vector3(0, -0.82, 0)
		hip.add_child(knee)
		part(knee, mk_sph(0.085), Vector3.ZERO, skin)
		part(knee, mk_cap(0.06, 0.82), Vector3(0, -0.42, 0), skin)
		var foot := part(knee, mk_sph(0.1), Vector3(0, -0.85, 0.12), skin)
		foot.scale = Vector3(0.9, 0.4, 2.4)
		for t in 3:
			part(knee, mk_sph(0.025), Vector3((t - 1) * 0.045, -0.87, 0.3), skin)

	# animated arms with shoulder, elbow, and hand pivots
	for sx in [-1.0, 1.0]:
		var ax: float = sx * 0.4
		var shoulder := Node3D.new()
		shoulder.name = "arm_l" if sx < 0 else "arm_r"
		shoulder.position = Vector3(ax * 0.9, 2.82, 0)
		torso_piv.add_child(shoulder)
		part(shoulder, mk_sph(0.1), Vector3.ZERO, skin)
		part(shoulder, mk_cap(0.05, 0.9), Vector3(ax * 0.1, -0.44, 0), skin)

		var elbow := Node3D.new()
		elbow.name = "elbow_l" if sx < 0 else "elbow_r"
		elbow.position = Vector3(ax * 0.1, -0.92, 0)
		shoulder.add_child(elbow)
		part(elbow, mk_sph(0.06), Vector3.ZERO, skin)
		var fr := 0.06 if sx < 0 else 0.045
		part(elbow, mk_cap(fr, 0.98), Vector3(0, -0.5, 0), skin)
		var hand := part(elbow, mk_sph(0.07), Vector3(0, -1.08, 0), skin)
		hand.scale = Vector3(0.8, 1.4, 0.5)
		for f in 4:
			part(elbow, mk_cap(0.012, 0.24), Vector3((f - 1.5) * 0.028, -1.24, 0), skin)

	# neck and tilted head
	var neck := part(torso_piv, mk_cap(0.05, 0.65), Vector3(-0.22, 3.05, 0), skin)
	neck.rotation.z = 1.06
	var hg := Node3D.new()
	hg.name = "head_piv"
	hg.position = Vector3(-0.5, 3.22, 0.02)
	hg.rotation.z = 1.15
	torso_piv.add_child(hg)
	var skull := part(hg, mk_sph(0.25), Vector3.ZERO, skin)
	skull.scale = Vector3(0.9, 1.15, 0.95)

	if smiley_face:
		attach_smiley_face(hg, 0.235, 0.24)
	else:
		for ex in [-0.1, 0.1
