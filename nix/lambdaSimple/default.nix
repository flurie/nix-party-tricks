{ pkgs ? import <nixpkgs> { system = "aarch64-linux"; } }:

let
  pythonEnv = pkgs.python39.withPackages (ps: with ps; [ awslambdaric pandas ]);
  entrypoint = pkgs.writeScriptBin "entrypoint.sh" ''
    #!${pkgs.bash}/bin/bash
    if [ -z "$AWS_LAMBDA_RUNTIME_API" ]; then
      exec ${pkgs.aws-lambda-rie}/bin/aws-lambda-rie ${pythonEnv}/bin/python3 -m awslambdaric $@
    else
      exec ${pythonEnv}/bin/python3 -m awslambdaric $@
    fi
  '';
  app = pkgs.writeScriptBin "app.py" ''
    #!${pythonEnv}/bin/python3

    import sys

    def handler(event, context):
        return "Hello from AWS Lambda using Python" + sys.version + "!"
  '';
in pkgs.dockerTools.buildLayeredImageWithNixDb {
  name = "nix-lambda";
  tag = "latest";
  contents = [ pkgs.bash pkgs.coreutils pythonEnv app pkgs.aws-lambda-rie ];
  config = {
    Entrypoint = [ "${entrypoint}/bin/entrypoint.sh" ];
    Cmd = [ "app.handler" ];
    WorkingDir = "${app}/bin";
  };
}
