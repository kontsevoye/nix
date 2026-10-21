# Apple's bundle includes text and PEM sections delimited by these headings.
# Reset at every section so unrelated roots and their metadata are preserved.
/^(###|===) / { skip = 0 }
/^=== .*\/CN=(AAA Certificate Services|emSign ECC Root CA - G3)$/ { skip = 1 }
!skip
