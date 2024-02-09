{
  description = "A static website development environment with Jekyll";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # No need for poetry2nix in a Jekyll project, so it's removed
  };

  outputs = { nixpkgs, flake-utils, ... }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            git
            gnumake
            hugo
            go
            #nodejs
            #ruby
            #bundler # Bundler is often used with Jekyll to manage Ruby gem dependencies
            #jekyll
          ];
        };
      }
    );
}
