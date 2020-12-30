#!/bin/bash
SUPPORTED_COLORS="orange lightgreen magenta cyan"
COLOR=$(hostname | cut -d '-' -f1)

# only change color for enclave nodes and if not already set
if [[ `hostname` == *"-xd-gw" ]] || [[ -e ~/.bgset ]]; then
    exit
fi

#color re-mappings for better rendering
if [[ $COLOR == "green" ]]; then
	COLOR=lightgreen
elif [[ $COLOR == "purple" ]]; then
	COLOR=magenta
fi	

# change the color
DONE=0
for c in $SUPPORTED_COLORS; do
	if [[ $c == $COLOR ]]; then
		CMD="printf '\e]11;%s\a' \"$COLOR\""
		echo "$CMD" >> ~/.bashrc
		touch ~/.bgset
		DONE=1
		break
	fi
done

if [[ $DONE -eq 0 ]]; then
	printf "ERROR: bg color not supported: $COLOR\n"
fi
