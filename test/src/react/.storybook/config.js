import { configure } from "@storybook/react";

function loadStories() {
  require("__test__src__react__component_story/component.story");
}

configure(loadStories, module);
