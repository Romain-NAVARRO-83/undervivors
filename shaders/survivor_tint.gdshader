shader_type canvas_item;
// Teinte des planches de survivants (rendu 3D pré-calculé).
// TEXTURE  : rendu ombré ; peau, cheveux et vêtement y sont blancs.
// mask_tex : R = peau, V = cheveux, B = vêtement (0 ailleurs).
// Sans masque (planche définitive déjà en couleurs), rien n'est teinté.

uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap;
uniform vec4 skin_color : source_color = vec4(1.0);
uniform vec4 hair_color : source_color = vec4(1.0);
uniform vec4 shirt_color : source_color = vec4(1.0);
// Blessure : flash rouge (0 à 1).
uniform float flash = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 m = texture(mask_tex, UV).rgb;
	float rest = clamp(1.0 - m.r - m.g - m.b, 0.0, 1.0);
	vec3 tint = vec3(rest) + skin_color.rgb * m.r + hair_color.rgb * m.g + shirt_color.rgb * m.b;
	vec3 col = mix(base.rgb * tint, vec3(1.0, 0.3, 0.25), flash * 0.75);
	COLOR = vec4(col, base.a * COLOR.a);
}
