import chalk from "chalk";

export function greet(name: string): string {
  return `Hello, ${chalk.red(name)}`;
}
