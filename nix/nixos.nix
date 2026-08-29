{ env, basePackage }:

let
  pkgs = env.pkgs;
  lib = pkgs.lib;
in
basePackage.override (attrs: {
  zigPreferMusl = false;

  zigBuildFlags = (attrs.zigBuildFlags or [ ]) ++ [
    "-Dpoweroff-path=${lib.getExe' pkgs.systemd "poweroff"}"
    "-Dreboot-path=${lib.getExe' pkgs.systemd "reboot"}"
  ];

  zigWrapperBins = attrs.zigWrapperBins or [ ];
  zigWrapperLibs = attrs.zigWrapperLibs or [ ];
})
