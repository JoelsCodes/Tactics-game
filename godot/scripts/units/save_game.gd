class_name SaveGame
extends RefCounted
## Everything that is saved: the party roster (leaders, vessels, loadouts, skills, relic inventory,
## active squad) and the campaign tracking. SaveCodec turns it into data, SaveSystem into files.

var roster: PartyRoster
var campaign := CampaignState.new()
var saved_at := 0  ## unix time of the last save


## A fresh game. `party` defaults to the placeholder SampleParty until there is a real start.
static func new_game(party: PartyRoster = null) -> SaveGame:
	var g := SaveGame.new()
	g.roster = party if party != null else SampleParty.make()
	return g
