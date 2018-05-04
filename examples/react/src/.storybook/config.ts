import { configure } from "@storybook/react";

function loadStories() {
  require("../component.story");
}

configure(loadStories, module);
