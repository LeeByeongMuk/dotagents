# Include explicitly from your existing Git config after reviewing.
# Identity, signing keys, credential helpers and remote URLs stay local.
[fetch]
	prune = true
[diff]
	algorithm = histogram
[merge]
	conflictStyle = diff3
