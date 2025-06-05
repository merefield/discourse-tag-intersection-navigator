# discourse-tag-intersection-navigator

A Discourse plugin that overhauls the Tag Intersections experience and makes it work with zero, one or more tags and different filters whilst giving you the option to make the interface your homepage

### Features

Enhances the existing Tag Intersections capability to:

* Allow it to be empty or used with just one tag
  * This makes for a more user friendly and flexible user experience, allowing you to drill in and out of a combination of tags
* Support for different filters instead of just Latest.
* Provide a way to make it the default on your desktop Homepage

### Important

:warning: you must *not* use the word "everything" as a tag on your instance (or whatever is in the corresponding setting). :warning:

### Settings

Three are just four settings:

* to enable the plugin
* determine which string is used to describe "everything" in the routing - I advise you don't change this, but you can experiment with alternative options.  You _must_ avoid using the same string as a tag
* to make the interface the Homepage for desktop (default OFF)
* include a community link in sidebar/header dropdown (default ON)

### Limitations/A Roadmap?

* It is relatively new and experimental, you may find issues.
* The interface is not offered on mobile.
* Like core intersections, does not work with a combo of Category - but this continues to fall back to the Category/Tag interface.
* There are no Topic counts on the navigation tabs and their visibility/availability is presently not determined by availability of the corresponding topic list population count.
* Not all filters are available.
