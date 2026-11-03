# UIKit

> Made by `tools/vault-code-notes.js` from `src/client/UI/UIKit.luau` (139 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
UIKit: tiny helpers for building UI in code with one consistent theme.
All UI in this game is created from code (no StarterGui assets), so restyling = edit Theme.
  UIKit.new(className, props, children?)  -> Instance (props.Parent applied last)
  UIKit.Screen(name)                      -> ScreenGui in PlayerGui
  UIKit.Panel(props) / Label(props) / Button(props, onClick)
  UIKit.Corner(radius), UIKit.Stroke(color, thickness), UIKit.Padding(px)
  UIKit.AutoScale(root)                   -> UIScale that fits a full-screen root to the screen size
```

## Uses

- (none)

## Used by

- [[AirdropController]]
- [[BossController]]
- [[CutsceneController]]
- [[EffectsController]]
- [[HUDController]]
- [[LobbyController]]
- [[RadioController]]
- [[ShopController]]
- [[SkipController]]
- [[StoreController]]
- [[TouchController]]
- [[TutorialController]]
- [[WelcomeController]]
