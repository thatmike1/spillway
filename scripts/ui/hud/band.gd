extends RefCounted
## the run band: the one row the eye reads during a run. it sits low centre, just under where the
## next landing usually appears (roughly 52 to 72 % of the height at running speed), so speed is
## read in peripheral vision without covering the deck ahead. speed is the centre; time sits on
## its left flank and style on its right, both aligned to the speed numeral's baseline. events
## (a split, a style callout) arrive just under their own flank and leave.

## the speed numeral's baseline as a share of the visible height.
const BASELINE := 0.82
## half the width reserved for the speed numeral, so the flanks never move as digits change.
const SPEED_HALF := 62.0
## gap between the reserved speed block and each flank.
const FLANK_GAP := 26.0
## the ink plate behind the band: its opacity and its padding around what it holds.
const PLATE_ALPHA := 0.5
const PLATE_PAD := Vector2(16.0, 8.0)
## how far below the baseline event rows (a split, a style callout) put their own baseline.
const EVENT_DROP := 30.0
## the floor for the band on short windows: keep it this far above the bottom edge.
const BOTTOM_MARGIN := 96.0

static func baseline(size: Vector2) -> float:
	return roundf(minf(size.y * BASELINE, size.y - BOTTOM_MARGIN))

static func centre(size: Vector2) -> float:
	return roundf(size.x * 0.5)

## the ascent of a label's current font at its current size: the distance from its top to its baseline.
static func ascent(label: Label) -> float:
	var face := label.get_theme_font("font")
	var px := label.get_theme_font_size("font_size")
	var top := 0.0
	var box := label.get_theme_stylebox("normal")
	if box != null:
		top = box.get_margin(SIDE_TOP)
	return top + face.get_ascent(px)

## place a label so its first baseline sits at `y`; `align` -1 puts its right edge at x, 0 centres
## it on x, 1 puts its left edge at x.
static func place(label: Label, x: float, y: float, align: int) -> void:
	label.reset_size()
	var w := label.get_minimum_size().x
	var left := x - w if align < 0 else (x - w * 0.5 if align == 0 else x)
	label.position = Vector2(roundf(left), roundf(y - ascent(label)))

## the left edge of the right flank and the right edge of the left flank.
static func left_flank(size: Vector2) -> float:
	return centre(size) - SPEED_HALF - FLANK_GAP

static func right_flank(size: Vector2) -> float:
	return centre(size) + SPEED_HALF + FLANK_GAP
