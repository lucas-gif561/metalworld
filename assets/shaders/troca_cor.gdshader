shader_type canvas_item;
// Recolore as roupas para diferenciar o jogador 2 sem mexer em pele e cabelo.
// - partes claras e sem cor (listras, camiseta) ficam com cor_destaque
// - azuis (calça jeans) giram o matiz por deslocamento_azul
// - outras cores fortes (ex.: cabelo rosa do sprite antigo) giram por deslocamento_outros

uniform vec4 cor_destaque : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float deslocamento_azul : hint_range(0.0, 1.0) = 0.42;
uniform float deslocamento_outros : hint_range(0.0, 1.0) = 0.35;

vec3 rgb_para_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_para_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	// No Godot 4, COLOR já chega multiplicado pela textura (e pelo modulate)
	vec4 original = COLOR;
	vec3 hsv = rgb_para_hsv(original.rgb);
	vec3 cor = original.rgb;

	bool tom_de_pele_ou_cabelo = hsv.x < 0.14 || hsv.x > 0.97;
	bool azul = hsv.x > 0.5 && hsv.x < 0.75 && hsv.y > 0.12 && hsv.z > 0.35;
	bool claro_sem_cor = hsv.y < 0.15 && hsv.z > 0.6;

	if (claro_sem_cor) {
		cor = cor_destaque.rgb * hsv.z;
	} else if (azul) {
		cor = hsv_para_rgb(vec3(fract(hsv.x + deslocamento_azul), min(hsv.y * 1.3, 1.0), hsv.z));
	} else if (hsv.y > 0.35 && hsv.z > 0.45 && !tom_de_pele_ou_cabelo) {
		cor = hsv_para_rgb(vec3(fract(hsv.x + deslocamento_outros), hsv.y, hsv.z));
	}

	COLOR = vec4(cor, original.a);
}
