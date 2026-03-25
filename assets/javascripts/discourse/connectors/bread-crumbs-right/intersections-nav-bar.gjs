import IntersectionsNavBar from "../../components/intersections-nav-bar";

const IntersectionsNavBarConnector = <template>
  <IntersectionsNavBar
    @tag={{@outletArgs.tag}}
    @additionalTags={{@outletArgs.additionalTags}}
  />
</template>;

export default IntersectionsNavBarConnector;
