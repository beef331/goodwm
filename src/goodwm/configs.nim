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

proc getButtonSyms(s: string): (int, cuint) =
  for sym in s.extractSyms:
    case sym.toLower
    of "alt", "Alt":
      result[1] = result[1] or Alt
    of "shift", "Shift":
      result[1] = result[1] or Shift
    of "super", "Super":
      result[1] = result[1] or Mod4Mask
    else:
      result[0] = parseint(sym)

proc reloadConfig*(d: var Desktop)

let
  KeyTable = [
    keFocusUp: focusUp.KeyEvent,
    keFocusDown: focusDown,
    keMoveUp: moveUp,
    keMoveDown: moveDown,
    keClose: killActiveWindow,
    keNextWorkspace: moveToNextWorkspace,
    keLastWorkspace: movetoLastWorkspace,
    keWindowToNextWorkSpace: moveWindowToNextWorkspace,
    keWindowToPrevWorkSpace: moveWindowToPrevWorkspace,
    keReloadConfig: reloadConfig,
    keToggleFloating: toggleFloating
  ]



proc toKeyShortcut(display: PDisplay, modi: cuint, sym, cmd: string): (Key, Shortcut) =
  result[0] = initKey(display, sym, modi)
  result[1] =
    try:
      let enm = parseEnum[KeyEvents](cmd)
      case enm
      of KeyTable.low..KeyTable.high:
        initShortcut(KeyTable[enm])
      of keMoveToScreen:
        let id = parseInt(sym)
        initShortcut(id)
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

    for i, x in conf.mouseShortcuts:
      let
        (btn, modi) =
          try:
              x.btn.getButtonSyms
            except:
              sendConfigError(fmt"{x.btn} is not a valid input")
              continue
        event =
          try:
              parseEnum[MouseInput](x.event)
            except:
              sendConfigError(fmt"{x.event} is not a valid mouse action.")
              continue
      d.mouseEvent[initButton(btn, modi)] = event

    for key in conf.keyShortcuts:
      block findKey:
        var (keySym, modi) = getKeySyms(key.inputs)
        if keySym.len > 0:
          let (key, shortcut) = toKeyShortcut(d.display, modi.cuint, keySym, key.cmd)
          d.shortcuts[key] = shortcut

  for scr in d.screens.mitems:
    scr.statusbar.updateStatusBar(scr.bounds.w.int, scr.barSize)

proc loadConfig*(): Option[Config] =
  for x in configPaths:
    if x.fileExists:
      try:
        let a = Toml.decode(x.readFile, Config)
        return some(a)
      except Exception as e:
        sendConfigError(e.msg)

proc reloadConfig*(d: var Desktop) =
  d.mouseEvent.clear()
  d.shortcuts.clear()
  setupConfig(d, loadConfig())
  grabInputs(d)
