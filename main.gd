extends Node3D
# DEATH - Godot 4.3. Everything is built in code so only a few files are needed.
const BALL_R := 0.45
var ball_vis: Node3D
var gas_k := 0.0
const TAPES := [
	"VERITY TOYS - TAPE 01\n\nWelcome to the Verity factory. Our little yellow friend smiles at every child.\n\nPlease. Do not wake the Tall One.",
	"VERITY TOYS - TAPE 02\n\nThe password was never hidden from the staff. We etched it on the prototype's arm, so the night shift would always remember.\n\nVERITY.",
	"VERITY TOYS - TAPE 03\n\nThe power failed and the Tall One woke up. Only the little one stayed kind.\n\nFind three fuses. Fix the power. And whatever you do, do not run in the dark.",
]
var tape_open := false
var tape_ui: ColorRect
var tape_lbl: Label
var tape_nodes: Array = []
var tape_done: Array = [false, false, false]
var fuse_nodes: Array = []
var fuse_has: Array = [false, false, false]
var fuse_in: Array = [false, false, false]
var fuse3_visible := false
var box_label: Label3D
var box_node: MeshInstance3D
var exit_door: StaticBody3D
var exit_open := false
var power_on := false
var hunter: Node3D
var hunter_legs: Array = []
var hunter_arms: Array = []
var hunter_col: CollisionShape3D
var hunter_chase := false
var hunter_wait := 0.0
var hunter_walk := 0.0
var caught := false
var end_ui: ColorRect
var caught_lbl: Label
var obj_lbl: Label
var clad_mesh: SphereMesh
var clad_material: StandardMaterial3D

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
var env: Environment
var gate: StaticBody3D
var gate_open := false
var has_key2 := false
var key2_node: Node3D
var key2_light: OmniLight3D
var key2_ready := false
var lead_path: Array = []
var lead_idx := 0
var leading := false
var stage := 0
var follower_legs: Array = []
var follower_arms: Array = []
var walk_t := 0.0
var gas_on := false
var gas_t := 0.0
var gas_rect: ColorRect
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
var iron_mat: StandardMaterial3D
var stone_albedo: ImageTexture
var stone_normal: ImageTexture
var clad_list: Array = []
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
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	get_viewport().scaling_3d_scale = 0.75
	gen_stone()
	make_env()
	make_materials()
	build_level()
	build_third_room()
	build_extras()
	build_clad_all()
	build_monster()
	make_follower()
	make_key2()
	make_player()
	setup_items()
	setup_items_extra()
	build_ui()
	play_title()


# ---------- materials ----------
func noise_tex(freq: float, normal: bool) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 256
	t.height = 256
	t.seamless = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	else:
		var g := Gradient.new()
		g.set_color(0, Color(0.4, 0.4, 0.4))
		g.set_color(1, Color.WHITE)
		t.color_ramp = g
	return t


func mat(col: Color, rough: float, metal: float, noisy: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if noisy:
		m.albedo_texture = noise_tex(0.03, false)
		m.normal_enabled = true
		m.normal_texture = noise_tex(0.08, true)
		m.normal_scale = 1.3
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.5
	return m


func skin_mat(col: Color) -> StandardMaterial3D:
	var m := mat(col, 0.8, 0.0, true)
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3.ONE * 3.0
	return m



func make_materials() -> void:
	floor_mat = stone_mat(Color(0.5, 0.5, 0.48), 0.85)
	wall_mat = stone_mat(Color(0.2, 0.19, 0.18), 0.9)
	metal_mat = mat(Color(0.35, 0.22, 0.14), 0.45, 0.7, true)
	haz_mat = mat(Color(0.8, 0.65, 0.0), 0.7, 0.0, true)
	dark_mat = mat(Color(0.06, 0.06, 0.06), 0.8, 0.2, false)
	iron_mat = mat(Color(0.12, 0.12, 0.13), 0.35, 0.9, true)


func make_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.2, 0.26)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.025)
	env.fog_density = 0.05
	env.glow_enabled = false
	env.glow_intensity = 0.7
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.85
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
	if solid and size.y >= 4.0:
		var oc := OccluderInstance3D.new()
		var bo := BoxOccluder3D.new()
		bo.size = size
		oc.occluder = bo
		b.add_child(oc)
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
	s.radial_segments = 16
	s.rings = 8
	return s


func mk_cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	c.radial_segments = 12
	c.rings = 4
	return c


func mk_box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func led(pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.07
	sp.height = 0.14
	var lm := StandardMaterial3D.new()
	lm.albedo_color = col
	lm.emission_enabled = true
	lm.emission = col
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
	l.position = pos
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 8.0
	add_child(l)
	if flicker:
		lamps.append({"l": l, "b": energy})
	return l


func pipe(pos: Vector3, length: float, r: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 10
	var mi := part(self, cm, pos, metal_mat)
	mi.rotation_degrees.x = 90


func sign3d(parent: Node3D, txt: String, pos: Vector3, rot_y: float, col: Color, fs: int) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font_size = fs
	l.pixel_size = 0.005
	l.modulate = col
	l.position = pos
	l.rotation_degrees.y = rot_y
	parent.add_child(l)
	return l


func add_cone(pos: Vector3) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 1.3
	cm.height = 4.6
	cm.radial_segments = 16
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 0.9, 0.65, 0.05)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	part(self, cm, pos, m)


func make_key() -> Node3D:
	var k := Node3D.new()
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1, 0.8, 0.2)
	gm.metallic = 1.0
	gm.roughness = 0.3
	gm.emission_enabled = true
	gm.emission = Color(0.5, 0.35, 0.0)
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
	box(Vector3(0, -0.1, -7.5), Vector3(44, 0.2, 45), floor_mat)
	box(Vector3(0, -0.1, -40), Vector3(12.4, 0.2, 20.4), floor_mat)
	box(Vector3(0, -0.1, -61), Vector3(10.4, 0.2, 22.4), floor_mat)
	box(Vector3(0, -0.1, -82), Vector3(18.4, 0.2, 20.4), floor_mat)
	box(Vector3(0, 5.1, -7.5), Vector3(44, 0.2, 45), wall_mat, false)
	box(Vector3(0, 8.1, -40), Vector3(12.4, 0.2, 20.4), wall_mat, false)
	box(Vector3(0, 5.1, -61), Vector3(10.4, 0.2, 22.4), wall_mat, false)
	box(Vector3(0, 5.1, -82), Vector3(18.4, 0.2, 20.4), wall_mat, false)
	# hall
	wall(-4, -1, 0.4, 14)
	wall(-4, -21, 0.4, 18)
	wall(4, -1, 0.4, 14)
	wall(4, -21, 0.4, 18)
	wall(-2.85, 6, 2.7, 0.4)
	wall(2.85, 6, 2.7, 0.4)
	wall(-2.75, -30, 2.5, 0.4)
	wall(2.75, -30, 2.5, 0.4)
	box(Vector3(0, 4.5, -30), Vector3(3, 1, 0.4), haz_mat, false)
	door = box(Vector3(0, 2, -30), Vector3(3, 4, 0.4), metal_mat)
	door_led = led(Vector3(0, 4.85, -29.7), Color(1, 0, 0))
	sign3d(door, "MAIN EXIT", Vector3(0, 1.2, 0.21), 0, Color(1, 0.1, 0.1), 40)
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
	for z in range(-2, -30, -4):
		pb(self, Vector3(8, 0.35, 0.35), Vector3(0, 4.75, z), metal_mat)
	for sx in [-1.0, 1.0]:
		pipe(Vector3(sx * 3.45, 3.7, -12), 36, 0.1)
	pipe(Vector3(3.4, 4.5, -12), 36, 0.18)
	box(Vector3(2.5, 0.6, -18), Vector3(1.2, 1.2, 1.2), metal_mat)
	box(Vector3(-2.6, 0.6, -25), Vector3(1.4, 1.2, 1.4), metal_mat)
	box(Vector3(-2.4, 3, -26), Vector3(1.6, 0.1, 6), metal_mat, false)
	for i in 5:
		pb(self, Vector3(0.04, 2.5, 0.04), Vector3(-1.5 + i * 0.8, 3.7, -9 - i * 3), metal_mat)
	sign3d(self, "CONTAINMENT", Vector3(3.48, 3.5, -10), -90, Color(1, 0.15, 0.1), 44)
	sign3d(self, "VAULT", Vector3(-3.48, 3.5, -10), 90, Color(1, 0.7, 0.2), 44)
	# right room: walls + glass
	wall(14, -10, 0.4, 12)
	wall(9, -4, 10, 0.4)
	wall(9, -16, 10, 0.4)
	var gl := StandardMaterial3D.new()
	gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gl.albedo_color = Color(0.5, 0.7, 0.6, 0.2)
	box(Vector3(9, 2, -15.7), Vector3(6, 4, 0.1), gl, false)
	# lights + fake light shafts
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1, 0.92, 0.7)
	for z in [-4, -12, -20, -27]:
		add_light(Color(1, 0.85, 0.63), 1.1, 14, Vector3(0, 4.6, z))
		pb(self, Vector3(1, 0.1, 0.3), Vector3(0, 4.9, z), lamp_mat)
		add_cone(Vector3(0, 2.4, z))
	add_light(Color(1, 0.13, 0), 1.4, 12, Vector3(9, 3.5, -10))
	add_light(Color(1, 0.6, 0), 0.8, 10, Vector3(12, 3, -14))



func make_crate(pos: Vector3) -> Dictionary:
	var root := StaticBody3D.new()
	root.position = pos
	add_child(root)
	var vis := Node3D.new()
	root.add_child(vis)
	var cm := mat(Color(0.3, 0.21, 0.13), 0.9, 0.0, true)
	pb(vis, Vector3(1.6, 0.1, 1.6), Vector3(0, 0.05, 0), cm)
	pb(vis, Vector3(1.6, 1.1, 0.1), Vector3(0, 0.65, 0.75), cm)
	pb(vis, Vector3(1.6, 1.1, 0.1), Vector3(0, 0.65, -0.75), cm)
	pb(vis, Vector3(0.1, 1.1, 1.4), Vector3(0.75, 0.65, 0), cm)
	pb(vis, Vector3(0.1, 1.1, 1.4), Vector3(-0.75, 0.65, 0), cm)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pb(vis, Vector3(0.14, 1.2, 0.14), Vector3(sx * 0.78, 0.65, sz * 0.78), metal_mat)
	var ll := Node3D.new()
	ll.position = Vector3(-0.85, 1.22, 0)
	vis.add_child(ll)
	pb(ll, Vector3(0.85, 0.1, 1.7), Vector3(0.425, 0, 0), cm)
	var lr := Node3D.new()
	lr.position = Vector3(0.85, 1.22, 0)
	vis.add_child(lr)
	pb(lr, Vector3(0.85, 0.1, 1.7), Vector3(-0.425, 0, 0), cm)
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(1.6, 1.3, 1.6)
	cs.shape = shp
	cs.position.y = 0.65
	cs.name = "col"
	root.add_child(cs)
	return {"root": root, "vis": vis, "lid_l": ll, "lid_r": lr}



func wall_h(x: float, z: float, w: float, d: float, h: float) -> StaticBody3D:
	return box(Vector3(x, h / 2.0, z), Vector3(w, h, d), wall_mat)


func build_third_room() -> void:
	wall_h(-5, -30, 2, 0.4, 8)
	wall_h(5, -30, 2, 0.4, 8)
	box(Vector3(0, 6.5, -30), Vector3(12.4, 3, 0.4), wall_mat, false)
	wall_h(-6, -40, 0.4, 20, 8)
	wall_h(6, -40, 0.4, 20, 8)
	add_light(Color(1, 0.8, 0.6), 0.8, 14, Vector3(0, 7.2, -36))
	add_light(Color(1, 0.8, 0.6), 0.7, 14, Vector3(0, 7.2, -46))
	for x in [-3.5, 0.0, 3.5]:
		crates.append(make_crate(Vector3(x, 0, -44)))
	hl_crate = crates[1]
	var pl := StandardMaterial3D.new()
	pl.albedo_color = Color(1, 0.05, 0.02)
	pl.emission_enabled = true
	pl.emission = Color(1, 0.05, 0.02)
	pl.emission_energy_multiplier = 2.0
	hl_plate = pb(hl_crate["vis"], Vector3(1.0, 0.03, 1.0), Vector3(0, 1.38, 0), pl)
	hl_plate.visible = false
	hl_spot = SpotLight3D.new()
	hl_spot.light_color = Color(1, 0.1, 0.05)
	hl_spot.light_energy = 3.0
	hl_spot.spot_range = 12.0
	hl_spot.spot_angle = 28.0
	hl_spot.position = Vector3(0, 7.7, -44)
	hl_spot.rotation_degrees.x = -90
	hl_spot.visible = false
	add_child(hl_spot)
	build_gate_and_gas()


func build_gate_and_gas() -> void:
	wall_h(-3.75, -50, 4.5, 0.4, 8)
	wall_h(3.75, -50, 4.5, 0.4, 8)
	box(Vector3(0, 6, -50), Vector3(3, 4, 0.4), wall_mat, false)
	var bar := StandardMaterial3D.new()
	bar.albedo_color = Color(0.8, 0.02, 0.02)
	bar.emission_enabled = true
	bar.emission = Color(1, 0.05, 0.05)
	bar.emission_energy_multiplier = 1.5
	pb(self, Vector3(3.4, 0.55, 0.1), Vector3(0, 4.45, -49.72), bar)
	sign3d(self, "CAUTION", Vector3(0, 4.45, -49.64), 0, Color.WHITE, 40)
	add_light(Color(1, 0.1, 0.05), 0.9, 7, Vector3(0, 4.0, -48.5))
	gate = StaticBody3D.new()
	gate.position = Vector3(0, 2, -50)
	add_child(gate)
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(3, 4, 0.3)
	cs.shape = shp
	cs.name = "col"
	gate.add_child(cs)
	for i in 17:
		pb(gate, Vector3(0.05, 4, 0.05), Vector3(-1.4 + i * 0.175, 0, 0), iron_mat)
	for gy in [-1.9, 0.0, 1.9]:
		pb(gate, Vector3(3, 0.14, 0.14), Vector3(0, gy, 0), iron_mat)
	pb(gate, Vector3(0.35, 0.5, 0.2), Vector3(0, -0.3, 0.12), iron_mat)
	# gas hall
	wall(-5, -61, 0.4, 22)
	wall(5, -61, 0.4, 22)
	add_light(Color(0.85, 0.9, 1.0), 0.8, 12, Vector3(0, 4.6, -56))
	add_light(Color(0.85, 0.9, 1.0), 0.6, 12, Vector3(0, 4.6, -65))
	# storage hall
	wall(-5.75, -72, 6.5, 0.4)
	wall(5.75, -72, 6.5, 0.4)
	wall(-9, -82, 0.4, 20.4)
	wall(9, -82, 0.4, 20.4)
	wall(0, -92, 18.4, 0.4)
	add_light(Color(1, 0.8, 0.6), 0.7, 14, Vector3(0, 4.6, -76))
	add_light(Color(1, 0.8, 0.6), 0.6, 14, Vector3(0, 4.6, -84))
	add_light(Color(1, 0.5, 0.3), 0.6, 12, Vector3(0, 4.0, -90))
	for p in [Vector3(-6, 0.6, -78), Vector3(-6, 0.6, -80.2), Vector3(6, 0.6, -81), Vector3(6, 0.6, -83.2), Vector3(-5, 0.6, -86)]:
		box(p, Vector3(1.2, 1.2, 1.2), metal_mat)
	box(Vector3(-8.2, 1.5, -84), Vector3(1.0, 3.0, 5.0), dark_mat)
	box(Vector3(8.2, 1.5, -76), Vector3(1.0, 3.0, 5.0), dark_mat)
	box(Vector3(0, 0.5, -89), Vector3(0.8, 1.0, 0.8), metal_mat)


# ---------- the Verity monster ----------

func make_verity() -> Node3D:
	var m := Node3D.new()
	var skin := skin_mat(Color(0.58, 0.44, 0.26))
	var rib := mat(Color(0.28, 0.19, 0.1), 1.0, 0.0, false)
	var blk := StandardMaterial3D.new()
	blk.albedo_color = Color.BLACK
	blk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var teeth := StandardMaterial3D.new()
	teeth.albedo_color = Color(0.85, 0.8, 0.65)
	teeth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var chest := part(m, mk_cap(0.24, 1.0), Vector3(0, 2.45, 0), skin)
	chest.scale = Vector3(1.0, 1.0, 0.65)
	var belly := part(m, mk_sph(0.2), Vector3(0, 1.97, 0), skin)
	belly.scale = Vector3(1.1, 0.9, 0.7)
	var pelvis := part(m, mk_sph(0.22), Vector3(0, 1.8, 0), skin)
	pelvis.scale = Vector3(1.0, 0.7, 0.75)
	for i in 6:
		var r := part(m, mk_cap(0.02, 0.5 - i * 0.02), Vector3(0, 2.1 + i * 0.12, 0.15), rib)
		r.rotation_degrees.z = 90
	var legs: Array = []
	for sx in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.17, 1.8, 0)
		m.add_child(hip)
		part(hip, mk_cap(0.075, 0.95), Vector3(0, -0.45, 0), skin)
		part(hip, mk_sph(0.085), Vector3(0, -0.9, 0), skin)
		part(hip, mk_cap(0.06, 0.92), Vector3(0, -1.35, 0), skin)
		var foot := part(hip, mk_sph(0.1), Vector3(0, -1.75, 0.12), skin)
		foot.scale = Vector3(0.9, 0.4, 2.4)
		for t in 3:
			part(hip, mk_sph(0.025), Vector3((t - 1) * 0.045, -1.77, 0.3), skin)
		legs.append(hip)
	var arms: Array = []
	for sx in [-1.0, 1.0]:
		var ax: float = sx * 0.4
		var sh := Node3D.new()
		sh.position = Vector3(ax, 2.85, 0)
		m.add_child(sh)
		part(m, mk_sph(0.1), Vector3(ax * 0.9, 2.82, 0), skin)
		part(sh, mk_cap(0.05, 0.95), Vector3(0, -0.47, 0), skin)
		part(sh, mk_sph(0.06), Vector3(0, -0.95, 0), skin)
		var fr := 0.06 if sx < 0 else 0.045
		part(sh, mk_cap(fr, 1.0), Vector3(0, -1.45, 0), skin)
		var hand := part(sh, mk_sph(0.07), Vector3(0, -2.03, 0), skin)
		hand.scale = Vector3(0.8, 1.4, 0.5)
		for f in 4:
			part(sh, mk_cap(0.012, 0.24), Vector3((f - 1.5) * 0.028, -2.19, 0), skin)
		if sx < 0:
			var lab := Label3D.new()
			lab.text = "VERITY"
			lab.font_size = 40
			lab.pixel_size = 0.0035
			lab.shaded = true
			lab.modulate = Color(0.22, 0.02, 0.0)
			lab.rotation_degrees.z = 90
			lab.position = Vector3(0, -1.45, 0.066)
			sh.add_child(lab)
		arms.append(sh)
	var neck := part(m, mk_cap(0.05, 0.65), Vector3(-0.22, 3.05, 0), skin)
	neck.rotation.z = 1.06
	var hg := Node3D.new()
	hg.position = Vector3(-0.5, 3.22, 0.02)
	hg.rotation.z = 1.15
	m.add_child(hg)
	var skull := part(hg, mk_sph(0.25), Vector3.ZERO, skin)
	skull.scale = Vector3(0.9, 1.15, 0.95)
	for ex in [-0.1, 0.1]:
		var eye := part(hg, mk_sph(0.06), Vector3(ex, 0.08, 0.2), blk)
		eye.scale = Vector3(1.0, 1.6, 0.6)
	part(hg, mk_box(Vector3(0.4, 0.05, 0.05)), Vector3(0, -0.13, 0.215), blk)
	for k in 9:
		part(hg, mk_box(Vector3(0.012, 0.08, 0.05)), Vector3(-0.16 + k * 0.04, -0.13, 0.222), teeth)
	m.set_meta("legs", legs)
	m.set_meta("arms", arms)
	return m


func build_monster() -> void:
	hunter = make_verity()
	hunter.position = Vector3(11, 0, -10)
	hunter.rotation_degrees.y = -90
	add_child(hunter)
	hunter_legs = hunter.get_meta("legs")
	hunter_arms = hunter.get_meta("arms")
	var sb := StaticBody3D.new()
	sb.position = Vector3(11, 1.8, -10)
	hunter_col = CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(0.8, 3.6, 0.9)
	hunter_col.shape = shp
	sb.add_child(hunter_col)
	add_child(sb)


func sph_point(lat: float, lon: float) -> Vector3:
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)) * BALL_R * 0.99


func make_follower() -> void:
	follower = Node3D.new()
	follower.visible = false
	follower.position = Vector3(0, -4, -44)
	add_child(follower)
	ball_vis = Node3D.new()
	ball_vis.position = Vector3(0, BALL_R, 0)
	follower.add_child(ball_vis)
	var ym := StandardMaterial3D.new()
	ym.albedo_color = Color(1.0, 0.82, 0.08)
	ym.roughness = 0.45
	ym.emission_enabled = true
	ym.emission = Color(0.4, 0.3, 0.0)
	part(ball_vis, mk_sph(BALL_R), Vector3.ZERO, ym)
	var blk := StandardMaterial3D.new()
	blk.albedo_color = Color.BLACK
	blk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-1.0, 1.0]:
		var e := part(ball_vis, mk_sph(BALL_R * 0.11), sph_point(0.3, sx * 0.3), blk)
		e.scale = Vector3(0.7, 1.5, 0.4)
	var prev := Vector3.ZERO
	for i in 25:
		var t := (i - 12) / 12.0
		var pt := sph_point(-0.5 + 0.38 * t * t, t * 0.85)
		part(ball_vis, mk_sph(BALL_R * 0.045), pt, blk)
		if i > 0:
			var dseg := pt - prev
			var seg := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = BALL_R * 0.045
			cyl.bottom_radius = BALL_R * 0.045
			cyl.height = dseg.length()
			cyl.radial_segments = 6
			seg.mesh = cyl
			seg.material_override = blk
			seg.transform = Transform3D(Basis(Quaternion(Vector3.UP, dseg.normalized())), (pt + prev) * 0.5)
			ball_vis.add_child(seg)
		prev = pt
	var gl := OmniLight3D.new()
	gl.light_color = Color(1, 0.85, 0.3)
	gl.light_energy = 0.8
	gl.omni_range = 6.0
	gl.position = Vector3(0, 0.8, 0)
	follower.add_child(gl)


func make_key2() -> void:
	key2_node = make_key()
	key2_node.position = Vector3(12.5, 0.12, -11.6)
	key2_node.rotation_degrees = Vector3(90, 0, 0)
	key2_node.visible = false
	add_child(key2_node)
	key2_light = add_light(Color(1, 0.8, 0.35), 0.8, 4, Vector3(12.5, 0.9, -11.6), false)
	key2_light.visible = false


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
	cam.far = 60
	player.add_child(cam)
	flash = SpotLight3D.new()
	flash.light_energy = 9.0
	flash.spot_range = 45
	flash.spot_angle = 42
	flash.spot_attenuation = 0.7
	flash.shadow_enabled = true
	cam.add_child(flash)
	var glow := OmniLight3D.new()
	glow.light_energy = 0.5
	glow.omni_range = 7.0
	flash.add_child(glow)


# ---------- interactions ----------

func setup_items() -> void:
	items = [
		{"node": term_node, "r": 2.8, "msg": "PASSWORD", "active": term_active, "run": open_kp},
		{"node": key_node, "r": 2.6, "msg": "PICK UP", "active": key_active, "run": take_key},
		{"node": door, "r": 3.4, "msg": "USE", "active": door_active, "run": use_door},
		{"node": key2_node, "r": 2.4, "msg": "PICK UP", "active": key2_active, "run": take_key2},
		{"node": gate, "r": 3.4, "msg": "USE", "active": gate_active, "run": use_gate},
	]
	for i in crates.size():
		var c: Dictionary = crates[i]
		if i == 1:
			items.append({"node": c["root"], "r": 2.6, "msg": "OPEN", "active": crate_active, "run": open_crate})
		else:
			items.append({"node": c["root"], "r": 2.4, "msg": "SEARCH", "active": empty_active, "run": (search_fuse if i == 0 else empty_crate)})


func key2_active() -> bool:
	return key2_ready and not has_key2

func gate_active() -> bool:
	return not gate_open


func take_key2() -> void:
	has_key2 = true
	key2_node.visible = false
	key2_light.visible = false
	inv_lbl.text = "KEYS: MASTER + IRON"
	toast("Iron key acquired. Verity starts walking...")
	lead_start([Vector3(12.4, 0, -7.2), Vector3(8.6, 0, -7.2), Vector3(7, 0, -10), Vector3(0, 0, -10), Vector3(0, 0, -28), Vector3(0, 0, -33), Vector3(0, 0, -47)], 3)


func use_gate() -> void:
	if not has_key2:
		toast("LOCKED. It needs the iron key.")
		return
	gate_open = true
	slide_up(gate, 3.0)
	toast("The iron gate opens...")
	var inner: Array = [Vector3(0, 0, -52), Vector3(0, 0, -62), Vector3(0, 0, -70)]
	if leading:
		lead_path.append_array(inner)
		stage = 5
	else:
		await get_tree().create_timer(2.5).timeout
		lead_start(inner, 5)


func term_active() -> bool:
	return not term_ok

func key_active() -> bool:
	return vault_open and not has_key

func door_active() -> bool:
	return not door_open

func crate_active() -> bool:
	return door_open and not crate_opened

func empty_active() -> bool:
	return door_open


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
	hl_plate.visible = true
	hl_spot.visible = true
	toast("The door grinds open...")


func empty_crate() -> void:
	toast("Empty.")


func slide_up(n: Node3D, t: float) -> void:
	var col := n.get_node_or_null("col") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)
	create_tween().tween_property(n, "position:y", n.position.y + 5.0, t)


func flash_red() -> void:
	red_rect.color.a = 0.55
	create_tween().tween_property(red_rect, "color:a", 0.0, 0.9)



func open_crate() -> void:
	crate_opened = true
	hl_spot.visible = false
	hl_plate.visible = false
	var root: Node3D = hl_crate["root"]
	var vis: Node3D = hl_crate["vis"]
	var ll: Node3D = hl_crate["lid_l"]
	var lr: Node3D = hl_crate["lid_r"]
	var tw := create_tween()
	for i in 10:
		tw.tween_property(vis, "rotation:z", 0.05 if i % 2 == 0 else -0.05, 0.06)
	tw.tween_property(vis, "rotation:z", 0.0, 0.05)
	await tw.finished
	shake = 1.0
	flash_red()
	follower.position = Vector3(root.position.x, -2.0, root.position.z)
	follower.visible = true
	var tl := create_tween().set_parallel(true)
	tl.tween_property(ll, "rotation:z", deg_to_rad(115.0), 0.5)
	tl.tween_property(lr, "rotation:z", deg_to_rad(-115.0), 0.5)
	await get_tree().create_timer(0.7).timeout
	var trise := create_tween()
	trise.tween_property(follower, "position:y", 2.2, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await trise.finished
	await get_tree().create_timer(0.3).timeout
	var cs := root.get_node_or_null("col") as CollisionShape3D
	if cs:
		cs.set_deferred("disabled", true)
	var tdis := create_tween()
	tdis.tween_property(vis, "scale", Vector3.ZERO, 0.6)
	await tdis.finished
	vis.visible = false
	var tfall := create_tween()
	tfall.tween_property(follower, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tfall.tween_property(follower, "position:y", 0.45, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tfall.tween_property(follower, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tfall.finished
	shake = 0.5
	await get_tree().create_timer(0.5).timeout
	lead_start([Vector3(0, 0, -41.8), Vector3(0, 0, -33), Vector3(0, 0, -28), Vector3(0, 0, -10), Vector3(7, 0, -10), Vector3(8.6, 0, -7.2), Vector3(12.4, 0, -7.2), Vector3(12.4, 0, -8.6)], 1)


func lead_start(path: Array, st: int) -> void:
	lead_path = path
	lead_idx = 0
	leading = true
	stage = st


func lead_update(delta: float) -> void:
	if not leading:
		return
	var tgt: Vector3 = lead_path[lead_idx]
	var cur := Vector3(follower.position.x, 0.0, follower.position.z)
	var dv := tgt - cur
	if dv.length() < 0.12:
		lead_idx += 1
		if lead_idx >= lead_path.size():
			leading = false
			lead_arrived()
		return
	var step := dv.normalized() * 2.4 * delta
	if step.length() > dv.length():
		step = dv
	follower.position += step
	roll_ball(step.normalized(), step.length())


func roll_ball(d: Vector3, dist: float) -> void:
	var axis := Vector3.UP.cross(d).normalized()
	ball_vis.transform.basis = (Basis(axis, dist / BALL_R) * ball_vis.transform.basis).orthonormalized()


func face_player(delta: float) -> void:
	var dirp := Vector3(player.position.x - follower.position.x, 0.0, player.position.z - follower.position.z)
	if dirp.length() < 0.1:
		return
	var target := Basis.looking_at(-dirp.normalized(), Vector3.UP)
	ball_vis.transform.basis = ball_vis.transform.basis.slerp(target, minf(1.0, delta * 3.0))


func lead_arrived() -> void:
	var th := create_tween()
	for i in 2:
		th.tween_property(follower, "position:y", 0.4, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		th.tween_property(follower, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if stage == 1:
		key2_node.visible = true
		key2_light.visible = true
		key2_ready = true
		toast("Verity points at something on the floor...")
		stage = 2
	elif stage == 3:
		toast("Verity waits at the iron gate.")
		stage = 4
	elif stage == 5:
		toast("Verity waits at the storage hall.")
		stage = 6


func gas_update(delta: float) -> void:
	var inside := gate_open and player.position.z < -50.6 and player.position.z > -72.0
	gas_k = move_toward(gas_k, 1.0 if inside else 0.0, delta * (0.3 if inside else 0.5))
	env.fog_density = lerpf(0.05, 0.22, gas_k)
	env.fog_light_color = Color(0.02, 0.02, 0.025).lerp(Color(0.85, 0.85, 0.88), gas_k)
	gas_rect.color.a = 0.1 * gas_k


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
	# post-processing: color grade, chromatic edge, vignette, film grain
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.25, 0.95, length(d) * 1.35);
	float g = fract(sin(dot(UV * vec2(1280.0, 720.0) + vec2(TIME * 60.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(mix(vec3(g), vec3(0.0), v), max(v * 0.8, 0.05));
}"""
	var post := ColorRect.new()
	post.size = vp
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psm := ShaderMaterial.new()
	psm.shader = sh
	post.material = psm
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
	obj_lbl = lbl(hud, "", 18, Color(0.7, 0.95, 0.7), Vector2(10, 38), 560)
	obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	red_rect = ColorRect.new()
	red_rect.color = Color(0.6, 0, 0, 0)
	red_rect.size = vp
	red_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(red_rect)
	gas_rect = ColorRect.new()
	gas_rect.color = Color(1, 1, 1, 0.0)
	gas_rect.size = vp
	gas_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(gas_rect)
	caught_lbl = lbl(ui, "CAUGHT", 130, Color(0.85, 0.05, 0.05), Vector2(0, vp.y * 0.3), vp.x)
	caught_lbl.visible = false
	tape_ui = fullscreen(Color(0, 0, 0, 0.92))
	tape_ui.visible = false
	tape_lbl = lbl(tape_ui, "", 28, Color(0.85, 0.85, 0.85), Vector2(vp.x * 0.15, vp.y * 0.15), vp.x * 0.7)
	tape_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tape_lbl.size = Vector2(vp.x * 0.7, vp.y * 0.55)
	var tclose := btn(tape_ui, "CLOSE", Vector2(200, 64), Vector2(vp.x / 2 - 100, vp.y * 0.78), 26)
	tclose.pressed.connect(close_tape)
	end_ui = fullscreen(Color.BLACK)
	end_ui.visible = false
	lbl(end_ui, "CHAPTER 1 COMPLETE", 80, Color(0.8, 0.05, 0.05), Vector2(0, vp.y * 0.25), vp.x)
	lbl(end_ui, "To be continued...", 36, Color(0.8, 0.8, 0.8), Vector2(0, vp.y * 0.5), vp.x)
	var again := btn(end_ui, "PLAY AGAIN", Vector2(260, 70), Vector2(vp.x / 2 - 130, vp.y * 0.7), 26)
	again.pressed.connect(restart)
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


func _input(e: InputEvent) -> void:
	if not started or kp_open or tape_open or caught or settings_ui.visible:
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
	if hl_spot.visible:
		hl_spot.light_energy = 3.0 + sin(Time.get_ticks_msec() / 180.0) * 1.5
	cam.h_offset = randf_range(-1.0, 1.0) * shake * 0.08
	cam.v_offset = randf_range(-1.0, 1.0) * shake * 0.08
	shake = maxf(0.0, shake - delta * 0.8)
	gas_update(delta)
	var ot := objective()
	if obj_lbl.text != ot:
		obj_lbl.text = ot



func _physics_process(delta: float) -> void:
	if not started or kp_open or tape_open or caught or settings_ui.visible:
		return
	lead_update(delta)
	hunter_update(delta)
	if stage > 0 and not leading and follower.visible:
		face_player(delta)
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


# ---------- stone relief ----------
func gen_stone() -> void:
	var sz := 128
	var cells := 6
	var pts: Array = []
	var shade: Array = []
	for cy in cells:
		for cx in cells:
			pts.append(Vector2((cx + randf() * 0.7 + 0.15) / cells, (cy + randf() * 0.7 + 0.15) / cells))
			shade.append(randf())
	var fn := FastNoiseLite.new()
	fn.frequency = 0.08
	fn.fractal_octaves = 4
	var img := Image.create(sz, sz, false, Image.FORMAT_RGB8)
	var hmap := Image.create(sz, sz, false, Image.FORMAT_L8)
	for y in sz:
		for x in sz:
			var p := Vector2((x + 0.5) / sz, (y + 0.5) / sz)
			var ix := int(p.x * cells)
			var iy := int(p.y * cells)
			var d1 := 9.0
			var d2 := 9.0
			var id := 0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := ix + ox
					var gy := iy + oy
					var wx := 0.0
					var wy := 0.0
					if gx < 0:
						wx = -1.0
					elif gx >= cells:
						wx = 1.0
					if gy < 0:
						wy = -1.0
					elif gy >= cells:
						wy = 1.0
					var k := posmod(gy, cells) * cells + posmod(gx, cells)
					var q: Vector2 = pts[k]
					var d := p.distance_to(Vector2(q.x + wx, q.y + wy))
					if d < d1:
						d2 = d1
						d1 = d
						id = k
					elif d < d2:
						d2 = d
			var edge := clampf((d2 - d1) * 30.0, 0.0, 1.0)
			var bevel := pow(edge, 0.6)
			var sh: float = shade[id]
			var nz := fn.get_noise_2d(x, y)
			var hgt := clampf(bevel * (0.65 + 0.3 * sh) + nz * 0.12, 0.0, 1.0)
			var c := (0.5 + 0.35 * sh) * (1.0 + nz * 0.45) * (0.2 + 0.8 * bevel)
			img.set_pixel(x, y, Color(c, c * 0.98, c * 0.94))
			hmap.set_pixel(x, y, Color(hgt, hgt, hgt))
	img.resize(256, 256, Image.INTERPOLATE_CUBIC)
	hmap.resize(256, 256, Image.INTERPOLATE_CUBIC)
	hmap.bump_map_to_normal_map(8.0)
	img.generate_mipmaps()
	stone_albedo = ImageTexture.create_from_image(img)
	stone_normal = ImageTexture.create_from_image(hmap)


func stone_mat(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.albedo_texture = stone_albedo
	m.normal_enabled = true
	m.normal_texture = stone_normal
	m.normal_scale = 2.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.7
	return m


func init_clad() -> void:
	clad_mesh = SphereMesh.new()
	clad_mesh.radius = 0.5
	clad_mesh.height = 1.0
	clad_mesh.radial_segments = 8
	clad_mesh.rings = 4
	clad_material = StandardMaterial3D.new()
	clad_material.vertex_color_use_as_albedo = true
	clad_material.albedo_texture = noise_tex(0.05, false)
	clad_material.normal_enabled = true
	clad_material.normal_texture = noise_tex(0.12, true)
	clad_material.normal_scale = 1.5
	clad_material.roughness = 0.9
	clad_material.uv1_triplanar = true
	clad_material.uv1_scale = Vector3.ONE * 2.0


func clad(origin: Vector3, u: Vector3, length: float, height: float) -> void:
	var lst: Array = []
	var v := Vector3.UP
	var n := u.cross(v)
	var y := 0.0
	while y < height - 0.05:
		var rh := minf(randf_range(0.38, 0.6), height - y)
		var x := -randf() * 0.4
		while x < length - 0.05:
			var w := randf_range(0.5, 0.95)
			var a := maxf(x, 0.0)
			var b := minf(x + w, length)
			if b - a > 0.15:
				var prot := randf_range(0.1, 0.24)
				var thick := 0.5
				var rot := Basis(n, randf_range(-0.2, 0.2))
				var uu := rot * u
				var vv := rot * v
				var bas := Basis(uu * (b - a - 0.04), vv * (rh - 0.04), n * thick)
				var pos := origin + u * ((a + b) * 0.5) + v * (y + rh * 0.5) + n * (prot - thick * 0.5)
				var c := randf_range(0.28, 0.52) * (0.7 + 0.3 * clampf((y + rh * 0.5) / 2.5, 0.0, 1.0))
				lst.append([Transform3D(bas, pos), Color(c, c * 0.96, c * 0.9)])
			x += w
		y += rh
	build_clad(lst)


func build_clad_all() -> void:
	init_clad()
	var pxn := Vector3(0, 0, -1)
	var nxn := Vector3(0, 0, 1)
	var pzn := Vector3(1, 0, 0)
	var nzn := Vector3(-1, 0, 0)
	# hall
	clad(Vector3(-3.8, 0, 5.8), pxn, 13.8, 4.0)
	clad(Vector3(-3.8, 0, -12), pxn, 18.0, 4.0)
	clad(Vector3(3.8, 0, -8), nxn, 13.8, 4.0)
	clad(Vector3(3.8, 0, -30), nxn, 18.0, 4.0)
	clad(Vector3(-4, 0, -29.8), pzn, 2.5, 4.0)
	clad(Vector3(1.5, 0, -29.8), pzn, 2.5, 4.0)
	clad(Vector3(4, 0, 5.8), nzn, 2.4, 4.0)
	# left room
	clad(Vector3(-13.8, 0, -4.2), pxn, 11.6, 4.0)
	clad(Vector3(-13.8, 0, -15.8), pzn, 9.6, 4.0)
	clad(Vector3(-4, 0, -4.2), nzn, 3.0, 4.0)
	clad(Vector3(-9.1, 0, -4.2), nzn, 4.7, 4.0)
	# right room
	clad(Vector3(13.8, 0, -15.8), nxn, 11.6, 4.0)
	clad(Vector3(4.2, 0, -15.8), pzn, 1.8, 4.0)
	clad(Vector3(12, 0, -15.8), pzn, 1.8, 4.0)
	clad(Vector3(13.8, 0, -4.2), nzn, 9.6, 4.0)
	# third room
	clad(Vector3(-5.8, 0, -30.2), pxn, 19.8, 4.0)
	clad(Vector3(5.8, 0, -50), nxn, 19.8, 4.0)
	clad(Vector3(-5.8, 0, -49.8), pzn, 4.3, 4.0)
	clad(Vector3(1.5, 0, -49.8), pzn, 4.3, 4.0)
	# gas hall
	clad(Vector3(-4.8, 0, -50.2), pxn, 21.6, 4.0)
	clad(Vector3(4.8, 0, -71.8), nxn, 21.6, 4.0)
	# storage hall
	clad(Vector3(-8.8, 0, -72.2), pxn, 19.6, 4.0)
	clad(Vector3(8.8, 0, -91.8), nxn, 19.6, 4.0)
	clad(Vector3(-8.8, 0, -91.8), pzn, 17.6, 4.0)
	clad(Vector3(-2.5, 0, -72.2), nzn, 6.3, 4.0)
	clad(Vector3(9, 0, -72.2), nzn, 6.3, 4.0)


func build_clad(lst: Array) -> void:
	if lst.is_empty():
		return
	var center := Vector3.ZERO
	for e in lst:
		center += (e[0] as Transform3D).origin
	center /= lst.size()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = clad_mesh
	mm.instance_count = lst.size()
	for i in lst.size():
		var xf: Transform3D = lst[i][0]
		xf.origin -= center
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, lst[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = clad_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 26.0
	mi.position = center
	add_child(mi)


# ---------- chapter content ----------
func make_fuse(col: Color) -> Node3D:
	var f := Node3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.05
	cm.height = 0.22
	var gm := StandardMaterial3D.new()
	gm.albedo_color = col
	gm.emission_enabled = true
	gm.emission = col
	gm.emission_energy_multiplier = 1.4
	part(f, cm, Vector3.ZERO, gm)
	add_child(f)
	return f


func make_tape(pos: Vector3) -> Node3D:
	var t := Node3D.new()
	t.position = pos
	add_child(t)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.05, 0.05, 0.06)
	var lab := StandardMaterial3D.new()
	lab.albedo_color = Color(0.9, 0.9, 0.85)
	lab.emission_enabled = true
	lab.emission = Color(0.3, 0.3, 0.25)
	pb(t, Vector3(0.36, 0.06, 0.22), Vector3.ZERO, tm)
	pb(t, Vector3(0.2, 0.062, 0.1), Vector3(0, 0.001, 0), lab)
	return t


func build_extras() -> void:
	# exit door and fuse box in the spawn hall
	exit_door = box(Vector3(0, 2, 5.65), Vector3(3, 4, 0.3), metal_mat)
	sign3d(exit_door, "EXIT", Vector3(0, 1.3, -0.17), 180, Color(0.2, 1, 0.4), 44)
	var out := StandardMaterial3D.new()
	out.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	out.albedo_color = Color(0.9, 0.95, 1.0)
	box(Vector3(0, 2, 6.7), Vector3(3.2, 4, 0.2), out, false)
	box_node = pb(self, Vector3(1.2, 1.4, 0.25), Vector3(-2.9, 1.5, 5.55), dark_mat)
	box_label = sign3d(box_node, "FUSES 0/3", Vector3(0, 0.35, -0.14), 180, Color(1, 0.8, 0.2), 36)
	# fuses
	var fblue := make_fuse(Color(0.2, 0.5, 1.0))
	var fyellow := make_fuse(Color(1.0, 0.85, 0.1))
	fblue.position = Vector3(0, 1.2, -89)
	fyellow.position = Vector3(12.6, 0.2, -13.4)
	fyellow.rotation_degrees.z = 90
	fyellow.visible = false
	fuse_nodes = [Node3D.new(), fblue, fyellow]
	# tapes
	tape_nodes = [make_tape(Vector3(2.5, 1.26, -18)), make_tape(Vector3(-12.5, 0.04, -6.5)), make_tape(Vector3(-7.0, 0.04, -90.0))]
	# wall posters
	sign3d(self, "VERITY TOYS", Vector3(-3.48, 2.4, -18), 90, Color(1, 0.8, 0.1), 40)
	sign3d(self, "SMILE FOR VERITY", Vector3(3.48, 2.4, -22), -90, Color(1, 0.8, 0.1), 32)
	sign3d(self, "DO NOT RUN", Vector3(-3.48, 2.2, -4), 90, Color(1, 0.2, 0.2), 32)
	sign3d(self, "STAFF ONLY", Vector3(3.48, 2.2, -26), -90, Color(0.9, 0.9, 0.9), 32)


func setup_items_extra() -> void:
	items.append({"node": box_node, "r": 2.6, "msg": "FUSE BOX", "active": box_active, "run": use_box})
	items.append({"node": exit_door, "r": 3.2, "msg": "EXIT", "active": exit_active, "run": use_exit})
	items.append({"node": fuse_nodes[1], "r": 2.4, "msg": "PICK UP", "active": fuse1_active, "run": take_fuse1})
	items.append({"node": fuse_nodes[2], "r": 2.4, "msg": "PICK UP", "active": fuse2_active, "run": take_fuse2})
	for i in 3:
		items.append({"node": tape_nodes[i], "r": 2.2, "msg": "PLAY TAPE", "active": tape_active.bind(i), "run": play_tape.bind(i)})


func box_active() -> bool:
	return not power_on

func exit_active() -> bool:
	return not exit_open

func fuse1_active() -> bool:
	return not (fuse_has[1] or fuse_in[1])

func fuse2_active() -> bool:
	return fuse3_visible and not (fuse_has[2] or fuse_in[2])

func tape_active(i: int) -> bool:
	return not tape_done[i]


func play_tape(i: int) -> void:
	tape_done[i] = true
	tape_nodes[i].visible = false
	tape_open = true
	tape_lbl.text = TAPES[i]
	tape_ui.visible = true


func close_tape() -> void:
	tape_open = false
	tape_ui.visible = false


func restart() -> void:
	get_tree().reload_current_scene()


func search_fuse() -> void:
	if fuse_has[0] or fuse_in[0]:
		toast("Empty.")
		return
	fuse_has[0] = true
	toast("You found a RED fuse.")


func take_fuse1() -> void:
	fuse_has[1] = true
	fuse_nodes[1].visible = false
	toast("You took the BLUE fuse.")


func take_fuse2() -> void:
	fuse_has[2] = true
	fuse_nodes[2].visible = false
	toast("YELLOW fuse. Something is awake...")
	hunter_col.set_deferred("disabled", true)
	hunter_chase = true
	hunter_wait = 1.5
	shake = 0.8
	flash_red()


func use_box() -> void:
	var added := 0
	for i in 3:
		if fuse_has[i] and not fuse_in[i]:
			fuse_in[i] = true
			fuse_has[i] = false
			added += 1
	var total := 0
	for i in 3:
		if fuse_in[i]:
			total += 1
	box_label.text = "FUSES %d/3" % total
	if added == 0:
		toast("The fuse box needs 3 fuses (%d/3)." % total)
		return
	if total >= 3:
		power_restore()
		return
	toast("Fuse inserted (%d/3)" % total)
	if fuse_in[0] and fuse_in[1] and not fuse3_visible:
		fuse3_visible = true
		fuse_nodes[2].visible = true
		toast("Fuse inserted. Something moved in the Verity room...")


func power_restore() -> void:
	power_on = true
	hunter_chase = false
	toast("POWER RESTORED. The Tall One falls still.")
	create_tween().tween_property(hunter, "rotation:x", 1.3, 1.5)
	for l in lamps:
		l["b"] = float(l["b"]) * 1.5


func use_exit() -> void:
	if not power_on:
		toast("No power. The exit is sealed.")
		return
	exit_open = true
	slide_up(exit_door, 2.0)
	toast("The way out opens...")
	await get_tree().create_timer(3.0).timeout
	end_ui.visible = true


func objective() -> String:
	var total := 0
	for i in 3:
		if fuse_in[i]:
			total += 1
	if power_on:
		return "Escape through the EXIT door."
	if hunter_chase:
		return "RUN to the fuse box!"
	if not term_ok:
		return "Find the vault password."
	if not has_key:
		return "Take the key from the vault."
	if not door_open:
		return "Unlock the main door."
	if not crate_opened:
		return "Open the glowing box."
	if not has_key2:
		return "Follow Verity."
	if not gate_open:
		return "Follow Verity to the iron gate."
	if fuse3_visible:
		return "Get the last fuse from the Verity room."
	return "Find the fuses. Put them in the fuse box (%d/3)." % total


# ---------- the Tall One ----------
func region_of(p: Vector3) -> int:
	if p.z < -30.2:
		return 3
	if p.x > 4.2 and p.z > -16.0 and p.z < -4.0:
		return 2
	if p.x < -4.2 and p.z > -16.0 and p.z < -4.0:
		return 1
	return 0


func hunter_goal() -> Vector3:
	var hp := hunter.position
	var pp := player.position
	var hr := region_of(hp)
	var pr := region_of(pp)
	if hr == pr:
		return Vector3(pp.x, 0.0, pp.z)
	if hr == 0:
		if pr == 1:
			if hp.x > -2.6 or absf(hp.z + 10.0) > 1.5:
				return Vector3(-3.0, 0.0, -10.0)
			return Vector3(-6.0, 0.0, -10.0)
		if pr == 2:
			if hp.x < 2.6 or absf(hp.z + 10.0) > 1.5:
				return Vector3(3.0, 0.0, -10.0)
			return Vector3(6.0, 0.0, -10.0)
		if absf(hp.x) > 1.0 and hp.z > -28.0:
			return Vector3(0.0, 0.0, -27.0)
		return Vector3(0.0, 0.0, -33.0)
	if hr == 1:
		if absf(hp.z + 10.0) > 1.5 and hp.x < -4.6:
			return Vector3(-6.0, 0.0, -10.0)
		return Vector3(-3.0, 0.0, -10.0)
	if hr == 2:
		if absf(hp.z + 10.0) > 1.5 and hp.x > 4.6:
			return Vector3(6.0, 0.0, -10.0)
		return Vector3(3.0, 0.0, -10.0)
	if absf(hp.x) > 1.0 and hp.z > -34.0:
		return Vector3(0.0, 0.0, -33.0)
	return Vector3(0.0, 0.0, -27.0)


func animate_hunter(moving: bool, delta: float) -> void:
	if moving:
		hunter_walk += delta * 6.0
	var s := sin(hunter_walk) if moving else 0.0
	var l0: Node3D = hunter_legs[0]
	var l1: Node3D = hunter_legs[1]
	var a0: Node3D = hunter_arms[0]
	var a1: Node3D = hunter_arms[1]
	l0.rotation.x = lerpf(l0.rotation.x, s * 0.6, 0.3)
	l1.rotation.x = lerpf(l1.rotation.x, -s * 0.6, 0.3)
	a0.rotation.x = lerpf(a0.rotation.x, -s * 0.3, 0.3)
	a1.rotation.x = lerpf(a1.rotation.x, s * 0.3, 0.3)


func hunter_update(delta: float) -> void:
	if not hunter_chase or caught:
		animate_hunter(false, delta)
		return
	if hunter_wait > 0.0:
		hunter_wait -= delta
		animate_hunter(false, delta)
		return
	var goal := hunter_goal()
	var cur := Vector3(hunter.position.x, 0.0, hunter.position.z)
	var dv := goal - cur
	if dv.length() > 0.05:
		hunter.position += dv.normalized() * 3.3 * delta
		hunter.rotation.y = lerp_angle(hunter.rotation.y, atan2(dv.x, dv.z), minf(1.0, delta * 8.0))
	animate_hunter(true, delta)
	var pd := Vector2(player.position.x - hunter.position.x, player.position.z - hunter.position.z).length()
	if pd < 1.0:
		get_caught()


func get_caught() -> void:
	if caught:
		return
	caught = true
	hunter_chase = false
	shake = 1.2
	red_rect.color.a = 0.9
	caught_lbl.visible = true
	await get_tree().create_timer(2.5).timeout
	caught_lbl.visible = false
	red_rect.color.a = 0.0
	player.position = Vector3(0, 0.05, 4)
	yaw = 0.0
	pitch = 0.0
	player.rotation.y = 0.0
	cam.rotation.x = 0.0
	hunter.position = Vector3(11, 0, -10)
	hunter.rotation = Vector3(0, deg_to_rad(-90.0), 0)
	hunter_col.set_deferred("disabled", false)
	fuse_has[2] = false
	fuse_nodes[2].visible = true
	caught = false
