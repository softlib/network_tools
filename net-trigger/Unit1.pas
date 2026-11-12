unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  IdBaseComponent, IdComponent, IdRawBase, IdRawClient, IdIcmpClient,
  Vcl.Buttons, Vcl.Mask, Winapi.ShellAPI, idStack, Indy10ThreadedPing{, WinAPIPingHandle, WinAPIICMPDeclare};

type
  TForm1 = class(TForm)
    LabeledEdit1: TLabeledEdit;
    Button1: TButton;
    Timer1: TTimer;
    GroupBox1: TGroupBox;
    Label5: TLabel;
    LabelField1: TLabel;
    BitBtn1: TBitBtn;
    OpenDialog1: TOpenDialog;
    Label2: TLabel;
    LabelField2: TLabel;
    TrayIcon1: TTrayIcon;
    procedure Button1Click(Sender: TObject);
    procedure LabeledEdit1KeyPress(Sender: TObject; var Key: Char);
    procedure BitBtn1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Timer1Timer(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure IdClientReply(ASender: TComponent;
      const AReplyStatus: TReplyStatus);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure WMSysCommand(var Msg:TWMSysCommand);
    message WM_SYSCOMMAND;

  end;

  TMyThread = class(TThread)
  private
    tms, tti: longint;
  protected
    procedure Execute; Override;
  public
   constructor Create(CreateSuspended: boolean; ms, ti: longint);
  end;

  TMyPingThread = class(TThreadedPing)
  protected
    procedure SynchronizedResponse(const ReplyStatus:TReplyStatus); override;
  end;

var
  Form1: TForm1;
  icoGreen, icoRed: Ticon;
  fals, falsmax, totalreset :byte;
  sysdir: array [0..MAX_PATH] of char;
  iter: integer;
  falsetick:integer;
  pingready: boolean;

  LongHold, ShortHold:TMyThread;

implementation

{$R *.dfm}

procedure Tform1.WMSysCommand(var Msg: TWMSysCommand);
begin
  if (msg.CmdType=SC_MINIMIZE) and (Form1.Visible) then
  begin
  form1.Hide;
  TrayIcon1.Visible:=true;
  TrayIcon1.BalloonHint:=TrayIcon1.Hint;
  TrayIcon1.ShowBalloonHint;
  end;
  //DefaultHandler(msg);
  inherited;
end;

constructor TMyThread.Create(CreateSuspended: boolean; ms, ti: longint);
begin
   inherited Create(CreateSuspended);
   tms:=ms; tti:=ti;
end;

procedure TMyThread.Execute;
var i:longint;
begin
   {Execute Async task, without VCL cals}
  for I := 0 to tms div tti do
  begin
  sleep(tti);
  pingready:=false;
  fals:=0;
  end;
  pingready:=true;
  fals:=0;
  Self.Terminate;
end;

procedure TMyPingThread.SynchronizedResponse(const ReplyStatus:TReplyStatus);
begin
  Form1.IdClientReply(nil, ReplyStatus);
end;

procedure TForm1.BitBtn1Click(Sender: TObject);
begin
  if OpenDialog1.Execute then
   begin
    if FileExists(OpenDialog1.FileName) then
    begin
     BitBtn1.Kind:=bkOK;
     BitBtn1.Caption:='Script Loaded';
     BitBtn1.ShowHint:=true;
     BitBtn1.Hint:=OpenDialog1.FileName;
    end;
   end;
end;


procedure TForm1.Button1Click(Sender: TObject);
begin
    if Timer1.Enabled
      then begin
      timer1.Enabled:=false;
      //TrayIcon1.Visible:=false;
      Form1.Caption:='NetTrigger';
      Button1.Caption:='Start Testing';
      LabeledEdit1.ReadOnly:=false;
      LabeledEdit1.Color:=clWindow;
      BitBtn1.Enabled:=true;
      TrayIcon1.Icon:=Application.Icon;
      TrayIcon1.Hint:='NOT Watching...';
      TrayIcon1.ShowBalloonHint;
      LabelField1.Caption:=''; LabelField2.Caption:='';
      end else begin
      iter:=0;
      fals:=0;
      //CreateIndy;
      totalreset:=0;
      BitBtn1.Enabled:=false;
      icoGreen:=TIcon.Create; icoRed:=TIcon.Create;
      icoGreen.LoadFromFile('green.ico'); icoRed.LoadFromFile('red.ico');
      //TrayIcon1.Visible:=true;
      Button1.Caption:='Stop Testing';
      LabeledEdit1.ReadOnly:=true;
      LabeledEdit1.Color:=clBtnFace;

      GetSystemDirectory(sysdir,MAX_PATH);

      pingready:=true;
      timer1.Enabled:=true;

      end;

end;

procedure TForm1.LabeledEdit1KeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
  '0'..'9','.',',',#8:;
  else Key:=Char(0);
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
icoGreen.Free;
icoRed.Free;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
falsmax:=11;
fals:=0;
ReportMemoryLeaksOnShutdown := True;
end;

procedure TForm1.IdClientReply(ASender: TComponent;
  const AReplyStatus: TReplyStatus);
begin

    if //(pingerror) or
    (AReplyStatus.ReplyStatusType=rsTimeOut) or
    (AReplyStatus.ReplyStatusType=rsErrorUnreachable) or
    (AReplyStatus.ReplyStatusType=rsErrorTTLExceeded) or
    (AReplyStatus.ReplyStatusType=rsErrorPacketTooBig) or
    (AReplyStatus.ReplyStatusType=rsErrorParameter) or
    (AReplyStatus.ReplyStatusType=rsErrorDatagramConversion) or
    (AReplyStatus.ReplyStatusType=rsErrorSecurityFailure) or
    (AReplyStatus.ReplyStatusType=rsError)
   then
   begin
    form1.LabelField1.Font.Color:=clRed;
    form1.LabelField2.Font.Color:=clRed;
    form1.LabelField1.Caption:='Ping Error!';
    form1.LabelField2.Caption:='N/A';
    form1.TrayIcon1.Hint:='Ping Eror'+#13+'Detecting fails: #'+IntToStr(fals)+'/'+IntToStr(falsmax);
    form1.TrayIcon1.Icon:=icoRed;
    fals:=fals+1;

   end else begin
     form1.TrayIcon1.Icon:=icoGreen;
     fals:=0;
     totalreset:=0;
     form1.LabelField1.Font.Color:=clGreen;
     form1.LabelField2.Font.Color:=clGreen;

     form1.LabelField1.Caption:='['+IntToStr(iter)+'] '+AReplyStatus.Msg;
     form1.LabelField2.Caption:=IntToStr(AReplyStatus.TimeToLive) +'/'+ IntToStr(AReplyStatus.MsRoundTripTime);
     form1.TrayIcon1.Hint:='Ping OK!'+#13+'TTL/RndTm: '+IntToStr(AReplyStatus.TimeToLive) +'/'+ IntToStr(AReplyStatus.MsRoundTripTime);
   //  ShowMessage('ok');
   end;

   if (fals>=falsmax) then
   begin
      if FileExists(OpenDialog1.FileName) then
      begin
      fals:=0;
        ShellExecute(Application.Handle, 'open', 'cmd', PWideChar('/c '+OpenDialog1.FileName), PWideChar(StrPAs(sysdir)), SW_hide);
        totalreset:=totalreset+1;
        LongHold:=TMyThread.Create(false,60000,timer1.Interval);
      end else begin
        fals:=0;
      end;
   end;

   iter:=iter+1;
   Form1.Caption:='NetTrigger (Fail #'+IntToStr(fals)+'/'+IntToStr(falsmax)+')';
   if totalreset>=3 then Button1.Click;

end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
if pingready then
begin
      falsetick:=1;
      TMyPingThread.Create(LabeledEdit1.Text);
end
else
begin
     falsetick:=falsetick+1;
     form1.LabelField2.Caption:='CoolDown '+floattostr( round((timer1.Interval*falsetick)/1000) )+' sec...';
     form1.TrayIcon1.Hint:='Cooling down after rest '+floattostr( round((timer1.Interval*falsetick)/1000) )+' sec...';
end;


end;

procedure TForm1.TrayIcon1DblClick(Sender: TObject);
begin
  form1.Show;
 ShowWindow(form1.Handle,SW_RESTORE);
 TrayIcon1.Visible:=false;
end;

end.
