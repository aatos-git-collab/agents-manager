github-handle = @[a-zA-Z0-9_-]+\/[a-zA-Z0-9_.-]+
github_url   = https?:\/\/github\.com\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_.-]+

# Match @org handle in code
@org          = @[a-zA-Z0-9_-]+
# Match GitHub remote URLs (HTTP SSH)
git_remote    = (https?:\/\/gitHub\.com\/|git@gitHub\.com:)[a-zA-Z0-9_-]+\/[a-zA-Z0-9_.-]+\.git
# Match org in import/require statements
import_org    = from ['"'][a-zA-Z0-9_-]+\/[a-zA-Z0-9_.-]+['"]
require_org   = require\(['"'][a-zA-Z0-9_-]+\/[a-zA-Z0-9_.-]+['"]\)
