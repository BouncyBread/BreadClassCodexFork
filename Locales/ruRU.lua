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
    "U.GG показывает экипировку, которую чаще всего используют игроки в эпохальных+ и рейде в этом сезоне, отсортированную по популярности."
L["bis.help.ugg_mplus"] = "Данные эпохального+ взяты из высоких ключей."
L["tab.enhancements"] = "Улучшения"
L["talent_pane.view_talents"] = "Просмотр талантов"
L["talent_pane.save_as.tooltip"] = "Сохранить как новую раскладку"
L["talent_pane.auto_recommend"] = "Выбрать рекомендуемое автоматически"
L["talent_pane.difficulty"] = "Сложность"
L["talent_pane.recommended"] = "Рекомендуемое"
L["talent_pane.build_options"] = "Параметры билда"
L["talent_pane.save_as.prompt"] = "Имя раскладки:"
L["talent_pane.save_as.confirm"] = "Сохранить"

L["section.stat_priority"] = "Приоритет характеристик"
L["section.talents"] = "Таланты"
L["section.rotation"] = "Ротация"
L["section.omnium"] = "Omnium Folio"
L["omnium.week"] = "Неделя %d"

L["title_bar.menu_hint"] = "Закрепление, размер и отображение"
L["title_bar.open_settings"] = "Открыть настройки"
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
L["empty.no_builds_details"] = "Нет доступных билдов. Подробности на U.GG."
L["empty.no_builds_for"] = "Нет билдов для %s. См. U.GG."
L["empty.no_rotation_for_details"] = "Нет ротации для %s. Подробности на U.GG."
L["empty.no_rotation_available"] =
    "Ротация скоро появится.\nУ нас её пока нет для этой специализации."
L["empty.no_pvp_guide"] =
    "PvP-гайд скоро появится.\nДля этой специализации его пока нет."
L["empty.no_stat_targets"] =
    "Целевые показатели характеристик скоро появятся.\nДля этой специализации пока недостаточно данных в этом сезоне."

L["settings.description"] =
    "Лучшая экипировка, аксессуары, чары, камни, таланты, приоритеты характеристик, ротация и крафт для вашей специализации, взятые напрямую из Icy Veins и U.GG в игру."
L["settings.help_hint"] = "Введите /cc help, чтобы увидеть список команд."
L["attribution.copy_url"] = "Нажмите, чтобы скопировать ссылку"
L["attribution.visit_source"] = "Открыть источник: %s"
L["attribution.page_title"] = "Страница %s %s"
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
L["settings.label.float_auto_height"] = "Подгонять размер под содержимое"
L["settings.tooltip.float_auto_height"] =
    "Плавающая панель растёт под своё содержимое вместо постраничного показа в фиксированной высоте."
L["settings.label.float_height"] = "Высота плавающей панели"
L["settings.label.float_max_height"] = "Максимальная высота"
L["settings.tooltip.float_max_height"] =
    "Максимальная высота плавающей панели. Более высокое содержимое прокручивается."
L["settings.tooltip.float_height"] =
    "Высота плавающей панели, когда автоподгонка выключена."
L["settings.header.floating_panel"] = "Плавающая панель"
L["settings.header.docked_panel"] = "Закреплённая панель"
L["settings.subcat.panels"] = "Панели"
L["settings.subcat.compendium"] = "Compendium"
L["settings.subcat.tabs"] = "Вкладки"
L["settings.label.floating_mode"] = "Плавающая панель"
L["settings.tooltip.floating_mode"] =
    "Отсоединяет панель от окна персонажа, чтобы её можно было разместить в любом месте экрана."
L["settings.label.float_esc"] = "Закрывать по Esc"
L["settings.tooltip.float_esc"] =
    "Позволяет закрывать отсоединённую панель клавишей Esc."
L["settings.tooltip.comp_show_tab"] = "Показывать эту вкладку в Compendium."
L["settings.header.dock_behavior"] = "Поведение"
L["settings.header.dock_display"] = "Отображение"
L["settings.header.dock_appearance"] = "Внешний вид"
L["settings.header.tab_order"] = "Порядок"
L["settings.label.reorder_tabs"] = "Изменить порядок вкладок"
L["settings.value.reorder"] = "Изменить порядок"
L["settings.tooltip.reorder_tabs"] =
    "Перетаскивайте боковые вкладки, чтобы изменить их порядок. Открывает вашу панель и закрывает это окно."
L["settings.label.reset_tabs"] = "Сбросить порядок вкладок"
L["settings.value.reset"] = "Сброс"
L["settings.tooltip.reset_tabs"] =
    "Восстанавливает порядок вкладок по умолчанию."
L["settings.tooltip.dock_show_omnium"] =
    "Показать или скрыть Omnium Folio в закреплённой панели."
L["settings.tooltip.float_show_omnium"] =
    "Показать или скрыть Omnium Folio в плавающей панели."
L["settings.header.panel"] = "Панель"

L["settings.label.stat_priority_ranks"] = "Ранги приоритета характеристик"
L["settings.label.ugg_bis"] = "Инфо BiS U.GG в подсказках"
L["settings.label.icy_veins_bis"] = "Инфо BiS Icy Veins в подсказках"
L["settings.label.trinket_tier"] = "Уровень аксессуаров в подсказках"
L["settings.label.bis_scope"] = "Охват BiS в подсказках"
L["settings.label.highlight_owned"] = "Выделять имеющееся снаряжение"
L["settings.label.page_hard_stops"] = "Жёсткие границы разделов"
L["settings.tooltip.page_hard_stops"] =
    "Фиксирует прокрутку на текущем разделе. Колесо мыши останавливается на границе каждого раздела и не переходит к следующему автоматически. Используйте боковые вкладки для смены раздела."
L["settings.label.panel_width"] = "Ширина панели"
L["settings.tooltip.panel_width"] =
    "Ширина панели Bread Codex в пикселях. Применяется к закреплённому и плавающему режимам."
L["settings.label.gear_source"] = "Показывать источник предмета"
L["settings.hint.gear_source_no_icons"] = "Отображается в режимах таблицы и списка."
L["settings.tooltip.gear_source"] =
    "Показывает, откуда берётся каждый предмет из списка лучшей экипировки. Например, место добычи или изготовление. Отображается под названием предмета в режиме списка и отдельным столбцом в режиме таблицы. В режиме значков информация остаётся в подсказке предмета. Каждая панель запоминает выбор отдельно. Только для данных Icy Veins."
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
    "Показать кнопку на миникарте для быстрого доступа. ЛКМ открывает справочник, ПКМ открывает настройки."
L["settings.tooltip.login_message"] =
    "Выводить в чат сообщение «Bread Codex загружен. Введите /cc для открытия» при входе в игру или перезагрузке интерфейса."
L["settings.tooltip.pin_talent_source"] =
    "Фиксирует панель талантов на выбранном вручную источнике. Когда отключено, источник следует за вашими действиями. U.GG отображается в подземельях и рейдах, PvP на аренах и полях боя, Icy Veins в остальных случаях."
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

L["chat.loaded"] = "загружен. Введите |cff00ccff/cc|r для открытия"
L["chat.slash_conflict"] =
    "Другое дополнение использует |cff00ccff/cc|r. Введите |cff00ccff/classcodex|r, чтобы открыть Bread Codex."
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
    "Показывать раздел «Цели характеристик» (ваши текущие характеристики относительно целевых значений характеристик U.GG) на вкладке характеристик, когда панель закреплена."
L["settings.tooltip.float_show_stat_targets"] =
    "Показывать раздел «Цели характеристик» (ваши текущие характеристики относительно целевых значений характеристик U.GG) на вкладке характеристик, когда панель плавающая."
L["stat_targets.bin"] = "Топ %d%%"
L["stat_targets.bin_picker"] =
    "Выберите, из каких игроков берутся цели. Топ 20%, 50% или 80% по экипировке. Выберите, показывать ли в строках значения или проценты."
L["settings.value.stat_targets_values"] = "Значения"
L["settings.value.stat_targets_percent"] = "Проценты"
L["stat_targets.bin_desc.top20"] =
    "Рейтинги вторичных характеристик у топ-20% игроков. Достичь их сложнее всего."
L["stat_targets.bin_desc.top50"] =
    "Рейтинги у топ-50% игроков. Реалистичная цель для середины сезона."
L["stat_targets.bin_desc.top80"] =
    "Рейтинги у топ-80% игроков. Самая достижимая из трёх."
L["tooltip.stat_priority_footer"] = "Приоритет характеристик"

L["settings.label.source_display"] = "Отображение источника"
L["settings.tooltip.source_display"] =
    "Как отображать источники данных (U.GG, Icy Veins) во всплывающих подсказках предметов."
L["settings.tooltip.bis_source"] =
    "Когда показывать строку в нижней части подсказок предметов с указанием того, из какого таланта героя / контекста взяты приоритеты. «Только при отличии» показывает строку, только когда выбранный талант героя отличается от того, которым вы играете сейчас. Тихое напоминание о том, что закрепление или выбор панели разошлись с состоянием в игре."
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
L["loadout_dock.right_click_options"] = "Правый щелчок открывает параметры."
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
L["gear.tooltip.catalyst"] = "Катализировано из:"
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
L["settings.label.dock_show_icons"] = "Показывать значки билдов"
L["settings.tooltip.dock_show_icons"] =
    "Показывает значки специализации и таланта героя на доке раскладок."
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
    "Скрывает док раскладок во время боя. Смена талантов в бою всё равно не работает, так что это лишь убирает визуальный шум."
L["settings.label.dock_lock_position"] = "Закрепить положение дока"
L["settings.tooltip.dock_lock_position"] =
    "Запрещает перетаскивать док. Отключите, чтобы переместить, затем включите снова, чтобы избежать случайных сдвигов."
L["loadout_dock.lock_position"] = "Закрепить положение"
L["loadout_dock.unlock_position"] = "Открепить положение"
L["character_pane.position_locked"] =
    "Положение закреплено. Открепите в настройках"

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
    "Добавляет «Просмотр талантов» в меню правой кнопки мыши на рамках рейда, группы и юнитов. Отключите, если после правого щелчка появляются ошибки «Аддон пытался вызвать защищённую функцию». Это известная ошибка Blizzard."
L["chat.blizzard_bug_notice"] =
    "|cff66ccff[Bread Codex]|r Только что показанная ошибка «%s» является известной ошибкой Blizzard. Bread Codex её не вызывает. Отключите «Добавить Просмотр талантов в меню правой кнопки мыши» в настройках, чтобы остановить её."
L["settings.header.character_pane_button"] = "Кнопка окна персонажа"
L["character_pane.click_to_toggle"] = "Нажмите, чтобы открыть/закрыть панель"
L["settings.label.lock_button_position"] = "Закрепить положение кнопки"
L["settings.tooltip.lock_button_position"] =
    "Запрещает перемещать кнопку снаряжения через Shift-перетаскивание в окне персонажа."
L["character_pane.shift_drag_hint"] =
    "Shift-перетащить для перемещения. Shift+правый щелчок для сброса"
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
L["tab.settings"] = "Настройки"
L["tab.about"] = "Об аддоне"
L["about.header"] = "О Bread Codex"
L["about.version"] = "Версия аддона"
L["about.data_update"] = "Данные обновлены"
L["about.more"] = "Изучить и настроить"
L["about.website_page"] = "Страница Bread Codex"
L["about.compendium"] = "Compendium"
L["about.loadout_dock"] = "Док раскладок"
L["about.loadout_dock_tip"] =
    "Показывает перемещаемую панель с вашими раскладками талантов."
L["about.talent_highlight"] = "Подсветка талантов"
L["about.talent_highlight_tip"] =
    "Откройте дерево талантов, чтобы увидеть подсвеченные рекомендованные таланты."
L["about.toggle_hint"] = "Нажмите, чтобы включить или выключить."
L["about.all_settings"] = "Все настройки"
L["about.discord"] = "Discord Bread Codex"
L["about.support_iv"] = "Поддержать через Icy Veins Premium"
L["about.compendium_tip"] =
    "Просмотр экипировки, талантов и другого для каждого класса и специализации."
L["about.settings_tip"] = "Открыть полные настройки Bread Codex."
L["about.discord_tip"] = "Баги, отзывы и теорикрафт."
L["about.support_iv_tip"] = "Поддержите Bread Codex, оформив Premium на Icy Veins."
L["tab.supporters"] = "Поддержавшие"
L["settings.open_compendium"] = "Открыть Compendium"
L["settings.header.display"] = "Отображение"
L["settings.header.tabs"] = "Вкладки"
L["settings.header.more"] = "Ещё"
L["settings.header.sources"] = "Источники"
L["settings.row.window"] = "Окно"
L["settings.value.docked"] = "Закреплённое"
L["settings.value.floating"] = "Плавающее"
L["settings.row.rearrange"] = "Переставить вкладки"
L["settings.row.reset_order"] = "Сбросить порядок вкладок"
L["settings.row.reorder"] = "Изменить порядок вкладок"
L["settings.tooltip.reorder"] =
    "Перетаскивайте, чтобы переставить боковые вкладки, или сбросьте их к порядку по умолчанию."
L["settings.row.advanced"] = "Расширенные настройки"
L["settings.tooltip.window"] =
    "Закрепите панель на окне персонажа или оставьте её плавающей."
L["settings.tooltip.width"] = "Ширина закреплённой панели."
L["settings.tooltip.rearrange"] =
    "Перетаскивайте боковые вкладки вверх или вниз, чтобы изменить их порядок."
L["settings.tooltip.reset_order"] =
    "Восстанавливает порядок вкладок по умолчанию."
L["settings.tooltip.advanced"] = "Открывает полное окно настроек Bread Codex."
L["settings.tooltip.compendium"] =
    "Просмотр экипировки, талантов и другого для каждого класса и специализации."
L["settings.tooltip.omnium"] = "Показать или скрыть Omnium Folio в Compendium."
L["settings.tooltip.section_visibility"] = "Показать или скрыть эту вкладку в панели."
L["settings.label.title_context"] =
    "Показывать контент и талант героя в заголовке"
L["settings.tooltip.title_context"] =
    "Добавляет активный тип контента и талант героя к заголовку панели."
L["section.stats"] = "Характеристики"
L["empty.rotation_source_unavailable"] =
    "Ротация доступна только для источника Icy Veins."
L["empty.report_discord"] =
    "Сообщайте о проблемах или запрашивайте данные в Discord"
L["tab.crafting"] = "Ремёсла"
L["crafting.section_crafts"] = "Изделия"
L["crafting.section_embellishments"] = "Украшения"
L["crafting.help.embellishment_icyveins"] = "Рекомендуемое украшение (Icy Veins)."
L["crafting.tooltip.embellishment_icyveins"] = "Рекомендовано Icy Veins"
L["crafting.no_data"] = "Пока нет данных ремесла. Обновляются ежедневно."
L["crafting.menu.track_materials"] = "Отслеживать материалы"
L["crafting.menu.no_recipe"] = "Нет данных о рецепте"
L["crafting.help.intro"] =
    "Рекомендуемые ремесленные предметы для этой специализации."
L["crafting.help.menu"] =
    "ПКМ по предмету, чтобы отслеживать материалы или скопировать ссылку U.GG."
L["crafting.help.embellishment_limit"] =
    "Создавайте сколько угодно предметов, но на персонажа можно надеть только 2 украшения."
L["crafting.tooltip.menu_hint"] = "ПКМ для опций"

L["talents.leveling"] = "Прокачка"
L["loadout_dock.no_icyveins_builds"] = "Нет доступных сборок талантов Icy Veins."

L["settings.value.icyveins"] = "Icy Veins"
L["settings.label.dock_show_icyveins"] = "Показывать сборки Icy Veins в меню"
L["settings.tooltip.dock_show_icyveins"] =
    "Включить сборки талантов Icy Veins (в т.ч. для прокачки) в меню дока."
L["context.arena"] = "Арена"
L["context.battleground"] = "Поле боя"
L["omnium.help.intro"] =
    "Omnium Folio представляет собой систему рун дополнения Midnight. Тратьте Omnium, чтобы вставить руну силы в каждый узел. Выбирайте рекомендованную руну (зелёную) в каждой ячейке. Красная рамка означает, что ваш текущий выбор отличается от рекомендации."
L["omnium.unset"] = "Руна не выбрана"
L["reorder.hint"] =
    "Перетащите вкладки для смены порядка · нажмите, чтобы закрепить"
L["title_bar.menu.reorder"] = "Разблокировать порядок (перетащите вкладки)"
L["title_bar.menu.reset_order"] = "Сбросить порядок разделов"
L["hero.all"] = "Все таланты героя"

L["loadout_dock.all_settings"] = "Все настройки"
L["loadout_dock.builds_all"] = "Все"
L["loadout_dock.builds_hero"] = "Только мой талант героя"
L["loadout_dock.builds_recommended"] = "Рекомендуемые"
L["loadout_dock.builds_title"] = "Показывать билды"
L["loadout_dock.hero_active"] = "Активной специализации"
L["loadout_dock.hero_title"] = "Талант героя"
L["loadout_dock.pvp_all_brackets"] = "Все форматы"
L["loadout_dock.show_pvp"] = "Показывать PvP-билды"
L["loadout_dock.theme_codex"] = "Bread Codex"
L["loadout_dock.theme_compact"] = "Компактная"
L["loadout_dock.theme_minimalist"] = "Минималистичная"
L["loadout_dock.theme_title"] = "Тема"
L["settings.label.dock_background"] = "Фон"
L["settings.label.dock_max_width"] = "Максимальная ширина дока"
L["settings.label.dock_pick_color"] = "Свой цвет фона"
L["settings.label.raid_difficulty"] = "Сложность рейда"
L["settings.tooltip.dock_background"] =
    "Цвет фона дока при полной непрозрачности. Используйте цвет вашего класса или свой цвет. Только для темы Bread Codex."
L["settings.tooltip.dock_build_filter"] =
    "Какие рекомендованные билды показываются в меню раскладок дока. Показывать все, только билды для вашего текущего таланта героя или только рекомендованные."
L["settings.tooltip.dock_hero_filter"] =
    "С каким талантом героя сопоставляется фильтр билдов героя. Использовать талант активной специализации или выбрать конкретный талант героя."
L["settings.tooltip.dock_max_width"] =
    "Верхний предел ширины дока. Применяется как к фиксированной ширине, так и к автоподгонке ширины."
L["settings.tooltip.dock_pick_color"] =
    "Открывает палитру для фона дока. Выбор цвета переключает фон на «Свой»."
L["settings.tooltip.dock_show_pvp"] =
    "Включает билды арены и полей боя U.GG в меню раскладок дока."
L["settings.tooltip.dock_theme"] =
    "Bread Codex добавляет градиентный фон, рамку и значки в кольцах. «Компактная» убирает фон и рамку. «Минималистичная» показывает только подпись."
L["settings.tooltip.raid_difficulty"] =
    "Билды какой сложности рейда показывать. Управляет разделом рейда в доке раскладок и страницей талантов."
L["settings.value.dock_bg_class"] = "Цвет класса"
L["settings.value.dock_bg_custom"] = "Свой"
L["settings.value.dock_pick_color_pick"] = "Выбрать цвет…"
L["settings.value.heroic"] = "Героический"
L["settings.value.mythic"] = "Эпохальный"

L["item.menu.search_ah"] = "Добавить в список Auctionator"
L["item.menu.ah_listed"] = 'Добавлено в ваш список покупок Auctionator "Bread Codex".'
L["item.menu.ah_list_fail"] = "Не удалось обновить список покупок Auctionator."

L["item.menu.link_chat"] = "Ссылка в чат"
L["item.menu.copy_name"] = "Скопировать название"
L["item.menu.view_journal"] = "Открыть в журнале подземелий"

L["item.tooltip.menu_hint"] = "ПКМ для опций"

L["crafting.menu.sort_popular"] = "Показывать только самое популярное"
L["crafting.menu.popularity_title"] = "Популярность"

L["settings.header.tooltip_stat_priority"] = "Приоритет характеристик"
L["settings.header.tooltip_bis"] = "Best in Slot"
L["settings.header.tooltip_trinket"] = "Уровень аксессуаров"
L["settings.tooltip.stat_priority_source_line"] =
    "Показывает строку приоритета характеристик в подсказках предметов, с героем и контентом, которые отражают показанные ранги."

L["settings.label.priority_display"] = "Отображение приоритета"
L["settings.tooltip.priority_display"] =
    "Как строка приоритета характеристик отображает героя и контент. Выберите значки, подписи или и то, и другое."

L["onboarding.title"] = "Тур по Bread Codex"
L["onboarding.next"] = "Далее"
L["onboarding.help_tooltip_title"] = "Тур по Bread Codex"
L["onboarding.help_tooltip_body"] =
    "Пройдите тур.\nОн скроется после завершения. Включите его снова в настройках."
L["onboarding.ctx_title"] = "Контекст"
L["onboarding.ctx_body"] =
    "Задайте контент, источник гайда и таланты героя.\n\n|cffffd100Нажмите на список, чтобы изменить.|r"
L["onboarding.tabs_title"] = "Вкладки"
L["onboarding.tabs_body"] =
    "Каждая вкладка это гайд для вашей специализации.\n\n|cffffd100Нажмите на любую, чтобы открыть.|r"
L["onboarding.about_title"] = "Вкладка «Об аддоне»"
L["onboarding.about_body"] =
    "Откройте Compendium, включите док раскладок, перейдите к настройкам, Discord и поддержке.\n\n|cffffd100Нажмите на вкладку «Об аддоне», чтобы открыть её.|r"
L["onboarding.comp_title"] = "Compendium"
L["onboarding.comp_body"] =
    "Та же идея, что и у этой панели, но для каждого класса и специализации.\n\n|cffffd100Нажмите, чтобы открыть Compendium.|r"
L["onboarding.minimap_title"] = "Кнопка на миникарте"
L["onboarding.minimap_body"] =
    "|cffffd100ЛКМ|r по значку на миникарте открывает Compendium.\n|cffffd100ПКМ|r по нему открывает настройки."
L["onboarding.dock_title"] = "Док раскладок"
L["onboarding.dock_body"] =
    "|cffffd100Нажмите этот переключатель, чтобы включить его.|r\n\n|cffffd100ЛКМ|r по доку меняет раскладку.\n|cffffd100ПКМ|r по доку открывает настройки, например какие таланты героя показывать."
L["onboarding.talent_title"] = "Билды талантов"
L["onboarding.talent_body"] =
    "Bread Codex добавляет выбор билдов в дерево талантов. Выберите билд, и изменённые таланты засветятся.\n\n|cffffd100Нажмите на значок, чтобы показать или скрыть его.|r"
L["onboarding.thanks_title"] = "Всё готово"
L["onboarding.thanks_body"] =
    "Спасибо, что используете |cffffd100Bread Codex|r.\n\nВопросы, баги или идеи?\nНайдите нас в Discord."
L["onboarding.settings_show_button_label"] = "Показывать кнопку помощи на панели"
L["onboarding.settings_show_button_tooltip"] =
    "Показывает круглую «i» на панели. Нажмите на неё, чтобы повторить тур."
L["context.selector_title"] = "Контекст"
L["context.selector_hint"] =
    "Источник, тип контента, таланты героя. Нажмите, чтобы изменить."
L["tooltip.open_compendium"] = "Нажмите, чтобы открыть Compendium."
L["talent_pane.compare_hint"] =
    "Сравните свои таланты и загрузите свежие билды из наших источников."
L["gear.cog_hint"] = "Нажмите, чтобы сменить билд или вид."
L["trinkets.cog_hint"] = "Нажмите, чтобы отфильтровать уровни и контент."
L["rotation.cog_hint"] = "Нажмите, чтобы сменить ротацию."
L["hint.switch_view"] = "Нажмите, чтобы сменить вид."
L["hint.click_change"] = "Нажмите, чтобы изменить."
L["talents.builds_title"] = "Билды талантов"
L["talents.builds_body"] =
    "Выберите сложность рейда и включите «Рекомендуемое». Это самый популярный билд для каждого босса или подземелья."
L["card.hero_talent"] = "Талант героя"
L["card.currently_applied"] = "Сейчас применено"
L["talent_apply.applied"] = "Таланты применены: %s"
L["talent_apply.renamed"] = "Раскладка переименована в %s"
L["talent_apply.already_using"] = "Этот билд уже используется."
L["talent_apply.creating_slot"] = "Создание слота раскладки..."
L["talent_apply.saved"] = "Раскладка «%s» сохранена."
L["talent_apply.reset_failed"] =
    "Не удалось сбросить дерево талантов. Применение отменено. Попробуйте снова через мгновение."
L["talent_apply.commit_failed"] =
    "Не удалось сохранить. Откройте окно талантов и нажмите «Подтвердить изменения»."
L["talent_apply.in_combat"] = "Нельзя менять таланты в бою."
L["talent_apply.inspecting"] =
    "Нельзя применить билд во время осмотра другого игрока. Сначала закройте осмотр."
L["talent_apply.no_tree"] = "Не удалось определить дерево талантов."
L["talent_apply.no_config"] = "Нет активной конфигурации талантов."
L["talent_apply.no_slots_use"] =
    "Нет свободных слотов раскладок. Удалите один, чтобы использовать билды Bread Codex."
L["talent_apply.no_slots_save"] =
    "Нет свободных слотов раскладок. Удалите один, чтобы сохранить новый билд."
L["talent_apply.loading"] =
    "Конфигурация талантов ещё загружается. Попробуйте снова через мгновение."
L["talent_apply.tree_changed"] =
    "Дерево талантов изменилось во время применения. Попробуйте снова."
L["talent_apply.in_progress"] = "Применение уже идёт. Дождитесь завершения."
L["talent_apply.empty_export"] = "Пустая строка экспорта."
L["talent_apply.decode_failed"] = "Не удалось декодировать строку экспорта."
L["talent_apply.invalid_export"] = "Неверная строка экспорта."
L["talent_apply.bad_export"] = "Некорректная строка экспорта."
L["talent_apply.version_mismatch"] = "Несоответствие версии сериализации."
L["talent_apply.wrong_version"] =
    "Строка билда из другой версии игры. Скопируйте её заново."
L["talent_apply.spec_mismatch"] = "Экспорт для специализации %d, активна %d."
L["talent_apply.nodes_partial"] =
    "Применяется %d из %d узлов. На текущем уровне остальные не помещаются (%s). Повысьте уровень и примените заново, чтобы заполнить оставшиеся %d."
L["talent_apply.not_settled"] =
    "Применение талантов не завершилось за %s попыток. Система конфигурации занята. Попробуйте снова через мгновение."
L["talent_apply.unsaved_changes"] =
    "У вас есть несохранённые изменения талантов. Откройте панель талантов и нажмите «Подтвердить изменения» (или щёлкните правой кнопкой по названию раскладки, чтобы отменить их) перед применением билда Bread Codex."
L["talent_apply.could_not_load"] =
    "Не удалось загрузить раскладку Bread Codex. Откройте панель талантов, нажмите «Подтвердить изменения» и попробуйте снова."
L["talent_apply.name_required"] = "Требуется название раскладки."
L["talent_apply.name_reserved"] =
    '"%s" зарезервировано для Bread Codex. Выберите другое название.'
L["talent_apply.save_failed"] =
    "Не удалось сохранить раскладку. Проверьте строку билда."
L["talent_apply.import_unsupported"] = "Импорт не поддерживается этим клиентом."
L["talent_apply.save_unsupported"] =
    "Эта версия игры не поддерживает сохранение раскладок."
L["talent_apply.apis_unavailable"] = "Нужные API талантов недоступны."
L["talent_apply.import_failed"] = "Не удалось импортировать."
L["talent_apply.failed_generic"] = "Не удалось применить таланты."
L["chat.commands_header"] = "команды:"
L["error.panel"] = "Ошибка панели: %s"
L["error.no_talent_config"] =
    "Нет активной конфигурации талантов. Сначала откройте панель талантов."
L["error.no_tree_spec"] = "Не удалось определить дерево или специализацию."
L["dungeon.journal_unavailable"] =
    "Индекс добычи журнала недоступен (нет API журнала)."
L["dungeon.journal_build_failed"] =
    "Не удалось построить индекс добычи журнала: %s"
L["dungeon.journal_empty"] =
    "Индекс добычи журнала построен пустым. Сложность журнала может скрывать добычу."
