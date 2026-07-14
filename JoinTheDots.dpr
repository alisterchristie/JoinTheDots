program JoinTheDots;

uses
  System.StartUpCopy,
  FMX.Forms,
  formJoinTheDots in 'formJoinTheDots.pas' {Form51};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm51, Form51);
  Application.Run;
end.
