module dame.type;

enum Column {
    OLDNAME,
    NEWNAME,
}

enum ApplyType {
    FILEANDEXTNAME, 
    ONLYFILENAME,
    ONLYEXTNAME,
}

enum FormatType {
    KEEPCASE,  // keep it.
    LOWERCASE,
    UPPERCASE,
    TITLECASE,
    CAPEACHWORD,
}

import std.typecons;

alias NameAttri = Tuple!(string, "filePath", bool, "isRename", bool, "isSubname");
