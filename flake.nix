{
  # flakes only have three top-level attributes:
  # - description
  # - inputs
  # - outputs
  description = "nix party tricks";

  # these could also be written as inputs = { nixpkgs = {url = ...; }; };
  # but this is more conventional and easier to read.
  #
  # almost all flakes will take nixpkgs as an input
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  # this is a great library for making better devshells.
  # great for helping projects standardize on tooling and scripts!
  inputs.devshell = {
    url = "github:numtide/devshell";
    # the _follows_ attributes make these use the top-level version of these
    # dependencies, because they would otherwise grab separate copies of their
    # own based on which version their lockfile says to get. this trades a
    # minor hit to reproducibility for speed, but in some cases it's a trade
    # not worth making.
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };

  # common util library for flakes. it is typically used to save on
  # unnecessary boilerplate in outputs. instead of having to enumerate
  # output values, you can enumerate output targets and use one of its
  # eachSystem-type helper functions to autogenerate the rest of the
  # boilerplate.
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # tool for deploying any common nix system outputs to nix systems
  inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    # inputs.nixpkgs.follows = "nixpkgs";
  };

  # tool for generating images of all kinds, including AMIs
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Flakes have a very specific output schema they expect, but since they are
  # still in active development, they only warn on unexpected attributes.
  # See https://nixos.wiki/wiki/Flakes#Output_schema for the current schema.
  outputs =
    { self, flake-utils, devshell, nixpkgs, deploy-rs, nixos-generators, ... }:
    let
      # For a given attrA.attrB this results in attrA.${system}.attrB
      eachOutputs = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            # overlays allow you to "overlay" attributes on a set, typically on
            # nixpkgs. here we're adding some helper functions, adding some
            # packages from outside of nixpkgs and modifying another out of
            # necessity since it has a broken dependency.
            overlays = [
              devshell.overlay
              (final: prev: {
                # expose deploy-rs package directly here
                deploy-rs = deploy-rs.defaultPackage.${system};
                # https://github.com/NixOS/nixpkgs/issues/175875
                awscli2 = if prev.pkgs.stdenv.isDarwin then
                  nixpkgs.legacyPackages.x86_64-darwin.awscli2
                else
                  prev.awscli2;
              })
            ];
            inherit system;
          };
          # rec means we can define attributes in terms of other attributes.
          # it allows us to "rec"urse the definitions
        in rec {
          # our devshell for each standard nix system
          devShells.default = pkgs.devshell.mkShell {
            imports = [ (pkgs.devshell.importTOML ./devshell.toml) ];
          };
          # our presentation in html format, convenient for static sites!
          packages.nixPartyTricksDocs = pkgs.stdenv.mkDerivation {
            name = "nix-party-tricks-docs";
            buildInputs = [ pkgs.pandoc ];
            src = ./docs;
            buildPhase = ''
              ${pkgs.pandoc}/bin/pandoc -f org -t html presentation.org > index.html
            '';
            installPhase = ''
              mkdir -p $out/www
              mv index.html $out/www
            '';
          };
          # packages.${system}.default is what a flake builds when supplied
          # without an argument
          packages.default = packages.nixPartyTricksDocs;

          # a very basic python lambda
          packages.lambdaSimple = pkgs.callPackage ./nix/lambdaSimple { };

          # a more substantial python lambda
          packages.lambdaApi = pkgs.callPackage ./nix/lambdaApi { };

          # a most substantial python lambda
          packages.lambdaDocs = pkgs.callPackage ./nix/lambdaDocs {
            inherit (packages) nixPartyTricksDocs;
          };
        });
      # need _recursiveUpdate_ because otherwise the second packages attribute
      # will clobber the first one, but standard map merge uses _//_
    in nixpkgs.lib.recursiveUpdate eachOutputs {
      # machine config for our aws tester
      nixosConfigurations.aws = nixpkgs.lib.nixosSystem
        (let system = "x86_64-linux";
        in {
          inherit system;
          modules = [
            # fun note: the modules list can take functions that expect
            # standard NixOS attributes so that non-NixOS systems aren't
            # required to evaluate these since they don't necessarily expose
            # these!
            ({ pkgs, ... }: {
              # _with_ syntax is rarely preferred since it is not explicit
              # and can lead to confusion, but it is almost always fine
              # when specifying _systemPackages_.
              environment.systemPackages = with pkgs; [ direnv git ];
              programs.bash.interactiveShellInit = ''
                eval "$(${pkgs.direnv}/bin/direnv hook bash)"
              '';
              programs.bash.shellInit = ''
                eval "$(${pkgs.direnv}/bin/direnv hook bash)"
              '';
            })
            ({ modulesPath, ... }: {
              # NixOS provides an attribute _modulesPath_ so the OS doesn't have
              # to reason about where the NixOS modules live
              imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];
              ec2.hvm = true;
              system.stateVersion = "22.05";
            })
            ({ config, ... }: {
              networking.hostName = "nixos-aws";
              # Just enabling nginx will provide a config with a set of
              # sane defaults: serving the standard nginx static site on
              # localhost:80.
              services.nginx.enable = true;
              # The firewall is on by default, so we have to poke a hole in it.
              networking.firewall.allowedTCPPorts = [ 80 ];
              nix = {
                extraOptions = ''
                  keep-outputs = true
                  keep-derivations = true
                  experimental-features = nix-command flakes
                '';
                settings = {
                  substituters = [ "https://flurie.cachix.org" ];
                  trusted-public-keys = [
                    "flurie.cachix.org-1:A80LCk3Y3l9gkYSdSJvXYV6q/Dh41Tx8nG1yO1j9T5A="
                  ];
                };
              };
              virtualisation.docker.enable = true;
            })
          ];
        });
      packages.x86_64-linux.awsImage = let system = "x86_64-linux";
      in nixos-generators.nixosGenerate {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [
          # fun note: the modules list can take functions that expect
          # standard NixOS attributes so that non-NixOS systems aren't
          # required to evaluate these since they don't necessarily expose
          # these!
          ({ pkgs, ... }: {
            # _with_ syntax is rarely preferred since it is not explicit
            # and can lead to confusion, but it is almost always fine
            # when specifying _systemPackages_.
            environment.systemPackages = with pkgs; [ direnv git ];
            programs.bash.interactiveShellInit = ''
              eval "$(${pkgs.direnv}/bin/direnv hook bash)"
            '';
            programs.bash.shellInit = ''
              eval "$(${pkgs.direnv}/bin/direnv hook bash)"
            '';
          })
          ({ modulesPath, ... }: {
            # NixOS provides an attribute _modulesPath_ so the OS doesn't have
            # to reason about where the NixOS modules live
            imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];
            ec2.hvm = true;
            system.stateVersion = "22.05";
          })
          ({ config, ... }: rec {
            networking.hostName = "nixos-aws-ami";
            # Required for flakes support
            nix.extraOptions = "experimental-features = nix-command flakes";
            # Here nginx is serving our presentation converted to html instead
            # of its normal splash page. I made the output of that a directory
            # rather than a single file because otherwise the derivation result
            # would show up as a single file, and we want to have a directory
            # to serve from.
            services.nginx = {
              enable = true;
              # we're serving up the machine's own hostname, set for us by
              # our nix configuration. note if it had dots in it that we would
              # need to string escape it.
              virtualHosts.${networking.hostName} = {
                # note how I can embed nix expressions within themselves,
                # much like how you can embed bash evaluations.
                root = "${self.packages."${system}".default}/www";
              };
            };
            # The firewall is on by default, so we have to poke a hole in it.
            networking.firewall.allowedTCPPorts = [ 80 ];
          })
        ];
        # specifies the format of the image we want to create. AMIs use VHD
        # due to legacy.
        format = "amazon";
      };
      deploy = {
        nodes = {
          "aws" = {
            # these settings are configurable at each level of the deploy
            # object, so we set them so that they only need to be written
            # once, keeping our code DRY.
            sshUser = "root";
            user = "root";
            sshOpts = [ "-i" "/tmp/nixos-ssh.pem" ];
            # NOTE: we can not deal with the IPs in a demo by adding it to
            # /etc/hosts, but I recommend finding a more permanent solution
            # for a real system.
            hostname = "nixos-aws";
            profiles.hello = {
              path = deploy-rs.lib.x86_64-linux.activate.custom
                nixpkgs.legacyPackages.x86_64-linux.hello "./bin/hello";
            };
            profiles.system = {
              # NOTE: again, we use an absolute path here in order to make the
              # demo easy, but it's not a good idea to use a temp path for ssh
              # keys. A better solution here would be an actual secrets manager
              # such as 1password or Pass, the standard unix password manager.
              path = deploy-rs.lib.x86_64-linux.activate.nixos
                self.nixosConfigurations.aws;
            };
          };
        };
      };
    };
}
