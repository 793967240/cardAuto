# src/globals/event_bus.gd
# 全局信号总线 - UI 通过订阅这里的信号被动更新
# AutoLoad 为 "EventBus"
extends Node

# ─── 战斗事件 ────────────────────────────────────────────────
signal battle_tick_advanced(tick: int)
signal card_fired(combatant_id: StringName, card_id: StringName, index: int)
signal combatant_hp_changed(combatant_id: StringName, old_hp: int, new_hp: int)
signal combatant_died(combatant_id: StringName)
signal status_applied(combatant_id: StringName, status_id: StringName)
signal status_expired(combatant_id: StringName, status_id: StringName)
signal chain_recovery_started(combatant_id: StringName, duration: int)
signal chain_recovery_ended(combatant_id: StringName)
signal battle_ended(winner: int)

# ─── 构筑事件 ────────────────────────────────────────────────
signal deck_changed()
signal slot_card_placed(slot_index: int, card_id: StringName)
signal slot_card_removed(slot_index: int)

# ─── 地图/Run 事件 ────────────────────────────────────────────
signal node_entered(node_type: String)
signal run_started(character_id: StringName)
signal run_ended(won: bool)

# ─── 设置事件 ────────────────────────────────────────────────
signal language_changed(locale: String)
signal speed_changed(multiplier: float)
signal settings_saved()
