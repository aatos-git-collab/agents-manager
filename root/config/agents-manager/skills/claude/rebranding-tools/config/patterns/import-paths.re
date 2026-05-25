# Python imports
py_import      = from ['"]?[a-zA-Z0-9_.-]+['"]? import
py_from        = from ['"][a-zA-Z0-9_.-]+['"] import
# Node.js requires
js_require     = require\(['"'][a-zA-Z0-9_./@-]+['"]\)
# ES6 imports
es_import      = import ['"]?[*a-zA-Z0-9_./@-]+['"]? from
# Java/Kotlin package refs
java_pkg       = import [a-zA-Z0-9_.]+\.[a-zA-Z0-9_]+;
# Ruby requires
ruby_require   = require ['"][a-zA-Z0-9_./@-]+['"]
# Go imports
go_import      = ["a-zA-Z0-9_./@-]+"
