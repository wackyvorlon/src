import random
from nltk.corpus import wordnet

def get_verbs_from_wordnet(count=20):
    """Extract action verbs from wordnet suitable for fantasy titles."""
    verbs = set()
    
    # Get all verb synsets and extract base verb forms
    for synset in wordnet.all_synsets(wordnet.VERB):
        for lemma in synset.lemmas():
            verb = lemma.name().replace('_', ' ').capitalize()
            # Filter for shorter, more impactful verbs (2-3 syllables typically)
            if 4 <= len(verb) <= 15 and verb not in verbs:
                verbs.add(verb)
                if len(verbs) >= count:
                    return sorted(list(verbs))
    
    return sorted(list(verbs))

def generate_fantasy_book_titles(count=10):
    """Generate random fantasy book titles."""
    
    adjectives = [
        "The Dark", "The Lost", "The Forgotten", "The Crimson",
        "The Eternal", "The Shattered", "The Cursed", "The Hidden",
        "The Broken", "The Silent", "The Ancient", "The Mystic"
    ]
    
    nouns = [
        "Kingdom", "Realm", "Crown", "Throne", "Tower", "Gate",
        "Prophecy", "Curse", "Dragon", "Phoenix", "Spell", "Artifact",
        "Sword", "Stone", "Shadow", "Light", "Forest", "Mountain"
    ]
    
    suffixes = [
        "of Power", "of Legends", "Rising", "Awakening", "Chronicles",
        "Saga", "Wars", "Quest", "Return", "Ascension", "Reckoning"
    ]
    
    verbs = get_verbs_from_wordnet(30)
    
    titles = set()
    while len(titles) < count:
        # Generate different title formats for variety
        style = random.choice(range(6))
        
        if style == 0:
            # Format: "Adjective Noun: Suffix"
            title = f"{random.choice(adjectives)} {random.choice(nouns)}: {random.choice(suffixes)}"
        elif style == 1:
            # Format: "Adjective Noun"
            title = f"{random.choice(adjectives)} {random.choice(nouns)}"
        elif style == 2:
            # Format: "Adjective Noun Suffix" (no colon)
            title = f"{random.choice(adjectives)} {random.choice(nouns)} {random.choice(suffixes)}"
        elif style == 3:
            # Format: "Noun of Suffix"
            title = f"{random.choice(nouns)} {random.choice(suffixes)}"
        elif style == 4:
            # Format: "Adjective Noun Verb"
            title = f"{random.choice(adjectives)} {random.choice(nouns)} {random.choice(verbs)}"
        else:
            # Format: "Noun: Adjective Suffix"
            title = f"{random.choice(nouns)}: {random.choice(adjectives).replace('The ', '')} {random.choice(suffixes)}"
        
        titles.add(title)
    
    return sorted(list(titles))

if __name__ == "__main__":
    fantasy_titles = generate_fantasy_book_titles(15)
    print("Generated Fantasy Book Titles:")
    print("-" * 40)
    for i, title in enumerate(fantasy_titles, 1):
        print(f"{i}. {title}")
