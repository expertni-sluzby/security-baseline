patch: Číslo verze se při vydání dopočítá samo
Vydání security-baseline už nepotřebuje číslo verze. PR, které přidá nebo změní `releases/next.md` (první řádek název, zbytek poznámky), se po merge a zeleném self-testu na main vydá s dopočtenou verzí. Rozhodují commity od posledního vydání: `feat…:` znamená minor, jinak patch. Na prvním řádku lze verzi přebít předponou `patch:` nebo `minor:`. Zlom kontraktu (`…!:`, `BREAKING CHANGE`) se automaticky nevydá, patří do v2.

Pro konzumenty se nic nemění, `baseline.yml` je stejný jako ve v1.3.1. Tohle vydání poprvé projde automatickou cestou po merge. (#23)
