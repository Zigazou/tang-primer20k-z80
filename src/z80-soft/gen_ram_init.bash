#!/bin/bash

# This script generates a RAM initialization file in hex format suitable for use
# with hardware description languages in GoWin environments.
#
# Usage: gen_ram_init.bash <bytes_count>
#
# It reads a specified number of bytes (bytes_count) from standard input and
# outputs them in hex format. If standard input is shorter than the specified
# bytes_count, it pads the output with zeros until the required length is
# reached.
#
# Example:
#
#   cat input_file.bin | gen_ram_init.bash 256 > ram_init.hex

bytes_count="$1"

printf "#File_format=Hex\n"
printf "#Address_depth=%d\n" "$bytes_count"
printf "#Data_width=8\n"

(cat ; dd if=/dev/zero bs=1 count="$bytes_count" status=none) \
    | head --bytes="$bytes_count" \
    | hexdump \
        --no-squeezing \
        --format '1/1 "%02X\n"'
