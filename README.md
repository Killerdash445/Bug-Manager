<h1 align="center">
  <img src="docs/images/bug-manager-banner.jpg" width="100%" alt="Bug Manager">
</h1>

<p align="center">
  Follow friendly swarms on the Factorio map and share the terrain they discover with the teams you choose.
</p>

<p align="center">
  <strong>Source version</strong> <a href="friendly-bug-map/info.json"><code>1.3.12</code></a>
  &nbsp;·&nbsp; <strong>Factorio</strong> <code>2.1</code>
  &nbsp;·&nbsp; <strong>License</strong> <a href="LICENSE">MIT</a>
</p>

<p align="center">
  <strong><a href="https://mods.factorio.com/mod/friendly-bug-map">Get Bug Manager on the Mod Portal</a></strong>
  &nbsp;·&nbsp; <a href="#set-up-team-sharing">Quick setup</a>
  &nbsp;·&nbsp; <a href="friendly-bug-map/changelog.txt">Changelog</a>
</p>

## On the map

A single marker can read **Fox Swarm: 237 bugs**. Nearby bugs share an icon, larger groups take priority, and eligible bugs beyond the marker limit can still reveal terrain. The swarm keeps its existing orders.

| What you want to do | Where to find it |
| --- | --- |
| **Hide details on your map** | In remote view, click the **biter** in the map toolbar. A plain biter means details are on. A crossed-out biter means they are hidden for you. Your choice survives reconnects. Teammates keep their own views, and discovery and ordinary map blips continue. |
| **Find a particular swarm** | Open the marker panel with `/bug-map reset-ui`. Type a source team or its map name in **Find a group**, select a result, then click **Locate group**. Results are on your current surface and respect remote-view permissions. |
| **Configure your team’s map** | As an admin, click **Bug Manager** beside the hotbar. Choose **Sharing rules** to edit rules, or **Expand team display settings** to filter sources and name their swarms. Use the **⋮** menu beside the hotbar to pin the shortcut. |

<p align="center">
  <a href="docs/images/group-search.png"><img src="docs/images/group-search.png" width="390" alt="Marker panel showing the viewed surface, group search and admin controls"></a>
  <a href="docs/images/sharing-rule.png"><img src="docs/images/sharing-rule.png" width="390" alt="Sharing-rule editor previewing a one-way rule with icons, discovery, map refresh and a 16-tile radius"></a>
</p>

<p align="center">
  Open the <a href="docs/images/group-search.png">group finder</a> or the <a href="docs/images/sharing-rule.png">sharing-rule editor</a> at full size.
</p>

## Set up team sharing

1. **Install the mod.** Find **Bug Manager** in Factorio’s mod browser. Use the same game version and enabled mod versions on the server and joining clients.
2. **Choose the teams.** As an admin, open the hotbar shortcut and select **Add first sharing rule**. Pick the **Source force** that owns the bugs and the **Receiving force** that should see their information. To add another rule, use **Sharing rules → Add rule**, or open the list with `/bug-map config`.
3. **Choose what to share.** The three checkboxes below the team selectors control markers, discovery and refresh. **Advanced filters** opens the creature and surface options. The preview and **Apply** button stay below the scrolling form so you can check the direction and radius before saving.

> **Example** · With **Swarm → Builders**, Builders can follow Swarm’s bugs. Tick **Share in both directions** if Swarm should also receive map information from Builders’ eligible bugs.

New saves start with an empty rule list. Under **Advanced filters**, disabled creature, platform and sandbox checkboxes show the map defaults. Enable the corresponding override to edit this rule’s own choices. In team display settings, leave **Map name** blank to display the source team’s actual name.

## Multiplayer and upgrades

Base Factorio 2.1 is the only requirement. With Informatron 0.5.0 or later enabled, press **I** by default and choose **Bug Manager**. **My map** illustrates both toolbar icons. **Sharing rules** walks through a first rule, and **Missing icons or groups** helps diagnose a quiet map. If your server enables Informatron, joining players need the matching version. [View the in-game guide](docs/images/informatron-guide.png).

Markers and terrain update periodically. Discovered terrain stays on the map after a swarm moves away. Zoomed-in remote viewing follows Factorio’s normal live-visibility rules.

Back up your save, install the same ZIP on the server and clients, and load the existing save. Bug Manager then updates its tracking data automatically. Saved rules, custom team names, marker preferences and ordinary map tags carry forward. Apply any open rule edit before updating. An older window closes once and can be reopened with the hotbar shortcut or `/bug-map config`.

On Factorio **2.1.23**, direct upgrades to **1.3.12** and a second save and restart passed for all 19 earlier tracking builds from 1.0.0 through 1.3.11. One graphical client exercised the marker panel and rule editor with the 75-mod test profile. Simultaneous use by two connected clients remains untested on this build.

## Working with the source

- **Run a development copy.** Copy `friendly-bug-map/` into Factorio’s `mods/` directory and use one copy of Bug Manager at a time. Keep the internal name `friendly-bug-map` so existing saves recognise it. [Mod source](friendly-bug-map/) · [Version and dependencies](friendly-bug-map/info.json)
- **Contribute a translation.** Copy the English locale files into `locale/<language-code>/` inside the mod. Translate the values after each `=` and preserve keys and placeholders such as `__1__`. [English locale files](friendly-bug-map/locale/en/)

Created by **Killerdash117**.
