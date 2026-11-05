-- Survivors: the people living in the safehouse (vault: Lobby.md). PURE DATA.
-- Server/Map/Survivors places one figure per entry (Shared/ClassFigures, by Class) at Spot (lobby-relative
-- x, z) facing Face (x, z) with a name tag and a "Talk" prompt; Client/Controllers/SurvivorController
-- shows their Lines one at a time in a speech bubble, in order, starting from a random one.
-- Broadcasts are Overwatch's lore lines for the radio shack's "Listen in" (Server/Services/CommonsService).
-- Lore so far: the city is Port Harrow; the infection ("the Bloom") came up out of the ground under it;
-- Overwatch (Sgt. Voss) flies drops from a carrier offshore; the Grave Titans are what the Bloom grows
-- into given time. Keep new lines consistent with Config/Radio.

local Survivors = {}

Survivors.List = {
	{
		Id = "Rook",
		Name = "ROOK",
		Title = "Old-timer",
		Class = "Survivor",
		Spot = Vector2.new(13, 109),
		Face = Vector2.new(0, 100), -- the campfire
		Lines = {
			"I lived three streets off that square. Port Harrow had the best noodle stand on the coast.",
			"They call it the Bloom. Came up out of the storm drains one night and the city just... turned.",
			"Kills pay cash, waves pay more. Spend it every break. Cash does you no good in a body bag.",
			"Don't stand still out there. They come from every street at once. Keep your back to something.",
			"Sit a while. Fire's warm, couch is ugly, nobody here bites. Yet.",
		},
	},
	{
		Id = "Hale",
		Name = "DOC HALE",
		Title = "Medic",
		Class = "Medic",
		Spot = Vector2.new(-22, 100), -- between the mess tent and the fire, clear of the eave, sign and lights
		Face = Vector2.new(0, 100),
		Lines = {
			"Your body won't heal on its own out there. Clearing a wave patches everyone up. That's it.",
			"Press 2 mid-run for Vitality: more max health, and it tops you right up. Best money you'll spend.",
			"Fall in a fight and your squad keeps going? You're back on your feet when the next wave starts.",
			"Eat something. Beans again. It's always beans.",
			"I've seen what's under the square. Whatever the Titans are, the Bloom made them out of the people it took.",
		},
	},
	{
		Id = "Reyes",
		Name = "CPL. REYES",
		Title = "Radio operator",
		Class = "Scout",
		Spot = Vector2.new(35, 127), -- in front of the shack, clear of its roof
		Face = Vector2.new(34, 120),
		Lines = {
			"Overwatch is Sergeant Voss. Runs the drops from a carrier offshore. Never met him. Love the guy.",
			"Red smoke out there means a supply crate. Clear the guards and hold G. Could be cash, gems, or a buff.",
			"Pull up a chair by the radio and listen in. Voss tells the old stories when it's quiet.",
			"The Grave Titan shows up at the end of every run. Watch the ground: red rings and red lanes mean move.",
			"Port Harrow went dark on a Tuesday. I remember because the radio still had the weather on.",
		},
	},
	{
		Id = "Sparks",
		Name = "SPARKS",
		Title = "Mechanic",
		Class = "Engineer",
		Spot = Vector2.new(14, -50),
		Face = Vector2.new(0, -10), -- the plaza
		Lines = {
			"The Flight Line's through there. Stand on a pad: first one on is the host and picks the mission.",
			"Bring friends. A squad pad takes up to four, and full squads lift off in seconds.",
			"Press 1 mid-run to step up to your next gun. Pick which guns those are at the Armory, west tent.",
			"Every class has an E ability and an F ultimate. Kills charge the ultimate. Barracks, east side.",
			"Those helicopters run on duct tape and prayer. Mostly prayer.",
		},
	},
	{
		Id = "Mo",
		Name = "BIG MO",
		Title = "Bruiser",
		Class = "Bruiser",
		Spot = Vector2.new(-30, 124),
		Face = Vector2.new(-40, 140), -- the hoop
		Lines = {
			"Shoot some hoops. Keeps your aim honest between drops.",
			"Gems stay with you forever. Spend 'em on new guns and classes. Cash is just for the run.",
			"Check the board by the gate. Commendations pay out Gems for stuff you'd do anyway.",
			"Top Survivors board is over there. My name was on it once. Then Sparks hacked it. Allegedly.",
			"The Titan enrages at half health and calls in runners. That's when you stop being polite.",
		},
	},
}

Survivors.Broadcasts = {
	"Overwatch archive. Day one: we lost contact with Port Harrow at 0200. Last transmission was a scream and a song on loop.",
	"Overwatch archive. The Bloom spreads through the ground first, then the people. Don't drink the tap water. Don't drink any water.",
	"Overwatch archive. Seismic team says something big is moving under the city square. They called it a Titan. They called it, then they stopped calling.",
	"Overwatch to safehouse. Supply birds are on schedule. If you hear rotors, it's me. If you hear rotors and screaming, it's also me.",
	"Overwatch archive. The carrier can hold the coast for now. Every squad that comes back buys us another week.",
	"Overwatch to safehouse. Whoever keeps putting pineapple in the mess-tent beans: I can see you from orbit. I can't, but I'm watching.",
}

return Survivors
