# discourse-tag-intersection-navigator

A Discourse plugin that enhances the Tag Intersections experience by supporting zero, one, or many tags in a single interface, with optional filter navigation and navigation integrations.

### Features

Enhances the existing Tag Intersections capability to:

* Allow empty intersections and single-tag intersections.
* Support different list filters (not only Latest).
* Make intersections the default desktop homepage (optional).
* Add a community link to the sidebar/header dropdown (optional).

### Important

Do not use the configured "everything" word as a real tag on your site.

### Settings

There are four settings:

* Enable the plugin.
* Configure the routing placeholder string used to mean "everything".
* Make the interface the desktop homepage (default: OFF).
* Include a community link in sidebar/header dropdown (default: ON).

### Limitations / Roadmap

* Category + intersection fallback to Category/Tag is implemented.
* Sub-categories are not yet supported.
* Navigation tabs do not include topic counts, and visibility is not yet driven by result availability.
* Filter availability/ordering does not yet follow site filter configuration.
* Mobile behavior follows core navigation layout constraints and may differ from desktop.
