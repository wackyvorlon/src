#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
File: adjnoun.py
Description: Generates random adjective-noun pairs using WordNet.
Author: Alyssa
Date: April 18, 2025
"""


import random
import os
from nltk.corpus import wordnet

def get_words_by_pos(pos):
    """Fetch words of a specific part of speech from WordNet."""
    words = set()
    for synset in wordnet.all_synsets(pos):
        for lemma in synset.lemmas():
            words.add(lemma.name().replace('_', ' '))
    return list(words)

def generate_adjective_noun_pairs(adjectives, nouns, count=10):
    """Generate random adjective-noun pairs."""
    pairs = []
    for _ in range(count):
        adjective = random.choice(adjectives)
        noun = random.choice(nouns)
        pairs.append(f"{adjective} {noun}")
    return pairs

if __name__ == "__main__":
    # Ensure nltk WordNet data is downloaded only if nltk_data directory doesn't exist
    nltk_data_path = os.path.join(os.path.expanduser("~"), "nltk_data")
    if not os.path.exists(nltk_data_path):
        try:
            from nltk import download
            download('wordnet')
        except Exception as e:
            print(f"Error downloading WordNet data: {e}")
            exit(1)

    # Fetch adjectives and nouns from WordNet
    adjectives = get_words_by_pos(wordnet.ADJ)
    nouns = get_words_by_pos(wordnet.NOUN)

    # Generate and print 10 adjective-noun pairs
    pairs = generate_adjective_noun_pairs(adjectives, nouns, count=10)
    for pair in pairs:
        print(pair)