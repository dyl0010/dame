//
// (c) 2022 dyl0010
// This code is licensed under MIT license (see LICENSE.txt for details)
//
import std.algorithm; 
import std.file; 
import std.conv; 
import std.path; 
import std.range; 
import std.typecons;

import dlangui;
import dlangui.core.logger;

import dame.manager: mainWindow, uiManager, nameAttributes;
import dame.manager: UIManager, RenameManager;
import dame.type: NameAttri;

int namesCount = 0;

void recursiveRenameableItems(string[] paths, int indent) {

    assert(uiManager);

    paths.each!((filePath) {
        //
        // add absolute file path to nameAttributes.
        nameAttributes ~= tuple!("filePath", "isRename", "isSubname")(filePath, true, cast(bool)indent);

        if (filePath.isDir) {
            //Log.d('\t'.repeat(indent).to!string ~ "-- dame.app.debug -- [+] " ~ filePath.baseName);
            uiManager.namesTable.setCellText(0, namesCount++, '\t'.repeat(indent).to!dstring ~ " + "d ~ filePath.baseName.to!dstring);

            string[] subPaths;
            filePath.dirEntries(SpanMode.shallow)
                    .each!(sp => subPaths ~= sp);
            subPaths.recursiveRenameableItems(indent + 1);
        }
        else {
            //Log.d('\t'.repeat(indent).to!string ~ "-- dame.app.debug -- [~] " ~ filePath.baseName);
            uiManager.namesTable.setCellText(0, namesCount++, '\t'.repeat(indent).to!dstring ~ " - "d ~ filePath.baseName.to!dstring);
        }
    });
}

mixin APP_ENTRY_POINT;

extern (C) int UIAppMain(string[] args) {

    mainWindow = Platform.instance.createWindow("Dame"d, null, WindowFlag.Resizable, 800, 500);

    auto renameManager = new RenameManager;

    uiManager = new UIManager(renameManager);
    mainWindow.mainWidget = uiManager.setupUI();

    recursiveRenameableItems(args[1..$], 0);

    uiManager.namesTable.resize(2, namesCount);
    uiManager.updateNameCounter(namesCount);

    mainWindow.show();
    return Platform.instance.enterMessageLoop();
}

