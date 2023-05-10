# ~/.config/nixpkgs/overlays/pythonEnv.nix
self: super: {
  pythonEnv = super.buildEnv {
    name = "pythonEnv";
    paths = [
      # A Python 3 interpreter with some packages
      (self.python3.withPackages (
        ps: with ps; [
          slackclient
        ]
      ))

      # Some other packages we'd like as part of this env
      #self.mypy
    ];
  };
}