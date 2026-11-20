# Bug Manager

Track friendly bugs with grouped map markers and terrain discovery. Customize team sharing, labels, filters and visibility settings for multiplayer and modded games.

## Getting started

1. Install **Bug Manager** from Factorio’s mod browser. On a multiplayer server, use the same mod version on the server and joining clients. [Factorio Mod Portal](https://mods.factorio.com/mod/friendly-bug-map)
2. As an admin, open **Bug Manager** beside the hotbar and choose **Add first sharing rule**. Select the team whose bugs you want to track and the team that should see them, then click **Apply**. You can also use `/bug-map config` and choose **Add rule**.
3. Open the map and click the **biter button** in the shared mod toolbar. **1** shows group icons and counts. **0** hides them for you. Teammates keep their own preferences, and terrain discovery and ordinary Factorio map blips continue.

Admins can pin the **Bug Manager** shortcut beside the hotbar to change marker settings and sharing rules. Any player can use `/bug-map reset-ui` to open or centre their marker panel and locate a charted group.

## Compatibility

Bug Manager requires only base Factorio 2.1. If you use Informatron 0.5.0 or later, open its **Bug Manager** entry for the in-game guide.

## Working with the source

The [friendly-bug-map](friendly-bug-map/) folder is the complete unpacked mod. To test it locally, copy that folder into Factorio’s `mods` directory, using one copy of Bug Manager at a time. [Changelog](friendly-bug-map/changelog.txt)

Created by **Killerdash117**. [MIT license](LICENSE)
