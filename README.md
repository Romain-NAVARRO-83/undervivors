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
| Relâcher le contrôle (mode gestion, caméra libre) | Échap |
| Déplacer la caméra libre | ZQSD / WASD / flèches, quand aucun survivant n'est sélectionné |
| Panneau des survivants | G, ou bouton en haut à droite |
| Mode escouade on/off | F |
| Changer de formation | V |

## Contenu du prototype v0.1

- Sol isométrique placeholder (tuiles 64×32) avec place du village, herbe, plage et mer.
- 4 survivants aux noms générés (dont 1 héros ★, sans capacité pour l'instant).
- Survivant contrôlé : déplacement, visée, tir. Les autres errent autour du feu de camp et tirent seuls sur les cibles à portée.
- Armes paramétrables : lance-pierre par défaut, fusil à pompe à ramasser au sud-ouest du village.
- Cibles d'entraînement qui encaissent, se cassent, réapparaissent et rapportent de l'XP.
- Mort définitive ; si tous meurent, un nouveau survivant apparaît au centre (pas encore d'ennemi qui attaque).

## Ajouts v0.2

- Apparence aléatoire par survivant (forme du visage, peau, coiffure, yeux, bouche, accessoires, vêtement), visible dans le monde et en vignette.
- Stats : PV max, vitesse (agit sur le déplacement), précision (réduit la dispersion), force (pas encore utilisée), niveau.
- Passage de niveau tous les 100 XP : 1 point à attribuer dans la stat de son choix.
- Panneau de gestion : une tuile par survivant avec vignette, barres de stats, boutons « + » et arme. Clic sur une tuile = prendre le contrôle. Le jeu continue derrière.

## Ajouts v0.3

- Une mare (point de récolte d'eau) au sud-est du village.
- Stock commun du village, affiché en haut de l'écran.
- Assignation : **clic droit sur la mare** avec un survivant contrôlé (le contrôle passe au survivant libre suivant), ou menu **Tâche** dans le panneau des survivants.
- Le survivant assigné fait des allers-retours mare → feu de camp jusqu'à nouvel ordre ; il porte 1 + son niveau par trajet et continue de tirer seul en chemin.
- Prendre le contrôle d'un survivant assigné met sa tâche en pause ; il la reprend quand on le relâche. Un survivant contrôlé dépose sa charge en passant au feu de camp.

## Ajouts v0.4 : escouade

- Composer l'escouade dans le panneau (G) : bouton « Ajouter à l'escouade » sur chaque tuile, 4 membres maximum.
- **F** : entrer / sortir du mode escouade. On contrôle le leader ; les autres le suivent en formation et tirent seuls.
- Changer de leader : Tab, touches 1-4, clic sur la barre d'escouade en bas, ou clic droit sur un membre.
- **V** : formation colonne, ligne ou cercle (orientée selon la direction du leader).
- Les membres ont un anneau bleu et leur numéro au-dessus de la tête.
- La composition reste enregistrée en sortant du mode ; chacun reprend alors sa tâche (récolte) ou son errance.
- Si le leader meurt, le membre suivant prend la tête.

## Ajouts v0.5 : mode gestion

- Échap relâche le survivant contrôlé : plus personne n'est sélectionné et la caméra devient libre (ZQSD / WASD / flèches). En mode escouade, Échap quitte d'abord le mode (la composition reste enregistrée).
- Tab, 1-9, clic droit sur un survivant ou clic sur une tuile / vignette pour reprendre un survivant.

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
scripts/survivor_appearance.gd  apparence aléatoire et dessin du visage
scripts/resource_node.gd  point de récolte (la mare)
scripts/village_stock.gd  stock commun du village
scripts/ui/squad_bar.gd   barre d'escouade
scripts/ui/               interface : panneau de gestion, tuiles, vignettes, styles
data/weapons/*.tres       armes, modifiables dans l'inspecteur de Godot
tests/run_tests.gd        tests automatisés
```

## Graphismes

Tout est dessiné en code avec des formes simples. Format prévu pour les tuiles : **64×32 px** (losange isométrique 2:1). Les sprites remplaceront les fonctions `_draw()`.

## Tests

```
godot --headless --path . --import
godot --headless --fixed-fps 60 --path . -s tests/run_tests.gd
```
