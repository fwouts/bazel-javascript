// This is an unnecessarily convoluted example because we want an import of:
// - an NPM package
// - another JS file in the same directory and same BUILD target
// - another JS file in the same directory but different BUILD target
// - another JS file in a parent directory
// - another JS file in a child directory

import TextBuilder from "textbuilder";
import { A } from "../a";
import { B } from "./b";
import { C } from "./c";
import { D } from "./deep/d";

export function combined() {
  const t = new TextBuilder();
  t.append(A, ":", B, ":", C, ":", D);
  return t.build();
}
