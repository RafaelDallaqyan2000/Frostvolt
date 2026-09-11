extends "res://scripts/interface.gd"
# Fortress screens on top of the classic interface styles: menu, HUD, build panel, pause and results.
const C = preload("res://scripts/fortress/config.gd")
const Art = preload("res://scripts/fortress/art.gd")
const Grid = preload("res://scripts/fortress/build_grid.gd")
const Card = preload("res://scripts/fortress/item_card.gd")
const DANGER = Color("ff7f8f")
const GOLD = Color("ffd88a")
var hud_root: Control
var panel_root: Control
var status_label: Label
var status_sub: Label
var hp_value: Label
var hp_meter: ProgressBar
var route_bar: Control
var boss_box: Control
var boss_caption: Label
var boss_meter: ProgressBar
var event_label: Label
var cards_row: HBoxContainer
var cards: Array = []
var built_for: Array = []
var rebuild_queued := false
var stop_label: Label
var tower_label: Label
var hint_label: Label
var skip_button: Button
var go_button: Button
var note := ""
var note_until := 0.0
var chips: Dictionary = {}
var kills_value: Label
var clock_caption: Label
var clock_value: Label
var armour_value: Label
var tip_label: Label
const TIPS = [
 "Криопушка замедляет, а Тесла бьёт замедленных на 30% сильнее.",
 "Верхние орудия раньше достают летящих Шершней.",
 "Панцирник гасит часть урона каждого попадания — тяжёлые залпы надёжнее.",
 "Дальность считается от ствола: Тесле нужен передний край башни."]

static func plural(n: int, one: String, few: String, many: String) -> String:
 if n % 10 == 1 and n % 100 != 11: return one
 if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14]: return few
 return many

func tower_summary() -> String:
 var blocks: int = game.grid.blocks.size()
 var guns: int = game.turrets.size()
 var floors: int = game.grid.height()
 return "%d %s  ·  %d %s  ·  %d %s" % [blocks, plural(blocks, "блок", "блока", "блоков"), guns, plural(guns, "орудие", "орудия", "орудий"), floors, plural(floors, "этаж", "этажа", "этажей")]

func _ready() -> void:
 super()
 theme.set_stylebox("disabled", "Button", box(Color("0d1722"), Color("1f2f3b"), 16))
 theme.set_color("font_disabled_color", "Button", Color("58707c"))

func clear_screen(dim: bool = false) -> void:
 super(dim)
 hud_root = null
 panel_root = null
 status_label = null
 status_sub = null
 hp_value = null
 hp_meter = null
 route_bar = null
 boss_box = null
 boss_caption = null
 boss_meter = null
 event_label = null
 cards_row = null
 stop_label = null
 tower_label = null
 hint_label = null
 skip_button = null
 go_button = null
 kills_value = null
 clock_caption = null
 clock_value = null
 armour_value = null
 tip_label = null
 chips.clear()
 cards.clear()
 built_for.clear()

# Bars without the button content margins, so their height is exactly the requested one.
func meter(color: Color, height: int = 10) -> ProgressBar:
 var bar := ProgressBar.new()
 bar.show_percentage = false
 bar.custom_minimum_size.y = height
 for part in [["background", Color("233345")], ["fill", color]]:
  var style := StyleBoxFlat.new()
  style.bg_color = part[1]
  style.set_corner_radius_all(5)
  bar.add_theme_stylebox_override(part[0], style)
 return bar

func strip(color: Color, top_edge: bool) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.border_color = Color(0.47, 0.94, 0.8, 0.25)
 if top_edge: style.border_width_top = 2
 else: style.border_width_bottom = 2
 return style

func show_menu() -> void:
 clear_screen()
 var header = column(12)
 header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 header.offset_top = 20
 surface.add_child(header)
 header.add_child(label("FROSTVOLT     /     ПРОТОКОЛ 02", 20, MINT))
 header.add_child(label("ПОСЛЕДНИЙ\nРЕАКТОР", 60))
 header.add_child(label("КОЧЕВОЙ БАСТИОН", 30, GOLD))
 header.add_child(wrapped("Соберите башню на ходу и довезите ядро через ледяную пустошь.", 24))
 var footer = column(12)
 footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
 surface.add_child(footer)
 var record_panel := PanelContainer.new()
 record_panel.add_theme_stylebox_override("panel", box(Color("101e2b"), Color("29404b")))
 footer.add_child(record_panel)
 var records = column(6)
 record_panel.add_child(records)
 records.add_child(label("ЛУЧШИЙ ПУТЬ  %d м      ПОБЕД  %d" % [game.data.best_distance, game.data.wins], 22))
 var fastest: int = game.data.fastest_win
 records.add_child(label("Быстрейшая победа  %02d:%02d" % [fastest / 60, fastest % 60] if fastest > 0 else "Носитель ещё не побеждён", 20, MINT))
 records.add_child(wrapped("Сборка на остановках  ·  3 участка и босс  ·  около 3 минут", 19))
 footer.add_child(button("В путь   →", game.start_run, true))
 var row := HBoxContainer.new()
 row.add_theme_constant_override("separation", 12)
 footer.add_child(row)
 var sound_button = button("Звук: " + ("вкл" if game.data.sound else "выкл"), game.toggle_sound)
 sound_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(sound_button)
 var classic = button("Прежний режим", game.open_classic)
 classic.tooltip_text = "Оборона арены — исходная версия «Последнего реактора»"
 classic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(classic)

# Health, route progress and pause; the boss bar has a reserved row so it never covers the battle.
func build_top() -> void:
 var back := Panel.new()
 back.mouse_filter = Control.MOUSE_FILTER_IGNORE
 back.add_theme_stylebox_override("panel", strip(Color(0.03, 0.065, 0.11, 0.95), false))
 back.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 back.offset_left = -safe.x
 back.offset_right = safe.z
 back.offset_top = -safe.y
 back.offset_bottom = C.HUD_HEIGHT
 surface.add_child(back)
 var top = column(12)
 top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 surface.add_child(top)
 hud_root = top
 var row := HBoxContainer.new()
 row.custom_minimum_size.y = 68
 top.add_child(row)
 var titles = column(0)
 titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 titles.alignment = BoxContainer.ALIGNMENT_CENTER
 row.add_child(titles)
 status_label = label("", 18, MINT)
 titles.add_child(status_label)
 status_sub = label("", 25)
 titles.add_child(status_sub)
 var pause = button("II", game.pause_run)
 pause.tooltip_text = "Пауза (P / Esc)"
 pause.custom_minimum_size = Vector2(76, 68)
 row.add_child(pause)
 var hp_row := HBoxContainer.new()
 top.add_child(hp_row)
 var caption = label("ПРОЧНОСТЬ БАСТИОНА", 18, MUTED)
 caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 hp_row.add_child(caption)
 hp_value = label("", 22)
 hp_row.add_child(hp_value)
 hp_meter = meter(MINT, 14)
 top.add_child(hp_meter)
 route_bar = Control.new()
 route_bar.custom_minimum_size.y = 40
 route_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
 route_bar.draw.connect(draw_route)
 top.add_child(route_bar)
 var slot := Control.new()
 slot.custom_minimum_size.y = 34
 slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
 top.add_child(slot)
 boss_box = column(4)
 boss_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
 slot.add_child(boss_box)
 boss_caption = label("НОСИТЕЛЬ", 17, Color("ff7fa0"))
 boss_box.add_child(boss_caption)
 boss_meter = meter(Color("ff628c"), 10)
 boss_box.add_child(boss_meter)
 event_label = label("", 19, MUTED)
 event_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 slot.add_child(event_label)

func draw_route() -> void:
 if not is_instance_valid(route_bar): return
 var font := route_bar.get_theme_default_font()
 var w: float = route_bar.size.x
 var end_x := w - 26.0
 var y := 32.0
 var progress: float = game.route.progress()
 route_bar.draw_string(font, Vector2(0, 14), "ПУТЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
 route_bar.draw_string(font, Vector2(0, 14), "%d / %d м" % [game.meters(), int(C.route_length() / C.UNITS_PER_METER)], HORIZONTAL_ALIGNMENT_RIGHT, w, 17, TEXT)
 route_bar.draw_line(Vector2(0, y), Vector2(end_x, y), Color("233345"), 6)
 route_bar.draw_line(Vector2(0, y), Vector2(end_x * progress, y), MINT, 6)
 for i in range(1, C.SEGMENTS.size()):
  var reached := progress >= float(i) / C.SEGMENTS.size() - 0.001
  route_bar.draw_circle(Vector2(end_x * i / C.SEGMENTS.size(), y), 7, MINT if reached else Color("3b5563"))
  route_bar.draw_circle(Vector2(end_x * i / C.SEGMENTS.size(), y), 3, PANEL)
 route_bar.draw_colored_polygon(Art.ring(Vector2(w - 11, y), 10, 10, 6, PI / 6), Color("ff507e") if game.route.is_boss() else Color("7a3448"))
 var at := Vector2(end_x * progress, y)
 route_bar.draw_rect(Rect2(at + Vector2(-9, -13), Vector2(18, 9)), TEXT)
 route_bar.draw_rect(Rect2(at + Vector2(-4, -19), Vector2(8, 6)), MINT)

func flash_note(text: String) -> void:
 note = text
 note_until = game.clock + 2.8

func update_hud() -> void:
 if not is_instance_valid(hp_value): return
 hp_value.text = "%d / %d" % [ceili(game.hp), int(game.max_hp)]
 hp_meter.max_value = game.max_hp
 hp_meter.value = game.hp
 hp_meter.modulate = Color(1, 0.55, 0.55) if game.hit_flash > 0 else Color.WHITE
 var building: bool = game.state == game.State.BUILD or (game.state == game.State.PAUSED and game.paused_from == game.State.BUILD)
 if building:
  if game.stop == 0: status_label.text = "ДЕПО  ·  ПОДГОТОВКА"
  elif game.stop == C.SEGMENTS.size(): status_label.text = "ОСТАНОВКА %d  ·  ПЕРЕД БОССОМ" % game.stop
  else: status_label.text = "ОСТАНОВКА %d / %d" % [game.stop, C.SEGMENTS.size()]
  status_sub.text = "Достройка  ·  бой заморожен"
 elif game.route.is_boss():
  status_label.text = "ПУТЬ ПЕРЕКРЫТ"
  status_sub.text = "Уничтожьте Носителя"
 else:
  status_label.text = "УЧАСТОК %d / %d" % [game.route.stage, C.SEGMENTS.size()]
  status_sub.text = "В пути  ·  остановка через %d с" % ceili(maxf(0, C.SEGMENT_SECONDS - game.route.clock))
 route_bar.queue_redraw()
 var boss_alive: bool = game.boss != null and game.boss.hp > 0
 boss_box.visible = boss_alive
 event_label.visible = not boss_alive
 if boss_alive:
  boss_meter.max_value = game.boss.max_hp
  boss_meter.value = game.boss.hp
  boss_caption.text = "НОСИТЕЛЬ  ·  ПРИЗЫВ ПОДКРЕПЛЕНИЯ!" if game.boss.warn > 0 else "НОСИТЕЛЬ  ·  %d / %d" % [ceili(game.boss.hp), int(game.boss.max_hp)]
 elif game.clock < note_until: event_label.text = note
 else: event_label.text = "Бастион: " + tower_summary()
 if is_instance_valid(kills_value): update_console()

func show_hud() -> void:
 clear_screen()
 build_top()
 build_console()
 update_hud()

func panel_back() -> void:
 var back := Panel.new()
 back.add_theme_stylebox_override("panel", strip(Color(0.035, 0.07, 0.115, 0.97), true))
 back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 back.offset_left = -safe.x
 back.offset_right = safe.z
 back.offset_top = -C.PANEL_HEIGHT
 back.offset_bottom = safe.w
 surface.add_child(back)

func tile(parent: Control, caption: String) -> Label:
 var panel := PanelContainer.new()
 var style := box(Color("101e2b"), Color("29404b"), 12)
 style.content_margin_top = 8
 style.content_margin_bottom = 8
 style.content_margin_left = 14
 panel.add_theme_stylebox_override("panel", style)
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(panel)
 var box_column = column(0)
 panel.add_child(box_column)
 var head = label(caption, 15, MUTED)
 box_column.add_child(head)
 var value = label("", 27)
 box_column.add_child(value)
 value.set_meta("caption", head)
 return value

# Below the road during combat: weapon states, counters and a tip. It never reaches the battle area.
func build_console() -> void:
 panel_back()
 var body = column(12)
 body.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 body.offset_top = -C.PANEL_HEIGHT + 14
 surface.add_child(body)
 panel_root = body
 body.add_child(label("БОЙ  ·  АВТОНАВЕДЕНИЕ КАЖДОГО СТВОЛА", 20, MINT))
 var row := HBoxContainer.new()
 row.add_theme_constant_override("separation", 12)
 body.add_child(row)
 for kind in ["mg", "cryo", "tesla"]:
  var chip := PanelContainer.new()
  var style := box(Color("132536"), Color("2d4854"), 12)
  style.content_margin_left = 8
  style.content_margin_right = 8
  style.content_margin_top = 6
  style.content_margin_bottom = 6
  chip.add_theme_stylebox_override("panel", style)
  chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(chip)
  var inner := HBoxContainer.new()
  inner.add_theme_constant_override("separation", 6)
  chip.add_child(inner)
  var icon := Control.new()
  icon.custom_minimum_size = Vector2(56, 60)
  icon.draw.connect(func(): Art.draw_weapon_icon(icon, kind, icon.size * 0.5, 62.0, game.clock))
  inner.add_child(icon)
  var words = column(0)
  words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  words.alignment = BoxContainer.ALIGNMENT_CENTER
  inner.add_child(words)
  var count = label("", 20)
  words.add_child(count)
  var status = label("", 15, MUTED)
  words.add_child(status)
  chips[kind] = {"root": chip, "icon": icon, "count": count, "status": status}
 var stats := HBoxContainer.new()
 stats.add_theme_constant_override("separation", 12)
 body.add_child(stats)
 kills_value = tile(stats, "УНИЧТОЖЕНО")
 clock_value = tile(stats, "ДО ОСТАНОВКИ")
 clock_caption = clock_value.get_meta("caption")
 armour_value = tile(stats, "ПРОЧНОСТЬ")
 tip_label = wrapped("", 19)
 tip_label.max_lines_visible = 2
 body.add_child(tip_label)

func update_console() -> void:
 kills_value.text = str(game.kills)
 if game.route.is_boss() and game.boss != null:
  clock_caption.text = "НОСИТЕЛЬ"
  clock_value.text = "%d%%" % ceili(100.0 * maxf(0, game.boss.hp) / game.boss.max_hp)
 else:
  clock_caption.text = "ДО ОСТАНОВКИ"
  clock_value.text = "%d с" % ceili(maxf(0, C.SEGMENT_SECONDS - game.route.clock))
 armour_value.text = "%d%%" % ceili(100.0 * game.hp / game.max_hp)
 armour_value.add_theme_color_override("font_color", DANGER if game.hp < game.max_hp * 0.3 else TEXT)
 for kind in chips:
  var count := 0
  var busy := false
  for turret in game.turrets:
   if turret.kind == kind:
    count += 1
    busy = busy or turret.has_target
  var chip: Dictionary = chips[kind]
  chip.count.text = "%s ×%d" % [C.WEAPONS[kind].name, count] if count > 0 else C.WEAPONS[kind].name
  chip.status.text = ("ведёт огонь" if busy else "нет цели в радиусе") if count > 0 else "не установлено"
  chip.status.add_theme_color_override("font_color", Color("8ff0b0") if busy else MUTED)
  chip.root.modulate.a = 1.0 if count > 0 else 0.45
  chip.icon.queue_redraw()
 tip_label.text = TIPS[int(game.clock / 7.0) % TIPS.size()]

func show_build() -> void:
 clear_screen()
 build_top()
 panel_back()
 var body = column(12)
 body.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 body.offset_top = -C.PANEL_HEIGHT + 14
 surface.add_child(body)
 panel_root = body
 var head := HBoxContainer.new()
 body.add_child(head)
 stop_label = label("НАГРАДЫ ОСТАНОВКИ", 20, MINT)
 stop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 head.add_child(stop_label)
 tower_label = label("", 18, MUTED)
 head.add_child(tower_label)
 cards_row = HBoxContainer.new()
 cards_row.add_theme_constant_override("separation", 14)
 cards_row.custom_minimum_size.y = 176
 body.add_child(cards_row)
 hint_label = wrapped("", 19)
 hint_label.custom_minimum_size.y = 54
 hint_label.max_lines_visible = 2
 body.add_child(hint_label)
 var buttons := HBoxContainer.new()
 buttons.add_theme_constant_override("separation", 14)
 body.add_child(buttons)
 skip_button = button("Пропустить", game.skip_rewards)
 skip_button.tooltip_text = "Переработать оставшиеся награды в ремонт"
 skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 buttons.add_child(skip_button)
 go_button = button("В путь   →", game.depart, true)
 go_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 go_button.add_theme_stylebox_override("disabled", box(Color("15303a"), Color("2d4854"), 14))
 go_button.add_theme_color_override("font_disabled_color", Color("5d7f86"))
 buttons.add_child(go_button)
 rebuild_cards()
 update_hud()

# Cards are rebuilt only when the inventory changes, and never inside a card's own input callback.
func refresh_build() -> void:
 if not is_instance_valid(cards_row): return
 if game.inventory == built_for:
  refresh_state()
 elif not rebuild_queued:
  rebuild_queued = true
  call_deferred("rebuild_cards")

func rebuild_cards() -> void:
 rebuild_queued = false
 if not is_instance_valid(cards_row): return
 for child in cards_row.get_children():
  cards_row.remove_child(child)
  child.queue_free()
 cards.clear()
 built_for = game.inventory.duplicate(true)
 for i in range(game.inventory.size()):
  var card = make_card(i, game.inventory[i])
  cards_row.add_child(card)
  cards.append(card)
 if game.inventory.is_empty():
  var done = wrapped("Награды этой остановки установлены. Бастион готов к пути.", 22, MINT)
  done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  cards_row.add_child(done)
 refresh_state()

func refresh_state() -> void:
 if not is_instance_valid(go_button): return
 var left: int = game.inventory.size()
 skip_button.disabled = left == 0
 skip_button.text = "Пропустить  (+%d)" % int(C.SKIP_REPAIR * left) if left > 0 else "Пропустить"
 go_button.disabled = left > 0
 tower_label.text = "блоков %d / %d" % [game.grid.blocks.size(), C.COLS * C.ROWS]
 for card in cards:
  if not is_instance_valid(card): continue
  var active: bool = (game.drag != null and game.drag.index == card.index) or (game.returning != null and game.returning.index == card.index)
  card.modulate.a = 0.35 if active else 1.0
 update_hint()

func make_card(index: int, item: Dictionary):
 var card = Card.new()
 card.game = game
 card.index = index
 card.item = item
 card.name = "Item_%d_%s" % [index, item.id]
 card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 card.mouse_default_cursor_shape = Control.CURSOR_DRAG
 var room: bool = game.has_room(item)
 var style := box(Color("132536"), Color("3d6d74") if room else Color("8a3a48"), 14)
 style.content_margin_left = 12
 style.content_margin_right = 12
 style.content_margin_top = 10
 style.content_margin_bottom = 10
 card.add_theme_stylebox_override("panel", style)
 var row := HBoxContainer.new()
 row.mouse_filter = Control.MOUSE_FILTER_IGNORE
 row.add_theme_constant_override("separation", 8)
 card.add_child(row)
 var icon := Control.new()
 icon.custom_minimum_size = Vector2(80, 88)
 icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
 icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 icon.draw.connect(draw_icon.bind(icon, item))
 row.add_child(icon)
 var text = column(3)
 text.mouse_filter = Control.MOUSE_FILTER_IGNORE
 text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(text)
 var weapon: bool = item.type == "weapon"
 var info: Dictionary = C.WEAPONS[item.id] if weapon else C.SHAPES[item.id]
 text.add_child(label("ОРУДИЕ" if weapon else "ДЕТАЛЬ  ·  %d кл." % info.cells.size(), 15, GOLD if weapon else MINT))
 text.add_child(label(info.name, 23))
 # Line limits keep every card, and so the whole panel, at a fixed height.
 var purpose = wrapped(info.text, 17)
 purpose.max_lines_visible = 2
 text.add_child(purpose)
 if weapon:
  var numbers = label("урон %d · дальн. %d" % [int(info.damage), int(info.range)], 15, MUTED)
  numbers.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  numbers.clip_text = true
  text.add_child(numbers)
 if not room: text.add_child(label("НЕТ МЕСТА", 16, DANGER))
 return card

func draw_icon(icon: Control, item: Dictionary) -> void:
 var center := icon.size * 0.5
 if item.type == "piece":
  var size := C.shape_size(item.id)
  Art.draw_piece_icon(icon, item.id, center, minf(40.0, 84.0 / maxi(size.x, size.y)))
 else:
  icon.draw_rect(Rect2(center - Vector2(36, 36), Vector2(72, 72)), Color(0.14, 0.24, 0.31, 0.6))
  Art.draw_weapon_icon(icon, item.id, center, 80.0, 0.0)

func card_center(index: int) -> Vector2:
 for card in cards:
  if is_instance_valid(card) and card.index == index: return card.get_global_rect().get_center()
 return Vector2(get_viewport_rect().size.x * 0.5, game.panel_top + 110)

func reason(fit: int) -> String:
 match fit:
  Grid.Fit.OUTSIDE: return "Нельзя: часть детали выходит за сетку 4×6."
  Grid.Fit.OVERLAP: return "Нельзя: эти клетки уже заняты конструкцией."
  Grid.Fit.LOOSE: return "Нельзя: нет опоры. Нужна общая сторона с шасси или блоком — угол не считается."
  Grid.Fit.NO_BLOCK: return "Нельзя: орудие ставится только на построенный блок."
  Grid.Fit.TAKEN: return "Нельзя: на этом блоке уже стоит орудие."
 return ""

func update_hint() -> void:
 if not is_instance_valid(hint_label): return
 var color := MUTED
 var text := ""
 if game.drag != null:
  var what: String = "орудие" if game.drag.item.type == "weapon" else "деталь"
  if not game.drag.near: text = "Ведите к сетке над шасси. Отпущенная вне сетки %s вернётся на панель." % what
  elif game.drag.fit == Grid.Fit.OK:
   color = Color("8ff0b0")
   text = "Можно: отпустите, и %s встанет в зелёные клетки." % what
  else:
   color = DANGER
   text = reason(game.drag.fit)
 elif game.inventory.is_empty(): text = "Всё установлено. Нажмите «В путь» — движение и бой продолжатся."
 else:
  for item in game.inventory:
   if not game.has_room(item):
    color = DANGER
    text = "Для «%s» нет места. «Пропустить» переработает награды в ремонт." % (C.WEAPONS[item.id].name if item.type == "weapon" else C.SHAPES[item.id].name)
    break
  if text.is_empty():
   if game.stop == 0: text = "Перетащите блок на сетку над шасси, затем поставьте орудие на свободный блок."
   else: text = "Деталь должна касаться стороной шасси или блока. Зелёный — можно, красный — нельзя."
 hint_label.text = text
 hint_label.add_theme_color_override("font_color", color)

func show_pause() -> void:
 var body = modal_column()
 body.add_child(label("БАСТИОН В ОЖИДАНИИ", 20, MINT))
 body.add_child(label("ПАУЗА", 58))
 body.add_child(wrapped("Движение, оружие, враги и все таймеры забега остановлены.", 25))
 body.add_child(button("Продолжить", game.resume_run, true))
 body.add_child(button("Начать заново", game.start_run))
 body.add_child(button("В меню", game.to_menu))
 body.add_child(wrapped("Конструкция забега при выходе не сохраняется, рекорды — сохраняются.", 21))

func show_result(won: bool) -> void:
 var body = modal_column()
 body.add_child(label("МАРШРУТ ЗАВЕРШЁН" if won else "СВЯЗЬ С БАСТИОНОМ ПОТЕРЯНА", 20, MINT if won else DANGER))
 body.add_child(label("ПУТЬ СВОБОДЕН" if won else "РЕАКТОР ПОТЕРЯН", 48))
 body.add_child(wrapped("Носитель уничтожен, ядро довезено до цели." if won else "Бастион не выдержал. Соберите башню иначе и попробуйте снова.", 25))
 var reached: String = "бой с боссом" if game.route.is_boss() else "участок %d / %d" % [maxi(1, game.route.stage), C.SEGMENTS.size()]
 body.add_child(label("Пройдено %d м  ·  %s" % [game.meters(), reached], 25))
 body.add_child(label("Уничтожено %d  ·  время %02d:%02d" % [game.kills, int(game.elapsed) / 60, int(game.elapsed) % 60], 25, MINT))
 body.add_child(wrapped("Башня: " + tower_summary(), 21))
 body.add_child(button("Ещё раз", game.start_run, true))
 body.add_child(button("В меню", game.to_menu))
