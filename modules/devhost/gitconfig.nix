# Materialise /home/dany/.gitconfig declaratively from devhost.git.*
#
# Cattle-not-pets: every nixos-rebuild overwrites the file. Ad-hoc aliases
# you add by hand will not survive — promote them to NixOS config if you
# want them to stick.
#
# We do not use `home.file` (no home-manager in this repo) and we do not
# use `environment.etc` (the file lives in $HOME, not /etc). An activation
# script is the smallest honest tool for this job.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.devhost.git;

  gitconfig = pkgs.writeText "gitconfig" ''
    [user]
    	name = ${cfg.userName}
    	email = ${cfg.userEmail}
  '';
in
{
  options.devhost.git = {
    userName = lib.mkOption {
      type = lib.types.str;
      description = "git user.name written to /home/dany/.gitconfig";
    };
    userEmail = lib.mkOption {
      type = lib.types.str;
      description = "git user.email written to /home/dany/.gitconfig";
    };
  };

  config = {
    system.activationScripts.devhostGitconfig = lib.stringAfter [ "users" ] ''
      install -o dany -g users -m 0644 ${gitconfig} /home/dany/.gitconfig
    '';
  };
}
