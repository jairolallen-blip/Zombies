-- Tutorial: the first-time player's training run (vault: Lobby.md). PURE DATA.
-- New players (profile TutorialDone = false) are sent straight into it instead of the lobby
-- (QueueService). It's a normal run with fewer waves and a weaker boss, and Overwatch walks them
-- through one mechanic at a time (Server/Services/TutorialService):
--   each step shows an objective card (Client/Controllers/TutorialController) and says its radio line
--   when the run reaches its Start (wave number + phase "Break" or "Wave"; phase "Results" = the end,
--   any wave).
--   Steps run in order: a step whose Start comes when the one before isn't done yet waits for it,
--   unless its Start is a later wave or phase, then the unfinished one is dropped.
--   Delay (optional) holds the radio line and objective that many seconds.
--   Done names a check in TutorialService ("WaveCleared", "Upgraded", "Vitality", "Ability",
--   "Airdrop", "Ultimate", "RunOver"); Setup names a helper that runs when the step starts
--   ("CashForUpgrade", "CashForVitality", "DropCrate", "FillUltimate").

local Tutorial = {}

Tutorial.Waves = 5 -- the last one is the boss wave
Tutorial.BossHealthMult = 0.25 -- the "young" Titan: a quarter of the real one's health
Tutorial.RewardGems = 350 -- enough for the cheapest class (Scout) right away; paid instead of the normal end-of-run Gems, win or lose
Tutorial.ResultsTime = 12 -- seconds on the results screen (time for the last radio line) before the lobby

Tutorial.Steps = {
	{
		Start = { 1, "Break" },
		Objective = "Survive wave 1. Click to shoot, R to reload",
		Say = "Rookie, this is Overwatch. Infected incoming. Click to shoot, R to reload. Every kill pays cash, the green number.",
		Done = "WaveCleared",
	},
	{
		Start = { 2, "Break" },
		Objective = "Upgrade your gun: press 1",
		Say = "Cash buys upgrades mid-run. I've wired you enough: press 1 to swap to your next, stronger gun.",
		Setup = "CashForUpgrade",
		Done = "Upgraded",
	},
	{
		Start = { 2, "Break" },
		Objective = "Buy Vitality: press 2",
		Say = "Health never comes back on its own. Press 2 for Vitality: more max health and a full heal.",
		Setup = "CashForVitality",
		Done = "Vitality",
	},
	{
		Start = { 2, "Wave" },
		Objective = "Use your class ability: press E",
		Say = "Every class has an ability. Press E to use yours, then it recharges.",
		Done = "Ability",
	},
	{
		Start = { 3, "Wave" },
		Objective = "Supply drop! Reach the red smoke and hold G",
		Say = "Dropping you a crate. Follow the red smoke, clear the guards and hold G to open it. Crates hold buffs, cash or Gems.",
		Setup = "DropCrate",
		Done = "Airdrop",
	},
	{
		Start = { 4, "Wave" },
		Objective = "Your ultimate is charged: press F",
		Say = "Kills charge your ultimate. I've topped yours off: hit F and watch them drop.",
		Setup = "FillUltimate",
		Done = "Ultimate",
	},
	{
		Start = { 5, "Wave" },
		Delay = 8, -- after the boss entrance cutscene (Zombies GraveTitan Intro.Time)
		Objective = "Take down the young Titan. Dodge the red rings and lanes",
		Say = "That's a young Titan. A full-grown one waits at the end of every real run. Stay out of the red and keep shooting!",
		Done = "RunOver",
	},
	{
		Start = { 0, "Results" }, -- the run is over, however far they got
		Objective = "Training complete! Spend your Gems at the Armory and Barracks",
		Say = "Gems are yours to keep. Spend them at the safehouse on new guns and classes. Then pick a pad on the Flight Line and bring friends.",
	},
}

return Tutorial
