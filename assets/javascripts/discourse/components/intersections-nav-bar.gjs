import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import I18n from "discourse-i18n";

const filters = [
  I18n.t("filters.latest.title"),
  I18n.t("filters.top.title"),
  I18n.t("filters.hot.title"),
  I18n.t("filters.new.title"),
  I18n.t("filters.unread.title"),
  I18n.t("filters.unseen.title"),
];

const filters_anon = [
  I18n.t("filters.latest.title"),
  I18n.t("filters.top.title"),
  I18n.t("filters.hot.title"),
];

export default class IntersectionNavBarComponent extends Component {
  @service router;
  @service currentUser;
  @controller("discovery/list") discoveryController;

  @tracked selected = "Latest";

  get shouldShow() {
    return this.router.currentRouteName === "tags.intersection";
  }

  // Use reactive getter to make sure selected is always correct
  get currentSelected() {
    const filter = this.router.currentRoute.queryParams?.int_filter;
    if (filter) {
      return filter.charAt(0).toUpperCase() + filter.slice(1);
    } else {
      return "Latest";
    }
  }

  get filters() {
    if (this.currentUser) {
      // If the user is logged in, show all filters
      return filters;
    }
    return filters_anon;
  }

  isActive(filter) {
    return this.selected === filter;
  }

  activeClass(filter) {
    return this.isActive(filter) ? "active" : "";
  }

  @action
  filterClicked(filter, event) {
    // Handle the filter click event

    event?.preventDefault();

    this.discoveryController.set("int_filter", filter.toLowerCase());

    this.router.transitionTo(
      "tags.intersection",
      this.args.tagName,
      this.args.additionalTagNames.join("/"),
      {
        queryParams: { int_filter: filter.toLowerCase() },
      }
    );
  }

  <template>
    {{#if this.shouldShow}}
      <ul class="nav nav-pills">
        {{#each this.filters as |filter|}}
          <li class="filter-item">
            <button
              class="btn-transparent
                {{if (eq this.currentSelected filter) 'active'}}"
              type="button"
              {{on "click" (fn this.filterClicked filter)}}
            >
              {{filter}}
            </button>
          </li>
        {{/each}}
      </ul>
    {{/if}}
  </template>
}
