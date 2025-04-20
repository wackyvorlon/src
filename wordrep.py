import sys
from nltk.corpus import wordnet

def get_synonym(word):
    synonyms = wordnet.synsets(word.lower())  # Use lowercase for lookup
    if synonyms:
        synonym = synonyms[0].lemmas()[0].name()  # Get the first synonym
        # Match the case of the original word
        if word.isupper():
            return synonym.upper()
        elif word[0].isupper():
            return synonym.capitalize()
        else:
            return synonym
    return word

def replace_words_with_synonyms(input_file, output_file):
    try:
        with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
            for line in infile:
                words = line.split()
                replaced_line = ' '.join(get_synonym(word) for word in words)
                outfile.write(replaced_line + '\n')
        print(f"Replaced words written to {output_file}")
    except FileNotFoundError:
        print(f"Error: File {input_file} not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python wordrep.py <input_file> <output_file>")
    else:
        replace_words_with_synonyms(sys.argv[1], sys.argv[2])