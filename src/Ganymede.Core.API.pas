{===============================================================================
  Ganymede™ - Embeddable Native Scripting Engine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Ganymede.Core.API;

{$I Ganymede.Defines.inc}

interface

uses
  System.SysUtils,
  Ganymede.Utils,
  Ganymede.Core;

type
  { TGnyAPI }
  TGnyAPI = class(TGnyBaseObject)
  private
    FCore: TGanymede;
  public
    constructor Create(); override;
    destructor Destroy(); override;
  end;

//------------------------------------------------------------------------------
// Flat API wrappers — registered with the JIT via ImportHost
//------------------------------------------------------------------------------


implementation

var
  GAPI: TGnyAPI;

{ TGnyAPI }

constructor TGnyAPI.Create();
begin
  inherited;
  FCore := TGanymede.Create();
end;

destructor TGnyAPI.Destroy();
begin
  FreeAndNil(FCore);

  inherited;
end;

initialization
  GAPI := TGnyAPI.Create();

finalization
  FreeAndNil(GAPI);

end.
