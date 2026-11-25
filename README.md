<p align="center">
  <img src="friendly-bug-map/thumbnail.png" width="112" height="112" alt="Bug Manager mod icon">
</p>

<h1 align="center">Bug Manager</h1>

<p align="center">
  Follow friendly swarms across the Factorio map and share the terrain they discover with the teams you choose.
</p>

<p align="center">
  <strong>Source version</strong> <code>1.3.9</code> &nbsp;·&nbsp;
  <strong>Factorio</strong> <code>2.1</code> &nbsp;·&nbsp;
  <strong>License</strong> <a href="LICENSE">MIT</a>
</p>

<p align="center">
  <a href="https://mods.factorio.com/mod/friendly-bug-map">Install from the Mod Portal</a>
  &nbsp;·&nbsp; <a href="friendly-bug-map/changelog.txt">Changelog</a>
  &nbsp;·&nbsp; <a href="#working-with-the-source">Contributor guide</a>
</p>

## On the map

A swarm of 237 nearby bugs can appear as a single marker labelled **Fox Swarm: 237 bugs**. Larger groups take priority when the map reaches its marker limit. Bugs outside that limit can still reveal terrain. Tracking leaves the swarm under its existing orders.

| Control | Who can use it | What it does |
| --- | --- | --- |
| Biter button in the map toolbar | Every player in remote view | **1** shows group icons and counts. **0** hides them for you. Your choice is saved. Teammates keep their own views, discovery continues and ordinary map blips stay visible. |
| **Find a group** in the marker panel | Players with remote-view permission | Search the current surface by source team or custom map name. Select a result and click **Locate group** to centre the map on its last charted position. Open the panel with `/bug-map reset-ui`. |
| **Bug Manager** shortcut beside the hotbar | Admins | Set team marker visibility, filter sources, name swarms and manage sharing rules. Pin the shortcut from the **⋮** menu beside the hotbar. |

## Set up team sharing

1. Install **Bug Manager** from Factorio’s mod browser. On a multiplayer server, use the same game version and enabled mod versions on the server and joining clients.
2. As an admin, open the hotbar shortcut and choose **Add first sharing rule**. For another rule, choose **Sharing rules → Add rule**. You can also open the rule list with `/bug-map config`.
3. Select the **Source force** that owns the bugs and the **Receiving force** that should see their information. Choose markers, terrain discovery, map refresh or any combination. Check the direction and radius in the preview, then click **Apply**.

For example, a one-way rule from **Swarm → Builders** lets Builders follow Swarm’s bugs. Enable **Share in both directions** to let Swarm follow eligible bugs owned by Builders as well. New saves start with an empty rule list, and admins choose from the teams in their own save.

Open **Advanced filters** to choose creatures or surfaces for one rule. Disabled creature checkboxes show the map defaults. Enable **Override default entity filters** to edit them. In marker settings, leave **Map name** blank to display the source team’s actual name.

## Multiplayer and upgrades

Base Factorio 2.1 is the only requirement. If you use Informatron 0.5.0 or later, open its **Bug Manager** entry for the in-game guide. Markers and terrain refresh periodically. Discovered terrain persists after a swarm moves on, and zoomed-in remote viewing follows Factorio’s normal live-visibility rules.

Back up the server save before upgrading. Version **1.3.9** was tested on **Factorio 2.1.23** with one graphical client connected to a 75-mod dedicated server. Direct upgrade and restart checks passed from all 16 earlier tracking builds, including the published 1.3.8 package.

## Working with the source

- **Run a development copy.** Copy the `friendly-bug-map/` folder into Factorio’s `mods/` directory and use one copy of Bug Manager at a time. Keep the internal name `friendly-bug-map` so Factorio recognises the mod in existing saves. [Mod source](friendly-bug-map/) · [Version and dependencies](friendly-bug-map/info.json)
- **Contribute a translation.** Copy the English locale files into `locale/<language-code>/` inside the mod. Translate the text on the right of each `=` and preserve keys and placeholders such as `__1__`. [English locale files](friendly-bug-map/locale/en/)

Created by **Killerdash117**.
