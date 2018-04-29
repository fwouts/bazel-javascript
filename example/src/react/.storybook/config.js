import { configure } from "@storybook/react";

function loadStories() {
  require("__src__react__component_story/component.story");
}

configure(loadStories, module);
