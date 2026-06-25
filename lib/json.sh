#!/usr/bin/env bash

# generic JSON parser in pure bash and awk.
# reads JSON from stdin and outputs a flattened list of key-value pairs.
# example input: {"plugins": {"my_plugin": {"version": "1.0", "arr": [1, 2]}}}
# example output:
  # plugins.my_plugin.version="1.0"
  # plugins.my_plugin.arr[0]=1
  # plugins.my_plugin.arr[1]=2

# pardon my french
parse_json() {
    # Tokenize the JSON using grep
    grep -oE '"([^"\\]|\\.)*"|true|false|null|[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?|[][}{:,]' | \
    awk '
    BEGIN { 
        depth=0; 
        key="" 
    }
    {
        token = $0
        if (token == "{") {
            depth++
            is_key[depth] = 1
            array_idx[depth] = ""
        } else if (token == "}") {
            delete path[depth]
            delete array_idx[depth]
            depth--
        } else if (token == "[") {
            depth++
            is_key[depth] = 0
            array_idx[depth] = 0
        } else if (token == "]") {
            delete array_idx[depth]
            delete path[depth]
            depth--
        } else if (token == ":") {
            is_key[depth] = 0
        } else if (token == ",") {
            if (array_idx[depth] != "") {
                array_idx[depth]++
            } else {
                is_key[depth] = 1
            }
        } else {
            if (is_key[depth] == 1) {
                # Remove quotes from the key
                gsub(/^"|"$/, "", token)
                path[depth] = token
            } else {
                # It is a value
                p = ""
                for (i=1; i<=depth; i++) {
                    if (array_idx[i] != "") {
                        p = p "[" array_idx[i] "]"
                    } else if (path[i] != "") {
                        p = p "." path[i]
                    }
                }
                # Remove leading dot
                sub(/^\./, "", p)
                print p "=" token
            }
        }
    }
    '
}
