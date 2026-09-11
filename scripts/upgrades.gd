extends RefCounted
const CARDS = {
 "damage": ["Бронебойные патроны", "+20% базового урона пулемёта", 5],
 "rate": ["Ускоренный затвор", "+15% базовых выстрелов в секунду", 5],
 "range": ["Дальняя наводка", "+10% базового радиуса пулемёта", 3],
 "cryo": ["Криопушка", "Установка; далее +25% базового урона", 3],
 "tesla": ["Тесла", "Установка; далее +25% базового урона", 3],
 "slow": ["Глубокий холод", "+0,5 секунды замедления", 3],
 "chain": ["Цепной разряд", "+1 цель в каждом разряде", 3],
 "conduct": ["Проводимость", "+30% урона Теслы по замедленным", 1],
 "health": ["Укрепление", "+25 максимального и текущего здоровья", 4],
 "repair": ["Ремонт", "Восстановление 35% максимального здоровья", 0]}
static func eligible(tower, save: Dictionary) -> Array:
 var result := []
 for id in CARDS:
  if id == "repair":
   if tower.hp < tower.max_hp: result.append(id)
   continue
  if tower.level(id) >= CARDS[id][2]: continue
  if id in ["cryo", "tesla"] and not save[id]: continue
  if id == "slow" and tower.level("cryo") == 0: continue
  if id == "chain" and tower.level("tesla") == 0: continue
  if id == "conduct" and (tower.level("cryo") == 0 or tower.level("tesla") == 0): continue
  result.append(id)
 return result
static func offer(tower, save: Dictionary, rng: RandomNumberGenerator) -> Array:
 var pool = eligible(tower, save)
 var result := []
 while not pool.is_empty() and result.size() < 3:
  var index = rng.randi_range(0, pool.size() - 1)
  result.append(pool.pop_at(index))
 return result
static func apply(id: String, tower) -> void:
 tower.levels[id] = tower.level(id) + 1
 if id == "health":
  tower.max_hp += 25
  tower.hp += 25
 if id == "repair": tower.hp = minf(tower.max_hp, tower.hp + tower.max_hp * 0.35)
