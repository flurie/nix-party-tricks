{ pkgs ? import <nixpkgs> { } }:
with pkgs.python39.pkgs;
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
}
