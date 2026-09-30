# Slipper Jump! – herní zadání pro Roblox (Claude Code)

## Název a pitch

Název hry: **Slipper Jump!** Celá hra je v angličtině. Hráč skáče v pantoflích z mola do dlouhé vody, sbírá věci, kupuje lepší pantofle a snaží se doskočit až k obřímu dárku na konci.

Záložní názvy: Slipper Splash!, Slipper Jump Simulator, Pier Leap!, Mega Splash, Slipper Tycoon, Flying Slippers.

| Parametr | Hodnota |
| --- | --- |
| Platforma | Roblox (Roblox Studio, Luau) |
| Žánr | Simulator + tycoon (skákání, sbírání, pasivní příjem) |
| Věk | 8+, jednoduché ovládání, žádné násilí |
| Hráči | 1–8 na server, společný svět |
| Jazyk hry | Angličtina (všechny texty, názvy a UI ve hře) |
| Délka session | 10–30 minut, s důvodem se vracet (denní spinner, pasivní příjem) |

## Herní smyčka

Skok z mola (pantofle určují délku) → předmět z vody (čím dál, tím vzácnější) → domeček (10 míst, vydělává $ za sekundu) → stánek SHOP (lepší pantofle a čepice) → zase skok, tentokrát dál. Kdo doskočí na 100 000 studů, dostane obří dárek a může se znovuzrodit (Rebirth) s trvalým bonusem +50 % příjmu.

Hráč skáče, sbírá předměty, ty mu v domečku vydělávají a za peníze kupuje lepší pantofle a čepice, takže doskočí dál. Kdo doskočí k dárku, může se znovuzrodit a hrát s trvalým bonusem.

## Skok: síla, let a žebříček

Skok není jen zmáčknutí tlačítka. Hráč ovlivní, jak daleko doletí, a let ho zabaví.

**Síla skoku:** když hráč doběhne na konec mola a drží tlačítko JUMP, nad hlavou se mu plní ukazatel, který jezdí nahoru a dolů. Podle toho, kdy tlačítko pustí, dostane bonus:

| Zásah | Bonus ke vzdálenosti | Co se ukáže |
| --- | --- | --- |
| Mimo zónu | žádný | – |
| Good (žlutá zóna) | +10 % | „GOOD!“ |
| Perfect (úzká zelená zóna nahoře) | +25 % | „PERFECT!“ + konfety |

Za špatné načasování se nic nestrhává, aby to děti nemrzelo.

**Let:** ve vzduchu hráč nakláněním doleva a doprava (A/D, šipky, joystick na mobilu) uhýbá v rámci koridoru. Nad vodou visí řady mincí (každá mince = příjem domečku za 1 sekundu) a zlaté kruhy (každý +5 % ke vzdálenosti). Rozmístění mincí a kruhů určuje server a server také kontroluje, co hráč opravdu posbíral.

**Dárek jen s nejlepšími pantoflemi:** bonusy dohromady by jinak dovolily doletět k dárku i s horšími pantoflemi. Bez Royal Diamond Slippers je proto skok omezen na 95 000 studů. K dárku (100 000) se dostane jen hráč s nejlepšími pantoflemi.

**Žebříček:** na pláži u spawnu stojí velká tabule se dvěma žebříčky: nejdelší skoky na serveru dnes a nejdelší skoky všech hráčů celkově (OrderedDataStore). Hráč, který zrovna překoná rekord serveru, dostane hlášku pro všechny na serveru.

## Mapa světa

Svět je jedna dlouhá rovná osa: pláž a molo vpředu, voda táhnoucí se 100 000 studů dozadu, obří dárek na konci. Vše ostatní stojí na pláži vedle mola.

- **Pláž (spawn):** písek, palmy, deštníky. Hráč se objeví tady.
- **Molo:** dřevěné, 150 studů dlouhé, jen obyčejné dřevěné, nic na něm není (žádné odrazové prkno, pružina ani cedule). Hráč se rozběhne a skočí z konce mola.
- **Voda (skokový koridor):** 100 000 studů, rozdělená na 5 barevných zón (od světle tyrkysové po tmavě modrou). Koridor je po obou stranách ohraničený řadou bójek. Na každé značce vzdálenosti vede přes koridor napříč provaz s bójkami, takže je vidět, kam hráč doskočil. Značky jsou čím dál řidší: do 1 000 studů po 100 (100, 200 … 1 000), do 10 000 po 500 (1 500, 2 000 … 10 000), do 20 000 po 1 000 (11 000 … 20 000) a do 100 000 po 10 000 (30 000 … 100 000). Čím dál, tím vzácnější věci ve vodě.
- **Obří dárek:** na plovoucím ostrůvku na 100 000 studech. Je obrovský (300 studů vysoký), zlatý s červenou mašlí, a z něj míří do nebe svítící paprsek světla, aby byl vidět z mola i přes celou vodu.
- **Stánek SHOP:** dřevěný stánek s pruhovanou markýzou a velkým nápisem SHOP. Prodává pantofle (Slippers) a čepice (Hats).
- **Stánek SELL:** hned vedle, jiná barva markýzy, nápis SELL. Tady se prodávají věci z domečku.
- **Kolo štěstí (spinner):** velké kolo na podstavci u spawnu.
- **Domečky:** řada 8 plážových domečků v dolní části mapy, 4 vlevo a 4 vpravo, uprostřed mezi nimi volná cesta na molo (jeden na hráče na serveru). Každý je dlouhý obdélník táhnoucí se dozadu od pláže, vpředu široký otevřený vchod bez dveří. Nad vchodem je jméno hráče. Vnitřek popisuje sekce Domeček.
- **Robux obchod:** není fyzický stánek, otevírá se tlačítkem s košíkem v UI.

## Pantofle – Slippers (20 kusů)

Pantofle určují délku skoku: vzdálenost = 100 studů × násobič pantoflí × bonus čepice. Každé další pantofle skočí zhruba o polovinu dál než předchozí, takže hráč doskakuje dál a dál. K dárku na 100 000 studů doskočí až s posledními pantoflemi (Royal Diamond Slippers); ani nejlepší čepice nestačí, aby tam hráč doskočil s horšími. Ceny jsou v herních dolarech ($), každé pantofle mají vlastní stopu (trail) při letu.

| # | Slippers (ve hře) | Česky | Cena ($) | Násobič | Skok bez bonusů (studů) | Efekt při letu |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Basic Black Slippers | obyčejné černé | zdarma | 1× | 100 | žádný |
| 2 | Beach Blue Slippers | plážové modré | 100 | 1,5× | 150 | kapičky vody |
| 3 | Watermelon Slippers | melounové | 350 | 2× | 200 | semínka |
| 4 | Fluffy Bunny Slippers | chlupaté králíčkové | 800 | 3× | 300 | chmýří |
| 5 | Shark Slippers | žraločí | 2 000 | 4,5× | 450 | žraločí ploutev ve vodě |
| 6 | Rubber Duck Slippers | kachničkové | 4 500 | 6× | 600 | pískání kachničky |
| 7 | Pineapple Slippers | ananasové | 9 000 | 9× | 900 | lístky ananasu |
| 8 | Penguin Slippers | tučňákové | 18 000 | 13× | 1 300 | sněhové vločky |
| 9 | Rainbow Slippers | duhové | 35 000 | 18× | 1 800 | duhová stopa |
| 10 | Golden Slippers | pozlacené | 70 000 | 26× | 2 600 | zlaté jiskry |
| 11 | Spring Slippers | s pružinkou dole | 140 000 | 38× | 3 800 | zvuk „boing“ při odrazu |
| 12 | Rocket Slippers | raketové | 280 000 | 55× | 5 500 | kouř z trysek |
| 13 | Dino Slippers | dinosauří | 550 000 | 78× | 7 800 | stopy dinosaura |
| 14 | Crystal Slippers | křišťálové | 1 100 000 | 110× | 11 000 | třpytivé krystaly |
| 15 | Lava Slippers | lávové | 2 200 000 | 160× | 16 000 | pára nad vodou |
| 16 | Cloud Wing Slippers | obláčkové s křidélky | 4 500 000 | 230× | 23 000 | mráčky |
| 17 | Robot Slippers | robotí | 9 000 000 | 340× | 34 000 | blikající LED |
| 18 | Galaxy Slippers | vesmírné | 18 000 000 | 480× | 48 000 | hvězdičky a planety |
| 19 | Dragon Slippers | dračí | 40 000 000 | 650× | 65 000 | roztomilé plamínky |
| 20 | Royal Diamond Slippers | diamantové královské | 100 000 000 | 1 000× | 100 000 | koruna a konfety |

Pantofle se nosí na avataru (viditelné pro ostatní). Koupené pantofle zůstávají navždy, hráč si v inventáři vybírá, které má obuté.

## Předměty z vody a rarity

Každý skok dá jeden předmět, který vyplave v místě dopadu. Předmět vydělává peníze každou sekundu, když leží v domečku. Čím dál hráč doskočí, tím vyšší šance na vzácné věci.

| Rarita | Barva rámečku | Příjem ($/s) | Prodejní cena |
| --- | --- | --- | --- |
| Common | šedá | 1–3 | 10× příjem/s |
| Uncommon | zelená | 5–10 | 10× příjem/s |
| Rare | modrá | 20–50 | 10× příjem/s |
| Epic | fialová | 100–250 | 10× příjem/s |
| Legendary | zlatá | 500–1 500 | 10× příjem/s |
| Mythic | růžová, pulzuje | 3 000–8 000 | 10× příjem/s |
| Secret | černá s duhovou září | 20 000–50 000 | 10× příjem/s |

### Šance podle místa dopadu

| Zóna (dopad ve studech) | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1: 0–999 | 80 % | 18 % | 2 % | – | – | – | – |
| 2: 1 000–4 999 | 50 % | 35 % | 12 % | 3 % | – | – | – |
| 3: 5 000–19 999 | 25 % | 35 % | 28 % | 10 % | 2 % | – | – |
| 4: 20 000–59 999 | 10 % | 25 % | 35 % | 22 % | 7,5 % | 0,5 % | – |
| 5: 60 000–100 000 | – | 10 % | 30 % | 35 % | 20 % | 4,9 % | 0,1 % |

### Seznam předmětů

- **Common:** Seashell, Pebble, Plastic Shovel, Old Sock, Seaweed
- **Uncommon:** Starfish, Rubber Duck, Sand Bucket, Swim Ring, Beach Umbrella
- **Rare:** Message in a Bottle, Pearl, Crab in a Hat, Goldfish in a Bag, Compass
- **Epic:** Coin Chest, Ship in a Bottle, Octopus with Glasses, Dolphin Statue, Trident
- **Legendary:** Pirate Map, Golden Anchor, Glowing Jellyfish, Fish King Crown, Mermaid Statue
- **Mythic:** Sea Dragon Egg, Rainbow Pearl, Plush Kraken
- **Secret:** Water Unicorn, Deep Sea UFO, Mega Splash Duck (název a vzhled se neukazují, dokud je někdo nenajde, v katalogu je jen „???“)

## Domeček, prodej a darování

Každý hráč má dlouhý obdélníkový domeček s otevřeným vchodem (bez dveří). Uvnitř je 10 čtvercových podstavců: 5 podél levé stěny a 5 naproti podél pravé, uprostřed ulička. Nad každým podstavcem se vznáší a pomalu točí předmět a nad ním cedulka, kolik vydělává (např. „+$25/s“). Peníze se sčítají do kasičky u vchodu; hráč je vybere, když kolem ní projde.

**Zelené teleportační kolečko:** na podlaze u zadní stěny domečku svítí zelený kruh. Když na něj hráč stoupne, přenese se ke stánku SELL. Hodí se, když nese předmět nad hlavou a chce ho rychle prodat.

**Nový předmět po skoku:** automaticky se položí na první volný podstavec. Když je plno, hráč ho drží nad hlavou a musí se rozhodnout: vyměnit za slabší věc v domečku, prodat, nebo darovat.

**Zvednutí předmětu (Pick):** hráč přijde k podstavci, objeví se výzva „Hold E – Pick Up“ (na mobilu tlačítko). Po 1 sekundě držení nese předmět nad hlavou (obě ruce nahoře, předmět se jemně vznáší a točí).

**Prodej:** s předmětem nad hlavou jde ke stánku SELL a podrží „Sell“. Dostane 10× příjem/s předmětu. Vzácnost Legendary a vyšší se ptá „Are you sure you want to sell this?“.

**Darování:** s předmětem nad hlavou přijde k jinému hráči a podrží „Gift“. Druhý hráč dostane okno „PlayerX wants to give you Y. Accept / Decline“. Pravidla proti zneužívání:

- darovat se dá jen hráčům na stejném serveru,
- obdarovaný musí mít volné místo v domečku,
- limit 20 darů za den, aby nešlo předměty „farmit“ přes alt účty,
- darování je jednosměrné (žádné obchodování za Robux).

**Rozšíření domečku:** podstavce 11–20 se kupují za $ (viz levely) nebo game passem.

## Obří dárek – cíl hry

Kdo doskočí na 100 000 studů, dopadne na ostrůvek s dárkem. Dárek se roztrhne, vybuchnou konfety a celý server uvidí hlášku „PlayerX reached the Giant Gift!“.

Obsah dárku při prvním doskoku:

- **Golden Splash** – unikátní předmět (Secret, 100 000 $/s), nedá se prodat ani darovat,
- **1 000 000 $** hotově,
- **titulek nad hlavou** „Pier Master“,
- **Golden Bow Hat** (kosmetika, jen odsud).

**Znovuzrození (Rebirth):** po otevření dárku se objeví tlačítko Rebirth. Hráč přijde o pantofle a peníze (začne s Basic Black Slippers), ale předměty v domečku mu zůstanou a dostane trvale +50 % ke všemu příjmu. Každé znovuzrození změní barvu dárku (zlatá → stříbrná → duhová …) a dá nový titulek. Tím má hra konec i důvod hrát dál.

Další doskoky k dárku bez znovuzrození dávají 100 000 $ a zaručený Legendary předmět.

## Levely a odměny

Hra má 50 levelů. Zkušenosti (XP) se sbírají skoky: XP za skok = 10 + vzdálenost ÷ 1 000, zaokrouhleno dolů (skok na 100 studů = 10 XP, na 100 000 studů = 110 XP). XP potřebné na další level = 100 × aktuální level.

Za každý level hráč dostane 100 $ × číslo levelu (level 7 = 700 $). Navíc jsou milníky:

| Level | Odměna navíc |
| --- | --- |
| 5 | 1 extra točení spinneru |
| 10 | 11. podstavec v domečku |
| 15 | čepice Captain Hat |
| 20 | 12. podstavec + 2 točení |
| 25 | zaručený Epic předmět |
| 30 | 13. podstavec |
| 35 | čepice Pirate Hat |
| 40 | 14. a 15. podstavec |
| 45 | zaručený Legendary předmět |
| 50 | titulek „Pier Legend“ + 16. podstavec |

Level se ukazuje nad hlavou hráče vedle jména. Level se při znovuzrození neresetuje.

## Denní spinner

Každý hráč má 1 točení zdarma každých 24 hodin (počítá se od posledního točení, časovač je vidět na kole). Kolo má 8 barevných dílků:

| Dílek (ve hře) | Šance |
| --- | --- |
| $500 | 25 % |
| $2,000 | 20 % |
| Uncommon Item | 18 % |
| Rare Item | 15 % |
| 2x Money (15 min) | 10 % |
| $10,000 | 7 % |
| Epic Item | 4 % |
| Legendary Item | 1 % |

Peněžní odměny se násobí levelem hráče ÷ 5 (minimálně 1×), aby spinner zůstal zajímavý i později. Šance musí být vidět přímo u kola (tlačítko „i“), protože Roblox vyžaduje zobrazit šance u všech náhodných odměn, za které se dá platit Robuxy (extra točení).

## Čepice (20 kusů)

Druhá věc, kterou hráči kupují za $, jsou čepice na hlavu. Každá dává bonus buď k délce skoku, nebo k příjmu z domečku, takže si hráč vybírá styl hraní. Nosí se vždy jen jedna. Prodávají se ve stánku SHOP na druhé záložce.

| # | Hat (ve hře) | Česky | Cena ($) | Bonus |
| --- | --- | --- | --- | --- |
| 1 | Baseball Cap | kšiltovka | 500 | +2 % skok |
| 2 | Straw Hat | slaměný klobouk | 1 500 | +2 % příjem |
| 3 | Swim Cap | plavecká čepice | 4 000 | +4 % skok |
| 4 | Diving Goggles | potápěčské brýle | 10 000 | +5 % příjem |
| 5 | Fishing Hat | rybářský klobouk | 25 000 | +6 % skok |
| 6 | Propeller Cap | čepice s vrtulkou | 60 000 | +8 % skok |
| 7 | Chef Hat | kuchařská čepice | 120 000 | +8 % příjem |
| 8 | Cowboy Hat | kovbojský klobouk | 250 000 | +10 % skok |
| 9 | Shark Hood | žraločí kapuce | 500 000 | +12 % příjem |
| 10 | Flower Crown | věnec z květin | 1 000 000 | +12 % skok |
| 11 | Wizard Hat | kouzelnický klobouk | 2 000 000 | +15 % příjem |
| 12 | Knight Helmet | rytířská helma | 4 000 000 | +15 % skok |
| 13 | Viking Helmet | vikingská helma | 8 000 000 | +18 % příjem |
| 14 | Astronaut Helmet | astronautská helma | 15 000 000 | +20 % skok |
| 15 | Octopus Buddy | chobotnička na hlavě | 25 000 000 | +22 % příjem |
| 16 | Halo | svatozář | 40 000 000 | +25 % skok |
| 17 | Dragon Horns | dračí rohy | 60 000 000 | +28 % příjem |
| 18 | Rainbow Wig | duhová paruka | 90 000 000 | +30 % skok |
| 19 | Ice Crown | ledová koruna | 150 000 000 | +35 % příjem |
| 20 | Sea King Crown | koruna krále moří | 250 000 000 | +40 % skok i příjem |

Mimo obchod existují 3 čepice, které se nedají koupit: Captain Hat (level 15), Pirate Hat (level 35) a Golden Bow Hat (z obřího dárku). Skok je vždy omezen na 100 000 studů, dál už je jen dárek.

## Další herní systémy

### Návrat po skoku

Po dopadu: šplouchnutí, ukáže se vzdálenost a karta s předmětem (2 sekundy). Pak obrazovka krátce zčerná a hráč se objeví na pláži na začátku cesty k molu. Předmět už má v domečku, nebo nad hlavou, když je domeček plný. Hráč nikdy neplave zpátky.

### Tutoriál pro nové hráče

Při prvním vstupu do hry vede hráče 5 krátkých kroků. Každý krok má velkou šipku na zemi a jednu větu nahoře na obrazovce:

1. „Walk to the pier!“ – šipka k molu.
2. „Hold JUMP and let go in the green zone!“ – první skok, ukazatel síly se ten jeden skok pohybuje pomaleji.
3. „You found an item! Go to your house.“ – šipka k domečku, první předmět je vždy Uncommon.
4. „Collect your money!“ – šipka ke kasičce u vchodu.
5. „Buy better slippers at the SHOP!“ – šipka ke stánku, hráč dostane 100 $, aby si hned mohl koupit Beach Blue Slippers.

Tutoriál jde přeskočit a ukáže se jen jednou (uloží se do dat hráče).

### Víc hráčů najednou

- Server má maximálně 8 hráčů (nastavení hry v Robloxu).
- Hráči přes sebe procházejí (collision groups), aby se na molu nestrkali.
- Každý hráč vidí svůj let i lety ostatních, ale mince a kruhy v letu jsou pro každého zvlášť.

### Příchod a odchod hráče

- Při vstupu dostane hráč první volný domeček, jeho jméno se objeví nad vchodem a předměty se načtou na podstavce.
- Při odchodu se data uloží a domeček se vyprázdní pro dalšího hráče.
- Předmět, který hráč zrovna nese nad hlavou, se při odchodu vrátí do jeho inventáře, neztratí se.

### Příjem, když hráč nehraje

Po návratu do hry dostane hráč peníze za dobu, kdy nebyl ve hře: plný příjem domečku, nejvýš za 2 hodiny. Ukáže se okno „Welcome back! You earned $X while you were away.“

### Kódy

V nastavení je políčko na kód. Každý kód jde použít jednou na hráče. Kódy jsou v Config/Codes.luau, aby šly přidávat bez zásahu do logiky. Startovní kódy:

| Kód | Odměna |
| --- | --- |
| SPLASH | 500 $ |
| SLIPPERS | 1 točení spinneru |
| BIGGIFT | 2× příjem na 15 minut |

### Nastavení

Tlačítko s ozubeným kolem: vypnout hudbu, vypnout zvuky, zadat kód, přeskočit tutoriál.

### Události (po vydání)

Později pro udržení hráčů: víkend s 2× penězi, sezónní pantofle a předměty (Halloween, Vánoce, léto). Systém má s událostmi počítat: násobič příjmu a seznam sezónních věcí v Config/Events.luau.

## Robux obchod

Obchod se otevře tlačítkem s košíkem vpravo na obrazovce. Pravidlo: všechno, co ovlivňuje hru, jde získat i hraním; Robuxy jen zrychlují nebo přidávají vzhled. Pro děti je to férovější a hra se lépe hodnotí.

### Game passy (koupí se jednou, platí navždy)

| Game pass (ve hře) | Cena (R$) | Co dá |
| --- | --- | --- |
| Rainbow Trail | 49 | kosmetická stopa za skokem |
| Auto Collect | 99 | peníze z domečku se vybírají samy |
| +5 Slots | 149 | domeček má o 5 míst víc |
| 2x Money | 199 | dvojnásobný příjem ze všech zdrojů |
| VIP | 249 | zlaté jméno, VIP molo bez fronty, +1 denní točení |

### Developer products (dají se kupovat opakovaně)

| Produkt (ve hře) | Cena (R$) | Co dá |
| --- | --- | --- |
| Super Jump | 15 | příští skok +20 % |
| 1 Spin | 25 | jedno točení navíc |
| 2x Money (30 min) | 49 | dočasný boost |
| Money Bag | 49 | peníze ve výši 15 minut příjmu z domečku |
| 5 Spins | 99 | pět točení navíc |
| Money Chest | 149 | peníze ve výši 1 hodiny příjmu |

Peněžní balíčky se počítají z aktuálního příjmu hráče, takže jsou užitečné na začátku i na konci hry. Placená točení musí mít u tlačítka viditelné šance (tabulka ze sekce Denní spinner).

## Grafika pro děti od 8 let

Styl je veselá kreslená pláž: jasné barvy, kulaté tvary, velké čitelné ikony, žádné násilí ani strašidelné prvky.

- **Barvy:** tyrkysová voda, světle žlutý písek, korálově červené a sytě modré stánky, bílé mráčky. Každá rarita má svou barvu rámečku (viz tabulka rarit).
- **Modely:** jednoduché, low-poly, zaoblené hrany. Předměty z vody jsou o něco větší než v realitě, aby byly dobře vidět.
- **UI:** všechny texty anglicky (JUMP, SHOP, SELL, PICK UP, GIFT, SPIN), velká tlačítka (min. 60 px na mobilu), ikony s krátkým textem, písmo Fredoka One nebo Gotham Black. Čísla zkracovat (1.5K, 2.3M).
- **Zpětná vazba:** každý skok končí velkým šplouchnutím, vyskočí číslo vzdálenosti a karta s předmětem. Vzácné předměty mají delší animaci a zvuk fanfáry.
- **Stánky:** dřevěné budky s pruhovanými markýzami, nápisy SHOP a SELL velkými písmeny na ceduli nad pultem.
- **Zvuky:** vlny, racci, veselá ukulele hudba, „žbluňk“ při dopadu. Hudbu jde vypnout.
- **Bezpečnost:** chat jen přes filtr Robloxu (TextChatService), žádné vlastní textové vstupy mimo něj.

### Co je potřeba nakreslit a vymodelovat

Claude Code napíše kód, ale 3D modely nevytvoří. Hra potřebuje přes 70 modelů: 20 pantoflí, 31 předmětů z vody, 23 čepic, plus molo, stánky, domečky, kolo štěstí a obří dárek.

- **Na začátek:** Claude Code postaví dočasné modely z jednoduchých dílů (barevné kostky a koule s cedulkou s názvem), aby šla hra hned hrát a testovat.
- **Potom:** dočasné modely se vymění za hezké. Zdroje: Toolbox v Roblox Studiu (zdarma, kontrolovat, že model nemá skripty), Blender, nebo AI generátor 3D modelů. Každý model se pojmenuje přesně jako v Config modulech (např. „SharkSlippers“), aby ho kód našel.
- **Stránka hry:** ikona hry (512 × 512) a 3–5 náhledových obrázků (16 : 9). Na to se hodí ChatGPT a obrázky mapy, které už máte.

## Technické zadání pro Claude Code

Claude Code pracuje se soubory na disku, ne přímo v Roblox Studiu. Proto použijte **Rojo**: kód se píše jako .luau soubory ve složce projektu a Rojo plugin je živě synchronizuje do Studia. Mapu a 3D modely stavíte ve Studiu ručně nebo z Toolboxu.

### Struktura projektu

```
src/
  shared/        -- ReplicatedStorage
    Config/      -- Slippers, Hats, Items, Spinner, Levels, Products, Codes, Events (.luau)
    Util/        -- FormatNumber.luau
  server/        -- ServerScriptService
    DataService.luau      -- ukládání přes DataStore (ProfileStore)
    PlayerService.luau    -- příchod/odchod, přidělení domečku, příjem offline
    JumpService.luau      -- ukazatel síly, výpočet skoku, mince a kruhy, drop, návrat na pláž
    HouseService.luau     -- podstavce, příjem $/s, kasička, teleport k SELL
    ShopService.luau      -- nákup pantoflí a čepic, prodej
    GiftService.luau      -- darování mezi hráči
    SpinnerService.luau
    LevelService.luau
    RebirthService.luau
    LeaderboardService.luau
    CodeService.luau
    TutorialService.luau
    MonetizationService.luau  -- game passy + ProcessReceipt
  client/        -- StarterPlayerScripts
    UI/          -- HUD, obchod, inventář, spinner, Robux košík, nastavení, tutoriál (texty anglicky)
    Effects/     -- stopy, šplouchnutí, konfety, PERFECT!
assets/          -- dočasné modely z dílů (.model.json), později nahradit
```

### Klíčová pravidla

- Všechna čísla (ceny, šance, bonusy) jsou jen v Config modulech, aby šla hra ladit bez sahání do logiky.
- Server rozhoduje o všem: vzdálenost skoku, drop, peníze. Klient jen posílá „chci skočit“ (a výsledek ukazatele síly) přes RemoteEvent a přehrává animaci. Server ověří, že hodnota ukazatele dává smysl, a sám spočítá vzdálenost včetně mincí a kruhů posbíraných v letu. Tím se zabrání podvádění.
- Ukládání dat: $, pantofle, čepice, předměty v domečku, level, XP, počet znovuzrození, čas posledního točení, dokončený tutoriál, použité kódy, čas odchodu (pro příjem offline). Ukládat při odchodu a každých 60 s.
- Nákupy za Robux přes MarketplaceService.ProcessReceipt s ochranou proti dvojímu připsání.
- Skok: hráč doběhne na konec mola, stiskne tlačítko JUMP (mobil i PC), postava letí po parabole na vypočítanou vzdálenost ± 5 % náhody. Let trvá 3–10 sekund podle vzdálenosti (rychlost se přizpůsobí), kamera letí za hráčem s efektem rychlosti.

### Vzdálenost 100 000 studů v Robloxu

- **Přesnost:** daleko od středu světa (0, 0, 0) začnou postavy a předměty cukat. Střed světa proto dejte doprostřed vody (na 50 000 studů), aby nejvzdálenější bod byl jen 50 000 od středu.
- **Viditelnost dárku:** Roblox takhle daleko nic nevykreslí, skutečný dárek z mola vidět nebude. Na molu proto ukazujte jeho zmenšenou kopii na obzoru (fixní vzdálenost od kamery) a svítící paprsek do nebe. Opravdový model se načte, až se k němu hráč přiblíží.
- **Voda:** nepoužívat Terrain water na celých 100 000 studů (moc náročné). Stačí ploché díly s texturou vody, které se načítají po kouscích (StreamingEnabled).
- **Molo:** 150 studů, bez odrazového prkna a pružiny.

### Pořadí vývoje

1. Rojo projekt, všechny Config moduly, DataService, PlayerService (přidělení domečků, příchod a odchod).
2. Mapa z dočasných dílů: pláž, cesta na molo, molo, vodní koridor s bójkami a značkami, 8 domečků (4 + 4), stánky, kolo, ostrůvek s dárkem.
3. Skok: ukazatel síly, let, mince a kruhy, výpočet vzdálenosti, dopad, návrat na pláž.
4. Drop předmětů, domeček s 10 podstavci, příjem $/s, kasička, zelený teleport k SELL.
5. Stánek SHOP (pantofle, čepice) a SELL, nošení nad hlavou, darování.
6. Levely, spinner, obří dárek, znovuzrození, žebříček nejdelších skoků.
7. Tutoriál, nastavení, kódy, příjem offline.
8. Robux obchod (game passy, developer products).
9. Efekty, zvuky, výměna dočasných modelů za hezké, testování na mobilu a s více hráči.
10. Vydání hry (viz níže).

### Co musíte udělat ručně vy

Tyhle věci Claude Code neudělá, protože se dělají na webu Robloxu nebo ve Studiu:

- **Game passy a developer products** se zakládají v Creator Dashboard na webu Robloxu. Jejich čísla (ID) pak zkopírujte do Config/Products.luau.
- **Zapnout API přístup k DataStore** ve Studiu (Game Settings → Security → Enable Studio Access to API Services), jinak ukládání ve Studiu nefunguje.
- **Nastavit 8 hráčů na server** v Game Settings.
- **Vyplnit dotazník o obsahu** (Maturity & Compliance) v Creator Dashboard, jinak Roblox hru nezveřejní.
- **Nahrát ikonu a náhledové obrázky** hry.

### Úvodní prompt do Claude Code

> Vytváříme Roblox hru Slipper Jump! podle zadání v souboru ZADANI.md. Hra je o skákání v pantoflích (slippers) z mola do vody. Všechny texty, názvy předmětů a UI ve hře piš anglicky, komentáře v kódu mohou být česky. Použij Rojo a Luau se striktním typováním. Všechna čísla (ceny, šance, bonusy, vzdálenosti) patří jen do Config modulů. Server rozhoduje o všem, co ovlivňuje peníze a předměty. Místo 3D modelů zatím vytvoř jednoduché dočasné modely z dílů pojmenované podle Config modulů. Postupuj podle Pořadí vývoje, začni krokem 1. Po každém kroku mi napiš, co mám otestovat ve Studiu a co musím udělat ručně.
