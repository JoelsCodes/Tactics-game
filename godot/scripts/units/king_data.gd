class_name KingData
extends UnitData
## The King: the Commander. Exactly one leads every battle, with up to PartyRoster.PARTY_SIZE of his companions beside him (PartyRoster.party).


func role() -> Role:
	return Role.KING
