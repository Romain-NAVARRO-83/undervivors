class_name ItemIcon
extends RefCounted
## Petites icônes d'objets dessinées en code (placeholders), partagées par
## l'interface : barre des stocks, sac du survivant.


## Icône d'une ressource du stock : "eau", "nourriture" ou "bois".
static func draw_resource(ci: CanvasItem, kind: String, c: Vector2, s := 1.0) -> void:
	match kind:
		"eau":
			# Goutte
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				pts.append(c + Vector2(cos(a) * 6.0, sin(a) * 6.0 + 2.0) * s)
			pts.append(c + Vector2(0, -9) * s)
			ci.draw_colored_polygon(pts, Color(0.35, 0.65, 0.95))
			ci.draw_circle(c + Vector2(-2, 1) * s, 1.6 * s, Color(1, 1, 1, 0.7))
		"nourriture":
			# Boîte de conserve
			ci.draw_rect(Rect2(c + Vector2(-6, -6) * s, Vector2(12, 12) * s), Color(0.72, 0.72, 0.75))
			ci.draw_rect(Rect2(c + Vector2(-6, -3) * s, Vector2(12, 6) * s), Color(0.85, 0.55, 0.3))
			ci.draw_rect(Rect2(c + Vector2(-6, -6) * s, Vector2(12, 12) * s), Color(0.25, 0.25, 0.27), false, 1.2)
		"bois":
			# Deux planches croisées
			for k in 2:
				var off := Vector2(0, -3 + k * 6) * s
				ci.draw_rect(Rect2(c + off + Vector2(-8, -2.5) * s, Vector2(16, 5) * s), Color(0.62, 0.44, 0.26))
				ci.draw_rect(Rect2(c + off + Vector2(-8, -2.5) * s, Vector2(16, 5) * s), Color(0.3, 0.2, 0.1), false, 1.0)


## Icône d'un objet du sac (eau, nourriture, planche, arme…).
static func draw_item(ci: CanvasItem, item: Resource, c: Vector2, s := 1.0) -> void:
	if item is ConsumableData:
		draw_resource(ci, item.resource_type, c, s)
		return
	if item is WeaponData:
		var col: Color = item.rarity_color()
		ci.draw_rect(Rect2(c + Vector2(-8, -3) * s, Vector2(14, 5) * s), Color(0.35, 0.35, 0.38))
		ci.draw_rect(Rect2(c + Vector2(-8, -1) * s, Vector2(5, 7) * s), col)
		ci.draw_rect(Rect2(c + Vector2(4, -4) * s, Vector2(4, 3) * s), item.projectile_color)
		return
	ci.draw_circle(c, 5.0 * s, Color(0.8, 0.8, 0.8))
