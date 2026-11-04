# scripts/ui/MainMenuBackdrop.gd
class_name MainMenuBackdrop
extends Node2D

## Procedural vector art background for «Шагающий дом» Main Menu.
## Renders snowy hills, distant polar mountains, and a warmly lit walking cabin.

var time: float = 0.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var vp_size = get_viewport_rect().size
	var w: float = vp_size.x if vp_size.x > 0.0 else 1280.0
	var h: float = vp_size.y if vp_size.y > 0.0 else 720.0
	
	# 1. Sky Gradient (Midnight Navy -> Polar Twilight)
	var sky_rect = Rect2(0, 0, w, h)
	draw_rect(sky_rect, Color(0.04, 0.06, 0.12, 1.0))
	var horizon_rect = Rect2(0, h * 0.45, w, h * 0.55)
	draw_rect(horizon_rect, Color(0.08, 0.13, 0.22, 0.75))
	
	# 2. Distant Jagged Mountains
	var mountain_pts = PackedVector2Array([
		Vector2(0, h * 0.65),
		Vector2(w * 0.15, h * 0.48),
		Vector2(w * 0.3, h * 0.58),
		Vector2(w * 0.45, h * 0.44),
		Vector2(w * 0.65, h * 0.55),
		Vector2(w * 0.8, h * 0.42),
		Vector2(w, h * 0.6),
		Vector2(w, h),
		Vector2(0, h)
	])
	draw_colored_polygon(mountain_pts, Color(0.12, 0.18, 0.28, 0.85))
	
	# 3. Snowy Dunes & Foreground
	var dune_pts = PackedVector2Array([
		Vector2(0, h * 0.72),
		Vector2(w * 0.25, h * 0.68),
		Vector2(w * 0.55, h * 0.74),
		Vector2(w * 0.85, h * 0.7),
		Vector2(w, h * 0.75),
		Vector2(w, h),
		Vector2(0, h)
	])
	draw_colored_polygon(dune_pts, Color(0.72, 0.8, 0.9, 1.0))
	
	# Foreground Snow Slope
	var fg_pts = PackedVector2Array([
		Vector2(0, h * 0.8),
		Vector2(w * 0.35, h * 0.78),
		Vector2(w * 0.7, h * 0.82),
		Vector2(w, h * 0.79),
		Vector2(w, h),
		Vector2(0, h)
	])
	draw_colored_polygon(fg_pts, Color(0.85, 0.92, 0.98, 1.0))
	
	# 4. Silhouetted Walking House on the Right
	var hx: float = w * 0.72
	var hy: float = h * 0.64
	_draw_house_silhouette(hx, hy)

func _draw_house_silhouette(x: float, y: float) -> void:
	# Mechanical Legs
	var leg_color = Color(0.16, 0.18, 0.22, 1.0)
	var joint_color = Color(0.28, 0.32, 0.38, 1.0)
	
	# Back Leg
	draw_line(Vector2(x - 30, y + 20), Vector2(x - 55, y + 65), leg_color, 7.0)
	draw_line(Vector2(x - 55, y + 65), Vector2(x - 45, y + 110), leg_color, 6.0)
	draw_circle(Vector2(x - 55, y + 65), 5.0, joint_color)
	draw_line(Vector2(x - 60, y + 110), Vector2(x - 30, y + 110), leg_color, 5.0) # foot
	
	# Front Leg
	draw_line(Vector2(x + 30, y + 20), Vector2(x + 50, y + 65), leg_color, 7.0)
	draw_line(Vector2(x + 50, y + 65), Vector2(x + 65, y + 112), leg_color, 6.0)
	draw_circle(Vector2(x + 50, y + 65), 5.0, joint_color)
	draw_line(Vector2(x + 50, y + 112), Vector2(x + 80, y + 112), leg_color, 5.0) # foot
	
	# Cabin Chassis & Platform
	draw_rect(Rect2(x - 65, y + 10, 130, 16), Color(0.2, 0.22, 0.26, 1.0))
	
	# Cabin Wooden Walls
	var cabin_color = Color(0.28, 0.22, 0.18, 1.0)
	draw_rect(Rect2(x - 60, y - 50, 120, 60), cabin_color)
	
	# Plank horizontal lines
	for i in range(4):
		var py = y - 50 + (i + 1) * 12
		draw_line(Vector2(x - 60, py), Vector2(x + 60, py), Color(0.18, 0.14, 0.12, 0.8), 1.5)
	
	# Triangular Gable Roof
	var roof_pts = PackedVector2Array([
		Vector2(x - 70, y - 50),
		Vector2(x, y - 85),
		Vector2(x + 70, y - 50)
	])
	draw_colored_polygon(roof_pts, Color(0.18, 0.2, 0.25, 1.0))
	
	# Snow cap on roof
	var snow_roof = PackedVector2Array([
		Vector2(x - 72, y - 50),
		Vector2(x, y - 88),
		Vector2(x + 72, y - 50),
		Vector2(x + 70, y - 46),
		Vector2(x, y - 82),
		Vector2(x - 70, y - 46)
	])
	draw_colored_polygon(snow_roof, Color(0.9, 0.95, 1.0, 1.0))
	
	# Chimney with puffing smoke
	draw_rect(Rect2(x + 35, y - 85, 12, 35), Color(0.22, 0.22, 0.25, 1.0))
	
	# Animated warm hearth glowing in the window
	var pulse: float = 0.85 + 0.15 * sin(time * 3.5)
	var window_glow = Color(1.0, 0.78, 0.32, pulse)
	draw_rect(Rect2(x - 25, y - 35, 26, 26), window_glow)
	draw_line(Vector2(x - 12, y - 35), Vector2(x - 12, y - 9), Color(0.2, 0.16, 0.12, 1.0), 2.0)
	draw_line(Vector2(x - 25, y - 22), Vector2(x + 1, y - 22), Color(0.2, 0.16, 0.12, 1.0), 2.0)
	
	# Outer glow aura around window
	draw_circle(Vector2(x - 12, y - 22), 36.0, Color(1.0, 0.75, 0.25, 0.18 * pulse))
