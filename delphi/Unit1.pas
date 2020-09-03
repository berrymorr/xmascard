unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Mask, Spin, ComCtrls;

type
  TForm1 = class(TForm)
    lb1: TListBox;
    Label1: TLabel;
    Label2: TLabel;
    lb2: TListBox;
    Button1: TButton;
    Button2: TButton;
    od1: TOpenDialog;
    sd1: TSaveDialog;
    RadioGroup1: TRadioGroup;
    RadioG1B1: TRadioButton;
    RadioG1B2: TRadioButton;
    Processing: TGroupBox;
    cb1: TCheckBox;
    Label3: TLabel;
    Label4: TLabel;
    se1: TSpinEdit;
    pb1: TProgressBar;
    se2: TSpinEdit;
    cb2: TCheckBox;
    bpmedit: TSpinEdit;
    procedure Button1Click(Sender: TObject);
    procedure lb1Click(Sender: TObject);
    procedure RadioG1B1Click(Sender: TObject);
    procedure RadioG1B2Click(Sender: TObject);
    procedure cb1Click(Sender: TObject);
    procedure cb2Click(Sender: TObject);
    procedure bpmeditChange(Sender: TObject);
    procedure se1Change(Sender: TObject);
    procedure se2Change(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

const us_per_min=60000000;

type Tevent=record
msg:byte;
note:byte;
pos:dword;
delay:dword;
len:dword;
end;

type TMTrk=record
channel:byte;
poly:boolean;
name:string;
events:array of Tevent;
end;

var numtracks,mformat,division,ppqn:word;
us_per_tick,mpqn:dword;
tracks:array of TMTrk;
parsed:array of Tevent;

function SwapBytes(value:dword):dword;
type Bytes=packed array[0..3] of Byte;
begin
Bytes(Result)[0]:=Bytes(Value)[3];
Bytes(Result)[1]:=Bytes(Value)[2];
Bytes(Result)[2]:=Bytes(Value)[1];
Bytes(Result)[3]:=Bytes(Value)[0];
end;

function readvarlen(var f:file):dword;
var b:byte;
begin
result:=0;
repeat
  blockread(f,b,1);
  result:=(result shl 7)or(b and $7F);
until ((b and $80)<>$80);
end;

function KeyToStr(key:integer;byMIDI:boolean=true):string;
var n:integer;
str:string;
begin
if key=$DD then result:='pause' else
  begin
  n:=key mod 12;
  case n of
    0: str:='C';
    1: str:='C#';
    2: str:='D';
    3: str:='D#';
    4: str:='E';
    5: str:='F';
    6: str:='F#';
    7: str:='G';
    8: str:='G#';
    9: str:='A';
    10:str:='A#';
    11:str:='B';
  end;
  if byMIDI then
    result:=str+IntToStr(key div 12)
  else
    result:=str+IntToStr((key div 12)-2);
  end;
end;

function channel_exists(traxx:array of TMTrk;channel:byte;var trnum:integer):boolean;
var q:integer;
begin
result:=false;
trnum:=-1;
for q:=0 to length(traxx)-1 do
if traxx[q].channel=channel then
  begin
  trnum:=q;
  result:=true;
  break;
  end;
end;




procedure TForm1.Button1Click(Sender: TObject);
type Tcbuf=array[0..3]of char;
var q,len,trknum:integer;
f:file;
cbuf:Tcbuf;
bbuf:array[0..7]of byte;
ticks,tick_pos,dbuf:dword;
msg,prv_msg,data1,data2:byte;
mtrk_end:boolean;
smpte:shortint;

function nextMTrk(var f:file; var cb:Tcbuf; var db:dword):boolean;
var numread:integer;
begin
if eof(f) then
  begin
  result:=false;
  exit;
  end;

db:=0;
repeat
seek(f,filepos(f)+longint(db));
blockread(f,cb,4,numread);
blockread(f,db,4,numread);
db:=swapbytes(db);
if (numread<4) or eof(f) then
  begin
  result:=false;
  exit;
  end;
until cb='MTrk';
result:=true;
end;

begin
if od1.Execute then
  begin
  mpqn:=500000;//value for default 120bpm
  setlength(tracks,0);
  lb1.Clear;
  lb2.Clear;
  button2.Enabled:=false;
  processing.Visible:=false;
  pb1.Min:=0;
  pb1.Position:=0;
  pb1.Max:=0;
  pb1.Visible:=true;
  assignfile(f,od1.FileName);
  reset(f,1);
  blockread(f,cbuf,4); //reading MThd header
  if cbuf<>'MThd' then begin
                       showmessage('bad file');
                       application.Terminate;
                       end;
  blockread(f,bbuf,4); //reading length of MThd header
  if bbuf[3]<>6 then begin
                     showmessage('bad file');
                     application.Terminate;
                     end;
  blockread(f,bbuf,2); //reading format
  mformat:=(word(bbuf[0])shl 8) or bbuf[1];
  if mformat>1 then begin
                    if mformat=2 then showmessage('could not work with MIDI format #2')
                    else showmessage('bad file');
                    application.Terminate;
                    end;
  blockread(f,bbuf,2); //reading tracks num
  numtracks:=(word(bbuf[0])shl 8) or bbuf[1]; pb1.Max:=numtracks;
  blockread(f,bbuf,2); //reading time division
  division:=(word(bbuf[0])shl 8) or bbuf[1];


  if mformat=1 then //parse mformat=1
    begin
    pb1.Position:=0;
    pb1.Min:=0;
    while nextMTrk(f,cbuf,dbuf) do //searching next MTrk record
      begin
      prv_msg:=0;
      setlength(tracks,length(tracks)+1); //makin' new empty track
      tracks[length(tracks)-1].name:='';
      tracks[length(tracks)-1].poly:=false;
      setlength(tracks[length(tracks)-1].events,0);
      mtrk_end:=false;
      tick_pos:=0;
      repeat
      ticks:=readvarlen(f);
      inc(tick_pos,ticks);//save current position on track
      blockread(f,msg,1);//read msg
      if msg<$80 then    //check for running status
        begin
        msg:=prv_msg;         //running status in action!
        seek(f,filepos(f)-1); //allow re-read as parameter
        end
      else prv_msg:=msg;      //save prev. msg
      case msg of
      //note off
      $80..$8F:
        begin
        blockread(f,data1,1);//read note
        blockread(f,data2,1);//read velocity
        //is this da same note?
        if length(tracks[length(tracks)-1].events)>0 then
        if (tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].note=data1)then
          begin
          //save this note
          tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].len:=
          tick_pos-tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].pos;
          //if it's not zero-length note then make new dead note
          if tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].len>0 then
          setlength(tracks[length(tracks)-1].events,length(tracks[length(tracks)-1].events)+1);
          //save channel
          tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].msg:=(msg and $0F)or $90;
          //dead note
          tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].note:=$DD;
          tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].pos:=tick_pos;
          end else tracks[length(tracks)-1].poly:=true; //this is POLYYYYYYYYYYYYYYyyyy!!!11111
        end;

      //note on
      $90..$9F:
        begin
        blockread(f,data1,1);//read note
        blockread(f,data2,1);//read velocity
        if data2>0 then
          begin //velocity>0
          if length(tracks[length(tracks)-1].events)>0 then
            begin
            //save curr note's length
            tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].len:=
            tick_pos-tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].pos;
            //if it's not zero-length note then make new note
            if (tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].len>0)
            then setlength(tracks[length(tracks)-1].events,length(tracks[length(tracks)-1].events)+1);
            end else //if length(events)=0 then make new note
          setlength(tracks[length(tracks)-1].events,length(tracks[length(tracks)-1].events)+1);

          tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].msg:=msg;
          tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].note:=data1;
          tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].pos:=tick_pos;
          tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].delay:=ticks;
          end
        else //velocity=0. this is note off msg
          begin
          //is this da same note?
          if (tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].note=data1)then
            begin
            //save this note
            tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].len:=
            tick_pos-tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].pos;
            //make new dead note
            setlength(tracks[length(tracks)-1].events,length(tracks[length(tracks)-1].events)+1);
            //save channel
            tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].msg:=(msg and $0F)or $90;
            //dead note
            tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].note:=$DD;
            tracks[length(tracks)-1].events[length(tracks[length(tracks)-1].events)-1].pos:=tick_pos;
            end else tracks[length(tracks)-1].poly:=true; //this is POLYYYYYYYYYYYYYYyyyy!!!11111
          end;
        end;

      //skip two data bytes
      $A0..$AF,$B0..$BF,$E0..$EF: //A - note aftrtch, B - cntrllr, E - pitchbend
        begin
        blockread(f,data1,1);//read data1
        blockread(f,data2,1);//read data2
        end;

      //skip one data byte
      $C0..$DF: //C - program change, D - channel aftertouch
        begin
        blockread(f,data1,1);//read data1
        end;

      //SYSEX
      $F0:
        begin
        for q:=0 to readvarlen(f)-1 do//read SYSEX length
        blockread(f,data1,1);
        if data1<>$F7 then showmessage('SYSEX parsing error');
        end;

      //meta eventz
      $FF:
        begin
        blockread(f,data1,1); //read metaevent type
        len:=readvarlen(f);   //read metaevent length
        case data1 of
        $03,$04://track name,instrument name
          begin
          if tracks[length(tracks)-1].name<>'' then
          tracks[length(tracks)-1].name:=tracks[length(tracks)-1].name+'/';
          for q:=0 to len-1 do
            begin
            blockread(f,data2,1);
            tracks[length(tracks)-1].name:=tracks[length(tracks)-1].name+chr(data2);
            end;
          end;
        $2F:    //MTrk end
          begin
          mtrk_end:=true;
          //remove last dead note
          if length(tracks[length(tracks)-1].events)>0 then
          setlength(tracks[length(tracks)-1].events,length(tracks[length(tracks)-1].events)-1);
          end;
        $51:   //set TEMPO (MPQN)
          begin
          blockread(f,mpqn,3);
          mpqn:=swapbytes(mpqn);
          mpqn:=mpqn shr 8;
          end;
        else for q:=0 to len-1 do blockread(f,data2,1); //skip othr metamessagez
        end;
        end;

      //smth fatal
      else begin
           showmessage('File is corrupted!');
           application.Terminate;
           end;
      end;
      until mtrk_end;
      lb1.Items.Add('Trk. '+inttostr(length(tracks)-1)+
      ' "'+tracks[length(tracks)-1].name+'" ('+inttostr(dbuf)+')');
      pb1.Position:=pb1.Position+1;
      application.ProcessMessages;
      end;
    end   //end of parsing mtype=1


    else
    begin //parsing mtype=0
    nextMTrk(f,cbuf,dbuf); //goto single MTrk

    pb1.Max:=integer(pb1.Min+integer(dbuf));
    pb1.Position:=integer(filepos(f));
    pb1.Min:=pb1.Position;

    prv_msg:=0;
    mtrk_end:=false;
    tick_pos:=0;
      repeat
      pb1.Position:=filepos(f);
      application.ProcessMessages;

      ticks:=readvarlen(f);
      inc(tick_pos,ticks);//save current position on track
      blockread(f,msg,1);//read msg
      if msg<$80 then    //check for running status
        begin
        msg:=prv_msg;         //running status in action!
        seek(f,filepos(f)-1); //allow re-read as parameter
        end
      else prv_msg:=msg;      //save prev. msg

      case msg of
      //note off
      $80..$8F:
        begin
        blockread(f,data1,1);//read data1
        blockread(f,data2,1);//read data2
        if channel_exists(tracks,(msg and $0F),trknum)then
        //is this da same note?
        if length(tracks[trknum].events)>0 then
        if (tracks[trknum].events[length(tracks[trknum].events)-1].note=data1)then
          begin
          //save this note
          tracks[trknum].events[length(tracks[trknum].events)-1].len:=
          tick_pos-tracks[trknum].events[length(tracks[trknum].events)-1].pos;
          //if it's not zero-length note then make new dead note
          if tracks[trknum].events[length(tracks[trknum].events)-1].len>0 then
          setlength(tracks[trknum].events,length(tracks[trknum].events)+1);
          //save channel
          tracks[trknum].events[length(tracks[trknum].events)-1].msg:=(msg and $0F)or $90;
          //dead note
          tracks[trknum].events[length(tracks[trknum].events)-1].note:=$DD;
          tracks[trknum].events[length(tracks[trknum].events)-1].pos:=tick_pos;
          end else tracks[trknum].poly:=true; //this is POLYYYYYYYYYYYYYYyyyy!!!11111
        end;

      //note on
      $90..$9F:
        begin
        blockread(f,data1,1);//read data1
        blockread(f,data2,1);//read data2
        //find existing or create new track for readed channel
        if not channel_exists(tracks,(msg and $0F),trknum) then
          begin
          setlength(tracks,length(tracks)+1); //makin' new empty track
          tracks[length(tracks)-1].poly:=false;
          tracks[length(tracks)-1].name:='CH #'+inttostr(msg and $0F);
          tracks[length(tracks)-1].channel:=msg and $0F;
          setlength(tracks[length(tracks)-1].events,0);
          trknum:=length(tracks)-1;
          lb1.Items.Add(tracks[length(tracks)-1].name);
          end;
        //trknum - number of TMTrk in tracks, which contains current channel
        if data2>0 then
          begin //velocity>0
          if length(tracks[trknum].events)>0 then
            begin
            //save curr note's length
            tracks[trknum].events[length(tracks[trknum].events)-1].len:=
            tick_pos-tracks[trknum].events[length(tracks[trknum].events)-1].pos;
            //if it's not zero-length note then make new note
            if (tracks[trknum].events[length(tracks[trknum].events)-1].len>0)
            then setlength(tracks[trknum].events,length(tracks[trknum].events)+1);
            end else //if length(events)=0 then make new note
          setlength(tracks[trknum].events,length(tracks[trknum].events)+1);

          tracks[trknum].events[length(tracks[trknum].events)-1].msg:=msg;
          tracks[trknum].events[length(tracks[trknum].events)-1].note:=data1;
          tracks[trknum].events[length(tracks[trknum].events)-1].pos:=tick_pos;
          tracks[trknum].events[length(tracks[trknum].events)-1].delay:=ticks;
          end
        else //velocity=0. this is note off msg
          begin
          //is this da same note?
          if (tracks[trknum].events[length(tracks[trknum].events)-1].note=data1)then
            begin
            //save this note
            tracks[trknum].events[length(tracks[trknum].events)-1].len:=
            tick_pos-tracks[trknum].events[length(tracks[trknum].events)-1].pos;
            //make new dead note
            setlength(tracks[trknum].events,length(tracks[trknum].events)+1);
            //save channel
            tracks[trknum].events[length(tracks[trknum].events)-1].msg:=(msg and $0F)or $90;
            //dead note
            tracks[trknum].events[length(tracks[trknum].events)-1].note:=$DD;
            tracks[trknum].events[length(tracks[trknum].events)-1].pos:=tick_pos;
            end else tracks[trknum].poly:=true; //this is POLYYYYYYYYYYYYYYyyyy!!!11111
          end;
        end;

      //skip two data bytes
      $A0..$AF,$B0..$BF,$E0..$EF: //A - note aftrtch, B - cntrllr, E - pitchbend
        begin
        blockread(f,data1,1);//read data1
        blockread(f,data2,1);//read data2
        end;

      //skip one data byte
      $C0..$DF: //C - program change, D - channel aftertouch
        begin
        blockread(f,data1,1);//read data1
        end;

      //SYSEX message
      $F0:
        begin
        for q:=0 to readvarlen(f)-1 do//read SYSEX length
        blockread(f,data1,1);
        if data1<>$F7 then showmessage('SYSEX parsing error');
        end;

      //META events
      $FF:
        begin
        blockread(f,data1,1); //read metaevent type
        len:=readvarlen(f);   //read metaevent length
        case data1 of
        $2F:    //MTrk end
          begin
          mtrk_end:=true;
          //remove last dead note
          for q:=0 to length(tracks)-1 do
          if length(tracks[q].events)>0 then
          setlength(tracks[q].events,length(tracks[q].events)-1);
          end;
        $51:   //set TEMPO (MPQN)
          begin
          blockread(f,mpqn,3);
          mpqn:=swapbytes(mpqn);
          mpqn:=mpqn shr 8;
          end;
        else for q:=0 to len-1 do blockread(f,data2,1); //skip othr metamessagez
        end;

        end
      else //smthn's wrong
        begin
        showmessage('u should not see this. smthn''s wrong.');
        end;
      end;
      until mtrk_end;
    end;

  closefile(f); //all events of all MTrks r parsed
  pb1.Visible:=false;
  processing.Visible:=true;

  smpte:=shortint(hi(division));
  if smpte<0 then
    begin
    us_per_tick:=(-smpte)*lo(division);
    ppqn:=mpqn div us_per_tick;
    end
  else
    begin
    us_per_tick:=mpqn div division;
    ppqn:=division;
    end;
  //debug
  showmessage('us/tick='+inttostr(us_per_tick)+' ppqn='+inttostr(ppqn));
  if lb1.Items.Count>0 then
    begin
    lb1.ItemIndex:=0;
    lb1Click(nil);
    end;

  bpmedit.Value:=us_per_min div mpqn;
  end;
end;

procedure TForm1.lb1Click(Sender: TObject);
var q:integer;
begin
if (length(tracks)=0)or(lb1.ItemIndex<0)then exit;

form1.Caption:=od1.FileName;
if tracks[lb1.ItemIndex].poly then form1.Caption:=form1.Caption+' [!POLY!]';
form1.Caption:=form1.Caption+' ('+inttostr(us_per_min div mpqn)+' BPM)';

setlength(parsed,0);
lb2.Clear;
button2.Enabled:=false;
for q:=0 to length(tracks[lb1.ItemIndex].events)-1 do
  //ignore drums?
  if not ((cb1.Checked)and(tracks[lb1.ItemIndex].events[q].msg=$99))then
    begin
    //check for events count limit
    if (cb2.Checked)and(length(parsed)>=se2.Value) then break;
    //copy to parsed
    setlength(parsed,length(parsed)+1);
    parsed[q].msg:=tracks[lb1.ItemIndex].events[q].msg;
    //transposing
    if (tracks[lb1.ItemIndex].events[q].note+se1.Value>=0)and
       (tracks[lb1.ItemIndex].events[q].note<128)
    then parsed[q].note:=tracks[lb1.ItemIndex].events[q].note+se1.Value
    else parsed[q].note:=tracks[lb1.ItemIndex].events[q].note;
    parsed[q].pos:=tracks[lb1.ItemIndex].events[q].pos;
    parsed[q].delay:=tracks[lb1.ItemIndex].events[q].delay;
    parsed[q].len:=tracks[lb1.ItemIndex].events[q].len;

    lb2.Items.Add('#'+inttostr(q)+' msg=0x'+
    inttohex(parsed[q].msg,2)+' note='+
    keytostr(parsed[q].note,radioG1B2.Checked)+'(0x'+
    inttohex(parsed[q].note,2)+') pos/dly='+
    inttostr(parsed[q].pos)+'/'+
    inttostr(parsed[q].delay)+' len='+
    inttostr(parsed[q].len));
    end;
form1.Caption:=form1.Caption+' ('+inttostr(length(parsed))+' events on track)';
if length(parsed)>0 then button2.Enabled:=true;
end;

procedure TForm1.RadioG1B1Click(Sender: TObject);
begin
lb1Click(nil);
end;

procedure TForm1.RadioG1B2Click(Sender: TObject);
begin
lb1Click(nil);
end;

procedure TForm1.cb1Click(Sender: TObject);
begin
lb1Click(nil);
end;

procedure TForm1.cb2Click(Sender: TObject);
begin
se2.Enabled:=cb2.Checked;
lb1Click(nil);
end;

procedure TForm1.bpmeditChange(Sender: TObject);
begin
mpqn:=us_per_min div bpmedit.Value;
us_per_tick:=mpqn div ppqn;
lb1Click(nil);
end;

procedure TForm1.se1Change(Sender: TObject);
begin
lb1Click(nil);
end;

procedure TForm1.se2Change(Sender: TObject);
begin
lb1Click(nil);
end;

procedure TForm1.Button2Click(Sender: TObject);
var q,i:integer;
song_h:textfile;
begin
if sd1.Execute then
  begin
  i:=0;
  assignfile(song_h,sd1.FileName);
  rewrite(song_h);
  writeln(song_h,'/*typedef struct {');
  writeln(song_h,'uint8_t  note; //DD-dead note,BB-goto begin (end of song)');
  writeln(song_h,'uint16_t dly;');
  writeln(song_h,'}part;*/'#13#10);
  writeln(song_h,'// array elements count shouldn''t exceed 2048 for stm8s103f3p6');
  writeln(song_h,'const fcode part song[',length(parsed)+1,'] = {');
  for q:=0 to length(parsed)-1 do
    begin
    write(song_h,'0x',inttohex(parsed[q].note,2),',0x',
    inttohex(round(65535-us_per_tick*parsed[q].len/1000),4),',  ');
    inc(i);
    if i>7 then
      begin
      write(song_h,#13#10);
      i:=0;
      end;
    end;
  writeln(song_h,#13#10'0xBB,0xFFFF};');
  closefile(song_h);
  end;
end;

end.
