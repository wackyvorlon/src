import random

def generate_words(num_words, min_length, max_length):
    vowels = 'aeiou'
    consonants = 'bcdfghjklmnpqrstvwxyz'
    words = []

    for _ in range(num_words):
        word_length = random.randint(min_length, max_length)
        word = ''
        for i in range(word_length):
            if i % 2 == 0:
                word += random.choice(consonants)
            else:
                word += random.choice(vowels)
        words.append(word)

    return words

# Example usage
if __name__ == "__main__":
    num_words = 10
    min_length = 3
    max_length = 8
    generated_words = generate_words(num_words, min_length, max_length)
    for word in generated_words:
        print(word)