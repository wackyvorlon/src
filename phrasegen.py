import random
from nltk.corpus import wordnet

# Function to get words of a specific part of speech from WordNet
def get_words_by_pos(pos):
    words = set()
    for synset in wordnet.all_synsets(pos):
        for lemma in synset.lemmas():
            words.add(lemma.name().replace('_', ' '))
    return list(words)

# Fetch adjectives, nouns, and verbs from WordNet
adjectives = get_words_by_pos(wordnet.ADJ)
nouns = get_words_by_pos(wordnet.NOUN)
verbs = get_words_by_pos(wordnet.VERB)

def generate_phrases(count):
    phrases = []
    for _ in range(count):
        adjective = random.choice(adjectives)
        noun = random.choice(nouns)
        verb = random.choice(verbs)
        phrases.append(f"{adjective} {noun} {verb}")
    return phrases

# Generate and print 10 phrases
if __name__ == "__main__":
    # Ensure nltk WordNet data is downloaded
    try:
        from nltk import download
        download('wordnet')
    except Exception as e:
        print(f"Error downloading WordNet data: {e}")
        exit(1)

    for phrase in generate_phrases(10):
        print(phrase)