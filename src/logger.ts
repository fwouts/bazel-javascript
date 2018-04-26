import { INFO_PREFIX } from "./constants";

export class Logger {
  public info(message: string) {
    console.log(INFO_PREFIX + message);
  }
}
