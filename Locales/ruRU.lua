local _, ns = ...
local locale = GetLocale()
if locale ~= "ruRU" then return end
local L = ns.L

L["tab.guide"] = "Гайд"
L["tab.enchants"] = "Чары"
L["tab.gems"] = "Камни"
L["tab.consumables"] = "Расходники"
L["tab.trinkets"] = "Аксессуары"
L["tab.gear"] = "Экипировка"
L["tab.bis_gear"] = "Лучшая экипировка"
L["tab.best_in_slot"] = "Лучшая экипировка"
L["bis.help.intro"] =
    "Рекомендуемая экипировка для каждого слота. Используйте список источников для сравнения гайдов."
L["bis.help.ugg"] =
    "U.GG показывает экипировку, которую топовые игроки реально используют в эпохальных+ и рейде в этом сезоне — на основе популярности, а не кураторский список Best in Slot."
L["bis.help.ugg_mplus"] = "Данные эпохального+ взяты из высоких ключей."
L["tab.enhancements"] = "Улучшения"
L["talent_pane.view_talents"] = "Просмотр талантов"
L["talent_pane.save_as.tooltip"] = "Сохранить как новую раскладку"
L["talent_pane.auto_recommend"] = "Auto-pick recommended"
L["talent_pane.difficulty"] = "Difficulty"
L["talent_pane.recommended"] = "Recommended"
L["talent_pane.build_options"] = "Build options"
L["talent_pane.save_as.prompt"] = "Имя раскладки:"
L["talent_pane.save_as.confirm"] = "Сохранить"

L["section.stat_priority"] = "Приоритет характеристик"
L["section.talents"] = "Таланты"
L["section.rotation"] = "Ротация"
L["section.omnium"] = "Omnium Folio"
L["omnium.week"] = "Неделя %d"

L["title_bar.menu_hint"] = "Закрепление, размер и отображение"
L["title_bar.open_settings"] = "Open settings"
L["title_bar.menu.dock"] = "Закрепить на панели персонажа"
L["title_bar.menu.float"] = "Открепить (плавающий)"
L["title_bar.menu.width"] = "Ширина"
L["title_bar.menu.width_narrow"] = "Узкая"
L["title_bar.menu.width_default"] = "Стандартная"
L["title_bar.menu.width_wide"] = "Широкая"
L["title_bar.menu.width_extra_wide"] = "Очень широкая"
L["title_bar.menu.sections"] = "Разделы"
L["title_bar.menu.all_settings"] = "Все настройки…"

L["context.raid"] = "Рейд"
L["context.dungeon"] = "Подземелье"
L["context.delves"] = "Вылазки"
L["context.crafting"] = "Крафт"
L["context.overall"] = "Общее"
L["context.label"] = "Контент"

L["tooltip.bis_header"] = "Лучшая экипировка"
L["tooltip.source"] = "Источник"
L["tooltip.popularity"] = "Популярность"

L["context.mythic_plus"] = "Эпохальный+"

L["consumable.flask"] = "Настой"
L["consumable.combat_potion"] = "Боевое зелье"
L["consumable.food"] = "Еда"
L["consumable.weapon_buff"] = "Усиление оружия"
L["consumable.augment_rune"] = "Руна усиления"

L["gem.primary"] = "Основной"
L["gem.secondary"] = "Вторичный"

L["talent.build"] = "Билд"

L["empty.select_class_spec"] = "Выберите класс и специализацию выше."
L["empty.no_data"] = "Нет данных для этой специализации."
L["empty.no_spec"] = "Выберите специализацию, чтобы открыть Bread Codex."
L["empty.spec_leveling"] = "Гайд по прокачке (%s)"
L["empty.no_builds_details"] = "Нет доступных билдов — подробности на U.GG."
L["empty.no_builds_for"] = "Нет билдов для %s — см. U.GG."
L["empty.no_rotation_for_details"] = "Нет ротации для %s — подробности на U.GG."
L["empty.no_rotation_available"] =
    "Ротация скоро появится.\nУ нас её пока нет для этой специализации."
L["empty.no_pvp_guide"] =
    "PvP-гайд скоро появится.\nДля этой специализации его пока нет."
L["empty.no_stat_targets"] =
    "Целевые показатели характеристик скоро появятся.\nДля этой специализации пока недостаточно данных в этом сезоне."

L["settings.description"] =
    "Best in slot gear, trinkets, enchants, gems, talents, stat priorities, rotation and crafting for your spec, pulled straight from Icy Veins and U.GG into the game."
L["settings.help_hint"] = "Введите /cc help, чтобы увидеть список команд."
L["attribution.copy_url"] = "Нажмите, чтобы скопировать ссылку"
L["attribution.visit_source"] = "Открыть источник: %s"
L["attribution.page_title"] = "%s %s Page"
L["attribution.visit_cta"] = "Открыть"
L["settings.role.patreon"] = "Поддержать аддон"
L["settings.role.discord"] = "Баги, отзывы и помощь"
L["settings.source_role.icyveins"] = "Авторские гайды"
L["settings.source_role.ugg"] = "Мета на основе данных"
L["settings.champions"] = "Чемпионы"
L["settings.supporters"] = "Поддержка"
L["compendium.open_settings"] = "Открыть настройки"

L["settings.label.stat_priority_on_tooltips"] = "Приоритет характеристик в подсказках"

L["settings.header.tooltips"] = "Подсказки"
L["settings.header.general"] = "Общие"
L["settings.label.float_auto_height"] = "Auto-size to content"
L["settings.tooltip.float_auto_height"] =
    "Grow the floating panel to fit its content instead of paging within a fixed height."
L["settings.label.float_height"] = "Floating panel height"
L["settings.label.float_max_height"] = "Max height"
L["settings.tooltip.float_max_height"] = "The tallest the floating panel can grow; taller content scrolls."
L["settings.tooltip.float_height"] = "Height of the floating panel when auto-size is off."
L["settings.header.floating_panel"] = "Плавающая панель"
L["settings.header.docked_panel"] = "Закреплённая панель"
L["settings.subcat.panels"] = "Панели"
L["settings.subcat.compendium"] = "Compendium"
L["settings.subcat.tabs"] = "Tabs"
L["settings.label.floating_mode"] = "Floating panel"
L["settings.tooltip.floating_mode"] = "Detach the panel from the character pane so you can move it anywhere on screen."
L["settings.tooltip.comp_show_tab"] = "Show this tab in the Compendium."
L["settings.header.dock_behavior"] = "Behavior"
L["settings.header.dock_display"] = "Display"
L["settings.header.dock_appearance"] = "Appearance"
L["settings.header.tab_order"] = "Order"
L["settings.label.reorder_tabs"] = "Reorder tabs"
L["settings.value.reorder"] = "Reorder"
L["settings.tooltip.reorder_tabs"] = "Drag the side tabs to rearrange them. Opens your panel and closes this window."
L["settings.label.reset_tabs"] = "Reset tab order"
L["settings.value.reset"] = "Reset"
L["settings.tooltip.reset_tabs"] = "Restore the default tab order."
L["settings.tooltip.dock_show_omnium"] = "Show or hide the Omnium Folio in the docked panel."
L["settings.tooltip.float_show_omnium"] = "Show or hide the Omnium Folio in the floating panel."
L["settings.header.panel"] = "Панель"

L["settings.label.stat_priority_ranks"] = "Ранги приоритета характеристик"
L["settings.label.ugg_bis"] = "Инфо BiS U.GG в подсказках"
L["settings.label.icy_veins_bis"] = "Инфо BiS Icy Veins в подсказках"
L["settings.label.trinket_tier"] = "Уровень аксессуаров в подсказках"
L["settings.label.bis_scope"] = "Охват BiS в подсказках"
L["settings.label.highlight_owned"] = "Выделять имеющееся снаряжение"
L["settings.label.page_hard_stops"] = "Hard section boundaries"
L["settings.tooltip.page_hard_stops"] =
    "Lock scrolling to the current section — the mouse wheel stops at each section instead of sliding into the next. Use the side tabs to change sections."
L["settings.label.panel_width"] = "Ширина панели"
L["settings.tooltip.panel_width"] =
    "Ширина панели Bread Codex в пикселях. Применяется к закреплённому и плавающему режимам."
L["settings.label.gear_source"] = "Показывать источник предмета"
L["settings.hint.gear_source_no_icons"] = "Отображается в режимах таблицы и списка."
L["settings.tooltip.gear_source"] =
    "Показывает, откуда берется каждый рекомендуемый предмет — место добычи или изготовление. Под названием предмета в режиме списка и отдельным столбцом в режиме таблицы. В режиме значков информация остается в подсказке предмета. Каждая панель запоминает выбор отдельно. Только для данных Icy Veins."
L["settings.hint.gear_source_no_icons"] = "Отображается в режимах таблицы и списка."
L["settings.label.minimap_button"] = "Кнопка на миникарте"
L["settings.label.login_message"] = "Сообщение при входе"
L["settings.label.pin_talent_source"] = "Закрепить источник талантов"
L["settings.label.show_stat_priority"] = "Показать приоритет характеристик"
L["settings.label.show_talents"] = "Показать таланты"
L["settings.label.show_rotation"] = "Показать ротацию"
L["settings.label.show_enchants"] = "Показать чары"
L["settings.label.show_gems"] = "Показать камни"
L["settings.label.show_consumables"] = "Показать расходники"
L["settings.label.show_trinkets"] = "Показать аксессуары"
L["settings.label.show_crafts"] = "Показать крафт"
L["settings.label.show_embellishments"] = "Показывать украшения"
L["settings.tooltip.dock_show_embellishments"] =
    "Показывать раздел «Украшения», когда панель закреплена."
L["settings.tooltip.float_show_embellishments"] =
    "Показывать раздел «Украшения», когда панель плавающая."
L["settings.label.show_bis_gear"] = "Показать лучшую экипировку"

L["settings.tooltip.stat_priority_ranks"] =
    "Показывает ранг приоритета (#1, #2, #3) рядом с названиями характеристик в подсказках предметов."
L["settings.tooltip.ugg_bis"] =
    "Показывает, для каких специализаций предмет является лучшим в слоте (U.GG)."
L["settings.tooltip.icy_veins_bis"] =
    "Показывает, для каких специализаций предмет является лучшим в слоте (Icy Veins)."
L["settings.tooltip.trinket_tier"] =
    "Показывает ранг и значок уровня аксессуаров в подсказках предметов."
L["settings.tooltip.bis_scope"] =
    "Какие BiS-строки классов показывать на подсказках предметов. «Все классы» показывает каждый класс, для которого предмет BiS; «Только текущая группа» фильтрует по классам в вашей группе/рейде (откатывается на ваш класс в одиночке); «Только мой класс» показывает только ваш класс; «Выкл» скрывает список BiS (значок уровня аксессуара на строке названия по-прежнему появляется)."
L["settings.value.bis_scope_all"] = "Все классы"
L["settings.value.bis_scope_group"] = "Только текущая группа"
L["settings.value.bis_scope_self"] = "Только мой класс"
L["settings.tooltip.highlight_owned"] =
    "Подсвечивает строки BiS и аксессуаров мягким зелёным фоном, если предмет уже есть (сумки, банк, банк реагентов, банк боевого отряда или надет). Применяется и к закреплённой, и к плавающей панели."
L["settings.tooltip.minimap_button"] =
    "Показать кнопку на миникарте для быстрого доступа. ЛКМ открывает справочник, ПКМ — настройки."
L["settings.tooltip.login_message"] =
    "Выводить сообщение 'Bread Codex загружен — введите /cc для открытия' в чат при входе или перезагрузке интерфейса."
L["settings.tooltip.pin_talent_source"] =
    "Фиксирует панель талантов на выбранном вручную источнике. Когда отключено, источник следует за вашими действиями — U.GG в подземельях и рейдах, PvP на аренах и полях боя, Icy Veins в остальных случаях."
L["settings.tooltip.float_show_stat_priority"] =
    "Показать раздел приоритета характеристик в плавающей панели."
L["settings.tooltip.float_show_talents"] =
    "Показать раздел талантов в плавающей панели."
L["settings.tooltip.float_show_rotation"] =
    "Показать раздел ротации в плавающей панели."
L["settings.tooltip.float_show_enchants"] = "Показать раздел чар в плавающей панели."
L["settings.tooltip.float_show_gems"] = "Показать раздел камней в плавающей панели."
L["settings.tooltip.float_show_consumables"] =
    "Показать раздел расходников в плавающей панели."
L["settings.tooltip.float_show_trinkets"] =
    "Показать раздел аксессуаров в плавающей панели."
L["settings.tooltip.float_show_crafts"] =
    "Показать раздел крафта в плавающей панели."
L["settings.tooltip.float_show_bis_gear"] =
    "Показать раздел лучшей экипировки в плавающей панели."
L["settings.tooltip.dock_show_stat_priority"] =
    "Показать раздел приоритета характеристик в закреплённой панели."
L["settings.tooltip.dock_show_talents"] =
    "Показать раздел талантов в закреплённой панели."
L["settings.tooltip.dock_show_rotation"] =
    "Показать раздел ротации в закреплённой панели."
L["settings.tooltip.dock_show_enchants"] =
    "Показать раздел чар в закреплённой панели."
L["settings.tooltip.dock_show_gems"] =
    "Показать раздел камней в закреплённой панели."
L["settings.tooltip.dock_show_consumables"] =
    "Показать раздел расходников в закреплённой панели."
L["settings.tooltip.dock_show_trinkets"] =
    "Показать раздел аксессуаров в закреплённой панели."
L["settings.tooltip.dock_show_crafts"] =
    "Показать раздел крафта в закреплённой панели."
L["settings.tooltip.dock_show_bis_gear"] =
    "Показать раздел лучшей экипировки в закреплённой панели."

L["chat.loaded"] = "загружен — введите |cff00ccff/cc|r для открытия"
L["chat.slash_conflict"] =
    "Другое дополнение использует |cff00ccff/cc|r — введите |cff00ccff/classcodex|r, чтобы открыть Bread Codex."
L["chat.switched_to"] = "Переключено на %s (обнаружено)"
L["chat.mode_docked"] = "Закреплено"
L["chat.mode_floating"] = "Плавающий"
L["chat.mode_reset"] = "Сброшено"
L["chat.compendium_not_available"] = "Справочник недоступен."
L["chat.minimap_shown"] = "Кнопка на миникарте показана"
L["chat.minimap_hidden"] = "Кнопка на миникарте скрыта"
L["chat.minimap_not_available"] = "Кнопка на миникарте недоступна"
L["chat.unknown_command"] = "Неизвестная команда. Введите /cc help"
L["chat.settings_registration_failed"] = "Ошибка регистрации настроек: %s"
L["chat.compendium_data_not_loaded"] = "Данные справочника не загружены."

L["settings.label.stat_priority_source_line"] =
    "Строка источника приоритета характеристик"

L["section.stat_targets"] = "Цели характеристик"
L["settings.label.show_stat_targets"] = "Показывать цели характеристик"
L["settings.tooltip.dock_show_stat_targets"] =
    "Показывать раздел «Цели характеристик» (полосы в реальном времени относительно BiS-целей U.GG) на вкладке характеристик, когда панель закреплена."
L["settings.tooltip.float_show_stat_targets"] =
    "Показывать раздел «Цели характеристик» (полосы в реальном времени относительно BiS-целей U.GG) на вкладке характеристик, когда панель плавающая."
L["tooltip.stat_priority_footer"] = "Приоритет характеристик"

L["settings.label.source_display"] = "Отображение источника"
L["settings.tooltip.source_display"] =
    "Как отображать источники данных (U.GG, Icy Veins) во всплывающих подсказках предметов."
L["settings.tooltip.bis_source"] =
    "Когда показывать строку в нижней части подсказок предметов с указанием того, из какого таланта героя / контекста взяты приоритеты. «Только при отличии» показывает строку, только когда выбранный талант героя отличается от того, которым вы играете сейчас — тихое напоминание, что закреплённый выбор разошёлся с состоянием в игре."
L["settings.value.always"] = "Всегда"
L["settings.value.off"] = "Откл."
L["settings.value.only_when_different"] = "Только при отличии"
L["settings.value.both"] = "Оба"
L["settings.value.icons"] = "Значки"
L["settings.value.view"] = "Вид"
L["settings.value.list"] = "Список"
L["settings.value.table"] = "Таблица"
L["settings.value.labels"] = "Подписи"
L["settings.value.ugg"] = "U.GG"

L["context.mplus_dungeons"] = "Подземелья M+"
L["context.raid_heroic"] = "Боссы рейда (Героический)"
L["context.raid_mythic"] = "Боссы рейда (Эпохальный)"

L["settings.header.loadout_dock"] = "Док раскладок"
L["settings.label.show_loadout_dock"] = "Показывать док раскладок"
L["settings.tooltip.show_loadout_dock"] =
    "Плавающий виджет, отображающий название активной раскладки талантов. Нажмите, чтобы переключиться на любую сохранённую раскладку Blizzard или рекомендацию Bread Codex."
L["loadout_dock.click_to_switch"] = "Нажмите, чтобы сменить раскладку."
L["loadout_dock.right_click_options"] = "Правый щелчок — параметры."
L["loadout_dock.cannot_switch_combat"] = "Нельзя сменить раскладку в бою."
L["loadout_dock.switch_failed"] = "Не удалось сменить раскладку."
L["loadout_dock.no_loadouts"] = "Нет доступных раскладок"
L["loadout_dock.no_talent_builds"] = "Нет доступных билдов талантов."
L["loadout_dock.no_ugg_builds"] = "Нет доступных билдов U.GG."
L["loadout_dock.pick_a_build"] = "Выберите билд"
L["talent_pane.placeholder.encounter"] = "Выберите бой"
L["talent_pane.placeholder.bracket"] = "Выберите формат"
L["gear.tooltip.alternative"] = "Альтернатива:"
L["gear.tooltip.embellishment"] = "Украшения:"
L["loadout_dock.custom_build"] = "Свой билд"
L["loadout_dock.no_spec"] = "Выберите специализацию"
L["loadout_dock.saved_loadouts"] = "Сохранённые раскладки"
L["settings.label.dock_show_saved"] = "Показывать сохранённые раскладки в меню"
L["settings.label.dock_show_ugg"] = "Показывать рекомендации U.GG в меню"
L["settings.tooltip.dock_show_saved"] =
    "Включает ваши сохранённые в Blizzard раскладки талантов в меню дока."
L["settings.tooltip.dock_show_ugg"] =
    "Включает рекомендованные U.GG билды по боссам в меню дока."
L["settings.label.dock_show_spec_icon"] = "Показывать значок специализации"
L["settings.label.dock_show_icons"] = "Show build icons"
L["settings.tooltip.dock_show_icons"] = "Show the spec and hero talent icons on the loadout dock."
L["settings.tooltip.dock_show_spec_icon"] =
    "Показывает значок вашей активной специализации рядом с названием раскладки."
L["settings.label.dock_show_hero_icon"] = "Показывать значок таланта героя"
L["settings.tooltip.dock_show_hero_icon"] =
    "Показывает значок вашего активного таланта героя рядом с названием раскладки."
L["settings.label.dock_show_border"] = "Показывать рамку"
L["settings.tooltip.dock_show_border"] =
    "Рисует тонкую рамку вокруг дока. Отключите для минималистичного вида без рамки."
L["settings.label.dock_opacity"] = "Прозрачность фона"
L["settings.tooltip.dock_opacity"] =
    "Прозрачность подложки дока. 0 = невидимая, 100 = непрозрачная."
L["settings.label.dock_width"] = "Ширина"
L["settings.tooltip.dock_width"] =
    "Ширина дока в пикселях. Игнорируется при включённой автоматической подгонке."
L["settings.label.dock_auto_width"] = "Авто-подгон ширины"
L["settings.tooltip.dock_auto_width"] =
    "Автоматически подгоняет размер дока под название активной раскладки. Переопределяет ползунок ширины, когда включено."
L["settings.label.dock_scale"] = "Масштаб"
L["settings.tooltip.dock_scale"] =
    "Масштаб дока. Увеличивает шрифт, значки и высоту пропорционально."
L["settings.label.dock_alignment"] = "Выравнивание содержимого"
L["settings.tooltip.dock_alignment"] =
    "Где располагаются значки и подпись, когда док шире содержимого."
L["settings.value.center"] = "По центру"
L["settings.value.left"] = "Слева"
L["settings.value.right"] = "Справа"
L["settings.label.dock_hide_in_combat"] = "Скрывать в бою"
L["settings.tooltip.dock_hide_in_combat"] =
    "Полностью скрывает док в бою. Смена талантов в бою всё равно не работает, так что это лишь убирает визуальный шум."
L["settings.label.dock_lock_position"] = "Закрепить положение дока"
L["settings.tooltip.dock_lock_position"] =
    "Запрещает перетаскивать док. Отключите, чтобы переместить, затем включите снова, чтобы избежать случайных сдвигов."
L["loadout_dock.lock_position"] = "Закрепить положение"
L["loadout_dock.unlock_position"] = "Открепить положение"
L["character_pane.position_locked"] =
    "Положение закреплено — открепите в настройках"

L["pvp.label"] = "PvP"
L["pvp.no_builds"] = "Нет доступных PvP-билдов."
L["pvp.no_gear_data"] =
    "Пока нет данных PvP-снаряжения для этой специализации."
L["pvp.no_enchants"] = "Пока нет PvP-зачарований для этой специализации."
L["pvp.no_enchant_gem_data"] =
    "Пока нет данных PvP-зачарований/самоцветов для этой специализации."
L["pvp.no_stat_priority"] =
    "Пока нет приоритета характеристик PvP для этой специализации."

L["settings.header.talent_pane"] = "Окно талантов"
L["settings.label.talent_pane_show"] = "Показывать Bread Codex в окне талантов"
L["settings.tooltip.talent_pane_show"] =
    "Показывает выбор билдов Bread Codex в окне талантов Blizzard. Отключите, чтобы полностью скрыть."
L["settings.header.unit_menus"] = "Меню юнитов"
L["settings.label.unit_menu_enabled"] =
    "Добавить «Просмотр талантов» в меню правой кнопки мыши"
L["settings.tooltip.unit_menu_enabled"] =
    "Добавляет «Просмотр талантов» в меню правой кнопки мыши на рамках рейда, группы и юнитов. Отключите, если после правого щелчка появляются ошибки «Аддон пытался вызвать защищённую функцию» — это известная ошибка Blizzard."
L["chat.blizzard_bug_notice"] =
    "|cff66ccff[Bread Codex]|r Ошибка «%s», которую вы только что видели — это известная ошибка Blizzard, а не ошибка Bread Codex. Отключите «Добавить Просмотр талантов в меню правой кнопки мыши» в настройках, чтобы остановить её."
L["settings.header.character_pane_button"] = "Кнопка окна персонажа"
L["character_pane.click_to_toggle"] = "Нажмите, чтобы открыть/закрыть панель"
L["settings.label.lock_button_position"] = "Закрепить положение кнопки"
L["settings.tooltip.lock_button_position"] =
    "Запрещает перемещать кнопку снаряжения через Shift-перетаскивание в окне персонажа."
L["character_pane.shift_drag_hint"] =
    "Shift-перетащить для перемещения — Shift+правый щелчок для сброса"
L["settings.label.horizontal_offset"] = "Смещение по горизонтали"
L["settings.tooltip.horizontal_offset"] =
    "Смещение по горизонтали (в пикселях) от правого верхнего угла окна персонажа."
L["settings.label.vertical_offset"] = "Смещение по вертикали"
L["settings.tooltip.vertical_offset"] =
    "Смещение по вертикали (в пикселях) от правого верхнего угла окна персонажа."
L["settings.tooltip.reset_position"] =
    "Возвращает кнопку снаряжения в положение по умолчанию."

L["footer.today"] = "Сегодня"
L["footer.yesterday"] = "Вчера"
L["footer.days_ago"] = "%d дн. назад"
L["tab.settings"] = "Settings"
L["tab.about"] = "About"
L["about.header"] = "About Bread Codex"
L["about.version"] = "Addon Version"
L["about.data_update"] = "Data Updated"
L["about.more"] = "Explore & Customize"
L["about.website_page"] = "Bread Codex Page"
L["about.compendium"] = "Compendium"
L["about.loadout_dock"] = "Loadout Dock"
L["about.loadout_dock_tip"] = "Show a movable bar with your talent loadouts."
L["about.talent_highlight"] = "Talent Highlight"
L["about.talent_highlight_tip"] = "Open your talent tree to see the recommended talents highlighted."
L["about.toggle_hint"] = "Click to enable or disable."
L["about.all_settings"] = "All Settings"
L["about.discord"] = "Bread Codex Discord"
L["about.support_iv"] = "Support with Icy Veins Premium"
L["about.compendium_tip"] = "Browse gear, talents and more for every class and spec."
L["about.settings_tip"] = "Open the full Bread Codex options."
L["about.discord_tip"] = "Bugs, feedback and theorycrafting."
L["about.support_iv_tip"] = "Support Bread Codex by going Premium on Icy Veins."
L["tab.supporters"] = "Supporters"
L["settings.open_compendium"] = "Open Compendium"
L["settings.header.display"] = "Display"
L["settings.header.tabs"] = "Tabs"
L["settings.header.more"] = "More"
L["settings.header.sources"] = "Sources"
L["settings.row.window"] = "Window"
L["settings.value.docked"] = "Docked"
L["settings.value.floating"] = "Floating"
L["settings.row.rearrange"] = "Rearrange tabs"
L["settings.row.reset_order"] = "Reset tab order"
L["settings.row.reorder"] = "Reorder tabs"
L["settings.tooltip.reorder"] = "Drag to rearrange the side tabs, or reset them to the default order."
L["settings.row.advanced"] = "Advanced settings"
L["settings.tooltip.window"] = "Dock the panel to your character sheet, or let it float freely."
L["settings.tooltip.width"] = "How wide the docked panel is."
L["settings.tooltip.rearrange"] = "Drag the side tabs up or down to reorder them."
L["settings.tooltip.reset_order"] = "Restore the default tab order."
L["settings.tooltip.advanced"] = "Open the full Bread Codex options window."
L["settings.tooltip.compendium"] = "Browse gear, talents and more for every class and spec."
L["settings.tooltip.omnium"] = "Show or hide the Omnium Folio in the Compendium."
L["settings.tooltip.section_visibility"] = "Show or hide this tab in the panel."
L["settings.label.title_context"] = "Show content & hero in title"
L["settings.tooltip.title_context"] = "Append the active content type and hero talent to the panel title."
L["section.stats"] = "Stats"
L["empty.rotation_source_unavailable"] = "Rotation is only available for the Icy Veins source."
L["empty.report_discord"] = "Report issues or request data on Discord"
L["tab.crafting"] = "Ремёсла"
L["crafting.section_crafts"] = "Изделия"
L["crafting.section_embellishments"] = "Украшения"
L["crafting.help.embellishment_icyveins"] = "Рекомендуемое украшение (Icy Veins)."
L["crafting.tooltip.embellishment_icyveins"] = "Рекомендовано Icy Veins"
L["crafting.no_data"] = "Пока нет данных ремесла — обновляются ежедневно."
L["crafting.menu.track_materials"] = "Отслеживать материалы"
L["crafting.menu.no_recipe"] = "Нет данных о рецепте"
L["crafting.help.intro"] =
    "Рекомендуемые ремесленные предметы для этой специализации."
L["crafting.help.menu"] =
    "ПКМ по предмету: отслеживать материалы или скопировать ссылку U.GG."
L["crafting.help.embellishment_limit"] =
    "Создавайте сколько угодно предметов — но на персонажа можно надеть только 2 украшения."
L["crafting.tooltip.menu_hint"] = "ПКМ для опций"

L["talents.leveling"] = "Прокачка"
L["loadout_dock.no_icyveins_builds"] = "Нет доступных сборок талантов Icy Veins."

L["settings.value.icyveins"] = "Icy Veins"
L["settings.label.dock_show_icyveins"] = "Показывать сборки Icy Veins в меню"
L["settings.tooltip.dock_show_icyveins"] =
    "Включить сборки талантов Icy Veins (в т.ч. для прокачки) в меню дока."
L["context.arena"] = "Arena"
L["context.battleground"] = "Battleground"
L["omnium.help.intro"] =
    "The Omnium Folio is Midnight's rune system: spend Omnium to slot a rune of power in each node. Pick the recommended rune (green) in each slot; a red border means your current pick differs from the recommendation."
L["omnium.unset"] = "No rune selected"
L["reorder.hint"] = "Drag the tabs to reorder · click to lock"
L["title_bar.menu.reorder"] = "Unlock order (drag tabs)"
L["title_bar.menu.reset_order"] = "Reset section order"
L["hero.all"] = "All heroes"

-- Untranslated: enUS fallback (TODO)
L["loadout_dock.all_settings"] = "All settings"
L["loadout_dock.builds_all"] = "All"
L["loadout_dock.builds_hero"] = "My hero talent only"
L["loadout_dock.builds_recommended"] = "Recommended"
L["loadout_dock.builds_title"] = "Show builds"
L["loadout_dock.hero_active"] = "Active spec's"
L["loadout_dock.hero_title"] = "Hero talent"
L["loadout_dock.pvp_all_brackets"] = "All Brackets"
L["loadout_dock.show_pvp"] = "Show PvP builds"
L["loadout_dock.theme_codex"] = "Bread Codex"
L["loadout_dock.theme_compact"] = "Compact"
L["loadout_dock.theme_minimalist"] = "Minimalist"
L["loadout_dock.theme_title"] = "Theme"
L["settings.label.dock_background"] = "Background"
L["settings.label.dock_max_width"] = "Max dock width"
L["settings.label.dock_pick_color"] = "Custom background color"
L["settings.label.raid_difficulty"] = "Raid difficulty"
L["settings.tooltip.dock_background"] =
    "Dock background color at full opacity: your class color, or a custom color. Bread Codex theme only."
L["settings.tooltip.dock_build_filter"] =
    "Which recommended builds appear in the dock's loadout menu: everything, only builds for your current hero talent, or the recommended picks only."
L["settings.tooltip.dock_hero_filter"] =
    "Which hero talent the hero build filter matches against: the active spec's, or a specific hero talent."
L["settings.tooltip.dock_max_width"] =
    "Upper limit for the dock's width — applies both to the fixed width and to auto-width sizing."
L["settings.tooltip.dock_pick_color"] =
    "Open the color picker for the dock background. Choosing a color switches the background to Custom."
L["settings.tooltip.dock_show_pvp"] = "Include the U.GG arena and battleground builds in the dock's loadout menu."
L["settings.tooltip.dock_theme"] =
    "Bread Codex: selector styling — gradient background, border and ringed icons. Compact: same, without background or border. Minimalist: label only."
L["settings.tooltip.raid_difficulty"] =
    "Which raid difficulty's builds to show — drives the loadout dock's raid section and the talents page."
L["settings.value.dock_bg_class"] = "Class color"
L["settings.value.dock_bg_custom"] = "Custom"
L["settings.value.dock_pick_color_pick"] = "Pick color…"
L["settings.value.heroic"] = "Heroic"
L["settings.value.mythic"] = "Mythic"

-- Untranslated: enUS fallback (TODO)
L["item.menu.search_ah"] = "Add to Auctionator List"
L["item.menu.ah_listed"] = 'Added to your Auctionator "Bread Codex" shopping list.'
L["item.menu.ah_list_fail"] = "Could not update the Auctionator shopping list."

L["item.menu.copy_name"] = "Copy name"

L["item.tooltip.menu_hint"] = "Right-click for options"

L["crafting.menu.sort_popular"] = "Show most popular only"
L["crafting.menu.popularity_title"] = "Popularity"

L["settings.header.tooltip_stat_priority"] = "Stat Priority"
L["settings.header.tooltip_bis"] = "Best in Slot"
L["settings.header.tooltip_trinket"] = "Trinket Tier"
L["settings.tooltip.stat_priority_source_line"] = "Show the "

L["settings.label.priority_display"] = "Priority Display"
L["settings.tooltip.priority_display"] =
    "How the Stat Priority line shows the hero and content: icons, labels, or both."

L["onboarding.title"] = "Bread Codex Tour"
L["onboarding.next"] = "Next"
L["onboarding.help_tooltip_title"] = "Bread Codex Tour"
L["onboarding.help_tooltip_body"] = "Take the tour.\nIt hides once you finish. Re-enable it in Settings."
L["onboarding.ctx_title"] = "Context"
L["onboarding.ctx_body"] = "Set your content, guide source, and hero.\n\n|cffffd100Click the dropdown to change it.|r"
L["onboarding.tabs_title"] = "Tabs"
L["onboarding.tabs_body"] = "Each tab is a guide for your spec.\n\n|cffffd100Click one to open it.|r"
L["onboarding.about_title"] = "About Tab"
L["onboarding.about_body"] =
    "Open the Compendium, toggle the Loadout Dock, and reach settings, Discord, and support.\n\n|cffffd100Click the About tab to open it.|r"
L["onboarding.comp_title"] = "Compendium"
L["onboarding.comp_body"] =
    "The same idea as this panel, but for every class and spec.\n\n|cffffd100Click to open the Compendium.|r"
L["onboarding.minimap_title"] = "Minimap Button"
L["onboarding.minimap_body"] =
    "|cffffd100Left click|r the minimap icon for the Compendium.\n|cffffd100Right click|r it for settings."
L["onboarding.dock_title"] = "Loadout Dock"
L["onboarding.dock_body"] =
    "|cffffd100Click this toggle to turn it on.|r\n\n|cffffd100Left click|r the dock to switch loadout.\n|cffffd100Right click|r the dock for settings, like which hero's talents to show."
L["onboarding.talent_title"] = "Talent Builds"
L["onboarding.talent_body"] =
    "Bread Codex adds a build picker to your talent tree. Pick a build and the changed talents glow.\n\n|cffffd100Click the icon to show or hide it.|r"
L["onboarding.thanks_title"] = "You're All Set"
L["onboarding.thanks_body"] =
    "Thank you for using |cffffd100Bread Codex|r.\n\nQuestions, bugs, or ideas?\nCome find us on Discord."
L["onboarding.settings_show_button_label"] = "Show the help button on the panel"
L["onboarding.settings_show_button_tooltip"] = "Show the round i on the panel. Click it to replay the tour."
