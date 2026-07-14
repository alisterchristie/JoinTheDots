program JoinTheDots;

uses
  System.StartUpCopy,
  FMX.Forms,
  formJoinTheDots in 'formJoinTheDots.pas' {Form51},
  uJoinTheDotsGame in 'uJoinTheDotsGame.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm51, Form51);
  Application.Run;
end.
