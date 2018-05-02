import TextBuilder from "textbuilder";
import { PREFIX } from "@/test/src/nested/nodeps";

const t = new TextBuilder();
t.append(PREFIX);
t.append(":");

export const INFO_PREFIX = t.build();
