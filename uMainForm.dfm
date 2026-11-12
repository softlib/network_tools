object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = #32593#21345#31649#29702#22120
  ClientHeight = 481
  ClientWidth = 772
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 772
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnRefresh: TButton
      Left = 8
      Top = 8
      Width = 75
      Height = 25
      Caption = #21047#26032
      TabOrder = 0
      OnClick = btnRefreshClick
    end
    object btnEnable: TButton
      Left = 96
      Top = 8
      Width = 75
      Height = 25
      Caption = #21551#29992
      Enabled = False
      TabOrder = 1
      OnClick = btnEnableClick
    end
    object btnDisable: TButton
      Left = 184
      Top = 8
      Width = 75
      Height = 25
      Caption = #31105#29992
      Enabled = False
      TabOrder = 2
      OnClick = btnDisableClick
    end
    object chkAutoRefresh: TCheckBox
      Left = 280
      Top = 10
      Width = 145
      Height = 17
      Caption = #33258#21160#30417#27979'(2'#31186')'
      Checked = True
      State = cbChecked
      TabOrder = 3
    end
    object Button1: TButton
      Left = 472
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Button1'
      TabOrder = 4
      OnClick = Button1Click
    end
  end
  object lvAdapters: TListView
    Left = 0
    Top = 41
    Width = 772
    Height = 421
    Align = alClient
    Columns = <
      item
        Caption = #21517#31216
        Width = 170
      end
      item
        Caption = #35774#22791#21517
        Width = 190
      end
      item
        Caption = #29366#24577
        Width = 110
      end
      item
        Caption = #31867#22411
        Width = 100
      end
      item
        Caption = #32593#21345#31867#22411
        Width = 130
      end
      item
        Caption = 'IP '#22320#22336
        Width = 130
      end
      item
        Caption = 'GUID'
        Width = 240
      end>
    GridLines = True
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnDblClick = lvAdaptersDblClick
    OnSelectItem = lvAdaptersSelectItem
  end
  object sbMain: TStatusBar
    Left = 0
    Top = 462
    Width = 772
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object Timer1: TTimer
    Interval = 2000
    OnTimer = Timer1Timer
    Left = 720
    Top = 8
  end
end
