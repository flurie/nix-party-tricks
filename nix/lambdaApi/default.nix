{ pkgs }:

let
  mangum = with pkgs.python39.pkgs;
    buildPythonPackage rec {
      pname = "mangum";
      version = "0.15.0";

      src = fetchPypi {
        inherit pname version;
        sha256 = "sha256-EuhIBhmLI7vVpUubacGu88YhdzRyGbtXyOwRS4prhTc=";
      };

      buildInputs = [ typing-extensions ];

      pythonImportsCheck = [ "mangum" ];

      meta = with pkgs.lib; {
        description = "AWS Lambda support for ASGI applications";
        homepage = "https://github.com/jordaneremieff/mangum";
        license = licenses.mit;
        maintainers = with maintainers; [ ];
      };
    };
  pythonEnv =
    pkgs.python39.withPackages (ps: with ps; [ awslambdaric mangum fastapi ]);
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

    from fastapi import FastAPI
    from mangum import Mangum

    app = FastAPI()


    @app.get("/")
    def read_root():
        return {"Hello": "World"}


    @app.get("/items/{item_id}")
    def read_item(item_id: int, q: str = None):
        return {"item_id": item_id, "q": q}

    handler = Mangum(app, lifespan="off")
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
