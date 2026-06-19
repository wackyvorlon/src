
# A script to randomly generate fantasy book titles.

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

def get_adjectives_from_wordnet(count=20):
    """Extract adjectives from wordnet suitable for fantasy titles."""
    adjectives = set()
    
    # Get all adjective synsets and extract base adjective forms
    for synset in wordnet.all_synsets(wordnet.ADJ):
        for lemma in synset.lemmas():
            adj = lemma.name().replace('_', ' ').capitalize()
            # Filter for meaningful adjectives (3-12 characters)
            if 3 <= len(adj) <= 12 and adj not in adjectives:
                adjectives.add(adj)
                if len(adjectives) >= count:
                    return sorted(list(adjectives))
    
    return sorted(list(adjectives))

def get_nouns_from_wordnet(count=20):
    """Extract nouns from wordnet suitable for fantasy titles."""
    nouns = set()
    
    # Get all noun synsets and extract base noun forms
    for synset in wordnet.all_synsets(wordnet.NOUN):
        for lemma in synset.lemmas():
            noun = lemma.name().replace('_', ' ').capitalize()
            # Filter for meaningful nouns (4-15 characters)
            if 4 <= len(noun) <= 15 and noun not in nouns:
                nouns.add(noun)
                if len(nouns) >= count:
                    return sorted(list(nouns))
    
    return sorted(list(nouns))

def title_case(text):
    """Return a properly capitalized title string."""
    small_words = {
        "a", "an", "and", "as", "at", "but", "by", "for",
        "from", "in", "of", "on", "or", "the", "to", "with"
    }

    words = text.split()
    result = []
    prev_token = ""

    for index, word in enumerate(words):
        raw = word
        prefix = ""
        suffix = ""

        while raw and not raw[0].isalnum():
            prefix += raw[0]
            raw = raw[1:]
        while raw and not raw[-1].isalnum():
            suffix = raw[-1] + suffix
            raw = raw[:-1]

        lower_word = raw.lower()
        should_capitalize = (
            index == 0
            or prev_token.endswith(":")
            or lower_word not in small_words
        )

        if should_capitalize:
            raw = raw.capitalize()
        else:
            raw = lower_word

        result.append(f"{prefix}{raw}{suffix}")
        prev_token = word

    return " ".join(result)

def generate_fantasy_book_titles(count=10):
    """Generate random fantasy book titles."""
    
    adjectives = ["The " + adj for adj in get_adjectives_from_wordnet(30)]
    
    nouns = get_nouns_from_wordnet(30)
    
    suffixes = [
        "of Power", "of Legends", "Rising", "Awakening", "Chronicles",
        "Saga", "Wars", "Quest", "Return", "Ascension", "Reckoning"
    ]
    
    verbs = get_verbs_from_wordnet(30)
    
    titles = set()
    while len(titles) < count:
        # Generate different title formats for variety
        style = random.choice(range(6))
        suffix = random.choice(suffixes)
        
        if style == 0:
            # Format: "Adjective Noun: Suffix" or "Adjective Noun Suffix" (no colon if suffix starts with "of")
            if suffix.startswith("of"):
                title = f"{random.choice(adjectives)} {random.choice(nouns)} {suffix}"
            else:
                title = f"{random.choice(adjectives)} {random.choice(nouns)}: {suffix}"
        elif style == 1:
            # Format: "Adjective Noun"
            title = f"{random.choice(adjectives)} {random.choice(nouns)}"
        elif style == 2:
            # Format: "Adjective Noun Suffix" (no colon)
            title = f"{random.choice(adjectives)} {random.choice(nouns)} {suffix}"
        elif style == 3:
            # Format: "Noun of Suffix"
            title = f"{random.choice(nouns)} {suffix}"
        elif style == 4:
            # Format: "Adjective Noun Verb"
            title = f"{random.choice(adjectives)} {random.choice(nouns)} {random.choice(verbs)}"
        else:
            # Format: "Noun: Adjective Suffix" or "Noun Adjective Suffix" (no colon if suffix starts with "of")
            adj_clean = random.choice(adjectives).replace('The ', '')
            if suffix.startswith("of"):
                title = f"{random.choice(nouns)} {adj_clean} {suffix}"
            else:
                title = f"{random.choice(nouns)}: {adj_clean} {suffix}"
        
        title = title_case(title)
        titles.add(title)
    
    return sorted(list(titles))

if __name__ == "__main__":
    fantasy_titles = generate_fantasy_book_titles(15)
    print("Generated Fantasy Book Titles:")
    print("-" * 40)
    for i, title in enumerate(fantasy_titles, 1):
        print(f"{i}. {title}")
