#!/usr/bin/env python3

import random
import argparse

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

# Main function with command-line argument parsing
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate random words.")
    parser.add_argument(
        "-n", "--num_words", type=int, default=10, help="Number of words to generate (default: 10)"
    )
    parser.add_argument(
        "-min", "--min_length", type=int, default=3, help="Minimum length of words (default: 3)"
    )
    parser.add_argument(
        "-max", "--max_length", type=int, default=8, help="Maximum length of words (default: 8)"
    )
    args = parser.parse_args()

    generated_words = generate_words(args.num_words, args.min_length, args.max_length)
    for word in generated_words:
        print(word)