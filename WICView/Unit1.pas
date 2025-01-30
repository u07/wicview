unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, wincodec, NetEncoding,
  ComObj, ActiveX, Vcl.Menus, clipbrd, System.Generics.Collections, Vcl.Mask, System.StrUtils;

type
  TForm1 = class(TForm)
    tree: TTreeView;
    Button1: TButton;
    OpenDialog1: TOpenDialog;
    Button2: TButton;
    PopupMenu1: TPopupMenu;
    Copyastext1: TMenuItem;
    Copypath1: TMenuItem;
    SearchField: TMaskEdit;
    BackupTree: TTreeView;
    Label1: TLabel;
    SearchCnt: TStaticText;
    SaveRAW1: TMenuItem;
    SaveDialog1: TSaveDialog;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure treeChange(Sender: TObject; Node: TTreeNode);
    procedure Copyastext1Click(Sender: TObject);
    procedure Copypath1Click(Sender: TObject);
    procedure SearchFieldChange(Sender: TObject);
    procedure SaveRAW1Click(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    function GetTreePath: string;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  //descriptions: TDictionary<string,string>;
  descr: TStringList;
  fil: string;
  queue: TStringList;
  exp: boolean;

  wicFactory: IWICImagingFactory;
  wicDecoder: IWICBitmapDecoder;
  frameDecode: IWICBitmapFrameDecode;
  Root, CurrBranch: IWICMetadataQueryReader;
  metadataItems: IEnumString;



implementation

{$R *.dfm}


// Find a human-readable description
function FindDsc(str:string):string;
var
 i: integer;
 key,val:string;
begin
 result:='';
 if str='' then exit;
 for i:=0 to descr.Count-1 do
  begin
   key:=trim(descr[i]);
   val:=copy(key, pos(' ',key)+1, maxint);
   delete(key, length(key)-length(val), maxint);
   if (str=key) then
    begin
     result:=trim(val);
     exit;
    end;
  end;

 {for i:=0 to descr.Count-1 do
  begin
   key:=descr[i];
   val:=copy(key, pos(' ',key)+1, maxint);
   delete(key, length(key)-length(val), maxint);
   if (pos(key,str) > 0) then
    if (rate < (length(key)/length(str))) then
     begin
      rate:=(length(key)/length(str));
      result:=val;
     end;
  end;  }
end;


// Replace system conversion, which is not exif specific-aware
function PropToString(var prop: TPropVariant; BytesMax: cardinal): string;
var
 SS: POleStr;
 i: integer;
begin
 result:='';

 case prop.vt of
  // A pair of values 32+32 combined together
  VT_I8: result:=inttostr(integer(prop.CAL.cElems)) +'/'+ inttostr(integer(prop.CAL.pElems));
  // A pair of values 32+32 combined together
  VT_UI8: result:=inttostr(cardinal(prop.CAL.cElems)) +'/'+ inttostr(cardinal(prop.CAL.pElems));
  // An array of such pairs
  (VT_VECTOR OR VT_I8), (VT_VECTOR OR VT_UI8), (VT_VECTOR OR 15): begin
   for i:=0 to prop.cah.cElems-1 do
    result:=result + inttostr(integer(PlargeInteger(pansichar(prop.cah.pElems)+i*SizeOf(TLargeInteger))^ shl 32 shr 32)) + '/'
                   + inttostr(integer(PlargeInteger(pansichar(prop.cah.pElems)+i*SizeOf(TLargeInteger))^ shr 32)) + '; ';             // pointer arithmetic was much easier in 7...
  end;
  else begin
   SS:=CoTaskMemAlloc(BytesMax);
   // Unicode function. Size of the buffer in characters!
   if PropVariantToString(prop, SS, BytesMax div sizeof(widechar)) = S_OK
    then result:=SS
    else result:=SS+' ... ... (truncated)';
   CoTaskMemFree(SS);
  end;
 end;

 if prop.vt in [VT_BLOB] then
  result:='(hex) '+result;
end;






// On start - load dictionary
procedure TForm1.FormCreate(Sender: TObject);
var
 path: string;
begin
 queue:=TStringList.Create;
 descr:=TStringList.Create;
 path:=ExtractFilePath(Application.ExeName)+'description.txt';
 if not FileExists(path) then path:=ExtractFilePath(Application.ExeName)+'..\description.txt';
 if not FileExists(path) then path:=ExtractFilePath(Application.ExeName)+'..\..\description.txt';
 if FileExists(path) then descr.LoadFromFile(path);
end;


// Assemble full path to the corrent tree leaf
//  #1 separates minor data
function TForm1.GetTreePath: string;
var
 tmp: TTreeNode;
 s: string;
begin
 result:='';
 tmp:=tree.Selected;
 while (tmp <> nil) do
  begin
   s:=tmp.Text;
   delete(s, pos(#1, s), maxint);
   result:=s+result;
   tmp:=tmp.Parent;
  end;
end;


// Build and show metadata tree
// https://msdn.microsoft.com/en-us/library/windows/desktop/ee719799%28v=vs.85%29.aspx
procedure TForm1.Button1Click(Sender: TObject);
const
 _max = 300; // max data preview size
var
 prop: TPropVariant;
 opened: boolean;
 SS: POleStr;
begin
 if not OpenDialog1.Execute(handle) then exit;
 fil:=OpenDialog1.FileName;
 queue.clear;
 tree.Items.Clear;
 exp:=False;
 BackupTree.Items.Clear;

 // Create the COM imaging factory
 wicFactory:=CreateComObject(CLSID_WICImagingFactory) as IWICImagingFactory;
 // Create the decoder
 if (wicFactory.CreateDecoderFromFilename(pchar(fil), TGUID(nil^), GENERIC_READ, WICDecodeMetadataCacheOnDemand, wicDecoder) <> S_OK) then
  raise Exception.Create('Can not CreateDecoderFromFilename');
 // Get a single frame from the image (JPEG has only one frame)
 if (wicDecoder.GetFrame(0, frameDecode) <> S_OK) then
  raise Exception.Create('Can not get metadata frame');
 // Obtain the frame's query reader. Can also be obtained at the decoder level
 if (frameDecode.GetMetadataQueryReader(root) <> S_OK) then
  raise Exception.Create('Can not GetMetadataQueryReader');

 // Go through the top-level metadata, then deeper
 tree.Visible:=False;
 queue.Add(''); // Start from this path ('')
 while (queue.Count > 0) do
  begin
   opened:=False;
   PropVariantClear(prop);
   // Dealing with root? It's already opened.
   if (queue[0] = '') then
    begin
     CurrBranch:=Root;
     opened:=true;
    end;
   // Or we should open this branch?
   if not opened then
    if Succeeded(root.GetMetadataByName(pchar(queue[0]), prop)) then
     if (prop.vt = VT_UNKNOWN) then
      begin
       IInterface(prop.pStream).QueryInterface(IID_IWICMetadataQueryReader, CurrBranch);
       opened:=True;
      end;
   // We did opened the branch, or the root. Now can enumerate subitems
   // and add their names to the tree (and to the queue to check later)
   if opened then
    begin
     CurrBranch.GetEnumerator(metadataItems);
     while metadataItems.Next(1, SS, nil) = S_OK do
      begin
       queue.AddObject(queue[0]+SS, tree.Items.AddChild(TTreeNode(queue.Objects[0]),SS + #1 + FindDsc(queue[0]+SS)));
       CoTaskMemFree(SS);
      end;
    end else
    // Else this is not a branch. It is a leaf (or an error happened).
    // Let's show it's value next to it's name...
    begin
     PropVariantClear(prop);
     root.GetMetadataByName(pchar(queue[0]), prop);
     if (queue.Objects[0] <> nil) then
      TTreeNode(queue.Objects[0]).Text:=TTreeNode(queue.Objects[0]).Text +' = '+ PropToString(prop, _max);
    end;
   queue.Delete(0);
  end;
  tree.Visible:=True;
  BackupTree.Items.Assign(tree.Items);
end;


// Expand-collapse all
procedure TForm1.Button2Click(Sender: TObject);
begin
 if exp then tree.FullCollapse
  else tree.FullExpand;
 exp:=not exp;
end;


// Copy value as text
procedure TForm1.Copyastext1Click(Sender: TObject);
const
 _max = 20*1024*1024; // Actually max XMP block (if not extended) = 64 kb
var
 path: string;
 prop: TPropVariant;
begin
 path:=GetTreePath;
 if path = '' then exit;
 PropVariantClear(prop);
 root.GetMetadataByName(pchar(path), prop);
 Clipboard.SetTextBuf(pchar(PropToString(prop, _max)));
end;


// Copy path
procedure TForm1.Copypath1Click(Sender: TObject);
begin
 Clipboard.SetTextBuf(pchar(GetTreePath));
end;


// Save blob data as raw
procedure TForm1.SaveRAW1Click(Sender: TObject);
var
 path: string;
 prop: TPropVariant;
 m: TMemoryStream;
begin
 path:=GetTreePath;
 if path = '' then exit;
 if not SaveDialog1.Execute(handle) then exit;
 PropVariantClear(prop);
 root.GetMetadataByName(pchar(path), prop);
 m:=TMemoryStream.Create;
 case prop.vt of
  VT_BLOB: begin
            m.Write(prop.BLOB.pBlobData, prop.BLOB.cbSize);
            m.SaveToFile(SaveDialog1.FileName);
           end;
 end;
 m.Free;
end;

// Show-hide menu item
procedure TForm1.PopupMenu1Popup(Sender: TObject);
begin
 SaveRAW1.Visible:=pos('(hex) ', tree.Selected.Text) > 0;
end;


// Search
procedure TForm1.SearchFieldChange(Sender: TObject);
const
 col_good = $00C6FFC6;
 col_bad = $0080FFFF;
var
 i: integer;
 s: string;
 tmp: TTreeNode;
 cnt: integer;
begin
 // restore the original tree
 tree.Items.Assign(BackupTree.Items);
 SearchField.Color:=clWhite;
 SearchCnt.Visible:=False;
 s:=SearchField.Text;
 if s='' then exit;

 // mark elements and their parents with invisible mark (' ')
 cnt:=0;
 tree.Visible:=False;
 for i:=0 to tree.Items.Count-1 do
  if (AnsiContainsText(tree.Items[i].Text, s)) then
   begin
    inc(cnt);
    tmp:=tree.Items[i];
    while tmp <> nil do
     begin
      if (tmp.Text <> '') and (tmp.Text[1] <> ' ') then
       tmp.Text:=' '+tmp.Text;
      tmp:=tmp.Parent;
     end;
   end;

 // and delete unmarked
 i:=0;
 while i < tree.Items.Count do
  if (tree.Items[i].Text<>'') and (tree.Items[i].Text[1]=' ') then inc(i)
   else tree.Items.Delete(tree.Items[i]);

 // colorize search field
 if (tree.Items.Count > 0)
  then SearchField.Color:=col_good
  else SearchField.Color:=col_bad;
 SearchCnt.Caption:=IntToStr(cnt);
 SearchCnt.Visible:=true;
 tree.FullExpand;
 tree.Visible:=True;
end;


// Item selected
procedure TForm1.treeChange(Sender: TObject; Node: TTreeNode);
begin
 //
end;

end.
