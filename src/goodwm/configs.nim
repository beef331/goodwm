import types, notifications, inputs, statusbar, desktops
import toml_serialization
import std/[os, options, strutils, parseutils, strformat, tables]
import x11/[xlib, x]
let configPaths = [getConfigDir() / "goodwm/config.toml", "config.toml"]

iterator extractSyms(s: string): string =
  var
    i = 0
    res: string
  while i < s.len:
    var capture = s.parseUntil(res, '+', i)
    yield res
    inc i, capture + 1

proc getKeySyms(s: string): (string, cuint) =
  for sym in s.extractSyms:
    case sym.toLower
    of "alt", "Alt":
      result[1] = result[1] or Alt
    of "shift", "Shift":
      result[1] = result[1] or Shift
    of "super", "Super":
      result[1] = result[1] or Mod4Mask
    else:
      if result[0].len > 0:
        sendConfigError(fmt"Multiple keysyms in {s}")
        return
      result[0] = sym

proc reloadConfig*(d: var Desktop)

func toKeyShortcut(display: PDisplay, modi: cuint, sym, cmd: string): (Key, Shortcut) =
  result[0] = initKey(display, sym, modi)
  result[1] =
    try:
      initShortcut:
        case parseEnum[KeyEvents](cmd)
        of keClose:
          killActiveWindow.KeyEvent
        of keFocusUp:
          focusUp
        of keFocusDown:
          focusDown
        of keMoveUp:
          moveUp
        of keMoveDown:
          moveDown
        of keNextWorkspace:
          moveToNextWorkspace
        of keLastWorkspace:
          moveToLastWorkspace
        of keWindowToNextWorkspace:
          moveWindowToNextWorkspace
        of keWindowToPrevWorkspace:
          moveWindowToPrevWorkspace
        of keReloadConfig:
          reloadConfig
        of keToggleFloating:
          toggleFloating
    except:
      initShortcut(cmd)



proc setupConfig*(d: var Desktop, config: Option[Config]) =
  if config.isSome:
    let conf = config.get

    for x in d.screens.mitems:
      x.margin = conf.margin
      x.padding = conf.padding
      x.barSize = conf.barSize

    for i, x in conf.screenLayouts:
      if i in 0..<d.screens.len:
        try:
          d.screens[i].layout = parseEnum[ScreenLayout](x)
        except Exception as e:
          sendConfigError(e.msg)

    for i, x in conf.screenStatusBarPos:
      if i in 0..<d.screens.len:
        try:
          d.screens[i].barPos = parseEnum[StatusBarPos](x)
        except Exception as e:
          sendConfigError(e.msg)

    for key in conf.keyShortcuts:
      block findKey:
        var (keySym, modi) = getKeySyms(key.inputs)
        if keySym.len > 0:
          let (key, shortcut) = toKeyShortcut(d.display, modi.cuint, keySym, key.cmd)
          d.shortcuts[key] = shortcut

  for scr in d.screens.mitems:
    scr.statusbar = initStatusBar(scr.bounds.w.int, scr.barSize)

proc loadConfig*(): Option[Config] =
  for x in configPaths:
    if x.fileExists:
      try:
        let a = Toml.decode(x.readFile, Config)
        return some(a)
      except Exception as e:
        echo e.msg

proc reloadConfig*(d: var Desktop) =
  setupConfig(d, loadConfig())
  grabInputs(d)
