{
  description = "Sean's Blog in Drogon and C++";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
  inputs.quill-src = {
    url = "github:odygrd/quill/master";
    flake = false;
  };
  inputs.nix2container.url = "github:nlewo/nix2container";

  outputs = {
    self,
    nixpkgs,
    quill-src,
    nix2container,
    ...
  }: let
    # to work with older version of flakes
    lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

    # Generate a user-friendly version number.
    version = builtins.substring 0 8 lastModifiedDate;

    # System types to support.
    supportedSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];

    # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Nixpkgs instantiated for supported system types.
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [self.overlay];
      });
    nix2containerpkgsFor = forAllSystems (system: import nix2container.packages.${system});
  in {
    # A Nixpkgs overlay.
    overlay = final: prev: {
      quill = with final;
        clangStdenv.mkDerivation rec {
          pname = "quill";
          name = "${pname}-${version}";
          src = quill-src;
          nativeBuildInputs = [pkg-config cmake];
        };
      seans_blog = with final;
        stdenv.mkDerivation rec {
          pname = "personal_blog_api";
          name = "${pname}-${version}";

          src = ./.;

          nativeBuildInputs = [cmake];
          buildInputs = [drogon quill];
          installPhase = ''
            mkdir -p $out/bin
            cp personal_blog_api $out/bin
          '';
        };
    };

    # Provide some binary packages for selected system types.
    packages = forAllSystems (system:
      {
        inherit (nixpkgsFor.${system}) seans_blog quill;
      }
      // {
        blog = nix2container.packages.${system}.nix2container.buildImage {
          name = "seans-blog";
          config = {
            entrypoint = ["${nixpkgsFor.${system}.seans_blog}/bin/personal_blog_api"];
          };
        };
      });

    # The default package for 'nix build'. This makes sense if the
    # flake provides only one package or there is a clear "main"
    # package.
    defaultPackage = forAllSystems (system: self.packages.${system}.seans_blog);
  };
}
