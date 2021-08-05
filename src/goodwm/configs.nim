import types
import toml_serialization
import std/[os, options]

let configPaths = [getConfigDir() / "goodwm/config.toml"]

proc loadConfig*(): Option[Config] =
  for x in configPaths:
    if x.fileExists:
      try:
        return some(Toml.decode(x.readFile, Config))
      except Exception as e:
        echo e.msg

