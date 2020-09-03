object Form1: TForm1
  Left = 253
  Top = 372
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'MIDI 2 config.h v0.2a'
  ClientHeight = 348
  ClientWidth = 563
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 0
    Top = 8
    Width = 36
    Height = 13
    Caption = 'Tracks:'
  end
  object Label2: TLabel
    Left = 208
    Top = 8
    Width = 105
    Height = 13
    Caption = 'Track note on events:'
  end
  object lb1: TListBox
    Left = 0
    Top = 24
    Width = 201
    Height = 169
    ItemHeight = 13
    TabOrder = 2
    OnClick = lb1Click
  end
  object lb2: TListBox
    Left = 208
    Top = 24
    Width = 353
    Height = 169
    ItemHeight = 13
    TabOrder = 3
  end
  object Button1: TButton
    Left = 208
    Top = 272
    Width = 353
    Height = 25
    Caption = 'Load SMF'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 208
    Top = 312
    Width = 353
    Height = 25
    Caption = 'Save song.h'
    Enabled = False
    TabOrder = 1
    OnClick = Button2Click
  end
  object RadioGroup1: TRadioGroup
    Left = 208
    Top = 200
    Width = 153
    Height = 57
    Caption = 'Octave notation'
    TabOrder = 4
  end
  object RadioG1B1: TRadioButton
    Left = 216
    Top = 216
    Width = 105
    Height = 17
    Caption = 'Cubase/Reaper'
    Checked = True
    TabOrder = 5
    TabStop = True
    OnClick = RadioG1B1Click
  end
  object RadioG1B2: TRadioButton
    Left = 216
    Top = 232
    Width = 105
    Height = 17
    Caption = 'MIDI standard'
    TabOrder = 6
    OnClick = RadioG1B2Click
  end
  object Processing: TGroupBox
    Left = 0
    Top = 200
    Width = 201
    Height = 137
    Caption = 'Processing'
    TabOrder = 7
    Visible = False
    object Label3: TLabel
      Left = 82
      Top = 44
      Width = 29
      Height = 13
      Caption = 'BPM: '
    end
    object Label4: TLabel
      Left = 10
      Top = 76
      Width = 103
      Height = 13
      Caption = 'Transpose, semitones'
    end
    object cb1: TCheckBox
      Left = 8
      Top = 16
      Width = 185
      Height = 17
      Caption = 'Ignore CH10 (drums channel 0x09)'
      Checked = True
      State = cbChecked
      TabOrder = 0
      OnClick = cb1Click
    end
    object se1: TSpinEdit
      Left = 120
      Top = 75
      Width = 65
      Height = 22
      MaxValue = 127
      MinValue = -127
      TabOrder = 1
      Value = 0
      OnChange = se1Change
    end
    object se2: TSpinEdit
      Left = 120
      Top = 107
      Width = 65
      Height = 22
      MaxValue = 0
      MinValue = 0
      TabOrder = 2
      Value = 2048
      OnChange = se2Change
    end
    object cb2: TCheckBox
      Left = 8
      Top = 108
      Width = 113
      Height = 17
      Caption = 'Limit events count'
      Checked = True
      State = cbChecked
      TabOrder = 3
      OnClick = cb2Click
    end
    object bpmedit: TSpinEdit
      Left = 120
      Top = 44
      Width = 65
      Height = 22
      TabStop = False
      AutoSize = False
      MaxLength = 3
      MaxValue = 999
      MinValue = 1
      TabOrder = 4
      Value = 1
      OnChange = bpmeditChange
    end
  end
  object pb1: TProgressBar
    Left = 8
    Top = 224
    Width = 185
    Height = 17
    Min = 0
    Max = 100
    TabOrder = 8
    Visible = False
  end
  object od1: TOpenDialog
    DefaultExt = 'mid'
    Filter = 'Standard MIDI file|*.mid'
    Options = [ofHideReadOnly, ofFileMustExist, ofNoTestFileCreate, ofNoNetworkButton, ofEnableSizing]
    Left = 8
    Top = 32
  end
  object sd1: TSaveDialog
    FileName = 'song.h'
    Filter = 'song.h|song.h'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofPathMustExist, ofNoReadOnlyReturn, ofNoNetworkButton, ofEnableSizing]
    Left = 48
    Top = 32
  end
end
