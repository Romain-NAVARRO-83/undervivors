class_name SurvivorModel
extends Node3D
## Modèle 3D placeholder d'un survivant (low-poly cartoon), utilisé par le
## générateur de planches de sprites (tools/bake_survivor_sprites.gd).
## Proportions « chibi » : grosse tête, petit corps. Regarde vers -Z local.
##
## Deux modes de rendu :
## - SHADE : ombrage en aplats ; peau, cheveux et vêtement en blanc (teintés en
##   jeu), le reste avec ses couleurs fixes ; contour noir.
## - MASK : couleurs pures, sans lumière : peau = rouge, cheveux = vert,
##   vêtement = bleu, le reste noir. Sert à teinter au moment du jeu.

enum Pass { SHADE, MASK }
enum Part { SKIN, HAIR, SHIRT, PANTS, SHOES, EYES }

const PANTS := Color(0.27, 0.29, 0.36)
const SHOES := Color(0.22, 0.16, 0.11)
const EYES := Color(0.07, 0.05, 0.04)
const OUTLINE := 0.022

var hair_style: int = SurvivorAppearance.HairStyle.COURT
var render_pass: Pass = Pass.SHADE

var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _body: Node3D
var _mats := {}


func build() -> void:
	_body = Node3D.new()
	add_child(_body)
	# Jambes (pivot à la hanche) et chaussures
	_leg_l = _limb(_body, Vector3(-0.12, 0.62, 0), 0.105, 0.62, Part.PANTS)
	_leg_r = _limb(_body, Vector3(0.12, 0.62, 0), 0.105, 0.62, Part.PANTS)
	for leg in [_leg_l, _leg_r]:
		_box(leg, Vector3(0, -0.6, -0.05), Vector3(0.17, 0.11, 0.28), Part.SHOES)
	# Bassin
	_box(_body, Vector3(0, 0.67, 0), Vector3(0.42, 0.16, 0.26), Part.PANTS)
	# Torse (vêtement)
	var torso := _capsule(_body, Vector3(0, 0.98, 0), 0.22, 0.62, Part.SHIRT)
	torso.scale = Vector3(1.0, 1.0, 0.78)
	# Bras (pivot à l'épaule) : manche + main
	_arm_l = _limb(_body, Vector3(-0.3, 1.17, 0), 0.078, 0.5, Part.SHIRT)
	_arm_r = _limb(_body, Vector3(0.3, 1.17, 0), 0.078, 0.5, Part.SHIRT)
	for arm in [_arm_l, _arm_r]:
		_sphere(arm, Vector3(0, -0.5, 0), 0.085, Part.SKIN)
	# Cou et tête
	_cylinder(_body, Vector3(0, 1.27, 0), 0.08, 0.12, Part.SKIN)
	_sphere(_body, Vector3(0, 1.55, 0), 0.36, Part.SKIN)
	_sphere(_body, Vector3(0, 1.5, -0.35), 0.06, Part.SKIN)  # nez
	for x in [-0.13, 0.13]:
		_sphere(_body, Vector3(x, 1.6, -0.31), 0.055, Part.EYES, false)
	_build_hair()


func _build_hair() -> void:
	var hc := Vector3(0, 1.55, 0)
	match hair_style:
		SurvivorAppearance.HairStyle.CHAUVE:
			return
		SurvivorAppearance.HairStyle.COURT:
			_cap(hc, 0.385)
		SurvivorAppearance.HairStyle.HERISSE:
			_cap(hc, 0.375)
			for i in 7:
				var a := -1.2 + i * 0.4
				var cone := _cone(_body, hc + Vector3(sin(a) * 0.2, 0.3, 0.05 + cos(a * 2.0) * 0.08), 0.09, 0.22, Part.HAIR)
				cone.rotation = Vector3(0.35, 0, -a * 0.5)
		SurvivorAppearance.HairStyle.LONG:
			_cap(hc, 0.395)
			var back := _box(_body, hc + Vector3(0, -0.22, 0.24), Vector3(0.66, 0.62, 0.14), Part.HAIR)
			back.rotation.x = 0.12
		SurvivorAppearance.HairStyle.CHIGNON:
			_cap(hc, 0.385)
			_sphere(_body, hc + Vector3(0, 0.32, 0.18), 0.16, Part.HAIR)


## Calotte de cheveux : demi-sphère inclinée vers l'arrière (dégage le front).
func _cap(center: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r
	m.is_hemisphere = true
	m.radial_segments = 20
	m.rings = 8
	mi.mesh = m
	mi.position = center
	mi.rotation.x = 0.45
	mi.material_override = _material(Part.HAIR, true)
	_body.add_child(mi)


# --- Pose ---------------------------------------------------------------------

## Pose de marche : `t` de 0 à 1 sur un cycle (0 = repos si walking = false).
func set_pose(t: float, walking: bool) -> void:
	var swing := sin(t * TAU) if walking else 0.0
	_leg_l.rotation.x = swing * 0.55
	_leg_r.rotation.x = -swing * 0.55
	_arm_l.rotation.x = -swing * 0.5
	_arm_r.rotation.x = swing * 0.5
	_arm_l.rotation.z = -0.12
	_arm_r.rotation.z = 0.12
	_body.position.y = absf(cos(t * TAU)) * 0.05 if walking else 0.0


## Oriente le modèle vers une direction du sol (x, z).
func face(dir: Vector3) -> void:
	# Le modèle regarde vers -Z : rotation autour de Y qui amène -Z sur dir.
	rotation.y = atan2(-dir.x, -dir.z)


# --- Formes -------------------------------------------------------------------

func _limb(parent: Node3D, pivot: Vector3, r: float, length: float, part: Part) -> Node3D:
	var p := Node3D.new()
	p.position = pivot
	parent.add_child(p)
	_capsule(p, Vector3(0, -length / 2.0, 0), r, length, part)
	return p


func _capsule(parent: Node3D, pos: Vector3, r: float, h: float, part: Part) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 16
	m.rings = 6
	return _add(parent, m, pos, part)


func _sphere(parent: Node3D, pos: Vector3, r: float, part: Part, outlined := true) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 20
	m.rings = 10
	return _add(parent, m, pos, part, outlined)


func _box(parent: Node3D, pos: Vector3, size: Vector3, part: Part) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, pos, part)


func _cylinder(parent: Node3D, pos: Vector3, r: float, h: float, part: Part) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	return _add(parent, m, pos, part, false)


func _cone(parent: Node3D, pos: Vector3, r: float, h: float, part: Part) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 8
	return _add(parent, m, pos, part)


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, part: Part, outlined := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _material(part, outlined)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# --- Matériaux ----------------------------------------------------------------

func _material(part: Part, outlined: bool) -> Material:
	var key := "%d_%s" % [part, outlined]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	if render_pass == Pass.MASK:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = _mask_color(part)
	else:
		m.albedo_color = _shade_color(part)
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if part == Part.EYES:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if outlined:
		var o := StandardMaterial3D.new()
		o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		o.albedo_color = Color(0.05, 0.04, 0.035) if render_pass == Pass.SHADE else Color.BLACK
		o.cull_mode = BaseMaterial3D.CULL_FRONT
		o.grow = true
		o.grow_amount = OUTLINE
		m.next_pass = o
	_mats[key] = m
	return m


static func _mask_color(part: Part) -> Color:
	match part:
		Part.SKIN:
			return Color(1, 0, 0)
		Part.HAIR:
			return Color(0, 1, 0)
		Part.SHIRT:
			return Color(0, 0, 1)
	return Color.BLACK


static func _shade_color(part: Part) -> Color:
	match part:
		Part.PANTS:
			return PANTS
		Part.SHOES:
			return SHOES
		Part.EYES:
			return EYES
	return Color.WHITE  # teinté en jeu
