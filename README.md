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
| Stock d'objets (équiper / ranger) | I, ou bouton en haut à droite |
| Panneau debug | F1, ou bouton en haut à droite |

## Contenu du prototype v0.1

- Sol isométrique placeholder (tuiles 64×32) avec place du village, herbe, plage et mer.
- 4 survivants aux noms générés (dont 1 héros ★, sans capacité pour l'instant).
- Survivant contrôlé : déplacement, visée, tir. Les autres errent autour du feu de camp et tirent seuls sur les cibles à portée.
- Armes paramétrables : lance-pierre par défaut, fusil à pompe à ramasser au sud-ouest du village.
- (v0.1–0.9) Cibles d'entraînement, remplacées en v0.10 par des vagues de monstres.
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

## Ajouts v0.6 : faim, soif et bulles

- Jauges d'eau (vide en 4 min) et de nourriture (vide en 6 min), visibles dans le panneau et le HUD.
- En passant près du feu de camp, un survivant dépose sa charge puis boit et mange au stock commun.
- Sous 30 %, un survivant non contrôlé (hors escouade active) va de lui-même au stock, s'il y a de quoi ; stock vide = rien ne se passe.
- Jauge vide : vitesse × 0,6.
- Quand ça manque, le survivant le dit dans une bulle (répliques en humour noir), toutes les 7 à 12 s.
- **F10** (debug) : met tous les survivants en manque pour tester.

## Ajouts v0.7 : nourriture

- Bosquet de cocotiers au sud-ouest du village, en bord de plage : point de récolte de nourriture (3 s de cueillette).
- Même fonctionnement que la mare : clic droit dessus avec un survivant contrôlé, ou menu Tâche du panneau.
- Les survivants mangent ce qui arrive au stock quand leur jauge est sous 80 % : au début, le stock peut donc rester bas le temps que tout le monde soit rassasié.

## Ajouts v0.8 : coffres et loot

- 4 coffres sur la carte : on tire dessus pour les casser ; ils libèrent 1 à 3 objets qui jaillissent au sol.
- Nouvelles armes à trouver : pistolet rouillé, taser bricolé, sarbacane empoisonnée, fusil-harpon givré (rare), fusil à pompe.
- Ramassage : le survivant qui passe sur un objet le prend. S'il n'a que le lance-pierre, il équipe l'arme ; sinon elle va dans son sac (4 objets au niveau 1, +2 par niveau). Sac plein : l'objet reste au sol (le survivant le dit dans une bulle).
- Le sac est vidé dans le stock d'objets commun en passant au feu de camp (compteur « Objets » en haut). Mort en route = sac perdu.
- Les coffres ne sont pas des ennemis : le tir autonome ne les vise pas.

## Ajouts v0.9 : stock d'objets

- Panneau **Objets (I)** : à gauche les armes rapportées au village (regroupées, avec leurs stats et ≈ dégâts/s) ; à droite les survivants avec leur arme actuelle.
- Clic sur une arme pour la sélectionner, puis **Équiper** sur un survivant : son ancienne arme retourne au stock (le lance-pierre, lui, est toujours disponible).
- **Ranger** rend l'arme au stock et redonne le lance-pierre.
- Avec une arme sélectionnée, chaque survivant affiche le gain ou la perte de dégâts/s (vert / rouge).

## Ajouts v0.10 : vagues de monstres et panneau debug

- Les mannequins sont remplacés par des **monstres de base** : petites créatures cornues qui chassent le survivant le plus proche (ou marchent vers le village). Ils se jettent sur leur cible mais **ne font pas de dégâts** pour l'instant. 30 PV, 20 XP chacun.
- Les monstres arrivent en **vagues** depuis un bord de la carte (nord, est, sud ou ouest).
- **Panneau debug (F1)** :
  - Vagues : nombre de monstres, direction, lancer une vague, tuer tous les monstres, vagues automatiques toutes les 30 s.
  - Survivants : recruter, +100 XP au survivant contrôlé, soigner et rassasier, affamer tout le monde (F10).
  - Stock : +10 eau, +10 nourriture, +1 arme aléatoire.
  - Monde : faire réapparaître les coffres, vitesse du jeu ×1 / ×2 / ×4.
  - Infos : numéro de vague, monstres en vie, FPS.

## Ajouts v0.11 : ennemis postés et générateurs

- **Ennemis postés** : 3 camps sur la carte (dont un qui garde le coffre de l'est). Chaque monstre erre autour de son point d'attache, poursuit un survivant qui s'approche (≈ 200 px), puis abandonne et rentre s'il est entraîné trop loin de chez lui.
- **Générateurs de bots** (2, au nord-est et à l'ouest) : pylône au noyau lumineux qui produit un bot toutes les 7 s, 4 en vie au maximum, dans une zone marquée en pointillés rouges. 220 PV, 100 XP.
- Détruire un générateur arrête définitivement la production (zone orange) ; quand ses derniers bots sont morts, la zone est **sécurisée** (pointillés verts).
- Debug (F1) : replacer les ennemis, détruire les générateurs, compteurs de monstres et de générateurs.

## Ajouts v0.12 : crête rocheuse et passage gardé

- Une **crête rocheuse** coupe la carte en deux, du nord au sud, à l'est du village. Un **seul passage** la traverse, gardé par les **deux générateurs de bots**.
- La carte a maintenant une bordure : on ne peut plus sortir du sol.
- Les rochers arrêtent les tirs.
- Contournement simple : survivants (récolte, retour au stock, suiveurs d'escouade) et monstres passent automatiquement par le col quand leur destination est de l'autre côté.
- Côté est : un camp d'ennemis, le coffre gardé, et les générateurs. Côté village : la mare, les cocotiers, un camp à l'ouest.
- En mode gestion (aucun survivant sélectionné), la barre d'escouade est masquée.

## Ajouts v0.13

- Les survivants disent « Slurp ! » ou « Miam ! » quand ils boivent ou mangent au stock.
- Stock d'eau et de nourriture plafonné à **10** (affiché « 7/10 »). Stock plein : les récolteurs assignés font une pause au village (en gardant ce qu'ils portent) ; ils reprennent tout seuls quand le stock repasse sous 50 %.
- Badge d'assignation sur les vignettes (panneau, barre d'escouade, stock d'objets, HUD) : goutte = eau, noix de coco = nourriture ; barré quand la récolte est en pause.
- Les monstres présents dans la zone d'un générateur actif regagnent 4 PV/s (croix verte).
- Les bulles de dialogue proches s'empilent au lieu de se chevaucher.

## Ajouts v0.14 : bois

- Nouvelle ressource **bois**, destinée à la construction (elle ne se consomme pas).
- **Forêt** au nord du village : sapins, souches et bûches ; 4 s de coupe par trajet.
- Stock de bois plafonné à **20** ; même règle de pause et de reprise (sous 50 %) que l'eau et la nourriture.
- Le bûcheron rapporte un fagot de bûches sur le dos ; badge « bûche » sur sa vignette.
- Compteur « Bois » en haut de l'écran, « +10 bois » dans le panneau debug.

## Structure

```
scenes/main.tscn          scène principale
scripts/main.gd           montage du monde, sélection, caméra, HUD
scripts/survivor.gd       survivant : contrôle, errance, tir autonome, stats
scripts/name_generator.gd générateur de noms par syllabes multi-pays
scripts/weapon_data.gd    ressource « arme » (dégâts, cadence, dispersion, élément…)
scripts/projectile.gd     projectile
scripts/mob.gd            monstre de base (sans dégâts pour l'instant)
scripts/wave_manager.gd   vagues de monstres
scripts/mob_spawner.gd    générateur de bots
scripts/ridge.gd          crête rocheuse et bordure de carte
scripts/terrain.gd        relief et contournement par le passage
scripts/iso_ground.gd     sol isométrique placeholder
scripts/survivor_appearance.gd  apparence aléatoire et dessin du visage
scripts/resource_node.gd  points de récolte (mare, cocotiers, forêt)
scripts/village_stock.gd  stock commun du village
scripts/ui/squad_bar.gd   barre d'escouade
scripts/speech_bubble.gd  bulle de dialogue (phylactère)
scripts/loot_chest.gd     coffre de loot cassable
scripts/loot_table.gd     tirage du contenu des coffres
scripts/item_pickup.gd    objet au sol, ramassage
scripts/ui/loot_panel.gd  panneau du stock d'objets
scripts/ui/debug_panel.gd panneau debug (F1)
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
