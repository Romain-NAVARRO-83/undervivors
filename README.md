# Undervivors

Jeu d'action et de gestion en 2D isométrique : des survivants échoués sur une plage explorent un monde ouvert, combattent, récoltent et bâtissent un village. Mort permanente.

Moteur : **Godot 4.5** (GDScript). Le document de game design vit dans l'espace Notion « Igor ».

## Lancer le prototype

1. Installer [Godot 4.5](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir Godot → **Importer** → choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur **F5** (ou le bouton ▶ en haut à droite).
4. Menu titre : **Histoire** (le prologue, puis le chapitre 1), **Chapitre 1 — L'abri** (départ direct au chapitre 1), **Mode test** ou **Champ de tir** (essai des armes) (la carte de prototypage avec toutes les mécaniques et le panneau debug F1).

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
| Mode construction | B, ou bouton « Construire » en bas à droite |
| Alerte (tout le monde au camp) | H, ou bouton « ALERTE » en bas à droite |
| Mode histoire : lâcher le survivant (le temps file jusqu'à l'aube) | Espace |

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

## Ajouts v0.15 : constructions et alerte

- **Mode construction (B)** : choisir Mur (2 bois) ou Tourelle (6 bois) ; un aperçu vert/rouge suit la souris sur la grille iso et indique pourquoi un emplacement est refusé. Clic pour poser, clic maintenu pour une ligne de murs, clic droit / Échap pour annuler.
- **Chantier** : la construction se monte toute seule (mur 4 s, tourelle 8 s), sans survivant ; échafaudage et barre de progression. Un chantier est fragile, ses PV montent avec l'avancement.
- **Murs** : bloquent les monstres ; les survivants passent (comme par des portes).
- **Dégâts** : les monstres frappent les constructions collées à eux (8 par coup). Une construction détruite libère sa case. Les survivants, eux, ne sont toujours pas blessés.
- **Tourelles** : arbalète lourde (14 dégâts, 2 tirs/s, portée 430) qui ne tire que si un survivant y est **assigné** et à son poste (clic droit sur la tourelle avec un survivant contrôlé, ou menu Tâche « Servir : Tourelle n°X »). Voyant vert quand elle est servie ; l'XP revient au servant ; badge viseur sur sa vignette.
- **Alerte (H)** : tous les survivants libres rentrent se poster autour du feu de camp et tirent ; les servants restent à leur tourelle ; à la levée de l'alerte, chacun reprend sa tâche. Bandeau rouge pendant l'alerte.
- Debug : chantiers instantanés, construction gratuite.
- (v0.16) Murs et tourelles sont des **blocs iso 2D** à l'empreinte exacte d'une tuile (64×32) et de faible hauteur (mur 18 px, tourelle 24 px) ; collision et contact des monstres suivent le losange.

## Ajouts v0.17 : monde agrandi

- Carte environ 1,8× plus grande (81 × 81 tuiles), avec plage et mer le long des deux côtes sud.
- Place du village (zone marron) agrandie : rayon ≈ 9,5 tuiles autour du feu.
- **On ne construit que sur la place du camp** ; ailleurs, l'aperçu est rouge avec le message « Seulement sur la place du camp (zone marron) ».
- Contenu redistribué hors de la place : mare, cocotiers, forêt, 5 coffres, 5 camps d'ennemis ; crête rocheuse repoussée vers l'est (x = 900), toujours un seul passage gardé par les deux générateurs ; tout un territoire à explorer derrière.
- Vagues et caméra libre adaptées à la nouvelle taille.

## Ajouts v0.18 : arbres

- ~370 arbres non abattables (feuillus et conifères), placés sur la grille iso, qui bloquent survivants, monstres et tirs (petit tronc).
- **Lisière** dense sur les deux bords nord de la carte ; pas d'arbres sur la plage ni dans la mer.
- **Bosquets** dispersés sur l'herbe, en gardant dégagés : la place du camp, chaque point de récolte, coffre, camp, générateur, l'arrivée des vagues, et des **couloirs** entre le camp (ou le col) et chacun d'eux.
- Placement reproductible (graine fixe), réglable dans scripts/tree_field.gd.


## Ajouts v0.19 : blessures et mort

- Les monstres **mordent** : à chaque bond au contact, 8 PV en moins (un bond toutes les 1,2 s, soit ~7 PV/s par monstre). Chiffres rouges, survivant qui flashe, barre de PV verte → jaune → rouge.
- **Mort définitive** à 0 PV : le survivant disparaît avec ce qu'il portait, une **tombe** (croix de travers et « R.I.P. Prénom Nom ») reste sur place, message à l'écran.
- **Soin lent sur la place du camp** : 3 PV/s, après 5 s sans être touché, tant que les jauges d'eau et de nourriture ne sont pas vides.
- Un survivant **libre** (errance ou récolte) sous 30 % de PV **rentre se soigner** au camp et repart à 80 %. Les suiveurs d'escouade et le survivant contrôlé, eux, restent aux ordres du joueur.
- Bulles d'humour noir quand on se fait mordre.
- Debug (F1) : case « Monstres inoffensifs ».

## Ajouts v0.20 : types de monstres, niveaux, éléments

- **4 types de monstres**, réglables dans `data/mobs/*.tres` (comme les armes) :

| Type | Attaque | Vitesse | PV (niv. 1) | Dégâts | Éléments |
|---|---|---|---|---|---|
| Rongeur | corps à corps | moyenne | 30 | 8 | — |
| Cracheur | à distance (crachats lents, esquivables), garde ses distances | lente | 25 | 6 | faible feu, résiste poison |
| Cogneur | corps à corps, gros et lent | lente | 120 | 20 | faible électrique, résiste poison |
| Feu follet | corps à corps, flotte | rapide | 20 | 5 | immunisé feu, faible glace (×2) |

- **Niveaux** : par niveau au-delà du premier, +20 % de PV, +15 % de dégâts, +25 % d'XP. Affichés au-dessus des monstres (« Niv. 3 »).
- **Zones de niveau** : 1 autour du camp, 2 sur le reste de la côte ouest, 3 au-delà de la crête. Les ennemis postés prennent le niveau de leur zone ; chaque générateur a son propre niveau (2) et sa liste de types (rongeurs, cracheurs). Le HUD indique la zone du survivant contrôlé.
- **Monstre spécial** : « Le Vieux Cogneur », niveau 4, posté à l'est de la crête. ×4 PV, ×1,5 dégâts, ×4 XP, plus gros, aura dorée ; laisse 2 à 4 objets à sa mort.
- **Effets élémentaires actifs** (sur les monstres) :
  - **Feu** : brûlure 3 s (la moitié des dégâts de feu par seconde), relancée par chaque coup, ne se cumule pas.
  - **Poison** : 5 s, se cumule jusqu'à 5 doses (30 % des dégâts de poison par seconde et par dose).
  - **Glace** : ralentit de 40 % pendant 2 s (plus sur un monstre faible).
  - **Électrique** : un arc touche jusqu'à 2 monstres à moins de 80 px (60 % des dégâts électriques).
  - Résistances et faiblesses multiplient la part élémentaire ; immunité = ni dégâts ni effet (« Immunisé » s'affiche). Chiffres colorés par élément, « ! » sur une faiblesse.
  - Un monstre tué par brûlure, poison ou arc donne son XP au dernier tireur.
- Debug (F1) : niveau et type des vagues (ou « Mixte ») ; le niveau sert aussi aux vagues automatiques.

## Ajouts v0.21 : récolte plus efficace

- Quantité rapportée par trajet : **2 + 2 × niveau** (4 au niveau 1, 8 au niveau 3), au lieu de 1 + niveau.
- Les récolteurs vont **plus vite** sur leurs trajets : 1,2 × leur vitesse normale (au lieu de 0,75 ×).
- Réglages dans `scripts/survivor.gd` : `CARRY_BASE`, `CARRY_PER_LEVEL`, `WORK_SPEED_MULT`.

## Ajouts v0.22 : tir groupé sur les coffres, texte net

- En mode escouade, quand le **leader tire sur un coffre**, tous les suiveurs à portée tirent dessus aussi jusqu'à ce qu'il casse. Exception : un suiveur qui a un monstre à moins de 120 px se défend d'abord.
- **Texte plus net** : police en MSDF (reste nette à tous les zooms et toutes les résolutions) et filtrage linéaire par défaut au lieu de « nearest ». Concerne l'interface comme les textes dans le monde (noms d'objets, niveaux, dégâts, bulles).

## Ajouts v0.23 : murs infranchissables, anticrénelage

- **Murs et tourelles infranchissables** pour tous, survivants compris. Survivants et monstres les **contournent** (navigation A* sur la grille des tuiles, `scripts/nav.gd`) : les murs canalisent les monstres vers les passages.
- Un monstre **bloqué** contre une construction (ou à l'arrêt à son contact) la frappe ; sinon il la contourne.
- **Impossible de fermer une enceinte** : une pose est refusée si une case libre de la place du camp se retrouvait coupée de l'extérieur (« Fermerait une enceinte : laissez un passage »). Deux constructions qui se touchent par un coin bloquent le passage entre elles.
- **Anticrénelage 2D** (MSAA 4×) : bords des formes plus lisses (rendu Forward+).

## Ajouts v0.24 : servants perchés sur les tourelles

- Le servant **monte sur la plateforme** de sa tourelle et y reste ; il redescend devant elle quand il la quitte (boire, manger, reprise en main, tourelle détruite).
- Perché, il est **hors d'atteinte des monstres au corps à corps** ; les cracheurs peuvent encore le viser.
- Bouton **« Libérer <prénom> »** au-dessus de chaque tourelle servie : dissocie le servant, qui redescend et retourne errer au camp.

## Ajouts v0.25 : menu titre et début du mode histoire

- **Menu titre** : Histoire, Mode test, Quitter. Le mode test est la carte de prototypage habituelle, inchangée.
- **Prologue « La plage »** (mode histoire) : un seul survivant se réveille au milieu des débris fumants d'un accident dont il ne se souvient pas. La plage est coincée entre la mer et une **butte rocheuse infranchissable** qu'on longe vers l'est ; au bout, on la contourne pour passer de l'autre côté.
- Le prologue apprend les bases, un objectif à la fois (panneau en haut à gauche) :
  1. se déplacer ;
  2. longer la butte (on ne peut ni la franchir ni nager) ;
  3. viser et tirer sur un coffre, ramasser ce qui tombe (un pistolet rouillé) ;
  4. abattre un premier monstre, puis deux autres ;
  5. trouver le bout de la butte et passer de l'autre côté → fin du prologue.
- Pas de faim ni de soif dans le prologue. Mort définitive : écran « Recommencer / Menu titre ».
- **Échap** : pause (reprendre, recommencer, menu titre).

## Ajouts v0.26 : nouveau déroulé du prologue

Le prologue suit désormais cette histoire (demande de Romain) :

1. Réveil sur la plage, **sans arme**, au milieu des débris. **Aucun monstre sur la plage.**
2. On longe la butte vers l'est. Au bout, on rencontre un **second survivant** qui se joint à nous et nous **suit** (escouade de deux, pas encore de changement de personnage).
3. Plus loin, au nord-ouest, des **monstres à éviter** (on n'a pas d'arme) ; une **embuscade blesse notre ami** (il ne peut pas mourir pendant le prologue).
4. Plus loin, un **refuge** avec un feu de camp : l'ami blessé y reste et s'y soigne ; on part **seul chercher de l'eau** (à l'ouest).
5. (v0.27) Deux bouteilles d'eau à trouver et à rapporter au feu ; l'ami vient boire.
6. **Premier changement de survivant** (Tab ou clic droit sur l'ami) : fin du prologue.

Une flèche autour du personnage montre la direction de l'objectif quand il y en a une.

(v0.28) Plage raccourcie d'environ 40 % : la butte fait ~2 100 px au lieu de 3 600 ; la suite (ami, monstres, refuge, eau) est rapprochée d'autant.

## Ajouts v0.27 : unités d'eau et de nourriture à looter

- Nouvel objet : les **unités de ressources** (`data/items/eau.tres` « Bouteille d'eau », `data/items/nourriture.tres` « Boîte de conserve »). On les trouve au sol ou dans les coffres, à côté des sources continues (mare, cocotiers).
- Ramassées, elles vont dans le **sac** ; au feu de camp, elles rejoignent le **stock du village** (eau, nourriture).
- **Un survivant qui a soif (ou faim) et qui en transporte une la consomme lui-même** (« Slurp ! », « Miam ! »).
- Les coffres du mode test peuvent maintenant en contenir.
- **Prologue** : plus de mare. Au refuge, l'ami blessé a soif ; on part seul trouver **deux bouteilles d'eau** à l'ouest, on les rapporte au feu, l'ami vient boire, puis **premier changement de survivant** (Tab ou clic droit sur l'ami), qui termine le prologue.

## Ajouts v0.29 : survivants en 3D iso (sprites pré-rendus, 8 directions)

- Les survivants sont affichés avec des **sprites pré-rendus en 3D** : un modèle low-poly cartoon (contour noir, ombrage en aplats) rendu sous l'angle iso du jeu.
- **8 directions** : le survivant regarde vers sa **visée** s'il est armé, sinon dans le **sens de la marche** (il garde sa direction à l'arrêt).
- **Animation** : 1 image de repos + 6 images de marche, cadence proportionnelle à la vitesse.
- **Variété conservée** : une planche par coiffure (chauve, court, hérissé, long, chignon) ; la peau, les cheveux et le vêtement sont teintés en jeu selon l'apparence de chaque survivant. Flash rouge quand il est blessé ; anneau doré au sol pour les héros.
- Les vignettes de l'interface (panneau, escouade) gardent le visage dessiné en 2D.

### Planches de sprites

Fichiers : `assets/survivors/<coiffure>_shade.png` et `<coiffure>_mask.png`.

- **Disposition** : 7 colonnes (0 = repos, 1 à 6 = marche) × 8 lignes (directions : 0 = est, puis dans le sens horaire à l'écran : sud-est, sud (face), sud-ouest, ouest, nord-ouest, nord (dos), nord-est). Images de 128 × 160 px, **pieds au point (64, 150)**.
- `_shade` : le rendu ; peau, cheveux et vêtement y sont **blancs** (teintés en jeu).
- `_mask` : rouge = peau, vert = cheveux, bleu = vêtement, noir ailleurs.
- **Régénérer** les placeholders (fenêtre requise) :
  `godot --path . --rendering-method gl_compatibility -s tools/bake_survivor_sprites.gd`
  Le modèle 3D est dans `tools/survivor_model.gd`.
- **Remplacer par des rendus définitifs** : garder la même disposition et le même point des pieds. Une planche déjà en couleurs fonctionne aussi : il suffit de supprimer le `_mask.png` correspondant (plus de teinte).
- Sans planche pour une coiffure, le survivant est dessiné à l'ancienne (2D).
## Ajouts v0.30 : chapitre 1 « L'abri »

Le mode histoire continue après le prologue, **sur la même carte agrandie vers le nord** (le bord nord du prologue s'ouvre). Le menu titre permet aussi d'y aller directement.

1. Carton « Chapitre 1 — L'abri ». Les deux survivants sont au refuge, **sans arme**. **Faim et soif reprennent** ; **mort définitive** (plus de protection pour l'ami). L'un reste au camp : il a planté des **piquets** pour la future cabane.
2. **Trouver une arme** : un lance-pierre traîne à terre au nord du refuge, dans une valise éventrée. On le ramasse en passant dessus (pas de corps à corps).
3. **Premier combat** : un rongeur à abattre.
4. **Exploration libre** de trois coins, gardés par des monstres postés :
   - **la crique** (ouest) : bois flotté, un coffre avec de l'eau ;
   - **l'épave** (nord-est) : un second morceau de l'appareil, des planches, un coffre avec une **sarbacane** et une conserve ;
   - **le bosquet** (nord) : monstres de niveau 2, conserves, un coffre bien garni.
   On remplit son **sac** (4 objets au niveau 1) et on rapporte au feu. Objectif : **8 bois au stock** et **3 rations de nourriture rapportées**. Après 45 s sans rien ramasser, la flèche montre le loot le plus proche (ou le feu si le sac est plein).
5. **Construire la cabane** : aux piquets, **E** ou clic (8 bois). Le chantier se monte tout seul (14 s).
6. La cabane est debout : **fin du chapitre 1**.

Autres ajouts :
- Nouvel objet : **Planche** (`data/items/planche.tres`), une unité de **bois** à looter, qui rejoint le stock au feu.
- Une **arme rapportée au feu** va au survivant du camp qui n'en a pas. En mode histoire, l'arme remplacée au ramassage (le lance-pierre) part dans le sac au lieu de disparaître.
- **Tab** change de survivant quand on veut ; **F** : l'autre survivant nous suit, ou retourne attendre au refuge. Si l'un meurt, on continue avec l'autre (une tombe reste) ; s'ils meurent tous les deux, « Recommencer » relance le chapitre.
- Le panneau en haut à gauche affiche soif, faim et le stock du refuge.

Corrections :
- Prologue : le premier survivant pouvait boire au feu l'eau rapportée pour l'ami (test du prologue qui échouait de temps en temps).
- Un survivant blessé qui se soigne au camp va quand même boire et manger au stock.

## Ajouts v0.31 : tirs plus faciles à placer, animation d'impact

- **Zone de touche des balles agrandie** : rayon 8 px au lieu de 3, et recalée sur le sol. La balle vole à hauteur de buste alors que les monstres ont leur zone de touche aux pieds : on ratait des tirs qui passaient visuellement sur le monstre. Réglages en tête de `scripts/projectile.gd` (`HIT_RADIUS`, `HIT_DROP`).
- **Animation d'impact** (`scripts/hit_effect.gd`) : éclair blanc, onde qui s'élargit et éclats projetés vers l'avant du tir, aux couleurs de la balle. Variantes : échardes sur un coffre ou une construction, poussière sur un rocher ou un arbre.
- **Le monstre touché s'écrase** puis reprend sa forme, en plus du flash blanc.

## Ajouts v0.32 : recul des armes

- Nouvelle stat d'arme **Recul** (`recoil` dans les `.tres`, réglable dans l'inspecteur) : à chaque tir, le tireur est repoussé en arrière de sa visée d'environ ce nombre de pixels, et la caméra du survivant dirigé tressaute.
- Valeurs de départ : lance-pierre **0** (pas de recul), sarbacane 0, taser 4, pistolet 10, fusil-harpon 16, fusil à pompe 26.
- Un servant perché sur une tourelle ne bouge pas. Le recul s'affiche dans le stock d'objets.

## Ajouts v0.33 : champ de tir

Nouvelle entrée **Champ de tir** dans le menu titre : une petite carte pour essayer les armes.

- **Toutes les armes** de `data/weapons` (une arme ajoutée y apparaît toute seule), au choix par boutons ou touches **1 à 9**, avec leurs stats (dégâts, cadence, dispersion, portée, vitesse, recul, élément).
- **Cercle de portée** de l'arme autour du survivant.
- **Mannequins** à PV infinis à 100, 200, 300 et 400 px, en éventail pour qu'aucun ne cache l'autre, plus un **mannequin mobile** sur rail. Chacun affiche ses dégâts reçus et ses dégâts/s.
- **Statistiques** : tirs, touches, précision, dégâts/s sur 3 s, dégâts totaux. **R** remet à zéro (et chaque changement d'arme).
- **Monstres** à faire apparaître (rongeur, cracheur, cogneur, feu follet), niveau 1 à 10, **inoffensifs** ou non : pour tester éléments, résistances et faiblesses. Un rocher pour les impacts sur obstacle.
- Le survivant ne meurt pas et n'a ni faim ni soif. **Échap** : retour au menu.

Correction : une balle encore en vol quand son tireur meurt ne provoque plus d'erreur (Godot 4.7).

## Ajouts v0.34 : cycle jour/nuit (mode histoire)

- **Cycle jour/nuit** (`scripts/day_night.gd`) : une journée dure 8 min réelles, le jour (6 h → 21 h) 5 min 30, la nuit (21 h → 6 h) 2 min 30. Le monde se teinte au crépuscule puis s'assombrit ; le feu du refuge, la fenêtre de la cabane et une petite lueur autour du survivant dirigé éclairent la nuit. Horloge dans le panneau (« ☀ Jour 1 · 14 h 30 »). Le prologue commence à 8 h, le chapitre 1 à 9 h. Réglages en tête du script (`DAY_SECONDS`, `NIGHT_SECONDS`, `DAWN`, `DUSK`).
- **La nuit, les survivants non dirigés rentrent dans la cabane** : ils marchent jusqu'à la porte et disparaissent à l'intérieur (hors d'atteinte des monstres, ils s'y soignent), puis ressortent au lever du jour. Avant la cabane, ils se serrent autour du feu.
- Exceptions : un survivant qui **nous suit** (F) reste avec nous ; **Tab** sur un survivant qui dort le fait ressortir par la porte ; les servants de tourelle restent à leur poste.
- **Fin du chapitre 1** : la cabane terminée, la nuit tombe et l'autre survivant va s'y coucher. Nouveau bouton **Continuer** sur l'écran de fin : on reste sur l'île en exploration libre.
- Le mode test et le champ de tir n'ont pas de nuit.

## Ajouts v0.35 : cadran du temps, vignette du survivant, temps accéléré

- **Cadran du temps** en haut de l'écran (mode histoire) : un disque partagé entre le jour (ciel clair) et la nuit (étoiles), midi en haut, minuit en bas ; une aiguille terminée par le soleil ou la lune tourne avec l'heure. Dessous : « Jour 2 · 14 h 30 », et ⏩ quand le temps est accéléré.
- **Vignette du survivant dirigé** en bas à gauche : portrait, nom, niveau, arme, sac, jauges de PV, d'eau, de nourriture et d'XP.
- **Espace** (chapitre 1) : on lâche le survivant dirigé, qui redevient libre. Sans survivant dirigé, **le temps passe ×8 jusqu'à l'aube**, puis reprend son cours ; la caméra se déplace au clavier (ZQSD / flèches). **Tab** ou **clic droit** sur un survivant pour en reprendre un (le temps reprend alors son cours normal).

## Ajouts v0.36 : portions d'eau et de nourriture, panneau développeur du mode histoire

- **Une bouteille d'eau et une boîte de conserve font 3 portions.** Dans le sac, un survivant qui a soif (ou faim) en consomme **une portion** (25 points) et garde le reste ; l'objet disparaît quand il est vide. Au feu, les portions restantes vont au stock (1 portion = 1 unité) ; si le stock est plein, l'objet entamé reste dans le sac. Le nombre de portions se règle dans `data/items/*.tres` (`amount`), et s'affiche au sol : « Bouteille d'eau (3/3) ».
- Chapitre 1 : l'objectif de nourriture passe à **6 portions** (2 conserves).
- **Panneau développeur du mode histoire** (**F1**, ou bouton « Dev » en haut à droite) :
  - **Temps** : +1 h, +6 h, aube, midi, crépuscule, minuit ; pause, ×1, ×4, ×16.
  - **Survivant dirigé** : soigner, blesser, remplir ou vider eau et faim, +100 XP, retour au refuge, équiper n'importe quelle arme ; **invincibles**.
  - **Tous les survivants** : soigner, nourrir.
  - **Stock du refuge** : +3 eau, +3 nourriture, +8 bois, vider.
  - **Monstres** : inoffensifs, tuer les proches, tuer tous.
  - **Déroulé** : **étape suivante** (prologue et chapitre 1, téléporte au besoin), aller au chapitre 1, finir la cabane, révéler l'objectif.

## Ajouts v0.37 : arbres sur la grille, sentiers et repères, nouvelles armes et générateur

**Arbres** : chaque arbre occupe **une case entière** de la grille iso (calé au centre, collision = losange de la case) et la case est **bloquée pour la navigation** : survivants et monstres le contournent au lieu de s'y coincer. La grille de navigation couvre maintenant toute la carte du mode histoire.

**Chapitre 1 : sentiers et repères** pour s'orienter :
- des **sentiers** de terre battue relient le refuge à un **carrefour**, puis le carrefour à la crique, au bosquet et à l'épave (et le refuge à la plage) ; rien ne pousse dessus ;
- **panneaux** au carrefour (Bosquet, Crique, Épave, Refuge) et près du refuge ;
- **cairns** le long des sentiers, un **drapeau** rouge à la crique, un grand **arbre mort** à l'entrée du bosquet ;
- des bosquets épars dans la prairie.

**Armes** : 15 armes faites à la main, de niveau 1 à 5 (`tier`), dont **9 nouvelles** : lance-clous, arbalète bricolée (perforante), boomerang de plage, **fusil d'assaut** rouillé, **catapulte de fortune** (tir en cloche, explosion, fort recul), fusil de précision, fusil d'assaut militaire, **mortier rouillé** (tir en cloche, grosse explosion, très fort recul), mitrailleuse lourde.

Nouveaux effets d'arme (`WeaponData`) : tir en cloche (vole par-dessus les obstacles jusqu'au point visé), explosion (dégâts de zone dégressifs), perforation, ricochets, tête chercheuse, trajectoire ondulante, fragmentation, vampire, élément au hasard, boomerang, projectiles géants, poissons.

**Générateur d'armes aléatoires** (`scripts/weapon_generator.gd`), à la Borderlands : une base + un niveau + une **rareté** (commune → légendaire) + un **fabricant** (Rouille & Fils, Bricol'Tout, Précis-Mouette, Boum SARL, Coco Arms, Épave & Cie) + 0 à 3 **effets bizarres** + parfois un élément. Le nom se compose tout seul (« Fusil d'assaut rouillé à ricochets de feu ») ; les légendaires ont un nom propre. Les coffres du mode test et le butin des monstres spéciaux peuvent en contenir. Au **champ de tir** : liste déroulante de toutes les armes, bouton **Générer [G]** (niveau et rareté au choix) ; la précision compte une touche par tir.

## Ajouts v0.38 : barre du haut (stocks et heure), sac dans la vignette

- **Barre du haut** (mode histoire) : le cadran du temps au centre, entouré des **stocks du refuge** (eau, nourriture, bois) avec leur capacité ; un stock vide passe au rouge, un stock plein au vert. Les stocks quittent le panneau de gauche.
- **Vignette du survivant dirigé** : son **sac** s'affiche, une case par place, avec l'icône de chaque objet et les portions restantes de l'eau et de la nourriture.

## Structure

```
scenes/main.tscn          scène principale
scripts/main.gd           montage du monde, sélection, caméra, HUD
scripts/survivor.gd       survivant : contrôle, errance, tir autonome, stats
scripts/name_generator.gd générateur de noms par syllabes multi-pays
scripts/weapon_data.gd    ressource « arme » (dégâts, cadence, dispersion, élément…)
scripts/projectile.gd     projectile (effets spéciaux, tir en cloche)
scripts/explosion.gd      explosion : dégâts de zone et effet visuel
scripts/weapon_generator.gd  armes aléatoires (rareté, fabricant, effets)
scripts/story/landmark.gd  repères du mode histoire (panneaux, cairns, drapeau, arbre mort)
scripts/day_night.gd      cycle jour/nuit du mode histoire (teinte, lumières, heure)
scripts/hit_effect.gd     animation d'impact des tirs
scripts/wave_manager.gd   vagues de monstres
scripts/mob_spawner.gd    générateur de bots
scripts/ridge.gd          crête rocheuse et bordure de carte
scripts/tree_field.gd     arbres obstacles (lisière et bosquets)
scripts/terrain.gd        relief et contournement par le passage
scripts/buildings/        constructions : base, mur, tourelle, gestionnaire de pose
scripts/ui/build_bar.gd   barre de construction
scripts/iso_ground.gd     sol isométrique placeholder
scripts/survivor_appearance.gd  apparence aléatoire et dessin du visage
scripts/resource_node.gd  points de récolte (mare, cocotiers, forêt)
scripts/village_stock.gd  stock commun du village
scripts/ui/squad_bar.gd   barre d'escouade
scripts/speech_bubble.gd  bulle de dialogue (phylactère)
scripts/grave.gd          tombe laissée à la mort d'un survivant
scripts/mob.gd            monstres : comportements, attaques, effets élémentaires
scripts/mob_type.gd       type de monstre (ressource), tirage des vagues mixtes
scripts/level_zones.gd    niveau des monstres selon la zone de la carte
scripts/enemy_projectile.gd  crachat des monstres à distance
scripts/consumable_data.gd   unités de ressources à ramasser (eau, nourriture)
scripts/survivor_sprite.gd   affichage des survivants (planches 8 directions, teinte)
shaders/survivor_tint.gdshader  teinte peau / cheveux / vêtement
tools/                    générateur des planches (modèle 3D + rendu)
assets/survivors/         planches de sprites des survivants
data/items/*.tres         unités de ressources
scripts/nav.gd            contournement des constructions (A*), refus des enceintes fermées
data/mobs/*.tres          types de monstres, modifiables dans l'inspecteur de Godot
scripts/loot_chest.gd     coffre de loot cassable
scripts/loot_table.gd     tirage du contenu des coffres
scripts/item_pickup.gd    objet au sol, ramassage
scripts/ui/loot_panel.gd  panneau du stock d'objets
scripts/ui/debug_panel.gd panneau debug (F1)
scripts/ui/day_dial.gd    cadran du temps (mode histoire)
scripts/ui/top_bar.gd     barre du haut : stocks du refuge et cadran
scripts/ui/item_icon.gd   icônes d'objets dessinées en code
scripts/ui/story_dev_panel.gd  panneau développeur du mode histoire (F1)
scripts/ui/survivor_card.gd  vignette du survivant dirigé (mode histoire)
scripts/ui/               interface : panneau de gestion, tuiles, vignettes, styles
data/weapons/*.tres       armes, modifiables dans l'inspecteur de Godot
tests/run_tests.gd        tests automatisés (mode test)
tests/run_story_tests.gd  tests automatisés du prologue
scripts/menu.gd           menu titre
scripts/range/            champ de tir : carte, mannequins
scripts/input_setup.gd    touches du jeu (partagées)
scripts/story/            mode histoire : prologue (déroulé), carte de la plage, sol, débris, palmiers
scripts/story/chapter1.gd chapitre 1 « L'abri » : loot, monstres, cabane (enchaîne sur le prologue)
scripts/story/cabin.gd    la cabane du refuge (construction 2 × 2 tuiles)
```

## Graphismes

Les survivants utilisent des planches de sprites pré-rendues en 3D (voir « Planches de sprites ») ; le reste est dessiné en code avec des formes simples. Format prévu pour les tuiles : **64×32 px** (losange isométrique 2:1). Les sprites remplaceront les fonctions `_draw()`.

## Tests

```
godot --headless --path . --import
godot --headless --fixed-fps 60 --path . -s tests/run_tests.gd
godot --headless --fixed-fps 60 --path . -s tests/run_story_tests.gd
godot --headless --fixed-fps 60 --path . -s tests/run_chapter1_tests.gd
godot --headless --fixed-fps 60 --path . -s tests/run_range_tests.gd
godot --headless --fixed-fps 60 --path . -s tests/run_daynight_tests.gd
godot --headless --fixed-fps 60 --path . -s tests/run_story_dev_tests.gd
godot --headless --fixed-fps 60 --path . -s tests/run_weapons_tests.gd
```
