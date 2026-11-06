class_name BellwetherStory
extends RefCounted
## Chapter five, "The Man Behind the Summoner": the scenes StoryScene plays (step language in story_scene.gd). The owner's dialogue is word for word; only the gaps
## the brief described but did not write are mine and marked DRAFT. Quiet beats are played (looks, pauses, small effects), not narrated.
##   bw_arrival -> bw_toy      the first click on map 1: the festival preparations and the girl's toy; ends at the world map (to_map)
##   bw_road_pre / bw_road_post     Battle 1 The Roadside Ambush
##   bw_kids_pre / bw_kids_post     Battle 2 The Missing Children
##   bw_mine_pre / bw_mine_post     Battle 3 The Old Mine (the post scene: Alaric is hurt, the vessels fade, Lyra drags him out)
##   bw_empty_pre / bw_empty_post -> bw_interlude    Battle 4 The Empty Battlefield; then the inn: the vessels come back
##   bw_stay_pre / bw_stay_post -> bw_festival      Battle 5 The Choice to Stay; then the festival and the chapter's last scene

const TOWN := "res://samples/bellwether_town.json"
const MAP_1 := "res://samples/bellwether_1.json"
const MAP_2 := "res://samples/bellwether_2.json"
const MAP_3 := "res://samples/bellwether_3.json"
const MAP_4 := "res://samples/bellwether_4.json"
const MAP_5 := "res://samples/bellwether_5.json"


static func opening(n: int) -> Array:  # DRAFT barks as each battle opens
	return [[], ["warden", "Bram", "Wolves and raiders both. Stay together."], ["mira", "Lyra", "Watch the ledges. They know this ground."],
		["squire", "Gideon", "Slowly. Check every corner."], ["mira", "Lyra", "Stay behind me. I'll take the first one."], ["warden", "Bram", "Right, lad. Together this time."]][n]


static func scene(key: String) -> Dictionary:
	return SCENES.get(key, {})


const SCENES := {
	# ---------------------------------------------------------------------------------------------- the harvest festival
	"bw_arrival": {
		"id": "bw_arrival", "map": TOWN, "stage": [0, 0, 0, 0], "next": "bw_toy", "follow": [8, 9],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8a860", 0.12, 0.1],
			["spawn", "alaric", "king", [7, 2], "E"], ["spawn", "bram", "warden", [9, 1], "E", {"tint": "vessel"}], ["spawn", "merc", "merc", [5, 1], "E", {"tint": "vessel"}],
			["spawn", "lyra", "mira", [6, 0], "E"], ["spawn", "gideon", "squire", [10, 2], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [4, 2], "E", {"tint": "vessel"}],
			["spawn", "baker", "villager_man", [5, 9], "S"], ["spawn", "kid", "villager_kid", [8, 11], "W"],
			["title", "CHAPTER FIVE", "The Man Behind the Summoner", 2.8],
			["fade", 0.0, 1.8], ["beat", "start"],
			["walk", "alaric", [7, 6], {"t": 0.5, "par": true}], ["walk", "bram", [9, 5], {"t": 0.5, "par": true}], ["walk", "merc", [5, 5], {"t": 0.5, "par": true}],
			["walk", "lyra", [6, 4], {"t": 0.5, "par": true}], ["walk", "gideon", [10, 4], {"t": 0.5, "par": true}], ["walk", "kaelen", [4, 4], {"t": 0.5, "par": true}], ["join"],
			["look", "merc", "S"], ["bubble", "merc", "~"], ["beat", "food"],
			["look", "bram", "N"], ["bubble", "bram", "#!"], ["look", "gideon", "N"], ["walk", "gideon", [11, 6], {"t": 0.4}], ["look", "gideon", "E"], ["beat", "gideon_walls"],
			["look", "lyra", "S"], ["wait", 0.6], ["beat", "wonder"],
			["say", "merc", "MERC", "Three days until the crossing opens."],
			["say", "alaric", "ALARIC", "Three?"],
			["say", "merc", "MERC", "Unless you know how to move a collapsed bridge."],
			["say", "bram", "BRAM", "Give Gideon a hammer. He'll have a new one built by supper."],
			["say", "gideon", "GIDEON", "Not with this timber."],
			["say", "kaelen", "KAELEN", "See? That's why nobody invites you anywhere."],
			["say", "lyra", "LYRA", "We could enjoy ourselves."],
			["say", "alaric", "ALARIC", "We're losing time."],
			["say", "lyra", "LYRA", "We're waiting for a bridge. You can be miserable while waiting, or you can have dinner."],
			["say", "bram", "BRAM", "I vote dinner."],
			["wait", 0.8], ["look", "alaric", "W"], ["wait", 0.8], ["bubble", "alaric", "..."], ["beat", "reluctant"],
			["tint", "#e8a860", 0.2, 3.0],
			["fade", 1.0, 1.2],
		],
	},
	"bw_toy": {
		"id": "bw_toy", "map": TOWN, "stage": [0, 0, 0, 0], "to_map": true, "follow": [8, 14], "also_seen": ["bw_arrival"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#2a3a60", 0.22, 0.1],
			["spawn", "alaric", "king", [10, 17], "W"], ["spawn", "lyra", "mira", [7, 20], "W"], ["spawn", "bram", "warden", [5, 12], "E", {"tint": "vessel"}],
			["spawn", "merc", "merc", [4, 9], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [8, 7], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [11, 12], "W", {"tint": "vessel"}],
			["spawn", "girl", "villager_girl", [5, 11], "E"], ["spawn", "baker", "villager_man", [6, 15], "S"],
			["fade", 0.0, 1.8], ["beat", "start"],
			["wait", 1.4], ["look", "alaric", "S"], ["wait", 0.8],
			["walk", "girl", [[6, 14], [9, 17]], {"t": 0.5}], ["look", "girl", "E"], ["beat", "girl"],
			["say", "girl", "GIRL", "Are you a knight?"],
			["say", "alaric", "ALARIC", "No."],
			["say", "girl", "GIRL", "You look like one."],
			["say", "alaric", "ALARIC", "I'm not."],
			["say", "girl", "GIRL", "Then what are you?"],
			["say", "alaric", "ALARIC", "I'm traveling."],
			["say", "girl", "GIRL", "That's not a job."],
			["say", "alaric", "ALARIC", "No."],
			["say", "girl", "GIRL", "You're not very good at talking."],
			["say", "alaric", "ALARIC", "I've been told."],
			["bubble", "girl", "..."], ["wait", 0.8], ["beat", "toy"],
			["wait", 0.6], ["look", "alaric", "E"], ["act", "alaric", "attack"], ["wait", 0.5], ["play", "alaric", "idle"], ["fx", "alaric", "burst", 0.6], ["beat", "repaired"],
			["say", "girl", "GIRL", "How'd you know how to do that?"],
			["say", "alaric", "ALARIC", "I've fixed worse."],
			["say", "girl", "GIRL", "You should do that instead of traveling."],
			["wait", 1.0], ["bubble", "alaric", "~"], ["beat", "almost_smile"],
			["look", "lyra", "E"], ["wait", 1.4], ["beat", "lyra_watches"],
			["fade", 1.0, 1.4],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 1: The Roadside Ambush
	"bw_road_pre": {
		"id": "bw_road_pre", "map": MAP_1, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8a860", 0.1, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", "@captain", "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [5, 3], "E"],
			["spawn", "merc", "merc", [9, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [4, 2], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [10, 2], "E", {"tint": "vessel"}],
			["spawn", "merchant", "villager_man", [8, 12], "W"], ["spawn", "w1", "forest_wolf", [4, 13], "E", {"tint": "enemy", "alpha": 0.0}], ["spawn", "w2", "forest_wolf", [9, 14], "W", {"tint": "enemy", "alpha": 0.0}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["walk", "alaric", [7, 5], {"t": 0.5, "par": true}], ["walk", "bram", [8, 4], {"t": 0.5, "par": true}], ["walk", "lyra", [6, 4], {"t": 0.5, "par": true}],
			["walk", "merc", [9, 5], {"t": 0.5, "par": true}], ["walk", "gideon", [5, 5], {"t": 0.5, "par": true}], ["walk", "kaelen", [10, 4], {"t": 0.5, "par": true}], ["join"],
			["shake", 0.03, 0.8], ["bubble", "merchant", "!"], ["fadein", "w1", 0.8], ["fadein", "w2", 0.8], ["beat", "attack"],
			["say", "merchant", "MERCHANT", "Help! Somebody, please!"],  # DRAFT: the brief says only that a caravan is attacked
			["look", "alaric", "E"], ["wait", 0.5],
			["say", "alaric", "ALARIC", "Stay with me."],  # DRAFT
			["fade", 1.0, 1.0],
		],
	},
	"bw_road_post": {
		"id": "bw_road_post", "map": MAP_1, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8a860", 0.12, 0.1],
			["spawn", "alaric", "king", [7, 11], "E"], ["spawn", "bram", "warden", [8, 10], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 10], "E"],
			["spawn", "merc", "merc", [9, 11], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [5, 11], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [10, 10], "E", {"tint": "vessel"}],
			["spawn", "merchant", "villager_man", [7, 14], "W"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["walk", "merchant", [7, 13], {"t": 0.4}],
			["say", "merchant", "MERCHANT", "You saved everything I own. At least take something."],
			["say", "alaric", "ALARIC", "Keep it. You'll need it for repairs."],
			["look", "bram", "N"], ["wait", 0.4],
			["say", "bram", "BRAM", "You know, we're not exactly wealthy."],
			["say", "alaric", "ALARIC", "I noticed."],
			["say", "bram", "BRAM", "Just making sure."],
			["look", "merchant", "N"], ["wait", 0.6],
			["say", "merchant", "MERCHANT", "There's worse out at the old quarry. Things coming up out of it. Travelers have gone missing on that road."],  # DRAFT: the brief says he mentions creatures and missing travelers
			["say", "alaric", "ALARIC", "That's for the town watch."],  # DRAFT: "Alaric initially intends to leave the problem to the townspeople"
			["say", "merchant", "MERCHANT", "The watch is six men and a dog. And the children go up there to play."],  # DRAFT
			["wait", 0.8], ["look", "alaric", "N"], ["bubble", "alaric", "..."], ["beat", "concern"],
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 2: The Missing Children
	"bw_kids_pre": {
		"id": "bw_kids_pre", "map": MAP_2, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#a89070", 0.14, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "bram", "warden", "@captain", "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [5, 3], "E"],
			["spawn", "merc", "merc", [9, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [4, 2], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [10, 2], "E", {"tint": "vessel"}],
			["spawn", "mother", "villager_girl", [7, 6], "W"], ["spawn", "watchman", "villager_man", [8, 7], "W"],
			["fade", 0.0, 1.6], ["beat", "start"],
			["walk", "alaric", [7, 4], {"t": 0.5, "par": true}], ["walk", "bram", [8, 3], {"t": 0.5, "par": true}], ["walk", "lyra", [6, 3], {"t": 0.5, "par": true}], ["join"],
			["say", "watchman", "WATCHMAN", "Four children. The little one with the toy cart is among them."],  # DRAFT: the brief names the missing girl only in outline
			["say", "merc", "MERC", "The crossing opens tomorrow."],  # DRAFT: "the mountain crossing will reopen soon"
			["wait", 0.6], ["look", "alaric", "E"],
			["say", "alaric", "ALARIC", "Then it opens without us."],  # DRAFT: "He chooses to help anyway"
			["say", "bram", "BRAM", "Aye. Thought so."],  # DRAFT
			["fade", 1.0, 1.0],
		],
	},
	"bw_kids_post": {
		"id": "bw_kids_post", "map": MAP_2, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#a89070", 0.14, 0.1],
			["spawn", "alaric", "king", [7, 18], "E"], ["spawn", "bram", "warden", [8, 17], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 17], "E"],
			["spawn", "merc", "merc", [9, 18], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [5, 18], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [10, 17], "E", {"tint": "vessel"}],
			["spawn", "girl", "villager_girl", [5, 20], "E"], ["spawn", "kid1", "villager_kid", [6, 21], "E"], ["spawn", "kid2", "villager_kid", [4, 22], "S"],
			["fade", 0.0, 1.4], ["beat", "start"],
			["walk", "alaric", [6, 19], {"t": 0.5}], ["look", "girl", "E"], ["beat", "found"],
			["say", "girl", "GIRL", "I thought nobody was coming."],
			["say", "alaric", "ALARIC", "I said I'd fix your toy. Didn't say I was finished helping."],
			["wait", 0.6],
			["say", "girl", "GIRL", "Are you scared?"],
			["say", "alaric", "ALARIC", "A little."],
			["say", "girl", "GIRL", "You don't look scared."],
			["say", "alaric", "ALARIC", "That doesn't mean I'm not."],
			["wait", 0.8], ["look", "kid1", "N"], ["bubble", "kid1", "!"], ["shake", 0.02, 1.4], ["beat", "rumble"],
			["say", "kid1", "BOY", "Something big's been moving under the quarry. We heard it all night."],  # DRAFT: the brief says "the children reveal"
			["say", "kid2", "GIRL", "Grown-ups went in the mine and didn't come out."],  # DRAFT
			["look", "alaric", "N"], ["wait", 0.8],
			["say", "alaric", "ALARIC", "Take them back to town, Gideon."],  # DRAFT
			["say", "gideon", "GIDEON", "And you?"],  # DRAFT
			["say", "alaric", "ALARIC", "I'm going to look."],  # DRAFT: "Alaric decides to investigate"
			["fade", 1.0, 1.2],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 3: The Old Mine
	"bw_mine_pre": {
		"id": "bw_mine_pre", "map": MAP_3, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#4a3a2a", 0.28, 0.1],
			["spawn", "alaric", "king", [7, 2], "E"], ["spawn", "bram", "warden", [9, 2], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 1], "E"],
			["spawn", "merc", "merc", [10, 3], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [5, 2], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [8, 1], "E", {"tint": "vessel"}],
			["spawn", "miner", "villager_man", [8, 12], "W"], ["spawn", "fused", "crystalbound_warrior", [4, 12], "E", {"tint": "enemy", "alpha": 0.0}],
			["fade", 0.0, 1.8], ["beat", "start"],
			["walk", "alaric", [7, 5], {"t": 0.5, "par": true}], ["walk", "bram", [9, 4], {"t": 0.5, "par": true}], ["walk", "lyra", [6, 4], {"t": 0.5, "par": true}],
			["walk", "gideon", [5, 5], {"t": 0.5, "par": true}], ["walk", "kaelen", [8, 4], {"t": 0.5, "par": true}], ["walk", "merc", [10, 5], {"t": 0.5, "par": true}], ["join"],
			["fadein", "fused", 1.2], ["fx", "fused", "smoke", 1.0], ["shake", 0.03, 1.0], ["beat", "fused"],
			["say", "kaelen", "KAELEN", "Slowly. There's another way round: the left tunnel."],  # DRAFT: "Kaelen suggests finding a safer route"
			["bubble", "miner", "!"], ["look", "alaric", "E"], ["beat", "miner"],
			["walk", "alaric", [7, 8], {"t": 0.3, "anim": "run"}],
			["say", "gideon", "GIDEON", "Alaric, hold your position."],
			["say", "alaric", "ALARIC", "He's right there."],
			["say", "gideon", "GIDEON", "And so is the creature."],
			["say", "alaric", "ALARIC", "I can reach him."],
			["fade", 1.0, 1.0],
		],
	},
	"bw_mine_post": {
		"id": "bw_mine_post", "map": MAP_3, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#4a3a2a", 0.3, 0.1],
			["spawn", "alaric", "king", [7, 13], "E"], ["spawn", "bram", "warden", [8, 11], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 11], "E"],
			["spawn", "merc", "merc", [10, 12], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [5, 12], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [9, 10], "E", {"tint": "vessel"}],
			["spawn", "miner", "villager_man", [8, 14], "W"], ["spawn", "beast", "stone_colossus", [8, 22], "W", {"tint": "enemy", "alpha": 0.0}],
			["fade", 0.0, 1.4], ["beat", "start"],
			["walk", "alaric", [8, 13], {"t": 0.4}], ["act", "alaric", "attack"], ["fx", "alaric", "burst", 0.8], ["walk", "miner", [8, 11], {"t": 0.35, "anim": "run"}], ["beat", "saved"],
			["shake", 0.06, 1.6], ["red"], ["fadein", "beast", 0.6], ["cam", 12, 0.1], ["fx", "beast", "eruption", 2.2], ["beat", "creature"],
			["flash"], ["shake", 0.09, 1.0], ["hold", "alaric", "hit", 2], ["fx", "alaric", "burst", 1.6], ["wait", 0.8], ["hold", "alaric", "ko", 2], ["beat", "down"],
			["fadeout", "bram", 0.3], ["fadein", "bram", 0.3], ["fadeout", "merc", 0.3], ["fadein", "merc", 0.3], ["fadeout", "gideon", 0.3], ["fadein", "gideon", 0.3], ["fadeout", "kaelen", 0.3], ["fadein", "kaelen", 0.3], ["beat", "flicker"],
			["say", "bram", "BRAM", "Alaric?"],
			["say", "kaelen", "KAELEN", "Something's wrong."],
			["say", "gideon", "GIDEON", "He's losing the strength to sustain us."],
			["say", "bram", "BRAM", "Then get him out!"],
			["walk", "bram", [8, 12], {"t": 0.3, "anim": "run"}], ["fadeout", "bram", 0.25], ["fadein", "bram", 0.25], ["beat", "hand"],
			["say", "bram", "BRAM", "Come on, lad. Stay with us."],
			["fadeout", "merc", 0.8], ["fadeout", "kaelen", 0.8], ["fadeout", "gideon", 1.0], ["fadeout", "bram", 1.4], ["fx", "bram", "burst", 1.0], ["beat", "gone"],
			["wait", 0.8], ["walk", "lyra", [7, 12], {"t": 0.35, "anim": "run"}], ["look", "lyra", "S"], ["slide", "alaric", [6, 10]], ["slide", "lyra", [6, 9]], ["shake", 0.08, 1.6], ["fx", "beast", "eruption", 2.4], ["beat", "collapse"],
			["fade", 1.0, 1.4],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 4: The Empty Battlefield
	"bw_empty_pre": {
		"id": "bw_empty_pre", "map": MAP_4, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#2a2420", 0.34, 0.1],
			["spawn", "alaric", "king", "@king", "E"], ["spawn", "lyra", "mira", [7, 2], "E"],
			["fade", 0.0, 2.2], ["hold", "alaric", "ko", 2], ["beat", "start"],
			["wait", 1.4], ["play", "alaric", "idle"], ["look", "alaric", "E"], ["wait", 0.6],
			["say", "alaric", "ALARIC", "Bram."],
			["wait", 1.4], ["fx", "alaric", "circle", 1.2], ["wait", 0.8], ["bubble", "alaric", "..."], ["beat", "silence"],
			["say", "alaric", "ALARIC", "Bram!"],
			["say", "lyra", "LYRA", "You don't have the strength."],
			["say", "alaric", "ALARIC", "They're still inside."],
			["say", "lyra", "LYRA", "And we need to get you out."],
			["walk", "alaric", [6, 3], {"t": 0.7}], ["hold", "alaric", "hit", 3], ["wait", 0.6], ["play", "alaric", "idle"], ["beat", "struggle"],
			["fade", 1.0, 1.0],
		],
	},
	"bw_empty_post": {
		"id": "bw_empty_post", "map": MAP_4, "stage": [0, 0, 0, 0], "next": "bw_interlude",
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#2a2420", 0.3, 0.1],
			["spawn", "alaric", "king", [6, 14], "E"], ["spawn", "lyra", "mira", [7, 14], "E"],
			["fade", 0.0, 1.6], ["hold", "alaric", "hit", 2], ["beat", "start"],
			["walk", "lyra", [7, 13], {"t": 0.4}], ["look", "lyra", "N"],
			["say", "lyra", "LYRA", "Stop trying to do everything yourself."],
			["say", "alaric", "ALARIC", "I brought us here."],
			["say", "lyra", "LYRA", "And I chose to come."],
			["say", "alaric", "ALARIC", "You're the only one who can still fight."],
			["say", "lyra", "LYRA", "Then let me."],
			["wait", 1.2], ["beat", "accepts"],
			["play", "alaric", "idle"], ["walk", "lyra", [7, 8], {"t": 0.6, "par": true}], ["walk", "alaric", [6, 8], {"t": 0.8, "par": true}], ["join"], ["beat", "out"],
			["tint", "#e8d0a0", 0.2, 2.0],
			["fade", 1.0, 1.4],
		],
	},
	# ---------------------------------------------------------------------------------------------- interlude: the cost of relying on others
	"bw_interlude": {
		"id": "bw_interlude", "map": TOWN, "stage": [0, 0, 0, 0], "follow": [8, 16], "also_seen": ["bw_empty_post"],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8a860", 0.14, 0.1],
			["spawn", "alaric", "king", [10, 17], "W"], ["spawn", "lyra", "mira", [9, 19], "W"],
			["spawn", "bram", "warden", [8, 16], "E", {"tint": "vessel", "alpha": 0.0}], ["spawn", "gideon", "squire", [6, 15], "E", {"tint": "vessel", "alpha": 0.0}],
			["spawn", "merc", "merc", [7, 20], "E", {"tint": "vessel", "alpha": 0.0}], ["spawn", "kaelen", "choir", [5, 18], "E", {"tint": "vessel", "alpha": 0.0}],
			["fade", 0.0, 2.0], ["beat", "start"],
			["wait", 1.6], ["fx", "alaric", "circle", 1.4], ["flash"], ["fadein", "bram", 1.0], ["fx", "bram", "burst", 1.2], ["beat", "bram"],
			["walk", "bram", [9, 17], {"t": 0.4}], ["look", "bram", "E"],
			["say", "bram", "BRAM", "You gave us quite the scare."],
			["say", "alaric", "ALARIC", "I know."],
			["say", "bram", "BRAM", "Couldn't see a damned thing from the other side. One moment we're fighting, next moment we're gone."],
			["say", "alaric", "ALARIC", "I'm sorry."],
			["say", "bram", "BRAM", "For what? Getting hit? I've been doing that for years."],
			["say", "alaric", "ALARIC", "You couldn't help."],
			["wait", 0.8], ["look", "bram", "S"],
			["say", "bram", "BRAM", "Then next time, make sure you give us the chance."],
			["wait", 1.0], ["fadein", "merc", 0.6], ["fadein", "kaelen", 0.6], ["fadein", "gideon", 0.8], ["fx", "gideon", "burst", 1.0], ["beat", "gideon"],
			["walk", "gideon", [8, 16], {"t": 0.5}], ["look", "gideon", "E"], ["wait", 0.6],
			["say", "gideon", "GIDEON", "You ignored my warning."],
			["say", "alaric", "ALARIC", "I did."],
			["say", "gideon", "GIDEON", "You nearly got yourself killed."],
			["say", "alaric", "ALARIC", "I know."],
			["say", "gideon", "GIDEON", "Then learn from it."],
			["wait", 1.4], ["bubble", "alaric", "..."], ["beat", "no_argument"],
			["fade", 1.0, 1.4],
		],
	},
	# ---------------------------------------------------------------------------------------------- Battle 5: The Choice to Stay
	"bw_stay_pre": {
		"id": "bw_stay_pre", "map": MAP_5, "stage": [0, 0, 0, 0],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8a860", 0.12, 0.1],
			["spawn", "alaric", "king", [7, 8], "E"], ["spawn", "bram", "warden", [8, 7], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 7], "E"],
			["spawn", "merc", "merc", [9, 8], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [5, 8], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [10, 7], "E", {"tint": "vessel"}],
			["spawn", "titan", "stone_colossus", [7, 21], "W", {"tint": "enemy", "alpha": 0.0}], ["spawn", "villager", "villager_man", [8, 3], "S"],
			["fade", 0.0, 1.8], ["beat", "start"],
			["look", "bram", "E"],
			["say", "bram", "BRAM", "Road's open, lad."],
			["say", "alaric", "ALARIC", "I know."],
			["say", "bram", "BRAM", "King's still waiting."],
			["shake", 0.03, 1.4], ["look", "alaric", "W"], ["bubble", "villager", "!"], ["beat", "tremor"],
			["shake", 0.09, 1.6], ["red"], ["fadein", "titan", 1.2], ["fx", "titan", "eruption", 3.0], ["walk", "villager", [8, 0], {"t": 0.25, "anim": "run"}], ["beat", "emerges"],
			["look", "alaric", "W"], ["wait", 1.0],
			["say", "alaric", "ALARIC", "So are they."],
			["wait", 0.6], ["look", "bram", "S"],
			["say", "bram", "BRAM", "Thought you'd say that."],
			["say", "lyra", "LYRA", "Then let's not keep them waiting."],  # DRAFT
			["fade", 1.0, 1.0],
		],
	},
	"bw_stay_post": {
		"id": "bw_stay_post", "map": MAP_5, "stage": [0, 0, 0, 0], "next": "bw_festival",
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8a860", 0.2, 0.1],
			["spawn", "alaric", "king", [7, 16], "E"], ["spawn", "bram", "warden", [8, 15], "E", {"tint": "vessel"}], ["spawn", "lyra", "mira", [6, 15], "E"],
			["spawn", "merc", "merc", [9, 16], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [5, 16], "E", {"tint": "vessel"}], ["spawn", "kaelen", "choir", [10, 15], "E", {"tint": "vessel"}],
			["spawn", "v1", "villager_man", [7, 8], "E", {"alpha": 0.0}], ["spawn", "v2", "villager_girl", [6, 9], "E", {"alpha": 0.0}], ["spawn", "v3", "villager_kid", [8, 9], "E", {"alpha": 0.0}],
			["fade", 0.0, 1.6], ["beat", "start"],
			["wait", 1.0], ["fadein", "v1", 0.8], ["fadein", "v2", 0.8], ["fadein", "v3", 0.8],
			["walk", "v1", [7, 13], {"t": 0.4, "par": true}], ["walk", "v2", [6, 13], {"t": 0.4, "par": true}], ["walk", "v3", [8, 13], {"t": 0.35, "anim": "run", "par": true}], ["join"],
			["bubble", "v3", "!"], ["bubble", "v2", "~"], ["bubble", "v1", "~"], ["beat", "cheer"],
			["look", "alaric", "S"], ["wait", 1.0], ["bubble", "alaric", "..."],
			["say", "merc", "MERC", "That's the longest we've stayed anywhere."],  # DRAFT
			["say", "alaric", "ALARIC", "It was worth the delay."],  # DRAFT: "he does not regret staying"
			["fade", 1.0, 1.0],
		],
	},
	# ---------------------------------------------------------------------------------------------- final cutscene: a life he could have had
	"bw_festival": {
		"id": "bw_festival", "map": TOWN, "stage": [0, 0, 0, 0], "also_seen": ["bw_stay_post"], "follow": [8, 12],
		"steps": [
			["fade", 1.0, 0.0], ["bars", true], ["tint", "#e8a860", 0.16, 0.1],
			["spawn", "alaric", "king", [10, 17], "W"], ["spawn", "lyra", "mira", [9, 19], "W"],
			["spawn", "merc", "merc", [5, 5], "S", {"tint": "vessel"}], ["spawn", "bram", "warden", [9, 7], "S", {"tint": "vessel"}],
			["spawn", "kaelen", "choir", [4, 14], "E", {"tint": "vessel"}], ["spawn", "gideon", "squire", [6, 12], "E", {"tint": "vessel"}],
			["spawn", "girl", "villager_girl", [4, 20], "W"], ["spawn", "baker", "villager_man", [5, 9], "S"], ["spawn", "kid", "villager_kid", [7, 14], "E"], ["spawn", "kid2", "villager_kid", [4, 12], "N"],
			["fade", 0.0, 2.0], ["beat", "start"],
			["bubble", "merc", "~"], ["wait", 0.6], ["act", "kaelen", "attack"], ["bubble", "kid", "!"], ["wait", 0.6],
			["act", "gideon", "heavy"], ["fx", "gideon", "eruption", 1.2], ["bubble", "kid2", "!"], ["wait", 0.6],
			["say", "bram", "BRAM", "Who taught them to play that? A cat could do better."],  # DRAFT: "Bram complains about the music"
			["wait", 0.6], ["bubble", "lyra", "~"], ["tint", "#2a3a60", 0.26, 4.0], ["beat", "evening"],
			["wait", 1.2], ["walk", "girl", [[5, 18], [9, 18]], {"t": 0.5}], ["look", "girl", "E"], ["beat", "gift"],
			["say", "girl", "GIRL", "I made you something."],
			["say", "alaric", "ALARIC", "What is it?"],
			["say", "girl", "GIRL", "A knight."],
			["say", "alaric", "ALARIC", "I told you I'm not one."],
			["say", "girl", "GIRL", "You still look like one."],
			["wait", 0.8], ["say", "alaric", "ALARIC", "Thank you."],
			["walk", "girl", [[5, 18], [4, 20]], {"t": 0.5}], ["look", "lyra", "E"], ["walk", "lyra", [9, 17], {"t": 0.5}], ["beat", "lyra_sits"],
			["say", "lyra", "LYRA", "You saved them."],
			["say", "alaric", "ALARIC", "Not all of them."],
			["say", "lyra", "LYRA", "You couldn't have known what was waiting in the mine."],
			["say", "alaric", "ALARIC", "I should have listened to Gideon."],
			["say", "lyra", "LYRA", "You were afraid we'd lose time."],
			["say", "alaric", "ALARIC", "I was."],
			["wait", 1.0],
			["say", "lyra", "LYRA", "When we first met, I thought you never doubted yourself."],
			["say", "alaric", "ALARIC", "I doubt myself constantly."],
			["say", "lyra", "LYRA", "You hide it well."],
			["say", "alaric", "ALARIC", "I thought I had to."],
			["look", "lyra", "N"], ["wait", 0.8],
			["say", "lyra", "LYRA", "You don't have to hide everything from us."],
			["wait", 1.0], ["look", "alaric", "N"], ["beat", "watching"],
			["say", "alaric", "ALARIC", "I liked this place."],
			["say", "lyra", "LYRA", "Bellwether?"],
			["say", "alaric", "ALARIC", "Before everything happened, I would've wanted to live somewhere like this."],
			["say", "lyra", "LYRA", "Maybe one day you still can."],
			["wait", 1.6], ["bubble", "alaric", "..."], ["beat", "no_answer"],
			["tint", "#1c2a4a", 0.38, 3.0], ["fx", "lyra", "burst", 0.8], ["fx", "alaric", "streak", 1.0], ["fx", "merc", "burst", 1.0], ["fx", "bram", "burst", 1.0], ["beat", "lanterns"],
			["wait", 2.4],
			["title", "END OF CHAPTER FIVE", "The Man Behind the Summoner", 3.4],
			["fade", 1.0, 1.2],
		],
	},
}
