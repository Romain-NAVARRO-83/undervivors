extends SceneTree
## Générateur des planches de sprites des survivants (rendu 3D pré-calculé).
##
## Lancer (fenêtre requise, pas --headless) :
##   godot --path . --rendering-method gl_compatibility -s tools/bake_survivor_sprites.gd
##
## Pour chaque coiffure, deux PNG dans assets/survivors/ :
##   <coiffure>_shade.png : rendu ombré (peau, cheveux, vêtement en blanc)
##   <coiffure>_mask.png  : masque de teinte (R = peau, V = cheveux, B = vêtement)
## Planche : 7 colonnes (0 = repos, 1-6 = marche) × 8 lignes (directions :
## 0 = est, puis dans le sens horaire à l'écran : SE, S, SO, O, NO, N, NE).
## Images de FRAME_W × FRAME_H, pieds au point FEET.

const FRAME_W := 128
const FRAME_H := 160
const FEET := Vector2(64, 150)
const SUPERSAMPLE := 2
const COLS := 7          # repos + 6 images de marche
const DIRS := 8
const OUT_DIR := "res://assets/survivors/"
## Hauteur visible (unités 3D) d'une image : règle la taille du personnage.
const CAMERA_SIZE := 2.3
## Élévation de la caméra : 30° donne la projection iso 2:1 du sol.
const ELEVATION := deg_to_rad(30.0)

const STYLES := {
	SurvivorAppearance.HairStyle.CHAUVE: "chauve",
	SurvivorAppearance.HairStyle.COURT: "court",
	SurvivorAppearance.HairStyle.HERISSE: "herisse",
	SurvivorAppearance.HairStyle.LONG: "long",
	SurvivorAppearance.HairStyle.CHIGNON: "chignon",
}

var _vp: SubViewport
var _model_root: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_vp = SubViewport.new()
	_vp.size = Vector2i(FRAME_W, FRAME_H) * SUPERSAMPLE
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_setup_scene()
	await process_frame
	for style in STYLES:
		for pass_kind in [SurvivorModel.Pass.SHADE, SurvivorModel.Pass.MASK]:
			var sheet := Image.create(FRAME_W * COLS, FRAME_H * DIRS, false, Image.FORMAT_RGBA8)
			var model := SurvivorModel.new()
			model.hair_style = style
			model.render_pass = pass_kind
			_model_root.add_child(model)
			model.build()
			for d in DIRS:
				var phi := d * PI / 4.0
				model.face(Vector3(cos(phi), 0, sin(phi)))
				for c in COLS:
					model.set_pose((c - 1) / 6.0, c > 0)
					await process_frame
					await RenderingServer.frame_post_draw
					var img := _vp.get_texture().get_image()
					img.convert(Image.FORMAT_RGBA8)
					img.resize(FRAME_W, FRAME_H, Image.INTERPOLATE_CUBIC)
					sheet.blit_rect(img, Rect2i(0, 0, FRAME_W, FRAME_H), Vector2i(c * FRAME_W, d * FRAME_H))
			model.queue_free()
			await process_frame
			var name: String = STYLES[style] + ("_shade" if pass_kind == SurvivorModel.Pass.SHADE else "_mask")
			sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + name + ".png"))
			print("planche écrite : ", name)
	print("terminé")
	quit()


func _setup_scene() -> void:
	var scene := Node3D.new()
	_vp.add_child(scene)
	_model_root = Node3D.new()
	scene.add_child(_model_root)
	# Caméra orthographique : élévation 30°, axe X du monde = droite de l'écran,
	# +Z = bas de l'écran (comme l'axe y du jeu, écrasé de moitié).
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAMERA_SIZE
	cam.rotation.x = -ELEVATION
	var px_per_unit := float(FRAME_H) / CAMERA_SIZE
	var below_center := (FEET.y - FRAME_H / 2.0) / px_per_unit
	var screen_up := Vector3(0, cos(ELEVATION), -sin(ELEVATION))
	var target := screen_up * below_center
	cam.position = target + Vector3(0, sin(ELEVATION), cos(ELEVATION)) * 10.0
	cam.current = true
	scene.add_child(cam)
	# Lumière : soleil en haut à gauche, devant ; ambiance douce.
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-80), 0)
	sun.light_energy = 0.6
	scene.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
