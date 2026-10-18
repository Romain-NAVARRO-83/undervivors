# Undervivors

Jeu d'action et de gestion en 2D isométrique : des survivants échoués sur une plage explorent un monde ouvert, combattent, récoltent et bâtissent un village. Mort permanente.

Moteur : **Godot 4.5** (GDScript). Le document de game design vit dans l'espace Notion « Igor ».

## Lancer le prototype

1. Installer [Godot 4.5](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir Godot → **Importer** → choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur **F5** (ou le bouton ▶ en haut à droite).

## Commandes

| Action | Touche |
|---|---|
| Se déplacer | ZQSD (AZERTY), WASD (QWERTY) ou flèches |
| Viser | Souris |
| Tirer | Clic gauche (maintenu) |
| Survivant suivant | Tab |
| Choisir un survivant | 1 à 9, ou clic droit dessus |
| Relâcher le contrôle | Échap |

## Contenu du prototype v0.1

- Sol isométrique placeholder (tuiles 64×32) avec place du village, herbe, plage et mer.
- 4 survivants aux noms générés (dont 1 héros ★, sans capacité pour l'instant).
- Survivant contrôlé : déplacement, visée, tir. Les autres errent autour du feu de camp et tirent seuls sur les cibles à portée.
- Armes paramétrables : lance-pierre par défaut, fusil à pompe à ramasser au sud-ouest du village.
- Cibles d'entraînement qui encaissent, se cassent, réapparaissent et rapportent de l'XP.
- Mort définitive ; si tous meurent, un nouveau survivant apparaît au centre (pas encore d'ennemi qui attaque).

## Structure

```
scenes/main.tscn          scène principale
scripts/main.gd           montage du monde, sélection, caméra, HUD
scripts/survivor.gd       survivant : contrôle, errance, tir autonome, stats
scripts/name_generator.gd générateur de noms par syllabes multi-pays
scripts/weapon_data.gd    ressource « arme » (dégâts, cadence, dispersion, élément…)
scripts/projectile.gd     projectile
scripts/target_dummy.gd   cible d'entraînement (placeholder d'ennemi)
scripts/weapon_pickup.gd  arme au sol
scripts/iso_ground.gd     sol isométrique placeholder
data/weapons/*.tres       armes, modifiables dans l'inspecteur de Godot
tests/run_tests.gd        tests automatisés
```

## Graphismes

Tout est dessiné en code avec des formes simples. Format prévu pour les tuiles : **64×32 px** (losange isométrique 2:1). Les sprites remplaceront les fonctions `_draw()`.

## Tests

```
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```
