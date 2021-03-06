unit ConsumeFormUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, CurvyControls, Vcl.Grids, AdvObj,
  BaseGrid, AdvGrid, Vcl.ComCtrls, hyieutils, iexBitmaps, hyiedefs, iesettings, iexLayers, iexRulers,
  ieview, iemview, PNGMapleCanvasEx, Generics.Collections, Generics.Defaults, WZArchive;

type
  TConsumeForm = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    CurvyPanel1: TCurvyPanel;
    IDLabel: TLabel;
    NameLabel: TLabel;
    Image1: TImage;
    Button1: TButton;
    ConsumeGrid: TAdvStringGrid;
    Edit1: TEdit;
    procedure FormActivate(Sender: TObject);
    procedure ConsumeGridClickCell(Sender: TObject; ARow, ACol: Integer);
    procedure TabSheet2Show(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    HasLoad: Boolean;
    HasShowImageGrid: Boolean;
    ImageGrid: TImageEnMView;
    IconList: TObjectList<TBmpEx>;
    Wz: TWZArchive;
    procedure ImageGridSelect(Sender: TObject; idx: Integer);
    { Private declarations }
  public
    procedure ImageAssignIcon(AID, DirName: string; AIDLabel, ANameLabel: TLabel; AImage: TImage;
      IsEtc: Boolean = False);
    procedure CreateImageGrid(var AImageGrid: TImageEnMView; AOwner: TComponent; AParent: TWinControl);
    procedure DumpIcons(AImageGrid: TImageEnMView; DirName: string; var AWZ: TWZArchive; var
      AIconList: TObjectList<TBmpEx>);
    { Public declarations }
  end;

var
  ConsumeForm: TConsumeForm;

implementation

uses
  WzUtils, Global, StrUtils, WZDirectory, MobDrop, MapleCharacter;
{$R *.dfm}

procedure TConsumeForm.CreateImageGrid(var AImageGrid: TImageEnMView; AOwner: TComponent; AParent: TWinControl);
begin
  AImageGrid := TImageEnMView.Create(AOwner);
  AImageGrid.Parent := AParent;
  AImageGrid.Visible := True;
  AImageGrid.Align := alClient;
  AImageGrid.AlignWithMargins := True;
  AImageGrid.Margins.Left := 3;
  AImageGrid.Margins.Right := 3;
  AImageGrid.Margins.Top := 3;
  AImageGrid.Margins.Bottom := 3;
  AImageGrid.BorderStyle := bsNone;
  AImageGrid.Background := clWhite;
  AImageGrid.ThumbWidth := 35;
  AImageGrid.ThumbHeight := 35;
  AImageGrid.ThumbnailOptionsEx := [ietxShowIconForUnknownFormat, ietxShowIconWhileLoading, ietxEnableInternalIcons];
  AImageGrid.DefaultInfoText := iedtNone;
  AImageGrid.MultiSelectionOptions := [];
  AImageGrid.ShowText := False;
  AImageGrid.SelectionColor := clRed;
end;

procedure TConsumeForm.ImageAssignIcon(AID, DirName: string; AIDLabel, ANameLabel: TLabel; Aimage:
  TImage; IsEtc: Boolean = False);
begin

  var Left4 := LeftStr(AID, 4);
  if GetImgEntry('Item.wz/' + DirName + '/' + Left4 + '.img/' + AID + '/info/icon') <> nil then
  begin
    var PNG := GetImgEntry('Item.wz/' + DirName + '/' + Left4 + '.img/' + AID + '/info/icon', True).Canvas.DumpPNG;
    Aimage.Picture.Assign(PNG);
    PNG.Free;
  end;
  AIDLabel.Caption := AID;
  if IsEtc then
    ANameLabel.Caption := StringWZ.GetImgFile(DirName + '.img').Root.Get('Etc/' + IDToInt(AID) + '/name', '')
  else
    ANameLabel.Caption := StringWZ.GetImgFile(DirName + '.img').Root.Get(IDToInt(AID) + '/name', '');
end;

procedure TConsumeForm.Button1Click(Sender: TObject);
begin
  if Trim(IDLabel.Caption) <> '' then
    TMobDrop.Drop(Round(Player.X), Round(Player.Y), 0, Trim(IDLabel.Caption));
end;

procedure TConsumeForm.ConsumeGridClickCell(Sender: TObject; ARow, ACol: Integer);
begin
  ImageAssignIcon(ConsumeGrid.Cells[1, ARow], 'Consume', IDLabel, NameLabel, Image1);
end;

procedure TConsumeForm.Edit1Change(Sender: TObject);
begin
  ConsumeGrid.NarrowDown(Trim(Edit1.Text));
end;

procedure TConsumeForm.DumpIcons(AImageGrid: TImageEnMView; DirName: string; var AWZ: TWZArchive;
  var AIconList: TObjectList<TBmpEx>);
begin
  with AImageGrid.GetCanvas do
  begin
    Font.Size := 24;
    TextOut(100, 100, 'Loading...')
  end;
  AWZ := TWZArchive.Create(WzPath + '\Item.wz');
  var Dir := TWZDirectory(AWZ.Root.Entry[DirName]);
  AIconList := TObjectList<TBmpEx>.Create;
  for var img in Dir.Files do
  begin
    if not IsNumber(img.Name[1]) then
      Continue;
    with AWZ.ParseFile(img) do
    begin
      for var Iter in Root.Children do
      begin
        if not IsNumber(Iter.Name) then
          Continue;
        if Iter.Get('info/icon') <> nil then
        begin
          var Bmp := Iter.Get2('info/icon').Canvas.DumpBmpEx;
          Bmp.ID := Iter.Name;
          //Bmp.Name := Name;
          AIconList.Add(Bmp);
        end;
      end;
      Free;
    end;
  end;
  AIconList.Sort(TComparer<TBmpEx>.Construct(
    function(const Left, Right: TBmpEx): Integer
    begin
      Result := Left.ID.ToInteger - Right.ID.ToInteger;
    end));
  var Index := -1;
  AImageGrid.LockUpdate;
  for var Iter in AIconList do
  begin
    AImageGrid.AppendImage(Iter);
    Inc(Index);
    AImageGrid.ImageInfoText[Index] := Iter.ID;
  end;
  AImageGrid.UnlockUpdate;
  AImageGrid.ViewX := 0;
  AImageGrid.ViewY := 0;
end;

procedure TConsumeForm.FormActivate(Sender: TObject);
begin
  ActiveControl := nil;
  Edit1.Clear;
  if HasLoad then
    Exit;
  HasLoad := True;
  DumpIcons(ImageGrid, 'Consume', Wz, IconList);
end;

procedure TConsumeForm.FormCreate(Sender: TObject);
begin
  CreateImageGrid(ImageGrid, ConsumeForm, PageControl1.Pages[0]);
  ImageGrid.OnImageSelect := ImageGridSelect;
  Left := (Screen.Width - Width) div 2;
  Top := (Screen.Height - Height) div 2;
end;

procedure TConsumeForm.ImageGridSelect(Sender: TObject; idx: Integer);
begin
  ImageAssignIcon(ImageGrid.ImageInfoText[idx], 'Consume', IDlabel, NameLabel, Image1);
  ActiveControl := nil;
end;

procedure TConsumeForm.TabSheet2Show(Sender: TObject);
begin
  if HasShowImageGrid then
    Exit;
  HasShowImageGrid := True;

  ConsumeGrid.Canvas.Font.Size := 18;
  ConsumeGrid.Canvas.TextOut(60, 0, 'Loading...');

  var RowCount := -1;
  ConsumeGrid.BeginUpdate;
  for var Iter in StringWZ.GetImgFile('Consume.img').Root.Children do
  begin
    Inc(RowCount);
    ConsumeGrid.RowCount := RowCount + 1;
    ConsumeGrid.Cells[1, RowCount] := LeftPad(Iter.Name.ToInteger);
    ConsumeGrid.Cells[2, RowCount] := Iter.Get('name', '');
  end;
  ConsumeGrid.SortByColumn(1);
  ConsumeGrid.EndUpdate;
end;

procedure TConsumeForm.FormDestroy(Sender: TObject);
begin
  Wz.Free;
  IconList.Free;
end;

end.

