# Hezké 3D modely – návod a seznam

Hra funguje i bez nich (používá modely z kostek). Každý model, který přidáš, hra **sama** použije místo kostek a sama ho zmenší na správnou velikost.

## Jak vygenerovat model v Roblox Studiu

1. Otevři hru ve Studiu (File → Open from File → `SlipperJump.rbxl`).
2. Otevři **Assistant**: tlačítko s hvězdičkou/bublinou vpravo nahoře, nebo menu **Window → Assistant**.
3. Napiš do Assistanta anglicky třeba:
   `Generate a 3D model: a single golden high-top sneaker with diamonds, cartoon toy style`
   (popisy máš v tabulkách níž – stačí zkopírovat).
4. Assistant model vytvoří ve světě (Workspace). Když se ti nelíbí, nech vygenerovat znovu.
5. V okně **Explorer** (vpravo) model najdi, klikni na něj pravým → **Rename** a pojmenuj ho **přesně** podle sloupce „Název“ (velká a malá písmena se počítají!).
6. Přetáhni ho myší v Exploreru do složky **ReplicatedStorage → Assets → správná složka** (Slippers / Hats / Items).
7. Zmáčkni **Play** – hra použije nový model.

**Pantofle a tenisky:** generuj vždy **jednu** botu (levá a pravá se udělají samy).
Když bota na noze míří bokem nebo dozadu, klikni na model v Assets, ve **Properties** dole klikni **Add Attribute**,
název `RotateY`, typ **Number**, hodnota `90` (nebo `-90` / `180`) a zkus znovu Play.

**Když Assistant generování modelů nemá:** stejné popisy funguje i na webech jako **meshy.ai** nebo **tripo3d.ai**
(stáhni jako `.fbx` nebo `.obj`, ve Studiu **Home → Import 3D**, pak bod 5 a 6).
Nebo v **Toolboxu** (vlevo) najdi zdarma model a použij ho – jen zkontroluj, že uvnitř nemá skripty.

**Tip:** začni boty, které hráči vidí nejčastěji: prvních 5 pantoflí a prvních 5 tenisek.


## Už hotové modely (z dílů, v projektu)

Těchto 10 bot už je ve hře jako modely z dílů (soubory `assets/Slippers/*.model.json`, vyrábí je `python3 tools/shoes.py`):
BasicBlackSlippers, BeachBlueSlippers, WatermelonSlippers, SharkSlippers, RoyalDiamondSlippers,
MuddyOldSneakers, CanvasKicks, StreetRunners, SkyDunkLegends, GoldenAirKings.

Když místo nich chceš AI model z Assistanta: ve Studiu nejdřív **smaž** starý model se stejným jménem
ve složce `ReplicatedStorage → Assets → Slippers`, jinak hra může vzít ten starý.

## Pantofle (20) → složka `Assets/Slippers`

| # | Název (přesně) | Popis pro AI (zkopíruj) |
| --- | --- | --- |
| 1 | `BasicBlackSlippers` | a single basic black slipper (house slipper), bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 2 | `BeachBlueSlippers` | a single beach blue slipper (house slipper), water drops theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 3 | `WatermelonSlippers` | a single watermelon slipper (house slipper), seeds theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 4 | `FluffyBunnySlippers` | a single fluffy bunny slipper (house slipper), fluff theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 5 | `SharkSlippers` | a single shark slipper (house slipper), shark fin in the water theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 6 | `RubberDuckSlippers` | a single rubber duck slipper (house slipper), duck squeaks theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 7 | `PineappleSlippers` | a single pineapple slipper (house slipper), pineapple leaves theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 8 | `PenguinSlippers` | a single penguin slipper (house slipper), snowflakes theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 9 | `RainbowSlippers` | a single rainbow slipper (house slipper), rainbow trail theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 10 | `GoldenSlippers` | a single golden slipper (house slipper), golden sparks theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 11 | `SpringSlippers` | a single spring slipper (house slipper), \ theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 12 | `RocketSlippers` | a single rocket slipper (house slipper), rocket smoke theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 13 | `DinoSlippers` | a single dino slipper (house slipper), dino footprints theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 14 | `CrystalSlippers` | a single crystal slipper (house slipper), sparkling crystals theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 15 | `LavaSlippers` | a single lava slipper (house slipper), steam over the water theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 16 | `CloudWingSlippers` | a single cloud wing slipper (house slipper), little clouds theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 17 | `RobotSlippers` | a single robot slipper (house slipper), blinking leds theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 18 | `GalaxySlippers` | a single galaxy slipper (house slipper), stars and planets theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 19 | `DragonSlippers` | a single dragon slipper (house slipper), cute little flames theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 20 | `RoyalDiamondSlippers` | a single royal diamond slipper (house slipper), crown and confetti theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |

## Tenisky (20) → složka `Assets/Slippers`

| # | Název (přesně) | Popis pro AI (zkopíruj) |
| --- | --- | --- |
| 1 | `MuddyOldSneakers` | a single sneaker called "Muddy Old Sneakers", smells a bit... theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 2 | `TapedUpTrainers` | a single sneaker called "Taped-Up Trainers", held together by tape theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 3 | `CanvasKicks` | a single sneaker called "Canvas Kicks", classic canvas theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 4 | `StreetRunners` | a single sneaker called "Street Runners", dust clouds theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 5 | `SkateLows` | a single sneaker called "Skate Lows", skater sparks theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 6 | `CourtClassics` | a single sneaker called "Court Classics", court squeak theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 7 | `NeonSprinters` | a single sneaker called "Neon Sprinters", neon streaks theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 8 | `GraffitiHighTops` | a single sneaker called "Graffiti High-Tops", spray paint dots theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 9 | `LightningLows` | a single sneaker called "Lightning Lows", lightning trail theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 10 | `IceBreakers` | a single sneaker called "Ice Breakers", frosty sparks theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 11 | `RocketBoosters` | a single sneaker called "Rocket Boosters", booster pop theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 12 | `LavaStompers` | a single sneaker called "Lava Stompers", smoking soles theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 13 | `ThunderDunks` | a single sneaker called "Thunder Dunks", thunder steps theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 14 | `CrystalCourts` | a single sneaker called "Crystal Courts", crystal shards theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 15 | `GalaxyRunners` | a single sneaker called "Galaxy Runners", nebula mist theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 16 | `CyberSteppers` | a single sneaker called "Cyber Steppers", glowing circuits theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 17 | `DragonScaleHighs` | a single sneaker called "Dragon Scale Highs", dragon breath theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 18 | `PhantomGlides` | a single sneaker called "Phantom Glides", ghostly stars theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 19 | `SkyDunkLegends` | a single sneaker called "Sky Dunk Legends", legendary flames theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 20 | `GoldenAirKings` | a single sneaker called "Golden Air Kings", gold and diamonds theme, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |

## Čepice (23) → složka `Assets/Hats`

| # | Název (přesně) | Popis pro AI (zkopíruj) |
| --- | --- | --- |
| 1 | `BaseballCap` | a baseball cap for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 2 | `StrawHat` | a straw hat for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 3 | `SwimCap` | a swim cap for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 4 | `DivingGoggles` | a diving goggles for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 5 | `FishingHat` | a fishing hat for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 6 | `PropellerCap` | a propeller cap for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 7 | `ChefHat` | a chef hat for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 8 | `CowboyHat` | a cowboy hat for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 9 | `SharkHood` | a shark hood for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 10 | `FlowerCrown` | a flower crown for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 11 | `WizardHat` | a wizard hat for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 12 | `KnightHelmet` | a knight helmet for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 13 | `VikingHelmet` | a viking helmet for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 14 | `AstronautHelmet` | a astronaut helmet for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 15 | `OctopusBuddy` | a octopus buddy for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 16 | `Halo` | a halo for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 17 | `DragonHorns` | a dragon horns for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 18 | `RainbowWig` | a rainbow wig for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 19 | `IceCrown` | a ice crown for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 20 | `SeaKingCrown` | a sea king crown for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 21 | `CaptainHat` | a captain hat for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 22 | `PirateHat` | a pirate hat for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 23 | `GoldenBowHat` | a golden bow hat for a Roblox character head, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |

## Předměty z vody (32) → složka `Assets/Items`

| # | Název (přesně) | Popis pro AI (zkopíruj) |
| --- | --- | --- |
| 1 | `Seashell` | a cute seashell, common treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 2 | `Pebble` | a cute pebble, common treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 3 | `PlasticShovel` | a cute plastic shovel, common treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 4 | `OldSock` | a cute old sock, common treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 5 | `Seaweed` | a cute seaweed, common treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 6 | `Starfish` | a cute starfish, uncommon treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 7 | `RubberDuck` | a cute rubber duck, uncommon treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 8 | `SandBucket` | a cute sand bucket, uncommon treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 9 | `SwimRing` | a cute swim ring, uncommon treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 10 | `BeachUmbrella` | a cute beach umbrella, uncommon treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 11 | `MessageInABottle` | a cute message in a bottle, rare treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 12 | `Pearl` | a cute pearl, rare treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 13 | `CrabInAHat` | a cute crab in a hat, rare treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 14 | `GoldfishInABag` | a cute goldfish in a bag, rare treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 15 | `Compass` | a cute compass, rare treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 16 | `CoinChest` | a cute coin chest, epic treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 17 | `ShipInABottle` | a cute ship in a bottle, epic treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 18 | `OctopusWithGlasses` | a cute octopus with glasses, epic treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 19 | `DolphinStatue` | a cute dolphin statue, epic treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 20 | `Trident` | a cute trident, epic treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 21 | `PirateMap` | a cute pirate map, legendary treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 22 | `GoldenAnchor` | a cute golden anchor, legendary treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 23 | `GlowingJellyfish` | a cute glowing jellyfish, legendary treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 24 | `FishKingCrown` | a cute fish king crown, legendary treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 25 | `MermaidStatue` | a cute mermaid statue, legendary treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 26 | `SeaDragonEgg` | a cute sea dragon egg, mythic treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 27 | `RainbowPearl` | a cute rainbow pearl, mythic treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 28 | `PlushKraken` | a cute plush kraken, mythic treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 29 | `WaterUnicorn` | a cute water unicorn, secret treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 30 | `DeepSeaUFO` | a cute deep sea ufo, secret treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 31 | `MegaSplashDuck` | a cute mega splash duck, secret treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
| 32 | `GoldenSplash` | a cute golden splash, secret treasure from the sea, bold stylized cartoon game asset, oversized chunky proportions, thick sole, vibrant saturated colors, glossy, eye-catching, no text, no logos |
