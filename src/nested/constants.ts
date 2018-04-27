import TextBuilder from "textbuilder";

const t = new TextBuilder();
t.append("INFO");
t.append(":");

export const INFO_PREFIX = t.build();
