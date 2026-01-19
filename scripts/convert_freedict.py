#!/usr/bin/env python3
"""
FreeDict Dutch-English Dictionary Converter.

Downloads the FreeDict nld-eng dictionary in TEI XML format,
parses it, and converts it to a JSON format suitable for the
Dutch language learning application.

Output format:
{
    "word": {"pos": "part of speech", "en": "English translation"},
    ...
}
"""

import json
import os
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path
from xml.etree import ElementTree as ET

# FreeDict download URL (source tarball contains TEI XML)
FREEDICT_URL = "https://download.freedict.org/dictionaries/nld-eng/0.2/freedict-nld-eng-0.2.src.tar.xz"

# Output path (relative to project root)
OUTPUT_FILE = "static/data/dictionary.json"


def download_dictionary(url: str, dest_path: str) -> None:
    """
    Download the FreeDict dictionary archive.

    Args:
        url: URL to download from
        dest_path: Local path to save the file
    """
    print(f"Downloading dictionary from {url}...")
    urllib.request.urlretrieve(url, dest_path)
    print(f"Downloaded to {dest_path}")


def extract_tei_file(archive_path: str, extract_dir: str) -> str:
    """
    Extract the TEI XML file from the tar.xz archive.

    Args:
        archive_path: Path to the tar.xz archive
        extract_dir: Directory to extract to

    Returns:
        Path to the extracted TEI XML file
    """
    print(f"Extracting archive...")
    with tarfile.open(archive_path, "r:xz") as tar:
        tar.extractall(extract_dir)

    # Find the .tei file
    for root, dirs, files in os.walk(extract_dir):
        for f in files:
            if f.endswith(".tei"):
                tei_path = os.path.join(root, f)
                print(f"Found TEI file: {tei_path}")
                return tei_path

    raise FileNotFoundError("No .tei file found in archive")


def parse_tei_dictionary(tei_path: str) -> dict:
    """
    Parse the TEI XML dictionary file.

    Args:
        tei_path: Path to the TEI XML file

    Returns:
        Dictionary mapping Dutch words to their translations
    """
    print(f"Parsing TEI dictionary...")

    # TEI namespace
    ns = {"tei": "http://www.tei-c.org/ns/1.0"}

    tree = ET.parse(tei_path)
    root = tree.getroot()

    dictionary = {}
    entry_count = 0

    # Find all entry elements
    for entry in root.findall(".//tei:entry", ns):
        # Get the headword (orth element within form)
        form = entry.find("tei:form", ns)
        if form is None:
            continue

        orth = form.find("tei:orth", ns)
        if orth is None or not orth.text:
            continue

        word = orth.text.strip().lower()

        # Get part of speech
        pos = ""
        gram = entry.find(".//tei:gram[@type='pos']", ns)
        if gram is not None and gram.text:
            pos = gram.text.strip()

        # Get English translation (from sense/cit/quote)
        translations = []
        for sense in entry.findall("tei:sense", ns):
            for cit in sense.findall("tei:cit[@type='trans']", ns):
                quote = cit.find("tei:quote", ns)
                if quote is not None and quote.text:
                    translations.append(quote.text.strip())

        if translations:
            # Join multiple translations with semicolon
            en_translation = "; ".join(translations)

            # Store in dictionary (use first occurrence if duplicate)
            if word not in dictionary:
                dictionary[word] = {
                    "pos": pos,
                    "en": en_translation
                }
                entry_count += 1

    print(f"Parsed {entry_count} dictionary entries")
    return dictionary


def save_dictionary(dictionary: dict, output_path: str) -> None:
    """
    Save dictionary to JSON file.

    Args:
        dictionary: Dictionary data
        output_path: Output file path
    """
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(dictionary, f, ensure_ascii=False, separators=(",", ":"))

    # Get file size
    size_kb = os.path.getsize(output_path) / 1024
    print(f"Saved dictionary to {output_path} ({size_kb:.1f} KB)")


def main() -> int:
    """
    Main function to download, parse, and convert the dictionary.

    Returns:
        Exit code (0 for success, 1 for error)
    """
    # Get project root (parent of scripts directory)
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    output_path = project_root / OUTPUT_FILE

    print("FreeDict Dutch-English Dictionary Converter")
    print("=" * 50)

    try:
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download archive
            archive_path = os.path.join(temp_dir, "freedict-nld-eng.tar.xz")
            download_dictionary(FREEDICT_URL, archive_path)

            # Extract TEI file
            tei_path = extract_tei_file(archive_path, temp_dir)

            # Parse dictionary
            dictionary = parse_tei_dictionary(tei_path)

            # Save to JSON
            save_dictionary(dictionary, str(output_path))

        print("=" * 50)
        print(f"Successfully created dictionary with {len(dictionary)} words")
        return 0

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
