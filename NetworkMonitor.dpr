program NetworkMonitor;

uses
  Vcl.Forms,
  uMainForm in 'uMainForm.pas' {MainForm},
  uNetworkConnection in 'uNetworkConnection.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := '网卡管理器';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
