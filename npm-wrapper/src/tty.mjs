// Interactive-mode gate. Both stdio streams must be TTY and no CI env override in effect.
// `NON_INTERACTIVE=1` is a documented escape hatch for edge terminals (some VS Code integrated
// shells report isTTY=true but do not render prompt UI correctly).
export function isInteractive({
  stdin = process.stdin,
  stdout = process.stdout,
  env = process.env,
} = {}) {
  if (env.CI === 'true' || env.NON_INTERACTIVE === '1') return false;
  return Boolean(stdin.isTTY && stdout.isTTY);
}
