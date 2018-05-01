import { configure } from "@storybook/react";

function loadStories() {
  // TODO: Remove the need for manually writing require paths.
  require("__src__component_story/component.story");
}

configure(loadStories, module);
