import * as Koa from "koa";
import { greet } from "../../../libs/shared-package/greeter";

const app = new Koa();

app.use(async ctx => {
  ctx.body = greet("World");
  // Just for fun, add a small chance of crashing. This allows us to check whether stack
  // traces are readable.
  if (Math.random() < 0.1) {
    throw new Error("Random crash.");
  }
});

app.listen(3000, () => console.log("Server is ready."));
