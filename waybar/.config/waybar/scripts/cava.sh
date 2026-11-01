#!/bin/bash

bar=" ▂▃▄▅▆▇█"
dict="s/;//g;"

# creating "dictionary" to replace char with bar
i=0
while [ $i -lt ${#bar} ]
do
    dict="${dict}s/$i/${bar:$i:1}/g;"
    i=$((i=i+1))
done

# write cava config
config_file="/tmp/waybar_cava_config"
echo "
[general]
bars = 12
autosens = 1

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
" > $config_file

# read stdout from cava
cava -p $config_file | while read -r line; do
    # Convert numbers/semicolons to unicode bars
    visualizer=$(echo "$line" | sed "$dict")
    
    # Trim trailing/leading spaces to check if there is actual sound
    # When silent, cava outputs all zeros, which sed turns into all spaces
    trimmed=$(echo "$visualizer" | tr -d ' ')
    
    if [ -z "$trimmed" ]; then
        # Completely empty JSON hides the module
        echo '{"text": ""}'
    else
        # Output the visualizer text
        echo "{\"text\": \"$visualizer\"}"
    fi
done
