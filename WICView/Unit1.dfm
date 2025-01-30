object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 
    'wicview.exe - Windows Imaging API client - metadata viewer 30.01' +
    '.2017'
  ClientHeight = 535
  ClientWidth = 721
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  ShowHint = True
  OnCreate = FormCreate
  DesignSize = (
    721
    535)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 444
    Top = 468
    Width = 31
    Height = 13
    Caption = 'Label1'
  end
  object tree: TTreeView
    Left = 0
    Top = 0
    Width = 721
    Height = 535
    Align = alClient
    Indent = 19
    PopupMenu = PopupMenu1
    TabOrder = 0
    OnChange = treeChange
  end
  object Button1: TButton
    Left = 572
    Top = 490
    Width = 81
    Height = 25
    Hint = 'Open image'
    Anchors = [akRight, akBottom]
    Caption = 'Open an image'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 659
    Top = 490
    Width = 38
    Height = 25
    Hint = 'Expand or Collapse all the tree'
    Anchors = [akRight, akBottom]
    Caption = '+/-'
    TabOrder = 2
    OnClick = Button2Click
  end
  object SearchField: TMaskEdit
    Left = 506
    Top = 494
    Width = 60
    Height = 21
    Anchors = [akRight, akBottom]
    Color = clWhite
    TabOrder = 3
    Text = ''
    TextHint = 'Find...'
    OnChange = SearchFieldChange
  end
  object BackupTree: TTreeView
    Left = 506
    Top = 428
    Width = 60
    Height = 60
    Indent = 19
    PopupMenu = PopupMenu1
    TabOrder = 4
    Visible = False
    OnChange = treeChange
  end
  object SearchCnt: TStaticText
    Left = 441
    Top = 498
    Width = 59
    Height = 17
    Alignment = taRightJustify
    Anchors = [akRight, akBottom]
    AutoSize = False
    Caption = '0'
    Color = clWhite
    ParentColor = False
    TabOrder = 5
    Transparent = False
    Visible = False
  end
  object OpenDialog1: TOpenDialog
    Left = 592
    Top = 440
  end
  object PopupMenu1: TPopupMenu
    OnPopup = PopupMenu1Popup
    Left = 188
    Top = 116
    object Copyastext1: TMenuItem
      Caption = 'Copy data as text'
      OnClick = Copyastext1Click
    end
    object Copypath1: TMenuItem
      Caption = 'Copy path'
      OnClick = Copypath1Click
    end
    object SaveRAW1: TMenuItem
      Caption = 'Save as raw data'
      Visible = False
      OnClick = SaveRAW1Click
    end
  end
  object SaveDialog1: TSaveDialog
    Left = 664
    Top = 440
  end
end
