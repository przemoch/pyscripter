{-----------------------------------------------------------------------------
 Unit Name: cFindInFiles
 Author:    Kiriakos Vlahos
 Date:      29-May-2005
 Purpose:
 History:   Based on GExperts (www.gexperts.org) unit and covered by its licence

GExperts License Agreement
GExperts is copyright 1996-2005 by GExperts, Inc, Erik Berry, and several other
authors who have submitted their code for inclusion. This license agreement only covers code written by GExperts, Inc and Erik Berry. You should contact the other authors concerning their respective copyrights and conditions.

The rules governing the use of GExperts and the GExperts source code are derived
from the official Open Source Definition, available at http://www.opensource.org.
The conditions and limitations are as follows:

    * Usage of GExperts binary distributions is permitted for all developers.
      You may not use the GExperts source code to develop proprietary or
      commercial products including plugins or libraries for those products.
      You may use the GExperts source code in an Open Source project, under the
      terms listed below.
    * You may not use the GExperts source code to create and distribute custom
      versions of GExperts under the "GExperts" name. If you do modify and
      distribute custom versions of GExperts, the binary distribution must be
      named differently and clearly marked so users can tell they are not using
      the official GExperts distribution. A visible and unmodified version of
      this license must appear in any modified distribution of GExperts.
    * Custom distributions of GExperts must include all of the custom changes
      as a patch file that can be applied to the original source code. This
      restriction is in place to protect the integrity of the original author's
      source code. No support for modified versions of GExperts will be provided
      by the original authors or on the GExperts mailing lists.
    * All works derived from GExperts must be distributed under a license
      compatible with this license and the official Open Source Definition,
      which can be obtained from http://www.opensource.org/.
    * Please note that GExperts, Inc. and the other contributing authors hereby
      state that this package is provided "as is" and without any express or
      implied warranties, including, but not without limitation, the implied
      warranties of merchantability and fitness for a particular purpose. In
      other words, we accept no liability for any damage that may result from
      using GExperts or programs that use the GExperts source code.
-----------------------------------------------------------------------------}

unit cFindInFiles;

interface

uses
  Classes,
  Graphics,
  cFileSearch,
  JvAppStorage;

type
  TFindInFilesAction = (gaCurrentOnlyGrep, gaOpenFilesGrep, gaDirGrep);

  // Saved grep settings (used for refresh)
  TGrepSettings = packed record
    NoComments: Boolean;
    NoCase: Boolean;
    WholeWord: Boolean;
    RegEx: Boolean;
    IncludeSubdirs: Boolean;
    BackupModified : Boolean;
    Directories: string;
    Mask: string;
    Pattern: string;
    Replace: string;
    FindInFilesAction: TFindInFilesAction;
    CanRefresh: Boolean;
  end;

type
  // Individual grep match in a line
  TMatchResult = class(TCollectionItem)
  private
    FSPos: Integer;
    FEPos: Integer;
    FShowBold: Boolean;
  public
    property SPos: Integer read FSPos write FSPos;
    property EPos: Integer read FEPos write FEPos;
    property ShowBold: Boolean read FShowBold write FShowBold;
    constructor Create(Collection: TCollection); override;
  end;

  // Collection of TMatchResult
  // Collection of all matches in a line
  TLineMatches = class(TCollection)
  private
    function GetItem(Index: Integer): TMatchResult;
    procedure SetItem(Index: Integer; Value: TMatchResult);
  public
    constructor Create;
    function Add: TMatchResult;
    property Items[Index: Integer]: TMatchResult read GetItem write SetItem; default;
  end;

  // A single line that has a match from a file
  // One collection item per line with any number of matches
  TLineResult = class(TCollectionItem)
  private
    FLine: string;
    FLineNo: Integer;
    FMatches: TLineMatches;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    function Add: TMatchResult;
  public
    property Line: string read FLine write FLine;
    property LineNo: Integer read FLineNo write FLineNo;
    // Collection of all matches in a line
    property Matches: TLineMatches read FMatches;
  end;

  TMatchArray = array of TMatchResult;

  // Contains collection of all lines in a single source file that match.
  TFileResult = class(TCollection)
  private
    FExpanded: Boolean;
    FFileName: string;
    FRelativeFileName: string;
    FLastLineResult: Integer; // Last LineNo added to result set
    FLastIndex: Integer;      // Index of last added result
    FTotalMatches: Integer;   // Total matches in file
    function GetItem(Index: Integer): TLineResult;
    procedure SetItem(Index: Integer; Value: TLineResult);
  public
    constructor Create;
    function Add: TLineResult;
    procedure GetMatchesOnLine(Line: Integer; var Matches: TMatchArray);
    property Expanded: Boolean read FExpanded write FExpanded;
    property FileName: string read FFileName write FFileName;
    property RelativeFileName: string read FRelativeFileName write FRelativeFileName;
    property LastIndex: Integer read FLastIndex write FLastIndex;
    property LastLineResult: Integer read FLastLineResult write FLastLineResult;
    property Items[Index: Integer]: TLineResult read GetItem write SetItem; default;
    property TotalMatches: Integer read FTotalMatches write FTotalMatches;
  end;

type
  TOnHitMatch = procedure(Sender: TObject; LineNo: Integer; const Line: string;
      SPos, EPos: Integer) of object;
  TOnSearchFile = procedure(Sender: TObject; const FileName: string) of object;

  TGrepSearchRunner = class(TObject)
  private
    FOnHitMatch: TOnHitMatch;
    FOnSearchFile: TOnSearchFile;
    FStorageTarget: TStrings;
    FDupeFileList: TStrings;
    FAbortSignalled: Boolean;
    FFileSearchCount: Integer;
    FMatchCount: Integer;
    FFileResult: TFileResult;
    FSearcher: TSearcher;
    FSearchRoot: string;
    procedure FoundIt(Sender: TObject; LineNo: Integer; const Line: string;
      SPos, EPos: Integer);
    procedure StartFileSearch(Sender: TObject);
  private
    FGrepSettings: TGrepSettings;
    procedure GrepFile(const FileName: string);
  protected
    procedure DoHitMatch(LineNo: Integer; const Line: string;
      SPos, EPos: Integer); virtual;
    procedure GrepCurrentSourceEditor;
    procedure GrepOpenFiles;
    procedure GrepDirectory(Dir, Mask: string);
    procedure GrepDirectories(const Dir, Mask: string);
  public
    constructor Create(const Settings: TGrepSettings; StorageTarget: TStrings);
    procedure Execute;
    property OnSearchFile: TOnSearchFile read FOnSearchFile write FOnSearchFile;
    property FileSearchCount: Integer read FFileSearchCount;
    property MatchCount: Integer read FMatchCount;
    property AbortSignalled: Boolean read FAbortSignalled write FAbortSignalled;
  end;

 TFindInFilesExpert = class(TInterfacedPersistent, IJvAppStorageHandler)
  private
    FGrepMiddle: Boolean;
    FGrepSave: Boolean;
    FGrepExpandAll: Boolean;
    FBackupModified: Boolean;
    FSearchList: TStrings;
    FReplaceList: TStrings;
    FMaskList: TStrings;
    FDirList: TStrings;
    FGrepNoCase: Boolean;
    FGrepNoComments: Boolean;
    FGrepSearch: Integer;
    FGrepSub: Boolean;
    FGrepWholeWord: Boolean;
    FGrepRegEx: Boolean;
    FNumContextLines: Integer;
    FListFont: TFont;
    FContextFont: TFont;
    FContextMatchColor: TColor;
    procedure SetSearchList(New: TStrings);
    procedure SetReplaceList(New: TStrings);
    procedure SetMaskList(New: TStrings);
    procedure SetDirList(New: TStrings);
  protected
    // IJvAppStorageHandler implementation
    procedure ReadFromAppStorage(AppStorage: TJvCustomAppStorage; const BasePath: string);
    procedure WriteToAppStorage(AppStorage: TJvCustomAppStorage; const BasePath: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Configure;
    property GrepMiddle: Boolean read FGrepMiddle write FGrepMiddle;
    property GrepSave: Boolean read FGrepSave write FGrepSave;
    property GrepExpandAll: Boolean read FGrepExpandAll write FGrepExpandAll;
    property BackupModified: Boolean read FBackupModified write FBackupModified;
    property GrepNoCase: Boolean read FGrepNoCase write FGrepNoCase;
    property GrepNoComments: Boolean read FGrepNoComments write FGrepNoComments;
    property GrepSearch: Integer read FGrepSearch write FGrepSearch;
    property GrepSub: Boolean read FGrepSub write FGrepSub;
    property GrepWholeWord: Boolean read FGrepWholeWord write FGrepWholeWord;
    property GrepRegEx: Boolean read FGrepRegEx write FGrepRegEx;
    property NumContextLines: Integer read FNumContextLines write FNumContextLines;
    property ListFont: TFont read FListFont write FListFont;
    property ContextFont: TFont read FContextFont write FContextFont;
    property ContextMatchColor: TColor read FContextMatchColor write FContextMatchColor;

    property SearchList: TStrings read FSearchList write SetSearchList;
    property ReplaceList: TStrings read FReplaceList write SetReplaceList;
    property MaskList: TStrings read FMaskList write SetMaskList;
    property DirList: TStrings read FDirList write SetDirList;
  end;

procedure AddMRUString(Text: string; List: TStrings; DeleteTrailingDelimiter: Boolean);
procedure DeleteStringFromList(List: TStrings; const Item: string);

Var
  FindInFilesExpert : TFindInFilesExpert;

implementation

uses
  SysUtils, Forms, JclStrings, uEditAppIntfs, Dialogs, JvSearchFiles,
  JclFileUtils, VarPyth, frmFindResults, frmPyIDEMain,
  dlgFindResultsOptions, Controls;

{ TLineMatches }

constructor TLineMatches.Create;
begin
  inherited Create(TMatchResult);
end;

function TLineMatches.Add: TMatchResult;
begin
  Result := TMatchResult(inherited Add);
end;

function TLineMatches.GetItem(Index: Integer): TMatchResult;
begin
  Result := TMatchResult(inherited GetItem(Index));
end;

procedure TLineMatches.SetItem(Index: Integer; Value: TMatchResult);
begin
  inherited SetItem(Index, Value);
end;

{ TLineResult }

constructor TLineResult.Create(Collection: TCollection);
begin
  inherited Create(Collection);
  FMatches := TLineMatches.Create;
end;

destructor TLineResult.Destroy;
begin
  if Assigned(FMatches) then
  begin
    FMatches.Clear;
    FreeAndNil(FMatches);
  end;
  inherited Destroy;
end;

function TLineResult.Add: TMatchResult;
begin
  Result := Matches.Add;
end;

{ TFileResult }

constructor TFileResult.Create;
begin
  inherited Create(TLineResult);
  FLastLineResult := -1;
  FTotalMatches := 0;
end;

function TFileResult.Add: TLineResult;
begin
  Result := TLineResult(inherited Add);
end;

function TFileResult.GetItem(Index: Integer): TLineResult;
begin
  Result := TLineResult(inherited GetItem(Index));
end;

procedure TFileResult.SetItem(Index: Integer; Value: TLineResult);
begin
  inherited SetItem(Index, Value);
end;

procedure TFileResult.GetMatchesOnLine(Line: Integer; var Matches: TMatchArray);
var
  i, j: Integer;
  LineMatches: TLineResult;
  MR: TMatchResult;
begin
  SetLength(Matches, 0);
  for i := 0 to Count - 1 do
  begin
    LineMatches := GetItem(i);
    if LineMatches.FLineNo = Line then
    begin
      for j := 0 to LineMatches.Matches.Count - 1 do
      begin
        SetLength(Matches, Length(Matches) + 1);
        MR := LineMatches.Matches.GetItem(j);
        Matches[Length(Matches) - 1] := MR;
      end;
    end;
  end;
end;

{ TGrepSearchRunner }

procedure TGrepSearchRunner.GrepFile(const FileName: string);
begin
  Application.ProcessMessages;

  if FDupeFileList.IndexOf(FileName) > -1 then
    Exit;
  FDupeFileList.Add(FileName);

  Assert(FFileResult = nil, 'FFileResult leak');
  FFileResult := nil;
  FSearcher.FileName := FileName;

  FSearcher.Execute;
  FFileResult := nil;
end;

constructor TGrepSearchRunner.Create(const Settings: TGrepSettings; StorageTarget: TStrings);
begin
  inherited Create;

  Assert(Assigned(StorageTarget));
  FStorageTarget := StorageTarget;
  FGrepSettings := Settings;
end;

procedure TGrepSearchRunner.GrepCurrentSourceEditor;
resourcestring
  SNoFileOpen = 'No editor is currently active';
var
  CurrentFile: string;
  Editor : IEditor;
begin
  Editor := PyIDEMainForm.GetActiveEditor;
  if Assigned(Editor) then begin
    CurrentFile := Editor.FileName;
    if CurrentFile = '' then
      CurrentFile := Editor.FileTitle;
  end else
    CurrentFile := '';

  Assert(FFileResult = nil, 'FFileResult leak');
  FFileResult := nil;

  FSearchRoot := ExtractFilePath(CurrentFile);
  if CurrentFile <> '' then
  begin
    FSearcher.FileName := CurrentFile;
    FSearcher.Execute;
    FFileResult := nil;
  end
  else
    raise Exception.CreateRes(@SNoFileOpen);
end;

procedure TGrepSearchRunner.GrepOpenFiles;
Var
  i : integer;
  Editor : IEditor;
  FileName: string;
begin
  for i := 0 to GI_EditorFactory.Count -1 do begin
    Editor := GI_EditorFactory.Editor[i];
    FileName := Editor.GetFileNameOrTitle;
    GrepFile(FileName);
  end;
end;

procedure TGrepSearchRunner.GrepDirectories(const Dir, Mask: string);
var
  i: Integer;
  DirList: TStringList;
begin
  DirList := TStringList.Create;
  try
    StrToStrings(Dir, ';', DirList, False);
    for i := 0 to DirList.Count - 1 do
    begin
      if FAbortSignalled then
        Break;
      FSearchRoot := DirList[i];
      GrepDirectory(DirList[i], Mask);
    end;
  finally
    FreeAndNil(DirList);
  end;
end;

procedure TGrepSearchRunner.GrepDirectory(Dir, Mask: string);
resourcestring
  SSpecifiedDirectoryDoesNotExist = 'The search directory %s does not exist';
var
  JvSearchFiles: TJvSearchFiles;
  i : integer;
begin
  if not DirectoryExists(Dir) then
    raise Exception.CreateResFmt(@SSpecifiedDirectoryDoesNotExist, [Dir]);

  JvSearchFiles := TJvSearchFiles.Create(nil);
  try
    with JvSearchFiles do
    begin
      Name := 'JvSearchFiles';
      FileParams.SearchTypes := [stFileMask];
      FileParams.FileMaskSeperator := ';';
      FileParams.FileMask := Mask;
      RootDirectory := Dir;
      ErrorResponse := erRaise;
      if FGrepSettings.IncludeSubdirs then
        DirOption := doIncludeSubDirs
      else
        DirOption := doExcludeSubDirs;
      if JvSearchFiles.Search then begin
        for i := 0 to Files.Count - 1 do begin
          if FAbortSignalled then
              Exit;
          GrepFile(Files[i]);
        end;
      end;
    end;
  finally
    JvSearchFiles.Free;
  end;
end;

procedure TGrepSearchRunner.Execute;
begin
  FFileSearchCount := 0;
  FMatchCount := 0;

  FSearcher := TSearcher.Create('');
  try
    FSearcher.BufSize := 30000;
    FSearcher.OnFound := FoundIt;
    FSearcher.OnStartSearch := StartFileSearch;

    FSearcher.NoComments := FGrepSettings.NoComments;
    if FGrepSettings.NoCase then
      FSearcher.SearchOptions := [soCaseSensitive];
    if FGrepSettings.WholeWord then
      FSearcher.SearchOptions := FSearcher.SearchOptions + [soWholeWord];
    if FGrepSettings.RegEx then
      FSearcher.SearchOptions := FSearcher.SearchOptions + [soRegEx];

    FSearcher.SetPattern(FGrepSettings.Pattern);

    FDupeFileList := TStringList.Create;
    try
    case FGrepSettings.FindInFilesAction of
      gaCurrentOnlyGrep:
        GrepCurrentSourceEditor;
      gaOpenFilesGrep:
        GrepOpenFiles;
      gaDirGrep:
        begin
          if Length(Trim(FGrepSettings.Mask)) = 0 then
            GrepDirectories(FGrepSettings.Directories, '*.py')
          else
            GrepDirectories(FGrepSettings.Directories, AnsiUpperCase(FGrepSettings.Mask));
        end;
    end;	// end case
    finally
      FreeAndNil(FDupeFileList);
    end;

  finally
    FreeAndNil(FSearcher);
  end;
end;

procedure TGrepSearchRunner.FoundIt(Sender: TObject; LineNo: Integer; const Line: string; SPos, EPos: Integer);
var
  ALineResult: TLineResult;
  AMatchResult: TMatchResult;
begin
  Inc(FMatchCount);

  // If this is the first match or the match is on a
  // different file then add a new TFileResult.
  if (FFileResult = nil) or (FFileResult.FileName <> FSearcher.FileName) then
  begin
    FFileResult := TFileResult.Create;
    FFileResult.FileName := FSearcher.FileName;
    FFileResult.RelativeFileName := StringReplace(FSearcher.FileName, FSearchRoot, '', [rfIgnoreCase]);
    FStorageTarget.AddObject(FSearcher.FileName, FFileResult);
  end;

  // If the match is not on the same line number as the
  // last match then add another TLineResult to the file's
  // result set.
  if FFileResult.LastLineResult <> LineNo then
  begin
    ALineResult := FFileResult.Add;
    ALineResult.Line := Line;
    ALineResult.LineNo := LineNo;

    // Save Index number and line number for next match
    FFileResult.LastIndex := FFileResult.Count-1;
    FFileResult.LastLineResult := LineNo;
  end
  else
  begin
    // If the match is on the same line then add the
    // match to the previous match line
    ALineResult := FFileResult[FFileResult.LastIndex];
  end;

  AMatchResult := ALineResult.Add;
  AMatchResult.SPos := SPos;
  AMatchResult.EPos := EPos;
  FFileResult.TotalMatches := FFileResult.TotalMatches + 1;
end;

procedure TGrepSearchRunner.StartFileSearch(Sender: TObject);
begin
  Assert(Assigned(Sender as TSearcher));
  Inc(FFileSearchCount);
  if Assigned(FOnSearchFile) then
    FOnSearchFile(Self, FSearcher.FileName);
end;

procedure TGrepSearchRunner.DoHitMatch(LineNo: Integer; const Line: string;
  SPos, EPos: Integer);
begin
  if Assigned(FOnHitMatch) then
    FOnHitMatch(Self, LineNo, Line, SPos, EPos);
end;


{ TMatchResult }

constructor TMatchResult.Create(Collection: TCollection);
begin
  inherited;
  ShowBold := True;
end;

procedure AddMRUString(Text: string; List: TStrings; DeleteTrailingDelimiter: Boolean);
begin
  if Trim(Text) = '' then Exit;
  if Length(Text) > 300 then Exit;

  if DeleteTrailingDelimiter then
    Text := PathRemoveSeparator(Text);

  DeleteStringFromList(List, Text);

  if List.Count = 0 then
    List.Add(Text)
  else
    List.Insert(0, Text);

  if List.Count > 20 then
    List.Delete(List.Count - 1);
end;

procedure DeleteStringFromList(List: TStrings; const Item: string);
var
  Index: Integer;
begin
  Assert(Assigned(List));
  Index := List.IndexOf(Item);
  if Index >= 0 then
    List.Delete(Index);
end;

{ TFindInFilesExpert }

procedure TFindInFilesExpert.Configure;
var
  Dialog: TFindResultsOptionsDialog;
begin
  Dialog := TFindResultsOptionsDialog.Create(nil);
  try
    Dialog.chkGrepMiddle.Checked := GrepMiddle;
    Dialog.chkGrepExpandAll.Checked := GrepExpandAll;
    Dialog.pnlListFont.Font.Assign(ListFont);
    Dialog.pnlContextFont.Font.Assign(ContextFont);
    Dialog.pnlMatchLineColor.Font.Assign(ContextFont);
    Dialog.pnlMatchLineColor.Font.Color := ContextMatchColor;
    Dialog.spnContextLines.Value := NumContextLines;

    if Dialog.ShowModal = mrOk then
    begin
      GrepMiddle := Dialog.chkGrepMiddle.Checked;
      GrepExpandAll := Dialog.chkGrepExpandAll.Checked;
      FListFont.Assign(Dialog.pnlListFont.Font);
      FContextFont.Assign(Dialog.pnlContextFont.Font);
      ContextMatchColor := Dialog.pnlMatchLineColor.Font.Color;
      NumContextLines := Round(Dialog.spnContextLines.Value);
    end;
  finally
    FreeAndNil(Dialog);
  end;
end;

constructor TFindInFilesExpert.Create;
begin
  inherited Create;
  FSearchList := TStringList.Create;
  FReplaceList := TStringList.Create;
  FMaskList := TStringList.Create;
  FDirList := TStringList.Create;
  FListFont := TFont.Create;
  FContextFont := TFont.Create;
  FContextMatchColor := clHighlight;
  FNumContextLines := 2;

  FGrepSave := True;
  FGrepNoCase := False;
  FGrepNoComments := False;
  FGrepExpandAll := False;
  FBackupModified := False;
  FGrepSub := True;
  FGrepSearch := 1;
  FGrepSave := True;
  FGrepWholeWord := False;
  FGrepMiddle := True;
  FGrepRegEx := False;
  FindResultsWindow := TFindResultsWindow.Create(PyIDEMainForm);
  FindResultsWindow.FindInFilesExpert := Self;

  MaskList.Add('*.py');
  DirList.Add(SysModule.prefix+'\Lib');
end;

destructor TFindInFilesExpert.Destroy;
begin
  FreeAndNil(FSearchList);
  FreeAndNil(FReplaceList);
  FreeAndNil(FMaskList);
  FreeAndNil(FDirList);
  FreeAndNil(FListFont);
  FreeAndNil(FContextFont);

  inherited Destroy;
  inherited;
end;

procedure TFindInFilesExpert.ReadFromAppStorage(AppStorage: TJvCustomAppStorage;
  const BasePath: string);
begin
  with AppStorage do begin
    FGrepNoCase := ReadBoolean(BasePath+'\NoCase', False);
    FGrepNoComments := ReadBoolean(BasePath+'\NoComments', False);
    FGrepSearch := ReadInteger(BasePath+'\Search', 1);
    FGrepSub := ReadBoolean(BasePath+'\SubDirectories', True);
    FGrepSave := ReadBoolean(BasePath+'\Save', True);
    FGrepExpandAll := ReadBoolean(BasePath+'\ExpandAll', False);
    FBackupModified := ReadBoolean(BasePath+'\BackupModified', False);
    FGrepWholeWord := ReadBoolean(BasePath+'\Whole Word', False);
    FGrepMiddle := ReadBoolean(BasePath+'\Middle', True);
    FGrepRegEx := ReadBoolean(BasePath+'\RegEx', False);

    ReadPersistent(BasePath+'\ListFont', ListFont);
    ReadPersistent(BasePath+'\ContextFont', ContextFont);
    FNumContextLines :=  ReadInteger(BasePath+'\NumContextLines', FNumContextLines);
    FContextMatchColor :=  ReadInteger(BasePath+'\ContextMatchColor', FContextMatchColor);

    ReadStringList(BasePath+'\DirectoryList', DirList);
    ReadStringList(BasePath+'\SearchList', SearchList);
    ReadStringList(BasePath+'\ReplaceList', ReplaceList);
    ReadStringList(BasePath+'\MaskList', MaskList);
    if MaskList.Count = 0 then
    begin
      MaskList.Add('*.py');
    end;
    if DirList.Count = 0 then
    begin
      // Add Python Path
      DirList.Add(SysModule.prefix+'\Lib');
    end;
  end;
end;

procedure TFindInFilesExpert.WriteToAppStorage(AppStorage: TJvCustomAppStorage;
  const BasePath: string);
begin
  with AppStorage do begin
    WriteBoolean(BasePath+'\NoCase', GrepNoCase);
    WriteBoolean(BasePath+'\NoComments', GrepNoComments);
    WriteInteger(BasePath+'\Search', GrepSearch);
    WriteBoolean(BasePath+'\SubDirectories', GrepSub);
    WriteBoolean(BasePath+'\Save', GrepSave);
    WriteBoolean(BasePath+'\ExpandAll', GrepExpandAll);
    WriteBoolean(BasePath+'\BackupModified', BackupModified);
    WriteBoolean(BasePath+'\Whole Word', GrepWholeWord);
    WriteBoolean(BasePath+'\Middle', GrepMiddle);
    WriteBoolean(BasePath+'\RegEx', GrepRegEx);
    WritePersistent(BasePath+'\ListFont', ListFont);
    WritePersistent(BasePath+'\ContextFont', ContextFont);
    WriteInteger(BasePath+'\NumContextLines', NumContextLines);
    WriteInteger(BasePath+'\ContextMatchColor', ContextMatchColor);

    WriteStringList(BasePath+'\DirectoryList', DirList);
    WriteStringList(BasePath+'\SearchList', SearchList);
    WriteStringList(BasePath+'\ReplaceList', ReplaceList);
    WriteStringList(BasePath+'\MaskList', MaskList);
  end;
end;

procedure TFindInFilesExpert.SetDirList(New: TStrings);
begin
  FDirList.Assign(New);
end;

procedure TFindInFilesExpert.SetMaskList(New: TStrings);
begin
  FMaskList.Assign(New);
end;

procedure TFindInFilesExpert.SetReplaceList(New: TStrings);
begin
  FReplaceList.Assign(New);
end;

procedure TFindInFilesExpert.SetSearchList(New: TStrings);
begin
  FSearchList.Assign(New);
end;

end.



