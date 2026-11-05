#!/usr/bin/env python3
"""Adds the rank D..S skills (and extra rank E ones) of all six proficiencies to data/skills/*.json.

The rank E skills the owner wrote by hand (physical.json's ten, healing.json's seven) are kept exactly as they are; this script
appends everything else, so running it twice gives the same files (it drops what it added before: entries with "gen": true).
Each skill is (name, rank, flavour, power, fx, target) where target is "foe", "ally", "any" or "self".
Descriptions are the flavour plus a sentence built from the numbers, so text and rules never drift apart.
    python3 godot/tools/skills/build_skills.py
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.normpath(os.path.join(HERE, "..", "..", "data", "skills"))
SP = {"E": 3, "D": 4, "C": 5, "B": 6, "A": 8, "S": 10}
STAT = {"ATTACK": "Attack", "DEFENSE": "Defense", "MAGIC": "Magic", "RESISTANCE": "Resistance", "SPEED": "Speed", "WILL": "Will",
        "MOVE": "Move", "JUMP": "Jump"}
ST = {"burn": "burning (6% HP a turn)", "regen": "regen (8% HP a turn)", "ward": "warded (25% less damage)",
      "exposed": "exposed (25% more damage)", "silence": "silenced (no skills)", "root": "rooted (cannot walk)",
      "poison": "poisoned", "mild_blind": "blinded", "atk_down": "weakened (less physical damage)", "marked": "marked",
      "sleep": "asleep (loses its turns; a hit wakes it)", "stun": "stunned (loses its next turn)", "confuse": "confused (acts at random, friend or foe)",
      "berserk": "berserk (attacks the nearest unit of either side, +30% Attack)", "doom": "doomed (knocked out when the count ends)",
      "curse": "cursed (healing works half as well)", "blind": "blind (misses half the time)", "slowed": "slowed (Speed -40%)", "haste": "hasted (Speed +50%)"}


def describe(fx, power, target):
    out = []
    if fx.get("self_only"):
        out.append("Affects only the user.")
    elif target == "ally":
        out.append("Teammates only.")
    elif target == "foe":
        out.append("Enemies only.")
    if fx.get("blast"):
        out.append("Reaches every tile within %d of the aimed one." % fx["blast"])
    if fx.get("hits"):
        out.append("Strikes %d times." % fx["hits"])
    if fx.get("pct_hp"):
        out.append("Takes %d%% of the target's max HP, ignoring its defence." % fx["pct_hp"])
    if fx.get("execute"):
        out.append("+%d%% damage on a target at 30%% HP or less." % fx["execute"])
    if fx.get("desperate"):
        out.append("Up to +%d%% damage as the user's HP runs out." % fx["desperate"])
    if fx.get("vs_status"):
        out.append("+%d%% damage on a target that is %s." % (fx["vs_status"]["bonus"], ST.get(fx["vs_status"]["status"], fx["vs_status"]["status"])))
    if fx.get("chaos"):
        out.append("Its damage varies wildly: %d%% to %d%% of normal." % tuple(fx["chaos"]))
    if fx.get("drain"):
        out.append("The user regains %d%% of the damage dealt." % fx["drain"])
    for k, v in fx.get("status", {}).items():
        ch = fx.get("status_chance", 100)
        out.append("%s%s for %d turn%s." % (("%d%% chance: " % ch) if ch < 100 else "", ST[k].capitalize(), v, "" if v == 1 else "s"))
    for m in fx.get("mods", []):
        out.append("%s %s%d%% for %d turns." % (STAT[m["stat"]], "+" if m["pct"] > 0 else "", m["pct"], m["turns"]))
    if fx.get("heal_pct"):
        out.append("Restores %d%% of max HP." % fx["heal_pct"])
    if fx.get("cleanse"):
        out.append("Removes every harmful status and lowered stat.")
    if fx.get("cure"):
        out.append("Wakes and cures: " + ", ".join(fx["cure"]) + ".")
    if fx.get("guard"):
        out.append("The target guards until its next turn.")
    if fx.get("sp_drain"):
        out.append("Drains %d SP%s." % (fx["sp_drain"], " for the user" if fx.get("sp_steal") else ""))
    if fx.get("sp_give"):
        out.append("Gives %d SP." % fx["sp_give"])
    if fx.get("pull"):
        out.append("Drags the target %d tile%s toward the user." % (fx["pull"], "" if fx["pull"] == 1 else "s"))
    if fx.get("swap"):
        out.append("The user and the target change places.")
    if fx.get("delay"):
        out.append("Delays the target's next turn.")
    if fx.get("rush"):
        out.append("Brings the target's next turn sooner.")
    s = fx.get("self")
    if s:
        bits = []
        if s.get("heal_pct"):
            bits.append("heals %d%% of max HP" % s["heal_pct"])
        if s.get("recoil_pct"):
            bits.append("takes %d%% of max HP in recoil" % s["recoil_pct"])
        if s.get("sp_gain"):
            bits.append("gains %d SP" % s["sp_gain"])
        for m in s.get("mods", []):
            bits.append("%s %s%d%% for %d turns" % (STAT[m["stat"]], "+" if m["pct"] > 0 else "", m["pct"], m["turns"]))
        if s.get("guard"):
            bits.append("guards")
        if bits:
            out.append("The user " + ", ".join(bits) + ".")
    return " ".join(out)


def mod(stat, pct, turns):
    return {"stat": stat, "pct": pct, "turns": turns}


EFF = {"fire": "burst", "ice": "shard", "wind": "swirl", "lightning": "streak", "earth": "eruption", "light": "circle", "dark": "smoke"}

# ---------------------------------------------------------------- physical (the ten rank E ones are the owner's)
PHYSICAL = [
    ("Wild Swing", "E", "A haymaker thrown with eyes shut. Anything can happen.", 0, {"chaos": [50, 170]}, "any"),
    ("Bonk", "E", "A clumsy knock that sends the foe back a step and rattles the user too.", 0, {"self": {"recoil_pct": 5}}, "any"),
    ("Rending Cut", "D", "A cut that opens the target's guard.", 0, {"status": {"exposed": 2}}, "any"),
    ("Shoulder Barge", "D", "Drive a shoulder in and shove the foe two tiles.", 0, {}, "any"),
    ("Twin Strike", "D", "Two quick blows in one motion.", 0, {"hits": 2}, "any"),
    ("Rallying Blow", "D", "A strike that fires the user up.", 0, {"self": {"mods": [mod("ATTACK", 10, 2)]}}, "any"),
    ("Pin Down", "D", "Pin a foot to the ground.", 0, {"status": {"root": 1}}, "any"),
    ("Cartwheel Slash", "D", "A flailing cartwheel that hits whatever is near the target. Nobody knows how it works.", 0, {"chaos": [40, 220], "blast": 1}, "any"),
    ("Cleaver of Ruin", "C", "A finishing chop that loves a wounded target.", 0, {"execute": 40}, "any"),
    ("Vampiric Slash", "C", "A cut that drinks.", 0, {"drain": 40}, "any"),
    ("Reckless Charge", "C", "All power, no guard.", 0, {"scale": 1.3, "self": {"recoil_pct": 8}}, "any"),
    ("Crippling Blow", "C", "Smash a joint and sap the arm.", 0, {"status": {"atk_down": 2}}, "any"),
    ("Hooked Haul", "C", "A hooked blade that drags the foe in.", 0, {"pull": 2}, "any"),
    ("Tavern Brawl", "C", "Chairs, fists and a flung mug.", 0, {"hits": 2, "status": {"mild_blind": 2}, "status_chance": 50}, "any"),
    ("Stunning Blow", "D", "A blow to the head. 50% chance to stun.", 0, {"status": {"stun": 1}, "status_chance": 50}, "any"),
    ("Hammer Slam", "B", "A colossal blow that shakes the ground round it. 40% chance to stun each.", 0, {"blast": 1, "status": {"stun": 1}, "status_chance": 40}, "any"),
    ("Executioner's Cut", "B", "No mercy for the wounded.", 0, {"execute": 60}, "any"),
    ("Whirlwind", "B", "Spin through everyone around the aimed tile, friend or foe.", 0, {"blast": 1}, "any"),
    ("Iron Rain", "B", "Three heavy blows in a blink.", 0, {"hits": 3}, "any"),
    ("Barrel Roll", "B", "Roll a barrel through the foe. It does not care who is in the way.", 0, {"scale": 1.1}, "any"),
    ("Blade Storm", "A", "A whirl of steel that hits three times around the aimed tile.", 0, {"hits": 3, "blast": 1}, "any"),
    ("Last Stand", "A", "The nearer to death, the harder the hit.", 0, {"desperate": 80}, "any"),
    ("Shatter Guard", "A", "Break armour and nerve alike.", 0, {"status": {"exposed": 3}, "mods": [mod("DEFENSE", -20, 3)]}, "any"),
    ("Sundering Blow", "S", "A blow that breaks the target's defences.", 0, {"scale": 1.15, "status": {"exposed": 3}, "mods": [mod("DEFENSE", -30, 3)]}, "any"),
    ("Thousand Cuts", "S", "Five strikes before the target can blink.", 0, {"hits": 5}, "any"),
]
PHYS_EXTRA = {"Shoulder Barge": {"push": 2}, "Barrel Roll": {"push": 3}}

# ---------------------------------------------------------------- elemental
ELEMENTAL = [
    ("Ember Flick", "E", "A spark flicked at the foe.", 6, {"status": {"burn": 3}, "status_chance": 50}, "any", "fire"),
    ("Frost Prick", "E", "A needle of ice that slows the legs.", 6, {"mods": [mod("SPEED", -20, 2)]}, "any", "ice"),
    ("Static Snap", "E", "A crack of static that saps a little SP.", 6, {"sp_drain": 2}, "any", "lightning"),
    ("Gust", "E", "A shove of wind.", 5, {"pull": 1}, "any", "wind"),
    ("Pebble Toss", "E", "A stone thrown with a little magic behind it.", 8, {}, "any", "earth"),
    ("Soak", "E", "A splash that leaves the target exposed to the next blow.", 5, {"status": {"exposed": 1}}, "any", "ice"),
    ("Spark Sneeze", "E", "Magic from the wrong end. Anything from a tickle to a jolt.", 8, {"chaos": [30, 200]}, "any", "lightning"),
    ("Fireball", "D", "A fireball that scorches the tiles around it.", 10, {"blast": 1, "status": {"burn": 2}, "status_chance": 40}, "any", "fire"),
    ("Frost Lance", "D", "A lance of ice that chills the legs.", 11, {"slow": 2}, "any", "ice"),
    ("Chain Spark", "D", "Lightning that jumps twice.", 9, {"hits": 2}, "any", "lightning"),
    ("Mudslide", "D", "The ground gives way and holds the target fast.", 8, {"status": {"root": 1}}, "any", "earth"),
    ("Sentient Snowball", "D", "It rolls up, grows and drags the target in.", 10, {"pull": 2}, "any", "ice"),
    ("Flame Wave", "C", "A wave of fire across the tiles around the aim.", 13, {"blast": 1, "status": {"burn": 3}, "status_chance": 50}, "any", "fire"),
    ("Glacier Spike", "C", "A spike of ice that freezes the target to the spot.", 15, {"status": {"root": 2}}, "any", "ice"),
    ("Thunderclap", "C", "The shock knocks the target's timing off.", 14, {"sp_drain": 3, "delay": 30}, "any", "lightning"),
    ("Cutting Wind", "C", "Three razor gusts.", 11, {"hits": 3}, "any", "wind"),
    ("Scorch", "C", "Fire that loves a target already burning.", 12, {"vs_status": {"status": "burn", "bonus": 60}}, "any", "fire"),
    ("Hot Potato", "C", "Pass it on: the target is set alight and cannot put it out.", 8, {"status": {"burn": 4}}, "any", "fire"),
    ("Inferno", "B", "A blaze that fills the area.", 17, {"blast": 2, "status": {"burn": 3}}, "any", "fire"),
    ("Blizzard", "B", "Wind and snow that slow everything caught in it.", 15, {"blast": 1, "slow": 1, "mods": [mod("SPEED", -25, 2)]}, "any", "ice"),
    ("Storm Call", "B", "Call a storm and hope. It is rarely quiet.", 17, {"blast": 1, "chaos": [60, 180]}, "any", "lightning"),
    ("Tremor", "B", "The earth heaves and throws timing out.", 16, {"blast": 1, "delay": 40}, "any", "earth"),
    ("Pocket Thunderstorm", "B", "A small, furious cloud.", 14, {"blast": 1, "chaos": [50, 200]}, "any", "lightning"),
    ("Meteor Fall", "A", "A rock from the sky.", 24, {"blast": 2}, "any", "earth"),
    ("Absolute Zero", "A", "Cold that stops everything.", 22, {"status": {"root": 2, "exposed": 2}}, "any", "ice"),
    ("Tempest", "A", "Three storms in a row.", 15, {"hits": 3, "blast": 1}, "any", "wind"),
    ("Phoenix Dive", "S", "Dive in fire. The user rises a little stronger.", 32, {"status": {"burn": 3}, "drain": 50, "self": {"heal_pct": 15}}, "any", "fire"),
    ("Worldsplitter", "S", "The ground opens under everything near the aim.", 30, {"blast": 2, "status": {"exposed": 2}}, "any", "earth"),
]

# ---------------------------------------------------------------- healing (power: restores power + Magic / 2)
HEALING = [
    ("Bandage Hat", "E", "A sloppy wrap, but it holds.", 12, {}, "ally", "light"),
    ("Hum a Tune", "E", "A calming hum that restores a little SP.", 6, {"sp_give": 2}, "ally", "light"),
    ("Mend", "D", "A proper mend.", 18, {}, "ally", "light"),
    ("Soothing Mist", "D", "A mist that heals everyone near the aimed tile.", 10, {"blast": 1}, "ally", "light"),
    ("Purify", "D", "Clears the poisons and curses.", 6, {"cleanse": True}, "ally", "light"),
    ("Lucky Lollipop", "D", "Heals by a candy's whim: a trickle or a gush.", 18, {"chaos": [40, 200]}, "ally", "light"),
    ("Spit Shine", "D", "Wipes the grime off and raises a guard.", 6, {"cleanse": True, "guard": True}, "ally", "light"),
    ("Greater Heal", "C", "A strong heal.", 28, {}, "ally", "light"),
    ("Rejuvenate", "C", "A heal that keeps on healing.", 8, {"status": {"regen": 4}}, "ally", "light"),
    ("Warm Blanket", "C", "Heals and wraps the target in comfort.", 16, {"status": {"ward": 2}}, "ally", "light"),
    ("Second Wind", "C", "Heals and brings back some SP.", 16, {"sp_give": 3}, "ally", "light"),
    ("Chicken Soup", "C", "Heals, restores SP, and keeps healing a little.", 14, {"sp_give": 2, "status": {"regen": 2}}, "ally", "light"),
    ("Healing Circle", "B", "A circle of light that heals everyone in it.", 22, {"blast": 1}, "ally", "light"),
    ("Restorative Rain", "B", "A wide rain that heals and keeps healing.", 12, {"blast": 2, "status": {"regen": 2}}, "ally", "light"),
    ("Sanctuary", "B", "Cleanses the allies in the circle and wards them.", 6, {"blast": 1, "cleanse": True, "status": {"ward": 3}}, "ally", "light"),
    ("Radiant Mend", "A", "A great mend.", 46, {}, "ally", "light"),
    ("Mass Renewal", "A", "Heals a whole line and cleanses it.", 28, {"blast": 2, "cleanse": True}, "ally", "light"),
    ("Angel's Grace", "S", "Heals, cleanses, wards and renews everyone near the aim.", 36, {"blast": 2, "cleanse": True, "status": {"regen": 3, "ward": 2}}, "ally", "light"),
    ("Miracle", "S", "One ally is made whole.", 0, {"heal_pct": 100, "cleanse": True}, "ally", "light"),
]

# ---------------------------------------------------------------- tactical (no damage: positions, tempo and boosts)
TACTICAL = [
    ("Brace", "E", "Plant the feet and guard.", 0, {"self_only": True, "guard": True}, "self", "circle"),
    ("Rally Cry", "E", "A shout that stiffens an ally's arm.", 0, {"mods": [mod("ATTACK", 10, 2)]}, "ally", "circle"),
    ("Study Foe", "E", "Pick out the weak spot.", 0, {"status": {"marked": 3}}, "foe", "circle"),
    ("Fleet Foot", "E", "Lighten the step.", 0, {"self_only": True, "mods": [mod("MOVE", 25, 2)]}, "self", "circle"),
    ("Signal Flare", "E", "A flare that leaves the foe exposed for a blow.", 0, {"status": {"exposed": 1}}, "foe", "circle"),
    ("Swap Meet", "E", "Trade places with anyone, no questions.", 0, {"swap": True}, "any", "circle"),
    ("Fortify", "D", "Raise a ward on an ally.", 0, {"status": {"ward": 2}}, "ally", "circle"),
    ("Hasten", "D", "An ally acts sooner and moves faster.", 0, {"rush": 40, "mods": [mod("SPEED", 15, 2)]}, "ally", "circle"),
    ("Taunting Shout", "D", "The foe loses its rhythm.", 0, {"delay": 30}, "foe", "circle"),
    ("Ankle Snare", "D", "A snare holds one foe.", 0, {"status": {"root": 1}}, "foe", "circle"),
    ("Shift Places", "D", "Pull an ally out of danger by taking their place.", 0, {"swap": True}, "ally", "circle"),
    ("Bulwark", "C", "Allies near the aim guard and harden.", 0, {"blast": 1, "guard": True, "mods": [mod("DEFENSE", 15, 2)]}, "ally", "circle"),
    ("Battle Hymn", "C", "Allies near the aim strike harder.", 0, {"blast": 1, "mods": [mod("ATTACK", 15, 3)]}, "ally", "circle"),
    ("Grapple Line", "C", "A line that reels a foe in.", 0, {"pull": 3}, "foe", "circle"),
    ("Disrupt Formation", "C", "Throw the foe's timing off.", 0, {"delay": 60}, "foe", "circle"),
    ("Scout's Eye", "C", "A long look: quicker and surer on rough ground.", 0, {"self_only": True, "mods": [mod("MOVE", 25, 2), mod("JUMP", 50, 2)]}, "self", "circle"),
    ("Surprise Party", "C", "Allies near the aim get a little SP and a head start.", 0, {"blast": 1, "sp_give": 2, "rush": 20}, "ally", "circle"),
    ("Haste", "D", "An ally's turns come sooner.", 0, {"status": {"haste": 3}}, "ally", "circle"),
    ("Mass Haste", "B", "Allies near the aim speed up.", 0, {"blast": 2, "status": {"haste": 3}}, "ally", "circle"),
    ("Smelling Salts", "D", "Wakes a sleeper and clears a stun.", 0, {"cure": ["sleep", "stun"]}, "ally", "circle"),
    ("Flank Order", "B", "An ally moves at once.", 0, {"rush": 80}, "ally", "circle"),
    ("Phalanx", "B", "Allies near the aim are warded.", 0, {"blast": 2, "status": {"ward": 2}}, "ally", "circle"),
    ("Entangle", "B", "Roots hold every foe near the aim.", 0, {"blast": 1, "status": {"root": 1}}, "foe", "circle"),
    ("Weak Point", "B", "Open the target's guard wide.", 0, {"status": {"exposed": 3}, "mods": [mod("DEFENSE", -20, 3)]}, "foe", "circle"),
    ("Grand Strategy", "A", "Allies near the aim attack harder and act faster.", 0, {"blast": 2, "mods": [mod("ATTACK", 20, 3), mod("SPEED", 15, 3)]}, "ally", "circle"),
    ("Time Fold", "A", "An ally acts again almost at once.", 0, {"rush": 100}, "ally", "circle"),
    ("Checkmate", "A", "One foe, no moves left.", 0, {"status": {"root": 2, "exposed": 2}, "delay": 80}, "foe", "circle"),
    ("Commander's Aura", "S", "Allies near the aim are warded, renewed and stronger.", 0, {"blast": 3, "status": {"ward": 3, "regen": 3}, "mods": [mod("ATTACK", 20, 3)]}, "ally", "circle"),
    ("Stalemate", "S", "Every foe near the aim is stopped cold.", 0, {"blast": 2, "status": {"root": 1, "silence": 2}, "delay": 100}, "foe", "circle"),
]

# ---------------------------------------------------------------- status (afflictions on foes)
STATUS = [
    ("Cripple", "E", "Wear down the legs.", 0, {"mods": [mod("SPEED", -20, 2)]}, "foe", "smoke"),
    ("Hush", "E", "Silence a caster for a turn.", 0, {"status": {"silence": 1}}, "foe", "smoke"),
    ("Dazzle", "E", "A flash that blinds.", 0, {"status": {"mild_blind": 2}}, "foe", "circle"),
    ("Sap Strength", "E", "The arm goes weak.", 0, {"status": {"atk_down": 2}}, "foe", "smoke"),
    ("Itch Powder", "E", "The armour itches until the foe cannot stand it.", 0, {"mods": [mod("DEFENSE", -15, 2)]}, "foe", "smoke"),
    ("Rubber Chicken Slap", "E", "Humiliating, and a little blinding.", 0, {"status": {"mild_blind": 1}, "mods": [mod("WILL", -20, 2)]}, "foe", "smoke"),
    ("Weaken Armor", "D", "Rust and rot.", 0, {"status": {"exposed": 2}}, "foe", "smoke"),
    ("Stinging Mark", "D", "A mark that draws every blow.", 0, {"status": {"marked": 3}, "mods": [mod("RESISTANCE", -15, 3)]}, "foe", "smoke"),
    ("Slow Venom", "D", "A venom that saps the legs too.", 0, {"status": {"poison": 3}, "mods": [mod("SPEED", -15, 3)]}, "foe", "smoke"),
    ("Tar Trap", "D", "Sticky tar. One step, then none.", 0, {"status": {"root": 1}, "slow": 1}, "foe", "smoke"),
    ("Embarrassing Secret", "D", "Say it loudly. The foe loses heart.", 0, {"mods": [mod("ATTACK", -25, 2), mod("WILL", -25, 2)]}, "foe", "smoke"),
    ("Banana Peel", "D", "Probably. 70% of the time, it works every time.", 0, {"status": {"root": 1}, "status_chance": 70, "delay": 30}, "foe", "smoke"),
    ("Mass Blind", "C", "A cloud of dust over every foe near the aim.", 0, {"blast": 1, "status": {"mild_blind": 2}}, "foe", "smoke"),
    ("Curse of Rust", "C", "Defences crumble.", 0, {"mods": [mod("DEFENSE", -25, 3), mod("RESISTANCE", -25, 3)]}, "foe", "smoke"),
    ("Choke Spores", "C", "Spores that silence and sicken.", 0, {"blast": 1, "status": {"silence": 2, "poison": 2}}, "foe", "smoke"),
    ("Drain Spirit", "C", "Take the target's SP for yourself.", 0, {"sp_drain": 5, "sp_steal": True}, "foe", "smoke"),
    ("Lethargy", "C", "A heavy tiredness.", 0, {"delay": 70, "mods": [mod("SPEED", -25, 3)]}, "foe", "smoke"),
    ("Mime's Curse", "C", "The words will not come.", 0, {"status": {"silence": 3}}, "foe", "smoke"),
    ("Witherblight", "B", "A blight that spreads over the area.", 0, {"blast": 1, "status": {"poison": 4, "exposed": 2}}, "foe", "smoke"),
    ("Hex Chain", "B", "A hex that binds voice, arm and mind.", 0, {"status": {"silence": 3, "atk_down": 3}, "mods": [mod("MAGIC", -25, 3)]}, "foe", "smoke"),
    ("Paralyzing Gaze", "B", "A look that stops the foe cold.", 0, {"status": {"root": 2}, "delay": 60}, "foe", "smoke"),
    ("Plague Cloud", "A", "A cloud of sickness over the area.", 0, {"blast": 2, "status": {"poison": 5, "atk_down": 3}}, "foe", "smoke"),
    ("Soul Siphon", "A", "Take the SP and dull the mind.", 0, {"sp_drain": 10, "sp_steal": True, "mods": [mod("MAGIC", -20, 3)]}, "foe", "smoke"),
    ("Lullaby", "D", "A slow, soft song.", 0, {"status": {"sleep": 2}}, "foe", "smoke"),
    ("Sandman's Song", "B", "Everyone near the aim nods off.", 0, {"blast": 1, "status": {"sleep": 3}}, "foe", "smoke"),
    ("Nightfall", "A", "Night falls on the whole area; the silence is complete.", 0, {"blast": 2, "status": {"sleep": 3, "silence": 1}}, "foe", "smoke"),
    ("Bewilder", "C", "The world turns round and the target with it.", 0, {"status": {"confuse": 2}}, "foe", "smoke"),
    ("Mind Fog", "B", "A fog on the mind of everyone near the aim.", 0, {"blast": 1, "status": {"confuse": 2}}, "foe", "smoke"),
    ("Rage Song", "C", "A war-song that is too much for one foe.", 0, {"status": {"berserk": 3}}, "foe", "smoke"),
    ("Blinding Flash", "D", "A flash that takes the sight.", 0, {"status": {"blind": 2}}, "foe", "circle"),
    ("Daze", "D", "A word, a look, a blow to the senses. 60% chance.", 0, {"status": {"stun": 1}, "status_chance": 60}, "foe", "smoke"),
    ("Slow Spell", "D", "The air thickens round the target.", 0, {"status": {"slowed": 3}}, "foe", "smoke"),
    ("Hex of Waning", "C", "Healing runs off the target like water.", 0, {"status": {"curse": 3}}, "foe", "smoke"),
    ("Doom Mark", "B", "A mark that counts down. When it ends, so does the target.", 0, {"status": {"doom": 4}}, "foe", "smoke"),
    ("Death Knell", "S", "A bell for everyone near the aim.", 0, {"blast": 2, "status": {"doom": 5}}, "foe", "smoke"),
    ("Time Stop", "S", "For a moment nothing near the aim moves.", 0, {"blast": 2, "status": {"stun": 2}}, "foe", "circle"),
    ("Doom Shroud", "S", "Everything near the aim is cursed at once.", 0, {"blast": 2, "status": {"exposed": 3, "silence": 2, "root": 1, "poison": 4, "atk_down": 3}}, "foe", "smoke"),
]

# ---------------------------------------------------------------- void (damage that ignores Resistance)
VOID = [
    ("Hollow Touch", "E", "A touch of nothing.", 7, {}, "any", "dark"),
    ("Shadow Nip", "E", "A bite of shadow that feeds the user.", 6, {"drain": 50}, "any", "dark"),
    ("Dim Light", "E", "The world dims for the target.", 5, {"status": {"mild_blind": 2}}, "any", "dark"),
    ("Null Pulse", "E", "A pulse that empties a little SP.", 6, {"sp_drain": 2}, "any", "dark"),
    ("Existential Hiccup", "E", "Reality skips. Damage may follow.", 8, {"chaos": [20, 220]}, "any", "dark"),
    ("Void Lance", "D", "A lance of nothing.", 12, {}, "any", "dark"),
    ("Gravity Well", "D", "Pulls the target in.", 9, {"pull": 2}, "any", "dark"),
    ("Entropy Touch", "D", "Takes a slice of the target's max HP.", 0, {"pct_hp": 12}, "any", "dark"),
    ("Umbra Bite", "D", "A bite that feeds the user.", 10, {"drain": 50}, "any", "dark"),
    ("Void Pun", "D", "The groan is the weapon. The foe is silenced a turn.", 8, {"status": {"silence": 1}}, "any", "dark"),
    ("Rift Slash", "C", "Two cuts through the air itself.", 11, {"hits": 2}, "any", "dark"),
    ("Black Hole Pinch", "C", "A tiny hole that drags in everything near the aim.", 11, {"blast": 1, "pull": 1}, "any", "dark"),
    ("Soul Rend", "C", "Tears at a weakened soul.", 14, {"execute": 50}, "any", "dark"),
    ("Erase", "C", "Takes a big slice of the target's max HP.", 0, {"pct_hp": 18}, "any", "dark"),
    ("Cosmic Wedgie", "C", "Yank! Dragged in and left exposed.", 10, {"pull": 2, "status": {"exposed": 1}}, "any", "dark"),
    ("Abyssal Maw", "B", "A mouth of nothing over the area.", 17, {"blast": 1}, "any", "dark"),
    ("Event Horizon", "B", "Drags the target in and leaves it open.", 15, {"pull": 3, "status": {"exposed": 2}}, "any", "dark"),
    ("Null Field", "B", "Empties the SP of everyone near the aim and silences them.", 12, {"blast": 1, "sp_drain": 4, "status": {"silence": 1}}, "any", "dark"),
    ("Stare Into Abyss", "B", "It stares back. The target loses a slice of HP and its sight; so does the user's calm.", 0, {"pct_hp": 15, "status": {"mild_blind": 2}, "self": {"recoil_pct": 5}}, "any", "dark"),
    ("Collapse", "A", "Everything near the aim folds in.", 24, {"blast": 2}, "any", "dark"),
    ("Oblivion", "A", "Takes a great slice of the target's max HP.", 0, {"pct_hp": 30}, "any", "dark"),
    ("Unmake", "A", "Finishes what is nearly gone.", 22, {"execute": 80}, "any", "dark"),
    ("Singularity", "S", "A point that swallows the area and pulls it in.", 30, {"blast": 2, "pull": 2}, "any", "dark"),
    ("Annihilate", "S", "Takes almost half of the target's max HP. It costs the user.", 0, {"pct_hp": 45, "self": {"recoil_pct": 10}}, "any", "dark"),
]


def entry(t, kind):
    name, rank, flavour, power, fx, target = t[:6]
    eff = t[6] if len(t) > 6 else ""
    slow = fx.pop("slow", 0)
    d = {"name": name, "rank": rank, "sp": SP[rank]}
    d["description"] = (flavour + " " + describe(fx, power, target) + (" The target loses %d Move on its next turn." % slow if slow else "")).strip()
    if slow:
        d["slow"] = slow
    d["shape"] = "stance"
    if kind == "physical":
        d["animation"] = "attack" if rank in "ED" else "heavy"
        d["effect"] = "slash"
    else:
        d["animation"] = "cast"
        d["effect"] = EFF.get(eff, eff)
    if power:
        d["power"] = power
    if target == "ally" or target == "self":
        d["allies_only"] = True
    if target == "foe":
        d["enemies_only"] = True
    if fx:
        d["fx"] = fx
    d["effect_implemented"] = True
    d["gen"] = True
    return d


def write(file, extra, kind, extras=None):
    path = os.path.join(DIR, file)
    old = json.load(open(path)) if os.path.exists(path) else []
    keep = [e for e in old if not e.get("gen")]
    new = [entry(t, kind) for t in extra]
    for e in new:
        e.update((extras or {}).get(e["name"], {}))
    json.dump(keep + new, open(path, "w"), indent="\t", ensure_ascii=False)
    open(path, "a").write("\n")
    print(file, len(keep), "kept +", len(new))


write("physical.json", PHYSICAL, "physical", PHYS_EXTRA)
write("elemental.json", ELEMENTAL, "elemental")
write("healing.json", HEALING, "healing")
write("tactical.json", TACTICAL, "tactical")
write("status.json", STATUS, "status")
write("void.json", VOID, "void")
