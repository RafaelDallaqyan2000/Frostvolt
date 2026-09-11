extends Control
const MINT = Color("8bf0c9")
const TEXT = Color("edf3e9")
const MUTED = Color("93a8b4")
const PANEL = Color("111f30")
var game
var surface: Control
var hp_label: Label
var hp_bar: ProgressBar
var wave_label: Label
var time_label: Label
var kills_label: Label
var loadout_label: Label
var boss_bar: ProgressBar
var boss_label: Label
var notice: Label
var safe := Vector4(28, 30, 28, 30)

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var ui_theme := Theme.new()
 ui_theme.default_font_size = 24
 ui_theme.set_color("font_color", "Label", TEXT)
 ui_theme.set_color("font_color", "Button", TEXT)
 ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
 ui_theme.set_color("font_pressed_color", "Button", Color.WHITE)
 ui_theme.set_constant("outline_size", "Label", 0)
 ui_theme.set_stylebox("normal", "Button", box(PANEL, Color("2d4854"), 16))
 ui_theme.set_stylebox("hover", "Button", box(Color("1b3342"), MINT, 16))
 ui_theme.set_stylebox("pressed", "Button", box(Color("265145"), MINT, 16))
 ui_theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), MINT, 16))
 theme = ui_theme

func box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.border_color = border
 style.set_border_width_all(1)
 style.set_corner_radius_all(radius)
 style.content_margin_left = 20
 style.content_margin_right = 20
 style.content_margin_top = 14
 style.content_margin_bottom = 14
 return style

func update_safe_area() -> void:
 size = get_viewport_rect().size
 safe = Vector4(28, 30, 28, 30)
 if OS.get_name() == "Android":
  var usable = DisplayServer.get_display_safe_area()
  var screen = DisplayServer.screen_get_size()
  var viewport = get_viewport_rect().size
  if screen.x > 0 and screen.y > 0 and usable.size.x > 0 and usable.size.y > 0:
   safe.x = maxf(28, usable.position.x * viewport.x / screen.x + 12)
   safe.y = maxf(30, usable.position.y * viewport.y / screen.y + 12)
   safe.z = maxf(28, (screen.x - usable.end.x) * viewport.x / screen.x + 12)
   safe.w = maxf(30, (screen.y - usable.end.y) * viewport.y / screen.y + 12)
 if is_instance_valid(surface): set_surface_margins()

func set_surface_margins() -> void:
 surface.offset_left = safe.x
 surface.offset_top = safe.y
 surface.offset_right = -safe.z
 surface.offset_bottom = -safe.w

func clear_screen(dim: bool = false) -> void:
 for child in get_children():
  remove_child(child)
  child.queue_free()
 hp_label = null
 hp_bar = null
 wave_label = null
 time_label = null
 kills_label = null
 loadout_label = null
 boss_bar = null
 boss_label = null
 notice = null
 if dim:
  var shade := ColorRect.new()
  shade.color = Color(0.015, 0.035, 0.065, 0.93)
  shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  add_child(shade)
 surface = Control.new()
 surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(surface)
 set_surface_margins()
 surface.modulate.a = 0
 create_tween().tween_property(surface, "modulate:a", 1.0, 0.2)

func label(text: String, font_size: int = 24, color: Color = TEXT) -> Label:
 var item := Label.new()
 item.text = text
 item.add_theme_font_size_override("font_size", font_size)
 item.add_theme_color_override("font_color", color)
 item.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return item

func wrapped(text: String, font_size: int = 24, color: Color = MUTED) -> Label:
 var item = label(text, font_size, color)
 item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 return item

func column(separation: int = 12) -> VBoxContainer:
 var col := VBoxContainer.new()
 col.add_theme_constant_override("separation", separation)
 return col

func button(text: String, action: Callable, primary: bool = false) -> Button:
 var item := Button.new()
 item.text = text
 item.custom_minimum_size.y = 78
 item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 item.add_theme_font_size_override("font_size", 27)
 if primary:
  item.add_theme_stylebox_override("normal", box(MINT, MINT, 14))
  item.add_theme_stylebox_override("hover", box(Color("b4ffdc"), Color.WHITE, 14))
  item.add_theme_stylebox_override("pressed", box(Color("60ba9e"), MINT, 14))
  item.add_theme_color_override("font_color", Color("10271f"))
  item.add_theme_color_override("font_hover_color", Color("10271f"))
  item.add_theme_color_override("font_pressed_color", Color("10271f"))
 item.pressed.connect(action)
 return item

func meter(color: Color, height: int = 10) -> ProgressBar:
 var bar := ProgressBar.new()
 bar.show_percentage = false
 bar.custom_minimum_size.y = height
 bar.add_theme_stylebox_override("background", box(Color("233345"), Color.TRANSPARENT, 5))
 bar.add_theme_stylebox_override("fill", box(color, Color.TRANSPARENT, 5))
 return bar

func show_menu() -> void:
 clear_screen()
 var header = column(16)
 header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 header.offset_top = 32
 surface.add_child(header)
 header.add_child(label("FROSTVOLT     /     ПРОТОКОЛ 01", 20, MINT))
 header.add_child(label("ПОСЛЕДНИЙ\nРЕАКТОР", 64))
 header.add_child(wrapped("Десять волн. Три орудия.\nСохраните последнее тепло.", 27))
 var caption = label("ЯДРО СТАБИЛЬНО  •  ОЖИДАНИЕ", 18, MINT)
 caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 caption.offset_left = -300
 caption.offset_right = 300
 caption.offset_top = 150
 surface.add_child(caption)
 var footer = column(14)
 footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
 surface.add_child(footer)
 var record_panel := PanelContainer.new()
 record_panel.add_theme_stylebox_override("panel", box(Color("101e2b"), Color("29404b")))
 footer.add_child(record_panel)
 var records = column(8)
 record_panel.add_child(records)
 records.add_child(label("РЕКОРД  /  ВОЛНА %02d      УБИЙСТВ %d" % [game.data.wave, game.data.kills], 22))
 records.add_child(label("Побед: %d" % game.data.wins, 21, MINT))
 var unlocked = "Криопушка" if game.data.cryo else "Крио — после волны 1"
 unlocked += "  ·  " + ("Тесла" if game.data.tesla else "Тесла — после волны 3")
 records.add_child(wrapped(unlocked, 20))
 footer.add_child(button("Играть   →", game.start_run, true))
 footer.add_child(button("Звук: " + ("включён" if game.data.sound else "выключен"), game.toggle_sound))
 footer.add_child(label("Автоматический бой  /  около 5 минут", 19, MUTED))

func show_hud() -> void:
 clear_screen()
 var top = column(12)
 top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 surface.add_child(top)
 var row := HBoxContainer.new()
 top.add_child(row)
 var title = label("ПОСЛЕДНИЙ РЕАКТОР", 22, MINT)
 title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(title)
 var pause = button("II", game.pause_run)
 pause.tooltip_text = "Пауза (P / Esc)"
 pause.custom_minimum_size = Vector2(76, 68)
 row.add_child(pause)
 var health_row := HBoxContainer.new()
 top.add_child(health_row)
 var reactor_label = label("ЦЕЛОСТНОСТЬ ЯДРА", 19, MUTED)
 reactor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 health_row.add_child(reactor_label)
 hp_label = label("", 23)
 health_row.add_child(hp_label)
 hp_bar = meter(MINT, 12)
 top.add_child(hp_bar)
 var stats := HBoxContainer.new()
 stats.add_theme_constant_override("separation", 16)
 top.add_child(stats)
 wave_label = label("", 26)
 wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 stats.add_child(wave_label)
 kills_label = label("", 22, MUTED)
 stats.add_child(kills_label)
 time_label = label("", 26, MINT)
 stats.add_child(time_label)
 boss_label = label("НОСИТЕЛЬ / ЯДРО УЛЬЯ", 18, Color("ff7fa0"))
 top.add_child(boss_label)
 boss_bar = meter(Color("ff628c"), 9)
 top.add_child(boss_bar)
 var footer = column(10)
 footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
 surface.add_child(footer)
 footer.add_child(label("ОРУДИЯ / АВТОМАТИЧЕСКАЯ НАВОДКА", 18, MUTED))
 loadout_label = wrapped("", 24, TEXT)
 footer.add_child(loadout_label)
 footer.add_child(wrapped("Крио + Тесла + Проводимость = +30% по замедленным", 19, MINT))
 notice = label("", 26, TEXT)
 notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 notice.offset_left = -330
 notice.offset_right = 330
 notice.offset_top = 125
 surface.add_child(notice)
 update_hud()

func update_hud() -> void:
 if not is_instance_valid(hp_label): return
 hp_label.text = "%d / %d" % [ceili(game.tower.hp), int(game.tower.max_hp)]
 hp_bar.max_value = game.tower.max_hp
 hp_bar.value = game.tower.hp
 wave_label.text = "ВОЛНА %02d / 10" % game.waves.number
 kills_label.text = "Убито %d" % game.kills
 time_label.text = "%02d с" % ceili(maxf(0, game.B.WAVE_SECONDS - game.waves.elapsed)) if game.waves.number < 10 else "БОСС"
 loadout_label.text = "Пулемёт" + ("   /   Крио %d" % game.tower.level("cryo") if game.tower.level("cryo") > 0 else "") + ("   /   Тесла %d" % game.tower.level("tesla") if game.tower.level("tesla") > 0 else "")
 boss_bar.visible = game.boss != null
 boss_label.visible = game.boss != null
 if game.boss != null:
  boss_bar.max_value = game.boss.max_hp
  boss_bar.value = maxf(0, game.boss.hp)

func announce(title: String, subtitle: String) -> void:
 if not is_instance_valid(notice): return
 notice.text = title + "\n" + subtitle
 notice.modulate.a = 0
 var tween = notice.create_tween()
 tween.tween_property(notice, "modulate:a", 1.0, 0.25)
 tween.tween_interval(1.6)
 tween.tween_property(notice, "modulate:a", 0.0, 0.7)

func modal_column() -> VBoxContainer:
 clear_screen(true)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 surface.add_child(scroll)
 var center_box := CenterContainer.new()
 center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.add_child(center_box)
 var body = column(18)
 body.custom_minimum_size.x = get_viewport_rect().size.x - safe.x - safe.z - 12
 center_box.add_child(body)
 return body

func show_upgrades(cards: Array, unlock: String) -> void:
 var body = modal_column()
 body.add_child(label("ВОЛНА %02d ЗАВЕРШЕНА" % game.waves.number, 21, MINT))
 body.add_child(label("СТАТЬ СИЛЬНЕЕ", 43))
 body.add_child(wrapped("Выберите одно улучшение. Бой продолжится после выбора.", 23))
 if not unlock.is_empty(): body.add_child(wrapped(unlock, 20, MINT))
 for id in cards:
  var data = game.Upgrades.CARDS[id]
  var card = button("", game.choose_upgrade.bind(id))
  card.name = "Card_" + id
  card.custom_minimum_size.y = 162
  body.add_child(card)
  var margin := MarginContainer.new()
  margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 22)
  for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 15)
  margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
  card.add_child(margin)
  var content = column(5)
  content.mouse_filter = Control.MOUSE_FILTER_IGNORE
  margin.add_child(content)
  var current: int = game.tower.level(id)
  var level_text = "УРОВЕНЬ %d → %d / %d" % [current, current + 1, data[2]]
  if id == "repair": level_text = "ПРИМЕНЕНИЕ %d → %d  /  ПОВТОРЯЕМОЕ" % [current, current + 1]
  content.add_child(label(level_text, 17, MINT))
  content.add_child(label(data[0], 28))
  var description: String = data[1]
  if id in ["cryo", "tesla"]: description = "Установить дополнительное орудие" if current == 0 else "+25% базового урона орудия"
  content.add_child(wrapped(description, 21))
 if cards.is_empty(): body.add_child(button("Следующая волна", game.next_wave, true))
 body.add_child(wrapped("Бой остановлен  /  выжившие враги остаются на арене", 19))

func show_pause() -> void:
 var body = modal_column()
 body.add_child(label("СИСТЕМА В ОЖИДАНИИ", 20, MINT))
 body.add_child(label("ПАУЗА", 58))
 body.add_child(wrapped("Движение, оружие и отсчёт времени остановлены.", 25))
 body.add_child(button("Продолжить", game.resume_run, true))
 body.add_child(button("В меню", game.to_menu))
 body.add_child(wrapped("При выходе улучшения этого забега сбросятся. Открытия и рекорды сохранятся.", 21))

func show_result(won: bool) -> void:
 var body = modal_column()
 body.add_child(label("ПРОТОКОЛ ОБОРОНЫ ЗАВЕРШЁН", 20, MINT))
 body.add_child(label("ПОБЕДА" if won else "ЯДРО ПОГАСЛО", 48))
 body.add_child(wrapped("Последнее тепло сохранено. Носитель уничтожен." if won else "Сигнал потерян. Новая попытка — новая конфигурация.", 26))
 body.add_child(label("Волна %d / 10   ·   Убийств %d" % [game.waves.number, game.kills], 27))
 body.add_child(label("Время боя  %02d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60], 25, MINT))
 body.add_child(label("Проводимость: %d усиленных попаданий" % game.conductive_hits, 21, MUTED))
 body.add_child(button("Ещё раз", game.start_run, true))
 body.add_child(button("В меню", game.to_menu))
