module dame.manager;

import std.string;
import std.file; 
import std.algorithm; 
import std.conv; 
import std.path; 
import std.range; 
import std.format;
import std.typecons;
import std.regex;
import std.ascii: isAlpha, isAlphaNum;

import dlangui;
import dlangui.core.logger;

import dame.type: Column, ApplyType, FormatType, NameAttri;

//
// global vars
//
UIManager uiManager;

Window mainWindow;

NameAttri[] nameAttributes;  

//
// class RenameManager
//
class RenameManager {
private:
    alias IndexedName= Tuple!(dstring, "name", size_t, "index");

    string INVALID_FILENAME_CHARACTERS = "\\/:*?\"<>|";

    dstring searchFor;
    bool usedRegex = true;
    bool matchedAllOccurrences;
    bool isCaseSensitive;

    dstring replaceWith;

public:
    this() {
        Log.d("-- dame.app.debug -- ", "RenameManager created.");
    }

    void onSearchContentChanged(EditableContent src) {
        searchFor = src.text;
        this.update;
    }

    bool onUsedRegexStatusChanged(Widget src, bool checked) {
        usedRegex = checked;

        assert(uiManager);

        if (!usedRegex)
            uiManager.normalSearchFor();

        return this.update;
    }

    bool onMatchedAllOccurrencesStatusChanged(Widget src, bool checked) {
        matchedAllOccurrences = checked;
        return this.update;
    }

    bool onCaseSensitiveStatusChanged(Widget src, bool checked) {
        isCaseSensitive = checked;
        return this.update;
    }

    bool isValidText(dstring text) {
        foreach (dchar ch; INVALID_FILENAME_CHARACTERS)
            if (text.indexOf(ch) != -1)
                return false;

        return true;
    }

    void onReplaceWithContentChanged(EditableContent src) {
        replaceWith = src.text;

        assert(uiManager);

        if (!isValidText(replaceWith)) {
            uiManager.errorReplaceWith();
            uiManager.disableApplyBtn();
        }
        else {
            uiManager.normalReplaceWith();
            uiManager.enableApplyBtn();
        }

        this.update;
    }

private:
    auto applyType = ApplyType.FILEANDEXTNAME;
    bool includeFiles = true;
    bool includeFolders = true;
    bool includeSubfolders = true;

    auto fmtType = FormatType.KEEPCASE;
    
    bool useEnumItem;
    int currentEnum;

    int renameCounter;

public:
    bool onApplyTypeItemChanged(Widget src, int itemIndex) {
        applyType = cast(ApplyType)itemIndex;
        return this.update;
    }

    bool onIncludeFilesChanged(Widget src, bool checked) {
        includeFiles = checked;
        nameAttributes.each!((ref na) {
            if (!na.filePath.isDir && (!na.isSubname || includeSubfolders)) 
                na.isRename = checked;
        });
        return this.update;
    }

    bool onIncludeFoldersChanged(Widget src, bool checked) {
        includeFolders = checked;
        nameAttributes.each!((ref na) {
            if (na.filePath.isDir && (!na.isSubname || includeSubfolders)) 
                na.isRename = checked;
        });
        return this.update;
    }

    bool onIncludeSubfoldersChanged(Widget src, bool checked) {
        includeSubfolders = checked;
        nameAttributes.each!((ref na) {
            if(na.isSubname) {
                if(na.filePath.isDir && includeFolders) {
                    na.isRename = checked;
                } else if(!na.filePath.isDir && includeFiles) {
                    na.isRename = checked;
                }
            }
        });
        return this.update;
    }

    bool onKeepcaseCheckChanged(Widget src, bool checked) {
        if (checked) fmtType = FormatType.KEEPCASE;
        return this.update;
    }

    bool onLowercaseCheckChanged(Widget src, bool checked) {
        if (checked) fmtType = FormatType.LOWERCASE;
        return this.update;
    }

    bool onUppercaseCheckChanged(Widget src, bool checked) {
        if (checked) fmtType = FormatType.UPPERCASE;
        return this.update;
    }

    bool onTitlecaseCheckChanged(Widget src, bool checked) {
        if (checked) fmtType = FormatType.TITLECASE;
        return this.update;
    }

    bool onCapEachWordCheckChanged(Widget src, bool checked) {
        if (checked) fmtType = FormatType.CAPEACHWORD;
        return this.update;
    }

    bool onEnumItemChanged(Widget src, bool checked) {
        useEnumItem = checked;
        return this.update;
    }

    bool onRenameBtnClicked(Widget src) {
        auto rnt = this.rename;
        nameAttributes.length = 0;
        return rnt;
    }

    bool onRenameAndExitBtnClicked(Widget src) {
        auto rnt = this.rename;
        Platform.instance.closeWindow(mainWindow);
        return rnt;
    }

    bool rename() {
        for (int i = 0; i < nameAttributes.length; ++i) {
            auto na = nameAttributes[i];
            //Log.d(format("-- dame.app.debug -- na.filePath: %s\n\t->na.isRename: %s\n\t->na.isSubname: %s",
            //            na.filePath, na.isRename.to!bool, na.isSubname.to!bool));
            if (na.isRename) {
                //Log.d(format("-- dame.app.debug -- origin name: %s\n\t->new name: %s", 
                //        na.filePath, na.filePath.dirName.chainPath(uiManager.namesTable.cellText(Column.NEWNAME, i).to!string)));
                na.filePath.rename(na.filePath.dirName.chainPath(uiManager.namesTable.cellText(Column.NEWNAME, i).to!string));
            }
        }
        return true;
    }

    dstring getFilename(dstring file) {
        return file.stripExtension;
    }

    dstring getExtensionname(dstring file) {
        dstring exte = file.extension;
        return exte.length > 1 ? exte[1..$] : ""d;
    }

    dstring getMatchedPart(dstring file) {
        if (applyType == ApplyType.ONLYFILENAME) {
            return getFilename(file);
        } else if (applyType == ApplyType.ONLYEXTNAME) {
            return getExtensionname(file);
        } else {
            return file;
        }
   }

    dstring getCompletedName(dstring file, dstring matchedPart) {
        if (applyType == ApplyType.ONLYFILENAME) {
            dstring exte = getExtensionname(file);
            return matchedPart ~ (exte.length > 0 ? ("." ~ exte) : ""d);
        } else if (applyType == ApplyType.ONLYEXTNAME) {
            dstring filename = getFilename(file);
            return filename ~ (matchedPart.length > 0 ? ("." ~ matchedPart) : ""d);
        } else {
            return matchedPart;
        }
    }

    dstring getFormattedName(dstring matchedPart) {
        dstring ret;
        
        bool isCapitalize = true;

        bool isFirst = true;

        switch (fmtType) {
            case FormatType.KEEPCASE:
                ret = matchedPart;
                break;
            case FormatType.LOWERCASE:
                ret = matchedPart.toLower;
                break;
            case FormatType.UPPERCASE:
                ret = matchedPart.toUpper;
                break;
            case FormatType.TITLECASE:
                foreach (dchar c; matchedPart) {
                    if (isFirst && c.isAlpha) {
                        ret ~= c.toUpper;
                        isFirst = false;
                    } else {
                        ret ~= c.toLower;
                    }

                }
                break;
            case FormatType.CAPEACHWORD:
                foreach (dchar c; matchedPart) {
                    if (!c.isAlphaNum) {
                        isCapitalize = true;
                        ret ~= c;
                    } else {
                        ret ~= (isCapitalize ? c.toUpper : c.toLower);
                        isCapitalize = false;
                    }
                }
                break;
            default:
                Log.d("-- dame.app.error -- ", "unknown fmtType!");
        }
        return ret;
    }

    dstring calcNameByRegex(IndexedName oldInfo, dstring matchedPart) {

        assert(uiManager);

        dstring ret;
        
        try {
            auto re = regex(searchFor, isCaseSensitive ? "" : "i");

            if (matchedAllOccurrences) {
                ret = replaceAll(matchedPart, re, replaceWith);
            } else {
                ret = replaceFirst(matchedPart, re, replaceWith);
            }

            uiManager.normalSearchFor();
        } catch (RegexException e) {
            Log.d("-- dame.app.error -- ", "regex exception!");
            uiManager.errorSearchFor();  // regex syntax error.
        } catch (Exception e) {
            Log.d("-- dame.app.error -- ", "unknown exception!");
        }

        return ret;
    }

    dstring calcNameByNormal(IndexedName oldInfo, dstring matchedPart) {
        dstring ret;
        auto isCS = isCaseSensitive ? Yes.caseSensitive : No.caseSensitive;
        long currentIdx, startIdx;

        while (startIdx != -1) {

            startIdx = matchedPart[currentIdx..$].indexOf(searchFor, isCS);

            if (startIdx != -1) {
                startIdx += currentIdx;  // first element is matchedPart[0].
                ret ~= matchedPart[currentIdx..startIdx] ~ replaceWith;
                currentIdx = startIdx + searchFor.length;
            } else {
                ret ~= matchedPart[currentIdx..$];
            }

            if (!matchedAllOccurrences) {
                if (startIdx != -1)
                    ret ~= matchedPart[currentIdx..$];
                break;
            }
        }

        return ret;
    }

    dstring appendEnumItem(dstring name) {
        auto fileName = name.stripExtension;
        size_t enumStartIndex = fileName.lastIndexOf('(');
        dstring testedPart;

        if (enumStartIndex != -1)
            testedPart = fileName[fileName.lastIndexOf('(')..$]; 

        auto re = regex("^\\(\\d+\\) *$"d);  // testfile (999)   .txt
                                             //          ^^^^^^^^
        auto testedRest = testedPart.matchFirst(re);

        if (testedRest)
            return fileName[0..enumStartIndex] ~
                   testedRest.hit.replaceFirst(regex("\\d+"d), (++currentEnum).to!dstring) ~
                   name.extension;
        else
            return format("%s(%d)%s"d, fileName, ++currentEnum, name.extension);
    }

    //
    // calculate new names using current rules.
    dstring calcNewName(IndexedName oldInfo) {
        auto realName = oldInfo.name.stripLeft[2..$];  // format: [      + ]folder, here strip [...].

        dstring matchedPart = getMatchedPart(realName);

        dstring newName;
        
        if (usedRegex) {
            newName = calcNameByRegex(IndexedName(realName, oldInfo.index), matchedPart);
        } else {
            newName = calcNameByNormal(IndexedName(realName, oldInfo.index), matchedPart);
        }

        assert(oldInfo.index < nameAttributes.length);

        if (newName == matchedPart) {
            // not rename.
            nameAttributes[oldInfo.index].isRename = false;
            newName = ""d;
        } else {
            nameAttributes[oldInfo.index].isRename = true;
            newName = getFormattedName(newName);
            newName = getCompletedName(realName, newName);
        }

        // append enumeration string.
        if (useEnumItem && newName.length != 0) {
            newName = appendEnumItem(newName);
        }

        if (newName.length != 0) 
            ++renameCounter;
        
        return  newName;
    }

    //
    // if need calculate a new name.
    bool needCalcName(NameAttri na) {
        if (na.filePath.isDir && includeFolders) {
            if (na.isSubname) 
                return includeSubfolders;
            return true;
        } else if (!na.filePath.isDir && includeFiles){
            if (na.isSubname)
                return includeSubfolders;
            return true;
        } else {
            return false;
        }
    }

    bool update() {
        assert(uiManager);

        currentEnum = 0; 

        renameCounter = 0;
        
        foreach (int i, immutable na; nameAttributes) {
            auto OLDNAME = uiManager.namesTable.cellText(Column.OLDNAME, i);
            uiManager.namesTable.setCellText(Column.NEWNAME, i, needCalcName(na) ? calcNewName(IndexedName(OLDNAME, i)) : ""d);
        }

        uiManager.updateRenameCounter(renameCounter);
        
        return true;
    }
}

//
// class UIManager
//
class UIManager {

    immutable INIT_NAMES_TABLE_SIZE = 1000;

    StringGridWidget namesTable;

    EditLine searchContentELine;

    EditLine replaceWithELine;

    Button renameBtn;

    Button renameAndExitBtn;

    RenameManager renameManager;

    this(RenameManager rm) {
        assert(rm);
        renameManager = rm;

        namesTable = new StringGridWidget;

        searchContentELine = new EditLine;

        replaceWithELine = new EditLine;

        renameBtn = new Button;

        renameAndExitBtn = new Button;

        Log.d("-- dame.app.debug -- ", "UImanager created.");
    }

    void errorSearchFor() {
        searchContentELine.textColor("#ff0000");
    }

    void normalSearchFor() {
        searchContentELine.textColor("#000000");
    }

    void errorReplaceWith() {
        replaceWithELine.textColor("#ff0000");
    }

    void normalReplaceWith() {
        replaceWithELine.textColor("#000000");
    }

    void disableApplyBtn() {
        renameBtn.enabled(false);
        renameAndExitBtn.enabled(false);
    }

    void enableApplyBtn() {
        renameBtn.enabled(true);
        renameAndExitBtn.enabled(true);
    }

    void updateNameCounter(int count) {
        namesTable.setColTitle(0, "Original ~ %d"d.format(count));
    }

    void updateRenameCounter(int count) {
        namesTable.setColTitle(1, "Renamed ~ %d"d.format(count));
    }

    auto setupUI() {
        auto mainLayout = (new HorizontalLayout).margins(15).layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        auto editorPanel = (new VerticalLayout);
        auto previewPanel = (new VerticalLayout).layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        mainLayout.addChild(editorPanel);
        mainLayout.addChild(previewPanel);

        auto searchTWidget = (new TextWidget).text("Search for:"d);
        searchContentELine.layoutWidth(FILL_PARENT);
        auto searchHLayout = (new HorizontalLayout);
        searchHLayout.layoutWidth(FILL_PARENT);
        searchHLayout.addChild(searchTWidget);
        searchHLayout.addChild(searchContentELine);
        editorPanel.addChild(searchHLayout);


        auto usedRegexCBox = (new CheckBox).text("Use regular expressions"d).checked(true);
        auto matchedAllOccurrencesCBox = (new CheckBox).text("Match all occurrences"d).checked(false);
        auto isCaseSensitiveCBox = (new CheckBox).text("Case sensitive"d).checked(false);
        editorPanel.addChild(usedRegexCBox);
        editorPanel.addChild(matchedAllOccurrencesCBox);
        editorPanel.addChild(isCaseSensitiveCBox);

        auto replaceWithTWidget = (new TextWidget).text("Replace with:"d);
        replaceWithTWidget.tooltipText("A file name can't contain any of the following characters:\\ / : * ? \" < > |"d);
        replaceWithELine.layoutWidth(FILL_PARENT);
        auto replaceWithHLayout = (new HorizontalLayout).layoutWidth(FILL_PARENT);
        replaceWithHLayout.addChild(replaceWithTWidget);
        replaceWithHLayout.addChild(replaceWithELine);
        editorPanel.addChild(replaceWithHLayout);

        // 
        // set callback.
        searchContentELine.contentChange = &renameManager.onSearchContentChanged;

        usedRegexCBox.checkChange = &renameManager.onUsedRegexStatusChanged;
        matchedAllOccurrencesCBox.checkChange = &renameManager.onMatchedAllOccurrencesStatusChanged;
        isCaseSensitiveCBox.checkChange = &renameManager.onCaseSensitiveStatusChanged;

        replaceWithELine.contentChange = &renameManager.onReplaceWithContentChanged;
        // end.
        //
        
        auto applyAsGBox = (new GroupBox).text("Apply to"d);
        auto applyTypeComboBox = (new ComboBox("", ["Filename + extension"d, "Filename only"d, "Extension only"d]));
        applyTypeComboBox.selectedItemIndex(0);

        auto includeFilesTWidget = (new TextWidget).text("Include files"d);
        auto includeFilesSBtn = (new SwitchButton).checked(true);
        auto includeFilesHLayout = (new HorizontalLayout);
        includeFilesHLayout.addChild(includeFilesTWidget);
        includeFilesHLayout.addChild(includeFilesSBtn);

        auto includeFoldersTWidget = (new TextWidget).text("Include folders"d);
        auto includeFoldersSBtn = (new SwitchButton).checked(true);
        auto includeFoldersHLayout = (new HorizontalLayout);
        includeFoldersHLayout.addChild(includeFoldersTWidget);
        includeFoldersHLayout.addChild(includeFoldersSBtn);

        auto includeSubfoldersTWidget = (new TextWidget).text("Include subfolders"d);
        auto includeSubfoldersSBtn = (new SwitchButton).checked(true);
        auto includeSubfoldersHLayout = (new HorizontalLayout);
        includeSubfoldersHLayout.addChild(includeSubfoldersTWidget);
        includeSubfoldersHLayout.addChild(includeSubfoldersSBtn);

        applyAsGBox.addChild(applyTypeComboBox);
        applyAsGBox.addChild(includeFilesHLayout);
        applyAsGBox.addChild(includeFoldersHLayout);
        applyAsGBox.addChild(includeSubfoldersHLayout);
        editorPanel.addChild(applyAsGBox);

        //
        // set callback.
        applyTypeComboBox.itemClick = &renameManager.onApplyTypeItemChanged;

        includeFilesSBtn.checkChange = &renameManager.onIncludeFilesChanged;
        includeFoldersSBtn.checkChange = &renameManager.onIncludeFoldersChanged;
        includeSubfoldersSBtn.checkChange = &renameManager.onIncludeSubfoldersChanged;
        // end.
        //

        auto textFmtGBox = (new GroupBox).text("Text formatting"d);
        auto keepcaseRBtn = (new RadioButton).text("KeepOriginal"d).checked(true);
        auto lowercaseRBtn = (new RadioButton).text("lowercase"d);
        auto uppercaseRBtn = (new RadioButton).text("UPPERCASE"d);
        auto titlecaseRBtn = (new RadioButton).text("Title case"d);
        auto capEachWordRBtn = (new RadioButton).text("Capitalize Each World"d);
        auto textFmtTLayout = (new TableLayout).colCount(2);

        auto enumItemTWidget = (new TextWidget).text("Enumerate items"d);
        auto enumItemSBtn = (new SwitchButton);
        auto enumItemHLayout = (new HorizontalLayout);
        enumItemHLayout.addChild(enumItemTWidget);
        enumItemHLayout.addChild(enumItemSBtn);
        
        textFmtTLayout.addChild(keepcaseRBtn);
        textFmtTLayout.addChild(new HSpacer);
        textFmtTLayout.addChild(lowercaseRBtn);
        textFmtTLayout.addChild(uppercaseRBtn);
        textFmtTLayout.addChild(titlecaseRBtn);
        textFmtTLayout.addChild(capEachWordRBtn);

        textFmtGBox.addChild(textFmtTLayout);
        textFmtGBox.addChild(enumItemHLayout);
        
        editorPanel.addChild(textFmtGBox);

        auto btnHLayout = (new HorizontalLayout);
        renameBtn.text("Apply"d);
        renameAndExitBtn.text("Apply | close"d);
        btnHLayout.addChild(renameBtn);
        btnHLayout.addChild(renameAndExitBtn);

        //
        // set callback.
        keepcaseRBtn.checkChange = &renameManager.onKeepcaseCheckChanged;
        lowercaseRBtn.checkChange = &renameManager.onLowercaseCheckChanged;
        uppercaseRBtn.checkChange = &renameManager.onUppercaseCheckChanged;
        titlecaseRBtn.checkChange = &renameManager.onTitlecaseCheckChanged;
        capEachWordRBtn.checkChange = &renameManager.onCapEachWordCheckChanged;
        // end
        //
        
        enumItemSBtn.checkChange = &renameManager.onEnumItemChanged;
        
        renameBtn.click = &renameManager.onRenameBtnClicked;
        renameAndExitBtn.click = &renameManager.onRenameAndExitBtnClicked;

        editorPanel.addChild(btnHLayout);

        namesTable.resize(2, INIT_NAMES_TABLE_SIZE);
        namesTable.setColTitle(0, "Original"d).setColTitle(1, "Renamed ~ 0"d).showRowHeaders(false);
        namesTable.setColWidth(1, 300);
        namesTable.setColWidth(2, 300);
        previewPanel.addChild(namesTable);

        return mainLayout;
    }
}

