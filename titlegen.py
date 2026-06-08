import random

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
    
    titles = set()
    while len(titles) < count:
        title = f"{random.choice(adjectives)} {random.choice(nouns)}: {random.choice(suffixes)}"
        titles.add(title)
    
    return sorted(list(titles))

if __name__ == "__main__":
    fantasy_titles = generate_fantasy_book_titles(15)
    print("Generated Fantasy Book Titles:")
    print("-" * 40)
    for i, title in enumerate(fantasy_titles, 1):
        print(f"{i}. {title}")
