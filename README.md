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

Dokud mají produkty `Id = 0`, tlačítka v obchodě jen ukážou hlášku „not set up yet“.

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
10. Nastavení (⚙): kód **SPLASH** (+500 $), **SLIPPERS** (+1 točení), **BIGGIFT** (2× peníze 15 min).

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
    UI/  Kit, HUD, Shop, SpinnerUI, RobuxShop, Settings, Dialogs, TutorialUI
    Controllers/ JumpController (skok, let, kamera), WorldController (oceán, dárek na obzoru…)
    Effects/ Effects (konfety, šplouchnutí, PERFECT!, zatmění)
assets/                   → ReplicatedStorage.Assets (hezké modely, viz assets/README.md)
```

## 5. Jak hra funguje technicky

- **Server rozhoduje o všem.** Klient posílá jen „začal jsem držet JUMP“ a „pustil jsem na hodnotě X“.
  Server si sám měří čas, ověří, že hodnota ukazatele sedí (tolerance na ping), spočítá vzdálenost
  (pantofle × čepice × načasování × ±5 % × Super Jump), rozmístí mince a kruhy a během letu si
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

### Pravidla monetizace (aby hru Roblox nesmazal a rodiče ji hodnotili dobře)
- Žádné skutečné značky (Nike, Jordan…) – porušení ochranné známky.
- Šance u všech náhodných odměn musí být vidět (kolo štěstí je má).
- V EU je zakázané přímo vybízet děti k nákupu („Kup teď!“). Nabídky ukazujeme, netlačíme.
- Všechno, co ovlivňuje hru, jde získat i hraním; Robux jen zrychluje nebo přidává vzhled.
- Roblox platí i za čas hráčů s Premium (Engagement-Based Payouts) – zábavná hra vydělává i bez nákupů.
