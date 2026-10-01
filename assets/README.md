# Assets – modely

Sem patří hezké modely, které nahradí dočasné modely z dílů.
Ve hře je najdeš v Exploreru jako `ReplicatedStorage → Assets`. Nejjednodušší je vložit model přímo ve Studiu (viz MODELY.md v kořeni projektu).

- `Slippers/` – jeden pantofel (levý i pravý se vytvoří kopií), např. `SharkSlippers.rbxm`
- `Hats/` – čepice, např. `CowboyHat.rbxm`
- `Items/` – předměty z vody, např. `RubberDuck.rbxm`
- `Map/` – rekvizity mapy: `ShopStall`, `SellStall`, `House`, `Spinner`, `GiantGift`, `Palm`, `Umbrella`

Pravidla:
1. Model (Model) se musí jmenovat přesně jako `Id` v Config modulu (`src/shared/Config`).
2. Model musí mít nastavený `PrimaryPart`.
3. Z Toolboxu vždy smažte všechny skripty uvnitř modelu.
4. Když model ve složce chybí, hra automaticky postaví dočasný model z dílů.

Všechny boty, čepice a předměty už tu jsou jako `.model.json` (z dílů, generují je skripty v `tools/`).
Čepice s dílem `Attach` jsou ve skutečné velikosti a `Attach` určuje úchyt na hlavě (0,25 pod temenem).

Model exportujete ve Studiu: pravý klik → Save to File… → `.rbxm` do správné složky.
