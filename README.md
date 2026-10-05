# Slipper Jump! 🩴🌊🎁

Roblox hra: skáčeš v pantoflích z mola do dlouhé vody, sbíráš předměty, domeček ti vydělává,
kupuješ lepší pantofle a čepice a snažíš se doskočit až k obřímu dárku na 100 000 studech.

Kód je psaný v **Luau (strict)** a synchronizuje se do Roblox Studia přes **Rojo**.
Všechny texty ve hře jsou anglicky, komentáře v kódu česky.

---

## 1. Spuštění (poprvé)

1. Nainstaluj **Rojo**:
   - buď přes [Rokit](https://github.com/rojo-rbx/rokit): `rokit install` (verze je v `rokit.toml`),
   - nebo stáhni `rojo` z [GitHub Releases](https://github.com/rojo-rbx/rojo/releases) (verze 7.4.x).
2. V Roblox Studiu nainstaluj **Rojo plugin** (Plugins → Manage Plugins, nebo `rojo plugin install`).
3. Otevři novou prázdnou hru (Baseplate) a **smaž díl `Baseplate`** z Workspace (mapa se staví sama).
4. V terminálu ve složce projektu: `rojo serve`
5. Ve Studiu: Plugins → Rojo → **Connect**.
6. Zmáčkni **Play**. 🎉

Alternativa bez živé synchronizace: `rojo build -o SlipperJump.rbxl` a soubor otevři ve Studiu.

## 2. Co musíš udělat ručně (web / Studio)

| Co | Kde |
| --- | --- |
| Zapnout ukládání dat ve Studiu | Game Settings → Security → **Enable Studio Access to API Services** |
| 8 hráčů na server | Game Settings → Places → **Max Players = 8** |
| Založit game passy a developer products | Creator Dashboard → hra → Monetization. Jejich **ID zkopíruj do `src/shared/Config/Products.luau`** |
| Dotazník o obsahu | Creator Dashboard → Audience → **Maturity & Compliance** |
| Ikona 512×512 a 3–5 náhledů 16:9 | Creator Dashboard → Places → Thumbnails |
| Zvuky (volitelné) | ID zvuků z Creator Store vlož do `src/shared/Config/Sounds.luau` |

Dokud mají produkty `Id = 0`, v obchodě se neukazují (a tlačítka jen ukážou hlášku „not set up yet“).

**Všechny produkty k založení** (názvy a doporučené ceny, `Key` v `Products.luau`):

| Typ | Název (Key) | Cena | Co dělá |
| --- | --- | --- | --- |
| Game pass | Rainbow Trail (`RainbowTrail`) | 49 R$ | duhová stopa za skokem |
| Game pass | Auto Collect (`AutoCollect`) | 99 R$ | kasička se vybírá sama |
| Game pass | +5 Slots (`PlusSlots`) | 149 R$ | +5 míst v domečku |
| Game pass | 2x Money (`DoubleMoney`) | 199 R$ | 2× peníze natrvalo |
| Game pass | Turbo Fins (`TurboFins`) | 149 R$ | plavání +30 % |
| Game pass | **Super Jumper** (`SuperJumper`) | 199 R$ | +25 % ke vzdálenosti skoku natrvalo (limity 95 000 / 100 000 platí dál) |
| Game pass | **Lucky Charm** (`LuckyCharm`) | 179 R$ | 1,5× štěstí na vzácné předměty z vody natrvalo |
| Game pass | VIP (`VIP`) | 249 R$ | zlaté jméno, +1 denní točení |
| Game pass | **All Sneaker Skins** (`AllSneakers`) | 299 R$ | všech 20 skinů tenisek natrvalo |
| Game pass | **Treasure Hunter** (`TreasureHunter`) | 149 R$ | +1 diamant v každém skoku, vzácnější diamanty, častější balónky |
| Developer product | Starter Pack (`StarterPack`) | 49 R$ | jednorázový balíček |
| Developer product | Shark Repellent (`SharkRepellent`) | 29 R$ | 3 plavání bez žraloka |
| Developer product | Super Jump (`SuperJump`) | 15 R$ | příští skok +20 % |
| Developer product | **Mega Jump Pack** (`MegaJumpPack`) | 39 R$ | příští 3 skoky +50 % |
| Developer product | 1 Spin (`Spin1`) | 25 R$ | 1 točení (šance jsou vidět) |
| Developer product | 2x Money (30 min) (`Boost30`) | 49 R$ | 2× peníze na 30 min |
| Developer product | **Lucky Potion** (`LuckyPotion`) | 39 R$ | 2× štěstí na 15 min (čas se sčítá) |
| Developer product | Money Bag (`MoneyBag`) | 49 R$ | příjem domečku za 15 min |
| Developer product | 5 Spins (`Spins5`) | 99 R$ | 5 točení (šance jsou vidět) |
| Developer product | Money Chest (`MoneyChest`) | 149 R$ | příjem domečku za 1 h |
| Developer product | **10 Spins** (`Spins10`) | 179 R$ | 10 točení (nejvýhodnější) |
| Developer product | **Bubble Shield** (`BubbleShield`) | 25 R$ | 5 slalomů s jedním nárazem zdarma |
| Developer product | **Easy Path** (`TrialEasy`) | 19 R$ | snazší úkol na ostrově (nabízí se jen tam) |
| Developer product | **Skip Challenge** (`TrialSkip`) | 39 R$ | domů z ostrova hned i s bonusem (nabízí se jen tam) |
| Developer product | **Sneaker Skin** (`SkinTier1`) | 19 R$ | 1 skin tenisek (pozice 2–5) |
| Developer product | **Cool Sneaker Skin** (`SkinTier2`) | 39 R$ | 1 skin tenisek (pozice 6–10) |
| Developer product | **Epic Sneaker Skin** (`SkinTier3`) | 69 R$ | 1 skin tenisek (pozice 11–15) |
| Developer product | **Legendary Sneaker Skin** (`SkinTier4`) | 99 R$ | 1 skin tenisek (pozice 16–20) |

**Tenisky = skiny za Robux.** Mění jen vzhled bot (model, stopu, efekty), síla skoku je vždy z pantoflí.
Hráč si v ITEMS → Sneakers vybere skin, hra si zapamatuje který a otevře nákup správné cenové skupiny
(stačí tedy 4 produkty místo 20). První skin (Muddy Old Sneakers) má každý zdarma, Starter Pack přidává Street Runners.

**Testování ve Studiu:** dokud mají produkty `Id = 0`, ve Studiu se všechno ukazuje a „koupí“ se zdarma
(nápis *[Studio test]*), takže jde vše vyzkoušet. Ve zveřejněné hře se nezaložené produkty skryjí.

### Zveřejnění hry – krok za krokem
1. Ve Studiu **File → Publish to Roblox** (pojmenuj hru *Slipper Jump!*).
2. Game Settings → Security → zapni **Enable Studio Access to API Services** (ukládání dat).
3. Creator Dashboard → hra → **Monetization → Passes**: založ 10 passů z tabulky (název, cena, ikonka).
4. **Monetization → Developer Products**: založ 18 produktů z tabulky.
5. ID všech passů a produktů vlož do `src/shared/Config/Products.luau` (pole `Id`) a hru znovu publikuj.
6. Vyplň dotazník **Maturity & Compliance**, nahraj ikonu a obrázky a hru přepni na **Public**.

## 3. Co otestovat ve Studiu

**Jeden hráč (Play):**
1. Objevíš se na pláži, nahoře je tutoriál „Walk to the pier!“ a žlutá šipka.
2. Dojdi na konec mola → objeví se velké tlačítko **JUMP!** (nebo drž mezerník).
3. Drž, nad hlavou jezdí ukazatel; pusť v zelené → **PERFECT!** + konfety.
4. V letu uhýbej **A/D** (šipky, joystick) a sbírej mince a zlaté kruhy (+5 % vzdálenosti).
5. Po dopadu: šplouchnutí, vzdálenost, karta s předmětem (první je vždy Uncommon), zatmění a návrat na pláž.
6. V domečku (se tvým jménem nad vchodem) leží předmět na podstavci a vydělává. Projdi vchodem → kasička se vybere.
7. Dostaneš 100 $ → ve stánku **SHOP** kup Beach Blue Slippers. Tutoriál skončí.
8. U podstavce drž **E** → předmět nad hlavou → zelené kolečko vzadu tě hodí k **SELL** → drž „Sell“.
9. Kolo štěstí vpravo u vody: 1 točení zdarma, šance vidíš u kola.
10. Nastavení (⚙): kód **SPLASH** (+500 $), **SLIPPERS** (+1 točení), **BIGGIFT** (2× peníze 15 min), **LUCKY** (2× štěstí 15 min).

**Víc hráčů (Test → Clients and Servers → 2 hráči):**
- každý má svůj domeček, hráči přes sebe procházejí,
- s předmětem nad hlavou přijdi k druhému hráči a drž **G / Gift** → druhý dostane okno Accept/Decline,
- žebříček u spawnu ukazuje nejdelší skoky, nový rekord serveru se oznámí všem.

**Rychlé testování konce hry:** během Play přepni Command Bar na **Server** a zadej
(funguje jen ve Studiu):
```lua
game.Players:GetPlayers()[1]:SetAttribute("DevMoney", 1e9)
```
Pak kup Royal Diamond Slippers a skoč k dárku → Golden Splash, 1M $, titulek, Rebirth.
Cestou jsou dva dárkové ostrovy: **Bronze Gift** na 10 000 studech (250 000 $, Epic předmět, Propeller Cap) a **Silver Gift** na 40 000 studech (3M $, Legendary předmět, titulek). Skok se u nezískaného ostrova zastaví a hráč na něm přistane; po Rebirthu se dají získat znovu (`Config/GiantGift.luau` → `Islands`).

**Diamanty** (`Config/Diamonds.luau`): od levelu 3 (nebo po 5 skocích) se mezi kruhy objevují barevné diamanty – Emerald (peníze), Sapphire (peníze + XP), Amethyst (štít proti nárazu ve slalomu), Golden (2× mince) a Rainbow (všechno + delší skok). S levelem jich přibývá a vzácné jsou častější.

**Slalomy** (`Config/Swim.luau` → `Slalom.Variants`): kromě běžného slalomu (těžší s každým levelem) přicházejí zvláštní druhy – Rock Garden, Jellyfish Field, Storm (vlny posouvají do stran), Log Jam, Night (tma) a Puffer Party. Za slalom bez nárazu jsou ★★★ a bonus k odměně za vor.

**Balónky s pokladem** (`Config/Diamonds.luau` → `Balloon`): od levelu 4 občas visí ve vzduchu balónek s truhlou – kdo ho trefí, dostane předmět navíc (hned do domečku) a peníze.

**Nové události**: Diamond Rush (víc a vzácnějších diamantů) a Balloon Party (balónky v každém skoku).

**Nové Robux produkty**: game pass **Treasure Hunter** (+1 diamant, vzácnější diamanty, častější balónky) a produkt **Bubble Shield** (5 slalomů s jedním nárazem zdarma). Id doplňte v `Config/Products.luau`.

**Prodejní okno**: u stánku SELL (nebo tlačítkem 💰 SELL vpravo) se otevře seznam všech předmětů z domečku, skladu i z rukou. Prodat jde jednotlivě, „Sell all common“ nebo „Sell all up to Rare“; Legendary a vzácnější jen po potvrzení.

**Testovací panel**: ve Studiu je dole fialové tlačítko TEST – spustí libovolnou událost, nastaví level, přidá peníze, obuje pantofle, plaveckou výbavu, štíty, předměty. Ve zveřejněné hře není.

**Album** (ITEMS → Index): přehled nalezených předmětů po vzácnostech; za kompletní vzácnost točení zdarma (`Config/Items.luau` → `IndexRewardSpins`).

**Úkoly na cestu z ostrovů** (`Config/Trials.luau`, stavby v `server/TrialCourses.luau`): po otevření dárku hráč zůstane na ostrově a dostane úkol domů – Bronze = závod na kánoi (slalom, žralok), Silver = barevná dráha nad mořem (vlaječky, mizející plošiny, otáčející se tyče, klády), Obří dárek = kánoe v bouři před Krakenem. Dárek už má, úkol je bonus (peníze, točení, titulek). Kdykoli může zdarma „GO HOME (no bonus)“, za Robux Easy Path nebo Skip + bonus. Ve Studiu: TEST → Challenge: Bronze / Silver / Giant.

**Točení za Robux a PolicyService**: v zemích, kde Roblox zakazuje placené náhodné odměny, se nákupy točení (a Starter Pack se točeními) automaticky skryjí (`client/Purchase.luau`).

**Žraločí alarm**: když se pronásledovatel blíží, zčervenají okraje obrazovky a zrychluje tlukot srdce.

**Vytuněné boty** (`Shared/Models.luau` → `tune`): od Golden Slippers neonové lemy, pak drahokamy, chromová pata, křídla, duhově se přelévající prstenec, ostny a obří drahokam; nejdražší mají hvězdičkovou auru.

## 4. Struktura projektu

```
src/
  shared/                 → ReplicatedStorage.Shared
    Config/               Všechna čísla hry (ceny, šance, bonusy, vzdálenosti)
      Slippers, Hats, Items, Spinner, Levels, Products, Codes, Events,
      Jump, World, House, Economy, GiantGift, Tutorial, Sounds
    Util/FormatNumber     1.5K, 2.3M, čas
    Util/Signal
    Catalog.luau          vyhledávání v Configu podle Id
    Formulas.luau         vzorce (skok, XP, násobiče, sloty…)
    Models.luau           dočasné modely z dílů / hezké modely z Assets
    Net.luau              všechny RemoteEventy
  server/                 → ServerScriptService.Server
    Main.server.luau      spouštěč
    MapBuilder.luau       postaví celou mapu z dílů
    DataService           ProfileStore (ukládání, session lock, každých 60 s)
    PlayerService         příchod/odchod, stav pro klienta, návrat na pláž
    EconomyService        příjem $/s, kasička, offline příjem, násobiče
    HouseService          domečky, podstavce, kasička, teleport k SELL
    ItemService           drop podle zóny, Pick Up / Place / Swap, sklad
    AvatarService         pantofle na nohou, stopy, čepice, cedulka nad hlavou
    JumpService           ukazatel, výpočet skoku, mince a kruhy, serverová kontrola
    ShopService           nákup pantoflí a čepic, prodej
    GiftService           darování mezi hráči (limit 20/den)
    SpinnerService, LevelService, RebirthService, LeaderboardService,
    CodeService, TutorialService, MonetizationService
    Packages/ProfileStore (MadStudio / loleris)
  client/                 → StarterPlayerScripts.Client
    Main.client.luau
    ClientState, Sound
    UI/  Kit, HUD, Shop, SpinnerUI, RobuxShop, Offers, Settings, Dialogs, TutorialUI
    Controllers/ JumpController (skok, let, kamera), WorldController (oceán, dárek na obzoru…),
                 SeaLifeController (delfíni, rybky, rackové, třpytky – jen klient)
    Effects/ Effects (konfety, šplouchnutí, vlny, PERFECT!, otřes kamery, rychlostní čáry, zatmění)
assets/                   → ReplicatedStorage.Assets (hezké modely, viz assets/README.md)
```

## 5. Jak hra funguje technicky

- **Server rozhoduje o všem.** Klient posílá jen „začal jsem držet JUMP“ a „pustil jsem na hodnotě X“.
  Server si sám měří čas, ověří, že hodnota ukazatele sedí (tolerance na ping), spočítá vzdálenost
  (pantofle × čepice × načasování × ±5 % × Super Jumper pass × Mega/Super Jump), rozmístí mince a kruhy a během letu si
  zaznamenává pozice hráče. Po dopadu ověří každou minci a kruh podle skutečné dráhy.
- **Limit dárku:** bez Royal Diamond Slippers je skok omezen na 95 000 studů, jinak na 100 000.
- **Svět 100 000 studů:** střed světa (0,0,0) je uprostřed vody; molo končí na X = −50 000, dárek je na X = +50 000.
  Voda jsou ploché díly (ne Terrain), zapnutý je StreamingEnabled. Klient má vlastní „oceán“, který jede s kamerou,
  a zmenšený dárek s paprskem na obzoru, protože skutečný model je moc daleko.
- **Nákupy za Robux:** `ProcessReceipt` ukládá `PurchaseId` do profilu a potvrdí nákup až po uložení
  (žádné dvojí připsání ani ztracený nákup).
- **Data:** peníze, pantofle, čepice, předměty v domečku, sklad, level, XP, rebirthy, spinner, tutoriál,
  použité kódy, čas odchodu (offline příjem max. 2 h), nastavení, katalog nalezených věcí.

## 6. Ladění hry

Všechno se ladí v `src/shared/Config/` bez sahání do logiky:
- ceny a násobiče pantoflí → `Slippers.luau`, čepice → `Hats.luau`
- příjmy předmětů a šance podle zón → `Items.luau`
- rychlost ukazatele, zóny GOOD/PERFECT, počet mincí a kruhů, výška letu → `Jump.luau`
- kódy → `Codes.luau`, víkend 2× peníze a sezónní události → `Events.luau`

## 7. Výměna dočasných modelů za hezké

Viz [`assets/README.md`](assets/README.md). Model pojmenuj přesně jako `Id` v Configu
(např. `SharkSlippers`), ulož jako `.rbxm` do správné složky v `assets/` a hra ho použije místo dílů.

## 8. Novinky: tenisky, plavání se žralokem, události, úkoly

- **Tenisky** (`Config/Sneakers.luau`): druhá řada 20 bot od „Muddy Old Sneakers“ po „Golden Air Kings“.
  Mají stejnou cenu a sílu jako pantofle na stejné pozici, liší se jen vzhledem. Žádné skutečné značky.
  K dárku se dá doskočit s Royal Diamond Slippers i s Golden Air Kings.
- **Plavání zpět** (`Config/Swim.luau`): po dopadu hráč plave k záchrannému voru, honí ho žralok
  (v hlubší vodě rychlejší). Doplave → bonus peněz. Chytí ho → jen přijde o bonus.
  Rychlost plavání: záložka **Swim** v obchodě (za herní $), game pass **Turbo Fins**, produkt **Shark Repellent**.
  O výsledku rozhoduje server podle skutečné pozice hráče.
- **Události každých 5 minut** (`Config/Events.luau`): Golden Rings, Coin Storm, Treasure Tide, Shark Holiday, Mega Jump,
  Double XP, Rainbow Rings (víc kruhů) a **Jump Contest** (120 s, živá tabulka top 3 v HUD, odměny pro 1.–3. místo, konfety pro vítěze).
- **Série PERFECT skoků** (`Config/Jump.luau` → `PerfectStreak`): každý další PERFECT za sebou +5 % vzdálenosti (max. +30 %),
  jiný skok sérii vynuluje. Počítá server, neukládá se.
- **Denní úkoly a série přihlášení** (`Config/Quests.luau`): 3 úkoly denně, odměna za každý den v řadě.
- **Starter Pack**: levný jednorázový balíček (tlačítko 🎁 zmizí po koupi).

Nové produkty k založení v Creator Dashboard: game pass **Turbo Fins**, developer products **Starter Pack** a **Shark Repellent**.
Další nové produkty (Super Jumper, Lucky Charm, Lucky Potion, Mega Jump Pack) jsou v sekci 9.

## 9. Novinky: víc Robuxů férově

Nové produkty k založení v Creator Dashboard (ID pak vlož do `Config/Products.luau`):
- game pass **Super Jumper** – 199 R$ (+25 % vzdálenosti natrvalo, limity vzdálenosti platí dál),
- game pass **Lucky Charm** – 179 R$ (1,5× štěstí na vzácné předměty natrvalo),
- developer product **Lucky Potion** – 39 R$ (2× štěstí na 15 minut, čas se sčítá, ukládá se do profilu jako `LuckUntil`),
- developer product **Mega Jump Pack** – 39 R$ (příští 3 skoky +50 %, ukládá se jako `MegaJumps`; použije se dřív než Super Jump, nikdy ne oba naráz).

Jak to funguje:
- **Štěstí** (`Formulas.LuckyChances`): nejběžnější rarita v zóně zůstává stejná, nejvzácnější je až „štěstí“-krát
  častější, ostatní plynule mezi tím. Neodemyká rarity, které v zóně nejsou. Charm a Potion se násobí (max. 3×).
- **Roblox Premium**: hráči s Premium mají +10 % peněz (počítá server, i offline příjem). V Robux obchodě vidí odznak „Premium +10% money“.
- **Kontextové nabídky** (`client/UI/Offers.luau`): po novém osobním rekordu (Super Jumper, jinak Mega Jump Pack)
  nebo když hráče chytí žralok (Turbo Fins, jinak Shark Repellent) se po návratu na pláž může ukázat malá karta
  s jednou nabídkou. Nejvýš jednou za 10 minut (`Products.OfferCooldown`), nikdy v tutoriálu, jen založené produkty,
  nic, co hráč už vlastní. Neutrální text, tlačítko „No thanks“, sama zmizí po 15 s.
- HUD ukazuje odpočet „2x LUCK“ vedle „2x MONEY“ a počet Mega / Super Jumpů pod skokem.

### Pravidla monetizace (aby hru Roblox nesmazal a rodiče ji hodnotili dobře)
- Žádné skutečné značky (Nike, Jordan…) – porušení ochranné známky.
- Šance u všech náhodných odměn musí být vidět (kolo štěstí je má).
- V EU je zakázané přímo vybízet děti k nákupu („Kup teď!“). Nabídky ukazujeme, netlačíme.
- Všechno, co ovlivňuje hru, jde získat i hraním; Robux jen zrychluje nebo přidává vzhled.
- Roblox platí i za čas hráčů s Premium (Engagement-Based Payouts) – zábavná hra vydělává i bez nákupů.
