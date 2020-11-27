#!/bin/bash
tail -n 1 /tmp/sigma_lsp.log | egrep -o "Message\":\"[^\"]+\"" | cut -b 10- | tr "\n" " "
