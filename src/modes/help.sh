set -euo pipefail

echo "Usage: sh nightcore.sh [mode] [input directory]

Available modes:

- render - use the files present in the directory to render a nightcore video
- split - split the script's output file into multiple files
- compress - create a compressed version of the script's output file for sharing
- expand - remove compressed version of output file
- combine - remove all files split from the output file
- clean - remove all files produced by nightcore.sh from the directory
- help - show this menu
- help_full - show a more detailed version of this menu

Use the help_full mode for more info."
