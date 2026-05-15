{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.API;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  Ganymede.Utils,
  Ganymede;

type
  { TGnyAPI }
  TGnyAPI = class(TGnyBaseObject)
  private
  public
    constructor Create(); override;
    destructor Destroy(); override;
    procedure RegisterAll(const AScript: TGanymede);
  end;

//------------------------------------------------------------------------------
// Flat API wrappers — registered with the JIT via ImportHost
//------------------------------------------------------------------------------

var
  GAPI: TGnyAPI;

implementation

{ TGnyAPI }

constructor TGnyAPI.Create();
begin
  inherited;
end;

destructor TGnyAPI.Destroy();
begin
  inherited;
end;

procedure TGnyAPI.RegisterAll(const AScript: TGanymede);
begin
end;

initialization
  GAPI := TGnyAPI.Create();

finalization
  FreeAndNil(GAPI);

end.
