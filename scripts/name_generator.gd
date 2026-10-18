class_name NameGenerator
extends RefCounted
## Génère des noms « Prénom Nom » à partir de syllabes de prénoms classiques
## de plusieurs pays (voir GDD, section 5.2).
## Règle : le prénom et le nom ont chacun 2 à 4 syllabes, toutes de pays différents.

const MIN_SYLLABLES := 2
const MAX_SYLLABLES := 4

## Syllabes extraites de prénoms classiques, par pays.
## À enrichir librement : il faut au moins MAX_SYLLABLES pays.
const SYLLABLES := {
	"France": ["jean", "ma", "rie", "pier", "lu", "cie", "an", "toi", "ne", "lou", "ise", "ga", "bri", "el", "mar", "cel"],
	"Italie": ["gio", "van", "ni", "fran", "ces", "co", "lu", "ca", "chia", "ra", "mat", "teo", "ro", "sa", "pa", "olo"],
	"Espagne": ["car", "men", "die", "go", "jo", "se", "lu", "is", "pa", "blo", "ma", "nu", "lo", "res", "al", "ba"],
	"Allemagne": ["hans", "gre", "tel", "fritz", "lie", "sel", "wolf", "gang", "hel", "ga", "kurt", "ul", "rich", "ber", "ta", "o"],
	"Japon": ["ha", "ru", "ki", "yu", "mi", "sa", "ku", "ra", "ta", "ro", "ken", "ji", "ai", "ko", "hi", "to"],
	"Russie": ["i", "van", "ol", "ga", "dmi", "tri", "na", "ta", "sha", "bo", "ris", "ve", "ra", "mi", "kha", "il"],
	"Nigeria": ["chi", "nwe", "a", "de", "o", "lu", "wa", "fe", "mi", "ka", "yo", "bun", "mi", "tun", "de", "ji"],
	"Inde": ["ra", "vi", "pri", "ya", "a", "run", "an", "ja", "li", "dev", "san", "jay", "mee", "ra", "kri", "sh"],
	"Brésil": ["jo", "ão", "the", "go", "ra", "fa", "el", "lu", "iz", "bea", "triz", "ga", "bri", "ela", "cai", "o"],
	"Irlande": ["sea", "mus", "sio", "bhan", "pa", "draig", "ai", "fe", "con", "nor", "or", "la", "ci", "ar", "ro", "nan"],
	"Grèce": ["ni", "kos", "e", "le", "ni", "di", "mi", "tri", "os", "so", "fi", "a", "yan", "nis", "ze", "us"],
	"Turquie": ["meh", "met", "a", "yse", "mus", "ta", "fa", "el", "if", "ze", "ynep", "em", "re", "bu", "rak", "can"],
}


## Retourne un nom complet « Prénom Nom ».
static func generate(rng: RandomNumberGenerator = null) -> String:
	return "%s %s" % [generate_part(rng)["text"], generate_part(rng)["text"]]


## Retourne un dictionnaire avec le texte d'une partie du nom et le détail
## des syllabes tirées : { "text": String, "syllables": [ { "s": String, "country": String } ] }
static func generate_part(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var countries: Array = SYLLABLES.keys()
	var count := rng.randi_range(MIN_SYLLABLES, MAX_SYLLABLES)
	# Mélange des pays puis on en prend `count` : garantit des pays différents.
	var shuffled := countries.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var picked: Array = []
	var text := ""
	for k in count:
		var country: String = shuffled[k]
		var list: Array = SYLLABLES[country]
		var syllable: String = list[rng.randi_range(0, list.size() - 1)]
		picked.append({"s": syllable, "country": country})
		text += syllable
	return {"text": _capitalize_first(text), "syllables": picked}


static func _capitalize_first(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)
