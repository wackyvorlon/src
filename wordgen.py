import random

# Load English words from /usr/share/dict/words
def load_english_words(filepath="/usr/share/dict/words"):
    try:
        with open(filepath, "r") as file:
            return set(word.strip().lower() for word in file)
    except FileNotFoundError:
        print(f"Error: Word list file not found at {filepath}")
        return set()

ENGLISH_WORDS = load_english_words()

def generate_words(num_words, min_length, max_length):
    vowels = 'aeiou'
    consonants = 'bcdfghjklmnpqrstvwxyz'
    words = []

    for _ in range(num_words):
        while True:
            word_length = random.randint(min_length, max_length)
            word = ''
            for i in range(word_length):
                if i % 2 == 0:
                    word += random.choice(consonants)
                else:
                    word += random.choice(vowels)
            
            # Ensure the generated word is not an actual English word
            if word not in ENGLISH_WORDS:
                words.append(word)
                break

    return words

# Example usage
if __name__ == "__main__":
    num_words = 10
    min_length = 3
    max_length = 8
    generated_words = generate_words(num_words, min_length, max_length)
    for word in generated_words:
        print(word)