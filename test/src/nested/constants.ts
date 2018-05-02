import TextBuilder from "textbuilder";

// This is an absolute path import.
import { PREFIX } from "@/test/src/nested/nodeps";

// This is a relative path import, from a parent directory.
import { sum } from "../testing/sum";

const t = new TextBuilder();
t.append(PREFIX);
t.append("" + sum(1, 2) + ":");

export const INFO_PREFIX = t.build();
