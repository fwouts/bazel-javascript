import TextBuilder from "textbuilder";

const t = new TextBuilder();
t.append("Hello ", process.argv[2] || "Daniel");
export const GREETING = t.build();
